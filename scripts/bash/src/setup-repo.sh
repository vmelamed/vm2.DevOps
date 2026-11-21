#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -x script_name
declare -x script_dir
declare -x lib_dir

source "$lib_dir/core.sh"

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x err_repo_with_no_ci
declare -x err_not_git_directory
declare -x err_logic_error
declare -x err_root_not_repo_name
declare -x err_invalid_arguments
declare -x err_tool_error

# vm2 core lib constants
declare -x vm2_repositories
declare -x default_nuget_server
declare -x default_default_branch
#   repo state keys
declare -x key_git_root
declare -x key_git_url
declare -x key_owner
declare -x key_name
declare -x key_gh_full_name
declare -x key_gh_repo_id
declare -x key_default_branch

# vm2 core lib variables
declare -x _ignore

# this script variables
declare -x repo=''

declare -x nuget_server=$default_nuget_server
declare -x repo_url=''
declare -x repo_id=''

declare -x repo_name=''

declare -xi rc="$success"

#===============================================================================================
# Gather the CLI arguments:
#===============================================================================================
source "$script_dir/setup-repo.args.sh"
source "$script_dir/setup-repo.usage.sh"

get_arguments "$@"
# script arguments:
declare -x vm2_repos
declare -x repo_owner
declare -x repo_name
declare -x repo_path
declare -x default_branch
declare -x visibility
declare -x main_protection_rs_name
declare -x description
declare -x use_ssh
declare -x use_https
declare -x audit
declare -x interactive_vars
declare -x interactive_secrets
declare -x purge_vars
declare -x purge_secrets
declare -x configure_local

source "$script_dir/setup-repo.defaults.sh"
source "$script_dir/setup-repo.functions.sh"
source "$script_dir/setup-repo.audit.sh"

# script constants
declare -x default_local_git_settings
declare -x default_local_git_settings_order

trace "All vm2 repositories are expected to be in '$vm2_repos'"
trace "The path  of repository '$repo_name': '$repo_path'"

declare -A repo_state=()

get_repo_state "$repo_path" repo_state                                          || rc=$?
(( rc == success ))                                                             || usage "Failed to get the repository state for '$repo_path'." -ec "$rc"
dump_vars --quiet --header "Repository State 'repo_state':" repo_state

declare -x suggested_repo_name=''

