#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
lib_dir="$script_dir/../../../scripts/bash/lib"

declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -r defaultBuildProjects='[""]'
declare -r defaultTestProjects='["__skip__"]'
declare -r defaultBenchmarkProjects='["__skip__"]'
declare -r defaultRunnersOs='["ubuntu-latest"]'
declare -r defaultDotnetVersion='10.0.x'
declare -r defaultConfiguration='Release'
declare -r defaultPreprocessorSymbols=''
declare -r defaultMinCoveragePct=80
declare -r defaultMaxRegressionPct=20
declare -r defaultMinverTagPrefix='v'
declare -r defaultMinverPrereleaseId='preview.0'
declare -r defaultVerbose=false

# CI Variables that will be passed as environment variables
declare -x build_projects=${BUILD_PROJECTS:-${defaultBuildProjects}}
declare -x test_projects=${TEST_PROJECTS:-${defaultTestProjects}}
declare -x benchmark_projects=${BENCHMARK_PROJECTS:-${defaultBenchmarkProjects}}
declare -x runners_os=${RUNNERS_OS:-${defaultRunnersOs}}
declare -x dotnet_version=${DOTNET_VERSION:-${defaultDotnetVersion}}
declare -x configuration=${CONFIGURATION:-${defaultConfiguration}}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-${defaultPreprocessorSymbols}}
declare -x min_coverage_pct=${MIN_COVERAGE_PCT:-${defaultMinCoveragePct}}
declare -x max_regression_pct=${MAX_REGRESSION_PCT:-${defaultMaxRegressionPct}}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-${defaultMinverTagPrefix}}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-${defaultMinverPrereleaseId}}
declare -x verbose=${VERBOSE:-${defaultVerbose}}

source "$script_dir/validate-input.usage.sh"
source "$script_dir/validate-input.utils.sh"

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

is_safe_json_array "build_projects" "$defaultBuildProjects" is_safe_existing_file || true
is_safe_json_array "test_projects" "$defaultTestProjects" is_safe_existing_file || true
is_safe_json_array "benchmark_projects" "$defaultBenchmarkProjects" is_safe_existing_file || true
is_safe_runners_os "runners_os" "$defaultRunnersOs" is_safe_runner_os || true
if [[ -z "$dotnet_version" ]]; then
    warning_var dotnet_version "dotnet-version is empty." "$defaultDotnetVersion"
fi
is_safe_dotnet_version "$dotnet_version" || true
if [[ -z "$configuration" ]]; then
    warning_var configuration "configuration must have value." "$defaultConfiguration"
fi
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
is_safe_min_coverage_pct "$min_coverage_pct" || true
if (( min_coverage_pct < 50 || min_coverage_pct > 100 )); then
    warning_var min_coverage_pct "min-coverage-pct must be between 50-100." "$defaultMinCoveragePct"
fi
is_safe_max_regression_pct "$max_regression_pct" || true
if (( max_regression_pct < 0 || max_regression_pct > 50 )); then
    warning_var max_regression_pct "max-regression-pct must be between 0-50." "$defaultMaxRegressionPct"
fi
validate_minverTagPrefix "$minver_tag_prefix" || true
is_safe_minverPrereleaseId "$minver_prerelease_id" || true

dump_vars --quiet --force --markdown \
    -h "Validated Parameters" \
    build_projects \
    test_projects \
    benchmark_projects \
    runners_os \
    dotnet_version \
    configuration \
    preprocessor_symbols \
    min_coverage_pct \
    max_regression_pct \
    minver_tag_prefix \
    minver_prerelease_id | to_stdout

exit_if_has_errors

info "✅ All parameters validated successfully"

# Output all variables to github_output for use in subsequent jobs
# shellcheck disable=SC2154 # variable is referenced but not assigned.
args_to_github_output \
    build_projects \
    test_projects \
    benchmark_projects \
    runners_os \
    dotnet_version \
    configuration \
    preprocessor_symbols \
    min_coverage_pct \
    max_regression_pct \
    minver_tag_prefix \
    minver_prerelease_id
    # add more variables above this line
