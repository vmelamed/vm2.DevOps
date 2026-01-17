#!/bin/bash

# This script defines a number of GitHub specific constants, variables, and helper functions.

common_scripts_dir="$(dirname "${BASH_SOURCE[0]}")"

source "$common_scripts_dir/_common.sh"
source "$common_scripts_dir/_common.sanitize.sh"

# In CI mode '$github_output' is equal to the $GITHUB_OUTPUT file where GitHub Actions are allowed to pass key=value pairs from
# one job to another within the same workflow. If GITHUB_OUTPUT is not defined (e.g. running locally), it defaults to
# '/dev/stdout' as a means of diagnostic output.
declare -x github_output=${GITHUB_OUTPUT:-/dev/stdout}

# In CI mode '$github_step_summary' is equal to the $GITHUB_STEP_SUMMARY file which is used to add custom Markdown content to
# the workflow run summary. $github_step_summary is always parameter to `tee`, therefore if GITHUB_STEP_SUMMARY is not defined,
# github_step_summary defaults to '/dev/null' - the output to '/dev/stdout' will not be doubled.
declare -x github_step_summary=${GITHUB_STEP_SUMMARY:-/dev/null}

# redefined functions in GitHub actions context:
unset -f error
unset -f warning
unset -f info
# Question: should we trace to $github_step_summary as well or just keep it in the log?
# unset -f trace
unset -f warning_var

## Shell function to log error messages to the standard output and to the GitHub step summary (github_step_summary).
## Increments the error counter.
## Usage: error <message1> [<message2> ...]
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function error()
{
    echo "❌  ERROR $*" | tee -a "$github_step_summary" 1>&2
    errors=$((errors + 1))
    return 0
}

## Shell function to log warning messages to the standard output and to the GitHub step summary (github_step_summary).
## Usage: warning <message1> [<message2> ...]
function warning()
{
    echo "⚠️  WARNING $*" | tee -a "$github_step_summary" 1>&2
    return 0
}

## Shell function to log informational messages to the standard output and to the GitHub step summary (github_step_summary).
## Usage: info <message1> [<message2> ...]
function info()
{
    echo "ℹ️  INFO $*" | tee -a "$github_step_summary"
    return 0
}

# Question: should we trace to $github_step_summary as well or just keep it in the log?
## Logs a trace message if verbose mode is enabled.
## Usage: trace <message>
# function trace() {
#     # shellcheck disable=SC2154 # variable is referenced but not assigned.
#     if [[ "$verbose" == true ]]; then
#         echo "🐾 TRACE: $*" | tee -a "$github_step_summary"
#     fi
#     return 0
# }

## Shell function to log a summary message to the GitHub step summary (github_step_summary).
## Usage: summary <message1> [<message2> ...]
function summary()
{
    echo "## Summary: $*" | tee -a "$github_step_summary"
}

## Shell function to log a warning about a variable's value and set it to a default value to the standard output and to the
## GitHub step summary (github_step_summary).
## Usage: warning_var <variable_name> <warning message> <variable's default value>
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function warning_var()
{
    warning "$2" "Assuming the default value of '$3'."
    local -n var="$1";
    var="$3"
    return 0
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
    [[ $# -ge 2 || $# -le 1 ]] && error "to_github_output() requires one or two arguments: the name of the variable to output and possibly the name to use in GitHub Actions output."
    declare -n var="$1"

    local m
    [[ $# -eq 2 ]] && m="$2" || m="${1//_/-}"

    echo "$m=$var" | tee -a "${github_output}"
}

function args_to_github_output()
{
    if [[ $# -le 1 ]]; then
        error "args_to_github_output() requires one or more argument: the names of the variables to output."
        return 2
    fi

    {
        for v in "$@"; do
            declare -n var=$v
            local m="${v//_/-}"
            echo "$m=$var"
        done
    } | tee -a "$github_output"
}

## Validates if the first argument is a name of a valid JSON array of project paths, if it is null, empty or empty array, it use
## the second parameter as default value, usually `[""]`.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function validate_projects() {
    local -n projects=$1
    local default_projects=${2:-'[""]'}

    # test if present and valid JSON
    if [[ -n "$projects" ]] && ! jq -e  > "$_ignore" 2>&1 <<<"$projects"; then
        error "The value of the input '$1'='$projects' is not a valid JSON."
    # otherwise test if empty, null, empty string or empty array
    elif [[ -z "$projects" ]] || jq -e '. == null or . == "" or . == []' > "$_ignore" 2>&1 <<<"$projects"; then
        warning_var \
            "projects" \
            "The value of the input '$1' is empty: will build and pack the entire solution." \
            "$default_projects"
    # otherwise test if it is a JSON array of strings
    elif ! jq -e 'type == "array" and all(type == "string")' > /dev/null 2>&1 <<<"$projects"; then
        error "The value of the input '$1'='$projects' must be a string representing a JSON array of (possibly empty) strings - paths to the project(s) to be packed."
    # otherwise test if any of the strings in the array is empty
    elif jq -e 'any(. == "")' > /dev/null 2>&1 <<<"$projects"; then
        warning_var \
            "projects" \
            "At least one of the strings in the value of the input '$1' is empty: will build and pack the entire solution." \
            "$default_projects"
    fi
}
