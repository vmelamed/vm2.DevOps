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

            --package-project|-pp )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                package_project="$1"; shift
                ;;

            --configuration|-c )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                configuration="$1"; shift
                ;;

            --define|-d )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                preprocessor_symbols="$1"; shift
                ;;

            --minver-tag-prefix|-mp )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-mi )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_prerelease_id="$1"; shift
                ;;

            * )
                usage false "Unknown option: $option"
                ;;
        esac
    done
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        package_project \
        configuration \
        preprocessor_symbols \
        minver_tag_prefix \
        minver_prerelease_id \
        --header "other:" \
        ci
}
