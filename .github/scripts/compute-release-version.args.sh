# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# vm2 core lib exit codes
declare -xri success
declare -xri err_missing_argument
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_tool_not_found

# vm2 core lib constants
declare -xr ci

# vm2 core lib defaults
declare -xr default_minver_tag_prefix

# this scripts arguments
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x reason=${REASON:-"release build"}

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

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --minver-tag-prefix|-mp )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                minver_tag_prefix="$1"; shift
                ;;

            --reason|-r )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                reason="$1"; shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            * ) usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;
        esac
    done

    return "$success"
}

function verify_environment
{
    is_git_present                                                              || true

    return "$success"
}

function resolve_arguments()
{
    # Sanitize inputs to prevent injection attacks
    validate_minver_tag_components "$minver_tag_prefix"                         || true
    is_safe_reason "$reason"                                                    || true

    readonly minver_tag_prefix
    readonly reason

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

        minver_tag_prefix
        reason

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
