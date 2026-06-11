# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_unknown_argument

declare -x owner
declare -xi repeat
declare -x workflow

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
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

            --owner|-o )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${option,,}"
                owner="$1"; shift
                ;;

            --repeat|-n )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${option,,}"
                repeat="$1"; shift
                ;;

            --workflow|-w )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing value for ${option,,}"
                workflow="$1"; shift
                ;;

            *)  usage -ec "$err_unknown_argument" "Unknown argument: $option"
                ;;
        esac
    done
    dump_vars --force --quiet \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        owner \
        repeat \
        workflow
}
