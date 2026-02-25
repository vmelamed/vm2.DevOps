#!/usr/bin/env bash
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../../scripts/bash/lib")
declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -r defaultBuildProjects='[]'
declare -r defaultTestProjects='[]'
declare -r defaultBenchmarkProjects='[]'
declare -r defaultPackageProjects='[]'
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
declare -x package_projects=${PACKAGE_PROJECTS:-${defaultPackageProjects}}
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
# Check for required dependencies (jq and gh) and attempt to install them if not found
if ! command -v -p jq &> "$_ignore"; then
    if execute sudo apt-get update && sudo apt-get install -y jq; then
        info "GitHub CLI 'jq' successfully installed."
    else
        error "GitHub CLI 'jq' was not found and could not install it. Please have 'jq' installed."
        exit 1
    fi
else
    jq -V | to_stdout | grep -Eo 'jq-1\.8\.[0-9]+' || {
        error "GitHub CLI 'jq' version 1.8.x is required. Please update 'jq' to version 1.8.x."
        exit 1
    }
fi
if ! command -v -p gh 2>&1 "$_ignore"; then
    if execute sudo apt-get update && sudo apt-get install -y gh; then
        info "GitHub CLI 'gh' successfully installed."
    else
        error "GitHub CLI 'gh' was not found and could not install it. Please have 'gh' installed."
        exit 1
    fi
fi

# shellcheck disable=SC2034 # build_projects_len is assigned but never used, it's output for github_output
build_projects_len=$(is_safe_json_array "build_projects" "$defaultBuildProjects" is_safe_existing_file) || true

# shellcheck disable=SC2034 # test_projects_len is assigned but never used, it's output for github_output
test_projects_len=$(is_safe_json_array "test_projects" "$defaultTestProjects" is_safe_existing_file) || true

# shellcheck disable=SC2034 # benchmark_projects_len is assigned but never used, it's output for github_output
benchmark_projects_len=$(is_safe_json_array "benchmark_projects" "$defaultBenchmarkProjects" is_safe_existing_file) || true

# shellcheck disable=SC2034 # package_projects_len is assigned but never used, it's output for github_output
package_projects_len=$(is_safe_json_array "package_projects" "$defaultPackageProjects" is_safe_existing_file) || true

# shellcheck disable=SC2034 # runners_os_len is assigned but never used, it's output for github_output
runners_os_len=$(is_safe_json_array "runners_os" "$defaultRunnersOs" is_safe_runner_os) || true

is_safe_dotnet_version "$dotnet_version" || true
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
    package_projects \
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
    package_projects \
    runners_os \
    build_projects_len \
    test_projects_len \
    benchmark_projects_len \
    package_projects_len \
    runners_os_len \
    dotnet_version \
    configuration \
    preprocessor_symbols \
    min_coverage_pct \
    max_regression_pct \
    minver_tag_prefix \
    minver_prerelease_id
    # add more variables above this line
