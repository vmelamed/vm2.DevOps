# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function get_arguments()
{
    local option
    local value
    local p

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

            --configuration|-c )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                configuration="$1"; shift
                ;;

            --define|-d )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                preprocessor_symbols="$1"; shift
                ;;

            --minver-tag-prefix|-mp )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-mi )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                minver_prerelease_id="$1"; shift
                ;;

            --max-regression-pct|-max )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                value="$1"; shift
                max_regression_pct=$((value + 0))  # ensure it's an integer
                ;;

            --artifacts|-a )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                artifacts_dir=$1; shift
                ;;

            *)  value="$option"
                benchmark_project="$value"
                ;;
        esac
    done
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        benchmark_project \
        configuration \
        preprocessor_symbols \
        minver_tag_prefix \
        minver_prerelease_id \
        artifacts_dir \
        --header "other:" \
        ci
}
