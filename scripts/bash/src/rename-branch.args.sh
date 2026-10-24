# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error

declare -xr ci

#---------------------------------------------------------------------------------------------
# @description Parses the command-line arguments for 'rename-branch.sh'. Delegates common switches (help, quiet, verbose,
# trace, dry-run) to 'get_common_arg'. Accepts up to two positional arguments: if one positional argument is given, it is
# taken as the new branch name; if two are given, the first is the old branch name and the second is the new branch name.
# A third positional argument is an error.
#
# @arg $@ string Up to two positional arguments: '[<old_branch_name>] <new_branch_name>'.
#
# @exitcode success=0: Arguments parsed successfully.
# @exitcode err_too_many_arguments: A third positional argument was given.
#
# Note: 'usage_if_requested' exits the process directly (via 'usage') when '--help'/'-h'/'-?' was given; it does
#   not return a code to this function's caller.
#
# @example
#   get_arguments feature/new-name
# @example
#   get_arguments feature/old-name feature/new-name
#---------------------------------------------------------------------------------------------
function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
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

    usage_if_requested
    validate_arguments
    dump_args
}

function validate_arguments()
{
    #  TODO: add validation here
    return "$success"
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        old_branch_name
        new_branch_name

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
