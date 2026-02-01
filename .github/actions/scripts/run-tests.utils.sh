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
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --configuration|-c )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                configuration=$1; shift
                ;;

            --define|-d    )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                preprocessor_symbols=$1; shift
                ;;

            --min-coverage-pct|-min )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                min_coverage_pct=$1; shift
                min_coverage_pct=$((min_coverage_pct + 0))  # ensure it's an integer
                ;;

            --minver-tag-prefix|-mp )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-mi )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_prerelease_id="$1"; shift
                ;;

            --artifacts|-a )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                artifacts_dir=$1; shift
                ;;

            * ) value="$option"
                test_project="$value"
                ;;
        esac
    done
}

dump_all_variables()
{
    dump_vars --force \
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
        artifacts_dir \
        --header "other:" \
        ci \
        lib_dir \
        coverage_results_dir \
        --blank \
        coverage_source_path \
        --blank \
        coverage_reports_path \
        --blank \
        coverage_summary_text_dir \
        coverage_summary_html_dir \
        coverage_summary_text_path
}
