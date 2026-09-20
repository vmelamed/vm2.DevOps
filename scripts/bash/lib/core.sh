# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC1091 # Disable warnings for word splitting and globbing issues in the following source commands.

#=============================================================================================
# This script defines a number of general purpose functions by means of sourcing other scripts from the same directory.
# For the functions to be invocable by other scripts, this script must be sourced.
# When fatal parameter errors are detected, the script invokes exit, which leads to exiting the current shell.
#=============================================================================================

#=============================================================================================
# Common scripts variables and environment initialization
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_CORE_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_CORE_SH_LOADED=1

declare -x script_name
declare -x script_dir
declare -x lib_dir

[[ ! -v script_name    || -z "$script_name"    ]] && script_name=$(basename "${BASH_SOURCE[-1]}")
[[ ! -v script_dir     || -z "$script_dir"     ]] && script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[-1]}")")
[[ ! -v lib_dir        || -z "$lib_dir"        ]] && lib_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")

# variables commonly used for diagnostics
declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# source the components of the core library
source "$lib_dir/_constants.sh"
source "$lib_dir/_core_state.sh"
source "$lib_dir/_error_codes.sh"
source "$lib_dir/_diagnostics.sh"
source "$lib_dir/_args.sh"
source "$lib_dir/_predicates.sh"
source "$lib_dir/_semver.sh"
source "$lib_dir/_sanitize.sh"
source "$lib_dir/_dump_vars.sh"
source "$lib_dir/_user.sh"
source "$lib_dir/_git.sh"
source "$lib_dir/_git_vm2.sh"
source "$lib_dir/_dotnet_args.sh"
source "$lib_dir/_dotnet.sh"

declare -xr ci
declare -xr initial_cwd

declare -xri success
declare -xri err_logic_error
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_not_git_directory
declare -xri err_argument_value

declare -xr default__ignore
declare -xr debugger

# Override the default or environment values of common flags based on other flags upon sourcing.
# Make sure that the other set_* functions are honoring the ci flag.
if $ci; then
    # guard CI from quiet off
    _ignore=$default__ignore
    set_quiet
    set +x
fi

# get_devops_parent cache
declare __devops_parent=''

#---------------------------------------------------------------------------------------------
# @description Returns the parent directory of the vm2.DevOps repository, which is expected to
#   be the parent of ALL vm2.* projects, because, the vm2.DevOps repository should be cloned
#   into the same parent directory as the other vm2.* repositories. This directory is often
#   referred to as $VM2_REPOS, and is used by scripts that operate on multiple vm2.*
#   repositories.
#
# Notes:
#   - The function caches the result in a private variable to avoid repeated computation.
#   - If the script is not located in a Git repository, or if the repository is in a detached
#     HEAD state, the function will exit with an error.
#
# @stdout The absolute path of the parent directory of the vm2.DevOps repository.
# @example
#   parent_dir=$(get_devops_parent)
#---------------------------------------------------------------------------------------------
function get_devops_parent()
{
    if [[ -z $__devops_parent ]]; then
        local _r

        # shellcheck disable=SC2015
        root_working_tree "$lib_dir" _r &&
            __devops_parent=$(dirname "$_r" 2> "$_ignore") || {
                bug -ec "$err_logic_error" "Failed to resolve the parent directory of the vm2.DevOps repo from the script directory '$lib_dir'." \
                                           "Please ensure that the script is located in '$VM2_REPOS/vm2.DevOps/scripts/bash/lib' and" \
                                           "that the repository is not in a detached HEAD state."
                exit_if_has_bugs
            }

        # freeze it!
        readonly __devops_parent
    fi

    echo "$__devops_parent"
}

declare -xr explicit_exit_regex='^(exit([[:space:]]+.*)?|source[[:space:]]+.*)$'

#---------------------------------------------------------------------------------------------
# @description EXIT trap handler. Reports the failed command to stderr (if the shell is
#    exiting with a non-zero, non-explicit exit code), restores the working directory to
#    $initial_cwd, and disables trace mode.
#
# Notes:
#   - Registered automatically by core.sh via `trap on_exit EXIT` (unless $debugger is true).
#   - Works cooperatively with on_err, which handles the ERR trap.
#
# @exitcode success/positive=0: the shell exited cleanly
# @exitcode N inherited from the exiting command (the trap does not change the exit code)
#---------------------------------------------------------------------------------------------
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

#---------------------------------------------------------------------------------------------
# @description ERR trap handler. Reports the failed command to stderr, along with the exit
#    code, and prints a stack trace.
#
# Notes:
#   - Registered automatically by core.sh via `trap on_err ERR` (unless $debugger is true).
#   - Works cooperatively with on_exit, which handles the EXIT trap.
#
# @exitcode N inherited from the failing command (the trap does not change the exit code)
#---------------------------------------------------------------------------------------------
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


declare __no_traps=false

[[ -v 1 && -n $1 && ${1,,} == "--no-trap" ]] && __no_traps=true

# By default all scripts trap DEBUG and EXIT to provide some feed back for unexpected exits.
# To suppress the traps use the `--no-trap` command-line argument when you source core.sh.
# Traps are also suppressed when running under a debugger or in a CI environment.
if ! $__no_traps && ! $debugger && ! $ci; then
    # set the traps to see the last faulted command. However, they get in the way of debugging.
    trap on_err ERR
    trap on_exit EXIT
