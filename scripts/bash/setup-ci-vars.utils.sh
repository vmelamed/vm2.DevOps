#!/bin/bash

# shellcheck disable=SC2154 # v appears unused. Verify use (or export if used externally).
# shellcheck disable=SC2034 # xyz appears unused. Verify use (or export if used externally).
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
            --debugger     ) ;;  # already processed above
            --help|-h      ) usage; exit 0 ;;
            --build-project|-b )
                value="$1"; shift
                test_project="$value"
                ;;
            --test-project|-t )
                value="$1"; shift
                test_project="$value"
                ;;
            --benchmark-project|-p )
                value="$1"; shift
                benchmark_project="$value"
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
            --run-benchmarks|-r )
                value="$1"; shift
                run_benchmarks="$value"
                ;;
            --force-new-baseline|-f )
                value="$1"; shift
                force_new_baseline="$value"
                ;;
            --max-regression-pct|-max )
                value="$1"; shift
                max_regression_pct="$value"
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
    dump_vars \
        --header "Script Arguments:" \
        debugger \
        dry_run \
        verbose \
        quiet \
        --blank \
        os \
        dotnet_version \
        configuration \
        preprocessor_symbols \
        test_project \
        min_coverage_pct \
        run_benchmarks \
        benchmark_project \
        force_new_baseline \
        max_regression_pct
}
