# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# This script defines several GitHub specific constants, variables, and helper functions typical for the GitHub Actions environment.
# For the functions to be invocable by other scripts, this script needs to be sourced.

# The name of the top-level calling script name without the path
declare -x script_name
# The directory of the top-level calling script
declare -x script_dir
# The directory of my core library for shell scripts - usually "$GIT_REPOS/vm2.DevOps/scripts/bash/lib"
declare -x lib_dir

[[ ! -v script_name || -z "$script_name" ]] && script_name="$(basename "${BASH_SOURCE[-1]}")"
[[ ! -v script_dir || -z "$script_dir" ]] && script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[-1]}")")"
[[ ! -v lib_dir || -z "$lib_dir" ]] && lib_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"

source "$lib_dir/core.sh"
source "$lib_dir/_sanitize.sh"
source "$lib_dir/_dotnet.sh"

## In CI mode, indicates whether the script is running within GitHub Actions.
declare -x github_actions=${GITHUB_ACTIONS:-false}

# In CI mode '$github_output' is equal to the $GITHUB_OUTPUT file where GitHub Actions are allowed to pass key=value pairs from
# one job to another within the same workflow. If GITHUB_OUTPUT is not defined (e.g. running locally), it defaults to
# $_ignore (usually '/dev/null') to not duplicate the output to stdout.
declare -x github_output=${GITHUB_OUTPUT:-"$_ignore"}

# In CI mode '$github_step_summary' is equal to the $GITHUB_STEP_SUMMARY file which is used to add custom Markdown content to
# the workflow run summary. defaults to $_ignore (usually '/dev/null') - so that the output to $_ignore to not duplicate the output to stdout.
declare -x github_step_summary=${GITHUB_STEP_SUMMARY:-"$_ignore"}

# Whether to trace messages to /dev/stdout only or to GitHub Actions step summary (GITHUB_STEP_SUMMARY) as well.
declare -x trace_to_summary=${TRACE_TO_SUMMARY:-false}

# redefined functions in GitHub actions context:
unset -f to_stdout
unset -f to_stderr

#-------------------------------------------------------------------------------
# Summary: Sends input to stdout and, if in GitHub Actions, also appends to the GitHub step summary.
# Parameters: none (reads from stdin)
# Returns:
#   stdout: each line read from stdin
#   Exit code: 0 always
# Side Effects: Appends to $github_step_summary file when $github_actions is true
# Env. Vars:
#   github_actions - when true, indicates running in GitHub Actions environment
#   github_step_summary - path to GitHub Actions step summary file
# Usage: echo "message" | to_stdout
# Example: echo "Build completed successfully" | to_stdout
# Notes: Overrides the base implementation from _diagnostics.sh.
#-------------------------------------------------------------------------------
function to_stdout()
{
    local line
    while IFS= read -r line; do
        echo "$line"
        if [[ $github_actions == true ]]; then
            echo "$line" >> "$github_step_summary"
        fi
    done
}

#-------------------------------------------------------------------------------
# Summary: Sends trace output to stdout and optionally to GitHub step summary.
# Parameters: none (reads from stdin)
# Returns:
#   stdout: each line read from stdin
#   Exit code: 0 always
# Side Effects: Appends to $github_step_summary file when both $github_actions and $trace_to_summary are true
# Env. Vars:
#   github_actions - when true, indicates running in GitHub Actions environment
#   trace_to_summary - when true, also writes to step summary
#   github_step_summary - path to GitHub Actions step summary file
# Usage: echo "message" | to_trace_out
# Example: echo "Debug info: $variable" | to_trace_out
#-------------------------------------------------------------------------------
function to_trace_out()
{
    local line
    while IFS= read -r line; do
        echo "$line"
        if [[ $github_actions == true && $trace_to_summary == true ]]; then
            echo "$line" >> "$github_step_summary"
        fi
    done
}