fi

#---------------------------------------------------------------------------------------------
# @description Removes the ERR and EXIT traps set by core.sh.
#   - Useful when the expected errors are handled already.
#---------------------------------------------------------------------------------------------
function remove_traps()
{
    trap - ERR
    trap - EXIT
}

#---------------------------------------------------------------------------------------------
# @description Depending on the value of $dry_run, either executes the given command or prints
#    what would have been executed, without running it.
#
# @arg $1 string the command to execute
# @arg $@ mixed additional arguments to pass to the command (optional)
#
# @exitcode success/positive=0: The command succeeded, or dry-run mode was active (command not
#   executed).
# @exitcode N the executed command's own exit code, on failure
#
# @stdout in dry-run mode: "dry-run$ <command> [args...]"; otherwise whatever the executed
#    command writes to stdout
#
# @example
#   execute git commit -m "Initial commit"
#---------------------------------------------------------------------------------------------
function execute()
{
    (( $# > 0 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least one argument (provided $#): the command to execute and the arguments."

    exit_if_has_bugs

    if is_dry_run; then
        echo "dry-run$ $*"
        return 0
    fi

    trace "Executing (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): $*"
    "$@"
}

#---------------------------------------------------------------------------------------------
# @description Executes a command, retrying on failure until it succeeds or the maximum number
#    of attempts is reached, with a fixed delay between attempts.
#
# Notes:
#   - $1 and $2 are always max_attempts and delay; there is no default when the arguments are
#     omitted -- at least three arguments are required.
#   - If $3 is a valid boolean ('true' or 'false') it is consumed as the "ignore output" flag:
#     when 'true', the command's `stdout` is redirected to `$_ignore` instead of the terminal.
#     If $3 is not a boolean, it is treated as the start of the command to execute.
#
# @arg $1 int max_attempts - maximum number of attempts
# @arg $2 int delay - delay in seconds between retries
# @arg $3 bool ignore output - if boolean, redirect the command's stdout to
#    `$_ignore` when true (optional)
# @arg $@ mixed command and arguments to execute
#
# @exitcode success/positive=0: The command succeeded (including dry-run mode, where the
#   command is not executed).
# @exitcode N the command's own exit code, after the final failed attempt
#
# @stdout whatever the executed command writes to stdout, unless redirected to $_ignore per
#   the "ignore output" flag; in dry-run mode, nothing is written to stdout --
#   "dry-run$ <command> [args...]" is written to stderr instead
#
# @example
#   execute_with_retry 3 2 true gh api repos/owner/repo
#---------------------------------------------------------------------------------------------
function execute_with_retry()
{
    local -i _rc=$success

    (( $# >= 3 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least three arguments (provided $#):" \
                                                                        "  - maximum number of attempts" \
                                                                        "  - delay in seconds between retries" \
                                                                        "  - if present, boolean flag to suppress the output, optional" \
                                                                        "  - command and arguments to execute"
    [[ ! -v 1 ]] || is_natural "$1" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 1, the maximum attempt count, to be a natural number (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_natural "$2" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 2, the retry delay in seconds, to be a natural number (provided '${2:-<none>}')."

    local _max_attempts=$1; shift
    local _delay=$1; shift
    local _output="/dev/stdout"

    # shellcheck disable=SC2086
    is_boolean "$1" && $1 && _output="$_ignore"
    is_boolean "$1" && shift

    (( $# >= 1 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a command after the maximum-attempt, the delay arguments, and the optional output-suppression flag."

    exit_if_has_bugs

    local _attempt=0

    if is_dry_run; then
        echo "dry-run$ $*" >&2
        return "$success"
    fi

    local IFS=" "
    trace "Executing with retry (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): $*"
    until "$@" 1>"$_output"; do
        _rc=$?
        _attempt=$((_attempt + 1))
        if [[ $_attempt -ge $_max_attempts ]]; then
            return "$_rc"
        fi
        warning "Command failed (attempt $_attempt/$_max_attempts). Retrying in ${_delay}s."
        sleep "$_delay"
    done
}

#---------------------------------------------------------------------------------------------
# @description Expands a glob pattern (with globstar and nullglob enabled) and returns the
#    matching files as a space-separated list. The globstar option lets "**" match files
#    recursively across subdirectories.
#
# Notes:
#   - Prints an empty string if no files match the pattern.
#
# @arg $1 string file_pattern - glob pattern to match files (supports ** for recursive
#    matching)
#
# @stdout space-separated list of matching files (empty if none match)
#
# @example
#   packages=$(list_of_files "artifacts/packages/*.nupkg")
#   for pkg in $packages; do echo "$pkg"; done
#---------------------------------------------------------------------------------------------
function list_of_files()
{
    (( $# == 1 ))         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file pattern."
    [[ ! -v 1 || -n $1 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the file pattern, to be non-empty (provided '${1:-<none>}')."

    exit_if_has_bugs

    # remember the current settings of the nullglob and globstar options
    # shellcheck disable=SC2034 # state appears unused. Verify use (or export if used externally).
    local -A state=()
    save_state state

    # if a glob pattern does not match any files - expand to an empty string
    # enable globstar to allow **/ pattern to match directories and subdirectories recursively
    set_glob_star true
    set_null_glob true

    local _list=("$1")

    printf "%s" "${_list[*]}"

    # restore the previous settings of the nullglob and globstar options
    restore_state state
}
