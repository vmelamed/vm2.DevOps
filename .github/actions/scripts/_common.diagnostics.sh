#!/bin/bash

# error counter
declare -ix errors=0

## Shell function to log error messages to the standard output and to the GitHub step summary (github_step_summary).
## Increments the error counter.
## Usage: `error <message1> [<message2> ...]`, or `echo "message" | error`, or error <<< "message"
function error()
{
    if [[ $# -gt 0 ]]; then
        echo "❌  ERROR: $*" >&2
    else
        while IFS= read -r line; do
            echo "❌  ERROR: $line" >&2
        done
    fi
    errors=$((errors + 1))
    return 0
}

## Shell function to log warning messages to the standard output and to the GitHub step summary (github_step_summary).
## Usage: `warning <message1> [<message2> ...]`, or `echo "message" | warning`, or warning <<< "message"
function warning()
{
    if [[ $# -gt 0 ]]; then
        echo "⚠️  WARNING: $*"
    else
        while IFS= read -r line; do
            echo "⚠️  WARNING: $line" >&2
        done
    fi
    return 0
}

## Shell function to log informational messages to the standard output and to the GitHub step summary (github_step_summary).
## Usage: info <message1> [<message2> ...]
function info()
{
    if [[ $# -gt 0 ]]; then
        echo "ℹ️  INFO: $*"
    else
        while IFS= read -r line; do
            echo "ℹ️  INFO: $line" >&2
        done
    fi
    return 0
}

## Shell function to log a warning about a variable's value and set it to a default value.
## GitHub step summary (github_step_summary).
## Usage: warning_var <variable_name> <warning message> <variable's default value>
function warning_var()
{
    warning "$2" "Assuming the default value of '$3'."
    local -n var="$1";
    # shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
    var="$3"
    return 0
}

## Logs a trace message if verbose mode is enabled.
## Usage: trace <message>
function trace() {
    # shellcheck disable=SC2154 # variable is referenced but not assigned.
    if [[ "$verbose" == true ]]; then
        echo "🐾 TRACE: $*" >&2
    fi
    return 0
}

# When on_debug is specified as a handler of the DEBUG trap, remembers the last invoked bash command in $last_command.
# on_debug and on_exit are trying to cooperatively do error handling when exit is invoked. To be effective, after
# sourcing this script, set these signal traps:
#   trap on_debug DEBUG
#   trap on_exit EXIT
declare last_command
declare current_command="$BASH_COMMAND"

# on_debug and on_exit are trying to cooperatively do error handling when exit is invoked. To be effective, after
# sourcing this script, set these signal traps:
#   trap on_debug DEBUG
#   trap on_exit EXIT
function on_debug() {
    # keep track of the last executed command
    last_command="$current_command"
    current_command="$BASH_COMMAND"
}

# on_exit when specified as a handler of the EXIT trap
#   * if on_debug handles the DEBUG trap, displays the failed command
#   * if $initial_dir is defined, changes the current working directory to it
#   * does `set +x`.
# on_debug and on_exit are trying to cooperatively do error handling when exit is invoked. To be effective, after
# sourcing this script, set these signal traps:
#   trap on_debug DEBUG
#   trap on_exit EXIT
function on_exit() {
    # echo an error message before exiting
    local x=$?
    if ((x != 0)) && [[ ! $last_command =~ exit.* ]]; then
        error "on_exit: '$last_command' command failed with exit code $x"
    fi
    if [[ -n "$initial_dir" ]]; then
        cd "$initial_dir" || exit
    fi
    set +x
}
