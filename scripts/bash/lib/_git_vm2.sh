# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines functions for working with Git repositories in the vm2 environment.
# It includes functions for resolving the vm2_repos directory and checking the state of Git repositories.
# It is assumed that the vm2 repositories are cloned under a single parent directory, that can be specified by
# 1. a command line argument, or
# 2. the environment variable $VM2_REPOS or
# 3. the parent directory of the repo root of this script:
#    1) if this script is in $vm2_repos/vm2.DevOps/scripts/bash/lib
#    2) the repo root should be $vm2_repos/vm2.DevOps
#    3) the parent directory of the repo root should be $vm2_repos
# 4. the hard-coded default value $HOME/repos/vm2
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_GIT_VM2_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_GIT_VM2_SH_LOADED=1

declare -rx script_dir
declare -rx lib_dir
declare -x _ignore

declare -rxi success
declare -rxi failure

declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_found
declare -rxi err_not_file
declare -rxi err_not_directory
declare -rxi err_not_git_root
declare -rxi err_behind_latest_stable_tag
declare -rxi err_invalid_repo
declare -rxi err_invalid_repo
declare -rxi err_found_too_many
declare -rxi err_repo_with_no_ci
declare -rxi err_dir_with_ci
declare -rxi err_dir_with_no_ci
declare -rxi err_not_git_directory

declare -xr vm2_devops_repo_name
declare -xr vm2_sot_repo_name

