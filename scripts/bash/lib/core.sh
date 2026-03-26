# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed


# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# This script defines a number of general purpose functions.
# For the functions to be invocable by other scripts, this script needs to be sourced.
# When fatal parameter errors are detected, the script invokes exit, which leads to exiting the current shell.

#--------------------------------------------------------------------------------
# Common scripts variables and environment initialization
#--------------------------------------------------------------------------------

declare -x script_name
declare -x script_dir
declare -x lib_dir

if [[ ! -v script_name || -z "$script_name" ]]; then
    script_name=$(basename "${BASH_SOURCE[-1]}")
fi
if [[ ! -v script_dir || -z "$script_dir" ]]; then
    script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[-1]}")")
fi
if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
fi

# variables commonly used for diagnostics
declare -rx script_name
declare -rx script_dir
declare -rx lib_dir

declare -xr default__ignore=/dev/null

declare -x _ignore=$default__ignore                 # the file to redirect unwanted output to, changing the value may be useful for debugging, e.g. to redirect to /dev/stdout

# source the components of the core library
source "${lib_dir}/_constants.sh"
source "${lib_dir}/_diagnostics.sh"
source "${lib_dir}/_args.sh"
source "${lib_dir}/_predicates.sh"
source "${lib_dir}/_dump_vars.sh"
source "${lib_dir}/_semver.sh"
source "${lib_dir}/_user.sh"
source "${lib_dir}/_git.sh"

# Use $_ignore to redirect unwanted output, e.g. errors from commands or tools, to avoid cluttering the terminal or logs. When
# you need to see the output for debugging purposes, you can redirect $_ignore to /dev/stderr, but NEVER redirect it to /dev/stdout!
# If it is redirected to stdout AND the output of the whole command is captured or redirected, it will interfere with the
# expected output of the command, leading to incorrect results or unexpected behavior. Therefore NEVER assign a file to $_ignore
# directly. Use the functions below to manipulate it.

#-------------------------------------------------------------------------------
# Summary: Redirects the ignored output to the specified file.
# Parameters:
#   1 - file name to redirect the ignored output to (optional, default: /dev/stderr)
# Returns:
#   Exit code: 0 on success, 2 on invalid arguments
# Usage: show_ignored_output [file]
# Example: show_ignored_output /dev/stdout
#-------------------------------------------------------------------------------
function show_ignored_output()
{
    if [[ $# -gt 1 ]]; then
        error 3 "${FUNCNAME[0]}() accepts at most one argument: the file name to redirect the ignored output to."
        return 2
    fi

    (( $# == 0 )) && _ignore=/dev/stderr && return 0

    if [[ $1 =~ ^(/dev/stdout|/dev/fd/1|/proc/self/fd/1)$ ]]; then
        warning "Redirecting ignored output to /dev/stdout may lead to unpredictable results if the output of the commands using \$_ignore is captured or redirected!"
    fi

    _ignore=$1
    return 0
}

#-------------------------------------------------------------------------------
# Summary: restores the ignored output to /dev/null
#-------------------------------------------------------------------------------
function hide_ignored_output()
{
    _ignore=/dev/null
}

#-------------------------------------------------------------------------------
# Summary: Depending on the value of $dry_run, either executes or displays what would have been executed.
# Parameters:
#   1 - command - the command to execute
#   2+ - args - arguments to pass to the command (optional)
# Returns:
#   Exit code: 0 on success or in dry-run mode, command's exit code otherwise, 2 on invalid arguments
# Env. Vars:
#   dry_run - when true, displays command without executing it
# Usage: execute <command> [args...]
# Example: execute git commit -m "Initial commit"
#-------------------------------------------------------------------------------
declare -x dry_run=${DRY_RUN:-false}

function execute()
{
    if [[ $# -eq 0 ]]; then
        error 3 "${FUNCNAME[0]}() requires at least one argument: the command to execute."
        return 2
    fi

    if [[ "$dry_run" == true ]]; then
        echo "dry-run$ $*"
        return 0
    fi

    local IFS=" "
    trace "Executing (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): $*"
    "$@"
}

#-------------------------------------------------------------------------------
# Summary: Execute a command with retry logic for transient failures
# Parameters:
#   1 - max_attempts - maximum number of attempts (default: 3)
#   2 - delay - delay in seconds between retries (default: 2)
#   3 - ignore output - if the third parameter is boolean and is true it
#       indicates that the standard output of the command should be forwarded to
#       $_ignore (usually /dev/null)
#   3+ (or 4+ if $3 is boolean) - command and arguments to execute
# Returns:
#   Exit code: 0 on success, command's exit code after final failure
# Env. Vars:
#   dry_run - when true, displays command without executing it
# Usage: execute_with_retry <max_attempts> <delay> [<ignore output>] <command> [args...]
# Example: execute_with_retry 3 2 true gh api repos/owner/repo
#-------------------------------------------------------------------------------
function execute_with_retry()
{
    if [[ $# -lt 3 ]]; then
        error 3 "${FUNCNAME[0]}() requires at least three arguments: <max_attempts> <delay> <command> [args...]"
        return 2
    fi

    local max_attempts=$1; shift
    local delay=$1; shift
    local output="/dev/stdout"

    # shellcheck disable=SC2086
    is_boolean $1 && $1 && output="$_ignore" && shift

    if [[ $# -lt 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires at least four arguments: <max_attempts> <delay> <ignore output> <command> [args...]"
        return 2
    fi

    local attempt=0
    local exit_code=0

    if [[ "$dry_run" == true ]]; then
        echo "dry-run$ $*" >&2
        return 0
    fi

    local IFS=" "
    trace "Executing with retry (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): $*"
    until "$@" 1>"$output"; do
        exit_code=$?
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            return "$exit_code"
        fi
        warning "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s."
        sleep "$delay"
    done

    return 0
}

#-------------------------------------------------------------------------------
# Summary: Tests if parameter is a valid file pattern and returns matching files, recursing into subdirectories.
# Parameters:
#   1 - file_pattern - glob pattern to match files (supports ** for recursive matching)
# Returns:
#   stdout: space-separated list of matching files
#   Exit code: 0 on success, 2 on invalid arguments
# Usage: files=$(list_of_files <file_pattern>)
# Example:
#   packages=$(list_of_files "artifacts/pack/*.nupkg")
#   for pkg in $packages; do echo "$pkg"; done
# Notes: Returns empty string if no files match pattern.
#-------------------------------------------------------------------------------
function list_of_files()
{
    if [[ $# -lt 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires at least one argument: the file pattern."
        return 2
    fi

    # remember the current settings of the nullglob and globstar options
    local restoreGlobstar restoreNullglob
    restoreGlobstar=$(shopt -p globstar) || true
    restoreNullglob=$(shopt -p nullglob) || true

    # if a glob pattern does not match any files - expand to an empty string
    # enable globstar to allow **/ pattern to match directories and subdirectories recursively
    shopt -s globstar || true
    shopt -s nullglob || true

    local list=("$1")

    # restore the previous settings of the nullglob and globstar options
    eval "$restoreNullglob"
    eval "$restoreGlobstar"

    printf "%s" "${list[*]}"
    return 0
}
