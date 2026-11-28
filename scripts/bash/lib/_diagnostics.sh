# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_DIAGNOSTICS_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DIAGNOSTICS_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_not_overridden
declare -x err_invalid_nameref
declare -x err_argument_type
declare -x err_has_bugs
declare -x err_has_errors

# vm2 core lib constants
declare -x fatal_em
declare -x bug_em
declare -x error_em
declare -x warn_em
declare -x info_em
declare -x trace_em

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║ IMPORTANT: The tee_* functions are designed to be used on the RIGHT side   ║
# ║ of a pipe. Never pipe a function that SETS VARIABLES into one of them.     ║
# ║ The left side of a pipe runs in a subshell — all variable assignments are  ║
# ║ lost. Use two separate lines instead.                                      ║
# ║                                                                            ║
# ║ DO NOT:                                                                    ║
# ║     warning_var x "msg" "default" | tee_stdout                             ║
# ║     # assigns "default" to x in a subshell. The side effect is lost on     ║
# ║     #  the next line.                                                      ║
# ║                                                                            ║
# ║ IT IS OK:                                                                  ║
# ║       x="default"                                                          ║
# ║       echo "msg" | tee_stdout                                              ║
# ║                                                                            ║
# ╚════════════════════════════════════════════════════════════════════════════╝

#-----------------------------------------------------------------------------------------------
# @description Reads lines from stdin, echoing each to stdout. Creates an abstraction,
#   designed to be overridden in other scripts to redirect to alternate destination(s), e.g.,
#   stdout (the GitHub Actions log file) and the GitHub Actions step summary file.
#
# Notes:
#   - Can be overridden in scripts like `gh_core.sh` to redirect to the GitHub Actions step
#     summary
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @exitcode success=0: Every line from stdin was echoed (always).
#
# @stdout string each line read from stdin unchanged.
#
# @example
#   echo "Build completed" | tee_stdout
#-----------------------------------------------------------------------------------------------
function tee_stdout()
{
    local _line

    while IFS= read -r _line || [[ -n $_line ]]; do
        echo "$_line"
    done
}

#-----------------------------------------------------------------------------------------------
# @description Reads lines from stdin, echoing each to stderr. Creates an abstraction,
#   designed to be overridden in other scripts to redirect to alternate destination(s), e.g.,
#   stdout (the GitHub Actions log file) and the GitHub Actions output file.
#
# Notes:
#   - Can be overridden in scripts like `gh_core.sh` to redirect to the GitHub Actions step
#     summary
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @exitcode success=0: Every line from stdin was echoed (always).
#
# @stderr string each line read from stdin unchanged.
#
# @example
#   echo "Warning: file not found" | tee_stderr
#-----------------------------------------------------------------------------------------------
function tee_stderr()
{
    local _line

    while IFS= read -r _line || [[ -n $_line ]]; do
        echo "$_line" >&2
    done
}

#-----------------------------------------------------------------------------------------------
# @description Reads lines from stdin, echoing each to /dev/stdout. Creates an abstraction,
#   designed to be overridden in other scripts to redirect to alternate destination(s), e.g.,
#   to the GitHub Actions output file.
#
# Notes:
#   - Can be overridden in scripts like `gh_core.sh` to redirect to the GitHub Actions step
#     summary
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @exitcode success=0: Every line from stdin was echoed (always).
#
# @stdout string each line read from stdin unchanged.
#
# @example
#   echo "version=1.2.3" | tee_output
#-----------------------------------------------------------------------------------------------
function tee_output()
{
    local _line
    while IFS= read -r _line || [[ -n $_line ]]; do
        echo "$_line"
    done
}
declare -xa __summary_output

#-----------------------------------------------------------------------------------------------
# @description Logs one or more summary messages with a `## Summary` markdown heading, via
# `__summary_output` — so, if glow is installed, the summary will be pretty-printed using
#   glow; otherwise, it will be sent to `tee_stdout` as a markdown. Creates an abstraction,
#   designed to be overridden in other scripts to redirect to alternate destination(s), e.g.,
#   to the GitHub Actions step summary file. Alternatively, `__summary_output` can be modified
#   to redirect elsewhere considering more environment conditions like the CI environment
#   variable.
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @exitcode success=0: The summary was printed (always).
#
# @stdout `## Summary` markdown heading followed by each message line.
#
# @example
#   to_summary "Build completed successfully"
# @example
#   echo "Deployment finished" | to_summary
#-----------------------------------------------------------------------------------------------
# shellcheck disable=SC2120 # to_summary references arguments, but none are ever passed - usually passed in stdin
function to_summary()
{
    local _line
    local _first=true

    while IFS= read -r _line || [[ -n $_line ]]; do
        $_first && echo "## Summary" && _first=false
        echo "$_line"
    done | "${__summary_output[@]}"
}

