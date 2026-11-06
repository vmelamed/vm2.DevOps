# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

declare -xr ci

declare -xra dump_common_dotnet_args

# parameters specific to this script only with initial values from environment variables or defaults
declare -x benchmark_project="${benchmark_project:-"${BENCHMARK_PROJECT:-}"}"

function get_arguments()
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

        [[ "$_option" != -* ]]                                                  || usage -ec "$err_unknown_argument" "Unknown argument: $_option"

        ! $_positional_arg_set                                                  || usage -ec "$err_too_many_arguments" "Multiple benchmark projects specified: $_option"
        benchmark_project="$_option"
        _positional_arg_set=true
    done

    usage_if_requested
    validate_arguments
    exit_if_has_errors
    dump_args
}

function validate_arguments()
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
