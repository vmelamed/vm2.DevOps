# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# constants from lib:
declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_unknown_argument
declare -xri err_logic_error

declare -xra vm2_repositories

declare -xr vm2_sot_repo_name

# this script's arguments
declare -a requested_repos=()
declare -x summary_file=''

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            -sf|--summary-file )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                summary_file="$1"; shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            * ) is_empty_array target_repos || ! is_in "$_option" "${requested_repos[@]}" &&
                    requested_repos+=("$_option")
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
