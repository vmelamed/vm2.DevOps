# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

#---------------------------------------------------------------------------------------------
# @description Parses the command-line arguments for 'rename-branch.sh'. Delegates common switches (help, quiet, verbose,
# trace, dry-run) to 'get_common_arg'. Accepts up to two positional arguments: if one positional argument is given, it is
# taken as the new branch name; if two are given, the first is the old branch name and the second is the new branch name.
# A third positional argument is an error.
#
# @arg $@ string Up to two positional arguments: '[<old_branch_name>] <new_branch_name>'.
#
# @exitcode success/positive=0: Arguments parsed successfully.
# @exitcode non-zero A third positional argument was given ('err_too_many_arguments'), or help was requested (via
#   'usage_if_requested').
#
# @example
#   get_arguments feature/new-name
# @example
#   get_arguments feature/old-name feature/new-name
#---------------------------------------------------------------------------------------------
function get_arguments()
{
    local _option

    while [[ $# -gt 0 ]]; do
        _option="$1"; shift
        get_common_arg "$_option" && continue
        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            * ) if [[ -z "$new_branch_name" ]]; then
                    new_branch_name="$_option"
                elif [[ -z "$old_branch_name" ]]; then
                    old_branch_name="$new_branch_name"
                    new_branch_name="$_option"
                else
                    usage -ec "$err_too_many_arguments" "Too many positional arguments: $_option"
                fi
                ;;
        esac
    done
    dump_vars \
        --header "Arguments for $script_name:" \
        --core-state \
        old_branch_name \
        new_branch_name
        # add var names above this line
    usage_if_requested
}
