# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument

function dump_all_variables()
{
    dump_vars --quiet \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        delete_mode \
        old_tag \
        new_tag \
        del_tag \
        # add var names above this line
}

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

            --delete|-d )
                [[ $# -ge 1 && -z "$old_tag" ]] || usage -ec "$err_missing_argument" "Missing value for ${option,,}"
                delete_mode=true
                del_tag="$1"; shift
                ;;

            * )
                if   [[ -z "$old_tag" ]]; then old_tag="$option"
                elif [[ -z "$new_tag" ]]; then new_tag="$option"
                else usage "Unexpected argument: $option"
                fi
                ;;
        esac
    done
    dump_all_variables
}
