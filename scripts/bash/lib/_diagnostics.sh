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
# Summary: Logs messages to stdout, allowing override in other scripts for alternate destinations.
# Parameters: none (reads from stdin)
# Returns:
#   stdout: each line read from stdin
#   Exit code: always 0
# Usage: echo "message" | to_stdout
# Example: echo "Build completed" | to_stdout
# Notes: Can be overridden in scripts like gh_core.sh to redirect to GitHub Actions step summary.
#-------------------------------------------------------------------------------
function to_stdout()
{
    local line

    while IFS= read -r line; do
        echo "$line"
    done
}

#-------------------------------------------------------------------------------
# Summary: Logs trace messages to stderr, allowing override in other scripts for alternate destinations.
# Parameters: none (reads from stdin)
# Returns:
#   stderr: each line read from stdin
#   Exit code: always 0
# Usage: echo "message" | to_traceout
# Example: echo "Processing file: $file" | to_traceout
# Notes: Can be overridden in scripts like gh_core.sh to redirect to GitHub Actions step summary.
#-------------------------------------------------------------------------------
function to_traceout()
{
    local line

    while IFS= read -r line; do
        echo "$line" >&2
    done
}

#-------------------------------------------------------------------------------
# Summary: Logs messages to stderr, allowing override in other scripts for alternate destinations.
# Parameters: none (reads from stdin)
# Returns:
#   stderr: each line read from stdin
#   Exit code: always 0
# Usage: echo "message" | to_stderr
# Example: echo "Warning: file not found" | to_stderr
# Notes: Can be overridden in scripts like gh_core.sh to redirect to GitHub Actions step summary.
#-------------------------------------------------------------------------------
function to_stderr()
{
    local line

    while IFS= read -r line; do
        echo "$line" >&2
    done
}

#-------------------------------------------------------------------------------
# Summary: Returns the current value of the global error counter.
# Parameters: none
# Returns:
#   Exit code: the current value of the global error counter
# Env. Vars:
#   errors - global error counter
# Usage: if [[ $(get_errors) -gt 0 ]]; then ...; fi
# Example:
#   if [[ $(get_errors) -gt 0 ]]; then
#     echo "Errors were encountered."
#   else
#     echo "No errors."
#   fi
#-------------------------------------------------------------------------------
function get_errors()
{
    echo "$errors"
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Checks if the global error counter has any errors.
# Parameters: none
# Returns:
#   Exit code: 0 if no errors, 1 if errors exist
# Env. Vars:
#   errors - global error counter
# Usage: if has_errors; then ...; fi
# Example:
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
    error  -sd 3 -ec "$err_not_overridden" \
            "This implementation of usage() is meant to be an 'abstract declaration'." \
            "Either re-define usage() or source _args.sh." \
            "$@"
    exit "$failure";
}

