# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

declare -x package_project
declare -x reason
declare -x nuget_server
declare -x repo_owner
declare -x save_artifacts

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        # get the option and convert it to lower case
        _option="$1"
        shift

        get_common_arg "${_option,,}" &&
            continue

        (( $# >= 1 )) &&
            get_common_dotnet_arg "$_option" "$1" &&
            shift &&
            continue

        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            --reason )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                reason="$1"
                shift
                ;;

            --nuget-server|-n )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                nuget_server="$1"
                shift
                ;;

            --repo-owner|-o )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                repo_owner="$1"
                shift
                ;;

            --save-artifacts|-s )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                save_artifacts="$1"
                shift
                ;;

            # do not use the common options - they were already processed by get_common_arg and get_common_dotnet_arg:
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                ;;
            -d|-c|-f|-r|-a|-mp|-mi|--define|--configuration|--framework|--runtime|--artifacts-path|--minver-tag-prefix|--minver-prerelease-id|--nuget-username|--nuget-password )
                ;;

            * ) [[ -z $package_project ]] || usage -ec "$err_too_many_arguments" "Multiple package projects specified. Unknown option: $_option"
                [[ "$_option" != -* ]] || usage -ec "$err_unknown_argument" "Unknown option: $_option"
                package_project="$_option"
                ;;
        esac
    done

    dump_vars --force --quiet \
        --header "Arguments for $script_name:" \
        --core-state \
        package_project \
        --common-dotnet-args \
        reason \
        nuget_server \
        repo_owner \
        save_artifacts \
        --header "other:" \
        ci

    usage_if_requested
}
