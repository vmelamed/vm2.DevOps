#!/usr/bin/env bash

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
            # do not use the common options:
            -h|-v|-q|-x|-y|--help|--debugger|--quiet|--verbose|--trace|--dry-run )
                ;;

            --force-new-baseline|-f )
                force_new_baseline=true
                ;;

            --artifacts|-a )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                value="$1"; shift
                artifacts_dir=$(realpath -m "$value")
                ;;

            --max-regression-pct|-r )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                value="$1"; shift
                if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < 0 || value > 100 )); then
                    usage false "$(usage_text)" "The regression threshold must be an integer between 0 and 100. Got '$value'."
                    exit 2
                fi
                max_regression_pct=$((value + 0))  # ensure it's an integer
                ;;

            --configuration|-c )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                value="$1"; shift
                configuration="${value,,}"
                configuration="${configuration^}"
                if ! is_in "$configuration" "Release" "Debug"; then
                    usage false "The coverage threshold must be either 'Release' or 'Debug'. Got '$value'."
                    exit 2
                fi
                ;;

            --define|-d )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                value="$1"; shift
                if ! [[ "$value" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                    usage false "The specified pre-processor symbol '$value' is not valid."
                    exit 2
                fi
                if [[ ! "$preprocessor_symbols" =~ (^|;)"$value"($|;) ]]; then
                    preprocessor_symbols="$value $preprocessor_symbols"  # NOTE: space-separated!
                fi
                ;;

            --short-run|-s )
                # Shortcut for --preprocessor_symbols SHORT_RUN
                if [[ ! "$preprocessor_symbols" =~ (^|;)SHORT_RUN($|;) ]]; then
                    preprocessor_symbols="$preprocessor_symbols SHORT_RUN"  # NOTE: space-separated!
                fi
                ;;

            --minver-tag-prefix|-p )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-i )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_prerelease_id="$1"; shift
                ;;

            *)  value="$option"
                if [[ ! -s "$value" ]]; then
                    usage false "The specified test project file $value does not exist."
                fi
                bm_project="$value"
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
        bm_project \
        configuration \
        preprocessor_symbols \
        max_regression_pct \
        force_new_baseline \
        artifacts_dir \
        --header "other:" \
        ci \
        script_dir \
        --blank \
        solution_dir \
        results_dir \
        summaries_dir \
        baseline_dir
}
