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
            --build-project|-b )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                if [[ -n $build_project ]]; then
                    usage false "The script accepts 0 or 1 project or solution."
                fi
                build_project="$1"; shift
                ;;
            --configuration|-c )
                configuration="$1"; shift
                ;;
            --preprocessor-symbols|-d )
                preprocessor_symbols="$1"; shift
                ;;
            --minver-tag-prefix|-f )
                minver_tag_prefix="$1"; shift
                ;;
            --minver-prerelease-id|-i )
                minver_prerelease_id="$1"; shift
                ;;
            --nuget-username )
                nuget_username="$1"; shift
                ;;
            --nuget-password )
                nuget_password="$1"; shift
                ;;
            * )
                usage false "Unknown argument: $option"
                ;;
        esac
    done
    return 0
}

dump_all_variables()
{
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        build_project \
        configuration \
        preprocessor_symbols \
        minver_tag_prefix \
        minver_prerelease_id \
        nuget_username \
        --header "other:" \
        ci
}
