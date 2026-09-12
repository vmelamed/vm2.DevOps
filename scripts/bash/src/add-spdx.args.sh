# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_argument_value

declare -x dir
declare -x license

function get_arguments()
{
    local __option
    local value

    while (( $# > 0 )); do
        __option="$1"; shift
        if get_common_arg "$__option"; then
            continue
        fi

        value="$__option"
        __option=${__option,,}
        case "$__option" in
            -l|--license)
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $__option"
                license="$1"
                shift
                ;;

            *)  [[ -z $dir ]] || usage -ec "$err_too_many_arguments" "The directory was already specified - $dir"
                dir="$value"
                ;;
        esac
    done

    dump_vars \
        --graphical \
        --header "Arguments of $script_name:" \
        --core-state \
        dir \
        license \
        "$@"

    usage_if_requested
}
