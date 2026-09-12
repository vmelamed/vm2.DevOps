# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

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

        (( $# >= 1 )) &&
            get_common_dotnet_arg "$_option" "$1" &&
            shift &&
            continue

        [[ -z $benchmark_project ]] ||
            usage -ec "$err_too_many_arguments" "Multiple benchmark projects specified. Unknown option: $_option"
        [[ "$_option" != -* ]] ||
            usage -ec "$err_unknown_argument" "Unknown option: $_option"
        benchmark_project="$_option"
    done

    dump_vars --force --quiet \
        --header "Arguments for $script_name:" \
        --core-state \
        benchmark_project \
        --common-dotnet-args \
        --header "other:" \
        ci

    usage_if_requested
}
