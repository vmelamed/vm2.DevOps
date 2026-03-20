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
# shellcheck disable=SC1091
source "${lib_dir}/_sanitize.sh"

# defaults
declare -xr default_vm2_repos="$HOME/repos/vm2"
declare -xr default_owner="vmelamed"
declare -xr default_visibility="public"
declare -xr default_branch="main"
declare -xr default_interactive=false
declare -xr default_audit=false

# start with default input
declare -x vm2_repos="${VM2_REPOS:-$default_vm2_repos}"
declare -x repo_path=""
declare -x visibility=${default_visibility}
declare -x branch=${default_branch}
declare -x interactive_vars=${default_interactive}
declare -x interactive_secrets=${default_interactive}
declare -x audit=${default_audit}
declare -x main_protection_rs_name=""
declare -xi main_protection_rs_id=0
declare -x description=""
declare -x use_ssh=true
declare -x use_https=false
declare -x repo_owner=${ORGANIZATION:-$default_owner}

declare -x repo_name=""
declare -x repo=""
declare -x repo_url=""
declare -x repo_id=""

declare -x path_vars
declare -x path_repo
declare -x path_permissions
declare -x path_secrets
declare -x path_vars
declare -x path_rulesets
declare -x path_main_protection_ruleset

declare -xa required_checks=()
declare -xi github_actions_app_id=0

source "${script_dir}/repo-setup.args.sh"
source "${script_dir}/repo-setup.usage.sh"
source "${script_dir}/repo-setup.defaults.sh"
source "${script_dir}/repo-setup.functions.sh"
source "${script_dir}/repo-setup.audit.sh"

get_arguments "$@"

is_verbose && show_ignored_output

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
# Validate and adjust vm2_repos:
#-------------------------------------------------------------------------------

trace "VM2_REPOS='$VM2_REPOS'"
trace "vm2_repos='$vm2_repos'"

declare -xr expects_git_repo="${script_name} expects that the vm2.* repositories are located in one parent directory specified by the '--vm2-repos' option, or the '\$VM2_REPOS' environment variable, or in the default '\$HOME/repos/vm2'."

# try to resolve vm2_repos from the environment variable VM2_REPOS, if not $HOME/repos/vm2, and finally from the command line option --vm2-repos.
if [[ -n "$vm2_repos" && -d "$vm2_repos" ]]; then
    # looks good so far - ensure $vm2_repos is absolute path and exists.
    vm2_repos=$(realpath -e "$vm2_repos" 2> "$_ignore") ||
        usage false "The path specified by the '--vm2-repos' option, or the '\$VM2_REPOS' environment variable, or the default '\$HOME/repos/vm2' - '$vm2_repos' - is invalid."
    trace "vm2_repos='$vm2_repos' from '--vm2-repos option', or \$VM2_REPOS, or '\$HOME/repos/vm2'"
else
    # Try from the current working directory:
    r=$(root_working_tree "$(pwd)") ||
        confirm "${expects_git_repo} Could not determine the path of the parent directory of the vm2.* repositories. Do you want to proceed and try to determine it heuristically?" "n" ||
        usage false "${expects_git_repo} Could not determine the path of the parent directory of the vm2.* repositories."

    # or try heuristics:
    # suppose this script is from a cloned vm2.DevOps repository - use git to find the root of the repository and then use its parent directory as vm2_repos
    r=$(root_working_tree "$script_dir") ||

    ## let's not do this - we don't know where this script is located - it could be in any directory.
    ##
    ## or try to start from the directory of this script which is usually in vm2.DevOps/scripts/bash and find the grand-parent directory - vm2.DevOps
    ## we expect that this should give us the directory of the vm2.DevOps repo:
    #r=$(realpath -e "$script_dir/../..") ||

    # all failed - exit with error and usage.
    usage false "Could not get the parent directory of this script's repository. ${expects_git_repo}"

    # get the parent of vm2.DevOps as vm2_repos
    vm2_repos="$(dirname "$r")"

    trace "vm2_repos='$vm2_repos' from heuristics"
fi

# now make sure that we are seeing .github and vm2.DevOps properly through vm2_repos
validate_source_repo ".github"
validate_source_repo "vm2.DevOps"

declare -x _ci_yaml=''

_ci_yaml="$vm2_repos/vm2.DevOps/.github/workflows/_ci.yaml"
[[ -s "$_ci_yaml" ]] ||
    error "Could not find _ci.yaml GitHub Actions reusable workflow file in ${vm2_repos}."

exit_if_has_errors

declare -xr _ci_yaml

info "vm2.* repositories path        => $vm2_repos"

#-------------------------------------------------------------------------------
# Validate and adjust repo_path:
#-------------------------------------------------------------------------------

[[ -n "$repo_path" ]] ||  repo_path="$(pwd)"

# try to resolve repo_path from the parameter or from the current working directory
r=$(realpath -e "$repo_path" 2> "$_ignore") ||
# try to resolve repo_path relative to vm2_repos
r=$(realpath -e "$vm2_repos/${repo_path#/*}" 2> "$_ignore") ||
    usage false "Could not find the repository directory '$repo_path' neither in the current working directory, nor in '$vm2_repos'."
