# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_tool_not_found

declare -xr ci

declare -xra dump_common_dotnet_args

# parameters specific to this script only with initial values from environment variables or defaults
declare -x benchmark_project="${benchmark_project:-"${BENCHMARK_PROJECT:-}"}"

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
        _option="$1"
        shift
        get_common_arg "$_option" && continue

        get_common_dotnet_arg "$_option" "${1:-}" && {
            (( $# >= 1 )) && shift
            continue
        }

        [[ "$_option" != -* ]]                                                  || usage "Unknown argument: $_option" -ec "$err_unknown_argument"

        ! $_positional_arg_set                                                  || usage "Multiple benchmark projects specified: $_option" -ec "$err_too_many_arguments"
        benchmark_project="$_option"
        _positional_arg_set=true
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
    is_safe_existing_path "$benchmark_project"                                  || true
    [[ $benchmark_project == *.csproj ]]                                        || error "The script '${script_name}' accepts only project files (*.csproj) - not solutions (*.sln or *.slnx)."
    sanitize_common_dotnet_args "$benchmark_project"

    readonly benchmark_project

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

        benchmark_project

        "${dump_common_dotnet_args[@]}"
        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
