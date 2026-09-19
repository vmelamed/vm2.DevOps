# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# reference error codes defined in the core library
declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

declare -x ci

# parameters specific to this script only with initial values from environment variables or defaults
declare -x results_dir
declare -x testbed
declare -x repository
declare -x event_name
declare -x ref_name
declare -x head_ref
declare -x pr_number
declare -x pr_base_sha
declare -xi max_regression_pct
declare -xi max_gen1_collects
declare -xi max_gen2_collects
declare -x reset_thresholds

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"
        shift

        get_common_arg "${_option,,}" &&
            continue

        case "${_option,,}" in
            --testbed )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                testbed="$1"
                shift
                ;;

            --repository )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                repository="$1"
                shift
                ;;

            --event-name )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                event_name="$1"
                shift
                ;;

            --ref-name )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                ref_name="$1"
                shift
                ;;

            --head-ref )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                head_ref="$1"
                shift
                ;;

            --pr-number )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                pr_number="$1"
                shift
                ;;

            --pr-base-sha )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                pr_base_sha="$1"
                shift
                ;;

            --max-regression-pct )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                max_regression_pct="$1"
                shift
                ;;

            --max-gen1-collects )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                max_gen1_collects="$1"
                shift
                ;;

            --max-gen2-collects )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                max_gen2_collects="$1"
                shift
                ;;

            --reset-thresholds )
                (( $# > 0 )) || usage -ec "$err_missing_argument" "Missing boolean value for ${_option,,}"
                reset_thresholds="$1"
                shift
                ;;

            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                ;;

            * ) [[ -z $results_dir ]] || usage -ec "$err_too_many_arguments" "Multiple results directories specified. Unknown option: $_option"
                [[ "$_option" != -* ]] || usage -ec "$err_unknown_argument" "Unknown option: $_option"
                results_dir="$_option"
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

        results_dir
        testbed
        repository
        event_name
        ref_name
        head_ref
        pr_number
        pr_base_sha
        max_regression_pct
        max_gen1_collects
        max_gen2_collects
        reset_thresholds

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
