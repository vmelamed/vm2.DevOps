# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_GIT_VM2_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_GIT_VM2_SH_LOADED=1

declare -x script_dir
declare -x _ignore

declare -rxi success
declare -rxi failure

declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_found
declare -rxi err_not_file
declare -rxi err_not_directory
declare -rxi err_not_git_repository
declare -rxi err_behind_latest_stable_tag
declare -rxi err_invalid_repo
declare -rxi err_invalid_repo
declare -rxi err_found_more_than_one
declare -rxi err_repo_has_no_ci
declare -rxi err_dir_has_no_ci
declare -rxi err_not_git_directory

declare -xr default_vm2_repos="$HOME/repos/vm2"

#-------------------------------------------------------------------------------
# Summary: Resolves the vm2_repos directory from the environment variable $VM2_REPOS,
#   the default value $HOME/repos/vm2, or the command line argument.
# Parameters:
#   $1 - optional: the directory to use as vm2_repos
# Returns:
#   Exit codes:
#     $success - if the vm2_repos directory was successfully resolved
#     $err_not_found - if the vm2_repos directory could not be resolved from the provided parameter
#     $err_not_directory - if the parameter, or \$VM2_REPOS, or the default value $HOME/repos/vm2 are not valid directories
#     $err_invalid_arguments - if an invalid number of arguments was provided
# Environment variables:
#   VM2_REPOS - the parent directory where the vm2 repositories are expected to have been cloned to
#   default_vm2_repos - the default value for vm2_repos if VM2_REPOS is not set
# Usage:
#   resolve_vm2_repos [directory]
#-------------------------------------------------------------------------------
function resolve_vm2_repos()
{
    (( $# == 0 || $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires 1 or no arguments ($# provided): the directory to use as a parent to all vm2 repositories."
        return "$err_invalid_arguments"
    }

    # try to resolve vm2 from the
    #   1) argument (usually from the command line option --vm2-repos)
    #   2) environment variable $VM2_REPOS
    #   3) $HOME/repos/vm2
    local vm2_repos="${1:-${VM2_REPOS:-$default_vm2_repos}}"

    if [[ -n "$vm2_repos" && -d "$vm2_repos" ]]; then
        # so far so good - ensure $vm2_repos is an absolute path.
        vm2_repos=$(realpath -e "$vm2_repos" 2> "$_ignore")
        trace "vm2_repos='$vm2_repos' resolved from argument '\$1=${1:-}', or from env.var '\$VM2_REPOS=${VM2_REPOS:-}', or from the default value '\$default_vm2_repos=$default_vm2_repos'."
        echo "$vm2_repos"
        return "$success"
    fi

    # if the argument $1 is provided but is not a directory, return an error - no heuristics in this case
    (( $# == 1 )) && {
        error 3 "The argument '$1' is not a directory."
        return "$err_not_directory"
    }

    # continue with the heuristic search for the vm2 directory:
    # 1) try from the current working directory:
    local r

    if r=$(root_working_tree) && vm2_repos=$(dirname "$r" 2> "$_ignore"); then
        trace "vm2_repos='$vm2_repos' resolved from the current working directory."
        echo "$vm2_repos"
        return "$success"
    fi

    # 2) try from the calling script's directory, e.g. ~/repos/vm2/vm2.DevOps/scripts/bash/diff-common.sh:
    if r=$(root_working_tree "$script_dir") && vm2_repos=$(dirname "$r" 2> "$_ignore"); then
        trace "vm2_repos='$vm2_repos' resolved from the script directory."
        echo "$vm2_repos"
        return "$success"
    fi

    error "Could not resolve the vm2_repos directory from:" \
          "- the argument '\$1=${1:-}'" \
          "- the env.var '\$VM2_REPOS=${VM2_REPOS:-}'" \
          "- the default value '\$default_vm2_repos=$default_vm2_repos'" \
          "- the current working directory $(pwd)" \
          "- the script directory '$script_dir'"
    return "$err_not_found"
}

#-------------------------------------------------------------------------------
# Summary: Validates that
#     1) the specified directory exists
#     2) it is a git repository
#     3) it is not one of the special directories '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github' (unless the $3 is true)
#     4) it is at or ahead of the latest stable tag. Use 'ensure_fresh_git_state' top ensure fresh data of in the local repository.
# Parameters:
#   $1: $repo_name: repository name (e.g. "vm2.DevOps")
#   $2: $vm2_repos: the parent directory of all vm2 repositories where the repository is expected to be located as well.
#                   (e.g. $VM2_REPOS or "$HOME/repos/vm2"). Use `$(resolve_vm2_repos)` to determine the parent directory of all vm2 repositories.
#   $3: $validate_special_dirs: optional boolean flag indicating whether to validate the special directories '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github' (default: false)
# Returns:
#   stdout: the resolved repository absolute path if found
#   Exit code:
#     success - if the repository directory exists and meets the above criteria, or
#     err_not_found - could not find the repository directory in the current working directory, or in the specified parent directory, or under $VM2_REPOS
#     err_invalid_repo - if it is either '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github'
#     err_not_git_repository - found a directory that is not a git repository
#     err_behind_latest_stable_tag - if the repository is behind the latest stable tag
#     err_invalid_arguments - invalid number of arguments
# Dependencies:
#   git CLI (functions root_working_tree, is_on_or_after_latest_stable_tag)
# Usage:
#   validate_repo "vm2.Glob" "$vm2_repos"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function validate_repo()
{
    (( $# == 2 || $# == 3 )) || {
        error 3 "${FUNCNAME[0]}() requires 2 or 3 arguments ($# provided): the name of a repository, the directory where the repository is expected to be located " \
                "(e.g. $VM2_REPOS or $default_vm2_repos), and an optional boolean flag indicating whether to allow validation of a special directory 'vm2.DevOps' or '.github' (default: false)."
        return "$err_invalid_arguments"
    }
    (( $# == 3 )) && is_boolean "$3" || {
        error 3 "The third argument to ${FUNCNAME[0]}() must be a boolean (true or false)."
        return "$err_invalid_arguments"
    }

    local repo_name=$1
    local vm2_repos=$2
    local validate_special_dir=${3:-false}
    local r

    # try to resolve the repository path from the parameter alone (i.e., the current working directory or the absolute path provided as the first argument)
    r=$(realpath -e "$repo_name" 2> "$_ignore") ||
    # try to resolve repo_path relative to $repos
    r=$(realpath -e "$vm2_repos/${repo_name#/}" 2> "$_ignore") || {
       error 3 "Could not find the repository directory for '$repo_name' neither in the current working directory, nor in '$vm2_repos'."
       return "$err_not_found"
    }
    repo_path=$r

    if $validate_special_dir; then
        is_in "$repo_path" "${vm2_repos}/vm2.DevOps" "${vm2_repos}/.github" || {
            error 3 "Only the special repository directories '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github' can be validated with the allow_special_dirs flag set to true."
            return "$err_invalid_repo"
        }
    else
        ! is_in "$repo_path" "${vm2_repos}/vm2.DevOps" "${vm2_repos}/.github" || {
            error 3 "The repository directory cannot be '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github'."
            return "$err_invalid_repo"
        }
    fi

    trace "repo_path='$repo_path' from parameter, \$(pwd), or vm2_repos with realpath"

    if [[ ! -d "${repo_path}" ]]; then
        error 3 "The '${repo_name}' git repository directory is not found under ${vm2_repos}."
        return "$err_not_directory"
    fi

    if [[ "$repo_path" != $(root_working_tree "$repo_path") ]]; then
        error 3 "The ${repo_name} repository at '$repo_path' is not a git repository directory."
        return "$err_not_git_repository"
    fi

    is_on_or_after_latest_stable_tag "$repo_path" || {
        error 3 "The '${repo_name}' repository is behind the latest stable tag. Please synchronize."
        return "$err_behind_latest_stable_tag"
    }

    if [[ $repo_path != "${vm2_repos}/.github" && ! -d "$repo_path/.github/workflows" ]]; then
        error 3 "The '${repo_name}' repository does not have GitHub Actions workflows in '$repo_path/.github/workflows'."
        return "$err_repo_has_no_ci"
    fi

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Searches for a directory with the given name under a specified parent directory.
# The directory may or may not have a Git repository.
# Parameters:
#   1 - $look_for - directory name or relative path to search for
#   2 - $start_from - parent directory under which to search for the specified directory
# Returns:
#   stdout: the absolute path of the found directory
#   Exit codes:
#     $success - exactly one matching directory with a Git repository is found
#     $err_not_git_directory - exactly one matching directory is found, but it is not a Git repository
#     $err_found_more_than_one - multiple matching directories are found
#     $err_not_found - no matching directory is found
# Dependencies: find
# Usage: dir=$(search_repo_dir <directory-name> <start-from>)
#-------------------------------------------------------------------------------
function search_repo_dir()
{
    local look_for=$1
    local start_from=$2

    local found_repo_dirs=0
    local found_dirs=0
    local repo_dir=""
    local dir=""

    local dir_rel_path
    # remove the start_from prefix and the following slash, so that the path is relative to the search root and can be concatenated with the search prefix '*/'
    dir_rel_path="${look_for#"$start_from"}"
    dir_rel_path="${dir_rel_path#/}"

    local d
    while IFS= read -r d; do

        if is_inside_work_tree "$d"; then
            # good candidate - inside a git repository
            repo_dir="$d"
            (( ++found_repo_dirs ))
        else
            # plain directory, it is not inside a git repository
            dir="$d"
            (( ++found_dirs ))
        fi

    done < <(find "$start_from" \
                  \( -name .git \
                  -o -name node_modules \
                  -o -name .cache \
                  -o -name .nuget \
                  -o -name .dotnet \
                  -o -name .local \
                  -o -name .npm \
                  -o -name .cargo \
                  -o -name .rustup \
                  -o -name __pycache__ \
                  -o -name bin \
                  -o -name obj \
                  -o -name TestResults \
                  -o -name BenchmarkDotNet.Artifacts \
                  \) -prune \
                  -o -type d -path "*/$dir_rel_path" -print 2>"$_ignore")

    (( found_repo_dirs + found_dirs == 0 ))                           && return "$err_not_found"
    (( found_repo_dirs == 1 ))                    && echo "$repo_dir" && return "$success"
    (( found_repo_dirs == 0 && found_dirs == 1 )) && echo "$dir"      && return "$err_not_git_directory"

    return "$err_found_more_than_one"
}

#-------------------------------------------------------------------------------
# Summary: Finds the root directory of a Git repository working tree by searching for a directory with the given name under a
# specified parent directory. The directory may or may not have a Git repository. It may or may not be under \$VM2_REPOS.
# Parameters:
#   1 - $dir_path - directory name or relative path to search for (optional, default: current directory)
#   2 - $vm2_repos - parent directory under which to search for the specified directory (optional, default: $VM2_REPOS or $HOME/repos/vm2)
# Returns:
#   stdout: 2 values:
#     - the absolute path of the root of the (possibly future) Git repository containing the found directory
#     - the absolute path of the found directory
#   Exit code:
#     $success - exactly one matching directory with a Git repository is found
#     $err_repo_has_no_ci - exactly one matching directory with a Git repository is found, but it has no CI configuration
#     $err_not_git_directory - exactly one matching directory is found, but it is not a Git repository
#     $err_dir_has_no_ci - exactly one matching directory is found, but it is not a Git repository and has no CI configuration
#     $err_found_more_than_one - multiple matching directories are found
#     $err_not_found - no matching directory is found
# Dependencies: git, find
# Usage: resolve_repo_root <directory-name> [repos-parent]
# Example:
#       output=$(resolve_repo_root "$repo_root" "$vm2_repos")
#       rc=$?
#       (( rc == success || rc == err_repo_has_no_ci || rc == err_not_git_directory || rc == err_dir_has_no_ci )) || exit "$rc"
#       { read -r root; read -r resolved_dir; } <<< "$output"
#-------------------------------------------------------------------------------
function resolve_repo_root()
{
    (( $# <= 2 )) || {
        error 3 "${FUNCNAME[0]}() requires no more than 2 arguments ($# provided): " \
                "  - the directory where the repository is located " \
                "  - the parent directory under which to search for the repository."
        return "$err_invalid_arguments"
    }

    local dir_path
    dir_path=$(realpath -e "${1:-"$(pwd)"}") || {
        error 3 "The directory '$1' does not exist."
        return "$err_not_directory"
    }

    local vm2_repos
    vm2_repos=$(realpath -e "${2:-${VM2_REPOS:-$default_vm2_repos}}") || {
        error 3 "The directory '$2' does not exist."
        return "$err_not_directory"
    }

    local root_parent=""
    local repo_dir=""
    local dir=""
    local root=""
    local d

    # find a directory with the same sub-path under $vm2_repos and check if it is a git work tree root (if root_only is true)
    trace "Searching for '$dir_path' under '\$vm2_repos=$vm2_repos'..."
    d=$(search_repo_dir "$dir_path" "$vm2_repos")
    rc=$?
    if (( rc == err_not_found )); then
        # we didn't find it under vm2_repos, let's search under $HOME - it will take a lot longer...
        trace "Searching for '$dir_path' under '\$HOME=$HOME'..."
        d=$(search_repo_dir "$dir_path" "$HOME")
        rc=$?
    fi
    (( rc != err_not_found && rc != err_found_more_than_one ))              || return "$rc"

    if (( rc == success )); then
        # we found one: get its root
        repo_dir=$d
        root=$(root_working_tree "$repo_dir")                               || return "$err_invalid_repo"
        root_parent=$(dirname "$root")
        [[ $root_parent == "$vm2_repos" ]]                                  || warning "The parent directory of the repository root '$root' is not '$vm2_repos'."
        d="${dir_path#"$root_parent"}"
        d="${d#/}"
        echo "${repo_dir}"
        echo "${root}"
        [[ -d "$root/.github/workflows" ]]                                  || return "$err_repo_has_no_ci"
    elif (( rc == err_not_git_directory )); then
        # the directory exists but is not a git repository
        dir=$d
        # walk the path up until we find the CI configuration
        while [[ ! -d "$d/.github/workflows" ]]; do
            d=$(dirname "$d")
            [[ $d == "$HOME" ]] && rc="$err_dir_has_no_ci" && break
        done

        (( rc == err_not_git_directory )) && {
            echo "${dir}"
            echo "${d}"
        } || {
            # err_dir_has_no_ci
            echo "${dir}"
            echo "${dir}" # the return code should tell them that this is probably not the true root
        }
    fi

    return "$rc"
}
