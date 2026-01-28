#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function get_arguments()
{
    local option

    while [[ $# -gt 0 ]]; do
        option="$1"; shift
        if get_common_arg "$option"; then
            continue
        fi
        case "${option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --build-projects|-b )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                build_projects="$1"; shift
                ;;

            --test-projects|-t )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                test_projects="$1"; shift
                ;;

            --benchmark-projects|-p )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                benchmark_projects="$1"; shift
                ;;

            --runners-os|-o )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                runners_os="$1"; shift
                ;;

            --dotnet-version )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                dotnet_version="$1"; shift
                ;;

            --configuration|-c )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                configuration="$1"; shift
                ;;

            --preprocessor-symbols|-d )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                preprocessor_symbols="$1"; shift
                ;;

            --min-coverage-pct|-min )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                min_coverage_pct="$1"; shift
                ;;

            --max-regression-pct|-max )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                max_regression_pct="$1"; shift
                ;;

            --minver-tag-prefix|-f )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-i )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_prerelease_id="$1"; shift
                ;;

            * )
                usage false "Unknown option: $option"
                ;;
        esac
    done
}

dump_all_variables()
{
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        build_projects \
        test_projects \
        benchmark_projects \
        runners_os \
        dotnet_version \
        configuration \
        preprocessor_symbols \
        min_coverage_pct \
        max_regression_pct
}
