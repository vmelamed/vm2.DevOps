# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

declare -xr script_name
declare -xr lib_dir
declare -xr common_dir

declare -x commit_sha
declare -x new_branch
declare -x check_out_new_branch

# shellcheck disable=SC2154 # verbose is referenced but not assigned.
function get_arguments()
{
    local option

    while [[ $# -gt 0 ]]; do
        option="$1"; shift
        if get_common_arg "$option"; then
            continue
        fi

        case "${option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --branch|-b )
                (( $# >= 1 )) ||
                    usage -ec "$err_missing_argument" "Missing branch name after '$option'."
                new_branch="$1"; shift
                ;;

            --commit-sha|-c )
                (( $# >= 1 )) ||
                    usage -ec "$err_missing_argument" "Missing commit SHA after '$option'."
                commit_sha="$1"; shift
                ;;

            --check-out-new|-n )
                check_out_new_branch=true
                ;;

            * )
                usage -ec "$err_unknown_argument" "Unknown argument '$option'."
                ;;
        esac
    done
}
