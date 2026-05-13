#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
{
    source "$lib_dir/core.sh"
    source "$lib_dir/_sanitize.sh"
    source "$lib_dir/_git_vm2.sh"
}

# defaults
declare -xr default_owner="vmelamed"
declare -xr default_visibility="public"
declare -xr default_branch="main"
declare -xr default_interactive=false
declare -xr default_configure_local=true
declare -xr default_audit=false
declare -rx default_sot # AddNewPackage

# start with default input
declare -x repo_path=""
declare -x visibility=${default_visibility}
declare -x branch=${default_branch}
declare -x interactive_vars=${default_interactive}
declare -x interactive_secrets=${default_interactive}
declare -x configure_local=${default_configure_local}
declare -x audit=${default_audit}
declare -x main_protection_rs_name=""
declare -xi main_protection_rs_id=0
declare -x description=""
declare -x use_ssh=true
declare -x use_https=false
declare -x repo_owner=${ORGANIZATION:-$default_owner}
declare -rx sot=$default_sot

declare -x vm2_repos=""
declare -x repo_name=""
declare -x repo=""
declare -x repo_url=""
declare -x repo_id=""

declare -x path_vars
declare -x path_repo
declare -x path_permissions
declare -x path_actions_secrets
declare -x path_vars
declare -x path_rulesets
declare -x path_main_protection_ruleset

declare -xa required_checks=()
declare -xi github_actions_app_id=0

declare -x vm2=""

source "${script_dir}/repo-setup.args.sh"
source "${script_dir}/repo-setup.usage.sh"
source "${script_dir}/repo-setup.defaults.sh"
source "${script_dir}/repo-setup.functions.sh"
source "${script_dir}/repo-setup.audit.sh"

get_arguments "$@"

repo_path="${repo_path:-$(pwd)}"

#-------------------------------------------------------------------------------
# Check the prerequisites
#-------------------------------------------------------------------------------

