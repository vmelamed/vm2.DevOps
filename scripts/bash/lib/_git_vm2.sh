# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

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

    # $VM2_REPOS always overrides the default value $HOME/repos/vm2 (last resort!)
    local vm2_repos="${VM2_REPOS:-$default_vm2_repos}"

    # the parameter always overrides the environment variable $VM2_REPOS and the default value $HOME/repos/vm2 (last resort!)
    (( $# == 1 )) && vm2_repos="$1"

    # try to resolve vm2 from the
    #   1) argument (usually from the command line option --vm2-repos)
    #   2) environment variable $VM2_REPOS
    #   3) $HOME/repos/vm2
    if [[ -n "$vm2_repos" && -d "$vm2_repos" ]]; then
        # looks good so far - ensure $vm2_repos is an absolute path.
        vm2_repos=$(realpath -e "$vm2_repos" 2> "$_ignore")
        trace "vm2_repos='$vm2_repos' resolved from argument, or \$VM2_REPOS, or '$default_vm2_repos'."
        echo "$vm2_repos"
        return "$success"
    fi

    # if the first argument is provided but is not a directory, return an error - no heuristics in this case
    (( $# == 1 )) && {
        error 3 "The argument '$1' is not a directory."
        return "$err_not_directory"
    }

    # continue with the heuristic search for the vm2 directory:
    # 1) try from the current working directory:
    if vm2_repos=$(root_working_tree) && vm2_repos=$(dirname "$vm2_repos" 2> "$_ignore"); then
        trace "vm2_repos='$vm2_repos' resolved from the current working directory."
        echo "$vm2_repos"
        return "$success"
    fi

    # 2) try from the calling script's directory, e.g. ~/repos/vm2/vm2.DevOps/scripts/bash/diff-common.sh:
    if vm2_repos=$(root_working_tree "$script_dir") && vm2_repos=$(dirname "$vm2_repos" 2> "$_ignore"); then
        trace "vm2_repos='$vm2_repos' resolved from the script directory."
        echo "$vm2_repos"
        return "$success"
    fi

    error "Could not resolve the vm2_repos directory from \$VM2_REPOS, '$default_vm2_repos', the 'argument', the current working directory, or the script directory."
    return "$err_not_found"
}

#-------------------------------------------------------------------------------
# Summary: Validates that
#     1) the specified directory exists
#     2) it is a git repository
#     3) it is not one of the special directories '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github' (unless the $3 is true)
#     4) it is at or ahead of the latest stable tag.
# Parameters:
#   $1: repository name (e.g. "vm2.DevOps")
#   $2: parent directory of all vm2 repositories where the repository is expected to be located as well
#       (e.g. $VM2_REPOS or "$HOME/repos/vm2"). Use `resolve_vm2_repos` to determine the parent directory of all vm2 repositories.
#   $3: optional boolean flag indicating whether to allow the special directories '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github' (default: false)
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
        error 3 "${FUNCNAME[0]}() requires 2 or 3 arguments ($# provided): the name of a repository, the directory where the repository is expected to be located (e.g. $VM2_REPOS or $default_vm2_repos)," \
                " and an optional boolean flag indicating whether to allow the special directories '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github' (default: false)."
        return "$err_invalid_arguments"
    }

    local repo_name=$1
    local vm2_repos=$2
    local allow_special_dirs=${3:-false}
    local r

    # try to resolve the repository path from the parameter alone (i.e., the current working directory or the absolute path provided as the first argument)
    r=$(realpath -e "$repo_name" 2> "$_ignore") ||
    # try to resolve repo_path relative to vm2_repos
    r=$(realpath -e "$vm2_repos/${repo_name#/*}" 2> "$_ignore") || {
       error 3 "Could not find the repository directory for '$repo_name' neither in the current working directory, nor in '$vm2_repos'."
       return "$err_not_found"
    }

    repo_path=$r
    ! is_in "$repo_path" "${vm2_repos}/vm2.DevOps" "${vm2_repos}/.github" || "$allow_special_dirs" || {
        error 3 "The repository directory cannot be '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github'."
        return "$err_invalid_repo"
    }

    trace "repo_path='$repo_path' from parameter, \$(pwd), or vm2_repos with realpath"

    local dir="${vm2_repos:-.}/${repo_name}"

    if [[ ! -d "${dir}" ]]; then
        error 3 "The '${repo_name}' git repository directory is not found under ${vm2_repos}."
        return "$err_not_directory"
    fi

    if [[ "$dir" != $(root_working_tree "$dir") ]]; then
        error 3 "The ${repo_name} repository at '$dir' is not a git repository directory."
        return "$err_not_git_repository"
    fi

    is_on_or_after_latest_stable_tag "$dir" "$semverTagReleaseRegex" || {
        error 3 "The '${repo_name}' repository is behind the latest stable tag. Please synchronize."
        return "$err_behind_latest_stable_tag"
    }

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Finds the root directory of a Git repository working tree by searching for a directory with the given name under a
# specified parent directory.
# Parameters:
#   1 - dir - directory name or relative path to search for (optional, default: current directory)
#   2 - repos_parent - parent directory under which to search for the specified directory (optional, default: $VM2_REPOS or $HOME/repos/vm2)
# Returns:
#   stdout: the absolute path to the Git repository root
#   Exit code: 0 if exactly one matching root is found, 1 if none or multiple found, 2 on invalid arguments
# Dependencies: git, find
# Usage: root=$(resolve_repo_root <directory-name> [repos-parent] [root-only])
# Example: root=$(resolve_repo_root "vm2.Glob") # Finds the root of the Git repository containing a directory named "vm2.Glob"
#          under $HOME
# Example: root=$(resolve_repo_root "vm2.Templates/templates/AddNewPackage/content" true) # Finds the directory path
#          "vm2.Templates/templates/AddNewPackage/content" that is inside a Git repository work tree
#-------------------------------------------------------------------------------
function resolve_repo_root()
{
    (( $# <= 2 )) || {
        error 3 "${FUNCNAME[0]}() requires no more than 2 arguments ($# provided): the directory where the repository is located and the parent directory under which to search for the repository."
        return "$err_invalid_arguments"
    }

    local dir_path=${1:-"$(pwd)"}
    local vm2_repos="${2:-${VM2_REPOS:-$default_vm2_repos}}"

    dir_path="${dir_path#"$vm2_repos"}" # remove the $vm2_repos prefix if present, so that the path is relative to the search root
    dir_path="${dir_path#/}" # remove leading slash if any, so that the path is relative to the search root

    local repo_dir=""
    local dir=""
    local root=""
    local found_repo_dirs=0
    local found_dirs=0
    local d

    # find a directory with the same sub-path under $vm2_repos and check if it is a git work tree root (if root_only is true)
    # or inside a git work tree (if root_only is false)
    while IFS= read -r d; do
        [[ $d =~ /\.git/ ]] && continue # skip .git directories
        if is_inside_work_tree "$d"; then
            # it is inside a git repository
            repo_dir="$d"
            ((++found_repo_dirs))
        else
            # plain directory, it is not inside a git repository
            dir="$d"
            ((++found_dirs))
        fi
    done < <(find "$vm2_repos" -type d -path "*/$dir_path" 2>"$_ignore")

    local rc=0

    case $found_repo_dirs in
        0 )
            # maybe we found a plain directory that is not inside a git repository, go to the next case
            ;;
        1 )
            # we found one: get its root
            root=$(root_working_tree "$repo_dir")                       || return "$err_invalid_repo"
            validate_repo "$root" "$vm2_repos"; rc=$?; (( rc == 0 ))    || return "$rc"
            [[ -d "$root/.github/workflows" ]]                          || return "$err_invalid_repo"
            echo "${root}"
            return "$success"
            ;;
        * )
            error "Multiple directories named '$dir_path' were found."  && return "$err_found_more_than_one"
            ;;
    esac

    case $found_dirs in
        0 )
            error 3 "No directories named '$dir_path' were found."
            return "$err_not_found"
            ;;
        1 )
            # let's find the future git root
            root="${dir#"$vm2_repos"}"  # remove the $vm2_repos prefix
            root="${root%%/*}"  # remove everything after the first slash
            root="${root%%/}"   # remove trailing slash if any
            [[ -d "$root/.github/workflows" ]]                          || return "$err_invalid_repo"
            echo "${dir}"
            return "$err_not_git_repository" # we return this error code to indicate that the directory exists but is not a Git repository
                                             # the caller can decide what to do with this error code and this root
            ;;
        * )
            error "Multiple directories named '$dir_path' were found."  && return "$err_found_more_than_one"
            ;;
    esac

    return "$rc"
}
