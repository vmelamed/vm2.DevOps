# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# reference error codes defined in the core library
declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_tool_not_found

declare -xr ci

# parameters specific to this script only with initial values from environment variables or defaults
declare -x package_project
declare -x build
declare -x reason

declare -xra dump_common_dotnet_args

# variables specific to this script only with initial values from environment variables or defaults
declare -x package_project=${PACKAGE_PROJECT:-}
declare -x reason=${REASON:-}
declare -x build=${BUILD:-false}

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
    local _positional_arg_set=false

    while (( $# > 0 )); do
        # get the option and convert it to lower case
        _option="$1"
        shift

        get_common_arg "${_option,,}" && continue

        get_common_dotnet_arg "$_option" "${1:-}" && {
            (( $# >= 1 )) && shift
            continue
        }

        case "${_option,,}" in
            # get the arguments specific to this script
            --reason|-r )
                (( $# > 0 ))                                                    || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                reason="$1"
                shift
                ;;

            --build|-b )
                (( $# > 0 ))                                                    || usage "Missing boolean value for ${_option,,}" -ec "$err_missing_argument"
                build="$1"
                shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            # reserved: the options get_common_dotnet_arg consumes before this case (see the arm above).
            -c|-d|-tfm|-rid|--define|--configuration|--framework|--runtime|--artifacts-path|--minver-tag-prefix|--minver-prerelease-id|--nuget-username|--nuget-password )
                exit_with_bug "'$_option' should have been consumed by get_common_dotnet_arg." -ec "$err_logic_error"
                ;;

            -*) usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;

            * ) ! $_positional_arg_set                                          || usage "Multiple package projects specified: $_option" -ec "$err_too_many_arguments"
                package_project="$_option"
                _positional_arg_set=true
                ;;
        esac
    done

    return "$success"
}

function verify_environment
{
    is_dotnet_present                                                           || true

    return "$success"
}

function resolve_arguments()
{
    package_project=${package_project:-}
    # validate the values of the variables common for many vm2.DevOps scripts,
    # usually set from CLI arguments, environment variables, or defaults
    is_safe_existing_file "$package_project"                                    || true
    [[ $package_project == *.csproj ]]                                          || error "The script '${script_name}' accepts only project files (*.csproj) - not solutions (*.sln or *.slnx)." -ec "$err_argument_value"
    is_safe_boolean "$build"                                                    || true
    is_safe_reason "$reason"                                                    || true
    sanitize_common_dotnet_args "$package_project"

    readonly package_project
    readonly build
    readonly reason

    return "$success"
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        package
        reason

        "${dump_common_dotnet_args[@]}"

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
