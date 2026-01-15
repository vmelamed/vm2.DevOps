#!/bin/bash

declare -r this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -r script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -r script_dir

source "$script_dir/_common.sh"
source "$script_dir/_common_sanitize.sh"

# This script defines a number of DevOps specific constants, variables, and helper functions.

declare -r default_ci=false

# CI mode flag - true if running in GitHub Actions (or other CI environment), false otherwise
declare -rx ci=${CI:-$default_ci}

# In CI mode '$github_output' is equal to the $GITHUB_OUTPUT file where GitHub Actions are allowed to pass key=value pairs from
# one job to another within the same workflow. If GITHUB_OUTPUT is not defined (e.g. running locally), it defaults to
# '/dev/stdout' as a means of diagnostic output.
declare -x github_output=${GITHUB_OUTPUT:-/dev/stdout}

# In CI mode '$github_step_summary' is equal to the $GITHUB_STEP_SUMMARY file which is used to add custom Markdown content to
# the workflow run summary. $github_step_summary is always parameter to `tee`, therefore if GITHUB_STEP_SUMMARY is not defined,
# github_step_summary defaults to '/dev/null' - the output to '/dev/stdout' will not be doubled.
declare -x github_step_summary=${GITHUB_STEP_SUMMARY:-/dev/null}

# Regular expressions for git tags with semantic version (e.g. v1.2.3)
declare -x semverTagRegex
declare -x semverTagReleaseRegex
declare -x semverTagPrereleaseRegex

## Shell function to create the regular expressions above for tags comprising a given prefix with a semantic version.
## Call once when the tag prefix is known. For example: create_tag_regexes "v". It might be a good idea to declare the resulting
## variables as readonly after calling this function:
##   declare -xr semverTagRegex
##   declare -xr semverTagReleaseRegex
##   declare -xr semverTagPrereleaseRegex
function create_tag_regexes() {
    if [[ -z "$1" ]]; then
        echo "Git tag prefix (e.g. for use by MinVer) is required"
        return 1
    fi

    semverTagRegex=$(printf "^%s$semverRex$" "$1")
    semverTagReleaseRegex=$(printf "^%s$semverReleaseRex$" "$1")
    semverTagPrereleaseRegex=$(printf "^%s$semverPrereleaseRex$" "$1")
}

# redefine functions in CI:
unset -f set_debugger
unset -f set_trace_enabled
unset -f set_dry_run
unset -f error
unset -f warning
unset -f info
unset -f warning_var

## Sets the script to debugger mode
function set_debugger()
{
    if [[ $ci == true ]]; then
        # do not allow in CI mode
        debugger=false
    else
        debugger=true
        quiet=true
    fi
    return 0
}

## Enables trace mode for debugging
function set_trace_enabled()
{
    if [[ $ci == true ]]; then
        # do not allow in CI mode
        verbose=false
        _ignore=/dev/null
        set +x
    else
        verbose=true
        _ignore=/dev/stdout
        set -x
    fi
    return 0
}

## Sets the script to dry-run mode (does not execute commands, only simulates)
function set_dry_run()
{
    [[ $ci == true ]] && dry_run=false || dry_run=true
    return 0
}

## Sets the script to CI mode
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function set_ci()
{
    quiet=true
    dry_run=false
    verbose=false
    debugger=false
    _ignore=/dev/null
    set_table_format markdown
    set +x
    return 0
}

if [[ $ci == true ]]; then
    set_ci
fi

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

function summary()
{
    echo "## Summary $*" | tee -a "$github_step_summary"
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

declare -xr nugetServersRegex="^(nuget|github|https?://.+)$";

function validate_nuget_server() {
    local -n server=$1
    local default_server=${2:-"nuget"}

    if [[ -z "$server" ]]; then
        warning_var "server" "No NuGet server configured." "$default_server"
        return 0
    fi

    if [[ ! "$server" =~ $nugetServersRegex ]]; then
        error "Invalid NuGet server: $server"
    fi
}
