# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#---------------------------------------------------------------------------------------------
# This script defines diagnostic functions for logging messages to stdout, stderr, and trace output.
# It also defines a global error counter and functions to manipulate it.
#---------------------------------------------------------------------------------------------

# ╔═════════════════════════════════════════════════════════════════════════════╗
# ║ IMPORTANT: The to_* functions are designed to be used on the RIGHT side     ║
# ║ of a pipe. Never pipe a function that SETS VARIABLES into a to_* function.  ║
# ║ The left side of a pipe runs in a subshell — all variable assignments are   ║
# ║ lost. Use two separate lines instead.                                       ║
# ║                                                                             ║
# ║ DO NOT:                                                                     ║
# ║     warning_var x "msg" "default" | to_stdout                               ║
# ║     # assigns "default" to x in a subshell. The side effect is lost on      ║
# ║     #  the next line.                                                       ║
# ║                                                                             ║
# ║ IT IS OK:                                                                   ║
# ║       x="default"                                                           ║
# ║       echo "msg" | to_stdout                                                ║
# ║                                                                             ║
# ╚═════════════════════════════════════════════════════════════════════════════╝

# Circular include guard
(( ${__VM2_LIB_DIAGNOSTICS_SH_LOADED:-0} == 1 )) && return 0
declare -xri __VM2_LIB_DIAGNOSTICS_SH_LOADED=1

# Declare error codes defined in the core library
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_not_overridden
declare -xri err_invalid_nameref
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_has_bugs
declare -xri err_has_errors

#---------------------------------------------------------------------------------------------
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
# @stdout string each line read from stdin unchanged.
#
# @example
#   echo "Build completed" | to_stdout
#---------------------------------------------------------------------------------------------
function to_stdout()
{
    local _line

    while IFS= read -r _line; do
        echo "$_line"
    done
}

#---------------------------------------------------------------------------------------------
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
# @stderr string each line read from stdin unchanged.
#
# @example
#   echo "Warning: file not found" | to_stderr
#---------------------------------------------------------------------------------------------
function to_stderr()
{
    local _line

    while IFS= read -r _line; do
        echo "$_line" >&2
    done
}

#---------------------------------------------------------------------------------------------
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
# @stdout string each line read from stdin unchanged.
#
# @example
#   echo "version=1.2.3" | to_output
#---------------------------------------------------------------------------------------------
function to_output()
{
    local _line
    while IFS= read -r _line; do
        echo "$_line"
    done
}

#---------------------------------------------------------------------------------------------
# @description Determines the appropriate command to use for summary output based on the
#   environment: without glow, it uses `to_stdout`. Otherwise, it uses `glow` for
#   pretty printing of markdown.
#
# Notes: consider this variable an implementation detail and never use directly. Instead
#   redirect output to `to_summary` function
#---------------------------------------------------------------------------------------------
declare -xr glow_present
declare -a __summary_output

if $glow_present 2>&1; then
    # redirect summary markdown to glow for pretty printing on the console
    __summary_output=(glow -w 168)
else
    # redirect summary markdown to `to_stdout` (the terminal output if not redirected
    # externally)
    __summary_output=(to_stdout)
fi

#---------------------------------------------------------------------------------------------
# @description Logs one or more summary messages with a `## Summary` markdown heading, via
# `__summary_output` — so, if glow is installed, the summary will be pretty-printed using
#   glow; otherwise, it will be sent to `to_stdout` as a markdown. Creates an abstraction,
#   designed to be overridden in other scripts to redirect to alternate destination(s), e.g.,
#   to the GitHub Actions step summary file. Alternatively, `__summary_output` can be modified
#   to redirect elsewhere considering more environment conditions like the CI environment
#   variable.
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @stdout `## Summary` markdown heading followed by each message line.
#
# @example
#   to_summary "Build completed successfully"
# @example
#   echo "Deployment finished" | to_summary
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2120 # to_summary references arguments, but none are ever passed - usually passed in stdin
function to_summary()
{
    local _line
    local _first=true

    while IFS= read -r _line; do
        $_first && echo "## Summary" && _first=false
        echo "$_line"
    done | "${__summary_output[@]}"
}

