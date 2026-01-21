#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
if ! declare -pF "error" > "$_ignore"; then
    semver_dir="$(dirname "${BASH_SOURCE[0]}")"
    source "$semver_dir/_common.diagnostics.sh"
fi

## Shell function to test if a variable is defined.
## Usage: is_defined <variable_name>
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function is_defined() {
    if [[ $# -ne 1 ]]; then
        error "The function is_defined() requires exactly one argument: the name of the variable to test."
        return 2
    fi
    declare -p "$1" >"$_ignore" 2>&1
}

## Tests if the parameter represents a valid positive, integer number (aka natural number): {1, 2, 3, ...}
## Usage: is_positive <number>
function is_positive() {
    [[ "$1" =~ ^[+]?[0-9]+$  && ! "$1" =~ ^[+]?0+$ ]]
}

## Tests if the parameter represents a valid non-negative integer number: {0, +0, 1, 2, 3, ...}
## Usage: is_non_negative <number>
function is_non_negative() {
    [[ "$1" =~ ^[+]?[0-9]+$ ]]
}

## Tests if the parameter represents a valid non-positive integer number: {0, -0, -1, -2, -3, ...}
## Usage: is_non_positive <number>
function is_non_positive() {
    [[ "$1" =~ ^-[0-9]+$ || "$1" =~ ^[-]?0+$ ]]
}

## Tests if the parameter represents a valid negative integer number: {-1, -2, -3, ...}
## Usage: is_negative <number>
function is_negative() {
    [[ $1 =~ ^-[0-9]+$ && ! "$1" =~ ^[-]?0+$ ]]
}

## Tests if the parameter represents a valid integer number: {..., -2, -1, 0, 1, 2, ...}
## Usage: is_integer <number>
function is_integer() {
    [[ "$1" =~ ^[-+]?[0-9]+$ ]]
}

## Tests if the parameter represents a valid decimal number
## Usage: is_decimal <number>
function is_decimal() {
    [[ "$1" =~ ^[-+]?[0-9]*(\.[0-9]*)?$ ]]
}

## Tests if the first parameter is equal to one of the following parameters.
## Usage: is_in <value> <option1> [<option2> ...]
function is_in() {
    if [[ $# -lt 2 ]]; then
        error "The function is_in() requires at least 2 arguments: the value to test and at least one valid option."
        return 2
    fi

    local sought="$1"; shift
    local v
    for v in "$@"; do
        [[ "$sought" == "$v" ]] && return 0
    done
    return 1
}

## Tests the error counter to determine if there are any accumulated errors so far
## Usage: has_errors [<flag>]. The flag is optional and doesn't matter what it is - if it is passed, the method calls `exit 2`.
## Return: If it didn't exit, returns 1 if there are errors, 0 otherwise.
function has_errors()
{
    if ((errors > 0)); then
        if [[ -n $1 ]]; then
            usage "❌  ERROR: $errors error(s) encountered. Please fix the above issues and try again."
            exit 2
        else
            error "$errors error(s) encountered. Please fix the above issues and try again."
        fi
        return 1
    fi
    return 0
}

## Exits the script if there are any accumulated errors so far.
function exit_if_has_errors()
{
    has_errors 2
}

## Tests if the specified directory is a Git repository.
## Usage: is_git_repo <directory>
function is_git_repo()
{
    if [[ $# -ne 1 ]]; then
        error "The function is_git_repo() requires exactly one argument: the directory to test."
        return 2
    fi

    [[ -d $1 ]] && git -C "$1" rev-parse --is-inside-work-tree &>"$_ignore"
}

## Tests if the current commit in the specified directory is on the latest stable tag.
## Usage: is_on_or_after_latest_stable_tag <directory> <stable-tag-regex> [<skip-fetch>]
function is_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error "The function is_latest_stable_tag() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch latest in main changes from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag current_commit tag_commit

    is_git_repo "$1" || return 2
    if [[ $# -eq 3 && "$3" != "true" ]]; then
        git -C "$1" fetch origin main --quiet
    fi

    # Get latest stable tag (excludes pre-release tags with -)
    latest_tag=$(git -C "$1" tag | grep -E "$2" | sort -V | tail -n1)
    [[ -n $latest_tag ]] || return 1

    current_commit=$(git -C "$1" rev-parse HEAD)

    tag_commit=$(git -C "$1" rev-parse "$latest_tag^{commit}" 2>"$_ignore")

    [[ "$current_commit" == "$tag_commit" ]]
}

## Tests if the current commit in the specified directory is after the latest stable tag.
## Usage: is_after_latest_stable_tag <directory> <stable-tag-regex> [<skip-fetch>]
function is_after_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error "The function is_after_latest_stable_tag() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch latest in main changes from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag tag_commit commits_after

    is_git_repo "$1" || return 2
    if [[ $# -eq 3 && "$3" != "true" ]]; then
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

## Tests if the current commit in the specified directory is on or after the latest stable tag.
## Usage: is_on_or_after_latest_stable_tag <directory> <stable-tag-regex> [<skip-fetch>]
function is_on_or_after_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error "The function is_on_or_after_latest_stable_tag() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch latest in main changes from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag tag_commit

    is_git_repo "$1" || return 2
    if [[ $# -eq 3 && "$3" != "true" ]]; then
        git -C "$1" fetch origin main --quiet
    fi

    # Get latest stable tag
    latest_tag=$(git -C "$1" tag | grep -E "$2" | sort -V | tail -n1)
    [[ -n $latest_tag ]] || return 1

    tag_commit=$(git -C "$1" rev-parse "$latest_tag^{commit}" 2>"$_ignore")

    # Check if current commit is on or after the latest stable tag
    # Returns 0 if tag commit is an ancestor of HEAD (i.e., HEAD is at or after the tag)
    git -C "$1" merge-base --is-ancestor "$tag_commit" HEAD &>"$_ignore"
}
