# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # variable is referenced but not assigned.

#-------------------------------------------------------------------------------
# Summary: Finds the root directory of a Git repository working tree by searching for a directory with the given name under a
#  specified parent directory.
# Parameters:
#  1 - dir - directory name or relative path to search for (optional, default: current directory)
#  2 - root_only - if "true", only accept directories that are the root of a Git work tree (required for repo setup audit);
#      if "false", accept any directory inside a Git work tree (optional, default: "true")
#  3 - repos_parent - parent directory under which to search for the specified directory (optional, default: $GIT_REPOS or $HOME)
# Returns:
#  stdout: the absolute path to the Git repository root
#  Exit code: 0 if exactly one matching root is found, 1 if none or multiple found, 2 on invalid arguments
# Dependencies: git, find
# Usage: root=$(find_repo_root <directory-name> [root-only] [repos-parent])
# Example: root=$(find_repo_root "vm2.Glob") # Finds the root of the Git repository containing a directory named "vm2.Glob"
#  under $HOME
# Example: root=$(find_repo_root "vm2.Templates/templates/AddNewPackage/content" "true") # Finds the directory path
#  "vm2.Templates/templates/AddNewPackage/content" that is inside a Git repository work tree
#-------------------------------------------------------------------------------
function find_repo_root()
{
    local dir_path=${1:-"$(pwd)"}
    dir_path=${dir_path#/*/} # remove leading path components to be able to match the directory name with "*/$dir_path" in find
                             # this allows the caller to specify either a directory name or a relative path, e.g. "vm2.Glob" or "vm2.Glob/subdir"
    local root_only=${2:-"true"}
    local repos_parent="${3:-${GIT_REPOS:-$HOME}}"
    # dir_path=${dir_path%/}
    local root=""
    local found_roots=0
    local d
    local e

    # find a directory with the same sub-path under $repos_parent and check if it is a git work tree root (if root_only is true)
    # or inside a git work tree (if root_only is false)
    while IFS= read -r d; do
        if [[ "$root_only" == "true" ]]; then
            e="$(git -C "$d" rev-parse --show-toplevel 2>"$_ignore")" || continue
            root="$e"
            ((++found_roots))
        elif is_inside_work_tree "$d"; then
            root="$d"
            ((++found_roots))
        fi
    done < <(find "$repos_parent" -type d -path "*/$dir_path" 2>"$_ignore")

    (( found_roots == 1 )) && { echo "${root}"; return 0; }
    (( found_roots == 0 )) && error "No directory named '$dir_path' was found that is a root of a Git repository work tree." >&2
    (( found_roots  > 1 )) && error "Multiple directories named '$dir_path' were found that are roots of Git repository work trees." >&2
    return 1
}

#-------------------------------------------------------------------------------
# Summary: Retrieves GitHub repository information from a local Git repository root directory by parsing the origin remote URL.
# Parameters:
#   1 - dir - absolute path to the root of a Git repository work tree
# Returns:
#   stdout: key=value pairs (one per line):
#     root=<absolute path to the repo root>
#     url=<origin remote URL>
#     owner=<GitHub owner/organization name>
#     name=<GitHub repository name>
#   Exit code: 0 on success, 2 if the directory is not a Git repo root or the origin remote is not a GitHub SSH URL
# Dependencies: git
# Usage:
#   declare -A info
#   while IFS='=' read -r key value; do info["$key"]="$value"; done < <(gh_repo_info "/path/to/repo")
#   echo "${info[$owner]}/${info[$name]}"
# Example:
#   gh_repo_info "/home/valo/repos/vm2.Glob"
#   # Output:
#   # root=/home/valo/repos/vm2.Glob
#   # url=git@github.com:vmelamed/vm2.Glob.git
#   # owner=vmelamed
#   # name=vm2.Glob
#-------------------------------------------------------------------------------
repo_owner_rex='[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,37}[a-zA-Z0-9])'
repo_name_rex='[a-zA-Z0-9][a-zA-Z0-9._-]{0,99})' # GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.

repo_owner_regex="^${repo_owner_rex}$"
repo_name_regex="^${repo_name_rex}$"

github_url_regex="^(git@github\.com:|https://github\.com/)(${repo_owner_rex})/(${repo_name_rex})$"

declare -xr repo_owner_rex
declare -xr repo_name_rex
declare -xr repo_owner_regex
declare -xr repo_name_regex
declare -xr github_url_regex

declare -xi url_host=1
declare -xi url_owner=2
declare -xi url_name=4

function gh_repo_info()
{
    if [[ $# -lt 1 ]]; then
        error "${FUNCNAME[0]}() requires at least 1 argument: the root of a Git repository work tree." >&2
        return 2
    fi

    # Root of the git repo tree
    local root rc

    root=$(git -C "$1" rev-parse --show-toplevel 2>"$_ignore")
    rc=$?
    if [[ "$rc" -ne 0 ]]; then
        error "The provided directory '$1' is not from a Git repository work tree." >&2
        return 2
    fi

    # Origin remote URL
    local remoteUrl
    remoteUrl=$(git -C "$root" remote get-url origin 2>"$_ignore")
    if [[ ! $remoteUrl =~ $github_url_regex ]]; then
        error "The repository at '$root' does not have an 'origin' remote or '$remoteUrl' is not a GitHub repository." >&2
        return 2
    fi

    local owner name
    owner="${BASH_REMATCH[$url_owner]}"
    name="${BASH_REMATCH[$url_name]}"
    echo "root=$root"
    echo "url=$remoteUrl"
    echo "owner=$owner"
    echo "name=${name%.git}" # remove .git suffix if present
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Retrieves the root of the Git repository work tree for the specified
#          or the current directory.
# Parameters:
#   1 - directory - optional path to a directory inside a Git repository work tree
# Returns:
#   stdout: absolute path to the root of the Git repository work tree
#   Exit code: 0 on success, non-zero on failure
# Dependencies: git
# Usage: root_working_tree <directory>
# Example: root_working_tree "$PWD"
#-------------------------------------------------------------------------------
function root_working_tree()
{
    if [[ -d $1 ]]; then
        git -C "$1" rev-parse --show-toplevel 2> "$_ignore"
    else
        git rev-parse --show-toplevel 2> "$_ignore"
    fi
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