#=============================================================================================
# Global error counter
#=============================================================================================

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
declare -xi __errors=0

#---------------------------------------------------------------------------------------------
# @description The shallowest bash call-stack depth at which an unflushed error was recorded.
#   Mirrors `$__bugs_min_depth` -- see its documentation for the full rationale. Meaningless
#   while `$__errors == 0`.
#---------------------------------------------------------------------------------------------
declare -xi __errors_min_depth=0

#---------------------------------------------------------------------------------------------
# @description Tests whether the global error counter has recorded any errors.
#
# @exitcode success/positive=0: At least one error has been recorded.
# @exitcode failure/negative=1: No errors have been recorded.
#
# @example
#   if has_errors; then
#     echo "Errors were encountered."
#   else
#     echo "No errors."
#   fi
#---------------------------------------------------------------------------------------------
function has_errors()
{
    return $(( __errors > 0 ? positive : negative ))
}

#---------------------------------------------------------------------------------------------
# @description Returns the current value of the global error counter.
#
# @stdout int The current value of the global `$errors` counter.
#
# @exitcode success/positive=0
#
# @example
#   (( $(get_errors) == 0 )) && echo "No errors." || echo "Errors were encountered."
#---------------------------------------------------------------------------------------------
function get_errors()
{
    echo "$__errors"
}