repo_path=$r
! is_in "$repo_path" "${vm2_repos}/vm2.DevOps" "${vm2_repos}/.github" ||
    usage false "The repository directory cannot be '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github'."
trace "repo_path='$repo_path' from parameter, \$(pwd), or vm2_repos with realpath"

# we found some directory, let's see if it is from within a git repository (works when repo_path is the pwd) - and if yes - get the root of it
if r=$(find_repo_root "$repo_path" false "$vm2_repos") ||
   r=$(find_repo_root "$repo_path" false "$HOME"); then
    repo_path=$r
    trace "repo_path='$repo_path' from find_repo_root in vm2_repos or \$HOME"
else
    reset_errors

    # For initializing and configuring a new repo we require that the the user provides the path to the root of the new repo's
    # work tree. It should be created using `dotnet new vm2.NewPkg` and should have the .github/workflows/CI.yaml file in place.
    # If we cannot find the .github/workflows/CI.yaml file in the specified path, we bail out.
    [[ -s "$repo_path/.github/workflows/CI.yaml" ]] ||
        usage false "Could not find .github/workflows/CI.yaml in '$repo_path'. Please use 'dotnet new vm2.NewPkg' to create a valid project directory structure, or specify the correct path to the root of the project/repository using '--path <path>'."

    trace "repo_path='$repo_path' has .github/workflows/CI.yaml, but is not inside a git repository. Will initialize a new repository here."
fi
trace "Repository path: '$repo_path'"

#-------------------------------------------------------------------------------
# Get the repo state
#-------------------------------------------------------------------------------

declare -A repo_state=()
declare -x suggest_repo_name=''
declare -x ci_yaml=''

get_repo_state "$repo_path" repo_state
dump_repo_state repo_state

if has_local_repo repo_state; then

    if [[ "$repo_path" != "${repo_state[$key_root]}" ]]; then
        warning "The repository path '$repo_path' is different from the repository root '${repo_state[$key_root]}' detected by git. Adjusting to the git-detected repository root."
        repo_path="${repo_state[$key_root]}"
        [[ -s "$repo_path/.github/workflows/CI.yaml" ]] ||
            usage false "The git-detected repository path '$repo_path' is missing .github/workflows/CI.yaml. Please specify a valid path to the root of the project/repository using '--path <path>' or use 'dotnet new vm2.NewPkg' to create a valid directory structure."
        trace "repo_path='$repo_path' from git-detected repository root"
    fi
    info "Repository path                => $repo_path"

    declare -r repo_path

    if has_remote_repo repo_state; then
        repo_url="${repo_state[$key_url]}"
        repo_owner="${repo_state[$key_owner]}"
        repo_name="${repo_state[$key_name]}"
        repo="${repo_state[$key_repo]}"

        declare -xr repo_url
        declare -xr repo_owner
        declare -xr repo_name
        declare -rx repo

        info "GitHub Repository              => $repo"

        if has_github_remote repo_state; then
            repo_id="${repo_state[$key_repo_id]}"
            branch="${repo_state[$key_default_branch]}"
            main_protection_rs_name="${main_protection_rs_name:-${branch} protection}"

            info "GitHub Repository Id           => $repo_id"
            info "GitHub Default Branch          => $branch"
        fi

        info "GitHub Repository URL          => $repo_url"
    fi
fi

if ! has_local_repo repo_state || ! has_remote_repo repo_state; then
    suggest_repo_name=$(basename "$repo_path")
    trace "Will suggest '$suggest_repo_name' from basename repo_path as a repo name and repo description during repo creation if needed."

    declare -rx suggest_repo_name
fi

ci_yaml="${repo_path}/.github/workflows/CI.yaml"
trace "ci_yaml='$ci_yaml' from \$repo_path"

declare -xr ci_yaml

#-------------------------------------------------------------------------------
# Final validation of the inputs and assumptions before we start making any changes or API calls:
#-------------------------------------------------------------------------------

visibility="${visibility,,}"

[[ -s "$ci_yaml" ]]                                      || error "The specified path '${repo_path}' is not a valid project/repository root (missing .github/workflows/CI.yaml). Please specify a valid path to the root of the project/repository using '--path <path>' or use 'dotnet new vm2pkg <name>' to create a valid directory."
[[ -z $repo_name || $repo_name =~ $repo_name_regex ]]    || error "Could not determine repository name from the specified path '${repo_path}' or the name is invalid. Please specify a valid path to the root of the project/repository using '--path <path>'."
[[ -z $repo_owner || $repo_owner =~ $repo_owner_regex ]] || error "Could not determine repository owner from the specified path '${repo_path}', or from the environment variable ORGANIZATION, or the owner name is invalid. Please specify a valid owner of the project/repository using '--owner <owner>' or set the ORGANIZATION environment variable."
validate_repo_branch "$branch" &> "$_ignore"             || error "Invalid branch name '${branch}'. Please specify a valid branch name using '--branch <branch>'."
is_in "$visibility" "public" "private"                   || error "Invalid visibility '${visibility}'. Valid options are 'public', 'private', or 'internal'. Please specify a valid visibility using '--visibility <public|private|internal>'."

