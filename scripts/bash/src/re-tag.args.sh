# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri success
declare -xri err_missing_argument
declare -xri err_unknown_argument
declare -xri err_logic_error

declare -xr ci

declare -x delete_mode
declare -x del_tag
declare -x old_tag
declare -x new_tag

#---------------------------------------------------------------------------------------------
# @description Parses the command-line arguments for 're-tag.sh'. Delegates common switches (help, quiet, verbose, trace,
# dry-run) to 'get_common_arg'. Accepts either '--delete|-d <tag>' (delete mode) or up to two positional arguments,
# '<old-tag> <new-tag>' (rename mode). A third positional argument is rejected.
#
# @arg $@ string Either '--delete|-d <tag>', or up to two positional arguments '[<old-tag>] [<new-tag>]'.
#
# @exitcode success=0: Arguments parsed successfully.
# @exitcode err_missing_argument: '--delete' was given without a following tag value, or combined with an
#   already-parsed '<old-tag>'.
# @exitcode err_unknown_argument: A third positional argument was given.
#
# Note: 'usage_if_requested' exits the process directly (via 'usage') when '--help'/'-h'/'-?' was given; it does
#   not return a code to this function's caller.
#
# @example
#   get_arguments v3.1.0-preview.5 v3.1.1-preview.2
# @example
#   get_arguments --delete v3.1.0-preview.4
#---------------------------------------------------------------------------------------------
function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --delete|-d )
                [[ $# -ge 1 && -z "$old_tag" ]] || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                delete_mode=true
                del_tag="$1"; shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            * )
                if   [[ -z "$old_tag" ]]; then old_tag="$_option"
                elif [[ -z "$new_tag" ]]; then new_tag="$_option"
                else usage -ec "$err_unknown_argument" "Unknown argument: $_option"
                fi
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

        delete_mode
        old_tag
        new_tag
        del_tag

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
