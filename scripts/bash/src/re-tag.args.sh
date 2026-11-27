# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x script_name
declare -x lib_dir

# vm2 core lib exit codes
declare -x success
declare -x err_missing_argument
declare -x err_argument_value
declare -x err_unknown_argument
declare -x err_logic_error
declare -x err_tool_not_found
declare -x err_too_many_arguments

# vm2 core lib constants
declare -x ci
declare -x git_tags_ns

# vm2 core lib variables
declare -x noise_sink

# this script variables
declare -x delete_mode=false
declare -x del_tag=""
declare -x old_tag=""
declare -x new_tag=""

#-----------------------------------------------------------------------------------------------
# @description Parses the command-line arguments for 're-tag.sh'. Delegates common switches
#   (help, quiet, verbose, trace, dry-run) to 'get_common_arg'. Accepts either '--delete|-d <tag>'
#   (delete mode) or up to two positional arguments, '<old-tag> <new-tag>' (rename mode). A
#   third positional argument is rejected.
#
# @arg $@ string Either '--delete|-d <tag>', or up to two positional arguments '[<old-tag>] [<new-tag>]'.
#
# @exitcode success=0: always.
#
# @example
#   get_arguments v3.1.0-preview.5 v3.1.1-preview.2
# @example
#   get_arguments --delete v3.1.0-preview.4
#-----------------------------------------------------------------------------------------------
function get_arguments()
{
    parse_arguments "$@"
    usage_if_requested
    verify_environment
    exit_if_has_errors  # circuit breaker: is_tag_name in resolve_arguments needs git
    resolve_arguments
    exit_if_has_errors
    dump_args
}

function parse_arguments()
{
    local _option
    local _option_ndx=0

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --delete|-d )
                (( $# > 0 ))                                                    || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                (( _option_ndx == 0 ))                                          || usage "'--delete' takes exactly one tag and cannot be combined with other tags or another '--delete'." -ec "$err_too_many_arguments"
                delete_mode=true
                del_tag=$1; shift
                _option_ndx=2 # do not allow more arguments
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                                                                                   exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            -*)                                                                    usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;

            * ) if (( _option_ndx == 0 )); then
                    old_tag=$_option
                    (( ++_option_ndx ))
                elif (( _option_ndx == 1 )); then
                    new_tag=$_option
                    (( ++_option_ndx ))
                else
                                                                                   usage "Too many arguments: '$_option'." -ec "$err_too_many_arguments"
                fi
                ;;
        esac
    done

    return "$success"
}

function verify_environment
{
    verify_git                                                                  || return "$success"

    git rev-parse --git-dir &>"$noise_sink"                                     || error "$err_logic_error" "The current directory is not a git repository."

    return "$success"
}

function resolve_arguments()
{
    local -i _rc=$success

    if $delete_mode; then
        # test the del tag
        [[ -n $del_tag ]]                                                       || with_error _rc "$err_missing_argument" "Missing required tag to delete argument."
        (( _rc != success )) || is_valid_tag_name "$del_tag"                    || _rc=$?
        (( _rc != success )) || del_tag=${del_tag#"$git_tags_ns"}               # canonicalize by stripping refs/tags/
    else
        # test the old tag
        [[ -n $old_tag ]]                                                       || with_error _rc "$err_missing_argument" "Missing required old tag argument."
        (( _rc != success )) || is_valid_tag_name "$old_tag"                    || _rc=$?
        (( _rc != success )) || old_tag=${old_tag#"$git_tags_ns"}               # canonicalize by stripping refs/tags/

        # test the new tag
        _rc=$success
        [[ -n $new_tag ]]                                                       || with_error _rc "$err_missing_argument" "Missing required new tag argument."
        (( _rc != success )) || is_valid_tag_name "$new_tag"                    || _rc=$?
        (( _rc != success )) || new_tag=${new_tag#"$git_tags_ns"}               # canonicalize by stripping refs/tags/
    fi

    readonly delete_mode
    readonly del_tag
    readonly old_tag
    readonly new_tag

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

        delete_mode
        old_tag
        new_tag
        del_tag

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
