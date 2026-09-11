# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

declare -x artifact_name
declare -x artifacts
declare -x repository
declare -x workflow_id
declare -x workflow_name
declare -x workflow_path

function get_arguments()
{
    local _option

    while [[ $# -gt 0 ]]; do
        # get the option and convert it to lower case
        _option="$1"; shift
        get_common_arg "$_option" && continue
        # do not use short options -q -v -x -y
        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --artifact|-a )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
               artifact_name="$1"; shift
               ;;

            --directory|-d )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                artifacts="$1"; shift
                ;;

            --repository|-r )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                repository="$1"; shift
                ;;

            --wf-id|-i )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                workflow_id="$1"; shift
                workflow_name=""
                workflow_path=""
                ;;

            --wf-name|-n )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                workflow_id=""
                workflow_name="$1"; shift
                workflow_path=""
                ;;

            --wf-path|-p )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                workflow_id=""
                workflow_name="";
                workflow_path="$1"; shift
                ;;

            * )
                usage -ec "$err_unknown_argument" "Unknown argument '$_option'."
                ;;
        esac
    done

    dump_vars --force --quiet \
        --header "Arguments for $script_name:" \
        --core-state \
        artifact_name \
        artifacts \
        repository \
        workflow_id \
        workflow_name \
        workflow_path \
        --header "other:" \
        ci

    usage_if_requested
}
