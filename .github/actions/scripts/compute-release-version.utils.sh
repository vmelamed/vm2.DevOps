#!/usr/bin/env bash

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function get_arguments()
{
    if [[ "${#}" -eq 0 ]]; then return; fi

    # process --debugger first
    for v in "$@"; do
        if [[ "$v" == "--debugger" ]]; then
            get_common_arg "$v"
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

            --package-projects|-p )
                value="$1"; shift
                package_projects="$value"
                ;;

            --nuget-server|-n )
                value="$1"; shift
                nuget_server="$value"
                ;;

            --minver-tag-prefix|-t )
                value="$1"; shift
                minver_tag_prefix="$value"
                ;;

            --reason|-r )
                value="$1"; shift
                reason="$value"
                ;;

            * ) usage "Unknown option: $flag"
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
        package_projects \
        nuget_server \
        minver_tag_prefix \
        reason \
        --header "other:" \
        ci
}
