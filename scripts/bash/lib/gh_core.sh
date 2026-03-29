# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# This script defines several GitHub specific constants, variables, and helper
# functions typical for the GitHub Actions environment. For the functions to be
# invocable by other scripts, this script needs to be sourced.

# Circular include guard
(( ${__VM2_LIB_GH_CORE_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_GH_CORE_SH_LOADED=1

# The name of the top-level calling script name without the path
declare -x script_name
# The directory of the top-level calling script
declare -x script_dir
# The directory of my core library for shell scripts - usually
# "$VM2_REPOS/vm2.DevOps/scripts/bash/lib"
declare -x lib_dir

[[ ! -v script_name || -z "$script_name" ]] && script_name=$(basename "${BASH_SOURCE[-1]}")
[[ ! -v script_dir || -z "$script_dir" ]] && script_dir=$(realpath -e "$(dirname "${BASH_SOURCE[-1]}")")
[[ ! -v lib_dir || -z "$lib_dir" ]] && lib_dir=$(realpath -e "$(dirname "${BASH_SOURCE[0]}")")

source "${lib_dir}/core.sh"
source "${lib_dir}/_sanitize.sh"
source "${lib_dir}/_dotnet.sh"

## In CI mode, indicates whether the script is running within GitHub Actions.
declare -x github_actions=${GITHUB_ACTIONS:-false}

# In CI mode '$github_output' is equal to the $GITHUB_OUTPUT file where GitHub
# Actions are allowed to pass key=value pairs from one job to another within the
# same workflow. If GITHUB_OUTPUT is not defined (e.g. running locally), it
# defaults to $_ignore (usually '/dev/null') to not duplicate the output to
# stdout.
declare -x github_output=${GITHUB_OUTPUT:-"/dev/null"}

# In CI mode '$github_step_summary' is equal to the $GITHUB_STEP_SUMMARY file
# which is used to add custom Markdown content to the workflow run summary.
# Defaults to $_ignore (usually '/dev/null') - so that the output to $_ignore to
# not duplicate the output to stdout.
declare -x github_step_summary=${GITHUB_STEP_SUMMARY:-"/dev/null"}

# Whether to trace messages to /dev/stdout only or to GitHub Actions step
# summary (GITHUB_STEP_SUMMARY) as well.
declare -x trace_to_summary=${TRACE_TO_SUMMARY:-false}

# redefined functions in GitHub actions context:
unset -f to_stdout
unset -f to_stderr

#-------------------------------------------------------------------------------
# Summary: Sends the input to stdout AND, if in GitHub Actions, to GitHub step summary.
# Parameters: none (reads from stdin)
# Returns:
#   stdout: each line read from stdin
#   Exit code: 0
# Side Effects: Appends also to $github_step_summary file when $github_actions is
#   true
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
        $github_actions && echo "$line" >> "$github_step_summary"
    done
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Sends the input to stderr AND, if in GitHub Actions, to GitHub step summary.
# Parameters: none (reads from stdin)
# Returns:
#   stderr: each line read from stdin
#   Exit code: 0
# Side Effects: Appends also to $github_step_summary file when both $github_actions
#   and $trace_to_summary are true
# Env. Vars:
#   github_actions - when true, indicates running in GitHub Actions environment
#   trace_to_summary - when true, also writes to step summary
#   github_step_summary - path to GitHub Actions step summary file
# Usage: echo "message" | to_traceout
# Example: echo "Debug info: $variable" | to_traceout
#-------------------------------------------------------------------------------
function to_traceout()
{
    local line
    while IFS= read -r line; do
        echo "$line" >&2
        $github_actions && $trace_to_summary && echo "$line" >> "$github_step_summary"
    done
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Sends the input to stderr AND, if in GitHub Actions, to GitHub step summary.
# Parameters: none (reads from stdin)
# Returns:
#   stderr: each line read from stdin
#   Exit code: 0
# Side Effects: Appends also to $github_step_summary file when $github_actions is
#   true
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
        $github_actions && echo "$line" >> "$github_step_summary"
    done
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Logs a summary message(s) with markdown heading to stdout AND, if in
#   GitHub Actions, to GitHub step summary.
# Parameters:
#   1+ - message - summary message parts (optional, if not provided reads from
#       stdin)
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
    local line
    local first=true

    function __print_line()
    {
        $first && echo "## Summary" && first=false
        echo "$line"
    }

    {
        if [[ $# -gt 0 ]]; then
            for line in "$@"; do
                __print_line
            done
        else
            while IFS= read -r line; do
                __print_line
            done
        fi
    } | to_stdout

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Sends input to stdout AND, if in GitHub Actions, also appends to the
#   GitHub output file.
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
        $github_actions && echo "$line" >> "$github_output"
    done
}

#-------------------------------------------------------------------------------
# Summary: Outputs a key and value of a variable to GitHub Actions GITHUB_OUTPUT file.
# Parameters:
#   1 - variable_name (nameref!) - the name of the variable that contains the GITHUB_OUTPUT value
#   2 - output_key - the GITHUB_OUTPUT key
#       Optional, defaults to the name of the variable in $1, but underscores are replaced by hyphens)
# Returns:
#   Outputs to $github_output via to_output
#   Exit code: 0 on success, 2 on invalid arguments
# Usage: to_github_output <variable_name> [<output-key>]
# Example:
#   build_version="1.2.3"
#   to_github_output build_version             # outputs: build-version=1.2.3
#   to_github_output build_version custom-key  # outputs: custom-key=1.2.3
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function to_github_output()
{
    (( $# == 1 || $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires one or two arguments (provided $#): " \
              "the name of the variable to output and optionally the name to use in GitHub Actions output."
        return "$err_invalid_arguments"
    }

    local k
    # get the key from the second argument if provided,
    # otherwise transform the var name to a key by replacing underscores with hyphens
    (( $# == 2 )) && k="$2" || k="${1//_/-}"

    local -n v=$1
    echo "$k=$v" | to_output
}

#-------------------------------------------------------------------------------
# Summary: Outputs a key=value pair for each of the input variable names.
#   The key is synthesized from the name by replacing the underscores with
#   hyphens. The value is the value of the variable with that name.
# Parameters:
#   1+ - variable_names - name refs of variables to output
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
    (( $# > 0 )) || {
        error 3 "${FUNCNAME[0]}() requires one or more arguments (provided $#): the names of the variables to output."
        return "$err_invalid_arguments"
    }

    {
        local var
        local k
        for var in "$@"; do
            # transform the var name to a key by replacing underscores with hyphens
            k="${var//_/-}"
            echo "$k=${!var}"
        done
    } | to_output
}
