#!/usr/bin/env bash

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function get_arguments()
{
    local option
    local value

    while [[ $# -gt 0 ]]; do
        # get the option and convert it to lower case
        option="$1"; shift
        if get_common_arg "$option"; then
            continue
        fi
        # do not use short options -q -v -x -y
        case "${option,,}" in
            # do not use the common options:
            -h|-v|-q|-x|-y|--help|--debugger|--quiet|--verbose|--trace|--dry-run )
                ;;

            --artifacts|-a )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                value="$1"; shift
                artifacts_dir=$(realpath -m "$value")
                ;;

            --define|-d    )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                value="$1"; shift
                if ! [[ "$value" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                    usage false "The specified preprocessor symbol '$value' is not valid."
                fi
                if [[ ! "$preprocessor_symbols" =~ (^|;)"$value"($|;) ]]; then
                    preprocessor_symbols="$value $preprocessor_symbols"   # NOTE: space-separated!
                fi
                ;;

            --min-coverage-pct|-t )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                value="$1"; shift
                if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < 0 || value > 100 )); then
                    usage false "The coverage threshold must be an integer between 0 and 100. Got '$value'."
                fi
                min_coverage_pct=$((value + 0))  # ensure it's an integer
                ;;

            --configuration|-c )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                value="$1"; shift
                configuration="${value,,}"
                configuration="${configuration^}"
                if ! is_in "$configuration" "Release" "Debug"; then
                    usage false "The coverage threshold must be either 'Release' or 'Debug'. Got '$value'."
                fi
                ;;

            * ) value="$option"
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                if [[ ! -s "$value" ]]; then
                    usage false "The specified test project file '$value' does not exist."
                fi
                test_project="$value"
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
        test_project \
        configuration \
        preprocessor_symbols \
        min_coverage_pct \
        artifacts_dir \
        --header "other:" \
        ci \
        script_dir \
        solution_dir \
        base_name \
        test_results_dir \
        coverage_results_dir \
        --blank \
        coverage_source_dir \
        coverage_source_fileName \
        coverage_source_path \
        --blank \
        coverage_reports_dir \
        coverage_reports_path \
        --blank \
        coverage_summary_dir \
        coverage_summary_path \
        coverage_summary_html_dir
}
