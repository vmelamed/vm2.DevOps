# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC1091 # Disable warnings for word splitting and globbing issues in the following source commands.

#=============================================================================================
# This script defines several GitHub specific constants, variables, and helper functions
# typical for the GitHub Actions environment. The script sources core.sh from the same
# directory. For the functions to be invocable by other scripts, this script must be sourced.
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_GH_CORE_SH_LOADED:-0} == 1 )) && return 0
declare -xri __VM2_LIB_GH_CORE_SH_LOADED=1

declare -x script_name
declare -x script_dir
declare -x lib_dir

[[ ! -v script_name || -z "$script_name" ]] && script_name=$(basename "${BASH_SOURCE[-1]}")
[[ ! -v script_dir  || -z "$script_dir"  ]] && script_dir=$(realpath -e "$(dirname "${BASH_SOURCE[-1]}")")
[[ ! -v lib_dir     || -z "$lib_dir"     ]] && lib_dir=$(realpath -e "$(dirname "${BASH_SOURCE[0]}")")

source "$lib_dir/core.sh"

declare -xri success
declare -xri failure
declare -xri err_invalid_arguments
declare -xri err_invalid_nameref

declare -xr ci
declare -x _ignore

declare -xr GITHUB_ACTIONS=${GITHUB_ACTIONS:-false}
declare -xr GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-"$_ignore"}
declare -xr GITHUB_OUTPUT=${GITHUB_OUTPUT:-"$_ignore"}

#---------------------------------------------------------------------------------------------
# @description Reads lines from stdin, sending each to stdout (which may be the GitHub Actions
#   log file) and also appending it to the GitHub Actions step summary file in CI (which may
#   be /dev/null outside GitHub Actions).
#
# Notes:
#   - Overrides the base implementation from `_diagnostics.sh`
#   - The output is sent to stdout (or the GitHub Actions logs)
#   - In GitHub Actions, the output is appended also to the step summary file.
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @stdout and \$GITHUB_STEP_SUMMARY string each line read from stdin unchanged.
#
# @example
#   echo "Build completed successfully" | to_stdout
#---------------------------------------------------------------------------------------------
function to_stdout()
{
    local _line
    while IFS= read -r _line; do
        echo "$_line"
        if $GITHUB_ACTIONS; then
            echo "$_line" >> "$GITHUB_STEP_SUMMARY"
        fi
    done
}

#---------------------------------------------------------------------------------------------
# @description Reads lines from stdin, sending each to stderr (which may be the GitHub Actions
#   log file) and also appending it to the GitHub Actions step summary file in CI (which may
#   be /dev/null outside GitHub Actions).
#
# Notes:
#   - Overrides the base implementation from `_diagnostics.sh`
#   - The output is sent to stderr (or the GitHub Actions logs)
#   - In GitHub Actions, the output is appended also to the step summary file.
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @stderr string each line read from stdin unchanged.
#
# @example
#   echo "Warning: file not found" | to_stderr
#---------------------------------------------------------------------------------------------
function to_stderr()
{
    local _line
    while IFS= read -r _line; do
        echo "$_line" >&2
        if $GITHUB_ACTIONS; then
            echo "$_line" >> "$GITHUB_STEP_SUMMARY"
        fi
    done
}

#---------------------------------------------------------------------------------------------
# @description Reads lines from stdin, sending each to stdout (which may be the GitHub Actions
#   log file) and also appending it to the GitHub Actions output file in CI (which may be
#   /dev/null outside GitHub Actions).
#
# Notes:
#   - Overrides the base implementation from `_diagnostics.sh`
#   - The output is sent to stdout (or the GitHub Actions logs)
#   - In GitHub Actions, the output is appended also to the GitHub Actions output
#
# @arg $@ nil No arguments; reads its input from stdin.
#
# @stdout string each line read from stdin unchanged.
#
# @example
#   echo "version=1.2.3" | to_output
#---------------------------------------------------------------------------------------------
function to_output()
{
    local _line
    while IFS= read -r _line; do
        echo "$_line"
        if $GITHUB_ACTIONS; then
            echo "$_line" >> "$GITHUB_OUTPUT"
        fi
    done
}

#---------------------------------------------------------------------------------------------
# @description Determines the appropriate command to use for summary output based on the
#   environment: outside CI, when `glow` is present, it uses `glow` for pretty printing of
#   markdown. Otherwise (in CI, or when `glow` is absent), it uses `to_stdout`. Changes the
#   behavior of `to_summary` without overriding it.
#
# Notes: consider this variable an implementation detail and never use directly. Instead
#   redirect output to `to_summary` function
#---------------------------------------------------------------------------------------------
declare -xr glow_present
declare -a __summary_output

if ! $ci && $glow_present 2>&1; then
    # redirect summary markdown to glow for pretty printing on the console
    # there is no $GITHUB_STEP_SUMMARY in local runs
    __summary_output=(glow -w 168)
else
    # redirect summary markdown to `to_stdout` (the GitHub Actions logs or the terminal output
    # if not redirected externally) AND to the GitHub Actions step summary if present or
    # /dev/null
    __summary_output=(to_stdout)
fi

#---------------------------------------------------------------------------------------------
# @description Outputs a "key=value" pair for each of the passed-in variable names to
#   $GITHUB_OUTPUT function.
#
# @arg $@ nameref List of names of the variables (namerefs) to output.
#
# @stdout and $GITHUB_OUTPUT (if in GH actions) "key=value" for each variable, via
#   `to_output`.
#
# @example
#   build_version="1.2.3"
#   package_count=5
#   args_to_github_output build_version package_count
#   # outputs:
#   # build-version=1.2.3
#   # package-count=5
#---------------------------------------------------------------------------------------------
function args_to_github_output()
{
    (( $# > 0 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one or more arguments (provided $#) - the names of the variables to output."

    # validate the variable names before doing any output
    local _var
    local -i _argument_number=1
    for _var in "$@"; do
        is_variable_name "$_var" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument $_argument_number to be a valid variable name (provided '${_var-<none>}')."
        (( _argument_number++ ))
    done

    exit_if_has_bugs

    local _k _v
    for _var in "$@"; do
        _k=$_var
        _v="${!_var}"
        # transform the var name to a key by
        #   - removing the leading underscore
        #   - replacing the other underscores
        #   - transform to lowercase
        _k="${_k##_}"
        _k="${_k//_/-}"
        _k="${_k,,}"

        # output the key-value pair
        echo "$_k=$_v"
    done | to_output
}
