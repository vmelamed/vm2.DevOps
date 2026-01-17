#!/bin/bash

# This script defines a number of general purpose functions.
# For the functions to be invocable by other scripts, this script needs to be sourced.
# When fatal parameter errors are detected, the script invokes exit, which leads to exiting the current shell.

#-------------------------------------------------------------------------------
# Common scripts variables and environment initialization
#-------------------------------------------------------------------------------

# commonly used variables
initial_dir=$(pwd)
declare -rx initial_dir

common_scripts_dir="$(dirname "${BASH_SOURCE[0]}")"

source "${common_scripts_dir}/_common.diagnostics.sh"
source "${common_scripts_dir}/_common.flags.sh"
source "${common_scripts_dir}/_common.dump_vars.sh"
source "${common_scripts_dir}/_common.semver.sh"
source "${common_scripts_dir}/_common.predicates.sh"
source "${common_scripts_dir}/_common.user.sh"

# trap on_debug DEBUG
# trap on_exit EXIT

## Depending on the value of $dry_run either executes or just displays what would have been executed.
## Usage: execute <command> [args...]
function execute() {
    if [[ "$dry_run" == true ]]; then
        echo "dry-run$ $*"
        return 0
    fi
    trace "$*"
    "$@"
}

# ---------------------
## String manipulations
# ---------------------

# to_lower converts all characters in the passed in value to lowercase and prints the to stdout.
# Usage example: local a="$(to_lower "$1")"
function to_lower() {
    printf "%s" "${1,,}"
    return 0
}

# to_upper converts all characters in the passed in value to uppercase and prints the to stdout.
# Usage example: local a="$(to_upper "$1")"
function to_upper() {
    printf "%s" "${1^^}"
    return 0
}

# capitalize converts the first character in the passed in value to upper case and the rest to lowercase and prints the to stdout.
# Usage example: local a="$(capitalize "$1")"
function capitalize() {
    a="${1,,}"
    printf "%s" "${a^}"
    return 0
}

# ---------------------
## Others:
# ---------------------

## Tests if the parameter represents a valid file pattern and returns a list of matching files.
## Usage: list_of_files <file_pattern>
## Returns: space separated list of matching files in stdout
## Example: list_of_files "artifacts/pack/*.nupkg"
function list_of_files() {
    if [[ $# -lt 1 ]]; then
        error "The function list_of_files() requires at least one parameter: the file pattern."
        return 2
    fi

    restoreNullglob=$(shopt -p nullglob)
    restoreGlobstar=$(shopt -p globstar)
    # by default, if a glob pattern does not match any files, it expands to an empty string instead of the default: to leave
    # the pattern unchanged, e.g. ${artifacts_dir}/results/*-report.json - we don't want that
    shopt -s nullglob
    shopt -s globstar || true
    # shellcheck disable=SC2206
    local list=($1)
    eval "$restoreNullglob"
    eval "$restoreGlobstar"
    printf "%s" "${list[*]}"
    return 0
}

## Gets the result of executing JSON query expression on YAML file.
## Requires "jq" and "yq" to be installed!
## Param 1 - the JSON query expression to execute
## Param 2 - the YAML file
## Return 0 if the result is not null and not empty; otherwise 1
## The query result will be output to stdout.
function get_from_yaml()
{
    if [[ $# -lt 2 ]]; then
        echo "The function get_from_yaml() requires two parameters: the query and the yaml file name." >&2
        return 2
    fi

    local query="$1";
    local file="$2"
    if [[ ! -s "$file" ]]; then
        echo "The file '$file' is empty or does not exist." >&2
        return 1
    fi
    local r
    r=$(yq eval "$query" "$file") || return 1
    [[ "$r" == "null" ]] && return 1
    printf '%s' "$r"
    return 0
}

## Gets a user ID and a password from the script user. In the end the script will ask the user to
## confirm their entries.
## Parameter 1 - the prompt for getting the user ID. Default "User ID: "
## Parameter 2 - the prompt for getting the password. Default "Password: "
## Parameter 3 - the prompt to confirm that the input is correct. If empty, the function will not ask the user to confirm
## their input.
## The user ID and the password will be held in $return_userid and $return_passwd until the next invocation of the
## function.
function get_credentials() {
    local promptUserID=${1:-"User ID: "}
    local promptPassword=${2:-"Password: "}
    local promptConfirm=$3
    userid=""
    passwd=""
    [[ "$quiet" == true ]] && printf "%s:%s" "$userid" "$passwd" && return 0
    while [[ -z $userid  &&  -z $passwd ]]; do
        read -rp "$promptUserID" userid >&2
        read -rsp "$promptPassword" passwd >&2
        echo >&2
        if [[ -n "$promptConfirm" ]] && confirm "$promptConfirm"; then
            printf "%s:%s" "$userid" "$passwd"
            exit 0
        else
            userid=""
            passwd=""
        fi
    done
}

# scp_retry tries the SSH copy command up to three times with timeout of 10sec timeout between retries.
# Parameters - the same parameters as the scp command, this is there must be at least 2 arguments.
# If the operation is successful it will set $return_copied to 'true' until the next invocation.
function scp_retry() {
    local -i maxRetries=3
    local -i retry_after=10
    local -i try=0
    while true; do
        if execute scp "$@"; then
            printf 'true'
            return 0
        fi
        if ((try < maxRetries)); then
            echo "  - will try scp again in ${retry_after}sec..." >&2
            sleep "$retry_after"
        else
            break
        fi
        ((try++))
    done

    echo "FAILED: scp $*" >&2
    return 1
}
