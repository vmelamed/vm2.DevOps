#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
source "${lib_dir}/core.sh"

# defaults
declare -xr default_owner="vmelamed"
declare -xr default_visibility="public"
declare -xr default_branch="main"
declare -xr default_configure_only=false
declare -xr default_skip_secrets=false
declare -xr default_skip_variables=false
declare -xr default_force_defaults=false
declare -xr default_audit=false
declare -xr default_main_protection_rs_name="main protection"

# start with default input
declare -x repo_path=""
declare -x git_repos="${GIT_REPOS:-}"
declare -x visibility=${default_visibility}
declare -x branch=${default_branch}
declare -x configure_only=${default_configure_only}
declare -x skip_secrets=${default_skip_secrets}
declare -x skip_variables=${default_skip_variables}
declare -x force_defaults=${default_force_defaults}
declare -x audit=${default_audit}
declare -x main_protection_rs_name=${default_main_protection_rs_name}
declare -x description=""
declare -x use_ssh=false
declare -x use_https=false
declare -x repo_owner=${ORGANIZATION:-$default_owner}

declare -x repo_name=""
declare -x repo=""
declare -x repo_url=""
declare -x repo_id=""

# required checks enforced by branch protection; extended dynamically
declare -xa required_checks=()

source "${script_dir}/repo-setup.args.sh"
source "${script_dir}/repo-setup.usage.sh"
source "${script_dir}/repo-setup.functions.sh"

get_arguments "$@"

declare -xr expects_git_repo="${script_name} expects that the vm2* repositories are located in one parent directory specified with \$GIT_REPOS environment variable or --git-repos option."

#-------------------------------------------------------------------------------
# Check the prerequisites
#-------------------------------------------------------------------------------

