# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_more_than_one_argument
declare -rxi err_unknown_argument

# shellcheck disable=SC2154 # variable is referenced but not assigned.
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

            --release-tag|-t )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                release_tag="$1"; shift
                ;;

            --minver-tag-prefix|-p )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --reason|-r )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                reason="$1"; shift
                ;;

            --needs-empty-commit )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for ${option,,}"
                needs_empty_commit="$1"; shift
                ;;

            * )
                usage "$err_unknown_argument" "Unknown argument: $option"
                ;;
        esac
    done
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        dry_run \
        verbose \
        quiet \
        --blank \
        release_tag \
        minver_tag_prefix \
        reason \
        needs_empty_commit \
        --header "other:" \
        ci
}
