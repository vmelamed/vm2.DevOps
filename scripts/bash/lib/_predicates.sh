# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed


# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# shellcheck disable=SC2154 # variable is referenced but not assigned.
if ! declare -pF "error" > "$_ignore"; then
    diag_dir="$(dirname "${BASH_SOURCE[0]}")"
    source "$diag_dir/_diagnostics.sh"
fi

#-------------------------------------------------------------------------------
# Summary: Tests if a variable is defined.
# Parameters:
#   1 - variable_name - name of the variable to test (nameref)
# Returns:
#   Exit code: 0 if variable is defined, non-zero otherwise, 2 on invalid arguments
# Env. Vars:
#   _ignore - file to redirect unwanted output to
# Usage: if is_defined <variable_name>; then ... fi
# Example: if is_defined MY_VAR; then echo "MY_VAR is defined"; fi
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function is_defined()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one argument: the name of the variable to test."
        return 2
    fi
    declare -p "$1" > "$_ignore" 2>&1
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid positive integer number (natural number: 1, 2, 3, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if positive integer, non-zero otherwise
# Usage: if is_positive <number>; then ... fi
# Example: if is_positive "$count"; then echo "Count is positive"; fi
#-------------------------------------------------------------------------------
function is_positive()
{
    [[ "$1" =~ ^[+]?[0-9]+$  && ! "$1" =~ ^[+]?0+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid non-negative integer (0, 1, 2, 3, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if non-negative integer, non-zero otherwise
# Usage: if is_non_negative <number>; then ... fi
# Example: if is_non_negative "$index"; then echo "Index is valid"; fi
#-------------------------------------------------------------------------------
function is_non_negative()
{
    [[ "$1" =~ ^[+]?[0-9]+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid non-positive integer (0, -1, -2, -3, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if non-positive integer, non-zero otherwise
# Usage: if is_non_positive <number>; then ... fi
# Example: if is_non_positive "$delta"; then echo "Delta is non-positive"; fi
#-------------------------------------------------------------------------------
function is_non_positive()
{
    [[ "$1" =~ ^-[0-9]+$ || "$1" =~ ^[-]?0+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid negative integer (-1, -2, -3, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if negative integer, non-zero otherwise
# Usage: if is_negative <number>; then ... fi
# Example: if is_negative "$offset"; then echo "Offset is negative"; fi
#-------------------------------------------------------------------------------
function is_negative()
{
    [[ $1 =~ ^-[0-9]+$ && ! "$1" =~ ^[-]?0+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid integer (..., -2, -1, 0, 1, 2, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if integer, non-zero otherwise
# Usage: if is_integer <number>; then ... fi
# Example: if is_integer "$value"; then echo "Value is an integer"; fi
#-------------------------------------------------------------------------------
function is_integer()
{
    [[ "$1" =~ ^[-+]?[0-9]+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid decimal number (including integers and floating-point).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if decimal number, non-zero otherwise
# Usage: if is_decimal <number>; then ... fi
# Example: if is_decimal "$price"; then echo "Price is valid"; fi
#-------------------------------------------------------------------------------
function is_decimal()
{
    [[ "$1" =~ ^[-+]?[0-9]*(\.[0-9]*)?$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the first parameter equals one of the following parameters.
# Parameters:
#   1 - value - value to search for
#   2+ - options - one or more valid options to compare against
# Returns:
#   Exit code: 0 if value found in options, 1 if not found, 2 on invalid arguments
# Usage: if is_in <value> <option1> [option2...]; then ... fi
# Example: if is_in "$color" "red" "green" "blue"; then echo "Valid color"; fi
#-------------------------------------------------------------------------------
function is_in()
{
    if [[ $# -lt 2 ]]; then
        error "${FUNCNAME[0]}() requires at least 2 arguments: the value to test and at least one valid option."
        return 2
    fi

    local sought="$1"; shift
    local v
    for v in "$@"; do
        [[ "$sought" == "$v" ]] && return 0
    done
    return 1
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
