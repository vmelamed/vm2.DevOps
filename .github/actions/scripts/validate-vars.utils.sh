#!/bin/bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function get_arguments()
{
    if [[ "${#}" -eq 0 ]]; then return; fi

    # process --debugger first
    for v in "$@"; do
        if [[ "$v" == "--debugger" ]]; then
            get_common_arg "--debugger"
            break
        fi
    done
    if [[ $debugger != "true" ]]; then
        trap on_debug DEBUG
        trap on_exit EXIT
    fi

    local flag
    local value

    while [[ "${#}" -gt 0 ]]; do
        flag="$1"
        shift
        if get_common_arg "$flag"; then
            continue
        fi

        case "${flag,,}" in
            # do not use the common options:
            --help|-h|--debugger|-q|--quiet-v|--verbose-x|--trace-y|--dry-run )
                ;;
            --build-projects|-b )
                value="$1"; shift
                build_projects="$value"
                ;;
            --test-projects|-t )
                value="$1"; shift
                test_projects="$value"
                ;;
            --benchmark-projects|-p )
                value="$1"; shift
                benchmark_projects="$value"
                ;;
            --os|-o )
                value="$1"; shift
                os="$value"
                ;;
            --dotnet-version )
                value="$1"; shift
                dotnet_version="$value"
                ;;
            --configuration|-c )
                value="$1"; shift
                configuration="$value"
                ;;
            --preprocessor-symbols|-d )
                value="$1"; shift
                preprocessor_symbols="$value"
                ;;
            --min-coverage-pct|-min )
                value="$1"; shift
                min_coverage_pct="$value"
                ;;
            --max-regression-pct|-max )
                value="$1"; shift
                max_regression_pct="$value"
                ;;
            --minver-tag-prefix|-f )
                value="$1"; shift
                minver_tag_prefix="$value"
                ;;
            --minver-prerelease-id|-i )
                value="$1"; shift
                minver_prerelease_id="$value"
                ;;
            * )
                usage "Unknown option: $flag"
                exit 2
                ;;
        esac
    done
}

dump_all_variables()
{
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        debugger \
        dry_run \
        verbose \
        quiet \
        --blank \
        build_projects \
        test_projects \
        benchmark_projects \
        os \
        dotnet_version \
        configuration \
        preprocessor_symbols \
        min_coverage_pct \
        max_regression_pct
}
