# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC1091 # Disable warnings for word splitting and globbing issues in the following source commands.

#-------------------------------------------------------------------------------
# This script defines several GitHub specific constants, variables, and helper
# functions typical for the GitHub Actions environment. The script sources
# core.sh and _dotnet.sh from the same directory. For the functions to be
# invocable by other scripts, this script must be sourced.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_GH_CORE_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_GH_CORE_SH_LOADED=1

# The name of the top-level calling script name without the path
declare -x script_name
# The directory of the top-level calling script
declare -x script_dir
# The directory of my core library for shell scripts - usually
# "$VM2_REPOS/$vm2_devops_repo_name/scripts/bash/lib"
declare -x lib_dir

[[ ! -v script_name || -z "$script_name" ]] && script_name=$(basename "${BASH_SOURCE[-1]}")
[[ ! -v script_dir  || -z "$script_dir"  ]] && script_dir=$(realpath -e "$(dirname "${BASH_SOURCE[-1]}")")
[[ ! -v lib_dir     || -z "$lib_dir"     ]] && lib_dir=$(realpath -e "$(dirname "${BASH_SOURCE[0]}")")

source "$lib_dir/core.sh"

declare -rxi success
declare -rxi failure

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

declare -rxi err_invalid_nameref

declare -rx varNameRegex

