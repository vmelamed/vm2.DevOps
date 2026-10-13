# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error

declare -xr ci

# parameters specific to this script only with initial values from environment variables or defaults
declare -x test_project
declare -xi min_coverage_pct
declare -xi min_branch_coverage_pct

declare -xra dump_common_dotnet_args

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        # get the option and convert it to lower case
        _option="$1"
        shift
        get_common_arg "${_option,,}" && continue

        get_common_dotnet_arg "$_option" "${1:-}" && {
            (( $# >= 1 )) && shift
            continue
        }

        case "${_option,,}" in
            # get the arguments specific to this script
            --min-coverage-pct|-min )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                min_coverage_pct=$1
                shift
                min_coverage_pct=$((min_coverage_pct + 0))  # ensure it's an integer
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            # reserved: the options get_common_dotnet_arg consumes before this case (see the arm above).
            -c|-d|-tfm|-rid|--define|--configuration|--framework|--runtime|--artifacts-path|--minver-tag-prefix|--minver-prerelease-id|--nuget-username|--nuget-password )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_dotnet_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            * ) [[ -z $test_project ]] || usage -sd 3 -ec "$err_too_many_arguments" "Multiple test projects specified. Unknown option: $_option"
                test_project="$_option"
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

        test_project
        min_coverage_pct

        "${dump_common_dotnet_args[@]}"

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
