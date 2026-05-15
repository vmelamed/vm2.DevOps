# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

declare -x base_ref=""

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

            --base-ref|-b )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${option,,}"
                base_ref="$1"; shift
                ;;
            * )
                usage -ec "$err_unknown_argument" "Unknown argument: $option"
                ;;
        esac
    done

    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        dry_run verbose quiet \
        --blank \
        base_ref
}
