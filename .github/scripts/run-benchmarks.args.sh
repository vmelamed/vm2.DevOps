# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

declare -x ci

# parameters specific to this script only with initial values from environment variables or defaults
declare -x benchmark_project

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"
        shift
        get_common_arg "$_option" &&
            continue

        get_common_dotnet_arg "$_option" "${1:-}" && {
            (( $# >= 1 )) && shift
            continue
        }

        [[ -z $benchmark_project ]] ||
            usage -ec "$err_too_many_arguments" "Multiple benchmark projects specified. Unknown option: $_option"
        [[ "$_option" != -* ]] ||
            usage -ec "$err_unknown_argument" "Unknown option: $_option"
        benchmark_project="$_option"
    done

    dump_args

    usage_if_requested
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
        --header "\`dotnet <command>\` CLI Arguments:"
        --common-dotnet-args

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
