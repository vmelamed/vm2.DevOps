# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

declare -x build_project
declare -x configuration
declare -x preprocessor_symbols
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password
declare -x artifacts

function get_arguments()
{
    local _option

    while [[ $# -gt 0 ]]; do
        _option="$1"; shift
        if get_common_arg "$_option"; then
            continue
        fi
        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --configuration|-c )
                configuration="$1"; shift
                ;;

            --define|-d )
                preprocessor_symbols="$1"; shift
                ;;

            --minver-tag-prefix|-mp )
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-mi )
                minver_prerelease_id="$1"; shift
                ;;

            --nuget-username )
                gh_nuget_username="$1"; shift
                ;;

            --nuget-password )
                gh_nuget_password="$1"; shift
                ;;

            --artifacts|-a )
                artifacts="$1"; shift
                ;;

            * ) [[ -z $build_project ]] || usage -ec "$err_too_many_arguments" "Multiple build projects specified. Unknown option: $_option"
                [[ "$_option" != -* ]] || usage -ec "$err_unknown_argument" "Unknown option: $_option"
                build_project="$_option"
                ;;
        esac
    done
    usage_if_requested
    dump_vars --force --quiet \
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
        gh_nuget_username \
        --secret gh_nuget_password \
        --header "other:" \
        ci
}