if has_local_repo repo_state; then
    declare -A mismatches=()

    [[ "$repo_path" == "${repo_state[$key_git_root]}" ]]                        ||  {
                                                                                        warning "The repository path '$repo_path' is different from the repository root detected by git. Adjusting to the latter - '${repo_state[$key_git_root]}'."
                                                                                        repo_path=${repo_state[$key_git_root]}
                                                                                        mismatches["<repo-directory-path>"]=1
                                                                                    }
    [[ -s "$repo_path/.github/workflows/CI.yaml" ]]                             || usage "The git-detected repository path '$repo_path' is missing a sub-directory '.github/workflows/CI.yaml'." \
                                                                                         "Please specify a valid path to the root of the project/repository as a positional parameter or use 'dotnet new vm2.NewPkg' to create a valid directory structure." \
                                                                                         -ec "$err_repo_with_no_ci"
    trace "Setting repo_path='$repo_path' from git-detected repository root"

    # now we can freeze $repo_path
    readonly repo_path
    info "Git repository working tree root: '$repo_path'."

    if has_remote_repo repo_state; then
        repo_url="${repo_state[$key_git_url]}"
        [[ $repo_owner == "${repo_state[$key_owner]}" ]]                        ||  {
                                                                                        warning "The specified GitHub repository owner '$repo_owner' is different from the one recorded by Git. Adjusting to the latter - '${repo_state[$key_owner]}'."
                                                                                        repo_owner=${repo_state[$key_owner]}
                                                                                        mismatches["--owner <owner>"]=1
                                                                                    }
        [[ $repo_name == "${repo_state[$key_name]}" ]]                          ||  {
                                                                                        warning "The GitHub repository name derived from the repository path '$repo_name' is different from the one recorded by Git. Adjusting to the latter - ${repo_state[$key_name]}."
                                                                                        repo_name=${repo_state[$key_name]}
                                                                                        mismatches["<repo-directory-path>"]=1
                                                                                    }
        repo="$repo_owner/$repo_name"

        readonly repo_url
        readonly repo_owner
        readonly repo_name
        readonly repo

        if ! is_in "$repo_name" "${vm2_repositories[@]}"; then
            warning "The repository '$repo_name' is not in the list 'vm2_repositories' (see \$VM2_REPOS/vm2.DevOps/scripts/bash/lib/_constants.sh)."  \
                    "Any vm2 script that works on all vm2 repositories or uses the '--all-repositories' switch will ignore the '$repo_name' in their operations." \
                    "If it SHOULD be included, ensure that '$repo_name' is added to the 'vm2_repositories' list."
        fi

        info "GitHub repository owner          => $repo_owner"
        info "GitHub repository name           => $repo_name"
        info "GitHub repository full name      => $repo"

        if has_github_remote repo_state; then

            [[ $default_branch == "${repo_state[$key_default_branch]}" ]]       ||  {
                                                                                        warning "The specified GitHub repository' default branch '$default_branch' is different from the one recorded by Git. Adjusting to the latter - '${repo_state[$key_default_branch]}'."
                                                                                        default_branch=${repo_state[$key_default_branch]}
                                                                                        mismatches["--branch <branch>"]=1
                                                                                    }
            readonly default_branch

            main_protection_rs_name="${main_protection_rs_name:-"$default_branch protection"}"

            repo_id="${repo_state[$key_gh_repo_id]}"

            info "GitHub repository default Branch => $default_branch"
            info "GitHub repository Id             => $repo_id"
        fi

        info "GitHub repository URL            => $repo_url"

        if (( ${#mismatches[@]} > 0 )); then
            declare mismatched_arguments message

            IFS=', ' mismatched_arguments="${!mismatches[*]}"
            printf -v message "Do you want to continue with the adjusted arguments despite the mismatches with the arguments: %s?" "$mismatched_arguments"
            confirm "$message" "N"                                              || usage "Detected invalid arguments: $mismatched_arguments" -ec "$err_invalid_arguments"
        fi
    fi
fi

if ! has_local_repo repo_state || ! has_remote_repo repo_state; then
    suggested_repo_name=$(basename "$repo_path")
    trace "Will suggest '$suggested_repo_name' from basename repo_path as a repo name and repo description during repo creation if needed."
fi

readonly suggested_repo_name

has_github_remote repo_state && get_current_nuget_server

# Check the integrity of the default data
validate_defaults
resolve_github_app_ids
list_required_checks

if $audit; then
    #===============================================================================================
    # Requested audit
    #===============================================================================================

    has_github_remote repo_state                                                || error "The repository in '$repo_path' is not linked to a GitHub remote. Cannot perform audit." \
                                                                                         "Please ensure that the repository is properly initialized and linked to GitHub before running the script with '--audit'." \
                                                                                         -ec "$err_logic_error"
                                                                                exit_if_has_errors

    initialize_jq_queries
    initialize_gh_paths
    initialize_main_protection_rs_id || true

    audit_repo

    exit "$success"
fi

#===============================================================================================
# Initialize and configure the repository
#===============================================================================================

# list of undo statements to perform in case of failure or when the script finishes, e.g., to delete the created repository or to undo any changes to the local repository. The undos must be executed in a LIFO order.
declare -a undos=()

#-----------------------------------------------------------------------------------------------
# @description Prints the recorded `undos` array (commands to revert side effects performed by this run, e.g.
# deleting a newly created GitHub repository or removing a remote) in LIFO order, so the user can copy-paste them
# to manually roll back a failed or aborted run. No-op if nothing has been recorded yet.
#
# @exitcode success=0: Always.
# @stdout The list of undo commands in LIFO order, wrapped in explanatory text -- or nothing if `undos` is empty.
#-----------------------------------------------------------------------------------------------
function undo_changes()
{
    is_empty_array undos && return "$success"

    echo "To undo the changes above, you can run the following commands:"
    local -i _index
    for (( _index=${#undos[@]}-1; _index>=0; _index-- )); do
        echo "    ${undos[_index]}"
    done
    echo "and then run the script again."
}

if ! has_local_repo repo_state; then
    #===========================================================================
    # Initialize a local repository.
    #===========================================================================

    info "Initialize local git repository in '$repo_path' with initial branch '$default_branch':"

    execute --quiet git -C "$repo_path" init --initial-branch="$default_branch" || with_error rc "$err_tool_error" "Failed to initialize a new Git repository in '$repo_path' and to create an initial branch '$default_branch'."
    (( rc != success )) || undos+=("rm -rf '$repo_path/.git'")

    (( rc != success )) || info "  - Stage the existing files in '$repo_path'"
    (( rc != success )) || execute --quiet git -C "$repo_path" add .            || with_error rc "$err_tool_error" "Failed to stage the files in '$repo_path'."
    (( rc != success )) || trace "    Staged all existing files in '$repo_path' for commit."

    if (( rc == success )) && ! git -C "$repo_path" diff --cached --quiet; then
        info "  - Commit the existing files in '$repo_path'"
        execute --quiet git -C "$repo_path" commit -m "chore: initial scaffold" || with_error rc "$err_tool_error" "Failed to commit the staged files in '$repo_path' to branch '$default_branch'."
        (( rc != success )) || trace "    Committed staged files to '$repo_path'."
    fi

    # shellcheck disable=SC2015 # Info: Note that A && B || C is not if-then-else. C may run when A is true.
    is_dry_run &&
        info "A new git repository would have been initialized in '$repo_path' in the default branch '$default_branch'." ||
        info "Initialized a new git repository in '$repo_path' in the default branch '$default_branch'."
fi

if ! has_remote_repo repo_state; then
    #===========================================================================
    # Create and link a remote GitHub repository
    #===========================================================================

    # shellcheck disable=SC2015 # Info: Note that A && B || C is not if-then-else. C may run when A is true.
    info "Create GitHub repository:"

    confirm "Create the GitHub repository '$suggested_repo_name'?" "Y"          ||  {
                                                                                        warning "Please rename the repository root directory to match the name of the desired GitHub repository."
                                                                                        exit "$err_root_not_repo_name"
                                                                                    }

    repo_name="${repo_name:-$suggested_repo_name}"
    repo="$repo_owner/$repo_name"
    repo=${repo#/} # remove leading slash if repo_owner is empty

    create_repo_params=(
        "$repo"
        "--$visibility"
        "--source" "$repo_path"
        "--remote" "origin"
        "--disable-wiki"
    )

    [[ -n "$description" ]] || enter_value "GitHub repository description (3-350 characters)" description "$repo_name" false validate_gh_repo_description
    [[ -n "$description" ]] && create_repo_params+=("--description" "$description")

    $use_ssh   && repo_url="git@github.com:$repo.git"
    $use_https && repo_url="https://github.com/$repo"

    info "  - Create the GitHub repository '$repo' with '$visibility' visibility, default branch '$default_branch', and description: '$description'"
    execute_with_retry --quiet --classify gh_failure \
        gh repo create "${create_repo_params[@]}"                               || with_error rc $? "Failed to create a GitHub repository '$repo'"
    (( rc != success )) || undos+=("gh repo delete '$repo' --yes")

    (( rc != success )) || info "  - Set the remote origin URL to '$repo_url'"
    (( rc != success )) || execute --quiet git -C "$repo_path" remote set-url origin "$repo_url" \
                                                                                || with_error rc "$err_tool_error" "Failed to set the remote origin URL to '$repo_url'"
    (( rc != success )) || undos+=("git -C '$repo_path' remote remove origin")

    (( rc != success )) || info "  - Push the default branch '$default_branch' to GitHub"
    (( rc != success )) || execute_with_retry --quiet \
                                git -C "$repo_path" push -u origin "$default_branch" \
                                                                                || with_error rc $? "Failed to push the default branch '$default_branch' to GitHub"
    (( rc != success )) || undos+=("git -C '$repo_path' push -u origin --delete '$default_branch'")

    # shellcheck disable=SC2015 # Info: Note that A && B || C is not if-then-else. C may run when A is true.
    (( rc != success )) || { is_dry_run &&
                                info "Would have created and linked GitHub repository '$repo' to the local repository in '$repo_path'." ||
                                info "GitHub repository '$repo' was created and linked to the local repository in '$repo_path'."; }

    # Checks: get the repo state again that will have more real git and github information in it.
    (( rc != success )) || get_repo_state "$repo_path" repo_state               || with_error rc $? "Failed to get repository state after creation. " \
                                                                                                    "The repository may have been created successfully, but the script cannot continue with configuration." \
                                                                                                    "Please check the repository at $repo_path."
    (( rc != success )) || dump_vars --quiet --header "Repository State 'repo_state':" repo_state

    ! has_errors                                                                || undo_changes
                                                                                exit_if_has_errors

    repo_url="${repo_state[$key_git_url]}"
    repo_id="${repo_state[$key_gh_repo_id]}"
    default_branch="${repo_state[$key_default_branch]}"
    main_protection_rs_name="${main_protection_rs_name:-$default_branch protection}"

    info "Repository URL                 => $repo_url"
    info "Repository Id                  => $repo_id"
fi

if $configure_local; then
    info "Configure local git settings."

    declare _key value
    for _key in "${default_local_git_settings_order[@]}"; do
        value="${default_local_git_settings[$_key]}"
        execute git -C "$repo_path" config --local "$_key" "$value"             || with_error rc $? "Failed to configure the local Git repository with '$_key' => '$value'"
        (( rc != success )) || trace "  $_key => '$value'."
    done

    # shellcheck disable=SC2015 # Info: Note that A && B || C is not if-then-else. C may run when A is true.
    is_dry_run &&
        info "Would have configured the local Git settings."
        info "The local Git settings were configured."
    rc=$success

    if [[ -f "$repo_path/.gitmodules" ]]; then
        info "Initialize Git submodules."
        execute git -C "$repo_path" submodule update --init --recursive         || with_error rc $? "Failed to initialize the Git submodules"
        # shellcheck disable=SC2015 # Info: Note that A && B || C is not if-then-else. C may run when A is true.
        (( rc != success )) || { is_dry_run &&
                                    info "Would have initialized the Git submodules." ||
                                    info "The Git submodules were initialized."; }
    fi
    rc=$success
fi

#===============================================================================================
# Configure the remote repository on GitHub
#===============================================================================================

initialize_jq_queries
initialize_gh_paths
initialize_main_protection_rs_id
rc=$?
# continue on success or failure (e.g. not found), otherwise exit (e.g. not authorized)
(( rc == success || rc == failure ))                                            || exit_if_has_errors

configure_default_repo_settings
configure_actions_permissions
configure_branch_protection
# configure variables before secrets, so that we know the NuGet server in use!
configure_variables "actions"
trace "NuGet server is: $nuget_server"
# configure secrets
configure_secrets "actions"
configure_secrets "dependabot"

echo ""

audit_repo

if [[ ${#undos[@]} -gt 0 ]]; then
    echo ""
    undo_changes | info
fi
