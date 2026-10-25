# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#=============================================================================================
# This script defines a number of general purpose functions by means of sourcing other scripts
# from the same directory. For the functions to be invocable by other scripts, this script
# must be sourced too. When fatal parameter errors are detected, the script invokes exit,
# which leads to exiting the current shell.
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
source "$lib_dir/_predicates.sh"
source "$lib_dir/_diagnostics.sh"
source "$lib_dir/_core_args.sh"
source "$lib_dir/_semver.sh"
source "$lib_dir/_sanitize.sh"
source "$lib_dir/_dump_vars.sh"
source "$lib_dir/_user.sh"
source "$lib_dir/_git.sh"
source "$lib_dir/_git_vm2.sh"
source "$lib_dir/_xml.sh"
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
declare -xri err_not_found

declare -xr error_em

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
# @stderr report of the failed command and exit code
#
# @exitcode success=0: the shell exited cleanly
# @exitcode N inherited from the exiting command (the trap does not change the exit code)
#---------------------------------------------------------------------------------------------
function on_exit()
{
    # capture the exit code from the exiting command
    local -i _ec=$?

    # nothing here, or in the cleanups add_trap appended after this function,
    # is a new error to report: on_err has reported the real one already
    trap '' ERR

    # disable tracing;
    # and errexit, so a failing cleanup appended by add_trap does not cut off the ones after it
    set +x +e

    if (( _ec != "$success" )) && [[ ! ${BASH_COMMAND:-} =~ $explicit_exit_regex ]]; then
        # report the failed command and the exit code on stderr
        printf "$error_em  EXIT: the command '%s' failed with exit code %d\n" "${BASH_COMMAND:-<unknown>}" "$_ec" >&2
    fi

    # restore the initial cwd before exiting
    cd "$initial_cwd" 2>/dev/null || true

    # the shell exits with $_ec anyway (bash keeps the status it had when the EXIT trap started); returning it would
    # only stop the trap, under set -e, before the cleanups that add_trap appended after this function
    return 0
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
        printf "$error_em  ON ERROR post-mortem:
        - exit code: %s
        - command:   '%s'
        - call stack:\n" "$_rc" "$BASH_COMMAND"
        show_stack 1 12
    } >&2

    return "$success"
}

declare __no_traps=false

[[ -v 1 && -n $1 && ${1,,} == "--no-trap" ]] && __no_traps=true

# By default all scripts trap DEBUG and EXIT to provide some feed back for unexpected exits.
# To suppress the traps use the `--no-trap` command-line argument when you source core.sh.
# Traps are also suppressed when running under a debugger or in a CI environment.
if ! $__no_traps && ! $debugger && ! $ci; then
    # set the traps to see the last faulted command. However, they get in the way of debugging.
    # errtrace (-E): functions, command substitutions, and subshells inherit the ERR trap -- without it, a failure inside
    # a function (where most of the work happens) never reaches on_err, and the post-mortem with its call stack is lost
    set -o errtrace
    trap on_err ERR
    trap on_exit EXIT
fi

