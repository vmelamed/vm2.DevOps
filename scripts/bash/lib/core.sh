# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC1091 # Disable warnings for word splitting and globbing issues in the following source commands.

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
declare -x initial_cwd
declare __devops_parent=""

[[ ! -v script_name    || -z "$script_name"    ]] && script_name=$(basename "${BASH_SOURCE[-1]}")
[[ ! -v script_dir     || -z "$script_dir"     ]] && script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[-1]}")")
[[ ! -v lib_dir        || -z "$lib_dir"        ]] && lib_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
initial_cwd=$(pwd)

# variables commonly used for diagnostics
declare -rx script_name
declare -rx script_dir
declare -rx lib_dir
declare -rx initial_cwd

declare -rx default__ignore=/dev/null
declare -x _ignore=$default__ignore
# Use $_ignore to redirect unwanted output, e.g. errors from commands or tools, to avoid cluttering the terminal or logs. When
# you need to see the output for debugging purposes, you can redirect $_ignore to /dev/stderr, but NEVER redirect it to /dev/stdout!
# If it is redirected to stdout AND the output of the whole command is captured or redirected, it will interfere with the
# expected output of the command, leading to incorrect results or unexpected behavior. Therefore NEVER assign a file to $_ignore
# directly. Use the functions below to manipulate it.

# source the components of the core library
source "$lib_dir/_error_codes.sh"
source "$lib_dir/_constants.sh"
source "$lib_dir/_diagnostics.sh"
source "$lib_dir/_args.sh"
source "$lib_dir/_predicates.sh"
source "$lib_dir/_dump_vars.sh"
source "$lib_dir/_semver.sh"
source "$lib_dir/_user.sh"
source "$lib_dir/_git.sh"
source "$lib_dir/_sanitize.sh"
source "$lib_dir/_dotnet.sh"

declare -xr ci

declare -xr debugger
declare -xr success=0
declare -xr err_logic_error
declare -xr err_invalid_arguments
declare -xr err_argument_type
declare -xr err_not_git_directory
declare -xr err_argument_value
declare -xr dry_run

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
            error -sd 3 -ec "$err_logic_error" "Failed to resolve parent directory of the vm2.DevOps repo from the script directory '$lib_dir'." \
                                               "Please ensure that the script is located in 'vm2.DevOps/scripts/bash/lib' and that the repository is not in a detached HEAD state."
            exit "$err_not_git_directory"
        }

        # freeze it!
        readonly __devops_parent
    fi

    echo "$__devops_parent"
    return "$success"
}


#-------------------------------------------------------------------------------
# @description EXIT trap handler. Reports the failed command to stderr (if the shell is exiting with a non-zero, non-explicit
# exit code), restores the working directory to $initial_cwd, and disables trace mode.
#
# Notes:
#   - Registered automatically by core.sh via `trap on_exit EXIT` (unless $debugger is true).
#   - Works cooperatively with on_err, which handles the ERR trap.
#
# @exitcode 0 the shell exited cleanly
# @exitcode N inherited from the exiting command (the trap does not change the exit code)
#-------------------------------------------------------------------------------
declare -xr explicit_exit_regex='^(exit([[:space:]]+.*)?|source[[:space:]]+.*)$'
function on_exit()
{
    local _ec=$?

    set +x
    if (( _ec != "$success" )) && [[ ! ${BASH_COMMAND:-} =~ $explicit_exit_regex ]]; then
        printf "❌  EXIT: the command '%s' failed with exit code %d\n" "${BASH_COMMAND:-<unknown>}" "$_ec" >&2
    fi

    cd "$initial_cwd" 2>/dev/null || true
    return "$_ec"
}

