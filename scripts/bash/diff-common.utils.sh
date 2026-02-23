# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x git_repos
declare -x minver_tag_prefix
declare -xa file_regexes
declare -x target_dir

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

            --git-repos|-r )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                git_repos="$1"; shift
                ;;

            --minver-tag-prefix|-mp )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --files|-f )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                IFS=',' read -r -a file_regexes <<< "$1"
                shift
                ;;

            * ) if [[ -z "$target_dir" ]]; then
                    target_dir="$option"
                else
                    usage false "Too many positional arguments: ${option}"
                fi
                ;;
        esac
    done
}

dump_all_variables()
{
    dump_vars "$@" -q \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        repos \
        minver_tag_prefix \
        target_dir \
        file_regexes \
        # add var names above this line
}
