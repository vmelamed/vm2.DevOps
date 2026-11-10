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
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_tool_not_found
declare -xri err_tool_unauthenticated

declare -xra gh_apps_with_secrets

declare -xr default_repo_owner

# this script constants
declare -xr default_app='actions'

declare -x _ignore

# this script arguments
declare -x repo_owner=''
declare -x app=''
declare -x secret_name=''

function get_arguments()
{
    parse_arguments "$@"
    usage_if_requested
    verify_environment
    resolve_arguments
    exit_if_has_errors
    dump_args
}

function parse_arguments()
{
    local _option
    local _option_set=false

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            -o|--repo-owner )
                (( $# >= 1 ))                                                   || usage "Missing value for $_option" -ec "$err_missing_argument"
                repo_owner="$1"; shift
                ;;

            -a|--app )
                (( $# >= 1 ))                                                   || usage "Missing value for $_option" -ec "$err_missing_argument"
                app="$1"; shift
                ;;

            -n|--secret-name )
                (( $# >= 1 ))                                                   || usage "Missing value for $_option" -ec "$err_missing_argument"
                secret_name="$1"; shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            -*) usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;

            * ) ! $_option_set                                                  || usage "Too many positional arguments (secret name): $_option" -ec "$err_too_many_arguments"
                secret_name="$_option"
                _option_set=true
                ;;
        esac
    done

    return "$success"
}

function verify_environment
{
    is_git_present                                                              || true
    is_gh_present                                                               || true

    return "$success"
}

function resolve_arguments()
{
    app=${app:-$default_app}
    repo_owner=${repo_owner:-$default_repo_owner}

    is_in_i "$app" "${gh_apps_with_secrets[@]}"                                 || error "Invalid app specified: '$app'. Must be one of: ${gh_apps_with_secrets[*]}." -ec "$err_argument_value"
    is_valid_secret_name "$secret_name"                                         || error "Invalid secret name specified: '$secret_name'. " -ec "$err_argument_value"
    exit_if_has_errors true

    readonly repo_owner
    readonly app
    readonly secret_name
    return "$success"
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
