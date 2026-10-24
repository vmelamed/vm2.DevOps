# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_argument_value
declare -xri err_logic_error

declare -xr ci

declare -x dir
declare -x license

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case ${_option,,} in
            -l|--license)
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                license="$1"
                shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            *)  [[ -z $dir ]] || usage -ec "$err_too_many_arguments" "The directory was already specified - $dir"
                dir="$_option"
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

        dir
        license

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