#-------------------------------------------------------------------------------
# @description Reads lines from /dev/stdin, echoing each to stdout and also appending it to the GitHub
# Actions step summary file or to /dev/null.
#
# Notes:
#   - Overrides the base implementation from `_diagnostics.sh`.
#   - Outside GitHub Actions, `$github_step_summary` defaults to `/dev/null`, so the append is a
#     no-op there. The function does not itself branch on `$github_actions`.
#
# @exitcode 0 Always.
#
# @stdout Each line read from stdin.
#
# @example
#   echo "Build completed successfully" | to_stdout
#-------------------------------------------------------------------------------
function to_stdout()
{
    local _line
    while IFS= read -r _line; do
        echo "$_line"
        echo "$_line" >> "$github_step_summary"
    done
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Reads lines from stdin, sending each to /dev/stderr, and
# additionally appending it to the GitHub Actions step summary file or to /dev/null, when `$trace_to_summary` is true.
#
# @exitcode 0 Always.
#
# @example
#   echo "Debug info: $variable" | to_traceout
#-------------------------------------------------------------------------------
function to_traceout()
{
    local _line
    while IFS= read -r _line; do
        echo "$_line" >&2
        $trace_to_summary && echo "$_line" >> "$github_step_summary" || true
    done
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Reads lines from stdin, sending each to stderr and also appending it to the GitHub
# Actions step summary file or to /dev/null.
#
# Notes:
#   - Outside GitHub Actions, `$github_step_summary` defaults to `/dev/null`, so the append is a
#     no-op there. The function does not itself branch on `$github_actions`.
#
# @exitcode 0 Always.
#
# @example
#   echo "Warning: deprecated feature" | to_stderr
#-------------------------------------------------------------------------------
function to_stderr()
{
    local _line
    while IFS= read -r _line; do
        echo "$_line" >&2
        echo "$_line" >> "$github_step_summary"
    done
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Logs one or more summary messages with a `## Summary` markdown heading, via
# `to_stdout` — so, in GitHub Actions, the heading and messages also land in the step summary.
#
# @arg $@ string Summary message parts, one per line (optional; if omitted, reads lines from
#   stdin instead).
#
# @exitcode 0 Always.
#
# @stdout `## Summary` heading followed by each message line.
#
# @example
#   to_summary "Build completed successfully"
# @example
#   echo "Deployment finished" | to_summary
#-------------------------------------------------------------------------------
# shellcheck disable=SC2120 # to_summary references arguments, but none are ever passed.
# It's OK: the f-n can either read from stdin (preferred!) or use its parameters (should be avoided).
function to_summary()
{
    local _line
    local _first=true

    function __print_line()
    {
        $_first && echo "## Summary" && _first=false
        echo "$_line"
    }

    {
        if [[ $# -gt 0 ]]; then
            for _line in "$@"; do
                __print_line
            done
        else
            while IFS= read -r _line; do
                __print_line
            done
        fi
    } | to_stdout

    return "$success"
}

#-------------------------------------------------------------------------------
# @description Reads lines from stdin, echoing each to /dev/stdout and also appending it to the
# GitHub Actions output file or /dev/null.
#
# Notes:
#   - Outside GitHub Actions, `$github_output` defaults to `/dev/null`, so the append is a no-op
#     there. The function does not itself branch on `$github_actions`.
#
# @exitcode 0 Effectively always (no explicit `return`; the loop's last command is `echo`, which
#   succeeds).
#
# @stdout Each line read from stdin.
#
# @example
#   echo "version=1.2.3" | to_output
#-------------------------------------------------------------------------------
function to_output()
{
    local _line
    while IFS= read -r _line; do
        echo "$_line"
        echo "$_line" >> "$github_output"
    done
}

#-------------------------------------------------------------------------------
# @description Outputs a "key=value" pair for a variable to the GitHub Actions output file
# (`$github_output`), via `to_output`.
#
# @arg $1 nameref Name of the variable whose value is to be output.
# @arg $2 string GitHub Actions output key (optional; defaults to the name in $1 with underscores
#   replaced by hyphens).
#
# @exitcode 0 Success.
# @exitcode 2 Invalid arguments (wrong argument count, or $1 is not a valid variable name).
#
# @stdout "key=value", via `to_output` (also appended to `$github_output`).
#
# @example
#   build_version="1.2.3"
#   to_github_output build_version             # outputs: build-version=1.2.3
# @example
#   to_github_output build_version custom-key  # outputs: custom-key=1.2.3
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function to_github_output()
{
    local -i _rc="$success"

    (( $# == 1 || $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires one or two arguments (provided $#): " \
              "the name of the variable to output and optionally the name to use in GitHub Actions output."
    }
    [[ -v 1 && $1 =~ $varNameRegex ]] || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be a valid variable name (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _k
    # get the key from the second argument if provided,
    # otherwise transform the var name to a key by replacing underscores with hyphens
    (( $# == 2 )) && _k="$2" || _k="${1//_/-}"

    local -n _v=$1
    echo "$_k=$_v" | to_output
}

#-------------------------------------------------------------------------------
# @description Outputs a "key=value" pair for each of the given variable names, via `to_output`.
# Each key is synthesized from the variable name by replacing underscores with hyphens; the value
# is read from the variable via indirect expansion (`${!var}`).
#
# @arg $@ nameref Names of the variables to output.
#
# @exitcode 0 Success.
# @exitcode 2 Invalid arguments (no variable names given).
#
# @stdout "key=value" for each variable, via `to_output` (also appended to `$github_output`).
#
# @example
#   build_version="1.2.3"
#   package_count=5
#   args_to_github_output build_version package_count
#   # outputs:
#   # build-version=1.2.3
#   # package-count=5
#-------------------------------------------------------------------------------
function args_to_github_output()
{
    local -i _rc="$success"

    (( $# > 0 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires one or more arguments (provided $#): the names of the variables to output."
    }

    local _var
    local -i _argument_number=1
    for _var in "$@"; do
        [[ $_var =~ $varNameRegex ]] || {
            _rc="$err_invalid_nameref"
            error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument $_argument_number to be a valid variable name (provided '${_var-<missing>}')."
        }
        (( _argument_number++ ))
    done

    (( _rc == success )) || return "$err_invalid_arguments"

    {
        local _k
        for _var in "$@"; do
            # transform the var name to a key by replacing underscores with hyphens
            _k="${_var//_/-}"
            echo "$_k=${!_var}"
        done
    } | to_output
}
