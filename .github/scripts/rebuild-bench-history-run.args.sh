# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

declare -x benchmark_project
declare -xi repeat
declare -x configuration
declare -x preprocessor_symbols
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x artifacts_dir
declare -x bencher_project
declare -x bencher_testbed
declare -x bencher_branch
declare -x bencher_adapter

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function get_arguments()
{
    local _option

    while [[ $# -gt 0 ]]; do
        _option="$1"; shift
        if get_common_arg "$_option"; then
            continue
        fi
        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --repeat|-n )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                repeat="$1"; shift
                ;;

            --configuration|-c )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                configuration="$1"; shift
                ;;

            --define|-d )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                preprocessor_symbols="$1"; shift
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
                artifacts_dir="$1"; shift
                ;;

            --bencher-project|-bp )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                bencher_project="$1"; shift
                ;;

            --bencher-testbed|-tb )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                bencher_testbed="$1"; shift
                ;;

            --bencher-branch|-br )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                bencher_branch="$1"; shift
                ;;

            --bencher-adapter|-ad )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                bencher_adapter="$1"; shift
                ;;

            *)  [[ -z $benchmark_project ]] || usage -ec "$err_too_many_arguments" "Multiple benchmark projects specified. Unknown option: $_option"
                [[ "$_option" != -* ]] || usage -ec "$err_unknown_argument" "Unknown option: $_option"
                benchmark_project="$_option"
                ;;
        esac
    done
    usage_if_requested
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        benchmark_project \
        repeat \
        configuration \
        preprocessor_symbols \
        minver_tag_prefix \
        minver_prerelease_id \
        artifacts_dir \
        bencher_project \
        bencher_testbed \
        bencher_branch \
        bencher_adapter \
        --header "other:" \
        ci
}