#---------------------------------------------------------------------------------------------
# @description Sets the global error counter to a specific value.
#
# Notes:
#
# @arg $1 int The new value for the global error counter. Must be a non-negative integer.
#
# @exitcode success/positive=0: The counter was set.
#
# @example
#   set_errors 0  # sets the global error counter to zero
#---------------------------------------------------------------------------------------------
function set_errors()
{
    (( $# == 1 ))                        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument ($# provided):" \
                                                                                "  - the new value for the global error counter"
    [[ ! -v 1 ]] || is_non_negative "$1" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 1 to be provided as a non-negative integer: the new value for the global error counter (provided '${1:-<none>}')."

    exit_if_has_bugs

    __errors=$1
}

#---------------------------------------------------------------------------------------------
# @description Resets the global error counter to zero.
#
# @exitcode success/positive=0
#
# @example
#   reset_errors  # sets the global error counter to zero
#---------------------------------------------------------------------------------------------
function reset_errors()
{
    __errors=0
}

#=============================================================================================
# Global bug counter
#=============================================================================================

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
declare -xi __bugs=0

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
declare -xi __bugs_min_depth=0

#---------------------------------------------------------------------------------------------
# @description Tests the global bug counter and exits the script if any bugs were recorded,
#   unless the shallowest unflushed bug belongs to an ancestor's still-open validation block
#   (see `$__bugs_min_depth`), in which case it defers to that ancestor's own
#   `exit_if_has_bugs()` call instead of exiting on its behalf.
#
# @noargs
#
# @exitcode success/positive=0: No bugs were recorded, or the recorded bug(s) are not this
#   call's to report; execution continues normally.
#
# @example
#   exit_if_has_bugs  # exits with code 254 (err_has_bugs) if any bugs were recorded
#---------------------------------------------------------------------------------------------
function exit_if_has_bugs()
{
    (( __bugs == 0 )) && return "$success"

    local -i _depth=${#FUNCNAME[@]}
    (( __bugs_min_depth >= _depth )) || return "$success" # not mine to report -- defer to the ancestor whose validation block is still open

    local -i _bugs=$__bugs
    __bugs=0            # clear before reporting: helpers called below (is_exit_code, __test_with_regex, etc.) also
    __bugs_min_depth=0  # follow the check-then-exit_if_has_bugs convention, and would otherwise see the stale
                        # count and recurse back into this same exit path indefinitely.
    error -ec "$err_has_bugs" -ns "$_bugs bug(s) detected. Please fix the above issues and try again. Exiting the script immediately..."
    exit "$err_has_bugs"
}

#---------------------------------------------------------------------------------------------
# @description Should be overridden in the top level script by sourcing _args.sh, akin to
#   a forward declaration in C/C++ for use within this script (e.g., `exit_if_has_errors()`).
#   Local implementation of usage() to avoid circular dependency with _args.sh
#
# Note: This implementation of usage() is meant to be a 'forward declaration'! It should be
#   overridden in the top-level script or by sourcing _args.sh.
#
# @arg $@ string Ignored -- forwarded to `bug` as part of the "not overridden" message.
#
# @exitcode failure/negative=1: Always -- this placeholder always exits.
#---------------------------------------------------------------------------------------------
function usage()
{
    bug -ec "$err_not_overridden" "This implementation of usage() is meant to be a 'forward declaration'!" \
                                    "Either re-define usage() or source _args.sh." \
                                    "$@"
    exit "$failure";
}

#---------------------------------------------------------------------------------------------
# @description Tests the global error counter and exits the script (via `usage`) if any errors
#   were recorded.
#
# @arg $1 boolean Optional. If true, displays the usage message when errors are present.
#   Default is true.
#
# @exitcode success=0: No errors were recorded; execution continues normally.
# @exitcode failure=1: The application exits with an error due to recorded errors.
#
# @example
#   exit_if_has_errors  # exits (via usage) with code 1 if errors exist
#---------------------------------------------------------------------------------------------
function exit_if_has_errors()
{
    local _display_usage=true

    ! has_errors && return "$success"

    local -i _depth=${#FUNCNAME[@]}
    (( __errors_min_depth >= _depth )) || return "$success" # not mine to report -- defer to the ancestor whose validation block is still open

    [[ -v 1 ]] && is_boolean "$1" && _display_usage="$1"

    local -i _errors=$__errors
    __errors=0            # clear before reporting: guards against any future helper called below that follows
    __errors_min_depth=0  # the check-then-exit_if_has_errors convention and would otherwise see the stale
                          # count and recurse back into this same exit path (mirrors exit_if_has_bugs).

    $_display_usage && usage -ec "$err_has_errors" -ns "$_errors error(s) encountered. Please fix the above issues and try again."
    # exits with error message, code, and usage, if $_display_usage is true

    error -ec "$err_has_errors" -ns "$_errors error(s) encountered. Please fix the above issues and try again. Exiting the script immediately..."
    exit "$err_has_errors"
    # exits with error message and code (no usage) if $_display_usage is false
}

#=============================================================================================
# Diagnostic messages
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description Prints one or more message lines with a given prefix, optionally translating
#   embedded error codes to messages and optionally appending a stack dump. Used internally by
#   `error()`, `warning()`, `info()`, and `trace()` -- not meant to be called directly from
#   top-level scripts.
#
# Notes:
#   - This function is intended for internal use only.
#   - It is used by the higher-level diagnostic functions to standardize message formatting.
#   - The message prefix and the named parameters must be provided as arguments to the
#     function - they are not expected in stdin.
#
# @arg $1 string The severity prefix to prepend to the first printed line. SHOULD be one of:
#   `$error_prefix`, `$warning_prefix`, `$info_prefix`, or `$trace_prefix`.
# @arg $@ string The message parts to print, each on a new line. Optional -- if none are given
#   (after removing the possible named parameters below), the message parts are instead read
#   line-by-line from `stdin`. May include the following named parameters (not in stdin!),
#   interspersed anywhere among the message parts parameters:
#     - `--error-code`|`-ec` followed by a positive error code -- translated to its error
#       message (via `error_message()`) and substituted into the output in place of the flag and
#       and its argument. If occurs multiple times, every occurrence is translated and
#       substituted into the output.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`|`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). May occur multiple times; only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @exitcode success/positive=0: Message printed successfully.
#
# @stdout string The formatted message: the prefix followed by the first line (prefixed
#   further with the immediate caller's source file and line number if `--stack-depth`/`-sd`
#   was given a value greater than 0), then any remaining lines indented to align under the
#   first, then (if a stack depth was requested) the call stack via `show_stack`.
#---------------------------------------------------------------------------------------------
function __message()
{
    local -i _rc="$success"

    (( $# > 0 ))                 || bug -ec "$err_missing_argument" "${FUNCNAME[0]}() called without any parameters. Provide at least a prefix as the first parameter."
    (( $# > 1 )) || [[ ! -t 0 ]] || bug -ec "$err_missing_argument" "${FUNCNAME[0]}() called without message parameters and there are none in the pipe. Provide message parameters or pipe them into the function."

    exit_if_has_bugs

    # The first parameter MUST be the prefix to prepend to each message line, e.g. "ERROR: ", "WARN: ", etc.
    local _prefix="$1"
    shift

    # The remaining parameters are
    #   - the message parts
    #   - error codes to be translated to messages, prefixed by the `-ec` or `--error-code` flag
    #   - the stack skip and depth to display, prefixed by the `-ss` `--stack-skip`, `-sd` or `--stack-depth` flag
    # If there are no remaining parameters, the message will be read from `stdin`.

    local -i _error_code=$success

    local -i _skip=2
    # by default skips the frames of:
    #   2 show_stack()
    #   1 message()
    # show at the top the caller of message() -- e.g. error()
    local -i _depth=1000000 # stack dump depth - default is full stack dump

    local -a _message_parts=()

    # preprocess the arguments array for -ec and -sd flags, and then print the messages lines with the prefix.
    while (( $# > 0 )); do
        case "$1" in

            "--error-code"|"-ec" )
                # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                if (( $# > 0 )); then
                    shift
                    is_exit_code "$1" && _error_code="$1" && _message_parts+=("$(error_message "$_error_code")") ||
                        printf "%s Expected an error code (0..255) after the '--error-code' flag, provided: '%s'\n. Ignoring both arguments." "$bug_prefix" "$1"
                fi
                ;;

            "--stack-depth"|"-sd" )
                # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                if (( $# > 0 )); then
                    shift
                    is_non_negative "$1" &&
                        _depth="$1" ||
                        printf "%s Expected a positive number or 0 number of frames to display after the '--stack-depth' flag, provided: '%s'\n. Ignoring both arguments." "$bug_prefix" "$1"
                fi
                ;;

            "--stack-skip"|"-ss" )
                # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                if (( $# > 0 )); then
                    shift
                    is_non_negative "$1" &&
                        _skip="$1" ||
                        printf "%s Expected a positive number or 0 number of frames to skip after the '--stack-skip' flag, provided: '%s'\n. Ignoring both arguments." "$bug_prefix" "$1"
                fi
                ;;

            "--no-stack"|"-ns" )
                _depth=0
                ;;

            * ) _message_parts+=("$1")
                ;;
        esac
        shift
    done

    local -i _count=${#_message_parts[@]}

    [[ $_count -gt 0 || ! -t 0 ]] || bug -ec "$err_missing_argument" "${FUNCNAME[0]}() called without message part(s) and there are none in the stdin pipe. Provide the message part(s) or pipe them into the function."

    exit_if_has_bugs

    local _first_part=true

    function __print_message_part()
    {
        local __part="$1"

        if $_first_part; then
            if (( _depth > 0 )); then
                printf "%s%s (%s):\n" "$_prefix" "${BASH_SOURCE[3]:-}" "${BASH_LINENO[2]:-}"
                printf "           %s\n" "$__part"
            else
                printf "%s%s\n" "$_prefix" "$__part"
            fi
            _first_part=false
        else
            printf "           %s\n" "$__part"
        fi
        return "$success"
    }

    if (( _count > 0 )); then
        for _part in "${_message_parts[@]}"; do
            __print_message_part "$_part"
        done
    else
        while IFS= read -r _part; do
            __print_message_part "$_part"
        done
    fi

    (( _depth > 0 )) &&
        show_stack "$_skip" "$_depth" true

    return "$success"
}

declare -xr error_exit_prefix="❌  ERROR: "
declare -xr error_prefix="❌  ERROR: "
declare -xr bug_prefix="🪲  BUG:   "
declare -xr fatal_prefix="💀  FATAL: "
declare -xr warning_prefix="⚠️  WARN:  "
declare -xr info_prefix="ℹ️  INFO:  "
declare -xr trace_prefix="🐾  TRACE: "

#---------------------------------------------------------------------------------------------
# @description Logs an error message to stderr (via `message`, prefixed with `$error_prefix`)
# and increments the global error counter.
#
# Notes:
#   - Increments the global `$errors` counter by 1, every call.
#   - The named parameters must be provided as arguments to the function - they are not
#     expected in stdin.
#
# @arg $@ string Error message parts (optional -- if none are given, the message is read from
#   stdin instead). May include the named parameters described in `message`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: 0). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @exitcode success/positive=0: Message printed successfully.
#
# @example
#   error "File not found: $filename"
# @example
#   error "Build failed"
#---------------------------------------------------------------------------------------------
function error()
{
    __message "$error_prefix" "$@" > >(to_stderr)
    local -i _depth=${#FUNCNAME[@]}
    (( __errors == 0 || _depth < __errors_min_depth )) && __errors_min_depth=$_depth
    (( ++__errors ))
}

#---------------------------------------------------------------------------------------------
# @description Logs a bug message to stderr (via `message`, prefixed with `$bug_prefix`)
# and increments the global bug counter. Should be used when there is an obvious bug in
# the code.
#
# Notes:
#   - Increments the global `$__bugs` counter by 1, every call.
#   - The named parameters must be provided as arguments to the function - they are not
#     expected in stdin.
#
# @arg $@ string Error message parts (optional -- if none are given, the message is read from
#   stdin instead). May include the named parameters described in `message`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: 0). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @exitcode success/positive=0: Message printed successfully.
#
# @example
#   error "File not found: $filename"
# @example
#   error "Build failed"
#---------------------------------------------------------------------------------------------
function bug()
{
    __message "$bug_prefix" "$@" > >(to_stderr)
    local -i _depth=${#FUNCNAME[@]}
    (( __bugs == 0 || _depth < __bugs_min_depth )) && __bugs_min_depth=$_depth
    (( ++__bugs ))
}

#---------------------------------------------------------------------------------------------
# @description Logs a message with a fatal prefix and exits with the specified error code.
#
# Notes:
#   - Exits the script with the specified error code.
#   - Accepts named parameters provided as arguments to the function - not in stdin.
#
# @arg $@ string Exit message parts (optional -- if none are given, the message is read from
#   stdin instead). May include the named parameters described in `message`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: 0). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @exitcode The exit code specified by the `--error-code`/`-ec` named parameter, or the
#   default failure code if none is provided.
#
# @example
#   fatal_exit -ec $err_file_not_found "File not found: $filename"
#---------------------------------------------------------------------------------------------
function fatal_exit()
{
    local -i _exit_code=$failure
    local -a _args=("$@")
    local -i _i

    for (( _i = 0; _i < ${#_args[@]}; _i++ )); do
        [[ ${_args[_i]} == "--error-code" || ${_args[_i]} == "-ec" ]] || continue
        is_exit_code "${_args[_i+1]:-}" && _exit_code=${_args[_i+1]}
        break
    done

    __message "$fatal_prefix" "$@" > >(to_stderr)
    exit "$_exit_code"
}

#---------------------------------------------------------------------------------------------
# @description Logs a warning message to stderr (via `message`, prefixed with
#   `$warning_prefix`).
#
# Notes:
#   - The named parameters must be provided as arguments to the function - they are not
#     expected in stdin.
#
# @arg $@ string Warning message parts (optional -- if none are given, the message is read
#   from stdin instead). May include the named parameters as described in `message`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: 0). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @exitcode success/positive=0: Message printed successfully.
#
# @example
#   warning "The option is deprecated"
# @example
#   warning -sd 3 "Missing optional configuration"
#---------------------------------------------------------------------------------------------
function warning()
{
    __message "$warning_prefix" --no-stack "$@" > >(to_stderr)
}


#---------------------------------------------------------------------------------------------
# @description Logs an informational message to stdout (via `message`, prefixed with
#   `$info_prefix`).
#
# Notes:
#   - The named parameters must be provided as arguments to the function - they are not
#     expected in stdin.
#
# @arg $@ string Informational message parts (optional -- if none are given, the message is
#   read from stdin instead). May include the named parameters as described in `message()`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: 0). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @stdout string The formatted info message, prefixed with `$info_prefix`.
#
# @exitcode success/positive=0: Message printed successfully.
#
# @example
#   info "Starting build process"
# @example
#   echo "Configuration loaded" | info
#---------------------------------------------------------------------------------------------
function info()
{
    __message "$info_prefix" --no-stack "$@" > >(to_stdout)
}

#---------------------------------------------------------------------------------------------
# @description Logs a trace message to stderr (via `message`, prefixed with `$trace_prefix`),
#   but only when verbose mode is enabled.
#
# Notes:
#   - The named parameters must be provided as arguments to the function - they are not
#     expected in stdin.
#
# @arg $@ string Trace message parts (optional -- if none are given, the message is read from
#   stdin instead, unless verbose mode is off, in which case stdin is never read). May include
#   the named parameters as described in `message()`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: 0). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @exitcode success/positive=0: Message printed successfully.
#
# @example
#   trace "Processing item: $item"
# @example
#   echo "Debug: variable value = $var" | trace
#---------------------------------------------------------------------------------------------
function trace()
{
    is_verbose || return "$success"
    __message "$trace_prefix" --no-stack "$@" > >(to_stderr)
}

#---------------------------------------------------------------------------------------------
# @description Displays the passed-in warning about a variable's value, and sets that variable
#   to a specified default value.
#
# Notes:
#   - The named parameters must be provided as arguments to the function - they are not
#     expected in stdin.
#   - This function uses a bash nameref (`local -n`) to set the variable by name. Do NOT pipe
#     a call to this function into `to_stdout` or similar -- the left side of a pipe runs in a
#     subshell, so the variable assignment would be lost (see the file-level warning at the
#     top of this file).
#
# @arg $1 nameref to a variable to assign the default value to.
# @arg $2 string The warning message to display.
# @arg $3 string The default value to assign to the variable.
#
# @exitcode success/positive=0: The variable was set successfully.
#
# @example
#   warning_var timeout "Timeout not specified." 30
#---------------------------------------------------------------------------------------------
function warning_var()
{
    (( $# == 3 ))                         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three arguments ($# provided):" \
                                                                                "  - variable name" \
                                                                                "  - warning message" \
                                                                                "  - default value"
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ ! -v 1 ]] || is_variable_name "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to be a valid variable name (provided '${1:-<none>}')."
    [[ ! -v 2 || -n $2 ]]                 || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the warning message, to be non-empty (provided '${2:-<none>}')."

    exit_if_has_bugs

    warning "$2" "Assuming the default value of '$3'."

    local -n _var=$1;
    _var="$3"
}

#---------------------------------------------------------------------------------------------
# @description Displays the current call stack. Consider redirecting the output to stderr at
#   the call site.
#
# @arg $1 int How many stack frames to skip, not including the caller of `show_stack`.
#   Optional, default: 0.
# @arg $2 int How many stack frames to show. Optional, default: all remaining frames after the
#   skip.
# @arg $3 bool Whether to output the stack trace at all. Optional, default: the value of the
#   global `$verbose` variable.
#
# @exitcode success/positive=0
#
# @stdout string The formatted stack trace, one line per frame, showing function name, source
#   file, and line number (consider redirecting to stderr at the call site).
#
# @example
#   show_stack 2 3 true # typically called during debugging or error handling
#---------------------------------------------------------------------------------------------
function show_stack()
{
    local _show

    if is_boolean "${3:-}"; then
        _show="$3"
    else
        is_verbose && _show=true || _show=false
    fi
    $_show || return "$success"

    local _skip=${1:-0}
    (( ++_skip ))                                           # skip the frame of this call

    local _max_take=$(( ${#FUNCNAME[@]} - _skip ))          # take no more than the remaining stack frames
    local _take=${2:-$_max_take}

    (( _take = _take < _max_take ? _take : _max_take ))     # adjust take if it exceeds the available stack frames
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