#-----------------------------------------------------------------------------------------------
# @description Returns the current time in microseconds since the epoch. us stands for
#   microseconds: visually close to the Greek letter mu - 'μ', the symbol for micro.
#
#   Note: Requires Bash 5.0 or later for $EPOCHREALTIME.
#
# @stdout The current time in microseconds since the epoch.
#
# @exitcode success=0: Always succeeds.
#
# @example
#   point0_us=$(now_us)
#   sleep 1
#   point1_us=$(now_us)
#   echo "Elapsed time: $((point1_us - point0_us)) us"
#-----------------------------------------------------------------------------------------------
function now_us()
{
    echo "${EPOCHREALTIME//[!0-9]/}"
}

#-----------------------------------------------------------------------------------------------
# @description Should be overridden in the top level script by sourcing core.args.sh, akin to
#   a forward declaration in C/C++ for use within this script (e.g., `exit_if_has_errors()`).
#   Local implementation of usage() to avoid circular dependency with core.args.sh
#
# Note: This implementation of usage() is meant to be a 'forward declaration'! It MUST be
#   overridden in the top-level script or by sourcing core.args.sh.
#
# @arg $@ string Ignored -- forwarded to `bug` as part of the "not overridden" message.
#
# @exitcode failure=1: Always -- this placeholder always exits with a bug.
#-----------------------------------------------------------------------------------------------
function usage()
{
    bug "$err_not_overridden" "This implementation of usage() is meant to be a 'forward declaration'!" \
                              "Either re-define usage() or source core.args.sh."
                              "$@"
    exit "$failure";
}

