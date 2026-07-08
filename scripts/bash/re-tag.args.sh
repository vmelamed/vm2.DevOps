# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_unknown_argument

declare -x delete_mode
declare -x del_tag
declare -x old_tag
declare -x new_tag

#-------------------------------------------------------------------------------
# @description Dumps the current values of the script's argument variables (common switches plus the delete-mode flag and
# the old/new/delete tag names) for diagnostics.
#
# @exitcode 0 Always.
#
# @stdout A tabular dump of the script's argument variables (suppressed if '--quiet' is in effect — see 'dump_vars').
#-------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------
# @description Parses the command-line arguments for 're-tag.sh'. Delegates common switches (help, quiet, verbose, trace,
# dry-run) to 'get_common_arg'. Accepts either '--delete|-d <tag>' (delete mode) or up to two positional arguments,
# '<old-tag> <new-tag>' (rename mode). A third positional argument is rejected.
#
# @arg $@ string Either '--delete|-d <tag>', or up to two positional arguments '[<old-tag>] [<new-tag>]'.
#
# @exitcode 0 Arguments parsed successfully.
# @exitcode non-zero '--delete' was given without a following tag value, or combined with an already-parsed '<old-tag>'
#   ('err_missing_argument'); a third positional argument was given; or help was requested (via 'usage_if_requested').
#
# @example
#   get_arguments v3.1.0-preview.5 v3.1.1-preview.2
# @example
#   get_arguments --delete v3.1.0-preview.4
#-------------------------------------------------------------------------------
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
                else usage -c "$err_unknown_argument" "Unknown argument: $option"
                fi
                ;;
        esac
    done
    usage_if_requested
    dump_all_variables
}
