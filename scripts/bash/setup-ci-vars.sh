#!/bin/bash
set -euo pipefail

# ==============================================================================
# This script validates and sets up CI variables for GitHub Actions workflows.
# It validates and adjusts all input variables and outputs them to GITHUB_OUTPUT
# for use by subsequent workflow jobs. The initial values are coming either from
# the respective environment variables or the script parameters.
# Validated variables:
#   build_projects
#   test_projects
#   benchmark_projects
#   os
#   dotnet_version
#   configuration
#   preprocessor_symbols
#   min_coverage_pct
#   force_new_baseline
#   max_regression_pct
#   verbose
# ==============================================================================

declare -xr this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

source "$script_dir/_common.sh"

declare -r defaultBuildProjects='[""]'
declare -r defaultBenchmarkProjects='[]'
declare -r defaultOses='["ubuntu-latest"]'
declare -r defaultDotnetVersion='10.0.x'
declare -r defaultConfiguration='Release'
declare -r defaultForceNewBaseline=false
declare -r defaultMinCoveragePct=80
declare -r defaultMaxRegressionPct=10
declare -r defaultVerbose=false

# CI Variables that will be passed as environment variables
declare -x build_projects=${BUILD_PROJECTS:-${defaultBuildProjects}}
declare -x test_projects=${TEST_PROJECTS:-}
declare -x benchmark_projects=${BENCHMARK_PROJECTS:-${defaultBenchmarkProjects}}
declare -x os=${OS:-${defaultOses}}
declare -x dotnet_version=${DOTNET_VERSION:-${defaultDotnetVersion}}
declare -x configuration=${CONFIGURATION:-${defaultConfiguration}}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x min_coverage_pct=${MIN_COVERAGE_PCT:-${defaultMinCoveragePct}}
declare -x force_new_baseline=${FORCE_NEW_BASELINE:-${defaultForceNewBaseline}}
declare -x max_regression_pct=${MAX_REGRESSION_PCT:-${defaultMaxRegressionPct}}
declare -x verbose=${VERBOSE:-${defaultVerbose}}

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

if [[ -z "$build_projects" || "$build_projects" == '[""]' || "$build_projects" == '[]' || "$build_projects" == 'null' ]]; then
    warning build_projects "build-projects is empty: will build the solution" "$defaultBuildProjects"
else
    echo "$build_projects" | jq -c
    if $? -ne 0; then
        error "Invalid JSON for build-projects."
    else
        echo "$build_projects" | jq -c '.[]' | while read -r project; do
            if [[ ! -s "$project" ]]; then
                error "Build project '$project' does not exist or is empty."
            fi
        done
    fi
fi

if [[ -z "$test_projects" || "$test_projects" == '[]' || "$test_projects" == 'null' ]]; then
    error "test-projects cannot be empty"
else
    echo "$test_projects" | jq -c
    if $? -ne 0; then
        error "Invalid JSON for test-projects."
    else
        echo "$test_projects" | jq -c '.[]' | while read -r project; do
            if [[ ! -s "$project" ]]; then
                error "Test project '$project' does not exist or is empty."
            fi
        done
    fi
fi

if [[ -z "$benchmark_projects" || "$benchmark_projects" == '[]' || "$benchmark_projects" == 'null' ]]; then
    warning benchmark_projects "benchmark_projects is empty" "$defaultBenchmarkProjects"
else
    echo "$benchmark_projects" | jq -c
    if $? -ne 0; then
        error "Invalid JSON for benchmark-projects."
    else
        echo "$benchmark_projects" | jq -c '.[]' | while read -r project; do
            if [[ ! -s "$project" ]]; then
                error "Benchmark project '$project' does not exist or is empty."
            fi
        done
    fi
fi

# Validate and set os
if [[ -z "$os" || "$os" == '[""]' || "$os" == '[]' || "$os" == 'null' ]]; then
    declare ubuntuOs='["ubuntu-latest"]'
    warning os "os is empty" "$ubuntuOs"
else
    echo "$os" | jq -c
    if $? -ne 0; then
        error "Invalid JSON for os."
    else
        echo "$os" | jq -c '.[]' | while read -r anOs; do
            if [[ -z "$anOs" ]]; then
                error "There is an empty OS value."
            fi
        done
    fi
fi

# Validate and set dotnet-version
if [[ -z "$dotnet_version" ]]; then
    warning dotnet_version "dotnet-version is empty." "$defaultDotnetVersion"
fi

# Set configuration with validation
if [[ -z "$configuration" ]]; then
    warning configuration "configuration must have value." "$defaultConfiguration"
fi

# Validate numeric inputs
if ! [[ "$min_coverage_pct" =~ ^[0-9]+$ ]] || (( min_coverage_pct < 50 || min_coverage_pct > 100 )); then
    warning min_coverage_pct "min-coverage-pct must be 50-100." "$defaultMinCoveragePct"
fi

if [[ "$force_new_baseline" != "true" && "$force_new_baseline" != "false" ]]; then
    warning force_new_baseline "force-new-baseline must be true/false." "$defaultForceNewBaseline"
fi

if ! [[ "$max_regression_pct" =~ ^[0-9]+$ ]] || (( max_regression_pct < 0 || max_regression_pct > 50 )); then
    warning max_regression_pct "max-regression-pct must be 0-50." "$defaultMaxRegressionPct"
fi

if [[ "$verbose" != "true" && "$verbose" != "false" ]]; then
    warning verbose "verbose must be true/false." "$defaultVerbose"
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


# shellcheck disable=SC2154
function github_output()
{
    declare -n variable="$1"
    declare modified="${1//_/-}"

    echo "${modified}=${variable}" >> "${GITHUB_OUTPUT}"
}

# Output all variables to GITHUB_OUTPUT for use in subsequent jobs
# shellcheck disable=SC2154
github_output build_projects
github_output test_projects
github_output benchmark_projects
github_output os
github_output dotnet_version
github_output configuration
github_output preprocessor_symbols
github_output min_coverage_pct
github_output force_new_baseline
github_output max_regression_pct
github_output verbose
