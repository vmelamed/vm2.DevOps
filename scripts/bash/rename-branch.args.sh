# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

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

            * ) if [[ -z "$new_branch_name" ]]; then
                    new_branch_name="$option"
                elif [[ -z "$old_branch_name" ]]; then
                    old_branch_name="$new_branch_name"
                    new_branch_name="$option"
                else
                    usage false "Too many positional arguments: ${option}"
                fi
                ;;
        esac
    done
}

dump_all_variables()
{
    dump_vars --quiet \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        old_branch_name \
        new_branch_name
        # add var names above this line
}
