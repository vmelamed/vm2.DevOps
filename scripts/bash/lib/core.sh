# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines a number of general purpose functions by means of sourcing other scripts
# from the same directory. For the functions to be invocable by other scripts, this script
# must be sourced too. When fatal parameter errors are detected, the script invokes exit,
# which leads to exiting the current shell.
#===============================================================================================

#===============================================================================================
# Common scripts variables and environment initialization
#===============================================================================================

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
readonly script_name
readonly script_dir
readonly lib_dir

# source the components of the core library
source "$lib_dir/_constants.sh"
source "$lib_dir/_core_state.sh"
source "$lib_dir/_error_codes.sh"
source "$lib_dir/_predicates.sh"
source "$lib_dir/_predicates_tools.sh"
source "$lib_dir/_diagnostics.sh"
source "$lib_dir/_core_args.sh"
source "$lib_dir/_semver.sh"
source "$lib_dir/_sanitize.sh"
source "$lib_dir/_dump_vars.sh"
source "$lib_dir/_user.sh"
source "$lib_dir/_git.sh"
source "$lib_dir/_git_gh.sh"
source "$lib_dir/_git_vm2.sh"
source "$lib_dir/_xml.sh"
source "$lib_dir/_dotnet_constants.sh"
source "$lib_dir/_dotnet_args.sh"
source "$lib_dir/_dotnet_msbuild.sh"
source "$lib_dir/_dotnet.sh"

declare -x ci
declare -x initial_cwd

declare -x success
declare -x err_logic_error
declare -x err_invalid_arguments
declare -x err_invalid_nameref
declare -x err_argument_type
declare -x err_not_git_directory
declare -x err_argument_value
declare -x err_not_found

declare -x error_em

declare -x default__ignore
declare -x debugger

# Override the default or environment values of common flags based on other flags upon sourcing.
# Make sure that the other set_* functions are honoring the ci flag.
if $ci; then
    # guard CI from quiet off
    _ignore=$default__ignore
    set_quiet
    set +x
fi

declare -xr explicit_exit_regex='^(exit([[:space:]]+.*)?|source[[:space:]]+.*)$'

#-----------------------------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------------------------
# @description ERR trap handler. Reports the failed command to stderr, along with the exit
#    code, and prints a stack trace.
#
# Notes:
#   - Registered automatically by core.sh via `trap on_err ERR` (unless $debugger is true).
#   - Works cooperatively with on_exit, which handles the EXIT trap.
#
# @exitcode N inherited from the failing command (the trap does not change the exit code)
#-----------------------------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------------------------
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
#   - One exception: on EXIT, the command goes before core.sh's report_open_scopes, which must stay
#     last: it exits when a scope was left open, and the commands after it would never run.
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
#-----------------------------------------------------------------------------------------------
function add_trap()
{
    (( $# >= 2 ))                                                               || bug "${FUNCNAME[0]}() requires at least two arguments (provided $#):" \
                                                                                       "  - the command to append" \
                                                                                       "  - one or more signal names" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || -n $1 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 1, the command, to be non-empty." -ec "$err_argument_value"

    local _signal
    for _signal in "${@:2}"; do
        trap -p "$_signal" > /dev/null 2>&1 ||
            bug "${FUNCNAME[0]}() requires the signal names to be valid (provided '$_signal')." -ec "$err_argument_value"
    done
                                                                                exit_if_has_bugs

    local _command=$1
    local -a _current
    local _existing
    shift

    for _signal in "$@"; do
        eval "_current=( $(trap -p "$_signal") )"
        _existing=${_current[2]:-}
        # a newline, not '; ', joins the commands: '; ' breaks after a trailing '&' (syntax error) and
        # after a trailing '# comment' (which would swallow the appended command)
        case ${_signal^^} in
            EXIT|SIGEXIT|0 )
                # keep report_open_scopes last: it exits on a leaked scope, so nothing after it would run
                if [[ $_existing == report_open_scopes || $_existing == *$'\n'report_open_scopes ]]; then
                    trap -- "${_existing%report_open_scopes}$_command"$'\n'"report_open_scopes" "$_signal"
                    continue
                fi
                ;;
            * ) ;;
        esac
        trap -- "${_existing:+$_existing$'\n'}$_command" "$_signal"
    done

    return "$success"
}