function on_err()
{
    local -i _rc=$?

    {
        echo "❌ ON ERROR post-mortem:"
        echo "  - exit code: $_rc;"
        echo "  - command:   '$BASH_COMMAND';"
        echo "  - stack:"
        show_stack 2 12 true
    } >&2
    return "$_rc"
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
# @description Redirects the ignored output (held in $_ignore) to the specified file. With no argument, redirects it to
# /dev/stderr so that output normally discarded becomes visible for debugging.
#
# Notes:
#   - Redirecting to /dev/stdout is allowed but triggers a warning, since it can corrupt the output of any command whose
#     stdout is captured or redirected.
#
# @arg $1 string file to redirect the ignored output to (optional, default: /dev/stderr)
#
# @exitcode 0 success
# @exitcode 2 invalid arguments ($err_invalid_arguments)
#
# @example
#   show_ignored_output /dev/stdout
#-------------------------------------------------------------------------------
function show_ignored_output()
{
    (( $# <= 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() accepts at most one argument (provided $#): the file name to redirect the ignored output to."
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
# @description Restores the ignored output (held in $_ignore) to /dev/null.
#-------------------------------------------------------------------------------
function hide_ignored_output()
{
    _ignore=/dev/null
}

#-------------------------------------------------------------------------------
# @description Depending on the value of $dry_run, either executes the given command or prints what would have been
# executed, without running it.
#
# @arg $1 string the command to execute
# @arg $@ mixed additional arguments to pass to the command (optional)
#
# @exitcode 0 success, or dry-run mode (command not executed)
# @exitcode 2 invalid arguments ($err_invalid_arguments)
# @exitcode N the executed command's own exit code, on failure
#
# @stdout in dry-run mode: "dry-run$ <command> [args...]"; otherwise whatever the executed command writes to stdout
#
# @example
#   execute git commit -m "Initial commit"
#-------------------------------------------------------------------------------
function execute()
{
    (( $# > 0 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least one argument (provided $#): the command to execute."
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
# @description Executes a command, retrying on failure until it succeeds or the maximum number of attempts is reached, with a
# fixed delay between attempts.
#
# Notes:
#   - $1 and $2 are always max_attempts and delay; there is no default when the arguments are omitted -- at least three
#     arguments are required.
#   - If $3 is a valid boolean ('true' or 'false') it is consumed as the "ignore output" flag: when 'true', the command's
#     stdout is redirected to $_ignore instead of the terminal. If $3 is not a boolean, it is treated as the start of the
#     command to execute.
#
# @arg $1 int max_attempts - maximum number of attempts
# @arg $2 int delay - delay in seconds between retries
# @arg $3 bool ignore output - if boolean, redirect the command's stdout to $_ignore when true (optional)
# @arg $@ mixed command and arguments to execute
#
# @exitcode 0 success (including dry-run mode, where the command is not executed)
# @exitcode 2 invalid arguments ($err_invalid_arguments)
# @exitcode N the command's own exit code, after the final failed attempt
#
# @stdout whatever the executed command writes to stdout, unless redirected to $_ignore per the "ignore output" flag; in
#   dry-run mode, nothing is written to stdout -- "dry-run$ <command> [args...]" is written to stderr instead
#
# @example
#   execute_with_retry 3 2 true gh api repos/owner/repo
#-------------------------------------------------------------------------------
function execute_with_retry()
{
    local -i _rc=$success

    (( $# >= 3 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires at least three arguments (provided $#): <max_attempts> <delay> <command> [args...]"
    }
    [[ -v 1 ]] && is_natural "$1" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the maximum attempt count, to be a natural number (provided '${1-<missing>}')."
    }
    [[ -v 2 ]] && is_natural "$2" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the retry delay in seconds, to be a natural number (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _max_attempts=$1; shift
    local _delay=$1; shift
    local _output="/dev/stdout"

    # shellcheck disable=SC2086
    is_boolean "$1" && $1 && _output="$_ignore"
    is_boolean "$1" && shift

    (( $# >= 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires a command after the maximum-attempt and delay arguments and the optional output-suppression flag."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _attempt=0
    local _exit_code=0

    if [[ "$dry_run" == true ]]; then
        echo "dry-run$ $*" >&2
        return "$success"
    fi

    local IFS=" "
    trace "Executing with retry (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): $*"
    until "$@" 1>"$_output"; do
        _exit_code=$?
        _attempt=$((_attempt + 1))
        if [[ $_attempt -ge $_max_attempts ]]; then
            return "$_exit_code"
        fi
        warning "Command failed (attempt $_attempt/$_max_attempts). Retrying in ${_delay}s."
        sleep "$_delay"
    done

    return "$success"
}

#-------------------------------------------------------------------------------
# @description Expands a glob pattern (with globstar and nullglob enabled) and returns the matching files as a
# space-separated list. The globstar option lets "**" match files recursively across subdirectories.
#
# Notes:
#   - Prints an empty string if no files match the pattern.
#   - The previous nullglob/globstar shopt settings are restored before the function returns.
#
# @arg $1 string file_pattern - glob pattern to match files (supports ** for recursive matching)
#
# @exitcode 0 success
# @exitcode 2 invalid arguments ($err_invalid_arguments)
#
# @stdout space-separated list of matching files (empty if none match)
#
# @example
#   packages=$(list_of_files "artifacts/packages/*.nupkg")
#   for pkg in $packages; do echo "$pkg"; done
#-------------------------------------------------------------------------------
function list_of_files()
{
    local -i _rc=$success

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file pattern."
    }
    [[ -v 1 && -n $1 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the file pattern, to be non-empty (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    # remember the current settings of the nullglob and globstar options
    local _restoreGlobstar _restoreNullglob
    _restoreGlobstar=$(shopt -p globstar) || true
    _restoreNullglob=$(shopt -p nullglob) || true

    # if a glob pattern does not match any files - expand to an empty string
    # enable globstar to allow **/ pattern to match directories and subdirectories recursively
    shopt -s globstar || true
    shopt -s nullglob || true

    local _list=("$1")

    # restore the previous settings of the nullglob and globstar options
    eval "$_restoreNullglob"
    eval "$_restoreGlobstar"

    printf "%s" "${_list[*]}"
    return "$success"
}
