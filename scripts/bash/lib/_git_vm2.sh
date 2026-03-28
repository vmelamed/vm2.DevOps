# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # variable is referenced but not assigned.

declare -xr default_vm2_repos="$HOME/repos/vm2"

declare -x vm2_repos="${VM2_REPOS:-$default_vm2_repos}"

#-------------------------------------------------------------------------------
# Summary: Resolves the vm2_repos directory from the environment variable $VM2_REPOS,
#   the default value $HOME/repos/vm2, or the command line argument.
# Parameters:
#   $1 - optional: the directory to use as vm2_repos
# Returns:
#   Exit code: 0 if the vm2_repos directory was successfully resolved, 1 otherwise
# Environment variables:
#   VM2_REPOS - the parent directory where the vm2 repositories are expected to have been cloned to
#   default_vm2_repos - the default value for vm2_repos if VM2_REPOS is not set
# Usage:
#   resolve_vm2_repos [directory]
#-------------------------------------------------------------------------------

function resolve_vm2_repos()
{
    # the parameter overrides the environment variable $VM2_REPOS and the default value $HOME/repos/vm2
    if [[ $# -ge 1 ]]; then
        vm2_repos="$1"
    fi

    # try to resolve vm2_repos from
    #   1) the environment variable VM2_REPOS
    #   2) if not from $HOME/repos/vm2
    #   3) from the command line option --vm2-repos.
    if [[ -n "$vm2_repos" && -d "$vm2_repos" ]]; then
        # looks good so far - ensure $vm2_repos is an absolute path.
        vm2_repos=$(realpath -e "$vm2_repos" 2> "$_ignore") &&
        trace "vm2_repos='$vm2_repos' resolved from \$VM2_REPOS, or '\$HOME/repos/vm2', or from 'argument'" &&
        return 0

        [[ $# -ge 1 ]] &&
        error "'$1' - the argument is not a directory."
        return 1
    fi

    local r

    # try from the current working directory:
    if r=$(root_working_tree); then
        vm2_repos=$(dirname "$r")
        trace "vm2_repos='$vm2_repos' resolved from the current working directory"
        return 0
    fi

    # or from the script directory:
    if r=$(root_working_tree "$script_dir"); then
        vm2_repos=$(dirname "$r")
        trace "vm2_repos='$vm2_repos' resolved from the script directory"
        return 0
    fi

    error "Could not resolve the vm2_repos directory from \$VM2_REPOS, '\$HOME/repos/vm2', the 'argument', the current working directory, or the script directory."
    return 1
}

#-------------------------------------------------------------------------------
# Summary: Validates that
#     1) the specified directory exists
#     2) it is a git repository
#     3) is at or ahead of the latest stable tag.
# Parameters:
#   $1: repository name (e.g. "vm2.DevOps")
# Returns:
#   Exit code:
#     0 - if the repository directory exists and meets the above criteria, or
#     1 - if the repository directory is behind the latest stable tag
#     2 - if the repository directory is not a git repository
#     3 - if the repository directory was not found under $vm2_repos or the current working directory
# Environment variables:
#   vm2_repos:
#     the parent directory where the repository is expected to have been cloned to, e.g. $VM2_REPOS or "$HOME/repos/vm2"
# Dependencies:
#   git CLI (functions root_working_tree, is_on_or_after_latest_stable_tag)
# Usage:
#   validate_source_repo "vm2.DevOps"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function validate_source_repo()
{
    if [[ $# -lt 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires at least 1 argument: the name of a repository."
        return 5
    fi

    local repo_name=$1
    local dir="${vm2_repos:-.}/${repo_name}"

    if [[ ! -d "${dir}" ]]; then
        error 3 "The '${repo_name}' repository is not found under ${vm2_repos}."
        return 3
    fi

    if [[ "$dir" != $(root_working_tree "$dir") ]]; then
        error 3 "The ${repo_name} repository at '$dir' is not a git repository."
        return 2
    fi

    if ! is_on_or_after_latest_stable_tag "$dir" "$semverTagReleaseRegex"; then
        error 3 "The '${repo_name}' repository is behind the latest stable tag. Please synchronize."
        return 1
    fi

    return 0
}

#-------------------------------------------------------------------------------
# Summary: Finds the root directory of a Git repository working tree by searching for a directory with the given name under a
# specified parent directory.
# Parameters:
#  1 - dir - directory name or relative path to search for (optional, default: current directory)
#  2 - root_only - if true, only accept directories that are the root of a Git repository working tree
#      if false, accept any directory inside a Git repository working tree (optional, default: true)
#  3 - repos_parent - parent directory under which to search for the specified directory (optional, default: $VM2_REPOS or $HOME)
# Returns:
#  stdout: the absolute path to the Git repository root
#  Exit code: 0 if exactly one matching root is found, 1 if none or multiple found, 2 on invalid arguments
# Dependencies: git, find
# Usage: root=$(find_repo_root <directory-name> [root-only] [repos-parent])
# Example: root=$(find_repo_root "vm2.Glob") # Finds the root of the Git repository containing a directory named "vm2.Glob"
#  under $HOME
# Example: root=$(find_repo_root "vm2.Templates/templates/AddNewPackage/content" true) # Finds the directory path
#  "vm2.Templates/templates/AddNewPackage/content" that is inside a Git repository work tree
#-------------------------------------------------------------------------------
function find_repo_root()
{
    local dir_path=${1:-"$(pwd)"}
    dir_path=${dir_path#/*/} # remove leading path components to be able to match the directory name with "*/$dir_path" in find
                             # this allows the caller to specify either a directory name or a relative path, e.g. "vm2.Glob" or "vm2.Glob/subdir"
    local root_only=${2:-true}
    local repos_parent="${3:-${VM2_REPOS:-$HOME}}"
    # dir_path=${dir_path%/}
    local root=""
    local found_roots=0
    local d
    local e

    # find a directory with the same sub-path under $repos_parent and check if it is a git work tree root (if root_only is true)
    # or inside a git work tree (if root_only is false)
    while IFS= read -r d; do
        if [[ "$root_only" == true ]]; then
            e="$(git -C "$d" rev-parse --show-toplevel 2>"$_ignore")" || continue
            root="$e"
            ((++found_roots))
        elif is_inside_work_tree "$d"; then
            root="$d"
            ((++found_roots))
        fi
    done < <(find "$repos_parent" -type d -path "*/$dir_path" 2>"$_ignore")

    local rc=0
    (( found_roots == 1 )) && rc=0 || rc=1
    (( found_roots  > 1 )) && { rc=2; root=""; error "Multiple Git repository roots named '$dir_path' were found."; }

    # send the root to stdout
    echo "${root}"

    return "$rc"
}
