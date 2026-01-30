#!/usr/bin/env bash

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
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

            --package-projects|-pp )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                package_projects="$1"; shift
                ;;

            --minver-tag-prefix|-mp )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --reason|-r )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                reason="$1"; shift
                ;;

            --nuget-server|-n )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                nuget_server="$1"; shift
                ;;

            * ) usage false "Unknown option: $option"
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
        package_projects \
        minver_tag_prefix \
        reason \
        nuget_server \
        --header "other:" \
        ci
}
