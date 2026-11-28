# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# length-review: keep together -- well-focused on diagnostic messages: error, bug, warning info, trace and derivatives like exit_with_error.

# Circular include guard
(( ${__VM2_LIB_DIAGNOSTICS_MESSAGES_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DIAGNOSTICS_MESSAGES_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x positive
declare -x err_invalid_arguments
declare -x err_invalid_nameref
declare -x err_argument_value
declare -x err_missing_argument
declare -x err_has_bugs
declare -x err_has_errors

# vm2 core lib constants
declare -x fatal_em
declare -x bug_em
declare -x error_em
declare -x warn_em
declare -x info_em
declare -x trace_em

# vm2 core lib constants defined here
declare -xr error_prefix="$error_em  ERROR: "
declare -xr bug_prefix="$bug_em  BUG:   "
declare -xr warning_prefix="$warn_em  WARN:  "
declare -xr info_prefix="$info_em  INFO:  "
declare -xr trace_prefix="$trace_em  TRACE: "

#===============================================================================================
# Diagnostic messages
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description Prints one or more message lines with a given prefix, optionally translating
#   embedded error codes to messages and optionally appending a stack dump. Used internally by
#   `error()`, `warning()`, `info()`, and `trace()` -- not meant to be called directly from
#   top-level scripts.
#
# Notes:
#   - This function is intended for internal use only.
#   - It is used by the higher-level diagnostic functions to standardize message formatting.
#
# @arg $1 string The severity prefix to prepend to the first printed line. SHOULD be one of:
#   `$error_prefix`, `$warning_prefix`, `$info_prefix`, or `$trace_prefix`.
# @arg $@ string The message parts to print, each on a new line. At least one is required
#   (a translated error code counts as one). May include the following named parameters,
#   interspersed anywhere among the message parts:
#     - `--error-code`|`-ec` followed by a positive error code -- translated to its error
#       message (via `error_message()`) and substituted into the output in place of the flag
#       and its argument. If occurs multiple times, every occurrence is translated and
#       substituted into the output.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`|`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). May occur multiple times; only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. Shortcut for `--stack-depth 0`. May occur
#       multiple times with `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @stdout string The formatted message, prefixed with `$1`.
#
# @exitcode success=0: Message printed successfully.
#
# @stdout string The formatted message: the prefix followed by the first line (prefixed
#   further with the immediate caller's source file and line number if `--stack-depth`/`-sd`
#   was given a value greater than 0), then any remaining lines indented to align under the
#   first, then (if a stack depth was requested) the call stack via `show_stack`.
#-----------------------------------------------------------------------------------------------
function __message()
{
    local -i _rc="$success"

    (( $# > 1 ))                                                                || bug "$err_missing_argument" "${FUNCNAME[0]}() requires more than 1 argument (provided $#):" \
                                                                                                               "  - the message prefix" \
                                                                                                               "  the message parts"
                                                                                exit_if_has_bugs

    # The first parameter MUST be the prefix to prepend to each message line, e.g. "ERROR: ", "WARN: ", etc.
    local _prefix="$1"
    shift

    # The remaining parameters are
    #   - the message parts
    #   - error codes to be translated to messages, prefixed by the `-ec` or `--error-code` flag
    #   - the stack skip and depth to display, prefixed by the `-ss` `--stack-skip`, `-sd` or `--stack-depth` flag

    local -i _skip=2
    # by default skips the frames of:
    #   2 show_stack()
    #   1 message()
    # show at the top the caller of message() -- e.g. error()
    local -i _depth=1000000 # stack dump depth - default is full stack dump

    # preprocess the arguments array for -ec and -sd flags, and then print the messages lines with the prefix.
    local -a _message_parts=()
    local _arg
    while (( $# > 0 )); do
        _arg=$1
        shift

        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        case "$_arg" in

            "--error-code"|"-ec" )
                if (( $# > 0 )); then
                    is_exit_code "$1" && (( $1 > 0 )) &&
                        _message_parts+=("$(error_message "$1")") ||
                        printf "%sExpected an error code (1..255) after the '--error-code' flag, provided: '%s'. Ignoring both arguments.\n" "$bug_prefix" "$1" >&2
                    shift
                else
                    printf "%sExpected an error code (1..255) after the '--error-code' flag.\n" "$bug_prefix" >&2
                fi
                ;;

            "--dotnet-error-code"|"-dc" )
                if (( $# > 0 )); then
                    is_exit_code "$1" && (( $1 > 0 )) &&
                        _message_parts+=("$(dotnet_error_message "$1")") ||
                        printf "%sExpected a dotnet error code (1..255) after the '--dotnet-error-code' flag, provided: '%s'. Ignoring both arguments.\n" "$bug_prefix" "$1" >&2
                    shift
                else
                    printf "%sExpected a dotnet error code (1..255) after the '--dotnet-error-code' flag.\n" "$bug_prefix" >&2
                fi
                ;;

            "--stack-depth"|"-sd" )
                if (( $# > 0 )); then
                    is_non_negative "$1" &&
                        _depth="$1" ||
                        printf "%sExpected a positive number or 0 number of frames to display after the '--stack-depth' flag, provided: '%s'. Ignoring both arguments.\n" "$bug_prefix" "$1" >&2
                    shift
                else
                    printf "%sExpected a positive number or 0 number of frames to display after the '--stack-depth' flag.\n" "$bug_prefix" >&2
                fi
                ;;

            "--stack-skip"|"-ss" )
                if (( $# > 0 )); then
                    is_non_negative "$1" &&
                        _skip="$1" ||
                        printf "%sExpected a positive number or 0 number of frames to skip after the '--stack-skip' flag, provided: '%s'. Ignoring both arguments.\n" "$bug_prefix" "$1" >&2
                    shift
                else
                    printf "%sExpected a positive number or 0 number of frames to skip after the '--stack-skip' flag.\n" "$bug_prefix" >&2
                fi
                ;;

            "--no-stack"|"-ns" )
                _depth=0
                ;;

            * ) _message_parts+=("$_arg")
                ;;
        esac
    done

    [[ ${#_message_parts[@]} -gt 0 ]]                                           || bug "$err_missing_argument" "${FUNCNAME[0]}() requires 1 or more message parts as arguments (provided none)."
                                                                                exit_if_has_bugs

    local _part="${_message_parts[0]}"

    if (( _depth > 0 )); then
        printf "%s%s @ %s (%s):\n" "$_prefix" "$_part" "${BASH_SOURCE[_skip]:-}" "${BASH_LINENO[_skip-1]:-}"
    else
        printf "%s%s\n" "$_prefix" "$_part"
    fi
    for _part in "${_message_parts[@]:1}"; do
        printf "           %s\n" "$_part"
    done

    (( _depth > 0 )) &&
        show_stack "$_skip" "$_depth" true

    return "$success"
}


#-----------------------------------------------------------------------------------------------
# @description Logs an error message to stderr and registers a last error discoverable with
#   `get_last_error()`, `has_errors()`, `exit_if_has_errors()`.
#
# @arg $1 int The error code (optional): the vm2 `$err_*` code of the failure. Recognized only
#   in the first position. Equivalent to omitting it and having `--error-code` with the same
#   error code in the last 2 positions. E.g., these two calls are equivalent:
#   `error "$err_io_failure" "Could not write to the file '$_file'."`
#   `error "Could not write to the file '$_file'." --error-code "$err_io_failure"`.
#   The former is the preferred form for readability's sake.
# @arg $@ string Error message parts. May include the following named parameters described in
#   `__message()`:
#     - `--error-code`/`-ec` followed by an error code -- the form before the leading code;
#       translated to its error message and included in the output where it appears. If $1 is
#       omitted, the last `--error-code` is assigned to `$__last_error` (`get_last_error()`)
#     - `--stack-skip`/`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). If given more than once, the last occurrence takes
#       effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). If given more than once, the last occurrence takes effect.
#     - `--no-stack`/`-ns` -- do not dump the stack. Combined with `--stack-depth`/`-sd`, the
#       last occurrence takes effect.
#
# @stderr string The formatted error message, prefixed with `$error_prefix`.
#
# @exitcode success=0: always. An error is registered: the caller decides what to do via
#     `get_last_error()`, `exit_if_has_errors()`, `has_errors()`.
#
# Notes:
#   - Increments the global `$__errors` counter by 1, every call.
#   - Records the error code in `$__last_error` (default: `$failure`). With several codes, only
#     the last one is registered. A leading code in $1 is always displayed and considered as the
#     last code (it is appended after all the other arguments).
#   - the error is registered: the caller decides what to do via `get_last_error()`,
#     `exit_if_has_errors()`, `has_errors()`.
#
# @example
#   error "$err_not_found" "Failed to find the file '$filename'."
# @example
#   error "Failed to build '$project'." -ec  "$err_tool_error" # the form before the leading code
#-----------------------------------------------------------------------------------------------
function error()
{
    # scan the arguments for the last --error-code to record it in __last_error
    local -a _args
    local _ec=${1-}

    if is_exit_code "$_ec" && (( _ec > 0 )); then
        _args=("${@:2}" -ec "$_ec")
        __last_error=$_ec
    else
        _args=("$@")
        __last_error=$failure

        local -i _i
        for (( _i = 0; _i < ${#_args[@]}; _i++ )); do
            [[ ${_args[_i]} == "-ec" || ${_args[_i]} == "--error-code" ]] || continue
            if (( _i + 1 < ${#_args[@]} )); then
                _ec=${_args[_i + 1]}
                is_exit_code "$_ec" && (( _ec > 0 )) && __last_error=$_ec
            fi
        done
    fi

    __message "$error_prefix" "${_args[@]}" > >(tee_stderr); wait "$!" || true

    local -i _depth=${#FUNCNAME[@]}
    (( __errors == 0 || _depth < __errors_min_depth )) && __errors_min_depth=$_depth
    (( ++__errors ))

    return "$success"
}

#-----------------------------------------------------------------------------------------------
# @description Switches a chain of fallible steps to the error track (railway-oriented
#   programming by hand): records a vm2 `$err_*` code in the caller's variable and reports the
#   failure with `error()`. Meant to be called right after the failed command, as
#   `cmd || with_error ...`. It captures `$?` first, and appends it to the other message parts
#   as "Exit code: N" when non-zero, so the log shows both the logical vm2 code and the
#   command's (tool or OS) own exit status. The following steps should be guarded by
#   `(( rc != success )) || ...` so that they are skipped after the first error encounter.
#   See CLAUDE.md, "Chaining Fallible Steps with `with_error`".
#
#   The stack dump and the `@ file (line)` location skip this function and start at its caller.
#
#   The output variable comes first, against the usual rule (outputs after inputs), so that a
#   call reads like the assignment it performs: `with_error _rc "$err_x" ...` sets `_rc` to
#   `$err_x`, the way `readarray -t arr < <(...)` puts its target before its source.
#
# @arg $1 string The name of a declared integer variable that receives the code from `$2`.
#   This is against the usual rule (outputs after inputs) for readability's sake and a call
#   reads like the assignment it  performs: `with_error _rc "$err_x" ...` sets `_rc` to `$err_x`,
#   the way `readarray -t arr < <(...)` puts its target before its source. Required.
# @arg $2 integer The vm2 error code (`$err_*`) to record and report, in the range [1, 255].
#    Required.
# @arg $@ string The `error()` message parts. At least one argument is required.
#
# @set The variable named in `$1` is set to `$2`. Also everything `error()` sets: the global
#   error counter, the last error code, etc.
#
# @stderr string The formatted error message, prefixed with `$error_prefix`.
#
# @exitcode success=0: Always, so that `cmd || with_error ...` does not trip `errexit`. The
#   failure is carried in the variable named in `$1`.
#
# @example
#   declare -i rc=$success
#   declare results_text=''
#   declare -a results=()
#   results_text=$(get_results)                                || with_error rc "$err_tool_error" "Failed to get the results."
#   (( rc != success )) || [[ -z $results_text ]] || readarray -t results <<< "$results_text"
#   (( rc != success )) || some_tool --input "$input_file"     || with_error rc "$err_tool_error" "some_tool failed."
#   (( rc == success ))                                        || return "$rc"
#   # alternatively, for a top-level script, `exit_if_has_errors()`
#-----------------------------------------------------------------------------------------------
function with_error()
{
    # immediately capture the previous command's exit code!
    local -i _prev_error=$?

    (( $# >= 2 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least 2 arguments (provided $#):" \
                                                                                                                "  - the name of a variable to receive the error code" \
                                                                                                                "  - the error code to record and report"
    [[ ! -v 1 ]] || { is_variable "$1" && is_mutable "$1"; }                    || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name a writable variable for the error code (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || { is_exit_code "$2" && (( $2 > 0 )); }                      || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 2 to be a valid return code in the range [1, 255] (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    local -n __err_code_var=$1
    local -i __err_code=$2
    shift 2

    __err_code_var=$__err_code
    if (( _prev_error != 0 && _prev_error != __err_code )); then
        error "$@" "Exit code: $_prev_error" -ec "$__err_code" -ss 3 # 3 skips this function in the stack dump
    else
        error "$__err_code" "$@" -ss 3
    fi

    local -i _depth=${#FUNCNAME[@]}
    (( __errors_min_depth <= _depth )) || __errors_min_depth=$_depth   # the error belongs to the caller, not to with_error

    return "$success"   # __err_code_var carries the actual failure
}

#-----------------------------------------------------------------------------------------------
# @description Logs an error message to stderr (via `__message()`, prefixed with `$error_prefix`)
# and exits immediately with the last error code or `$err_has_errors`.
#
# @arg $1 int The error code (optional): the vm2 `$err_*` code of the failure. Recognized only
#   in the first position. Equivalent to omitting it and having `--error-code` with the same
#   error code in the last 2 positions, e.g.:
#   `exit_with_error "$err_io_failure" "Could not write to the file."` is equivalent to
#   `exit_with_error "Could not write to the file." --error-code "$err_io_failure"`
# @arg $@ string Error message parts. May include the following named parameters described in
#   `__message()`:
#     - `--error-code`/`-ec` followed by an error code -- the form before the leading code;
#       translated to its error message and included in the output where it appears. If $1 is
#       omitted, the last `--error-code` is assigned to `$__last_error` (`get_last_error()`)
#     - `--stack-skip`/`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). If given more than once, the last occurrence takes
#       effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). If given more than once, the last occurrence takes effect.
#     - `--no-stack`/`-ns` -- do not dump the stack. Combined with `--stack-depth`/`-sd`, the
#       last occurrence takes effect.
#
# @stderr string The formatted error message, prefixed with `$error_prefix`.
#
# @exitcode N: Never returns -- always exits the script, with the error code recorded by
#   `error()` from `-ec`/`--error-code` (default `$failure` if that flag was not given), or
#   `$err_has_errors` in the unlikely case that recorded code is itself 0.
#
# @example
#   exit_with_error "$err_not_file" "Invalid file specified." --no-stack
#-----------------------------------------------------------------------------------------------
function exit_with_error()
{
    error "$@"

    local -i _ec=$(( __last_error != success ? __last_error : err_has_errors ))

    exit "$_ec"
}

#-----------------------------------------------------------------------------------------------
# @description Logs a bug message to stderr (via `__message()`, prefixed with `$bug_prefix`) and
#   registers a last bug discoverable with `has_bugs()`, `exit_if_has_bugs()`.
#
#   Use it for a broken contract: the calling code is wrong (e.g. a wrong argument count, or an
#   argument of the wrong type), not the user's input or the environment -- that is what `error`
#   is for.
#
# @arg $1 int The error code of the bug (optional): the vm2 `$err_*` code of the failure.
#   Recognized only in the first position. Equivalent to omitting it and having `--error-code`
#   with the same error code in the last 2 positions. E.g., these two calls are equivalent:
#   `bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the path."`.
#   `bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the path." -ec "$err_invalid_arguments"`
#   The former is the preferred form for readability's sake.
# @arg $@ string Bug message parts. May include the following named parameters described in
#   `__message()`:
#     - `--error-code`/`-ec` followed by an error code -- the form before the leading code;
#       translated to its error message and included in the output where it appears. If $1 is
#       omitted, the last `--error-code` is assigned to `$__last_error` (`get_last_error()`)
#     - `--stack-skip`/`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). If given more than once, the last occurrence takes
#       effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). If given more than once, the last occurrence takes effect.
#     - `--no-stack`/`-ns` -- do not dump the stack. Combined with `--stack-depth`/`-sd`, the
#       last occurrence takes effect.
#
# @stderr string The formatted bug message, prefixed with `$bug_prefix`.
#
# @exitcode success=0: always. A bug is registered: the caller decides what to do via
#   `exit_if_has_bugs()`, `has_bugs()`.
#
# Notes:
#   - Records the error code in `$__last_bug` (default: `$failure`). With several codes,
#     provided by several `-ec` options, only the last one is registered. A leading code in $1
#     is always displayed and considered as the last code (it is appended after all the other
#     arguments).
#   - the bug is registered: the caller decides what to do via `exit_if_has_bugs()` and
#     `has_bugs()`. Increments the global `$__bugs` counter by 1, every call.
#
# @example
#   (( $# == 1 )) || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the path."
#   exit_if_has_bugs
# @example
#   bug -sd 3 "${FUNCNAME[0]}() requires argument 1 to be a file (provided '${1-<missing>}')." -ec "$err_not_file"   # the form before the leading code
#-----------------------------------------------------------------------------------------------
function bug()
{
    # scan the arguments for --error-code to record it in __last_bug
    local -a _args=()

    if is_exit_code "${1-}"; then
        _args=("${@:2}" -ec "$1")
    else
        _args=("$@")
    fi

    __last_bug=$failure
    local -i _i
    for (( _i = 0; _i < ${#_args[@]}; _i++ )); do
        [[ ${_args[_i]} == "-ec" || ${_args[_i]} == "--error-code" ]] || continue
        (( _i + 1 < ${#_args[@]} )) && is_exit_code "${_args[_i + 1]}" && __last_bug=${_args[_i + 1]}
    done

    __message "$bug_prefix" "${_args[@]}" > >(tee_stderr); wait "$!" || true
    local -i _depth=${#FUNCNAME[@]}
    (( __bugs == 0 || _depth < __bugs_min_depth )) && __bugs_min_depth=$_depth
    (( ++__bugs ))
    return "$success"
}

#-----------------------------------------------------------------------------------------------
# @description Logs a bug message to stderr (via `bug`) and exits immediately: for a broken
#   contract that the code cannot go past, where `bug` followed by `exit_if_has_bugs` would only
#   add a line.
#
# @arg $@ The same arguments as `bug`, including the optional leading error code.
#
# @stderr string The formatted bug message, prefixed with `$bug_prefix`.
#
# @exitcode N: never returns -- always exits the script with the code that `bug` recorded in
#   `$__last_bug` (a leading code, or the last `-ec`/`--error-code`; `$failure` if there is
#   none), or `$err_has_bugs` if that code is 0.
#
# @example
#   exit_with_bug "$err_logic_error" "The case for '$_kind' is not implemented."
# @example
#   exit_with_bug --no-stack "Invalid file specified." -ec "$err_not_file"   # the form before the leading code
#-----------------------------------------------------------------------------------------------
function exit_with_bug()
{
    bug "$@"

    local -i _ec=$(( __last_bug != success ? __last_bug : err_has_bugs ))

    exit "$_ec"
}

#-----------------------------------------------------------------------------------------------
# @description Logs a warning message to stderr (via `__message()`, prefixed with
#   `$warning_prefix`).
#
# @arg $@ string Warning message parts. May include the named parameters as described in
#   `__message()`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @stderr string The formatted warning message, prefixed with `$warning_prefix`.
#
# @exitcode success=0: Message printed successfully.
#
# @example
#   warning "The option is deprecated"
# @example
#   warning -sd 3 "Missing optional configuration"
#-----------------------------------------------------------------------------------------------
function warning()
{
    __message "$warning_prefix" --no-stack "$@" > >(tee_stderr); wait "$!" || true
}

#-----------------------------------------------------------------------------------------------
# @description Displays the passed-in warning about a variable's value, and sets that variable
#   to a specified default value.
#
# Notes:
#   - This function uses a bash nameref (`local -n`) to set the variable by name. Do NOT pipe
#     a call to this function into `tee_stdout` or similar -- the left side of a pipe runs in a
#     subshell, so the variable assignment would be lost (see the file-level warning at the
#     top of this file).
#
# @arg $1 nameref to a variable to assign the default value to.
# @arg $2 string The warning message to display.
# @arg $3 string The default value to assign to the variable.
#
# @stderr string The formatted warning message, prefixed with `$warning_prefix`.
#
# @exitcode success=0: The variable was set successfully.
#
# @example
#   warning_var timeout "Timeout not specified." 30
#-----------------------------------------------------------------------------------------------
function warning_var()
{
    (( $# == 3 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 3 arguments (provided $#):" \
                                                                                                                "  - variable name" \
                                                                                                                "  - warning message" \
                                                                                                                "  - default value"
    [[ ! -v 1 ]] || { is_variable "$1" && is_mutable "$1"; }                    || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name a writable variable to set to the default value (provided '${1-<missing>}')."
    [[ ! -v 2 || -n $2 ]]                                                       || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the warning message, to be non-empty (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    warning "$2" "Assuming the default value of '$3'."

    local -n __var=$1;
    __var="$3"
}

#-----------------------------------------------------------------------------------------------
# @description Logs an informational message to stdout (via `__message()`, prefixed with
#   `$info_prefix`).
#
# @arg $@ string Informational message parts. May include the named parameters as described in
#   `__message()`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @stdout string The formatted info message, prefixed with `$info_prefix`.
#
# @exitcode success=0: Message printed successfully.
#
# @example
#   info "Starting build process"
# @example
#   info "Configuration loaded from '$config_file':" "$(jq . "$config_file")"
#-----------------------------------------------------------------------------------------------
function info()
{
    __message "$info_prefix" --no-stack "$@" > >(tee_stdout); wait "$!" || true
}

#-----------------------------------------------------------------------------------------------
# @description Logs a trace message to stderr (via `__message()`, prefixed with `$trace_prefix`),
#   but only when verbose mode is enabled.
#
# @arg $@ string Trace message parts. May include the named parameters as described in
#   `__message()`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error
#       message and included in the output. May occur multiple times.
#     - `--stack-skip`|`-ss` followed by an integer -- how many stack frames to skip before
#       showing the stack (default: 2). May occur multiple times; only the last occurrence
#       takes effect.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). If given more than once, only the last occurrence takes
#       effect.
#     - `--no-stack`|`-ns` do not dump the stack. May occur multiple times with
#       `--stack-depth`/`-sd`; only the last occurrence takes effect.
#
# @stderr string The formatted trace message, prefixed with `$trace_prefix`.
#
# @exitcode success=0: Message printed successfully.
#
# @example
#   trace "Processing item: $item"
# @example
#   trace "Debug: variable value = '$var'"
#-----------------------------------------------------------------------------------------------
function trace()
{
    is_verbose || return "$success"
    __message "$trace_prefix" --no-stack "$@" >&2
}
