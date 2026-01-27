# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# error counter
declare -ix errors=0

## Logs messages to /dev/stdout
## Usage: `echo "message" | to_stdout`, or to_stdout <<< "message" - used with pipes only
## While trivial and seemingly unnecessary this function allows for overriding in other scripts (see gh_core.sh) and sending the
## output to other destinations (e.g. GitHub Actions step summary file).
function to_stdout()
{
    local line
    {
        while IFS= read -r line; do
            echo "$line"
        done
    }
}

## Logs trace messages to /dev/stdout
## Usage: `echo "message" | to_trace_out`, or to_trace_out <<< "message" - used with pipes only
## While trivial and seemingly unnecessary this function allows for overriding in other scripts (see gh_core.sh) and sending the
## output to other destinations as well (e.g. GitHub Actions step summary file).
function to_trace_out()
{
    local line
    {
        while IFS= read -r line; do
            echo "$line"
        done
    }
}

## Logs messages to /dev/stderr
## Usage: `echo "message" | to_stderr`, or to_stderr <<< "message" - used with pipes only
## While trivial and seemingly unnecessary this function allows for overriding in other scripts (see gh_core.sh) and sending the
## output to other destinations as well (e.g. GitHub Actions step summary file).
function to_stderr()
{
    local line
    {
        while IFS= read -r line; do
            echo "$line" >&2
        done
    }
}

## Shell function to log error messages to the error output.
## Increments the error counter.
## Usage: `error <message1> [<message2> ...]`, or `echo "message" | error`, or error <<< "message"
function error()
{
    {
        if [[ $# -gt 0 ]]; then
            echo "❌  ERROR: $*"
        else
            local line
            while IFS= read -r line; do
                echo "❌  ERROR: $line"
            done
        fi
    } | to_stderr
    errors=$((errors + 1))
    return 0
}

## Shell function to log warning messages to the error output.
## Usage: `warning <message1> [<message2> ...]`, or `echo "message" | warning`, or warning <<< "message"
function warning()
{
    {
        if [[ $# -gt 0 ]]; then
            echo "⚠️  WARNING: $*"
        else
            local line
            while IFS= read -r line; do
                echo "⚠️  WARNING: $line"
            done
        fi
    } | to_stderr
    return 0
}

## Shell function to log a warning about a variable's value and set it to a default value.
## Usage: warning_var <variable_name> <warning message> <variable's default value>
function warning_var()
{
    warning "$2" "Assuming the default value of '$3'."
    local -n var="$1";
    # shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
    var="$3"
    return 0
}

## Shell function to log informational messages to the standard output.
## Usage: `info <message1> [<message2> ...]`, or `echo "message" | info`, or info <<< "message"
function info()
{
    {
        if [[ $# -gt 0 ]]; then
            echo "ℹ️  INFO: $*"
        else
            local line
            while IFS= read -r line; do
                echo "ℹ️  INFO: $line"
            done
        fi
    } | to_stdout
    return 0
}

## Logs a trace message to the standard output if verbose mode is enabled.
## Usage: `trace <message1> [<message2> ...]`, or `echo "message" | trace`, or trace <<< "message"
function trace()
{
    # shellcheck disable=SC2154 # variable is referenced but not assigned.
    [[ "$verbose" != true ]] && return 0

    {
        if [[ $# -gt 0 ]]; then
            echo "🐾 TRACE: $*"
        else
            local line
            while IFS= read -r line; do
                echo "🐾 TRACE: $line"
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

# on_debug and on_exit are trying to cooperatively do error handling when exit is invoked. To be effective, after
# sourcing this script, set these signal traps:
#   trap on_debug DEBUG
#   trap on_exit EXIT
function on_debug()
{
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
function on_exit()
{
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

function show_stack()
{
    [[ "$verbose" != true ]] && return 0

    local i
    for ((i=0; i<${#FUNCNAME[@]}; i++)); do
        echo "$i: ${FUNCNAME[i]} at ${BASH_SOURCE[i]}:${BASH_LINENO[i]}"
    done
}
