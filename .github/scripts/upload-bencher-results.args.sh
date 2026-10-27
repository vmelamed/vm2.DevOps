# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# reference error codes defined in the core library
declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_tool_not_found

declare -xr ci
declare -x _ignore

declare -xr key_repo

declare -xri default_max_regression_pct=20
declare -xri default_max_gen1_collects=2
declare -xri default_max_gen2_collects=1

# parameters specific to this script only with initial values from environment variables or defaults
declare -x results_dir=${RESULTS_DIR:-}
declare -x testbed=${TESTBED:-}
declare -x repository=${REPOSITORY:-"${GITHUB_REPOSITORY:-}"}
declare -x event_name=${EVENT_NAME:-"${GITHUB_EVENT_NAME:-}"}
declare -x ref_name=${REF_NAME:-"${GITHUB_REF_NAME:-}"}
declare -x head_ref=${HEAD_REF:-"${GITHUB_HEAD_REF:-}"}
declare -x pr_number=${PR_NUMBER:-}
declare -x pr_base_sha=${PR_BASE_SHA:-}
declare -x max_regression_pct=${MAX_REGRESSION_PCT:-"$default_max_regression_pct"}
declare -x max_gen1_collects=${MAX_GEN1_COLLECTS:-"$default_max_gen1_collects"}
declare -x max_gen2_collects=${MAX_GEN2_COLLECTS:-"$default_max_gen2_collects"}
declare -x reset_thresholds=${RESET_THRESHOLDS:-false}

declare -x BENCHER_API_TOKEN

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"
        shift
        get_common_arg "${_option,,}" && continue

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

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            * ) [[ -z $results_dir ]] || usage -ec "$err_too_many_arguments" "Multiple results directories specified. Unknown option: $_option"
                results_dir="$_option"
                ;;
        esac
    done

    usage_if_requested
    verify_environment
    validate_arguments
    exit_if_has_errors
    dump_args
}

function validate_arguments()
{
    # Sensible standalone defaults for GitHub-context values that otherwise only exist automatically
    # inside GitHub Actions -- every vm2.DevOps CI script must also run cleanly from a developer
    # machine, so fall back to the local git remote/branch instead of forcing these to be typed in.
    [[ -n $event_name ]] || event_name="push"
    [[ -n $testbed ]]    || testbed="local"

    if [[ -z $repository ]]; then
        declare _repo_root
        _repo_root=$(git rev-parse --show-toplevel 2>"$_ignore") || true
        if [[ -n ${_repo_root:-} ]]; then
            declare -A _repo_state=()
            get_repo_state "$_repo_root" _repo_state false || true
            repository=${_repo_state[$key_repo]:-}
        fi
    fi

    [[ -n $ref_name ]] || ref_name=$(git branch --show-current 2>"$_ignore") || true

    # validate the values of the variables. results_dir is NOT run through is_safe_path/is_safe_existing_path: those
    # reject absolute paths by design (the framework's convention for user-facing --artifacts-path-style inputs), but
    # this value is an internal, already-resolved absolute path handed off from run-benchmarks.sh's own output, not a
    # raw CLI/env path a caller is expected to type in relative form.
    [[ -n $results_dir ]]                               || error -ec "$err_missing_argument" "The results directory is required."
    [[ -z $results_dir || -d $results_dir ]]            || error -ec "$err_argument_value" "The results directory '$results_dir' is not a directory."
    [[ -n $testbed ]]                                   || error -ec "$err_missing_argument" "--testbed is required."
    [[ $repository == */* ]]                            || error -ec "$err_argument_value" "--repository must be in 'owner/repo' form (provided '${repository:-<empty>}')."
    [[ -n $event_name ]]                                || error -ec "$err_missing_argument" "--event-name is required."
    [[ -n $ref_name ]]                                  || error -ec "$err_missing_argument" "--ref-name is required."
    is_safe_max_regression_pct "$max_regression_pct"    || true
    is_non_negative "$max_gen1_collects"                || error -ec "$err_argument_value" "--max-gen1-collects must be a non-negative integer (got '$max_gen1_collects')."
    is_non_negative "$max_gen2_collects"                || error -ec "$err_argument_value" "--max-gen2-collects must be a non-negative integer (got '$max_gen2_collects')."
    is_safe_boolean "$reset_thresholds"                 || true

    if [[ $event_name == "pull_request" ]]; then
        [[ -n $head_ref ]]                              || error -ec "$err_missing_argument" "--head-ref is required when --event-name is 'pull_request'."
        [[ -n $pr_number ]]                             || error -ec "$err_missing_argument" "--pr-number is required when --event-name is 'pull_request'."
        [[ -n $pr_base_sha ]]                           || error -ec "$err_missing_argument" "--pr-base-sha is required when --event-name is 'pull_request'."
        [[ -n ${GH_TOKEN:-} ]]                          || error -ec "$err_missing_argument" "The GH_TOKEN environment variable is required when --event-name is 'pull_request'."
    fi

    # freeze the parameters
    readonly results_dir
    readonly testbed
    readonly repository
    readonly event_name
    readonly ref_name
    readonly head_ref
    readonly pr_number
    readonly pr_base_sha
    readonly max_regression_pct
    readonly max_gen1_collects
    readonly max_gen2_collects
    readonly reset_thresholds

    return "$success"
}

function verify_environment()
{
    [[ -n ${BENCHER_API_TOKEN:-} ]]                     || error -ec "$err_missing_argument" "The BENCHER_API_TOKEN environment variable is required."

    is_tool_present bc &> "$_ignore"                    || error -ec "$err_tool_not_found" "'bc' is not installed. Please install it first."
    is_tool_present bencher &> "$_ignore"               || error -ec "$err_tool_not_found" "'bencher' is not installed. Please install it first."
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
