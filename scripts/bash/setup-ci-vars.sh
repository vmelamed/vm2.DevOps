#!/bin/bash
set -euo pipefail

declare -xr this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

source "$script_dir/_common.sh"

# CI Variables that will be passed as environment variables
declare -x matrix_os=${MATRIX_OS:-"ubuntu-latest"}
declare -x dotnet_version=${DOTNET_VERSION:-"9.0.x"}
declare -x configuration=${CONFIGURATION:-"Release"}
declare -x defined_symbols=${DEFINED_SYMBOLS:-}
declare -x build_project=${BUILD_PROJECT:-}
declare -x test_project=${TEST_PROJECT:-}
declare -x benchmark_project=${BENCHMARK_PROJECT:-}
declare -x min_coverage_pct=${MIN_COVERAGE_PCT:-80}
declare -x run_benchmarks=${RUN_BENCHMARKS:-true}
declare -x force_new_baseline=${FORCE_NEW_BASELINE:-false}
declare -x max_regression_pct=${MAX_REGRESSION_PCT:-10}
declare -x verbose=${VERBOSE:-false}

source "$script_dir/setup-ci-vars.usage.sh"
source "$script_dir/setup-ci-vars.utils.sh"

get_arguments "$@"

dump_all_variables

declare -i errors=0

## Shell function to log an error
## Usage: error "Error message"
# shellcheck disable=SC2154
function error()
{
    echo "❌ ERROR $*" | tee >> "$GITHUB_STEP_SUMMARY" >&2
    errors=$((errors + 1))
}

## Shell function to log a warning and set a default value
## Usage: warning variable_name variable_value "Warning message"
function warning()
{
    declare -n variable="$2";
    echo "⚠️ WARNING $4, Assuming $3" | tee >> "$GITHUB_STEP_SUMMARY" >&2
    # shellcheck disable=SC2034
    variable="$3"
    return 1
}

# Validate and set target-os
if ! echo "$matrix_os" | jq . >/dev/null 2>&1; then
    warning matrix_os '["ubuntu-latest"]' "Invalid JSON for target-os."
fi

# Validate and set dotnet-version
if [[ -z "$dotnet_version" ]]; then
    warning dotnet_version "9.0.x" "dotnet-version is empty."
fi

# Set configuration with validation
if [[ "$configuration" != "Release" && "$configuration" != "Debug" ]]; then
    warning configuration "Release" "configuration must be 'Release' or 'Debug'."
fi

if [[ -z "$test_project" ]]; then
    error "test-project cannot be empty"
fi

if [[ -z "$benchmark_project" ]]; then
    error "benchmark-project cannot be empty"
fi

# Validate numeric inputs
if ! [[ "$min_coverage_pct" =~ ^[0-9]+$ ]] || (( min_coverage_pct < 50 || min_coverage_pct > 100 )); then
    warning min_coverage_pct 80 "min-coverage-pct must be 50-100."
fi

# Boolean validations
if [[ "$run_benchmarks" != "true" && "$run_benchmarks" != "false" ]]; then
    warning run_benchmarks "true" "run-benchmarks must be true/false."
fi

if [[ "$force_new_baseline" != "true" && "$force_new_baseline" != "false" ]]; then
    warning force_new_baseline "false" "force-new-baseline must be true/false."
fi

if ! [[ "$max_regression_pct" =~ ^[0-9]+$ ]] || (( max_regression_pct < 0 || max_regression_pct > 50 )); then
    warning max_regression_pct 10 "max-regression-pct must be 0-50."
fi

if [[ "$verbose" != "true" && "$verbose" != "false" ]]; then
    warning verbose "false" "verbose must be true/false."
fi

if (( errors > 0 )); then
    echo "❌ Exiting with $errors error(s). Please fix the issues and try again." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    exit 1
fi

{
    # Log all computed values for debugging
    echo "✔️ All variables validated successfully"
    echo ""
    echo "| Variable           | Value               |"
    echo "|:-------------------|:--------------------|"
    echo "| target-os          | $matrix_os          |"
    echo "| dotnet-version     | $dotnet_version     |"
    echo "| configuration      | $configuration      |"
    echo "| define-symbols     | $defined_symbols    |"
    echo "| build-project      | $build_project      |"
    echo "| test-project       | $test_project       |"
    echo "| min-coverage-pct   | $min_coverage_pct   |"
    echo "| run-benchmarks     | $run_benchmarks     |"
    echo "| benchmark-project  | $benchmark_project  |"
    echo "| force-new-baseline | $force_new_baseline |"
    echo "| max-regression-pct | $max_regression_pct |"
    echo "| verbose            | $verbose            |"
} | tee >> "$GITHUB_STEP_SUMMARY"

# shellcheck disable=SC2154
{
    # Output all variables to GITHUB_OUTPUT for use in subsequent jobs
    echo "target-os=$matrix_os"
    echo "dotnet-version=$dotnet_version"
    echo "configuration=$configuration"
    echo "define-symbols=$defined_symbols"
    echo "build-project=$build_project"
    echo "test-project=$test_project"
    echo "min-coverage-pct=$min_coverage_pct"
    echo "run-benchmarks=$run_benchmarks"
    echo "benchmark-project=$benchmark_project"
    echo "force-new-baseline=$force_new_baseline"
    echo "max-regression-pct=$max_regression_pct"
    echo "verbose=$verbose"
} >> "$GITHUB_OUTPUT"
