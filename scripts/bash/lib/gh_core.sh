# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# This script defines several GitHub specific constants, variables, and helper functions typical for GitHub Actions environment.
# For the functions to be invocable by other scripts, this script needs to be sourced.

declare -x script_name
declare -x script_dir
declare -x lib_dir

if [[ ! -v script_name || -z "$script_name" ]]; then
    script_name="$(basename "${BASH_SOURCE[-1]}")"
fi
if [[ ! -v script_dir || -z "$script_dir" ]]; then
    script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[-1]}")")"
fi
if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
fi

source "$lib_dir/core.sh"
source "$lib_dir/_sanitize.sh"

## In CI mode, indicates whether the script is running within GitHub Actions.
declare -x github_actions=${GITHUB_ACTIONS:-false}

# In CI mode '$github_output' is equal to the $GITHUB_OUTPUT file where GitHub Actions are allowed to pass key=value pairs from
# one job to another within the same workflow. If GITHUB_OUTPUT is not defined (e.g. running locally), it defaults to
# '/dev/null' to not duplicate the output to stdout.
declare -x github_output=${GITHUB_OUTPUT:-"$_ignore"}

# In CI mode '$github_step_summary' is equal to the $GITHUB_STEP_SUMMARY file which is used to add custom Markdown content to
# the workflow run summary. defaults to '/dev/null' - so that the output to '/dev/null' to not duplicate the output to stdout.
declare -x github_step_summary=${GITHUB_STEP_SUMMARY:-"$_ignore"}

# Whether to trace messages to /dev/stdout only or to GitHub Actions step summary (GITHUB_STEP_SUMMARY) as well.
declare -x trace_to_summary=${TRACE_TO_SUMMARY:-false}

# redefined functions in GitHub actions context:
unset -f to_stdout
unset -f to_stderr

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

## Shell function to log a summary message to the GitHub step summary (github_step_summary).
## Usage: summary <message1> [<message2> ...]
function summary()
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

## Shell function to output a variable to GitHub Actions output (GITHUB_OUTPUT).
## Usage: to_github_output <variable_name> [<output_name>]
## Note that if no output name is specified, then it is defined as the variable name with all underscores in the variable name
## converted to hyphens for GitHub Actions output, e.g.
## `to_github_output build_projects` will output `build-projects=<value of $build_projects>` into $github_output or
## `to_github_output build_projects test-projects` will output `test-projects=build-projects` into $github_output
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