#-------------------------------------------------------------------------------
# Summary: Sends input to stderr and, if in GitHub Actions, also appends to the GitHub step summary.
# Parameters: none (reads from stdin)
# Returns:
#   stderr: each line read from stdin
#   Exit code: 0 always
# Side Effects: Appends to $github_step_summary file when $github_actions is true
# Env. Vars:
#   github_actions - when true, indicates running in GitHub Actions environment
#   github_step_summary - path to GitHub Actions step summary file
# Usage: echo "error message" | to_stderr
# Example: echo "Warning: deprecated feature" | to_stderr
#-------------------------------------------------------------------------------
function to_stderr()
{
    local line
    while IFS= read -r line; do
        echo "$line" >&2
        if [[ $github_actions == true ]]; then
            echo "$line" >> "$github_step_summary"
        fi
    done
}

#-------------------------------------------------------------------------------
# Summary: Logs a summary message with markdown heading to stdout and GitHub step summary.
# Parameters:
#   1+ - message - summary message parts (optional, if not provided reads from stdin)
# Returns:
#   stdout: formatted summary with ## heading prefix via to_stdout
#   Exit code: 0 always
# Usage: to_summary <message1> [message2...]
# Example:
#   to_summary "Build completed successfully"
#   echo "Deployment finished" | to_summary
#-------------------------------------------------------------------------------
function to_summary()
{
    if [[ $# -gt 0 ]]; then
        echo "## Summary: $*" | to_stdout
    else
        {
            local line
            local first=true
            while IFS= read -r line; do
                if [[ $first == true ]]; then
                    echo "## Summary: $line"
                    first=false
                else
                    echo "$line"
                fi
            done
        } | to_stdout
    fi
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Sends input to stdout and, if in GitHub Actions, also appends to the GitHub output file.
# Parameters: none (reads from stdin)
# Returns:
#   stdout: each line read from stdin
#   Exit code: 0 always
# Side Effects: Appends to $github_output file when $github_actions is true
# Env. Vars:
#   github_actions - when true, indicates running in GitHub Actions environment
#   github_output - path to GitHub Actions output file
# Usage: echo "key=value" | to_output
# Example: echo "version=1.2.3" | to_output
#-------------------------------------------------------------------------------
function to_output()
{
    local line
    while IFS= read -r line; do
        echo "$line"
        if [[ $github_actions == true ]]; then
            echo "$line" >> "$github_output"
        fi
    done
}

#-------------------------------------------------------------------------------
# Summary: Outputs a variable to GitHub Actions output, converting underscores to hyphens in the key name.
# Parameters:
#   1 - variable_name - name of the variable to output (nameref)
#   2 - output_name - custom name for output key (optional, defaults to variable_name with _ → -)
# Returns:
#   Outputs to $github_output via to_output
#   Exit code: 0 on success, 2 on invalid arguments
# Usage: to_github_output <variable_name> [output_name]
# Example:
#   build_version="1.2.3"
#   to_github_output build_version  # outputs: build-version=1.2.3
#   to_github_output build_version custom-key  # outputs: custom-key=1.2.3
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function to_github_output()
{
    if [[ $# -eq 0 || $# -ge 3 ]]; then
        error "${FUNCNAME[0]}() requires one or two arguments: the name of the variable to output and optionally the name to use in GitHub Actions output."
        return 2
    fi
    declare -n var="$1"

    local m
    [[ $# -eq 2 ]] && m="$2" || m="${1//_/-}"

    echo "$m=$var" | to_output
}

#-------------------------------------------------------------------------------
# Summary: Outputs multiple variables to GitHub Actions output, converting underscores to hyphens in key names.
# Parameters:
#   1+ - variable_names - names of variables to output
# Returns:
#   Outputs to $github_output via to_output
#   Exit code: 0 on success, 2 on invalid arguments
# Usage: args_to_github_output <variable_name1> [variable_name2...]
# Example:
#   build_version="1.2.3"
#   package_count=5
#   args_to_github_output build_version package_count
#   # outputs:
#   # build-version=1.2.3
#   # package-count=5
#-------------------------------------------------------------------------------
function args_to_github_output()
{
    if [[ $# -eq 0 ]]; then
        error "${FUNCNAME[0]}() requires one or more arguments: the names of the variables to output."
        return 2
    fi

    {
        for v in "$@"; do
            declare -n var=$v
            local m="${v//_/-}"
            echo "$m=$var"
        done
    } | to_output
}