#-------------------------------------------------------------------------------
# Summary: Tests the global error counter and exits if errors were encountered.
# Parameters:
# Returns:
#   Exit code: 2 if errors exist, 0 otherwise
# Env. Vars:
#   errors - global error counter
# Usage: exit_if_has_errors
# Example:
#   exit_if_has_errors  # exits with code 2 if errors exist
#-------------------------------------------------------------------------------
function exit_if_has_errors()
{
    # shellcheck disable=SC2154 # errors is referenced but not assigned.
    has_errors && usage "$failure" "$errors error(s) encountered. Please fix the above issues and try again."
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Sets the global error counter.
# Parameters: the new value for the global error counter
# Returns:
#   Exit code: always 0
# Env. Vars:
#   errors - global error counter
# Usage: set_errors <value>
# Example:
#   set_errors 0  # sets the global error counter to zero
#-------------------------------------------------------------------------------
function set_errors()
{
    (( $# == 1 )) || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() requires one argument ($# provided): the new value for the global error counter."
        return "$err_invalid_arguments"
    }
    [[ $1 =~ ^[0-9]+$ ]] || {
        error  -sd 3 "${FUNCNAME[0]}() requires a numeric argument: the new value for the global error counter."
        return "$err_argument_type"
    }

    # shellcheck disable=SC2154 # errors is referenced but not assigned.
    errors=$1
}

#-------------------------------------------------------------------------------
# Summary: Resets the global error counter to zero.
# Parameters: none
# Returns:
#   Exit code: always 0
# Env. Vars:
#   errors - global error counter
# Usage: reset_errors
# Example:
#   reset_errors  # sets the global error counter to zero
#-------------------------------------------------------------------------------
function reset_errors()
{
    # shellcheck disable=SC2154 # errors is referenced but not assigned.
    errors=0
}

#-------------------------------------------------------------------------------
# Summary: INTERNAL! prints messages with a given prefix and optional stack depth.
# Parameters:
#   1 - prefix - the prefix to prepend to each message line
#   2+ - message - message parts (optional, if not provided reads from stdin)
# Named parameters:
#   "--error-code" or "-ec" followed by a positive error code - the function will translate the error code to a message and
#                                                               include it in the output.
#   "--stack-depth" or "-sd" followed by an integer - how many stack frames to show in the message (default: 0)
#
#   There maybe multiple occurrences of "-ec" followed by error codes in the message parts, and all of them will be
#   translated to messages and included in the output.
#   Also there maybe multiple occurrences of "--stack-depth" followed by integers in the message parts, but only the last one
#   will be used to determine the stack depth to show in the message.
# Returns:
#   stdout: formatted message with prefix
#   Exit code: always 0
#-------------------------------------------------------------------------------
function message()
{
    local -i count=$# # count of arguments passed to the function
    local -i updated_count=$count # updated count of message parts after processing named parameters

    (( count > 0 )) || {
        error -ec "$err_missing_argument" -sd 4 "Function called without any parameters. Provide at least a prefix as the first parameter."
        return "$err_missing_argument"
    }
    [[ $count -gt 1 || ! -t 0 ]] || {
        # no message arguments were passed and nothing is being piped in on stdin
        error -ec "$err_missing_argument" -sd 4 "Function called without message parameters and there are none in the pipe. Provide message parameters or pipe them into the function."
        return "$err_missing_argument"
    }

    # The first parameter is the prefix to prepend to each message line, e.g. "ERROR: ", "WARN: ", "INFO: ", etc.
    local prefix="$1"
    shift
    (( updated_count-- )) || true # decrement the count of message parts to account for the prefix

    # The remaining parameters are the message parts or error codes to be translated to messages.
    # If there are no remaining parameters, the message will be read from stdin.

    local args=("$@")
    local -i depth=0 # stack dump depth

    local -i i
    # preprocess the arguments array for -ec and -sd flags, and then print the messages lines with the prefix.
    for (( i=0; i < count-1; i++ )); do
        case "${args[i]}" in

            "--error-code"|"-ec" )
                is_positive "${args[i+1]:-}" &&
                    args[i]="$(error_message "${args[i+1]}")" || {
                        warning "Expected a positive number that is a known error code after '${args[i]}', but got '${args[i+1]:-}'. Skipping both arguments."
                        unset "args[i]"
                        (( updated_count-- )) || true # decrement the count of message parts if the error code is invalid
                    }
                (( i++ )) # skip the next argument (the error code)
                if (( i < count )); then
                    unset "args[i]" # remove the code from the arguments array
                    (( updated_count-- )) || true # decrement the count of message parts if the error code is invalid
                fi
                continue
                ;;

            "--stack-depth"|"-sd" )
                is_positive "${args[i+1]:-}" &&
                    depth="${args[i+1]}" ||
                    warning "Expected a positive error code after '${args[i]}', but got '${args[i+1]:-}'. Skipping both arguments."
                unset "args[i]" # remove the flag from the arguments array
                (( updated_count-- )) || true # decrement the count of message parts if the error code is invalid
                (( i++ )) # skip the next argument (the stack depth)
                if (( i < count )); then
                    unset "args[i]" # remove the code from the arguments array
                    (( updated_count-- )) || true # decrement the count of message parts if the error code is invalid
                fi
                continue
                ;;

            * )
        esac
    done

    [[ $updated_count -gt 0 || ! -t 0 ]] || {
        # no message arguments were passed and nothing is being piped in on stdin
        error -ec "$err_missing_argument" -sd 4 "Function called without message parameters and there are none in the pipe. Provide message parameters or pipe them into the function."
        return "$err_missing_argument"
    }

    local first=true

    function __print_line()
    {
        if $first; then
            (( depth == 0 )) &&
                printf "%s%s\n" "$prefix" "$1" ||
                printf "%s%s (%s): %s\n" "$prefix" "${BASH_SOURCE[3]:-}" "${BASH_LINENO[2]:-}" "$1"
            first=false
        else
            echo "           $1"
        fi
        return "$success"
    }

    if (( updated_count > 0 )); then
        for line in "${args[@]}"; do
            [[ -n $line ]] && __print_line "$line"
        done
    else
        while IFS= read -r line; do
            __print_line "$line"
        done
    fi

    (( depth > 0 )) &&
        # skips the frames of
        #   3 show_stack()
        #   2 message()
        #   1 the caller of message() -- e.g. error()
        # basically show where the error or trace was called from.
        show_stack 3 "$depth" true

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Logs error messages to stderr and increments the global error counter.
# Parameters:
#   1 - depth (optional) - how many stack frames to show in the message (default: 0)
#   1+ - message - error message parts (optional, if not provided reads from stdin)
#        Here you can include named parameters:
#        Named parameters:
#          "--error-code" or "-ec", followed by a positive error code - the function will translate the error code to a message
#                                                                       and include it in the output.
#          "--stack-depth" or "-sd", followed by an integer - how many stack frames to show in the message (default: 0)
#
#            There maybe multiple occurrences of "-ec" followed by error codes in the message parts, and all of them
#            will be translated to messages and included in the output.
#            Also there maybe multiple occurrences of "--stack-depth" followed by integers in the message parts, but only the
#            last one will be used to determine the stack depth to show in the message.
# Returns:
#   stderr: formatted error message with '❌  ERROR: ' prefix via to_stderr
#   Exit code: always 0
# Side Effects: Increments the global $errors counter
# Usage: error [<depth>] [message2...]
# Example:
#   error "File not found: $filename"
#   echo "Build failed" | error 3
#-------------------------------------------------------------------------------
declare -xr error_prefix="❌  ERROR: "

