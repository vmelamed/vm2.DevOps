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
# ║                                                  # efect is lost on the   ║
# ║                                                  # next line.             ║
# ║                                                                           ║
# ║  YES: x="default"                                                         ║
# ║       warning "msg" | to_stdout                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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
# Usage: echo "message" | to_trace_out
# Example: echo "Processing file: $file" | to_trace_out
# Notes: Can be overridden in scripts like gh_core.sh to redirect to GitHub Actions step summary.
#-------------------------------------------------------------------------------
function to_trace_out()
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
# Summary: Logs error messages to stderr and increments the global error counter.
# Parameters:
#   1+ - message - error message parts (optional, if not provided reads from stdin)
# Returns:
#   stderr: formatted error message with ❌ prefix via to_stderr
#   Exit code: 0 always
# Side Effects: Increments the global $errors counter
# Usage: error <message1> [message2...]
# Example:
#   error "File not found: $filename"
#   echo "Build failed" | error
#-------------------------------------------------------------------------------
function error()
{
    local bash_source=${BASH_SOURCE[1]:-}
    local bash_lineno=${BASH_LINENO[0]:-}
    local line
    local first=true
    {
        if [[ $# -gt 0 ]]; then
            for line in "$@"; do
                if [[ "$first" == true ]]; then
                    printf "❌  ERROR: %s (%s): " "${bash_source}" "${bash_lineno}"
                    first=false
                fi
                echo "$line"
            done
        else
            while IFS= read -r line; do
                if [[ "$first" == true ]]; then
                    printf "❌  ERROR: %s (%s): " "${bash_source}" "${bash_lineno}"
                    first=false
                fi
                echo "$line"
            done
        fi
        show_stack 2 10 true
    } | to_stderr

    (( ++errors ))
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Logs warning messages to stderr.
# Parameters:
#   1+ - message - warning message parts (optional, if not provided reads from stdin)
# Returns:
#   stderr: formatted warning message with ⚠️ prefix via to_stderr
#   Exit code: 0 always
# Usage: warning <message1> [message2...]
# Example:
#   warning "Deprecated option used"
#   echo "Missing optional configuration" | warning
#-------------------------------------------------------------------------------
function warning()
{
    local bash_source=${BASH_SOURCE[1]:-}
    local bash_lineno=${BASH_LINENO[0]:-}
    local line
    local first=true

    {
        if [[ $# -gt 0 ]]; then
            for line in "$@"; do
                if [[ "$first" == true ]]; then
                    printf "⚠️  WARNING: %s (%s): " "${bash_source}" "${bash_lineno}"
                    first=false
                fi
                echo "$line"
            done
        else
            while IFS= read -r line; do
                if [[ "$first" == true ]]; then
                    printf "⚠️  WARNING: %s (%s): " "${bash_source}" "${bash_lineno}"
                    first=false
                fi
                echo "$line"
            done
        fi
        show_stack 2 10
    } | to_stderr

    return 0
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
    if [[ $# -ne 3 || -z "$1" || -z "$2" ]]; then
        error "${FUNCNAME[0]}() requires three parameters: variable name, warning message, and default value."
        return 1
    fi
    warning "$2" "Assuming the default value of '$3'."

    local -n var=$1;
    # shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
    var="$3"
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Logs informational messages to stdout.
# Parameters:
#   1+ - message - informational message parts (optional, if not provided reads from stdin)
# Returns:
#   stdout: formatted info message with "ℹ️  INFO: " prefix via to_stdout
#   Exit code: 0 always
# Usage: info <message1> [message2...]
# Example:
#   info "Starting build process"
#   echo "Configuration loaded" | info
#-------------------------------------------------------------------------------
function info()
{
    local first=true
    local line

    {
        if [[ $# -gt 0 ]]; then
            for line in "$@"; do
                if [[ "$first" == true ]]; then
                    printf "ℹ️  INFO: "
                    first=false
                fi
                echo "$line"
            done
        else
            while IFS= read -r line; do
                if [[ "$first" == true ]]; then
                    printf "ℹ️  INFO: "
                    first=false
                fi
                echo "$line"
            done
        fi
    } | to_stdout

    return 0
}

#-------------------------------------------------------------------------------
# Summary: Logs trace messages to stdout when verbose mode is enabled.
# Parameters:
#   1+ - message - trace message parts (optional, if not provided reads from stdin)
# Returns:
#   stdout: formatted trace message with 🐾 prefix via to_trace_out (only when verbose=true)
#   Exit code: 0 always
# Env. Vars:
#   verbose - when true, outputs trace messages; when false, suppresses output
# Usage: trace <message1> [message2...]
# Example:
#   trace "Processing item: $item"
#   echo "Debug: variable value = $var" | trace
#-------------------------------------------------------------------------------
function trace()
{
    # shellcheck disable=SC2154 # variable is referenced but not assigned.
    [[ "$verbose" != true ]] && return 0

    local line
    local first=true
    {
        if [[ $# -gt 0 ]]; then
            for line in "$@"; do
                if [[ "$first" == true ]]; then
                    printf "🐾 TRACE: "
                    first=false
                fi
                echo "$line"
            done
        else
            while IFS= read -r line; do
                if [[ "$first" == true ]]; then
                    printf "🐾 TRACE: "
                    first=false
                fi
                echo "$line"
            done
        fi
    } | to_trace_out
    return 0
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
    # keep track of the last executed command
    last_command="$current_command"
    current_command="$BASH_COMMAND"
}

#-------------------------------------------------------------------------------
# Assuming that the sourcing script didn't change directory, remember the current directory as the "initial".
#-------------------------------------------------------------------------------
initial_dir=$(pwd)
declare -rx initial_dir

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
    local x=$?
    if ((x != 0)) && [[ ! $last_command =~ exit.* ]]; then
        error "on_exit: '$last_command' command failed with exit code $x"
    fi
    cd "$initial_dir" || true
    set +x
}

#-------------------------------------------------------------------------------
# Summary: Displays the current call stack to stdout (consider redirecting to stderr)
# Parameters:
#   1 - skip (optional) - how many stack frames to skip; defaults to 0
#   2 - take (optional) - how many stack frames to show; defaults to 1
#   3 - verbose (optional) - if true, outputs the stack trace; if false, does nothing;
#       defaults to the value of the global $verbose variable
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

    [[ "$v" != true ]] && return 0

    local skip=${1:-1}
    local max_take=$(( ${#FUNCNAME[@]} - skip ))
    local take=$(( ${2:-$max_take} < max_take ? ${2:-$max_take} : max_take ))
    local end=$(( skip + take ))
    local i

    for (( i=skip; i<end; i++ )); do
        local func_name=${FUNCNAME[i]:-}
        local bash_source=${BASH_SOURCE[i+1]:-}
        local bash_lineno=${BASH_LINENO[i]:-}
        printf "    - %-12s (%s: %d)\n" "$func_name" "${bash_source}" "${bash_lineno}"
    done

    return 0
}
