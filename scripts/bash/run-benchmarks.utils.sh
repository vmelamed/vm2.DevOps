#!/bin/bash

# shellcheck disable=SC2034 # xyz appears unused. Verify use (or export if used externally).
function get_arguments()
{
    if [[ "${#}" -eq 0 ]]; then return; fi

    # process --debugger first
    for v in "$@"; do
        # there is no debugger in CI!
        if [[ "$v" == "--debugger" ]]; then
            set_debugger
            break
        fi
    done
    # shellcheck disable=SC2154 # v appears unused. Verify use (or export if used externally).
    if [[ $debugger != true ]]; then
        trap on_debug DEBUG
        trap on_exit EXIT
    fi

    local flag
    local value
    local p

    while [[ "${#}" -gt 0 ]]; do
        # get the flag and convert it to lower case
        flag="$1"; shift
        if get_common_arg "$flag"; then
            continue
        fi
        # do not use short options -q -v -x -y
        case "${flag,,}" in
            --debugger              ) ;;  # already processed
            --help|-h               ) usage; exit 0 ;;
            --force-new-baseline|-f ) force_new_baseline=true ;;
            --artifacts|-a          )
                value="$1"
                shift
                artifacts_dir=$(realpath -m "$value")
                ;;
            --max-regression-pct|-r )
                value="$1"; shift
                if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < 0 || value > 100 )); then
                    usage "$(usage_text)" "The regression threshold must be an integer between 0 and 100. Got '$value'."
                    exit 2
                fi
                max_regression_pct=$((value + 0))  # ensure it's an integer
                ;;

            --configuration|-c )
                value="$1"
                shift
                configuration="${value,,}"
                configuration="${configuration^}"
                if ! is_in "$configuration" "Release" "Debug"; then
                    usage "The coverage threshold must be either 'Release' or 'Debug'. Got '$value'."
                    exit 2
                fi
                ;;

            --define|-d )
                value="$1"; shift
                if ! [[ "$value" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                    usage "The specified pre-processor symbol '$value' is not valid."
                    exit 2
                fi
                if [[ ! "$defined_symbols" =~ (^|;)"$value"($|;) ]]; then
                    defined_symbols="$value $defined_symbols"  # NOTE: space-separated!
                fi
                ;;

            --short-run|-s )
                # Shortcut for --defined_symbols SHORT_RUN
                if [[ ! "$defined_symbols" =~ (^|;)SHORT_RUN($|;) ]]; then
                    defined_symbols="$defined_symbols SHORT_RUN"  # NOTE: space-separated!
                fi
                ;;

            *)  value="$flag"
                if [[ ! -s "$value" ]]; then
                    usage "The specified test project file $value does not exist."
                    exit 2
                fi
                bm_project="$value"
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
        trace_enabled \
        --blank \
        bm_project \
        configuration \
        defined_symbols \
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
