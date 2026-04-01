# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_more_than_one_argument
declare -rxi err_unknown_argument

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function get_arguments()
{
    local option

    while [[ $# -gt 0 ]]; do
        # get the option and convert it to lower case
        option="$1"; shift
        if get_common_arg "$option"; then
            continue
        fi
        # do not use short options -q -v -x -y
        case "${option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --artifact|-a )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
               artifact_name="$1"; shift
               ;;

            --directory|-d )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                artifacts_dir="$1"; shift
                ;;

            --repository|-r )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                repository="$1"; shift
                ;;

            --wf-id|-i )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                workflow_id="$1"; shift
                workflow_name=""
                workflow_path=""
                ;;

            --wf-name|-n )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                workflow_id=""
                workflow_name="$1"; shift
                workflow_path=""
                ;;

            --wf-path|-p )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                workflow_id=""
                workflow_name="";
                workflow_path="$1"; shift
                ;;

            * )
                usage "$err_unknown_argument" "Unknown argument '$option'."
                ;;
        esac
    done
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        artifact_name \
        artifacts_dir \
        repository \
        workflow_id \
        workflow_name \
        workflow_path \
        --header "other:" \
        ci
}
