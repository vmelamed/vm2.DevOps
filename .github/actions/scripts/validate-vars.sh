#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
lib_dir="$script_dir/../../../scripts/bash/lib"

declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -xr skip_projects_sentinel

declare -r defaultBuildProjects='[""]'
declare -r defaultTestProjects="[\"$skip_projects_sentinel\"]"
declare -r defaultBenchmarkProjects="[\"$skip_projects_sentinel\"]"
declare -r defaultOses='["ubuntu-latest"]'
declare -r defaultDotnetVersion='10.0.x'
declare -r defaultConfiguration='Release'
declare -r defaultPreprocessorSymbols=''
declare -r defaultMinCoveragePct=80
declare -r defaultMaxRegressionPct=20
declare -r defaultVerbose=false
declare -r defaultMinverTagPrefix='v'
declare -r defaultMinverPrereleaseId='preview.0'

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
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-${defaultMinverTagPrefix}}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-${defaultMinverPrereleaseId}}

source "$script_dir/validate-vars.usage.sh"
source "$script_dir/validate-vars.utils.sh"

get_arguments "$@"
dump_all_variables

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
if ! command -v -p jq &> "$_ignore" || ! command -v -p gh 2>&1 "$_ignore"; then
    if execute sudo apt-get update && sudo apt-get install -y gh jq; then
        info "GitHub CLI 'gh' and/or 'jq' successfully installed."
    else
        error "GitHub CLI 'gh' and/or 'jq' were not found and could not install them. Please have 'gh' and 'jq' installed."
        exit 1
    fi
fi

# We can build one or more projects or one solution with all projects in it:
# shellcheck disable=SC2154 # variable is referenced but not assigned.
if [[ -z "$build_projects" ]] || jq -e "$jq_empty" <<< "$build_projects" > "$_ignore" 2>&1; then
    warning_var build_projects "The value of the option --build-projects is empty: will build the entire solution." "$defaultBuildProjects"
else
    jq -e "$jq_array_strings" <<< "$build_projects" > "$_ignore" 2>&1
    jq_exit=$?
    if [[ $jq_exit == 5 ]]; then
        error "The value of the option --build-projects '$build_projects' is not a valid JSON."
    elif [[ $jq_exit != 0 ]]; then
        error "The value of the option --build-projects '$build_projects' must be a string representing a (possibly empty) JSON array of (possibly empty) strings - paths to the project(s) to be built."
    elif jq -e "$jq_array_strings_has_empty" <<< "$build_projects" > "$_ignore" 2>&1; then
        warning_var build_projects "At least one of the strings in the value of the option --build-projects '$build_projects' is empty: will build the entire solution." "$defaultBuildProjects"
    else
        for p in $(jq -r '.[]' <<< "$build_projects"); do
            if [[ "$p" != "" && "$p" != "$skip_projects_sentinel" && ! -s "$p" ]]; then
                error "Build project file '$p' does not exist or is empty. Please check the path."
            fi
        done
    fi
fi

# There must be at least one test project specified:
# shellcheck disable=SC2154 # variable is referenced but not assigned.
if [[ -z "$test_projects" ]]; then
    warning_var test_projects "The value of the option --test-projects is empty: will not run tests." "$defaultTestProjects"
else
    jq -e "$jq_array_strings_nonempty" <<< "$test_projects" > "$_ignore" 2>&1
    jq_exit=$?
    if [[ $jq_exit == 5 ]]; then
        error "The value of the option --test-projects '$test_projects' is not a valid JSON."
    elif [[ $jq_exit != 0 ]]; then
        warning_var test_projects "The value of the option --test-projects is empty or invalid: will not run tests." "$defaultTestProjects"
    else
        for p in $(jq -r '.[]' <<< "$test_projects"); do
            if [[ "$p" != "$skip_projects_sentinel"  && ! -s "$p" ]]; then
                error "Test project file '$p' does not exist or is empty. Please verify the path in --test-projects."
            fi
        done
    fi
fi

