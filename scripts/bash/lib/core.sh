# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines a number of general purpose functions by means of sourcing other scripts from the same directory.
# For the functions to be invocable by other scripts, this script must be sourced.
# When fatal parameter errors are detected, the script invokes exit, which leads to exiting the current shell.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Common scripts variables and environment initialization
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_CORE_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_CORE_SH_LOADED=1

declare -x script_name
declare -x script_dir
declare -x lib_dir
declare -x initial_dir
declare __devops_parent=""

[[ ! -v script_name    || -z "$script_name"    ]] && script_name=$(basename "${BASH_SOURCE[-1]}")
[[ ! -v script_dir     || -z "$script_dir"     ]] && script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[-1]}")")
[[ ! -v lib_dir        || -z "$lib_dir"        ]] && lib_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
initial_dir=$(pwd)

# variables commonly used for diagnostics
declare -rx script_name
declare -rx script_dir
declare -rx lib_dir
declare -rx initial_dir

declare -rx default__ignore=/dev/null
declare -x _ignore=$default__ignore
# Use $_ignore to redirect unwanted output, e.g. errors from commands or tools, to avoid cluttering the terminal or logs. When
# you need to see the output for debugging purposes, you can redirect $_ignore to /dev/stderr, but NEVER redirect it to /dev/stdout!
# If it is redirected to stdout AND the output of the whole command is captured or redirected, it will interfere with the
# expected output of the command, leading to incorrect results or unexpected behavior. Therefore NEVER assign a file to $_ignore
# directly. Use the functions below to manipulate it.

# source the components of the core library
source "${lib_dir}/_error_codes.sh"
source "${lib_dir}/_constants.sh"
source "${lib_dir}/_diagnostics.sh"
source "${lib_dir}/_args.sh"
source "${lib_dir}/_predicates.sh"
source "${lib_dir}/_dump_vars.sh"
source "${lib_dir}/_semver.sh"
source "${lib_dir}/_user.sh"
source "${lib_dir}/_git.sh"
source "${lib_dir}/_sanitize.sh"

trace "We are running in CI mode: $ci"
# Override the default or environment values of common flags based on other flags upon sourcing.
# Make sure that the other set_* functions are honoring the ci flag.
if $ci; then
    # guard CI from quiet off
    _ignore=$default__ignore
    set_quiet
    set_table_format markdown
    set +x
else
    set_table_format "${DUMP_FORMAT:-graphical}"      # on terminal, default to graphical format unless overridden by DUMP_FORMAT
fi

function get_devops_parent()
{
    if [[ -z $__devops_parent ]]; then
        r=$(root_working_tree "$lib_dir") && __devops_parent=$(dirname "$r" 2> "$_ignore") || {
            error -ec "$err_logic_error" -sd 3 "Failed to resolve parent directory of the vm2.DevOps repo from the script directory '$lib_dir'. Please ensure that the script is located in 'vm2.DevOps/scripts/bash/lib' and that the repository is not in a detached HEAD state."
            exit "$err_not_git_directory"
        }

        # freeze it!
        readonly __devops_parent
    fi

    echo "$__devops_parent"
    return "$success"
}


#-------------------------------------------------------------------------------
# Summary: EXIT trap handler that displays failed commands, restores directory, and disables tracing.
# Parameters: none
# Returns:
#   stderr: error message if exit code is non-zero and not from explicit exit command
#   Exit code: inherits from the exiting command
# Side Effects:
#   - Changes directory to $initial_dir
#   - Disables trace mode (set +x)
# Env. Vars:
#   initial_dir - directory to restore on exit
# Usage: trap on_exit EXIT
# Notes: Works cooperatively with on_debug for error handling. Automatically set by core.sh.
#-------------------------------------------------------------------------------
declare -xr explicit_exit_regex='^(exit([[:space:]]+.*)?|source[[:space:]]+.*)$'
function on_exit()
{
    local ec=$?

    set +x
    if (( ec != "$success" )) && [[ ! ${BASH_COMMAND:-} =~ $explicit_exit_regex ]]; then
        printf "❌  EXIT: the command '%s' failed with exit code %d\n" "${BASH_COMMAND:-<unknown>}" "$ec" >&2
    fi

    cd "$initial_dir" 2>/dev/null || true
    return "$ec"
}

function on_err()
{
    local rc=$?

    echo "❌  ERR: rc=$rc cmd='$BASH_COMMAND' stack:" >&2
    show_stack 2 12 true >&2
    return "$rc"
}

# By default all scripts trap DEBUG and EXIT to provide better error handling.
# However, when running under a debugger, e.g. 'bashdb', trapping these signals
# interferes with the debugging session.
if ! $debugger; then
    # set the traps to see the last faulted command. However, they get in the way of debugging.
    trap on_err ERR
    trap on_exit EXIT
fi

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
    (( $# <= 1 )) || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() accepts at most one argument (provided $#): the file name to redirect the ignored output to."
        return "$err_invalid_arguments"
    }

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
function execute()
{
    (( $# > 0 )) || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() requires at least one argument (provided $#): the command to execute."
        return "$err_invalid_arguments"
    }

    if is_dry_run; then
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
    (( $# >= 3 )) || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() requires at least three arguments (provided $#): <max_attempts> <delay> <command> [args...]"
        return "$err_invalid_arguments"
    }

    local max_attempts=$1; shift
    local delay=$1; shift
    local output="/dev/stdout"

    # shellcheck disable=SC2086
    is_boolean "$1" && $1 && output="$_ignore"
    is_boolean "$1" && shift

    (( $# >= 1 )) || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() requires at least four arguments (provided $#): <max_attempts> <delay> <ignore output> <command> [args...]"
        return "$err_invalid_arguments"
    }

    local attempt=0
    local exit_code=0

    if [[ "$dry_run" == true ]]; then
        echo "dry-run$ $*" >&2
        return "$success"
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

    return "$success"
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
    (( $# >= 1 )) || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() requires at least one argument (provided $#): the file pattern."
        return "$err_invalid_arguments"
    }

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
    return "$success"
}
