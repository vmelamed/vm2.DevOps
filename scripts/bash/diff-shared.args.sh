# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

declare -x vm2_repos
declare -xa file_regexes
declare -x target_dir
declare -x target_branch

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
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

            --vm2-repos|-r )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                vm2_repos="$1"; shift
                ;;

            --files|-f )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                IFS=',' read -r -a file_regexes <<< "$1"
                shift
                ;;

            * ) if [[ -z "$target_dir" ]]; then
                    target_dir="$option"
                else
                    usage "$err_too_many_arguments" "Too many positional arguments (project directory or repository name): ${option}"
                fi
                ;;
        esac
    done
    dump_args
}

dump_args()
{
    dump_vars --quiet \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        vm2_repos \
        target_dir \
        file_regexes
        # add var names above this line
}