command -v jq &> "$_ignore"                                 || error "'jq' is not installed. Please install it first."
command -v yq &> "$_ignore"                                 || error "'yq' is not installed. Please install it first."
[[ $(yq --version) =~ https://github\.com/mikefarah/yq/ ]]  || error 'This script requires "yq" by Mike Farah: "wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/.local/bin/yq4; chmod +x ~/.local/bin/yq4"'
command -v gh &> "$_ignore"                                 || error "'gh' is not installed. Please install it first."
gh auth status &> "$_ignore"                                || error "'gh' is not authenticated. Run 'gh auth login' first."

exit_if_has_errors

#-------------------------------------------------------------------------------
# Validate and adjust git_repos:
#-------------------------------------------------------------------------------

trace "GIT_REPOS='$GIT_REPOS'"
trace "git_repos='$git_repos'"

if [[ -n "$git_repos" && -d "$git_repos" ]]; then
   git_repos=$(realpath -e "$git_repos" 2> "$_ignore") || usage false "The path specified with \$GIT_REPOS environment variable or --git-repos option - '$git_repos' - is invalid."
else
    confirm "${expects_git_repo} Do you want to proceed and try to determine it heuristically?" "n" || exit 2
    r=$(root_working_tree "$script_dir") ||
    r=$(realpath -e "$(dirname "$script_dir/../..")") || usage false "Could not get the parent directory of this script's repository. ${expects_git_repo}"
    git_repos=$(realpath -e "$(dirname "$r")")
    trace "git_repos='$git_repos' from root_working_tree || realpath() heuristics"
fi

# make sure we are seeing .github and vm2.DevOps properly through git_repos
validate_source_repo ".github"
validate_source_repo "vm2.DevOps"
_ci_yaml="$git_repos/vm2.DevOps/.github/workflows/_ci.yaml"
[[ -s "$_ci_yaml" ]] || error "Could not find _ci.yaml workflow file in ${git_repos}."

exit_if_has_errors

declare -xr _ci_yaml

info "vm2* repositories path         => $git_repos"

#-------------------------------------------------------------------------------
# Validate and adjust repo_path:
#-------------------------------------------------------------------------------

[[ -n $repo_path ]] || repo_path=$(pwd)

r=$(realpath -e "$repo_path" 2> "$_ignore") ||
r=$(realpath -e "$git_repos/$repo_path" 2> "$_ignore") || usage false "Could not find the repository directory '$repo_path' neither in the current working directory, nor in '$git_repos'."
repo_path=$r
trace "repo_path='$repo_path' from realpath"
! is_in "$repo_path" "${git_repos}/vm2.DevOps" "${git_repos}/.github" || usage false "The repository directory cannot be '${git_repos}/vm2.DevOps' or '${git_repos}/.github'."

if r=$(find_repo_root "$repo_path" false "$git_repos") ||
   r=$(find_repo_root "$repo_path" false "$HOME"); then
    repo_path=$r
    trace "repo_path='$repo_path' from find_repo_root"
else
    ! $audit || usage false "Could not find an existing repository root for audit."
    # we cannot be here for audit. Audit requires that the specified repo is already initialized and configured.
    # For initializing and configuring a new repo we require that the the user provides the path to the root of the new repo's
    # work tree. We'll initialize it there and create the repo in GitHub based on it. If the user doesn't provide the full path,
    # we'll try to find an existing directory with the expected name in $git_repos or $HOME and use it as the root of the
    # new repository. We will not create a new directory for the repo, but we will initialize it as a git repository and link it
    # to GitHub.
    found_roots=0
    while IFS= read -r d; do
        [[ -d "$d/.github/workflows" ]] || continue
        repo_path="$d"
        (( ++found_roots ))
        trace "repo_path='$repo_path' from find in git_repos"
    done < <(find "$git_repos" -type d -path "*/${repo_path#/}" 2>"$_ignore")
    if (( found_roots == 0 )); then
        while IFS= read -r d; do
            [[ -d "$d/.github/workflows" ]] || continue
            repo_path="$d"
            (( ++found_roots ))
            trace "repo_path='$repo_path' from find in HOME"
        done < <(find "$HOME" -type d -path "*/${repo_path#/}" 2>"$_ignore")
    fi
    (( found_roots != 0 )) || usage false "Could not find a directory '${repo_path}' in \$GIT_REPOS or \$HOME. Please specify a valid path to the root of the solution."
    (( found_roots == 1 )) || usage false "Multiple directories named '${repo_path}' found in \$GIT_REPOS or \$HOME. Please specify a more specific path to the root of the solution."
fi
trace "Repository path is probably '$repo_path'"

#-------------------------------------------------------------------------------
# Get the repo state
#-------------------------------------------------------------------------------

declare -xA repo_state
declare suggest_repo_name=''

get_repo_state "$repo_path" repo_state || true

if has_local_repo repo_state; then
    repo_path="${repo_state[$key_root]}"

    declare -xr repo_path

    info "Repository path                => $repo_path"

    if has_remote_repo repo_state; then
        repo_url="${repo_state[$key_url]}"
        repo_owner="${repo_state[$key_owner]}"
        repo_name="${repo_state[$key_name]}"
        repo="${repo_state[$key_repo]}"

        declare -xr repo_url
        declare -xr repo_owner
        declare -xr repo_name
        declare -rx repo

        info "Repository                     => $repo"
        info "Repository URL                 => $repo_url"

        if has_github_remote repo_state; then
            repo_id="${repo_state[$key_repo_id]}"

            declare -xr ci_yaml

            info "Repository Id                  => $repo_id"
        fi
    fi
else
    suggest_repo_name=$(basename "$repo_path")

    declare -r suggest_repo_name

    trace "suggest_repo_name='$suggest_repo_name' from basename repo_path"
fi

ci_yaml="${repo_path}/.github/workflows/CI.yaml"
trace "ci_yaml='$ci_yaml' from \$repo_path"

#-------------------------------------------------------------------------------
# Final validation of the inputs and assumptions before we start making any changes or API calls:
#-------------------------------------------------------------------------------

[[ -s "$ci_yaml" ]]                                      || error "The specified path '${repo_path}' is not a valid project/repository root (missing .github/workflows/CI.yaml). Please specify a valid path to the root of the project/repository using '--path <path>' or use 'dotnet new vm2pkg <name>' to create a valid directory."
[[ -z $repo_name || $repo_name =~ $repo_name_regex ]]    || error "Could not determine repository name from the specified path '${repo_path}' or the name is invalid. Please specify a valid path to the root of the project/repository using '--path <path>'."
[[ -z $repo_owner || $repo_owner =~ $repo_owner_regex ]] || error "Could not determine repository owner from the specified path '${repo_path}', or from the environment variable ORGANIZATION, or the owner name is invalid. Please specify a valid owner of the project/repository using '--owner <owner>' or set the ORGANIZATION environment variable."
git check-ref-format --branch "$branch" &> "$_ignore"    || error "Invalid branch name '${branch}'. Please specify a valid branch name using '--branch <branch>'."
[[ $branch == "${repo_state[$key_default_branch]}" ]]    || error "The specified branch '$branch' is different from the GitHub default branch '${repo_state[$key_default_branch]}' in the existing repository. Please specify the valid branch name using '--branch <branch>'."
visibility="${visibility,,}"
is_in "$visibility" "public" "private" "internal"        || error "Invalid visibility '${visibility}'. Valid options are 'public', 'private', or 'internal'. Please specify a valid visibility using '--visibility <public|private|internal>'."

exit_if_has_errors

resolve_github_actions_app_id
detect_required_checks

declare -xr github_actions_app_id
declare -xra required_checks

# ------------------------------------------------------------------
# Audit
# ------------------------------------------------------------------

if $audit; then
    has_remote_repo repo_state || usage false "The specified repository does not appear to be initialized or linked to a remote repository on GitHub. Audit cannot proceed. Please specify a valid path to the root of the project/repository using '--path <path>' that is linked to a GitHub repository, or initialize and link the repository to GitHub first."
    source "${script_dir}/repo-setup.audit.sh"
    echo
    audit_repo
    exit 0
fi

# ------------------------------------------------------------------
# Initialize and configure the repository
# ------------------------------------------------------------------

declare -a undos=()
declare -A repo_state=()

declare -r valid_repo_names="GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit.
See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details."

if ! $has_local_repo repo_state; then

    # -------------------------------------------------------------------
    # We need to initialize the local repository.
    # -------------------------------------------------------------------

    if execute git -C "$repo_path" init; then
        trace "Repository initialized in '$repo_path'."
        undos+=("rm -rf '$repo_path/.git'")
    fi

    execute git -C "$repo_path" checkout -b "${branch}"                 && trace "'${branch}' branch checked out"
    execute git -C "$repo_path" add .                                   && trace "Staged all existing files in '$repo_path' for commit."
    if ! git -C "$repo_path" diff --cached --quiet; then
        execute git -C "$repo_path" commit -m "chore: initial scaffold" && trace "Committed staged files to '$repo_path'."
    fi

    repo_state["$key_root"]="$repo_path"
fi

if ! $has_remote_repo repo_state; then

    function validate_repo_name()
    {
        [[ "$1" =~ $repo_name_rex && "$1" != *.git ]] || {
            error "Invalid repository name. $valid_repo_names"
            return 1
        }
    }

    [[ -n $repo_name ]] || repo_name=$(enter_value "GitHub Repository name" "$suggest_repo_name" _ validate_repo_name)
    repo="$repo_owner/$repo_name"
    repo=${repo#/} # remove leading slash if repo_owner is empty

    info "Creating GitHub repository ${repo}..."
    create_repo_params=(
        "$repo"
        "--${visibility}"
        "--source" "$repo_path"
        "--remote" "origin"
        "--push"
        "--disable-wiki"
    )

    function validate_repo_description()
    {
        (( ${#1} >= 3 && ${#1} <= 350 )) || {
            error "Repository description must be between 3 and 350 characters long"
            return 1
        }
    }

    [[ -n "$description" ]] || description=$(enter_value "GitHub repository description (3-350 characters)" "$repo_name" _ validate_repo_description)
    [[ -n "$description" ]] && create_repo_params+=("--description" "$description")

    if $use_ssh || $use_https; then
        $use_ssh   && repo_url="git@github.com:${repo}.git" || true
        $use_https && repo_url="https://github.com/${repo}" || true
    else
        case $(choose "Access remote origin via" "SSH" "HTTPS") in
            1 ) use_ssh=true;   repo_url="git@github.com:${repo}.git" ;;
            * ) use_https=true; repo_url="https://github.com/${repo}" ;;
        esac
    fi

    execute gh repo create "${create_repo_params[@]}"
    undos+=("gh repo delete '$repo' --yes")

    execute git -C "$repo_path" remote set-url origin "${repo_url}"
    undos+=("git -C '$repo_path' remote remove origin")

    execute git -C "$repo_path" push -u origin "${branch}"

    # get the repo state again that will have more real git information in it.
    get_repo_state "$repo_path" repo_state || error "Failed to get repository state after creation. The repository may have been created successfully, but the script cannot continue with configuration. Please check the repository at $repo_path"

    repo_path="${repo_state[$key_root]}"
    repo_url="${repo_state[$key_url]}"
    repo_id="${repo_state[$key_repo_id]}"

    [[ -n "$repo_url"  ]] &&
    info "Repository URL                 => $repo_url"
    [[ -n "$repo_id"   ]] &&
    info "Repository Id                  => $repo_id"
fi

[[ -n "$repo_url" && -n "$repo_id" ]] || usage false "The repository does not appear to be initialized and/or linked to the remote. Run the script again without the switch --configure-only or troubleshoot the problem."

# ----------------------------------------------------------------------------
# Configure the remote repository on GitHub, and push initial commit to GitHub
# ----------------------------------------------------------------------------

configure_repo_settings
configure_actions_permissions
configure_branch_protection
$skip_secrets   || configure_secrets
$skip_variables || configure_variables

info "Repository ready: https://github.com/${repo}"
if [[ "$skip_secrets" != true ]]; then
    warning "All secrets have placeholder values — update them with real values."
fi
