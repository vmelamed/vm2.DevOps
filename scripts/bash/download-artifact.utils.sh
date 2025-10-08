#!/bin/bash

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
    # shellcheck disable=SC2154 # v appears unused. Verify use (or export if used externally).
    if [[ $debugger != "true" ]]; then
        trap on_debug DEBUG
        trap on_exit EXIT
    fi

    local flag
    local value
    local p

    while [[ "${#}" -gt 0 ]]; do
        # get the flag and convert it to lower case
        flag="$1"
        shift
        if get_common_arg "$flag"; then
            continue
        fi
        # do not use short options -q -v -x -y
        case "$flag" in
            --debugger )
                ;;  # already processed above
            --help|-h )
                usage
                exit 0
                ;;
            --repository|-r )
                repository="$1";
                shift
                ;;
            --wf-id|-i )
                workflow_id="$1"
                workflow_name=""
                workflow_path=""
                shift
                ;;
            --wf-name|-n )
                workflow_id=""
                workflow_name="$1"
                workflow_path=""
                shift
                ;;
            --wf-path|-p )
                workflow_id=""
                workflow_name="";
                workflow_path="$1"
                shift
                ;;
            --artifact|-a )
               artifact_name="$1"
               shift
               ;;
            --directory|-d )
                artifacts_dir="$1"
                shift
                ;;
            * )
                usage "Unknown option '$flag'."
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
        trace_enabled \
        --blank \
        repository \
        workflow_name \
        workflow_path \
        workflow_id \
        artifact_name \
        artifacts_dir \
        --header "other:" \
        ci
}
