# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# core constants
declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_argument_value
declare -xri err_not_found
declare -xri err_tool_not_found
declare -xri err_logic_error

declare -xr ci
declare -x _ignore

# default constants for parameters
declare -xr default_interval=15
declare -xr default_timeout=900

# script arguments -- the numbers stay strings until validated: assigning e.g. 'abc' to a 'declare -i' variable would
# evaluate it as an arithmetic expression
declare -x pr_number=''
declare -x repo=''
declare -x watch=false
declare -x interval=$default_interval
declare -x timeout=$default_timeout

#---------------------------------------------------------------------------------------------
# @description Parses the command-line arguments for 'show-pr-comments.sh'. Delegates common switches (help, quiet, verbose,
# trace, dry-run) to 'get_common_arg'. Accepts at most one positional argument: the pull request number.
#
# @arg $@ string The command-line arguments.
#
# Note: 'usage_if_requested' exits the process directly (via 'usage') when '--help'/'-h'/'-?' was given.
#---------------------------------------------------------------------------------------------
function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            -r|--repo )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                repo="$1"; shift
                ;;

            -w|--watch )
                watch=true
                ;;

            -i|--interval )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                interval="$1"; shift
                ;;

            -t|--timeout )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                timeout="$1"; shift
                ;;

            # reserved: get_common_arg consumes these options before this case. Effectively this arm never runs BUT it lets
            # ShellCheck flag (SC2221/SC2222) any script-specific arm that tries to reuse one of them, and it bugs out if
            # the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -* ) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            * ) [[ -z $pr_number ]] || usage -ec "$err_too_many_arguments" "Too many positional arguments: $_option"
                pr_number="$_option"
                ;;
        esac
    done

    usage_if_requested
    validate_arguments
    dump_args
}

#---------------------------------------------------------------------------------------------
# @description Validates the arguments, resolves the repository and the pull request number when they were omitted, and
# freezes them. The resolution queries GitHub through 'gh' (read-only, so not through 'execute').
#
# @exitcode success=0: The arguments are valid and resolved (otherwise the script exits through 'exit_if_has_errors').
#---------------------------------------------------------------------------------------------
function validate_arguments()
{
    is_tool_present gh ||
        error -ec "$err_tool_not_found" "The GitHub CLI 'gh' is required: https://cli.github.com"
    [[ -z $pr_number || $pr_number =~ ^[1-9][0-9]*$ ]] ||
        error -ec "$err_argument_value" "The pull request number must be a positive integer (provided '$pr_number')."
    [[ -z $repo || $repo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] ||
        error -ec "$err_argument_value" "The repository must be given as 'owner/repo' (provided '$repo')."
    [[ -z $repo || -n $pr_number ]] ||
        error -ec "$err_missing_argument" "With '--repo', the pull request number is required: the current branch belongs to the current directory's repository."
    [[ $interval =~ ^[1-9][0-9]*$ ]] ||
        error -ec "$err_argument_value" "The interval must be a positive number of seconds (provided '$interval')."
    [[ $timeout =~ ^[1-9][0-9]*$ ]] ||
        error -ec "$err_argument_value" "The timeout must be a positive number of seconds (provided '$timeout')."
    exit_if_has_errors

    # resolve what was omitted: the current directory's repository, the current branch's pull request
    [[ -n $repo ]] || repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>"$_ignore") ||
        error -ec "$err_not_found" "The current directory is not in a GitHub repository; use '--repo <owner/repo>'."
    [[ -n $pr_number || -z $repo ]] || pr_number=$(gh pr view --json number --jq .number 2>"$_ignore") ||
        error -ec "$err_not_found" "The current branch has no pull request; give the pull request number."
    exit_if_has_errors false

    readonly pr_number
    readonly repo
    readonly watch
    readonly interval
    readonly timeout

    return "$success"
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        pr_number
        repo
        watch
        interval
        timeout

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