#-----------------------------------------------------------------------------------------------
# @description Displays the current call stack. Consider redirecting the output to stderr at
#   the call site.
#
# @arg $1 int How many stack frames to skip, not including the caller of `show_stack`.
#   Optional, default: 0.
# @arg $2 int How many stack frames to show. Optional, default: all remaining frames after the
#   skip.
#
# @exitcode success=0
#
# @stdout string The formatted stack trace, one line per frame, showing function name, source
#   file, and line number (consider redirecting to stderr at the call site).
#
# @example
#   show_stack 2 3 # typically called during debugging or error handling
#-----------------------------------------------------------------------------------------------
function show_stack()
{
    local _skip=${1:-0}
    (( ++_skip ))                                           # skip the frame of this call

    local _max_take=$(( ${#FUNCNAME[@]} - _skip ))          # take no more than the remaining stack frames
    local _take=${2:-$_max_take}

    _take=$(( _take < _max_take ? _take : _max_take ))      # adjust take if it exceeds the available stack frames
    (( _take <= 0 )) && return "$success"

    local _func
    local _source
    local _lineno

    local -i _index
    local _end=$(( _skip + _take ))

    for (( _index=_skip; _index<_end; _index++ )); do
        _func=${FUNCNAME[_index]:-}
        _source=${BASH_SOURCE[_index]:-}
        _lineno=${BASH_LINENO[_index-1]:-}
        printf "    ↑ %-20s (%s: %d)\n" "$_func" "$_source" "$_lineno"
    done

    return "$success"
}

#===============================================================================================
# Errors State
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description A global error counter.
# Notes:
#   - Consider this variable as a private implementation detail; it should not be modified
#     directly outside of the provided functions.
#   - It is tested by the `has_errors()` and `get_errors()` functions.
#   - It is controlled by the functions `set_errors()` and `reset_errors()`.
#   - Use also `exit_if_has_errors()` to immediately exit the script if there are any errors
#     recorded.
# @default false
# @type boolean
#-----------------------------------------------------------------------------------------------
declare -xi __errors=0

#-----------------------------------------------------------------------------------------------
# @description The most recent error code recorded by the global error counter.
#-----------------------------------------------------------------------------------------------
declare -xi __last_error=$success

#-----------------------------------------------------------------------------------------------
# @description The shallowest bash call-stack depth at which an un-flushed error was recorded.
#   Mirrors `$__bugs_min_depth` -- see its documentation for the full rationale. Meaningless
#   while `$__errors == 0`.
#-----------------------------------------------------------------------------------------------
declare -xi __errors_min_depth=0

#-----------------------------------------------------------------------------------------------
# @description Tests whether the global error counter has recorded any errors.
#
# @exitcode positive=0: At least one error has been recorded.
# @exitcode negative=1: No errors have been recorded.
#
# @example
#   if has_errors; then
#     echo "Errors were encountered."
#   else
#     echo "No errors."
#   fi
#-----------------------------------------------------------------------------------------------
function has_errors()
{
    return $(( __errors > 0 ? positive : negative ))
}

#-----------------------------------------------------------------------------------------------
# @description Gets the most recent error code recorded by the global error counter.
#
# @arg $1 string the name of a variable that will receive the last error code.
#
# @exitcode success=0: always
#
# @example
#   local -i _error;
#   get_last_error _error
#-----------------------------------------------------------------------------------------------
function get_last_error()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of a variable to receive the last error code."
    [[ ! -v 1 ]] || { is_variable "$1" && is_mutable "$1"; }                    || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name a writable variable for the last error code (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs

    local -n __error=$1

    __error=$__last_error
    return "$success"
}

#-----------------------------------------------------------------------------------------------
# @description Returns the current value of the global error counter.
#
# @stdout int The current value of the global `$errors` counter.
#
# @exitcode success=0
#
# @example
#   (( $(get_errors) == 0 )) && echo "No errors." || echo "Errors were encountered."
#-----------------------------------------------------------------------------------------------
function get_errors()
{
    echo "$__errors"
}

#-----------------------------------------------------------------------------------------------
# @description Sets the global error counter to a specific value.
#
# Notes:
#
# @arg $1 int The new value for the global error counter. Must be a non-negative integer.
#
# @exitcode success=0: The counter was set.
#
# @example
#   set_errors 0  # sets the global error counter to zero
#-----------------------------------------------------------------------------------------------
function set_errors()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the new value for the global error counter."
    [[ ! -v 1 ]] || is_non_negative "$1"                                        || bug "$err_argument_type" "${FUNCNAME[0]}() requires argument 1 to be provided as a non-negative integer: the new value for the global error counter (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs

    __errors=$1
    (( __errors == 0 || __last_error != 0 )) || __last_error=$failure # unspecified error
}

#-----------------------------------------------------------------------------------------------
# @description Resets the global error counter to zero.
#
# @exitcode success=0
#
# @example
#   reset_errors  # sets the global error counter to zero
#-----------------------------------------------------------------------------------------------
function reset_errors()
{
    __errors=0
    __last_error=$success
}

#-----------------------------------------------------------------------------------------------
# @description Tests the global error counter and exits the script (via `usage`) if any errors
#   were recorded.
#
# @arg $1 boolean Optional. If true (the default) and errors are present, also invokes `usage()`.
#
# @exitcode success=0: No errors were recorded; execution continues normally.
# @exitcode failure=1: The application exits with an error due to recorded errors.
#
# @example
#   exit_if_has_errors  # exits (via usage) with code 1 if errors exist
#-----------------------------------------------------------------------------------------------
function exit_if_has_errors()
{
    has_errors                                                                  || return "$success"

    local -i _depth=${#FUNCNAME[@]}
    (( __errors_min_depth >= _depth ))                                          || return "$success" # not mine to report -- defer to the ancestor whose validation block is still open

    local _display_usage=true
    [[ -v 1 ]] && is_boolean "$1" && _display_usage="$1"

    local -i _errors=$__errors
    local -i _ec
    (( __last_error != 0 )) && _ec=$__last_error || _ec=$err_has_errors

    # to prevent recursion clear before reporting: helpers called below (is_exit_code, __test_with_regex, etc.)
    # also follow the check-then-exit_if_has_errors convention.
    __errors=0
    __last_error=0
    __errors_min_depth=0

    # exits with error message, code, and usage, if $_display_usage is true
    ! $_display_usage                                                           || usage "$_ec" "$_errors error(s) encountered. Fix the above issues and try again." -ns

    # otherwise, report the error and exit immediately
    exit_with_error "$_ec" "$_errors error(s) encountered. Fix the above issues and try again. Exiting the script immediately..." -ns
}

#===============================================================================================
# Bugs State
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description A global bug counter.
# Notes:
#   - Bugs are different from errors; they (usually) represent obvious mistakes in the calling
#     scripts - e.g. violation of a function contract. While errors may be tolerable and the
#     scripts may expect them, bugs usually indicate a fundamental problem that should be
#     fixed immediately.
#   - Use `exit_if_has_bugs()` to immediately exit the script if there are any bugs recorded.
#     The functions usually call this function in the end of the parameter validation block.
# @default false
# @type boolean
#-----------------------------------------------------------------------------------------------
declare -xi __bugs=0

#-----------------------------------------------------------------------------------------------
# @description The error code of the last recorded bug.
# @default 0
# @type integer
#-----------------------------------------------------------------------------------------------
declare -xi __last_bug=$success

#-----------------------------------------------------------------------------------------------
# @description The shallowest bash call-stack depth (`${#FUNCNAME[@]}`, measured the same way
#   `bug()` and `exit_if_has_bugs()` each see it from their own call site) at which an
#   unflushed bug was recorded. Meaningless while `$__bugs == 0`.
#
# Notes:
#   - `bug()` and `exit_if_has_bugs()` are always called as sibling statements within the same
#     function, so they observe the same depth for that function. This lets
#     `exit_if_has_bugs()` tell "a bug that belongs to me or something I called" (depth >= mine)
#     apart from "a bug an ancestor recorded earlier in its own still-open validation block,
#     before it got a chance to call its own `exit_if_has_bugs()`" (depth < mine) -- the latter
#     is deferred instead of being exited on by an unrelated, deeper function that happens to
#     also follow the check-then-exit_if_has_bugs convention.
#-----------------------------------------------------------------------------------------------
declare -xi __bugs_min_depth=0

#-----------------------------------------------------------------------------------------------
# @description Tests whether the global bug counter has recorded any bugs.
#
# @exitcode positive=0: At least one bug has been recorded.
# @exitcode negative=1: No bugs have been recorded.
#
# @example
#   if ! has_bugs; then
#     echo "No bugs."
#   fi
#-----------------------------------------------------------------------------------------------
function has_bugs()
{
    return $(( __bugs > 0 ? positive : negative ))
}

#-----------------------------------------------------------------------------------------------
# @description Tests the global bug counter and exits the script if any bugs were recorded,
#   unless the shallowest unflushed bug belongs to an ancestor's still-open validation block
#   (see `$__bugs_min_depth`), in which case it defers to that ancestor's own
#   `exit_if_has_bugs()` call instead of exiting on its behalf.
#
# @noargs
#
# @exitcode success=0: No bugs were recorded, or the recorded bug(s) are not this
#   call's to report; execution continues normally.
#
# @example
#   exit_if_has_bugs  # exits with code 254 (err_has_bugs) if any bugs were recorded
#-----------------------------------------------------------------------------------------------
function exit_if_has_bugs()
{
    has_bugs                                                                    || return "$success"

    local -i _depth=${#FUNCNAME[@]}
    (( __bugs_min_depth >= _depth ))                                            || return "$success" # not mine to report -- defer to the ancestor whose validation block is still open

    local -i _bugs=$__bugs
    local -i _ec
    (( __last_bug != success )) && _ec=$__last_bug || _ec=$err_has_bugs

    # clear before reporting: helpers called below (is_exit_code, __test_with_regex, etc.) also
    # follow the check-then-exit_if_has_bugs convention, and would otherwise see the stale
    # count and recurse back into this same exit path indefinitely.
    __bugs=0
    __last_bug=0
    __bugs_min_depth=0

    exit_with_error "$_ec" "$_bugs bug(s) detected. Fix the above issues and try again. Exiting the script immediately..." -ns
}

#-----------------------------------------------------------------------------------------------
# @description Determines the appropriate command to use for summary output based on the
#   environment: outside CI, when `glow` is present, it uses `glow` for pretty printing of
#   markdown. Otherwise (in CI, or when `glow` is absent), it uses `tee_stdout`. Changes the
#   behavior of `to_summary` without overriding it.
#
# Notes: consider this variable an implementation detail and never use directly. Instead
#   redirect output to `to_summary` function
#-----------------------------------------------------------------------------------------------
declare -a __summary_output
declare -x ci

if ! $ci && [[ -t 1 ]] && is_tool_present glow; then
    # redirect summary markdown to glow for pretty printing on the console
    # there is no $GITHUB_STEP_SUMMARY in local runs
    __summary_output=(glow -w 168)
else
    # redirect summary markdown to `tee_stdout`: the terminal (or the GitHub Actions log) and,
    # in GitHub Actions, also the step summary
    __summary_output=(tee_stdout)
fi

readonly __summary_output