#---------------------------------------------------------------------------------------------
# @description Appends a command to the current trap of one or more signals (e.g. after core.sh's
#    on_exit), instead of replacing it as a plain `trap` does.
#
# Notes:
#   - `trap -p` prints the trap as a re-readable shell command (`trap -- '<command>' SIGNAL`),
#     quoted by bash itself (a `'` inside the command comes out as `'\''`), so eval-ing it into an
#     array safely recovers the command as element 2. Inside $( ... ) bash still reports the
#     current shell's traps.
#   - Appends, never prepends: on_exit and on_err read `$?` in their first statement. The script's
#     exit code is preserved regardless of what the appended command returns.
#   - Single-quote the command to delay expansion until the trap fires (see the example).
#   - Traps belong to the current shell: called inside $( ... ) or a pipeline, it changes only that
#     subshell's trap.
#
# @arg $1 string The command to append.
# @arg $@ string One or more signal names (e.g. EXIT, INT).
#
# @exitcode success=0: Always (invalid arguments bug-exit).
#
# @example
#   add_trap "rm -f ${summary_file@Q}" EXIT
#---------------------------------------------------------------------------------------------
function add_trap()
{
    (( $# >= 2 ))         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least two arguments (provided $#):" \
                                                              "  - the command to append" \
                                                              "  - one or more signal names"
    [[ ! -v 1 || -n $1 ]] || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the command, to be non-empty."

    local _signal
    for _signal in "${@:2}"; do
        trap -p "$_signal" > /dev/null 2>&1 ||
            bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires the signal names to be valid (provided '$_signal')."
    done

    exit_if_has_bugs

    local _command=$1
    local -a _current
    shift

    for _signal in "$@"; do
        eval "_current=( $(trap -p "$_signal") )"
        # a newline, not '; ', joins the commands: '; ' breaks after a trailing '&' (syntax error) and
        # after a trailing '# comment' (which would swallow the appended command)
        trap -- "${_current[2]:+${_current[2]}$'\n'}$_command" "$_signal"
    done

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Depending on the value of $dry_run, either executes the given command or prints
#    what would have been executed, without running it. If the first argument is '--quiet',
#    the command's output is discarded unless verbose mode is on.
#
# @arg $1 string optional literal flag '--quiet': discard the command's stdout and stderr
#   unless verbose mode is on. DO NOT USE IT when the caller redirects or captures the output.
# @arg $@ mixed the command to execute and its arguments (after the optional '--quiet').
#
# @exitcode success=0: The command succeeded, or dry-run mode was active (command not
#   executed).
# @exitcode N the executed command's own exit code, on failure
#
# @stderr in dry-run mode: "dry-run$ <command> [args...]" (arguments quoted with %q) -- on
#   stderr, so a caller capturing stdout ('x=$(execute ...)', '> file') never receives it as data
# @stdout whatever the executed command writes (both of its streams are discarded with
#   '--quiet' unless verbose mode is on)
#
# @example
#   execute git commit -m "Initial commit"
#   execute --quiet dotnet clean "$project"
#
#   * Note: an anti-pattern:
#   execute --quiet ls > "current-directory-contents.txt"
#   # the '--quiet' flag suppresses the output, so redirecting it to a file defeats the
#   # purpose of using '--quiet'.
#---------------------------------------------------------------------------------------------
function execute()
{
    local _quiet=false
    [[ ${1-} == --quiet ]] && { _quiet=true; shift; }

    (( $# > 0 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires the command to execute (and its arguments)."
    exit_if_has_bugs

    local _command
    printf -v _command '%q ' "$@"
    _command=${_command% }

    if is_dry_run; then
        echo "dry-run$ $_command" >&2
        return "$success"
    fi

    trace "Executing (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): $_command"
    if $_quiet && ! is_verbose; then
        "$@" > "$_ignore" 2>&1
    else
        "$@"
    fi
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
#   - Consequence of the above: a command whose own name is literally 'true' or 'false' can
#     never be retried -- it is always consumed as the output-suppression flag instead,
#     leaving no command and causing an argument-count bug-exit. This is accepted, not a bug
#     to fix: nothing sane would ever retry the literal command 'true' (always succeeds,
#     retrying is pointless) or 'false' (always fails identically, so every retry is wasted).
#     If a real command ever needs that exact name, wrap it (`bash -c true`) to sidestep the
#     ambiguity.
#
# @arg $1 int `_max_attempts` - maximum number of attempts
# @arg $2 int `_delay` - delay in seconds between retries
# @arg $3 bool ignore output - if boolean, redirect the command's stdout to
#    `$_ignore` when true (optional)
# @arg $@ mixed command and arguments to execute
#
# @exitcode success=0: The command succeeded (including dry-run mode, where the
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
    (( $# >= 3 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least three arguments (provided $#):" \
                                                                        "  - maximum number of attempts" \
                                                                        "  - delay in seconds between retries" \
                                                                        "  - if present, boolean flag to suppress the output, optional" \
                                                                        "  - command and arguments to execute"
    [[ ! -v 1 ]] || is_natural "$1" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 1, the maximum attempt count, to be a natural number (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || is_natural "$2" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 2, the retry delay in seconds, to be a natural number (provided '${2-<missing>}')."

    local -i _max_attempts=$1; shift
    local -i _delay=$1; shift
    local _output="/dev/stdout"

    # shellcheck disable=SC2086
    is_boolean "$1" && $1 && _output="$_ignore"
    is_boolean "$1" && shift

    (( $# >= 1 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a command after the maximum-attempt, the delay arguments, and the optional output-suppression flag."
    exit_if_has_bugs

    if is_dry_run; then
        echo "dry-run$ $*" >&2
        return "$success"
    fi

    local IFS=" "
    trace "Executing with retry (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): $*"

    local -i _rc=$success
    local -i _attempt=0
    until "$@" 1>"$_output"; do
        _rc=$?
        (( ++_attempt < _max_attempts )) || return "$_rc"
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
# @exitcode success=0: The glob was expanded and printed (always, once past the argument
#   validation gate).
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
    [[ ! -v 1 || -n $1 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the file pattern, to be non-empty (provided '${1-<missing>}')."

    exit_if_has_bugs

    # remember the current settings of the nullglob and globstar options
    # shellcheck disable=SC2034 # state appears unused. Verify use (or export if used externally).
    local -A state=()
    save_state state

    # if a glob pattern does not match any files - expand to an empty string
    # enable globstar to allow **/ pattern to match directories and subdirectories recursively
    set_glob_star true
    set_null_glob true

    # shellcheck disable=SC2206 # intentionally unquoted: this glob-expands $1 into matching files
    local _list=($1)

    printf "%s" "${_list[*]}"

    # restore the previous settings of the nullglob and globstar options
    restore_state state
}

#---------------------------------------------------------------------------------------------
# @description Finds the files matching the first of the given file name patterns that matches
#   anything in a directory (usually the working tree of a repository) in a specified
#   precedence order, e.g., if the precedence order of patterns is
#   ('*.slnx' '*.sln' '*.csproj'), it will:
#   1. search for *.slnx files
#   2. if none are found, searches for *.sln files
#   3. if none are found, searches for *.csproj files
#   Excluded from the search are the '.git', 'obj', 'bin', and 'templates' sub-directories.
#
# @arg $1 The path to a directory (usually the working tree of a repository) to search for
#   file name patterns.
# @arg $2 The name of the array variable to store the found file names.
# @arg $3..$@ The priority order of sought file name patterns.
#
# @exitcode success=0: Files with names matching the specified name patterns were found and
#   stored in the specified array variable.
# @exitcode err_not_found=9: No files with names matching the specified name patterns were
#   found in the specified directory.
#---------------------------------------------------------------------------------------------
function find_files_by_precedence()
{
    (( $# > 2 ))                          || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least 3 arguments (provided $#):" \
                                                                              "  - path to the repository to search for the file name patterns" \
                                                                              "  - name of the array variable to store the found file names" \
                                                                              "  - the file name patterns to search for, in order of precedence"
    [[ ! -v 1 || -d "$1" ]]               || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires a path to a directory (usually a repository root working tree) as the first argument (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || is_indexed_array "$2" || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires the name of the array variable to store the found file names as the second argument (provided '${2-<missing>}')."
    exit_if_has_bugs

    local _dir=$1
    local -n __file_names=$2
    local __patterns=("${@:3}")
    local __pattern

    __file_names=()

    for __pattern in "${__patterns[@]}"; do
        readarray -t __file_names < <(find "$_dir" -mindepth 1 \( -name .git -o -name bin -o -name obj -o -name templates \) -prune -o -type f -name "$__pattern" -print)
        (( ${#__file_names[@]} == 0 )) || return "$success"
    done

    return "$err_not_found"
}
