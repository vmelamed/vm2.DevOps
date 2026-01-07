#!/bin/bash
set -euo pipefail

# ==============================================================================
# This script validates and sets up CI variables for GitHub Actions workflows.
# It validates and adjusts all input variables and outputs them to github_output
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
declare -r defaultTestProjects='["__skip__"]'
declare -r defaultBenchmarkProjects='["__skip__"]'
declare -r defaultOses='["ubuntu-latest"]'
declare -r defaultDotnetVersion='10.0.x'
declare -r defaultConfiguration='Release'
declare -r defaultPreprocessorSymbols=''
declare -r defaultMinCoveragePct=80
declare -r defaultMaxRegressionPct=20
declare -r defaultVerbose=false

# CI Variables that will be passed as environment variables
declare -x build_projects=${BUILD_PROJECTS:-${defaultBuildProjects}}
declare -x test_projects=${TEST_PROJECTS:-}
declare -x benchmark_projects=${BENCHMARK_PROJECTS:-${defaultBenchmarkProjects}}
declare -x os=${OS:-${defaultOses}}
declare -x dotnet_version=${DOTNET_VERSION:-${defaultDotnetVersion}}
declare -x configuration=${CONFIGURATION:-${defaultConfiguration}}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-${defaultPreprocessorSymbols}}
declare -x min_coverage_pct=${MIN_COVERAGE_PCT:-${defaultMinCoveragePct}}
declare -x max_regression_pct=${MAX_REGRESSION_PCT:-${defaultMaxRegressionPct}}
declare -x verbose=${VERBOSE:-${defaultVerbose}}

source "$script_dir/validate-vars.usage.sh"
source "$script_dir/validate-vars.utils.sh"

get_arguments "$@"
dump_all_variables

declare -i errors=0

## Shell function to log an error
## Usage: error "Error message"
# shellcheck disable=SC2154
function error()
{
    echo "❌ ERROR $*" | tee -a "$github_step_summary"
    errors=$((errors + 1))
    return 0
}

## Shell function to log a warning and set a default value
## Usage: warning variable_default_name "Warning message" variable_assumed_value
function warning()
{
    declare -n variable="$1";
    # shellcheck disable=SC2034
    variable="$3"
    echo "⚠️ WARNING $2 Assuming default value of '$3'." | tee -a "$github_step_summary"
    return 0
}

if ! command -v jq &> /dev/null; then
    error "jq command not found. Please install jq."
    exit 1
fi

jq_empty='. == null or . == "" or . == []'
jq_array_strings='type == "array" and all(type == "string")'
jq_array_strings_has_empty="any(. == \"\")"
jq_array_strings_nonempty="$jq_array_strings and length > 0 and all(length > 0)"

# We can build one or more projects or one solution with all projects in it:
if [[ -z "$build_projects" ]] || jq -e "$jq_empty" <<< "$build_projects" > /dev/null 2>&1; then
    warning build_projects "The value of the option --build-projects is empty: will build the entire solution." "$defaultBuildProjects"
else
    jq -e "$jq_array_strings" <<< "$build_projects" > /dev/null 2>&1
    jq_exit=$?
    if [[ $jq_exit == 5 ]]; then
        error "The value of the option --build-projects '$build_projects' is not a valid JSON."
    elif [[ $jq_exit != 0 ]]; then
        error "The value of the option --build-projects '$build_projects' must be a string representing a (possibly empty) JSON array of (possibly empty) strings - paths to the project(s) to be built."
    elif jq -e "$jq_array_strings_has_empty" <<< "$build_projects" > /dev/null 2>&1; then
        warning build_projects "At least one of the strings in the value of the option --build-projects '$build_projects' is empty: will build the entire solution." "$defaultBuildProjects"
    else
        for p in $(jq -r '.[]' <<< "$build_projects"); do
            if [[ ! -s "$p" && "$p" != "" ]]; then
                error "Build project file '$p' does not exist or is empty. Please check the path."
            fi
        done
    fi
fi

# There must be at least one test project specified:
if [[ -z "$test_projects" ]]; then
    warning test_projects "The value of the option --test-projects is empty: will not run tests." "$defaultTestProjects"
else
    jq -e "$jq_array_strings_nonempty" <<< "$test_projects" > /dev/null 2>&1
    jq_exit=$?
    if [[ $jq_exit == 5 ]]; then
        error "The value of the option --test-projects '$test_projects' is not a valid JSON."
    elif [[ $jq_exit != 0 ]]; then
        warning test_projects "The value of the option --test-projects is empty or invalid: will not run tests." "$defaultTestProjects"
    else
        for p in $(jq -r '.[]' <<< "$test_projects"); do
            if [[ ! -s "$p" && "$p" != "__skip__" ]]; then
                error "Test project file '$p' does not exist or is empty. Please verify the path in --test-projects."
            fi
        done
    fi
