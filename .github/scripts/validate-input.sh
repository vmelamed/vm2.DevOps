#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following
source "$lib_dir/gh_core.sh"

# Error code constants (defined in _error_codes.sh, re-declared here so ShellCheck sees them in scope)
declare -xri err_argument_value
declare -xri err_tool_not_found

# Declare variables defined in the core library.
declare -x _ignore
declare -x common_dotnet_args_to_output

# Define CI common variables passed in as common CI arguments
declare -x preprocessor_symbols
# declare -x configuration
# declare -x framework
# declare -x runtime
# declare -x artifacts
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password

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
declare -r defaultSkipBenchmarks=false
declare -r defaultSkipTests=false
declare -r defaultSkipPackages=false

# CI Variables that will be passed as environment variables
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
declare -x skip_benchmarks=${SKIP_BENCHMARKS:-$defaultSkipBenchmarks}
declare -x skip_tests=${SKIP_TESTS:-$defaultSkipTests}
declare -x skip_packages=${SKIP_PACKAGES:-$defaultSkipPackages}

source "$script_dir/validate-input.usage.sh"
source "$script_dir/validate-input.args.sh"

get_arguments "$@"
! is_verbose || dump_args "--force"

# Check for required dependencies (jq and gh) and attempt to install them if not found
if ! command -v -p jq &> "$_ignore"; then
    if execute sudo apt-get update && sudo apt-get install -y jq; then
        info "GitHub CLI 'jq' successfully installed."
    else
        error -ec "$err_tool_not_found" "GitHub CLI 'jq' was not found and could not install it. Please have 'jq' installed."
    fi
else
    jq -V | to_stdout | grep -Eo 'jq-1\.8\.[0-9]+' &> "$_ignore" || {
        warning "GitHub CLI 'jq' version 1.8.x is required. Upgrading 'jq' to version 1.8.2..."
        curl -sLo /tmp/jq https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64
        sudo install /tmp/jq /usr/local/bin/jq
        jq -V | to_stdout | grep -Eo 'jq-1\.8\.[0-9]+' &> "$_ignore" || {
            error -ec "$err_tool_not_found" "GitHub CLI 'jq' version 1.8.x is required. Please update 'jq' to version 1.8.x."
        }
    }
fi
if ! command -v -p gh &> "$_ignore"; then
    if execute sudo apt-get update && sudo apt-get install -y gh; then
        info "GitHub CLI 'gh' successfully installed."
    else
        error -ec "$err_tool_not_found" "GitHub CLI 'gh' was not found and could not install it. Please have 'gh' installed."
    fi
fi

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
    error -ec "$err_argument_value" "max-gen1-collects must be a non-negative integer (got '$max_gen1_collects')."
is_safe_integer "$max_gen2_collects"                                                                             || true
(( max_gen2_collects >= 0 )) ||
    error -ec "$err_argument_value" "max-gen2-collects must be a non-negative integer (got '$max_gen2_collects')."

is_safe_boolean "$reset_benchmark_thresholds"                                                                    || true
is_safe_boolean "$skip_benchmarks"                                                                               || true
is_safe_boolean "$skip_tests"                                                                                    || true
is_safe_boolean "$skip_packages"                                                                                 || true
sanitize_common_dotnet_args "$(jq -r '.[0] // "."' <<< "$build_projects")"                                       || true

$ci && _table_fmt="--markdown" || _table_fmt="--graphical"

declare -ra dump_vars_args=(
    --quiet
    --force
    "$_table_fmt"
    --header "Validated Parameters"
    --header "Hosts:"
    runners_os
    --header "Projects:"
    build_projects
    test_projects
    benchmark_projects
    package_projects
    --header "\`dotnet <command>\` CLI Arguments:"
    --common-dotnet-args
    --header "Coverage and Regression Parameters:"
    min_coverage_pct
    max_regression_pct
    max_gen1_collects
    max_gen2_collects
    --line
    reset_benchmark_thresholds
    skip_benchmarks
    skip_tests
    skip_packages
    --header "Core State:"
    --core-state
)

dump_vars "${dump_vars_args[@]}" | to_summary

exit_if_has_errors
info "✅ All parameters validated successfully"

# Output all variables to GITHUB_OUTPUT for use in subsequent jobs
args_to_github_output \
    build_projects \
    test_projects \
    benchmark_projects \
    package_projects \
    runners_os \
    min_coverage_pct \
    max_regression_pct \
    max_gen1_collects \
    max_gen2_collects \
    reset_benchmark_thresholds \
    skip_benchmarks \
    skip_tests \
    skip_packages \
    "${common_dotnet_args_to_output[@]}"
