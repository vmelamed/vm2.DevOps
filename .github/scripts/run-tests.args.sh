# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# core lib exit codes
declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error

# core lib constants
declare -xr ci
declare -xra dump_common_dotnet_args

# this scripts defaults
declare -xri default_min_line_coverage_pct=80
declare -xri default_min_branch_coverage_pct=75
declare -xri default_min_method_coverage_pct=80

# this scripts arguments
declare -x  test_project=${test_project:-"${TEST_PROJECT:-}"}
declare -x  min_coverage_pct=${MIN_COVERAGE_PCT:-"$default_min_line_coverage_pct"}
declare -x  min_branch_coverage_pct=''
declare -x  min_method_coverage_pct=''

function get_arguments()
{
    local _option
    local _positional_arg_set=false

    while (( $# > 0 )); do
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
                (( $# >= 1 ))                                                   || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                min_coverage_pct=$1
                shift
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

            -*) usage -ec "$err_unknown_argument" "Unknown argument: $_option"
                ;;

            * ) ! $_positional_arg_set                                          || usage -ec "$err_too_many_arguments" "Multiple test projects specified: $_option"
                test_project="$_option"
                _positional_arg_set=true
                ;;
        esac
    done

    usage_if_requested
    validate_arguments
    exit_if_has_errors
    dump_args
}

function validate_arguments()
{
    # validate the values of the variables common for many vm2.DevOps scripts,
    # usually set from CLI arguments, environment variables, or defaults
    is_safe_existing_file "$test_project"                                       || true
    [[ $test_project == *.csproj ]]                                             || error "The script '${script_name}' accepts only project files (*.csproj) - not solutions (*.sln or *.slnx)."
    sanitize_common_dotnet_args "$test_project"

    # Unless MIN_BRANCH_COVERAGE_PCT or MIN_METHOD_COVERAGE_PCT is set, derive it from the line coverage. Derive only from a
    # valid line coverage: the arithmetic expansion would evaluate (and run any command substitution in) an invalid one.
    if is_safe_min_coverage_pct "$min_coverage_pct"; then
        if (( min_coverage_pct < 50 )); then                                       error "min-coverage-pct must be between 50-100."
        else
            min_branch_coverage_pct=${MIN_BRANCH_COVERAGE_PCT:-$((min_coverage_pct - 5))}
            min_method_coverage_pct=${MIN_METHOD_COVERAGE_PCT:-$min_coverage_pct}
            is_safe_min_coverage_pct "$min_branch_coverage_pct"                 || true
            is_safe_min_coverage_pct "$min_method_coverage_pct"                 || true
        fi
    fi

    readonly test_project
    readonly min_coverage_pct
    readonly min_branch_coverage_pct
    readonly min_method_coverage_pct

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

        test_project
        min_coverage_pct

        "${dump_common_dotnet_args[@]}"

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
