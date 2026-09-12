# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri err_missing_argument
declare -xri err_unknown_argument

declare -x owner
declare -xi repeat
declare -x workflow

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue
        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --owner|-o )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                owner="$1"; shift
                ;;

            --repeat|-n )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                repeat="$1"; shift
                ;;

            --workflow|-w )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                workflow="$1"; shift
                ;;

            *)  usage -ec "$err_unknown_argument" "Unknown argument: $_option"
                ;;
        esac
    done

    dump_vars --force --quiet \
        --header "Arguments for $script_name:" \
        --core-state \
        owner \
        repeat \
        workflow

    usage_if_requested
}
