# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

declare -x test_project
declare -x configuration
declare -x preprocessor_symbols
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x artifacts
declare -ix min_coverage_pct
declare -ix min_branch_coverage_pct

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function get_arguments()
{
    local _option
    local _value

    while [[ $# -gt 0 ]]; do
        # get the option and convert it to lower case
        _option="$1"; shift
        if get_common_arg "$_option"; then
            continue
        fi
        # do not use short options -q -v -x -y
        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --configuration|-c )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                configuration=$1; shift
                ;;

            --define|-d    )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                preprocessor_symbols=$1; shift
                ;;

            --min-coverage-pct|-min )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                min_coverage_pct=$1; shift
                min_coverage_pct=$((min_coverage_pct + 0))  # ensure it's an integer
                ;;

            --minver-tag-prefix|-mp )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-mi )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                minver_prerelease_id="$1"; shift
                ;;

            --artifacts|-a )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                artifacts=$1; shift
                ;;

            * ) [[ -z $test_project ]] || usage -ec "$err_too_many_arguments" "Multiple test projects specified. Unknown option: $_option"
                [[ "$_option" != -* ]] || usage -ec "$err_unknown_argument" "Unknown option: $_option"
                test_project="$_option"
                ;;
        esac
    done
    usage_if_requested
    dump_vars --force --quiet \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        test_project \
        configuration \
        preprocessor_symbols \
        min_coverage_pct \
        minver_tag_prefix \
        minver_prerelease_id \
        artifacts \
        --header "other:" \
        ci
}
