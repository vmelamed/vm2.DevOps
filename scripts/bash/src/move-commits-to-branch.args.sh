# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error

declare -xr ci

declare -x _ignore

declare -x commit_sha=""
declare -x new_branch=""
declare -x check_out_new_branch=false
declare -x current_branch

#-----------------------------------------------------------------------------------------------
# @description Parses the command-line arguments for 'move-commits-to-branch.sh'. Delegates common switches (help, quiet,
# verbose, trace, dry-run) to 'get_common_arg'. Recognizes '--commit-sha|-c', '--branch|-b', and '--check-out-new|-n'; any
# other argument is rejected.
#
# @arg $@ string Named options: '--commit-sha|-c <sha>', '--branch|-b <name>', '--check-out-new|-n'.
#
# @exitcode success=0: Arguments parsed successfully.
# @exitcode err_missing_argument: A recognized option is missing its required value.
# @exitcode err_unknown_argument: An unrecognized argument was given.
#
# Note: 'usage_if_requested' exits the process directly (via 'usage') when '--help'/'-h'/'-?' was given; it does not
#   return a code to this function's caller.
#
# @example
#   get_arguments --commit-sha ff5c2d1 --branch feature/my-feature
#-----------------------------------------------------------------------------------------------
function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --branch|-b )
                (( $# >= 1 ))                                                   || usage "Missing branch name after '$_option'." -ec "$err_missing_argument"
                new_branch="$1"; shift
                ;;

            --commit-sha|-c )
                (( $# >= 1 ))                                                   || usage "Missing commit SHA after '$_option'." -ec "$err_missing_argument"
                commit_sha="$1"; shift
                ;;

            --check-out-new|-n )
                check_out_new_branch=true
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                                                                                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            * )                                                                 usage "Unknown argument '$_option'." -ec "$err_unknown_argument"
                ;;
        esac
    done

    usage_if_requested
    validate_environment
    validate_arguments
    exit_if_has_errors
    dump_args
}

function validate_environment()
{
    # Verify we're on main branch
    current_branch=$(git branch --show-current)
    [[ "$current_branch" == "main" ]]                                           || error "You must be on the 'main' branch. Currently on '$current_branch'" -ec "$err_argument_value"

    # Verify we don't have uncommitted changes
    git diff-index --quiet HEAD --                                              || error "You have uncommitted changes. Please commit or stash them first." -ec "$err_logic_error"
}

function validate_arguments()
{
    local -i _rc=$success

    # validate we have a valid branch name != main
    is_valid_branch_name "$new_branch"                                          || with_error _rc "$err_argument_value" "The option '--branch' is mandatory and must have a valid value"
    (( _rc != success )) || [[ "$new_branch" != "main" ]]                       || error "The new branch name cannot be 'main'" -ec "$err_argument_value"

    # Verify we have a valid and existing SHA
    _rc=$success
    is_valid_commit_sha "$commit_sha"                                           || with_error _rc "$err_argument_value" "The '--commit-sha' is mandatory and  must be a valid 7 to 40 hexadecimal digits string"
    (( _rc != success )) || git cat-file -e "$commit_sha^{commit}" 2>"$_ignore" || error "Commit '$commit_sha' does not exist" -ec "$err_argument_value"

    # freeze the arguments
    readonly new_branch
    readonly commit_sha
    readonly check_out_new_branch
    readonly current_branch

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

        current_branch
        new_branch
        commit_sha
        check_out_new_branch

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