exit_if_has_errors

resolve_github_actions_app_id
list_required_checks

# ------------------------------------------------------------------
# Audit
# ------------------------------------------------------------------

if $audit && ! $interactive_secrets && ! $interactive_vars && has_github_remote repo_state; then
    initialize_jq_queries
    initialize_gh_paths
    initialize_main_protection_rs_id
    audit_repo
    exit 0
fi

# ------------------------------------------------------------------
# Initialize and configure the repository
# ------------------------------------------------------------------

# list of undos to perform in case of failure or when the script finishes - e.g. to delete the created repository, or undo any changes to the local repository. The undos must be executed in a LIFO order.
declare -a undos=()

function undo_changes()
{
    (( ${#undos[@]} == 0 )) && return 0

    echo "To undo the changes above, you can run the following commands:"
    for (( i=${#undos[@]}-1; i>=0; i-- )); do
        echo "    ${undos[i]}"
    done
    echo "and then run the script again."
}

trap undo_changes EXIT

if ! has_local_repo repo_state; then

    # -------------------------------------------------------------------
    # We need to initialize the local repository.
    # -------------------------------------------------------------------
    info "Initializing local git repository in '$repo_path'..."

    [[ -n "$branch" ]] ||
        branch=$(enter_value "Default branch name" "$default_branch" false validate_branch_name)

    if execute git -C "$repo_path" init >"$_ignore"; then
        undos+=("rm -rf '$repo_path/.git'")
    fi

    info "  ...creating and checking out the default branch '${branch}';"
    execute git -C "$repo_path" checkout -b "${branch}" >"$_ignore" 2>&1            && trace "'${branch}' branch checked out"

    info "  ...staging and committing existing files in '$repo_path';"
    execute git -C "$repo_path" add . >"$_ignore"                                   && trace "Staged all existing files in '$repo_path' for commit."
    if ! git -C "$repo_path" diff --cached --quiet; then
        execute git -C "$repo_path" commit -m "chore: initial scaffold" >"$_ignore" && trace "Committed staged files to '$repo_path'."
    fi

    info "...initialized a new git repository in '$repo_path' in the default branch '${branch}'."
    repo_state["$key_root"]="$repo_path"
fi

if ! has_remote_repo repo_state; then

    #----------------------------------------------------------------------
    # Create and link remote GitHub repository
    #----------------------------------------------------------------------
    info "Creating GitHub repository..."

    [[ -n $repo_name ]] || repo_name=$(enter_value "GitHub Repository name" "$suggest_repo_name" false validate_repo_name)
    repo="$repo_owner/$repo_name"
    repo=${repo#/} # remove leading slash if repo_owner is empty

    create_repo_params=(
        "$repo"
        "--${visibility}"
        "--source" "$repo_path"
        "--remote" "origin"
        "--disable-wiki"
    )

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

    info "  ...creating repository '$repo' with $visibility visibility and default branch '$branch'. Description: '$description'. parameters;"
    execute_with_retry 3 2 true gh repo create "${create_repo_params[@]}" >"$_ignore"
    undos+=("gh repo delete '$repo' --yes")

    info "  ...setting the remote origin URL to '$repo_url';"
    execute git -C "$repo_path" remote set-url origin "${repo_url}" >"$_ignore"
    undos+=("git -C '$repo_path' remote remove origin")

    info "  ...pushing the default branch '${branch}' to GitHub;"
    execute_with_retry 3 2 true git -C "$repo_path" push -u origin "${branch}"
    undos+=("git -C '$repo_path' push -u origin --delete '${branch}'")

    info "...GitHub repository '$repo' created and linked to the local repository in '$repo_path'."

    # Checks: get the repo state again that will have more real git and github information in it.
    get_repo_state "$repo_path" repo_state; rc=$?
    dump_repo_state repo_state

    if [[ $rc -ne 0 ]]; then
        error "Failed to get repository state after creation. The repository may have been created successfully, but the script cannot continue with configuration. Please check the repository at $repo_path"
        exit 1
    fi

    repo_url="${repo_state[$key_url]}"
    repo_id="${repo_state[$key_repo_id]}"

    [[ -n "$repo_url" && -n "$repo_id" ]] ||
        usage false "The repository does not appear to be initialized and/or linked to the remote. Run the script again without the switch --configure-only or troubleshoot the problem."

    branch="${repo_state[$key_default_branch]}"
    main_protection_rs_name="${main_protection_rs_name:-${branch} protection}"

    [[ -n "$repo_url"  ]] &&
    info "Repository URL                 => $repo_url"
    [[ -n "$repo_id"   ]] &&
    info "Repository Id                  => $repo_id"
fi

# ----------------------------------------------------------------------------
# Configure the remote repository on GitHub
# ----------------------------------------------------------------------------

initialize_gh_paths
initialize_jq_queries
initialize_main_protection_rs_id || true

configure_default_repo_settings
configure_actions_permissions
configure_branch_protection
configure_variables
configure_secrets
echo ""
audit_repo
if [[ ${#undos[@]} -gt 0 ]]; then
    echo ""
    undo_changes | info
fi
