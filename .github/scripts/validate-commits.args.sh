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

declare -x base_ref=""

function get_arguments()
{
    local _option
    local _base_ref_given=false

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue
        case "${_option,,}" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            * ) [[ "$_option" != -* ]] ||
                    usage -ec "$err_unknown_argument" "Unknown argument: $_option"
                ! $_base_ref_given ||
                    usage -ec "$err_too_many_arguments" "Unknown argument: $_option"
                base_ref="$_option"
                _base_ref_given=true
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

        base_ref

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