#-------------------------------------------------------------------------------
# Summary: Resolves the vm2_repos directory from
#   1) the parameter (usually command line argument --vm2-repos), or
#   2) the environment variable $VM2_REPOS, or
#   3) the parent directory of the repository root of this script.
# Parameters:
#   $1 - optional: the directory to use as vm2_repos
# Returns:
#   Exit codes:
#     $success - if the vm2_repos directory was successfully resolved
#     $err_not_found - if the vm2_repos directory could not be resolved from the provided parameter
#     $err_not_directory - if the parameter, or \$VM2_REPOS, or the default value $HOME/repos/vm2 are not valid directories
#     $err_not_git_directory - the found directory is not a parent to the git repositories vm2.DevOps and vm2.Templates
#     $err_invalid_arguments - if an invalid number of arguments was provided
# Environment variables:
#   VM2_REPOS - the parent directory where the vm2 repositories are expected to have been cloned to
# Usage:
#   resolve_vm2_repos [directory]
#-------------------------------------------------------------------------------
function resolve_vm2_repos()
{
    (( $# <= 1 )) || {
        error 3 "${FUNCNAME[0]}() takes at most 1 optional arguments ($# provided): the directory that is a parent to all vm2 repositories."
        return "$err_invalid_arguments"
    }

    # try to resolve vm2 from the
    #   1) argument (usually from a command line option --vm2-repos)
    #   2) environment variable $VM2_REPOS
    #   3) the lib/ directory
    # in this order of preference:
    local repos="${1:-${VM2_REPOS:-$(get_devops_parent)}}"

    [[ -n "$repos" && -d "$repos" ]] || {
         error 3 "The parent directory for the vm2 repositories cannot be resolved from the provided parameter, environment variable \$VM2_REPOS' or from the vm2.DevOps repo's parent. Please provide it as an argument or set it in the environment variable \$VM2_REPOS."
         return "$err_not_directory"
    }

    trace "vm2_repos='$repos' resolved  from" \
                "argument '\$1=${1:-}', or from " \
                "'\$VM2_REPOS=${VM2_REPOS:-}', or from "\
                "'\$devops_parent=$(get_devops_parent)'."

    # ensure $vm2_repos is an existing, absolute path:
    repos=$(realpath -e "$repos" 2> "$_ignore") || {
        error 3 "The resolved parent directory for the vm2 repositories '$repos' does not exist or is not a directory. Please, create it and clone the repositories into it or correct the parameter/environment variable."
        return "$err_not_directory"
    }

    # validate that it is the parent directory of the git repositories vm2.DevOps and vm2.Templates:
    [[ $repos == "$(dirname "$(root_working_tree "$repos/$vm2_devops_repo_name")")" ]] || {
        error 3 "The '$repos' is not the parent directory of the '$vm2_devops_repo_name' repository. Please, ensure that the vm2 repositories are cloned into this directory or correct the parameter/environment variable."
        return "$err_not_git_root"
    }

    [[ $repos == "$(dirname "$(root_working_tree "$repos/$vm2_sot_repo_name")")" ]] || {
        error 3 "The '$repos' is not the parent directory of the '$vm2_sot_repo_name' repository. Please, ensure that the vm2 repositories are cloned into this directory or correct the parameter/environment variable."
        return "$err_not_git_root"
    }

    echo "$repos"
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Validates that
#     1) the specified directory exists
#     2) it is a root of the working tree of the git repository
#     3) it has GitHub Actions workflows in the .github/workflows directory (unless it is the .github repository itself)
#     4) it is on the specified branch (or the currently checked out branch if not specified)
#     5) it is at or ahead of the latest stable tag of the specified branch.
# Parameters:
#   $1: $repo_name: repository name or absolute, or relative path to the repository, e.g. "vm2.MyRepo" or "./my_repos/vm2_packages/vm2.MyRepo".
#   $2: $vm2_repos: the parent directory of all vm2 repositories where the repository $1 can be located as well, if it is specified by name only.
#                   (optional, default: $VM2_REPOS or "$HOME/repos/vm2"). You can use also `$(resolve_vm2_repos)` to determine the parent directory of all vm2 repositories.
#   $3: $branch: the branch to check against the latest stable tag (optional, default: the currently checked out branch)
# Returns:
#   stdout: the absoluter path to the working tree root of the resolved repository
#   Exit code:
#     $success - if the repository directory exists and meets the above criteria, or
#     $err_invalid_arguments - invalid number of arguments
#     $err_not_found - could not find the repository directory path from $repo_name and $vm2_repos parameters
#     $err_not_directory - the repository directory does not exist
#     $err_not_git_root - the directory exists but it is not a git repository
#     $err_repo_with_no_ci - the repository does not have GitHub Actions workflows in '$repo_path/.github/workflows'
#     $err_behind_latest_stable_tag - the directory exists and it is a git repository, but the repository is behind the latest stable tag of the specified branch
# Dependencies:
#   git CLI (functions root_working_tree, is_on_or_after_latest_stable_tag)
# Usage:
#   validate_repo_root "vm2.Glob" "$vm2_repos"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function validate_repo_root()
{
    (( $# >= 1 && $# <= 3 )) || {
        error 3 "${FUNCNAME[0]}() requires 1 to 3 arguments ($# provided): the name of a repository, the optionally the directory where the repository is expected to be located " \
                "(e.g. \$VM2_REPOS or \$(get_devops_parent), and the branch to check against the latest stable tag (optional, default: the currently checked out branch)."
        return "$err_invalid_arguments"
    }

    local repo=$1
    local repos
    repos="$(resolve_vm2_repos "$2")" || return $?
    local branch="${3}"
    local r
    local -i rc

    # try to resolve the repository path from the parameter alone (i.e., the current working directory or the absolute path provided as the first argument)
    r=$(realpath -e "$repo" 2> "$_ignore") ||
    # try to resolve repo_path relative to $vm2_repos
    r=$(realpath -e "$repos/${repo#/}" 2> "$_ignore") || {
       error 3 "Could not find the repository directory for '$repo' neither in the current working directory, nor in '$repos'."
       return "$err_not_found"
    }
    local path=$r

    trace "repo_path='$path' from parameter, \$(pwd), or vm2_repos with realpath"

    # 1) the specified directory exists
    [[ -d "${path}" ]] || {
        error 3 "The '${repo}' git repository directory is not found under ${repos}."
        return "$err_not_directory"
    }

    # 2) it is a root of the working directory of the git repository
    r=$(root_working_tree "$path" 2> "$_ignore") || {
        rc=$?
        error 3 "The '${repo}' repository at '$path' is not a git repository. $(error_message "$rc")."
        return "$err_not_git_directory"
    }
    [[ "$path" == "$r" ]] || {
        error 3 "The ${repo} repository at '$path' is not the root of the git repository working tree."
        return "$err_not_git_root"
    }

    # 3) it has GitHub Actions workflows in the .github/workflows directory (unless it is the .github repository itself)
    if [[ ${path##*/} != ".github" && ! -d "$path/.github/workflows" ]]; then
        error 3 "The '${repo}' repository does not have GitHub Actions workflows in '$path/.github/workflows'."
        return "$err_repo_with_no_ci"
    fi

    # 4) it is on the specified branch (or the currently checked out branch if not specified)
    if [[ -z "$branch" ]]; then
        branch=$(git -C "$path" branch --show-current 2>"$_ignore")
    else
        [[ "$branch" == $(git -C "$path" branch --show-current 2>"$_ignore") ]] || {
            error 3 "The '${repo}' repository at '$path' is not on the expected branch '$branch'."
            return "$err_invalid_branch"
        }
    fi

    # 5) it is at or ahead of the latest stable tag of the specified branch.
    ensure_fresh_git_state "$path" "$branch" || return $?
    is_on_or_after_latest_stable_tag "$path" || return $?

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Internal, used by resolve_repo_root. Searches for a directory with the given name under a specified parent directory.
# Parameters:
#   1 - $look_for - directory name or relative path to search for
#   2 - $start_from - parent directory under which to search for the specified directory
# Returns:
#   stdout: the absolute path of the found directory
#   Exit codes:
#     $success - exactly one matching directory with a Git repository is found
#     $err_not_git_directory - exactly one matching directory is found, but it is not a Git repository
#     $err_found_too_many - multiple matching directories are found
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

    return "$err_found_too_many"
}

#-------------------------------------------------------------------------------
# Summary: Finds the root directory of a Git repository working tree by searching for a directory with the given name under a
# specified parent directory. It may or may not be under \$VM2_REPOS. The directory may or may not have a Git repository.
# If it is not a Git repository, the root of the repository will be the nearest parent directory containing a '.github/workflows'
# directory or the found directory itself if no such parent directory is found.
# Parameters:
#   1 - $vm2_repos - parent directory under which to search for the specified directory (mandatory, resolved vm2_repos)
#   2 - $dir_path - directory name or relative path to search for (optional, default: the current directory)
# Returns:
#   stdout: 2 values:
#     1) the absolute path of the root of the Git repository containing the found directory
#     2) the absolute path of the found directory
#     If the found directory is not a Git repository, the first value will be the directory itself - equal to the second value.
#   Exit code:
#     $success - exactly one matching directory with a Git repository is found
#     $err_repo_with_no_ci - exactly one matching directory with a Git repository is found, but it has no CI configuration
#     $err_not_git_directory - exactly one matching directory with CI configuration is found, but it is not a Git repository
#     $err_dir_with_no_ci - exactly one matching directory is found, but it is not a Git repository and has no CI configuration
#     $err_found_too_many - multiple matching directories are found
#     $err_not_found - no matching directory was found
#           $err_not_found and $err_found_too_many are the fatal errors
# Dependencies: git, find
# Usage: resolve_repo_root <directory-name> [repos-parent]
# Example:
#       output=$(resolve_repo_root "$repo_root" "$vm2_repos")
#       rc=$?
#       (( rc == success || rc == err_repo_with_no_ci || rc == err_not_git_directory || rc == err_dir_with_no_ci )) || exit "$rc"
#       { read -r root; read -r resolved_dir; } <<< "$output"
#-------------------------------------------------------------------------------
function resolve_repo_root()
{
    (( $# == 1 || $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires 1 or 2 arguments ($# provided): " \
                "  1) the parent directory under which to search for the repository (resolved vm2_repos)" \
                "  2) the directory name of the repository (optional, default - the current directory)."
        return "$err_invalid_arguments"
    }

    local repos
    local dir_path
    
    repos=$1
    dir_path="${2:-"$(pwd)"}"

    local repo_dir=""
    local dir=""
    local repo_root=""
    local d
    local -i rc

    # find a directory with the same sub-path under $vm2_repos and check if it is a git work tree root (if root_only is true)
    trace "Searching for '$dir_path' under '\$vm2_repos=$repos'..."
    d=$(search_repo_dir "$dir_path" "$repos")
    rc=$?
    if (( rc == err_not_found )); then
        # we didn't find it under vm2_repos, let's search under $HOME - it will take a lot longer...
        trace "Searching for '$dir_path' under '\$HOME=$HOME'..."
        d=$(search_repo_dir "$dir_path" "$HOME")
        rc=$?
    fi

    # if rc is one of the fatal errors from the above searches - return
    is_in "$rc" "$err_not_found" "$err_found_too_many" && return "$rc"

    if (( rc == success )); then
        # we found repo directory, find the root of the repository and check if it has CI configuration
        repo_dir=$d
        repo_root=$(root_working_tree "$repo_dir") || return "$err_invalid_repo"
        [[ -d "$repo_root/.github/workflows" ]] || rc="$err_repo_with_no_ci"
    elif (( rc == err_not_git_directory )); then
        # the directory exists but is not a git repository
        dir=$d
        # walk the path up until we find a CI configuration
        rc="$err_dir_with_ci"
        while [[ ! -d "$d/.github/workflows" ]]; do
            d=$(dirname "$d")
            [[ $d == "$HOME" ]] && rc="$err_dir_with_no_ci" && break
        done

        case "$rc" in
            "$err_dir_with_ci" )
                # we found a CI configuration, return
                #   - the directory with the CI configuration as the repo root, but
                #   - the found directory as the resolved path and
                #   - with the error code indicating that it is not a git repository
                # the root can be initialized as a repository
                repo_dir="$dir"
                repo_root="$d"
                ;;
            "$err_dir_with_no_ci" )
                # we didn't find CI configuration, return
                #   - the found directory as the repo root (it may not be a repository, but at least it is the closest we got to the provided path)
                #   - the found directory also as the resolved path and
                #   - with the error code indicating that it's a directory with no CI configuration
                repo_dir="$dir"
                repo_root="$dir"
                ;;
            * )
                error "Unexpected error code '$rc' caught in ${FUNCNAME[0]}() function."
                return "$rc"
        esac
    else
        error "Unexpected error code '$rc' returned from search_repo_dir() function."
        return "$rc"
    fi

    echo "${repo_root}"
    echo "${repo_dir}"
    return "$rc"
}

#-------------------------------------------------------------------------------
# Summary: Resolves the path to the SoT shared content directory in the vm2_sot_repo_name repository, which is expected to be located
#          under $vm2_repos.
# Parameters:
#   1 - $vm2_repos: the parent directory where all the vm2 repositories are cloned (required)
#   2 - $sot: the SoT directory name relative to the vm2.Templates repository (required)
# Returns:
#   stdout: the absolute path to the SoT shared content directory,
#   Exit codes:
#     $success - if the SoT shared content directory is found at the expected location
#     $failure - if the specified parent directory for the vm2 repositories does not exist or is not a directory, or if the SoT shared content directory does not exist at the expected location under the specified parent directory for the vm2 repositories.
# Usage:
#   shared=$(get_vm2_sot_path [vm2_repos] [sot])
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154
function get_vm2_sot_path()
{
    [[ $# -eq 2 ]] || {
        error 3 "${FUNCNAME[0]} expects two arguments (provided $#):" \
                "  1) the parent directory of all vm2 repositories" \
                "  2) the SoT directory name relative to the vm2.Templates repository."
        return "$err_invalid_arguments"
    }

    local repos="${1}"

    [[ -n $repos ]] || {
        error "The parent directory for the vm2 repositories cannot be empty. Please provide it as an argument or set it in the environment variable \$VM2_REPOS."
        return "$err_argument_value"
    }
    [[ -d $repos ]] || {
        error "The specified parent directory for the vm2 repositories '$repos' does not exist or is not a directory. Please, create it and clone the repositories into it or correct the parameter/environment variable."
        return "$err_not_directory"
    }

    local source="${2}"

    [[ -n $source ]] || {
        error "The SoT directory name cannot be empty. Please provide it as an argument."
        return "$err_argument_value"
    }

    local vm2_sot="$repos/$vm2_sot_repo_name/templates/$source/content"

    [[ -d "$vm2_sot" ]] || {
        error "The SoT shared content directory is not found at the expected conventional location '$vm2_sot' under the specified parent directory for the vm2 repositories '$repos'. Please make sure it exists or correct the parameter/environment variable."
        return "$err_not_directory"
    }

    echo "$vm2_sot"
    return "$success"
}
