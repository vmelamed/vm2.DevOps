#!/bin/bash
set -euo pipefail

# ==============================================================================
# This script validates and sets up CI variables for GitHub Actions workflows.
# It validates all input variables and outputs them to GITHUB_OUTPUT for use by
# subsequent workflow jobs.
# ==============================================================================

declare -xr this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

source "$script_dir/_common.sh"

# CI Variables that will be passed as environment variables
declare -x build_project=${BUILD_PROJECT:-}
declare -x test_project=${TEST_PROJECT:-}
declare -x benchmark_project=${BENCHMARK_PROJECT:-}
declare -x os=${OS:-"ubuntu-latest"}
declare -x dotnet_version=${DOTNET_VERSION:-"10.0.x"}
declare -x configuration=${CONFIGURATION:-"Release"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x min_coverage_pct=${MIN_COVERAGE_PCT:-80}
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
## Usage: warning variable_default_name "Warning message" variable_assumed_value
function warning()
{
    declare -n variable="$1";
    echo "⚠️ WARNING '$2', Assuming '$3'" | tee >> "$GITHUB_STEP_SUMMARY" >&2
    # shellcheck disable=SC2034
    variable="$3"
    return 1
}

if [[ -z "$build_project" ]]; then
    # Find the first solution file (.slnx or .sln) or project file (.csproj)

    declare solutionOrProject=""

    # this is what `dotnet build` does if no project/solution is not specified, anyway - so comment it out
    #
    # if [[ -z "$solutionOrProject" ]]; then
    #     # First try to find .slnx files
    #     solutionOrProject=$(find . -maxdepth 3 -type f -name "*.slnx" -print -quit 2>/dev/null || true)
    # fi
    # if [[ -z "$solutionOrProject" ]]; then
    #     # Then try to find .sln files
    #     solutionOrProject=$(find . -maxdepth 3 -type f -name "*.sln" -print -quit 2>/dev/null || true)
    # fi
    # if [[ -z "$solutionOrProject" ]]; then
    #     # Finally try to find .csproj files
    #     solutionOrProject=$(find . -maxdepth 3 -type f -name "*.csproj" -print -quit 2>/dev/null || true)
    # fi

    warning build_project "build-project is empty" "$solutionOrProject"
fi

if [[ -z "$test_project" ]]; then
    error "test-project cannot be empty"
fi

if [[ -z "$benchmark_project" ]]; then
    warning benchmark_project "benchmark-project is empty" ""
fi

# Validate and set os
if [[ -z "$os" ]]; then
    warning os "Invalid JSON for target OS." "ubuntu-latest"
fi

# Validate and set dotnet-version
if [[ -z "$dotnet_version" ]]; then
    warning dotnet_version "dotnet-version is empty." "10.0.x"
fi

# Set configuration with validation
if [[ -z "$configuration" ]]; then
    warning configuration "configuration must have value." "Release"
fi

# Validate numeric inputs
if ! [[ "$min_coverage_pct" =~ ^[0-9]+$ ]] || (( min_coverage_pct < 50 || min_coverage_pct > 100 )); then
    warning min_coverage_pct "min-coverage-pct must be 50-100." 80
fi

if [[ "$force_new_baseline" != "true" && "$force_new_baseline" != "false" ]]; then
    warning force_new_baseline "force-new-baseline must be true/false." "false"
fi

if ! [[ "$max_regression_pct" =~ ^[0-9]+$ ]] || (( max_regression_pct < 0 || max_regression_pct > 50 )); then
    warning max_regression_pct "max-regression-pct must be 0-50." 10
fi

if [[ "$verbose" != "true" && "$verbose" != "false" ]]; then
    warning verbose "verbose must be true/false." "false"
fi

if (( errors > 0 )); then
    echo "❌ Exiting with $errors error(s). Please fix the issues and try again." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    exit 1
fi

{
    # Log all computed values for debugging
    echo "✔️ All variables validated successfully"
    echo ""
    echo "| Variable             | Value                 |"
    echo "|:---------------------|:----------------------|"
    echo "| build-project        | $build_project        |"
    echo "| test-project         | $test_project         |"
    echo "| benchmark-project    | $benchmark_project    |"
    echo "| os                   | $os                   |"
    echo "| dotnet-version       | $dotnet_version       |"
    echo "| configuration        | $configuration        |"
    echo "| preprocessor-symbols | $preprocessor_symbols |"
    echo "| min-coverage-pct     | $min_coverage_pct     |"
    echo "| force-new-baseline   | $force_new_baseline   |"
    echo "| max-regression-pct   | $max_regression_pct   |"
    echo "| verbose              | $verbose              |"
} | tee >> "$GITHUB_STEP_SUMMARY"

# Output all variables to GITHUB_OUTPUT for use in subsequent jobs
# shellcheck disable=SC2154
{
    echo "build-project=$build_project"
    echo "test-project=$test_project"
    echo "benchmark-project=$benchmark_project"
    echo "os=$os"
    echo "dotnet-version=$dotnet_version"
    echo "configuration=$configuration"
    echo "preprocessor-symbols=$preprocessor_symbols"
    echo "min-coverage-pct=$min_coverage_pct"
    echo "force-new-baseline=$force_new_baseline"
    echo "max-regression-pct=$max_regression_pct"
    echo "verbose=$verbose"
} >> "$GITHUB_OUTPUT"
