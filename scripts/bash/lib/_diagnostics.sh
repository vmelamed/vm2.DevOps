# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

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

declare -rxi success
declare -rxi failure

declare -rxi positive
declare -rxi negative

declare -rxi err_invalid_arguments

#-------------------------------------------------------------------------------
# Summary: Logs messages to stdout, allowing override in other scripts for alternate destinations.
# Parameters: none (reads from stdin)
# Returns:
#   stdout: each line read from stdin
#   Exit code: 0 always
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
#   Exit code: 0 always
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
#   Exit code: 0 always
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

# global error counter
declare -ix errors=0

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
    # shellcheck disable=SC2154 # errors is referenced but not assigned.
    return $(( errors > 0 ? positive : negative ))
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
    has_errors && usage false "$errors error(s) encountered. Please fix the above issues and try again."
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Resets the global error counter to zero.
# Parameters: none
# Returns:
#   Exit code: 0 always
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

declare -r no_arguments="Function called without message parameters and there are none in the pipe. Provide message parameters or pipe them into the function."

function message()
{
    local prefix="$1"
    shift

    local -i depth=0

    is_natural "${1:-}" && depth=$1 && shift

    if [[ $# -eq 0 && -t 0 ]]; then
        # no message arguments were passed and nothing is being piped in on stdin
        error 4 "$no_arguments"
        return "$err_invalid_arguments"
    fi

    local first=true
    local line

    # shellcheck disable=SC2031 # line was modified in a subshell but the f-n is called in the same subshell, so it works as intended.
    function __print_line()
    {
        if $first; then
            (( depth == 0 )) && printf "%s%s\n" "$prefix" "$line" || printf "%s%s (%s): %s\n" "$prefix" "${BASH_SOURCE[1]:-}" "${BASH_LINENO[0]:-}" "$line"
            first=false
        else
            echo "           $line"
        fi
    }

    {
        # shellcheck disable=SC2030 # line was modified in a subshell but the f-n is called in the same subshell, so it works as intended.
        if (( $# > 0 )); then
            for line in "$@"; do
                __print_line
            done
        else
            while IFS= read -r line; do
                __print_line
            done
        fi
        (( depth > 0 )) && show_stack 3 "$depth" true # skips the frames of show_stack, message_out, and the message_out caller function - basically show where the error or trace was called from.
    }

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Logs error messages to stderr and increments the global error counter.
# Parameters:
#   1+ - message - error message parts (optional, if not provided reads from stdin)
#   Note that if the first parameter is a number - it will be treated as the depth of the stack to dump.
# Returns:
#   stderr: formatted error message with '❌  ERROR: ' prefix via to_stderr
#   Exit code: 0 always
# Side Effects: Increments the global $errors counter
# Usage: error [<depth>] [message2...]
# Example:
#   error "File not found: $filename"
#   echo "Build failed" | error 3
#-------------------------------------------------------------------------------
declare -xr error_prefix="❌  ERROR: "

function error()
{
    local -i rc=0

    message "$error_prefix" "$@" > >(to_stderr)
    rc=$?
    (( ++errors ))
    return "$rc"
}

#-------------------------------------------------------------------------------
# Summary: Logs warning messages to stderr.
# Parameters:
#   1+ - message - warning message parts (optional, if not provided reads from stdin)
#   Note that if the first parameter is a number - it will be treated as the depth of the stack to dump.
# Returns:
#   stderr: formatted warning message with '⚠️  WARN: ' prefix via to_stderr
#   Exit code: 0 always
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
#   1+ - message - informational message parts (optional, if not provided reads from stdin)
# Returns:
#   stdout: formatted info message with 'ℹ️  INFO: ' prefix via to_stdout
#   Exit code: 0 always
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
#   1+ - message - trace message parts (optional, if not provided reads from stdin)
# Returns:
#   stdout: formatted trace message with '🐾  TRACE: ' prefix via to_trace-out (only when verbose=true)
#   Exit code: 0 always
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
# Summary: Logs a warning about a variable's value and sets it to a default value.
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
        error 3 "${FUNCNAME[0]}() requires three arguments ($# provided): variable name, warning message, and default value."
        return "$err_invalid_arguments"
    }
    [[ -n "$1" && -n "$2" ]] || {
        error 3 "${FUNCNAME[0]}() requires three arguments: variable name, warning message, and default value."
        return "$err_argument_value"
    }
    warning "$2" "Assuming the default value of '$3'."

    local -n var=$1;
    # shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
    var="$3"
    return "$success"
}

# When on_debug is specified as a handler of the DEBUG trap, remembers the last invoked bash command in $last_command.
# on_debug and on_exit are trying to cooperatively do error handling when exit is invoked. To be effective, after
# sourcing this script, set these signal traps:
#   trap on_debug DEBUG
#   trap on_exit EXIT
declare last_command=""
declare current_command="$BASH_COMMAND"

#-------------------------------------------------------------------------------
# Summary: DEBUG trap handler that tracks the last executed command for error reporting.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects: Updates global variables $last_command and $current_command
# Usage: trap on_debug DEBUG
# Notes: Works cooperatively with on_exit for error handling. Automatically set by core.sh.
#-------------------------------------------------------------------------------
function on_debug()
{
    local rc=$?
    # keep track of the last executed command
    last_command="$current_command"
    current_command="$BASH_COMMAND"

    return "$rc"
}

#-------------------------------------------------------------------------------
# Assuming that the sourcing script didn't change directory, remember the current directory as the "initial".
#-------------------------------------------------------------------------------
initial_dir=$(pwd)
declare -rx initial_dir
declare -x allow_on_exit=true
declare -xr explicit_exit_regex='^exit([[:space:]]+.*)?$'


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
function on_exit()
{
    # echo an error message before exiting
    local ec=$?

    set +x

    if (( ec != 0 )) && $allow_on_exit && [[ ! ${last_command:-} =~ $explicit_exit_regex ]]; then
        printf "❌  ERROR: on-exit: the command '%s' failed with exit code %d\n" "${last_command:-'<unknown>'}" "$ec" >&2
    fi

    cd "$initial_dir" 2>/dev/null || true

    return "$ec"
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

    local i
    local end=$(( skip + take ))
    for (( i=skip; i<end; i++ )); do
        func=${FUNCNAME[i]:-}
        source=${BASH_SOURCE[i]:-}
        lineno=${BASH_LINENO[i-1]:-}
        printf "    - %-20s (%s: %d)\n" "$func" "${source}" "${lineno}"
    done

    return "$success"
}
