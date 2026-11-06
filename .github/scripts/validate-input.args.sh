# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# core lib exit codes
declare -xri success
declare -xri err_missing_argument
declare -xri err_argument_value
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_tool_not_found

# core lib constants
declare -xr ci
declare -xra dump_common_dotnet_args

# core lib variables
declare -x _ignore

# this scripts argument defaults
declare -r defaultBuildProjects='[]'
declare -r defaultTestProjects='[]'
declare -r defaultBenchmarkProjects='[]'
declare -r defaultPackageProjects='[]'
declare -r defaultRunnersOs='["ubuntu-latest"]'
declare -r defaultMinCoveragePct=80
declare -r defaultMaxRegressionPct=20
declare -r defaultMaxGen1Collects=2
declare -r defaultMaxGen2Collects=1
declare -r defaultResetBenchmarkThresholds=false
declare -r defaultSkipTests=false
declare -r defaultSkipBuild=false
declare -r defaultSkipBenchmarks=false
declare -r defaultSkipPackages=false

# this scripts arguments
declare -x build_projects=${BUILD_PROJECTS:-$defaultBuildProjects}
declare -x test_projects=${TEST_PROJECTS:-$defaultTestProjects}
declare -x benchmark_projects=${BENCHMARK_PROJECTS:-$defaultBenchmarkProjects}
declare -x package_projects=${PACKAGE_PROJECTS:-$defaultPackageProjects}
declare -x runners_os=${RUNNERS_OS:-$defaultRunnersOs}
declare -x min_coverage_pct=${MIN_COVERAGE_PCT:-$defaultMinCoveragePct}
declare -x max_regression_pct=${MAX_REGRESSION_PCT:-$defaultMaxRegressionPct}
declare -x max_gen1_collects=${MAX_GEN1_COLLECTS:-$defaultMaxGen1Collects}
declare -x max_gen2_collects=${MAX_GEN2_COLLECTS:-$defaultMaxGen2Collects}
declare -x reset_benchmark_thresholds=${RESET_BENCHMARK_THRESHOLDS:-$defaultResetBenchmarkThresholds}
declare -x skip_build=${SKIP_BUILD:-$defaultSkipBuild}
declare -x skip_tests=${SKIP_TESTS:-$defaultSkipTests}
declare -x skip_benchmarks=${SKIP_BENCHMARKS:-$defaultSkipBenchmarks}
declare -x skip_packages=${SKIP_PACKAGES:-$defaultSkipPackages}

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"
        shift

        get_common_arg "$_option" &&
            continue

        get_common_dotnet_arg "$_option" "${1:-}" && {
            (( $# >= 1 )) && shift
            continue
        }

        case "${_option,,}" in
            --build-projects|-bp )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                build_projects="$1"
                shift
                ;;

            --test-projects|-tp )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                test_projects="$1"
                shift
                ;;

            --benchmark-projects|-bmp )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                benchmark_projects="$1"
                shift
                ;;

            --package-projects|-pp )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                package_projects="$1"
                shift
                ;;

            --runners-os|-os )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                runners_os="$1"
                shift
                ;;

            --min-coverage-pct|-min )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                min_coverage_pct="$1"
                shift
                ;;

            --max-regression-pct|-max )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                max_regression_pct="$1"
                shift
                ;;

            --max-gen1-collects|-g1 )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                max_gen1_collects="$1"
                shift
                ;;

            --max-gen2-collects|-g2 )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                max_gen2_collects="$1"
                shift
                ;;

            --reset-benchmark-thresholds|-rt )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                reset_benchmark_thresholds="$1"
                shift;
                ;;

            --skip-build|-sb )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                skip_build="$1"
                shift;
                ;;

            --skip-tests|-st )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                skip_tests="$1"
                shift;
                ;;

            --skip-benchmarks|-sbm )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                skip_benchmarks="$1"
                shift;
                ;;

            --skip-packages|-sp )
                (( $# >= 1 )) || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                skip_packages="$1"
                shift;
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            # reserved: the options get_common_dotnet_arg consumes before this case (see the arm above).
            -c|-d|-tfm|-rid|--define|--configuration|--framework|--runtime|--artifacts-path|--minver-tag-prefix|--minver-prerelease-id|--nuget-username|--nuget-password )
                exit_with_bug "'$_option' should have been consumed by get_common_dotnet_arg." -ec "$err_logic_error"
                ;;

            * ) usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;
        esac
    done

    usage_if_requested
    validate_environment
    validate_arguments
    exit_if_has_errors
    dump_args
}

