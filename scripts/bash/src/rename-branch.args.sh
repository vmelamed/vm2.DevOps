# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x script_name
declare -x lib_dir

# vm2 core lib exit codes
declare -x success
declare -x err_missing_argument
declare -x err_too_many_arguments
declare -x err_unknown_argument
declare -x err_logic_error
declare -x err_tool_not_found
declare -x err_tool_error
declare -x err_argument_value
declare -x err_invalid_repo

# vm2 core lib constants
declare -x ci
declare -x default_default_branch
declare -x git_heads_ns
declare -x git_remotes_ns
declare -x key_default_branch

# vm2 core lib variables
declare -x _ignore

# this script arguments
declare -x old_branch_name=''
declare -x new_branch_name=''

#-----------------------------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------------------------
function get_arguments()
{
    parse_arguments "$@"
    usage_if_requested
    verify_environment
    resolve_arguments
    exit_if_has_errors
    dump_args
}

function parse_arguments()
{
    local _option
    local -i _option_idx=0

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                                                                                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            -*)                                                                 usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;

            * ) if (( _option_idx == 0 )); then
                    new_branch_name=$_option
                    (( ++_option_idx ))
                elif (( _option_idx == 1 )); then
                    old_branch_name=$new_branch_name
                    new_branch_name=$_option
                    (( ++_option_idx ))
                else
                                                                                usage "Too many positional arguments: $_option" -ec "$err_too_many_arguments"
                fi
                ;;
        esac
    done

    return "$success"
}

function verify_environment
{
    # Note: fetch runs directly, not through execute: it only refreshes remote-tracking refs, and the checks below need them fresh, even in a dry run.
    ! is_git_present || git fetch origin 1>"$_ignore"                           || error "Failed to fetch from remote." -ec "$err_tool_error"
    return "$success"
}

function resolve_arguments()
{
    local -i _rc=$success

    [[ -n "$new_branch_name" ]]                                                 || with_error _rc "$err_missing_argument" "No new branch name provided."
    (( _rc != success )) || [[ "$old_branch_name" != "$new_branch_name" ]]      || with_error _rc "$err_argument_value" "The new branch name is the same as the old branch name."

    if is_git_present; then
        # test the new name:
        (( _rc != success )) || is_valid_branch_name "$new_branch_name"         || with_error _rc "$err_argument_value" "Invalid branch name '$new_branch_name'."
        (( _rc != success )) || new_branch_name="${new_branch_name#"$git_heads_ns"}" # canonicalize by stripping refs/heads/

        # Ensure that a local or remote branch with the new name does not exist already:
        (( _rc != success )) || ! git show-ref --verify --quiet "${git_heads_ns}$new_branch_name" \
                                                                                || with_error _rc "$err_argument_value" "Branch '$new_branch_name' already exists locally."
        (( _rc != success )) || ! git show-ref --verify --quiet "${git_remotes_ns}origin/$new_branch_name" \
                                                                                || with_error _rc "$err_argument_value" "Branch '$new_branch_name' already exists on remote."

        # test the old name:
        _rc=$success
        if [[ -n "$old_branch_name" ]]; then
            is_valid_branch_name "$old_branch_name"                             || with_error _rc "$err_argument_value" "Invalid branch name '$old_branch_name'."
            (( _rc != success )) || old_branch_name="${old_branch_name#"$git_heads_ns"}" # canonicalize by stripping refs/heads/
        else
            # Get the current branch name
            old_branch_name=$(git branch --show-current 2>"$_ignore")           || with_error _rc "$err_tool_error" "Failed to get the current branch name."
            (( _rc != success )) || [[ -n $old_branch_name ]]                   || with_error _rc "$err_missing_argument" "HEAD is detached, so there is no current branch to rename. Check out the branch, or pass its name as the second argument."
        fi

        local -A _repo_state
        (( _rc != success )) || get_repo_state "$(git rev-parse --show-toplevel)" _repo_state \
                                                                                || with_error _rc "$err_invalid_repo" "Failed to obtain the default branch name from GitHub."

        (( _rc != success )) || [[ $old_branch_name != "${_repo_state[$key_default_branch]}" ]] \
                                                                                || with_error _rc "$err_argument_value" "Cannot rename the default branch '${_repo_state[$key_default_branch]}'."

        # Check if the old branch exists locally and remotely:
        (( _rc != success )) || git show-ref --verify --quiet "${git_heads_ns}$old_branch_name" &>"$_ignore" \
                                                                                || with_error _rc "$err_argument_value" "Branch '$old_branch_name' does not exist locally."

        (( _rc != success )) || git show-ref --verify --quiet "${git_remotes_ns}origin/$old_branch_name" &>"$_ignore" \
                                                                                || with_error _rc "$err_argument_value" "Branch '$old_branch_name' does not exist remotely."
    fi


    readonly old_branch_name
    readonly new_branch_name

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
