# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# constants from lib:
declare -xri success
declare -xri err_argument_value

declare -xra vm2_repositories

declare -xr vm2_sot_repo_name

# this script's arguments
declare -a requested_repos=()

function get_arguments()
{
    local _option _repo

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            * ) requested_repos+=("$_option")
                ;;
        esac
    done

    validate_args
    usage_if_requested
}

function validate_args()
{
    local _repo
    for _repo in "${requested_repos[@]}"; do
        is_in "$_repo" "${vm2_repositories[@]}" || error -ec "$err_argument_value" "Unknown repository '$_repo'. Must be one of: ${vm2_repositories[*]}."
    done
    exit_if_has_errors true
}