function validate_environment()
{
    # Check for required dependencies (jq and gh) and attempt to install them if not found
    if ! is_tool_present jq; then
        if execute sudo apt-get update && sudo apt-get install -y jq; then
            info "GitHub CLI 'jq' successfully installed."
        else
            error "GitHub CLI 'jq' was not found and could not install it. Please have 'jq' installed." -ec "$err_tool_not_found"
        fi
    else
        jq -V | to_stdout | grep -Eo 'jq-1\.8\.[0-9]+' &> "$_ignore" || {
            warning "GitHub CLI 'jq' version 1.8.x is required. Upgrading 'jq' to version 1.8.2..."
            curl -sLo /tmp/jq https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64
            sudo install /tmp/jq /usr/local/bin/jq
            jq -V | to_stdout | grep -Eo 'jq-1\.8\.[0-9]+' &> "$_ignore" || {
                error "GitHub CLI 'jq' version 1.8.x is required. Please update 'jq' to version 1.8.x." -ec "$err_tool_not_found"
            }
        }
    fi
    if ! is_tool_present gh; then
        if execute sudo apt-get update && sudo apt-get install -y gh; then
            info "GitHub CLI 'gh' successfully installed."
        else
            error "GitHub CLI 'gh' was not found and could not install it. Please have 'gh' installed." -ec "$err_tool_not_found"
        fi
    fi
    return "$success"
}

function validate_arguments()
{
    #   Build-projects may freely mix individual project paths and solution files: the build matrix
    #   (_ci.yaml/_build.yaml) fans out over whatever's in this array as-is, one leg per entry,
    #   whether that's a whole solution or a single project. A solution build now correctly resolves
    #   Configuration in CI via Directory.Solution.props (see that file's own comment for why a
    #   solution-level `dotnet build` used to silently resolve Configuration to "Debug" regardless of
    #   Directory.Build.props's IsCI-conditioned default), so expanding a solution into its
    #   constituent projects here is no longer necessary to work around that bug -- it's now purely
    #   an opt-in choice a consumer repo's own CI.yaml can make (via expand_solution_projects(), kept
    #   in _dotnet.sh) for finer-grained parallel matrix legs, not something vm2.DevOps forces.
    validate_json_array build_projects "$defaultBuildProjects" is_safe_existing_file                                 || true
    validate_json_array test_projects "$defaultTestProjects" is_safe_existing_file                                   || true
    validate_json_array benchmark_projects "$defaultBenchmarkProjects" is_safe_existing_file                         || true
    validate_json_array package_projects "$defaultPackageProjects" is_safe_existing_file                             || true
    validate_json_array runners_os "$defaultRunnersOs" is_safe_runner_os                                             || true

    is_safe_min_coverage_pct "$min_coverage_pct"                                                                     || true
    (( min_coverage_pct >= 50 && min_coverage_pct <= 100 )) ||
        warning_var min_coverage_pct "min-coverage-pct must be between 50-100." "$defaultMinCoveragePct"

    is_safe_max_regression_pct "$max_regression_pct"                                                                 || true
    (( max_regression_pct >= 0 && max_regression_pct <= 50 )) ||
        warning_var max_regression_pct "max-regression-pct must be between 0-50." "$defaultMaxRegressionPct"

    is_safe_integer "$max_gen1_collects"                                                                             || true
    (( max_gen1_collects >= 0 )) ||
        error "max-gen1-collects must be a non-negative integer (got '$max_gen1_collects')." -ec "$err_argument_value"

    is_safe_integer "$max_gen2_collects"                                                                             || true
    (( max_gen2_collects >= 0 )) ||
        error "max-gen2-collects must be a non-negative integer (got '$max_gen2_collects')." -ec "$err_argument_value"

    is_safe_boolean "$reset_benchmark_thresholds"                                                                    || true
    is_safe_boolean "$skip_build"                                                                                    || true
    is_safe_boolean "$skip_tests"                                                                                    || true
    is_safe_boolean "$skip_benchmarks"                                                                               || true
    is_safe_boolean "$skip_packages"                                                                                 || true

    # Find first valid project file (if any)
    declare -a all_projects
    readarray -t all_projects < <(jq -rn --argjson b "$build_projects" \
                                        --argjson t "$test_projects" \
                                        --argjson m "$benchmark_projects" \
                                        --argjson p "$package_projects" \
                                        '($b + $t + $m + $p)[]' 2>"$_ignore")

    declare candidate=''

    for candidate in "${all_projects[@]}"; do
        [[ -f $candidate ]] && break
        candidate=''
    done

    [[ -z $candidate ]] || sanitize_common_dotnet_args "$candidate"
    #  TODO: add validation here
    return "$success"
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    declare table_fmt
    $ci && table_fmt="--markdown" || table_fmt="--graphical"

    declare -ra dump_vars_args=(
        --quiet
        --force
        "$table_fmt"
        --gh-escape
        --header "Validated Parameters"
        --header "Hosts:"
        runners_os
        --header "Projects:"
        build_projects
        test_projects
        benchmark_projects
        package_projects
        "${dump_common_dotnet_args[@]}"
        --header "Coverage and Regression Parameters:"
        min_coverage_pct
        max_regression_pct
        max_gen1_collects
        max_gen2_collects
        --line
        reset_benchmark_thresholds
        skip_build
        skip_tests
        skip_benchmarks
        skip_packages
        --header "Core State:"
        --core-state
    )

    dump_vars "${dump_vars_args[@]}" | to_summary
}
