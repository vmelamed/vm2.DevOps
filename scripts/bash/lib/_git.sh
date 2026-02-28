# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # variable is referenced but not assigned.

#-------------------------------------------------------------------------------
# Summary: Finds the root directory (by default) of a Git repository by searching for a
#   directory with the given name under $HOME.
# Parameters:
#   1 - dir - directory name or relative path to search for (optional, default: current directory)
#   2 - not_root_only - if "true", accept any directory inside a Git work tree;
#       otherwise only accept directories that are the root of a Git work tree (optional)
# Returns:
#   stdout: the absolute path to the Git repository root
#   Exit code: 0 if exactly one matching root is found, 1 if none or multiple found, 2 on invalid arguments
# Dependencies: git, find
# Usage: root=$(find_repo_root <directory-name> [not-root-only])
# Example: root=$(find_repo_root "vm2.Glob") # Finds the root of the Git repository containing a directory named "vm2.Glob"
#   under $HOME
# Example: root=$(find_repo_root "vm2.Templates/templates/AddNewPackage/content" "true") # Finds the directory path
#   "vm2.Templates/templates/AddNewPackage/content" that is inside a Git repository work tree
#-------------------------------------------------------------------------------
function find_repo_root()
{
    local dir=${1:-"$(pwd)"}
    dir=${dir#/}
    dir=${dir%/}
    local -a roots=()
    local d
    local e

    # find all directories with the same name under $HOME
    while IFS= read -r d; do
        if [[ "$2" == "true" ]] && is_inside_work_tree "$d"; then
            roots+=("$d")
        else
            e="$(git -C "$d" rev-parse --show-toplevel 2>"$_ignore")" || continue
            if [[ "$e" == "$d" ]] && ! is_in "$e" "${roots[@]}"; then
                roots+=("$e")
            fi
        fi
    done < <(find "$HOME" -type d -path "*/$dir" 2>"$_ignore")

    if [[ ${#roots[@]} -eq 1 ]]; then
        echo "${roots[0]}"
        return 0
    elif [[ ${#roots[@]} -eq 0 ]]; then
        error "No directory named '$dir' was found that is a root of a Git repository work tree." >&2
        return 1
    else
        error "Multiple directories named '$dir' were found that are roots of Git repository work trees." >&2
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Summary: Retrieves GitHub repository information from a local Git repository root directory by parsing the origin remote URL.
# Parameters:
#   1 - dir - absolute path to the root of a Git repository work tree
# Returns:
#   stdout: key=value pairs (one per line):
#     Root=<absolute path to the repo root>
#     Url=<origin remote URL>
#     Owner=<GitHub owner/organization name>
#     Name=<GitHub repository name>
#   Exit code: 0 on success, 2 if the directory is not a Git repo root or the origin remote is not a GitHub SSH URL
# Dependencies: git
# Usage:
#   declare -A info
#   while IFS='=' read -r key value; do info["$key"]="$value"; done < <(gh_repo_info "/path/to/repo")
#   echo "${info[Owner]}/${info[Name]}"
# Example:
#   gh_repo_info "/home/valo/repos/vm2.Glob"
#   # Output:
#   # root=/home/valo/repos/vm2.Glob
#   # url=git@github.com:vmelamed/vm2.Glob.git
#   # owner=vmelamed
#   # name=vm2.Glob
#-------------------------------------------------------------------------------
repo_owner_regex='[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])'
repo_name_regex='^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$'
github_url_regex="^(git@github.com:|https://github.com/)(${repo_owner_regex})/(${repo_name_regex})(\.git)?$"

declare -xr repo_owner_regex
declare -xr repo_name_regex
declare -xr github_url_regex

function gh_repo_info()
{
    if [[ $# -lt 1 ]]; then
        error "${FUNCNAME[0]}() requires at least 1 argument: the root of a Git repository work tree." >&2
        return 2
    fi

    # Root of the git repo tree
    local root

    root=$(git -C "$1" rev-parse --show-toplevel 2>"$_ignore")
    local rc
    rc=$?
    if [[ "$rc" -ne 0 || "$root" != "$1" ]]; then
        error "The provided directory '$1' is not a root of a Git repository work tree." >&2
        return 2
    fi

    # Origin remote URL
    local remoteUrl
    remoteUrl=$(git -C "$root" remote get-url origin 2>"$_ignore")
    if [[ ! $remoteUrl =~ $github_url_regex ]]; then
        error "The repository at '$root' does not have an 'origin' remote or '$remoteUrl' is not a GitHub repository." >&2
        return 2
    fi

    echo "root=$root"
    echo "url=$remoteUrl"
    echo "owner=${BASH_REMATCH[2]}"
    echo "name=${BASH_REMATCH[4]}"
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Tests if the specified directory is inside a Git repository (inside a git work tree).
# Parameters:
#   1 - directory - path to directory to test
# Returns:
#   Exit code: 0 if directory is inside a Git work tree, non-zero otherwise, 2 on invalid arguments
# Dependencies: git
# Usage: if is_inside_work_tree <directory>; then ... fi
# Example: if is_inside_work_tree "$PWD"; then echo "Inside Git repo"; fi
#-------------------------------------------------------------------------------
function is_inside_work_tree()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one argument: the directory to test."
        return 2
    fi

    [[ -d $1 ]] && git -C "$1" rev-parse --is-inside-work-tree &> "$_ignore"
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is on the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
#   2 - stable_tag_regex - regular expression for matching stable tags
#   3 - skip_fetch - if "true", skip fetching from remote (optional, default: fetch from remote)
# Returns:
#   Exit code: 0 if on latest stable tag, 1 if not, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_on_latest_stable_tag <directory> <stable-tag-regex> [skip-fetch]; then ... fi
# Example: if is_on_latest_stable_tag "$repo_dir" "^v[0-9]+\.[0-9]+\.[0-9]+$"; then echo "On latest stable"; fi
#-------------------------------------------------------------------------------
function is_on_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error "${FUNCNAME[0]}() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch the latest changes in main from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag current_commit tag_commit

    is_inside_work_tree "$1" || return 2
    if [[ $# -lt 3 || "$3" != "true" ]]; then
        git -C "$1" fetch origin main --quiet
    fi

    # Get latest stable tag (excludes pre-release tags with -)
    latest_tag=$(git -C "$1" tag | grep -E "$2" | sort -V | tail -n1)
    [[ -n $latest_tag ]] || return 1

    current_commit=$(git -C "$1" rev-parse HEAD)

    tag_commit=$(git -C "$1" rev-parse "$latest_tag^{commit}" 2>"$_ignore")

    [[ "$current_commit" == "$tag_commit" ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is after the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
#   2 - stable_tag_regex - regular expression for matching stable tags
#   3 - skip_fetch - if "true", skip fetching from remote (optional, default: fetch from remote)
# Returns:
#   Exit code: 0 if after latest stable tag, 1 if not, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_after_latest_stable_tag <directory> <stable-tag-regex> [skip-fetch]; then ... fi
# Example: if is_after_latest_stable_tag "$repo_dir" "^v[0-9]+\.[0-9]+\.[0-9]+$"; then echo "Beyond latest stable"; fi
#-------------------------------------------------------------------------------
function is_after_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error "${FUNCNAME[0]}() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch the latest changes in main from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag tag_commit commits_after

    is_inside_work_tree "$1" || return 2
    if [[ $# -lt 3 || "$3" != "true" ]]; then
        git -C "$1" fetch origin main --quiet
    fi

    # Get latest stable tag (excludes pre-release tags with -)
    latest_tag=$(git -C "$1" tag | grep -E "$2" | sort -V | tail -n1)
    [[ -n $latest_tag ]] || return 1

    tag_commit=$(git -C "$1" rev-parse "$latest_tag^{commit}" 2>"$_ignore")

    # Check if current commit is after the latest stable tag
    commits_after=$(git -C "$1" rev-list "$tag_commit..HEAD" --count 2>"$_ignore")
    [[ $commits_after -gt 0 ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is on or after the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
#   2 - stable_tag_regex - regular expression for matching stable tags
#   3 - skip_fetch - if "true", skip fetching from remote (optional, default: fetch from remote)
# Returns:
#   Exit code: 0 if on or after latest stable tag, 1 if before, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_on_or_after_latest_stable_tag <directory> <stable-tag-regex> [skip-fetch]; then ... fi
# Example: if is_on_or_after_latest_stable_tag "$repo_dir" "^v[0-9]+\.[0-9]+\.[0-9]+$"; then echo "Ready for release"; fi
#-------------------------------------------------------------------------------
function is_on_or_after_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error "${FUNCNAME[0]}() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch the latest changes in main from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag tag_commit

    is_inside_work_tree "$1" || return 2
    if [[ $# -lt 3 || "$3" != "true" ]]; then
        git -C "$1" fetch origin main --quiet
    fi

    # Get latest stable tag
    latest_tag=$(git -C "$1" tag | grep -E "$2" | sort -V | tail -n1)
    [[ -n $latest_tag ]] || return 1

    tag_commit=$(git -C "$1" rev-parse "$latest_tag^{commit}" 2>"$_ignore")

    # Check if current commit is on or after the latest stable tag
    # Returns 0 if tag commit is an ancestor of HEAD (i.e., HEAD is at or after the tag)
    git -C "$1" merge-base --is-ancestor "$tag_commit" HEAD &> "$_ignore"
}