if [[ -z "$benchmark_projects" ]] || jq -e "$jq_empty" <<< "$benchmark_projects" > "$_ignore" 2>&1; then
    warning_var benchmark_projects "The value of the option --benchmark-projects is empty: will not run benchmarks." "$defaultBenchmarkProjects"
else
    jq -e "$jq_array_strings_nonempty" <<< "$benchmark_projects" > "$_ignore" 2>&1
    jq_exit=$?
    if [[ $jq_exit == 5 ]]; then
        error "The value of the option --benchmark-projects '$benchmark_projects' is not a valid JSON."
    elif [[ $jq_exit != 0 ]]; then
        error "The value of the option --benchmark-projects '$benchmark_projects' must be a string representing a non-empty JSON array of non-empty strings - paths to the benchmark project(s) to be run."
    else
        for p in $(jq -r '.[]' <<< "$benchmark_projects"); do
            if [[ "$p" != "$skip_projects_sentinel"  && ! -s "$p" ]]; then
                error "Benchmark project file '$p' does not exist or is empty. Please verify the path in --benchmark-projects."
            fi
        done
    fi
fi

if [[ -z "$os" ]] || jq -e "$jq_empty" <<< "$os" > "$_ignore" 2>&1; then
    warning_var os "The value of the option --os '$os' is empty: will use default runner OS." "$defaultOses"
else
    jq -e "$jq_array_strings_nonempty" <<< "$os" > "$_ignore" 2>&1
    jq_exit=$?
    if [[ $jq_exit == 5 ]]; then
        error "The value of the option --os '$os' is not a valid JSON."
    elif [[ $jq_exit != 0 ]]; then
        error "The value of the option --os '$os' must be a string representing a non-empty JSON array of non-empty strings - monikers of GitHub runners."
    fi
fi

if [[ -z "$dotnet_version" ]]; then
    warning_var dotnet_version "dotnet-version is empty." "$defaultDotnetVersion"
fi

if [[ -z "$configuration" ]]; then
    warning_var configuration "configuration must have value." "$defaultConfiguration"
fi

# preprocessor_symbols can be empty - that's valid, so no validation needed

if ! [[ "$min_coverage_pct" =~ ^[0-9]+$ ]] || (( min_coverage_pct < 50 || min_coverage_pct > 100 )); then
    warning_var min_coverage_pct "min-coverage-pct must be 50-100." "$defaultMinCoveragePct"
fi

if ! [[ "$max_regression_pct" =~ ^[0-9]+$ ]] || (( max_regression_pct < 0 || max_regression_pct > 50 )); then
    warning_var max_regression_pct "max-regression-pct must be 0-50." "$defaultMaxRegressionPct"
fi

if [[ -z "$minver_tag_prefix" ]]; then
    warning_var minver_tag_prefix "minver-tag-prefix must have value." "$defaultMinverTagPrefix"
fi

if [[ -z "$minver_prerelease_id" ]]; then
    warning_var minver_prerelease_id "minver-prerelease-id must have value." "$defaultMinverPrereleaseId"
fi

if [[ "$verbose" != "true" && "$verbose" != "false" ]]; then
    warning_var verbose "verbose must be true/false." "$defaultVerbose"
fi

dump_vars --quiet --force --markdown \
    -h "Validated Variables" \
    build_projects \
    test_projects \
    benchmark_projects \
    os \
    dotnet_version \
    configuration \
    preprocessor_symbols \
    min_coverage_pct \
    max_regression_pct \
    minver_tag_prefix \
    minver_prerelease_id \
    | to_stdout

exit_if_has_errors

info "✅ All variables validated successfully"

# Output all variables to github_output for use in subsequent jobs
# shellcheck disable=SC2154 # variable is referenced but not assigned.
args_to_github_output \
    build_projects \
    test_projects \
    benchmark_projects \
    os \
    dotnet_version \
    configuration \
    preprocessor_symbols \
    min_coverage_pct \
    max_regression_pct \
    minver_tag_prefix \
    minver_prerelease_id \
    # add more variables above this line