command -v jq &> "$_ignore"                                 || error "'jq' is not installed. Please install it first."
command -v yq &> "$_ignore"                                 || error "'yq' is not installed. Please install it first."
[[ $(yq --version) =~ https://github\.com/mikefarah/yq/ ]]  || error 'This script requires "yq" by Mike Farah: "wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/.local/bin/yq4; chmod +x ~/.local/bin/yq4"'
command -v gh &> "$_ignore"                                 || error "'gh' is not installed. Please install it first."
gh auth status &> "$_ignore"                                || error "'gh' is not authenticated. Run 'gh auth login' first."

exit_if_has_errors

declare -xi rc="$success"

#===============================
# Find and validate vm2_repos:
#===============================
vm2_repos=$(resolve_vm2_repos "$vm2_repos") ||
    usage "$rc" "Could not find the parent directory for the vm2 repositories." \
                "Please, set the VM2_REPOS environment variable or provide the path as an argument with '--vm2-repos' option."

trace "All vm2 repositories are expected to be in '$vm2_repos'"
init_default_local_git_settings "$vm2_repos"

sot_path=$(get_vm2_sot_path "$vm2_repos" "$sot")

# make sure we are seeing the templates and vm2.DevOps properly through vm2_repos
[[ -d "$sot_path" && -d "$vm2_repos/$vm2_devops_repo_name" ]] ||
    usage "$err_not_found" "The GitHub Actions workflow templates directory .github and/or the '$vm2_devops_repo_name' directory is missing in '$vm2_repos', Please clone the repositories into '$vm2_repos'."

rc="$success"
validate_repo_root "$vm2_repos" "$vm2_repos/$vm2_devops_repo_name" "main" || rc=$?
(( rc == err_behind_latest_stable_tag )) &&
    error "The repository in '$vm2_repos/$vm2_devops_repo_name' is behind the latest stable tag. Please update it to the latest commit on the main branch."

rc="$success"
validate_repo_root "$vm2_repos" "$vm2_repos/$vm2_sot_repo_name" "main" || rc=$?
(( rc == err_behind_latest_stable_tag )) &&
    error "The repository in '$sot_path' is behind the latest stable tag. Please update it to the latest commit on the main branch."

declare -x _ci_yaml

_ci_yaml="$vm2_repos/$vm2_devops_repo_name/.github/workflows/_ci.yaml"
[[ -s "$_ci_yaml" ]] || error "Could not find _ci.yaml GitHub Actions reusable workflow file in ${vm2_repos}."

declare -xr _ci_yaml

exit_if_has_errors

#-------------------------------------------------------------------------------
# Resolve and validate repo_path:
#-------------------------------------------------------------------------------
rc="$success"
output=$(resolve_repo_root "$vm2_repos" "$repo_path") || rc=$?

is_in "$rc" "$success" "$err_dir_with_ci" ||
    usage "$err_argument_value" "Could not resolve the '$repo_path' within '$vm2_repos' to a Git initialized or not working tree root with configured CI. $(error_message "$rc")"

reset_errors

{ IFS= read -r repo_path; IFS= read -r _; } <<< "$output"

(( rc == err_dir_with_ci )) &&
    info "There is '$repo_path/.github/workflows/CI.yaml'. Will initialize a new repository in '$repo_path'."

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
            usage "$err_repo_with_no_ci" "The git-detected repository path '$repo_path' is missing .github/workflows/CI.yaml. Please specify a valid path to the root of the project/repository using '--path <path>' or use 'dotnet new vm2.NewPkg' to create a valid directory structure."
        trace "repo_path='$repo_path' from git-detected repository root"
    fi
    info "Git repository path            => $repo_path"

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

        info "GitHub repository              => $repo"

        if has_github_remote repo_state; then
            repo_id="${repo_state[$key_repo_id]}"
            branch="${repo_state[$key_default_branch]}"
            main_protection_rs_name="${main_protection_rs_name:-${branch} protection}"

            info "GitHub repository Id           => $repo_id"
            info "GitHub default Branch          => $branch"
        fi

        info "GitHub repository URL          => $repo_url"
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
validate_branch_name "$branch" &> "$_ignore"             || error "Invalid branch name '${branch}'. Please specify a valid branch name using '--branch <branch>'."
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
    initialize_main_protection_rs_id || true
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
    local -i index
    for (( index=${#undos[@]}-1; index>=0; index-- )); do
        echo "    ${undos[index]}"
    done
    echo "and then run the script again."
}

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

    [[ -n $repo_name ]] || repo_name=$(enter_value "GitHub Repository name" "$suggest_repo_name" false validate_gh_repo_name)
    repo="$repo_owner/$repo_name"
    repo=${repo#/} # remove leading slash if repo_owner is empty

    create_repo_params=(
        "$repo"
        "--${visibility}"
        "--source" "$repo_path"
        "--remote" "origin"
        "--disable-wiki"
    )

    [[ -n "$description" ]] || description=$(enter_value "GitHub repository description (3-350 characters)" "$repo_name" _ validate_gh_repo_description)
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
    execute_gh_with_retry 3 2 true  repo create "${create_repo_params[@]}"
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
        error "Failed to get repository state after creation. The repository may have been created successfully, but the script cannot continue with configuration. Please check the repository at $repo_path."
        exit 1
    fi

    repo_url="${repo_state[$key_url]}"
    repo_id="${repo_state[$key_repo_id]}"

    [[ -n "$repo_url" && -n "$repo_id" ]] ||
        usage "$err_not_git_directory" "The repository does not appear to be initialized and/or linked to the remote."

    branch="${repo_state[$key_default_branch]}"
    main_protection_rs_name="${main_protection_rs_name:-${branch} protection}"

    [[ -n "$repo_url"  ]] &&
    info "Repository URL                 => $repo_url"
    [[ -n "$repo_id"   ]] &&
    info "Repository Id                  => $repo_id"
fi

if $configure_local; then
    # ----------------------------------------------------------------------------
    # Configure local git settings
    # ----------------------------------------------------------------------------

    info "Configuring local git settings..."

    declare key value
    for key in "${default_local_git_settings_order[@]}"; do
        value="${default_local_git_settings[$key]}"
        execute git -C "$repo_path" config --local "$key" "$value"
        trace "$key set to '$value'."
    done

    info "...local git settings configured."
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
configure_secrets "actions"
configure_secrets "dependabot"
echo ""
audit_repo
if [[ ${#undos[@]} -gt 0 ]]; then
    echo ""
    undo_changes | info
fi