# Report the shell-option scopes left open at exit, and fail (see begin_scope in _core_state.sh). Not
# tied to the debugger/CI exceptions above: it does nothing unless a scope leaked, and CI is where a
# leak matters most. add_trap keeps it the last command of the EXIT trap.
$__no_traps || add_trap report_open_scopes EXIT

#-----------------------------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------------------------
function execute()
{
    local _quiet=false
    [[ ${1-} == --quiet ]] && { _quiet=true; shift; }

    (( $# > 0 ))                                                                || bug "${FUNCNAME[0]}() requires the command to execute (and its arguments)." -ec "$err_invalid_arguments"
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

#-----------------------------------------------------------------------------------------------
# @description Executes a command with retry logic for transient failures. In a dry run, a query
#   (specified by the option `--query`) runs as usual; any other command is only printed.
#
# Notes:
#   - The command's stdout is written to the caller's stdout (unless `--quiet`); its stderr
#     always goes to the caller's stderr.
#   - The switches `--query`, `--quiet`, and `--is-transient <predicate>` come before the
#     command, in any order: the first argument that is neither a switch nor a switch's value
#     starts the command, which runs with its arguments unchanged.
#
# @arg $1 int Maximum number of attempts.
# @arg $2 int Delay between attempts, in seconds.
# @option --query The command has no side effects (typically a query): it runs in a dry run too,
#   so the caller gets real data.
# @option --quiet Discards the command's stdout (not its stderr).
# @option --is-transient <predicate> The name of a function that decides whether a failure is
#   worth retrying. It receives three arguments:
#       - the command's exit code
#       - the name of the file holding the command's stdout
#       - the name of the file holding the command's stderr
#   The predicate MUST return:
#       positive=0 if the failure is transient, and the command can be retried
#       negative=1 if the failure is persistent, and retrying would not help
#   Without this option the predicate is `true`: every failure is treated as transient.
# @arg $@ string The command to execute, and its arguments.
#
# @stdout The command's stdout; nothing with `--quiet`, or for a non-query in a dry run.
# @stderr The command's stderr; in a dry run, `dry-run$ <command> <args>` for a non-query.
#
# @exitcode success=0: The command succeeded, or it is a non-query in a dry run (only printed).
# @exitcode err_io_failure=21: A temporary file for the command's output could not be created.
# @exitcode N The command's own exit code, after the final failed attempt.
#
# @example
#   execute_with_retry 3 5 --quiet dotnet nuget push "$package" --source "$source"
# @example
#   # retry only on curl's network errors: 6 (resolve host), 7 (connect), 28 (timeout)
#   function is_curl_transient() { [[ $1 == @(6|7|28) ]]; }
#   status=$(execute_with_retry 3 2 --query --is-transient is_curl_transient curl -fsS https://example.com/status)
#-----------------------------------------------------------------------------------------------
function execute_with_retry()
{
    (( $# >= 3 ))                                                               || bug "${FUNCNAME[0]}() requires at least three arguments (provided $#):" \
                                                                                       "  - maximum number of attempts" \
                                                                                       "  - delay between attempts, in seconds" \
                                                                                       "  - the command to execute" \
                                                                                       "  - [args...] Arguments for the command" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_natural "$1"                                             || bug "${FUNCNAME[0]}() requires argument 1, the maximum attempt count, to be a natural number (provided '${1-<missing>}')." -ec "$err_argument_type"
    [[ ! -v 2 ]] || is_non_negative "$2"                                        || bug "${FUNCNAME[0]}() requires argument 2, the retry delay in seconds, to be a non-negative integer (provided '${2-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs
    local -i _rc="$success"

    # get the attempts and the delay; the switches follow
    local _max_attempts=$1
    local _delay=$2
    shift 2

    local _is_query=false
    local _is_quiet=false
    local _is_transient=true

    while (( $# > 0 )) && [[ $1 == @(--query|--quiet|--is-transient) ]]; do
        [[ $1 == --query ]] && _is_query=true
        [[ $1 == --quiet ]] && _is_quiet=true
        [[ $1 == --is-transient ]] && {
            (( $# > 1 ))                                                        || bug "${FUNCNAME[0]}() option --is-transient MUST be followed by the name of a predicate function that can analyze the output from the command." -ec "$err_missing_argument"
            [[ ! -v 2 ]] || is_function "$2"                                    || bug "${FUNCNAME[0]}() option --is-transient MUST be followed by the name of a predicate function that can analyze the output from the command (provided '${2-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs
            _is_transient=$2
            shift
        }
        shift
    done
    (( $# > 0 ))                                                                || bug "${FUNCNAME[0]}() requires a command to execute, followed by 0 or more arguments." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    is_dry_run && ! $_is_query && {
        printf 'dry-run$'; printf ' %q' "$@"; echo;
        return "$success"
    } >&2

    # stdout and stderr go to temp files to preserve output fidelity (especially newlines), yet still allow us to process them separately
    local _stderr_file=''
    local _stdout_file=''
    _stderr_file=$(mktemp)                                                      || with_error _rc "$err_io_failure" "Failed to create a temporary file"
    (( _rc != success ))   || _stdout_file=$(mktemp)                            || with_error _rc "$err_io_failure" "Failed to create a temporary file"
    (( _rc == success ))                                                        || {
                                                                                        rm -f "$_stderr_file" "$_stdout_file"
                                                                                        return "$_rc"
                                                                                   }

    local IFS=" "
    trace "Executing with retry (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): $*"

    local -i _attempt=0
    local _transient_error

    until "$@" >"$_stdout_file" 2>"$_stderr_file"; do
        _rc=$?

        cat "$_stderr_file" >&2
        (( ++_attempt ))

        $_is_transient "$_rc" "$_stdout_file" "$_stderr_file" &&
            _transient_error=true ||
            _transient_error=false

        if (( _attempt < _max_attempts )) && $_transient_error; then
            # retry and reset rc to success to avoid returning a failure code if the last attempt fails with a transient error
            warning "Transient command failure (attempt $_attempt/$_max_attempts). Retrying in ${_delay}s."
            sleep "$_delay"
            _rc=$success
        else
            if $_transient_error; then
                error "After $_attempt attempts, the command is still failing." -ec "$err_logic_error"
            else
                error "The command failed with the non-transient exit code $_rc." -ec "$err_logic_error"
            fi
            break
        fi
    done

    (( _rc == success )) && cat "$_stderr_file" >&2
    $_is_quiet || cat "$_stdout_file"

    rm -f "$_stderr_file" "$_stdout_file"

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------------------------
function list_of_files()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file pattern." -ec "$err_invalid_arguments"
    [[ ! -v 1 || -n $1 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 1, the file pattern, to be non-empty (provided '${1-<missing>}')." -ec "$err_argument_value"
                                                                                exit_if_has_bugs

    # remember the current settings of the nullglob and globstar options
    begin_scope

    # if a glob pattern does not match any files - expand to an empty string
    # enable globstar to allow **/ pattern to match directories and subdirectories recursively
    set_glob_star true
    set_null_glob true

    # shellcheck disable=SC2206 # intentionally unquoted: this glob-expands $1 into matching files
    local _list=($1)

    printf "%s" "${_list[*]}"

    # restore the previous settings of the nullglob and globstar options
    end_scope
}

#-----------------------------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------------------------
function find_files_by_precedence()
{
    (( $# > 2 ))                                                                || bug "${FUNCNAME[0]}() requires at least 3 arguments (provided $#):" \
                                                                                       "  - path to the repository to search for the file name patterns" \
                                                                                       "  - name of the array variable to store the found file names" \
                                                                                       "  - the file name patterns to search for, in order of precedence" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d "$1" ]]                                                     || bug "${FUNCNAME[0]}() requires a path to a directory (usually a repository root working tree) as the first argument (provided '${1-<missing>}')." -ec "$err_argument_value"
    [[ ! -v 2 ]] || is_indexed_array "$2"                                       || bug "${FUNCNAME[0]}() requires the name of the array variable to store the found file names as the second argument (provided '${2-<missing>}')." -ec "$err_invalid_nameref"
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
