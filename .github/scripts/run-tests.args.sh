# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

# parameters specific to this script only with initial values from environment variables or defaults
declare -x test_project
declare -xi min_coverage_pct
declare -xi min_branch_coverage_pct

function get_arguments()
{
    local _option

    while [[ $# -gt 0 ]]; do
        # get the option and convert it to lower case
        _option="$1"
        shift
        get_common_arg "${_option,,}" &&
            continue

        (( $# >= 1 )) &&
            get_common_dotnet_arg "$_option" "$1" &&
            shift &&
            continue

        case "${_option,,}" in
            # get the arguments specific to this script
            --min-coverage-pct|-min )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                min_coverage_pct=$1
                shift
                min_coverage_pct=$((min_coverage_pct + 0))  # ensure it's an integer
                ;;

            # do not use the common options - they were already processed by get_common_arg and get_common_dotnet_arg:
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                ;;
            -d|-c|-f|-r|-a|-mp|-mi|--define|--configuration|--framework|--runtime|--artifacts-path|--minver-tag-prefix|--minver-prerelease-id|--nuget-username|--nuget-password )
                ;;

            * ) [[ -z $test_project ]] || usage -sd 3 -ec "$err_too_many_arguments" "Multiple test projects specified. Unknown option: $_option"
                [[ "$_option" != -* ]] || usage -sd 3 -ec "$err_unknown_argument" "Unknown option: $_option"
                test_project="$_option"
                ;;
        esac
    done

    dump_vars --force --quiet \
        --header "Arguments of $script_name:" \
        --core-state \
        test_project \
        --common-dotnet-args \
        min_coverage_pct \
        --header "other:" \
        ci

    usage_if_requested
}
