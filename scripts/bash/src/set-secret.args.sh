# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# constants from lib:
declare -xri success
declare -xri err_argument_value
declare -xri err_too_many_arguments
declare -xri err_missing_argument

declare -xra gh_apps_with_secrets

declare -xr default_repo_owner

# this script constants
declare -xr default_app='actions'

# this script arguments
declare -x repo_owner=''
declare -x app=''
declare -x secret_name=''

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            -o|--repo-owner )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                repo_owner="$1"; shift
                ;;

            -a|--app )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                app="$1"; shift
                ;;

            -n|--secret-name )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                secret_name="$1"; shift
                ;;

            * ) [[ -z "$secret_name" ]] || usage -ec "$err_too_many_arguments" "Too many positional arguments (secret name): $_option"
                secret_name="$_option"
                ;;
        esac
    done

    validate_args
    dump_args
    usage_if_requested
}

function validate_args()
{
    app=${app:-$default_app}
    repo_owner=${repo_owner:-$default_repo_owner}

    is_in "$app" "${gh_apps_with_secrets[@]}" || error -ec "$err_argument_value" "Invalid app specified: '$app'. Must be one of: ${gh_apps_with_secrets[*]}."
    is_valid_secret_name "$secret_name"    || error -ec "$err_argument_value" "Invalid secret name specified: '$secret_name'. "
    exit_if_has_errors true

    readonly repo_owner app secret_name
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        repo_owner
        app
        secret_name

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
