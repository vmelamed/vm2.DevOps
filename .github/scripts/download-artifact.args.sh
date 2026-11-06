# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# core lib exit codes
declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_argument_type
declare -xri err_not_found
declare -xri err_tool_not_found
declare -xri err_tool_unauthenticated

# core lib constants
declare -xr ci

# core lib variables
declare -x _ignore

# this scripts arguments
declare -x artifact_name=${ARTIFACT_NAME:-}
declare -x artifacts=${ARTIFACT_DIR:-}
declare -x repository=${REPOSITORY:-}
declare -x workflow_id=${WORKFLOW_ID:-}
declare -x workflow_name=${WORKFLOW_NAME:-}
declare -x workflow_path=${WORKFLOW_PATH:-}

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --artifact|-a )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                artifact_name="$1"; shift
                ;;

            --directory|-d )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                artifacts="$1"; shift
                ;;

            --repository|--repo|-r )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                repository="$1"; shift
                ;;

            --wf-id|-i )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                workflow_id="$1"; shift
                workflow_name=""
                workflow_path=""
                ;;

            --wf-name|-n )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                workflow_id=""
                workflow_name="$1"; shift
                workflow_path=""
                ;;

            --wf-path|-p )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                workflow_id=""
                workflow_name="";
                workflow_path="$1"; shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                                                                                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            * )                                                                 usage "Unknown argument '$_option'." -ec "$err_unknown_argument"
                ;;
        esac
    done

    usage_if_requested
    verify_environment
    validate_arguments
    exit_if_has_errors
    dump_args
}

function verify_environment()
{
    is_tool_present jq                                                          || error "'jq' is not installed. Please install it first." -ec "$err_tool_not_found"
    is_tool_present gh                                                          || { error "'gh' is not installed. Please install it first." -ec "$err_tool_not_found"; return "$success"; }
    gh auth status &> "$_ignore"                                                || error "'gh' is not authenticated. Run 'gh auth login' first." -ec "$err_tool_unauthenticated"

    return "$success";
}

function validate_arguments()
{
    [[ -n "$artifact_name" ]]                                                   || error "The name of the artifact to download must be specified." -ec "$err_missing_argument"
    is_safe_input "$artifact_name"                                              || true

    [[ -z "$artifacts" ]] || is_safe_valid_path "$artifacts"                    || true
    [[ -n "$artifacts" ]]                                                       || error "The directory to download the artifact to must be specified." -ec "$err_missing_argument"
    is_safe_input "$repository"                                                 || true
    is_safe_input "$workflow_id"                                                || true
    is_safe_input "$workflow_name"                                              || true
    is_safe_path "$workflow_path"                                               || true
    [[ -z "$workflow_id" ]] || is_natural "$workflow_id"                        || error "The specified workflow identifier '$workflow_id' is not valid." -ec "$err_argument_type"

    readonly artifact_name
    readonly artifacts
    [[ -z "$repository" ]] || readonly repository
    readonly workflow_name
    readonly workflow_path
    [[ -z "$workflow_id" ]] || readonly workflow_id

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

        artifact_name
        artifacts
        repository
        workflow_id
        workflow_name
        workflow_path

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
