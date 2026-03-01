#!/usr/bin/env bash

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function get_arguments()
{
    local option

    while [[ $# -gt 0 ]]; do
        # get the option and convert it to lower case
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

            --reason|-r )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                reason="$1"; shift
                ;;

            --nuget-server|-n )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                nuget_server="$1"; shift
                ;;

            --repo-owner|-o )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                repo_owner="$1"; shift
                ;;

            --artifacts-saved|-a )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                artifacts_saved="$1"; shift
                ;;

            --artifacts-dir|-ad )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                artifacts_dir="$1"; shift
                ;;

            * ) usage false "Unknown option: $option"
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
        preprocessor_symbols \
        minver_tag_prefix \
        minver_prerelease_id \
        reason \
        nuget_server \
        repo_owner \
        artifacts_saved \
        artifacts_dir \
        --header "other:" \
        ci
}