function error()
{
    (( ++errors ))
    message "$error_prefix" "$@" > >(to_stderr)
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Logs warning messages to stderr.
# Parameters:
#   1 - depth (optional) - how many stack frames to show in the message (default: 0)
#   1+ - message - warning message parts (optional, if not provided reads from stdin)
#        Here you can include named parameters:
#        Named parameters:
#          "--error-code" or "-ec", followed by a positive error code - the function will translate the error code to a message
#                                                                       and include it in the output.
#          "--stack-depth" or "-sd", followed by an integer - how many stack frames to show in the message (default: 0)
#
#            There maybe multiple occurrences of "-ec" followed by error codes in the message parts, and all of them
#            will be translated to messages and included in the output.
#            Also there maybe multiple occurrences of "--stack-depth" followed by integers in the message parts, but only the
#            last one will be used to determine the stack depth to show in the message.
# Returns:
#   stderr: formatted warning message with '⚠️  WARN: ' prefix via to_stderr
#   Exit code: always 0
# Usage: warning <message1> [message2...]
# Example:
#   warning "The option is deprecated"
#   echo "Missing optional configuration" | warning 3
#-------------------------------------------------------------------------------
declare -xr warning_prefix="⚠️  WARN: "

function warning()
{
    message "$warning_prefix" "$@" > >(to_stderr)
}

#-------------------------------------------------------------------------------
# Summary: Logs informational messages to stdout.
# Parameters:
#   1 - depth (optional) - how many stack frames to show in the message (default: 0)
#   1+ - message - informational message parts (optional, if not provided reads from stdin)
#        Here you can include named parameters:
#        Named parameters:
#          "--error-code" or "-ec", followed by a positive error code - the function will translate the error code to a message
#                                                                       and include it in the output.
#          "--stack-depth" or "-sd", followed by an integer - how many stack frames to show in the message (default: 0)
#
#            There maybe multiple occurrences of "-ec" followed by error codes in the message parts, and all of them
#            will be translated to messages and included in the output.
#            Also there maybe multiple occurrences of "--stack-depth" followed by integers in the message parts, but only the
#            last one will be used to determine the stack depth to show in the message.
# Returns:
#   stdout: formatted info message with 'ℹ️  INFO: ' prefix via to_stdout
#   Exit code: always 0
# Usage: info <message1> [message2...]
# Example:
#   info "Starting build process"
#   echo "Configuration loaded" | info
#-------------------------------------------------------------------------------
declare -xr info_prefix="ℹ️  INFO: "

function info()
{
    message "$info_prefix" "$@" > >(to_stdout)
}

#-------------------------------------------------------------------------------
# Summary: Logs trace messages to stdout when verbose mode is enabled.
# Parameters:
#   1 - depth (optional) - how many stack frames to show in the message (default: 0)
#   1+ - message - trace message parts (optional, if not provided reads from stdin)
#        Here you can include named parameters:
#        Named parameters:
#          "--error-code" or "-ec", followed by a positive error code - the function will translate the error code to a message
#                                                                       and include it in the output.
#          "--stack-depth" or "-sd", followed by an integer - how many stack frames to show in the message (default: 0)
#
#            There maybe multiple occurrences of "-ec" followed by error codes in the message parts, and all of them
#            will be translated to messages and included in the output.
#            Also there maybe multiple occurrences of "--stack-depth" followed by integers in the message parts, but only the
#            last one will be used to determine the stack depth to show in the message.
# Returns:
#   stdout: formatted trace message with '🐾  TRACE: ' prefix via to_trace-out (only when verbose=true)
#   Exit code: always 0
# Env. Vars:
#   verbose - when true, outputs trace messages; when false, suppresses output
# Usage: trace <message1> [message2...]
# Example:
#   trace "Processing item: $item"
#   echo "Debug: variable value = $var" | trace
#-------------------------------------------------------------------------------
declare -xr trace_prefix="🐾  TRACE: "

function trace()
{
    ! $verbose && return "$success"
    message "$trace_prefix" "$@" > >(to_traceout)
}

#-------------------------------------------------------------------------------
# Summary: Logs a warning about a variable's value and set that variable
#          to specified default value.
# Parameters:
#   1 - variable_name (nameref!) - name of the variable to set
#   2 - warning_message - warning message to display
#   3 - default_value - default value to assign to the variable
# Returns:
#   stderr: warning message via warning function
#   Exit code: 0 on success, 1 on error
# Side Effects: Sets the named variable to the default value
# Usage: warning_var <variable_name> <warning_message> <default_value>
# Example: warning_var timeout "Timeout not specified." 30
# WARNING: This function uses nameref to set the variable by name. DO NOT PIPE
#   this function into to_stdout or similar, as it will run in a subshell and
#   the variable assignment will be lost.
#-------------------------------------------------------------------------------
function warning_var()
{
    (( $# == 3 )) || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() requires three arguments ($# provided): variable name, warning message, and default value."
        return "$err_invalid_arguments"
    }
    [[ -n "$1" && -n "$2" ]] || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() requires three arguments: variable name, warning message, and default value."
        return "$err_argument_value"
    }
    [[ $1 =~ $varNameRegex ]] || {
        error -ec "$err_invalid_arguments" -sd 3 "${FUNCNAME[0]}() requires a non-empty variable name as argument."
        return "$err_invalid_nameref"
    }
    warning "$2" "Assuming the default value of '$3'."

    local -n var=$1;
    # shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
    var="$3"
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Displays the current call stack to stdout (consider redirecting to stderr)
# Parameters:
#   1 - skip (optional) - how many stack frames to skip; defaults to 0
#   2 - take (optional) - how many stack frames to show; defaults to 1
#   3 - verbose (optional) - if true, outputs the stack trace; if false, does nothing;
#       defaults to the value of the global $verbose variable or false if not set
# Returns:
#   stdout: formatted stack trace showing function names, files, and line numbers
#           (consider redirecting to stderr)
#   Exit code: always 0
# Env. Vars:
#   verbose - when true, displays stack trace; when false, does nothing
# Usage: show_stack
# Example: show_stack  # typically called during debugging or error handling
#-------------------------------------------------------------------------------
function show_stack()
{
    local v=${3:-"${verbose:-false}"}

    ! $v && return "$success"

    local skip=${1:-1}                              # by default skip this call
    local max_take=$(( ${#FUNCNAME[@]} - skip ))    # take no more than the remaining stack frames
    local take=${2:-$max_take}
    (( take = take < max_take ? take : max_take ))   # adjust take if it exceeds the available stack frames
    (( take <= 0 )) && return "$success"

    local func
    local source
    local lineno

    local -i index
    local end=$(( skip + take ))
    for (( index=skip; index<end; index++ )); do
        func=${FUNCNAME[index]:-}
        source=${BASH_SOURCE[index]:-}
        lineno=${BASH_LINENO[index-1]:-}
        printf "    - %-20s (%s: %d)\n" "$func" "${source}" "${lineno}"
    done

    return "$success"
}
