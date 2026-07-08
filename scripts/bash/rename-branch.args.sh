# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

#-------------------------------------------------------------------------------
# @description Parses the command-line arguments for 'rename-branch.sh'. Delegates common switches (help, quiet, verbose,
# trace, dry-run) to 'get_common_arg'. Accepts up to two positional arguments: if one positional argument is given, it is
# taken as the new branch name; if two are given, the first is the old branch name and the second is the new branch name.
# A third positional argument is an error.
#
# @arg $@ string Up to two positional arguments: '[<old_branch_name>] <new_branch_name>'.
#
# @exitcode 0 Arguments parsed successfully.
# @exitcode non-zero A third positional argument was given ('err_too_many_arguments'), or help was requested (via
#   'usage_if_requested').
#
# @example
#   get_arguments feature/new-name
# @example
#   get_arguments feature/old-name feature/new-name
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

            * ) if [[ -z "$new_branch_name" ]]; then
                    new_branch_name="$option"
                elif [[ -z "$old_branch_name" ]]; then
                    old_branch_name="$new_branch_name"
                    new_branch_name="$option"
                else
                    usage -ec "$err_too_many_arguments" "Too many positional arguments: $option"
                fi
                ;;
        esac
    done
    usage_if_requested
}

#-------------------------------------------------------------------------------
# @description Dumps the current values of the script's argument variables (common switches plus the old and new branch
# names) for diagnostics.
#
# @exitcode 0 Always.
#
# @stdout A tabular dump of the script's argument variables (suppressed if '--quiet' is in effect — see 'dump_vars').
#-------------------------------------------------------------------------------
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
