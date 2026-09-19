# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

declare -x ci

declare -x commit_sha
declare -x new_branch
declare -x check_out_new_branch

#---------------------------------------------------------------------------------------------
# @description Parses the command-line arguments for 'move-commits-to-branch.sh'. Delegates common switches (help, quiet,
# verbose, trace, dry-run) to 'get_common_arg'. Recognizes '--commit-sha|-c', '--branch|-b', and '--check-out-new|-n'; any
# other argument is rejected.
#
# @arg $@ string Named options: '--commit-sha|-c <sha>', '--branch|-b <name>', '--check-out-new|-n'.
#
# @exitcode success/positive=0: Arguments parsed successfully.
# @exitcode non-zero A recognized option is missing its required value ('err_missing_argument'), an unrecognized argument
#   was given ('err_unknown_argument'), or help was requested (via 'usage_if_requested').
#
# @example
#   get_arguments --commit-sha ff5c2d1 --branch feature/my-feature
#---------------------------------------------------------------------------------------------
function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --branch|-b )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing branch name after '$_option'."
                new_branch="$1"; shift
                ;;

            --commit-sha|-c )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing commit SHA after '$_option'."
                commit_sha="$1"; shift
                ;;

            --check-out-new|-n )
                check_out_new_branch=true
                ;;

            * )
                usage -ec "$err_unknown_argument" "Unknown argument '$_option'."
                ;;
        esac
    done

    dump_args

    usage_if_requested
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        new_branch
        commit_sha
        check_out_new_branch

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