fi

if [[ -z "$benchmark_projects" ]] || jq -e "$jq_empty" <<< "$benchmark_projects" > /dev/null 2>&1; then
    warning benchmark_projects "The value of the option --benchmark-projects is empty: will not run benchmarks." "$defaultBenchmarkProjects"
else
    jq -e "$jq_array_strings_nonempty" <<< "$benchmark_projects" > /dev/null 2>&1
    jq_exit=$?
    if [[ $jq_exit == 5 ]]; then
        error "The value of the option --benchmark-projects '$benchmark_projects' is not a valid JSON."
    elif [[ $jq_exit != 0 ]]; then
        error "The value of the option --benchmark-projects '$benchmark_projects' must be a string representing a non-empty JSON array of non-empty strings - paths to the benchmark project(s) to be run."
    else
        for p in $(jq -r '.[]' <<< "$benchmark_projects"); do
            if [[ ! -s "$p" && "$p" != "__skip__" ]]; then
                error "Benchmark project file '$p' does not exist or is empty. Please verify the path in --benchmark-projects."
            fi
        done
    fi
fi

# Validate and set os
if [[ -z "$os" ]] || jq -e "$jq_empty" <<< "$os" > /dev/null 2>&1; then
    warning os "The value of the option --os '$os' is empty: will use default runner OS." "$defaultOses"
else
    jq -e "$jq_array_strings_nonempty" <<< "$os" > /dev/null 2>&1
    jq_exit=$?
    if [[ $jq_exit == 5 ]]; then
        error "The value of the option --os '$os' is not a valid JSON."
    elif [[ $jq_exit != 0 ]]; then
        error "The value of the option --os '$os' must be a string representing a non-empty JSON array of non-empty strings - monikers of GitHub runners."
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

# preprocessor_symbols can be empty - that's valid, so no validation needed

# Validate numeric inputs
if ! [[ "$min_coverage_pct" =~ ^[0-9]+$ ]] || (( min_coverage_pct < 50 || min_coverage_pct > 100 )); then
    warning min_coverage_pct "min-coverage-pct must be 50-100." "$defaultMinCoveragePct"
fi

if ! [[ "$max_regression_pct" =~ ^[0-9]+$ ]] || (( max_regression_pct < 0 || max_regression_pct > 50 )); then
    warning max_regression_pct "max-regression-pct must be 0-50." "$defaultMaxRegressionPct"
fi

if [[ "$verbose" != "true" && "$verbose" != "false" ]]; then
    warning verbose "verbose must be true/false." "$defaultVerbose"
fi

if (( errors > 0 )); then
    {
        echo "❌ Exiting with $errors error(s). Please fix the issues and try again."
        echo ""
        echo "| Variable             | Value                 |"
        echo "|:---------------------|:----------------------|"
        echo "| build-projects       | $build_projects       |"
        echo "| test-projects        | $test_projects        |"
        echo "| benchmark-projects   | $benchmark_projects   |"
        echo "| os                   | $os                   |"
        echo "| dotnet-version       | $dotnet_version       |"
        echo "| configuration        | $configuration        |"
        echo "| preprocessor-symbols | $preprocessor_symbols |"
        echo "| min-coverage-pct     | $min_coverage_pct     |"
        echo "| max-regression-pct   | $max_regression_pct   |"
        echo "| verbose              | $verbose              |"
    } | tee -a "$github_step_summary"
    exit 1
fi

{
    # Log all computed values for debugging
    echo "✔️ All variables validated successfully"
    echo ""
    echo "| Variable             | Value                 |"
    echo "|:---------------------|:----------------------|"
    echo "| build-projects       | $build_projects       |"
    echo "| test-projects        | $test_projects        |"
    echo "| benchmark-projects   | $benchmark_projects   |"
    echo "| os                   | $os                   |"
    echo "| dotnet-version       | $dotnet_version       |"
    echo "| configuration        | $configuration        |"
    echo "| preprocessor-symbols | $preprocessor_symbols |"
    echo "| min-coverage-pct     | $min_coverage_pct     |"
    echo "| max-regression-pct   | $max_regression_pct   |"
    echo "| verbose              | $verbose              |"
} | tee -a "$github_step_summary"


# shellcheck disable=SC2154
function github_output()
{
    declare -n variable="$1"
    declare modified="${1//_/-}"

    echo "${modified}=${variable}" >> "${github_output}"
}

# Output all variables to github_output for use in subsequent jobs
# shellcheck disable=SC2154
github_output build_projects
github_output test_projects
github_output benchmark_projects
github_output os
github_output dotnet_version
github_output configuration
github_output preprocessor_symbols
github_output min_coverage_pct
github_output max_regression_pct
github_output verbose
