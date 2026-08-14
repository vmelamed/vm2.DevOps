# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines diagnostic functions for logging messages to stdout, stderr, and trace output.
# It also defines a global error counter and functions to manipulate it.
#-------------------------------------------------------------------------------

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ IMPORTANT: The to_* functions are designed to be used on the RIGHT side   ║
# ║ of a pipe. Never pipe a function that SETS VARIABLES into a to_* function.║
# ║ The left side of a pipe runs in a subshell — all variable assignments are ║
# ║ lost. Use two separate lines instead.                                     ║
# ║                                                                           ║
# ║   NO: warning_var x "msg" "default" | to_stdout  # assigns "default" to x ║
# ║                                                  # in a subshell. The side║
# ║                                                  # effect is lost on the  ║
# ║                                                  # next line.             ║
# ║                                                                           ║
# ║  YES: x="default"                                                         ║
# ║       echo "msg" | to_stdout                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# shellcheck disable=SC2154 # variable is referenced but not assigned.

# Circular include guard
(( ${__VM2_LIB_DIAGNOSTICS_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_DIAGNOSTICS_SH_LOADED=1

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative

# global error counter
declare -rxi err_invalid_arguments

declare -xi errors=0

#-------------------------------------------------------------------------------
# @description Logs messages to stdout. Designed to be overridden in other scripts to redirect to alternate
# destinations.
#
# Notes:
#   - Can be overridden in scripts like `gh_core.sh` to redirect to the GitHub Actions step summary.
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @stdout string Each line read from stdin, echoed back unchanged.
#
# @exitcode 0 Always.
#
# @example
#   echo "Build completed" | to_stdout
#-------------------------------------------------------------------------------
function to_stdout()
{
    local _line

    while IFS= read -r _line; do
        echo "$_line"
    done
}

#-------------------------------------------------------------------------------
# @description Logs trace messages to stderr. Designed to be overridden in other scripts to redirect to alternate
# destinations.
#
# Notes:
#   - Can be overridden in scripts like `gh_core.sh` to redirect to the GitHub Actions step summary.
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @exitcode 0 Always.
#
# @example
#   echo "Processing file: $file" | to_traceout
#-------------------------------------------------------------------------------
function to_traceout()
{
    local _line

    while IFS= read -r _line; do
        echo "$_line" >&2
    done
}

#-------------------------------------------------------------------------------
# @description Logs messages to stderr. Designed to be overridden in other scripts to redirect to alternate
# destinations.
#
# Notes:
#   - Can be overridden in scripts like `gh_core.sh` to redirect to the GitHub Actions step summary.
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @exitcode 0 Always.
#
# @example
#   echo "Warning: file not found" | to_stderr
#-------------------------------------------------------------------------------
function to_stderr()
{
    local _line

    while IFS= read -r _line; do
        echo "$_line" >&2
    done
}

#-------------------------------------------------------------------------------
# @description Returns the current value of the global error counter.
#
# @stdout int The current value of the global `$errors` counter.
#
# @exitcode 0 Always.
#
# @example
#   (( $(get_errors) == 0 )) && echo "No errors." || echo "Errors were encountered."
#-------------------------------------------------------------------------------
function get_errors()
{
    echo "$errors"
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Tests whether the global error counter has recorded any errors.
#
# @exitcode 0 ($positive) At least one error has been recorded (`$errors > 0`).
# @exitcode 1 ($negative) No errors have been recorded.
#
# @example
#   if has_errors; then
#     echo "Errors were encountered."
#   else
#     echo "No errors."
#   fi
#-------------------------------------------------------------------------------
function has_errors()
{
    return $(( errors > 0 ? positive : negative ))
}

## Should be overridden in the top level script by sourcing _args.sh, akin to forward declaration in C/C++
# Local implementation of usage() to avoid circular dependency with _args.sh
function usage()
{
    error -sd 3 -ec "$err_not_overridden" \
            "This implementation of usage() is meant to be an 'abstract declaration'." \
            "Either re-define usage() or source _args.sh." \
            "$@"
    exit "$failure";
}

#-------------------------------------------------------------------------------
# @description Tests the global error counter and exits the script (via `usage`) if any errors were recorded.
#
# @exitcode 0 No errors were recorded; execution continues normally.
#
# @example
#   exit_if_has_errors  # exits (via usage) with code 1 if errors exist
#-------------------------------------------------------------------------------
function exit_if_has_errors()
{
    # shellcheck disable=SC2154 # errors is referenced but not assigned.
    has_errors && usage "$failure" "$errors error(s) encountered. Please fix the above issues and try again."
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Sets the global error counter to a specific value.
#
# @arg $1 int The new value for the global error counter. Must be a non-negative integer.
#
# @exitcode 0 The counter was set.
# @exitcode 2 Wrong argument count, or the argument is not a non-negative integer.
#
# @example
#   set_errors 0  # sets the global error counter to zero
#-------------------------------------------------------------------------------
function set_errors()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires one argument ($# provided)."
    }
    [[ -v 1 && $1 =~ ^[0-9]+$ ]] || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be provided as a non-negative integer: the new value for the global error counter (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    # shellcheck disable=SC2154 # errors is referenced but not assigned.
    errors=$1
}

#-------------------------------------------------------------------------------
# @description Resets the global error counter to zero.
#
# @exitcode 0 Always.
#
# @example
#   reset_errors  # sets the global error counter to zero
#-------------------------------------------------------------------------------
function reset_errors()
{
    # shellcheck disable=SC2154 # errors is referenced but not assigned.
    errors=0
}

#-------------------------------------------------------------------------------
# @description INTERNAL! Prints one or more message lines with a given prefix, optionally translating embedded error
# codes to messages and appending a stack dump. Used internally by `error`, `warning`, `info`, and `trace` -- not
# meant to be called directly from top-level scripts.
#
# @arg $1 string The prefix to prepend to the first printed line (e.g. "ERROR: ", "WARN: ", "INFO: ").
# @arg $@ string The message parts to print, one per line. Optional -- if none are given (after removing the named
#   parameters below), the message is instead read line-by-line from stdin. May include these named parameters,
#   interspersed anywhere among the message parts:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error message (via
#       `error_message`) and substituted into the output in place of the flag and its argument. May occur multiple
#       times; every occurrence is translated.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below the message (default: 0).
#       May occur multiple times; only the last occurrence takes effect.
#
# @exitcode 0 Message printed successfully.
# @exitcode 4 ($err_missing_argument) No arguments were given at all, or no message parts remain after removing the
#   prefix and named parameters, and stdin is a terminal (i.e. there is nothing to read from a pipe either).
#
# @stdout string The formatted message: the prefix followed by the first line (prefixed further with the immediate
#   caller's source file and line number if `--stack-depth`/`-sd` was given a value greater than 0), then any
#   remaining lines indented to align under the first, then (if a stack depth was requested) the call stack via
#   `show_stack`.
#-------------------------------------------------------------------------------
function message()
{
    local -i _rc="$success"
    local -i _updated_count=$# # updated count of message parts after processing named parameters

    (( $# > 0 )) || {
        _rc="$err_missing_argument"
        error -sd 4 -ec "$_rc" "Function called without any parameters. Provide at least a prefix as the first parameter."
    }
    (( $# > 1 )) || [[ ! -t 0 ]] || {
        # no message arguments were passed and nothing is being piped in on stdin
        _rc="$err_missing_argument"
        error -sd 4 -ec "$_rc" "Function called without message parameters and there are none in the pipe. Provide message parameters or pipe them into the function."
    }

    (( _rc == success )) || return "$_rc"

    # The first parameter is the prefix to prepend to each message line, e.g. "ERROR: ", "WARN: ", "INFO: ", etc.
    local _prefix="$1"
    shift
    (( _updated_count-- )) || true # decrement the count of message parts to account for the prefix

    # The remaining parameters are the message parts or error codes to be translated to messages.
    # If there are no remaining parameters, the message will be read from stdin.

    local _args=("$@")
    local -i _depth=0 # stack dump depth

    local -i _index
    # preprocess the arguments array for -ec and -sd flags, and then print the messages lines with the prefix.
    for (( _index=0; _index < $#-1; _index++ )); do
        case "${_args[_index]}" in

            "--error-code"|"-ec" )
                is_positive "${_args[_index+1]:-}" &&
                    _args[_index]="$(error_message "${_args[_index+1]}")" || {
                        warning "Expected a positive number that is a known error code after '${_args[_index]}', but got '${_args[_index+1]:-}'. Skipping both arguments."
                        unset "_args[_index]"
                        (( _updated_count-- )) || true # decrement the count of message parts if the error code is invalid
                    }
                (( ++_index )) # skip the next argument (the error code)
                if (( _index < $# )); then
                    unset "_args[_index]" # remove the code from the arguments array
                    (( _updated_count-- )) || true # decrement the count of message parts if the error code is invalid
                fi
                continue
                ;;

            "--stack-depth"|"-sd" )
                is_positive "${_args[_index+1]:-}" &&
                    _depth="${_args[_index+1]}" ||
                    warning "Expected a positive error code after '${_args[_index]}', but got '${_args[_index+1]:-}'. Skipping both arguments."
                unset "_args[_index]" # remove the flag from the arguments array
                (( _updated_count-- )) || true # decrement the count of message parts if the error code is invalid
                (( ++_index )) # skip the next argument (the stack depth)
                if (( _index < $# )); then
                    unset "_args[_index]" # remove the code from the arguments array
                    (( _updated_count-- )) || true # decrement the count of message parts if the error code is invalid
                fi
                continue
                ;;

            * )
        esac
    done

    [[ $_updated_count -gt 0 || ! -t 0 ]] || {
        # no message arguments were passed and nothing is being piped in on stdin
        error -sd 4 -ec "$err_missing_argument" "Function called without message parameters and there are none in the pipe. Provide message parameters or pipe them into the function."
        return "$err_missing_argument"
    }

    local _first=true

    function __print_line()
    {
        if $_first; then
            (( _depth == 0 )) &&
                printf "%s%s\n" "$_prefix" "$1" ||
                printf "%s%s (%s): %s\n" "$_prefix" "${BASH_SOURCE[3]:-}" "${BASH_LINENO[2]:-}" "$1"
            _first=false
        else
            echo "           $1"
        fi
        return "$success"
    }

    if (( _updated_count > 0 )); then
        for _line in "${_args[@]}"; do
            [[ -n $_line ]] && __print_line "$_line"
        done
    else
        while IFS= read -r _line; do
            __print_line "$_line"
        done
    fi

    (( _depth > 0 )) &&
        # skips the frames of
        #   3 show_stack()
        #   2 message()
        #   1 the caller of message() -- e.g. error()
        # basically show where the error or trace was called from.
        show_stack 3 "$_depth" true

    return "$success"
}

declare -xr error_prefix="❌  ERROR: "

#-------------------------------------------------------------------------------
# @description Logs an error message to stderr (via `message`, prefixed with `$error_prefix`) and increments the
# global error counter.
#
# Notes:
#   - Increments the global `$errors` counter by 1, every call.
#
# @arg $@ string Error message parts (optional -- if none are given, the message is read from stdin instead). May
#   include the named parameters described in `message`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error message and included in
#       the output. May occur multiple times.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below the message (default: 0).
#       If given more than once, only the last occurrence takes effect.
#
# @exitcode 0 Message printed successfully.
# @exitcode 4 ($err_missing_argument) No message parts were given and stdin is a terminal (nothing to read).
#
# @example
#   error "File not found: $filename"
# @example
#   error -sd 3 "Build failed"
#-------------------------------------------------------------------------------
function error()
{
    (( ++errors ))
    message "$error_prefix" "$@" > >(to_stderr)
}

declare -xr warning_prefix="⚠️  WARN: "

#-------------------------------------------------------------------------------
# @description Logs a warning message to stderr (via `message`, prefixed with `$warning_prefix`).
#
# @arg $@ string Warning message parts (optional -- if none are given, the message is read from stdin instead). May
#   include the named parameters described in `message`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error message and included in
#       the output. May occur multiple times.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below the message (default: 0).
#       If given more than once, only the last occurrence takes effect.
#
# @exitcode 0 Message printed successfully.
# @exitcode 4 ($err_missing_argument) No message parts were given and stdin is a terminal (nothing to read).
#
# @example
#   warning "The option is deprecated"
# @example
#   warning -sd 3 "Missing optional configuration"
#-------------------------------------------------------------------------------
function warning()
{
    message "$warning_prefix" "$@" > >(to_stderr)
}

declare -xr info_prefix="ℹ️  INFO: "

#-------------------------------------------------------------------------------
# @description Logs an informational message to stdout (via `message`, prefixed with `$info_prefix`).
#
# @arg $@ string Informational message parts (optional -- if none are given, the message is read from stdin
#   instead). May include the named parameters described in `message`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error message and included in
#       the output. May occur multiple times.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below the message (default: 0).
#       If given more than once, only the last occurrence takes effect.
#
# @stdout string The formatted info message, prefixed with `$info_prefix`.
#
# @exitcode 0 Message printed successfully.
# @exitcode 4 ($err_missing_argument) No message parts were given and stdin is a terminal (nothing to read).
#
# @example
#   info "Starting build process"
# @example
#   echo "Configuration loaded" | info
#-------------------------------------------------------------------------------
function info()
{
    message "$info_prefix" "$@" > >(to_stdout)
}

declare -xr trace_prefix="🐾  TRACE: "

#-------------------------------------------------------------------------------
# @description Logs a trace message to stderr (via `message`, prefixed with `$trace_prefix`), but only when verbose
# mode is enabled.
#
# @arg $@ string Trace message parts (optional -- if none are given, the message is read from stdin instead, unless
#   verbose mode is off, in which case stdin is never read). May include the named parameters described in
#   `message`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to its error message and included in
#       the output. May occur multiple times.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below the message (default: 0).
#       If given more than once, only the last occurrence takes effect.
#
# @exitcode 0 Verbose mode is off (message suppressed without being processed), or the message was printed
#   successfully.
# @exitcode 4 ($err_missing_argument) Verbose mode is on, no message parts were given, and stdin is a terminal
#   (nothing to read).
#
# @example
#   trace "Processing item: $item"
# @example
#   echo "Debug: variable value = $var" | trace
#-------------------------------------------------------------------------------
function trace()
{
    ! $verbose && return "$success"
    message "$trace_prefix" "$@" > >(to_traceout)
}

#-------------------------------------------------------------------------------
# @description Logs a warning about a missing or invalid variable's value, and sets that variable to a specified
# default value.
#
# Notes:
#   - This function uses a bash nameref (`local -n`) to set the variable by name. Do NOT pipe a call to this
#     function into `to_stdout` or similar -- the left side of a pipe runs in a subshell, so the variable assignment
#     would be lost (see the file-level warning at the top of this file).
#
# @arg $1 nameref The name of the variable to set.
# @arg $2 string The warning message to display.
# @arg $3 string The default value to assign to the named variable.
#
# @exitcode 0 The variable was set successfully.
# @exitcode 2 ($err_invalid_arguments) Wrong argument count, an empty variable name or warning message, or the
#   variable name does not match `$varNameRegex`.
#
# @example
#   warning_var timeout "Timeout not specified." 30
#-------------------------------------------------------------------------------
function warning_var()
{
    local -i _rc="$success"

    (( $# == 3 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires three arguments ($# provided): variable name, warning message, and default value."
    }
    [[ -n $1 ]] && is_variable_name "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be a valid variable name (provided '${1-<missing>}')."
    }
    [[ -n $2 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the warning message, to be non-empty (provided '${2-<missing>}')."
    }
    [[ -v 3 ]] || {
        _rc="$err_missing_argument"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 3, the default value, to be provided."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    warning "$2" "Assuming the default value of '$3'."

    local -n _var=$1;
    # shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
    _var="$3"
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Displays the current call stack. Consider redirecting the output to stderr at the call site.
#
# @arg $1 int How many stack frames to skip, not including the caller of `show_stack`. Optional, default: 0.
# @arg $2 int How many stack frames to show. Optional, default: all remaining frames after the skip.
# @arg $3 bool Whether to output the stack trace at all. Optional, default: the value of the global `$verbose`
#   variable, or `false` if that is unset.
#
# @exitcode 0 Always.
#
# @stdout string The formatted stack trace, one line per frame, showing function name, source file, and line number
#   (consider redirecting to stderr at the call site).
#
# @example
#   show_stack  # typically called during debugging or error handling
#-------------------------------------------------------------------------------
function show_stack()
{
    local _v=${3:-"${verbose:-false}"}

    ! $_v && return "$success"

    local _skip=${1:-0}
    (( ++_skip ))                                    # skip the frame of this call

    local _max_take=$(( ${#FUNCNAME[@]} - _skip ))    # take no more than the remaining stack frames
    local _take=${2:-$_max_take}

    (( _take = _take < _max_take ? _take : _max_take ))  # adjust take if it exceeds the available stack frames
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
        printf "    - %-20s (%s: %d)\n" "$_func" "$_source" "$_lineno"
    done

    return "$success"
}
