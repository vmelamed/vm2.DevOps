# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

declare -x ci

declare -x build_projects
declare -x test_projects
declare -x benchmark_projects
declare -x package_projects
declare -x runners_os
declare -x min_coverage_pct
declare -x max_regression_pct
declare -x max_gen1_collects
declare -x max_gen2_collects
declare -x reset_benchmark_thresholds
declare -x skip_tests
declare -x skip_build
declare -x skip_benchmarks
declare -x skip_packages

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"
        shift

        get_common_arg "$_option" &&
            continue

        get_common_dotnet_arg "$_option" "${1:-}" && {
            (( $# >= 1 )) && shift
            continue
        }

        case "${_option,,}" in
            --build-projects|-bp )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                build_projects="$1"
                shift
                ;;

            --test-projects|-tp )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                test_projects="$1"
                shift
                ;;

            --benchmark-projects|-bmp )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                benchmark_projects="$1"
                shift
                ;;

            --package-projects|-pp )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                package_projects="$1"
                shift
                ;;

            --runners-os|-os )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                runners_os="$1"
                shift
                ;;

            --min-coverage-pct|-min )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                min_coverage_pct="$1"
                shift
                ;;

            --max-regression-pct|-max )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                max_regression_pct="$1"
                shift
                ;;

            --max-gen1-collects|-g1 )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                max_gen1_collects="$1"
                shift
                ;;

            --max-gen2-collects|-g2 )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                max_gen2_collects="$1"
                shift
                ;;

            --reset-benchmark-thresholds|-rt )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                reset_benchmark_thresholds="$1"
                shift;
                ;;

            --skip-build|-sb )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                skip_build="$1"
                shift;
                ;;

            --skip-tests|-st )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                skip_tests="$1"
                shift;
                ;;

            --skip-benchmarks|-sbm )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                skip_benchmarks="$1"
                shift;
                ;;

            --skip-packages|-sp )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                skip_packages="$1"
                shift;
                ;;

            # do not use the common options - they were already processed by get_common_arg and get_common_dotnet_arg:
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                ;;
            -c|--define|--configuration|--framework|--runtime|--artifacts-path|--minver-tag-prefix|--minver-prerelease-id|--nuget-username|--nuget-password )
                ;;

            * ) usage -ec "$err_unknown_argument" "Unknown argument: $_option"
                ;;
        esac
    done

    dump_args

    usage_if_requested
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        build_projects
        test_projects
        benchmark_projects
        package_projects
        runners_os
        min_coverage_pct
        max_regression_pct
        max_gen1_collects
        max_gen2_collects
        reset_benchmark_thresholds
        skip_build
        skip_tests
        skip_benchmarks
        skip_packages
        --header "\`dotnet <command>\` CLI Arguments:"
        --common-dotnet-args

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
