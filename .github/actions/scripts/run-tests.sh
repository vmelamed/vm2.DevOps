#!/usr/bin/env bash
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(realpath -e "$(dirname "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../../scripts/bash/lib")
declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -xr default_configuration="Release"
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"
declare -xr default_artifacts_dir="./TestResults"
declare -ixr default_min_coverage_pct=80

declare -x test_project=${TEST_PROJECT:-}
declare -x configuration=${CONFIGURATION:="${default_configuration}"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"${default_minver_tag_prefix}"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"${default_minver_prerelease_id}"}
declare -x artifacts_dir=${TEST_ARTIFACTS_DIR:-}
declare -ix min_coverage_pct=${MIN_COVERAGE_PCT:-"${default_min_coverage_pct}"}

source "$script_dir/run-tests.usage.sh"
source "$script_dir/run-tests.utils.sh"

get_arguments "$@"
# shellcheck disable=SC2119 # Use dump_all_variables "$@" if function's $1 should mean script's $1.
dump_inputs --quiet

is_safe_existing_file "$test_project" || true
test_name=$(basename "${test_project%.*}")                                      # the base name of the test project (without the path and file extension)
test_dir=$(dirname "$test_project")                                             # the directory of the test project
is_safe_input "$test_name" || true
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
validate_minverTagPrefix "$minver_tag_prefix" || true
is_safe_minverPrereleaseId "$minver_prerelease_id" || true
is_safe_path "$artifacts_dir" || true
is_safe_min_coverage_pct "$min_coverage_pct" || true

repo_root=$(git rev-parse --show-toplevel)
test_config_path="${repo_root}/testconfig.json"
coverage_settings_path="${repo_root}/coverage.settings.xml"                     # path to coverage settings file                ~/repos/vm2.Glob/coverage.settings.xml

if [[ ! -s "$test_config_path" ]]; then
    error "Test config file not found at: $test_config_path"
fi
if [[ ! -s "$coverage_settings_path" ]]; then
    error "Coverage settings file not found at: $coverage_settings_path"
fi

if [[ -n "$REPORTGENERATOR_LICENSE" ]]; then
    trace "ReportGenerator license provided '${REPORTGENERATOR_LICENSE:0:4}...${REPORTGENERATOR_LICENSE:952}' via environment variable."
else
    warning "No ReportGenerator license provided. If you have a license, you can set it via the environment variable REPORTGENERATOR_LICENSE to enable additional features in the generated reports."
fi
exit_if_has_errors

test_dir=$(realpath -e "${test_dir}")                                           # the directory of the test project
[[ -z "$artifacts_dir" ]] && artifacts_dir="${default_artifacts_dir}/${test_name}"
artifacts_dir=$(realpath -m "${artifacts_dir}" 2> "$_ignore")                   # the directory for test results and reports (resolved to an absolute path, if it was relative)
renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"

# Freeze the variables
declare -xr test_project
declare -xr configuration
declare -xr preprocessor_symbols
declare -xr min_coverage_pct
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr test_name
declare -xr test_dir
declare -xr repo_root
declare -xr test_config_path
declare -xr artifacts_dir
declare -xr renamed_artifacts_dir

if [[ -d "$artifacts_dir" && -n "$(ls -A "$artifacts_dir")" ]]; then
    if [[ -n "${CI:-}" ]]; then
        # Auto-delete in CI
        echo "Deleting existing artifacts directory (running in CI)..."
        execute rm -rf "$artifacts_dir"
    else
        choice=$(choose \
                    "The test results directory '$artifacts_dir' already exists. What do you want to do?" \
                        "Delete the directory and continue" \
                        "Rename the directory to '$renamed_artifacts_dir' and continue" \
                        "Exit the script") || exit $?

        trace "User selected option: $choice"
        case $choice in
            1)  echo "Deleting the directory '$artifacts_dir'..."
                execute rm -rf "$artifacts_dir"
                ;;
            2)  echo "Renaming the directory '$artifacts_dir' to '$renamed_artifacts_dir'..."
                execute mv "$artifacts_dir" "$renamed_artifacts_dir"
                ;;
            3)  echo "Exiting the script."
                exit 0
                ;;
            *)  echo "Invalid option $choice. Exiting."
                exit 2
                ;;
        esac
    fi
fi

# ${artifacts_dir}                                                              # abs.path to test results and reports          ~/repos/vm2.Glob/TestResults
coverage_source_path="${artifacts_dir}/coverage.cobertura.xml"                  # path to the raw coverage file                 ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/coverage.cobertura.xml
coverage_reports_dir="${artifacts_dir}/reports"                                 # directory for coverage reports                ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/reports

# shellcheck disable=SC2034 # coverage_reports_dir appears unused. Verify use (or export if used externally). Used in args_to_github_output below
declare -xr coverage_source_path
declare -xr coverage_settings_path

# shellcheck disable=SC2119 # Use dump_all_variables "$@" if function's $1 should mean script's $1.
dump_all_variables --quiet # --force

test_base_dir="${test_dir}/bin/${configuration}/net10.0"
test_exec_path="${test_base_dir}/${test_name}"
os_name="$(uname -s)"
if [[ "$os_name" == "Windows_NT" || "$os_name" == *MINGW* || "$os_name" == *MSYS* ]]; then
    test_exec_path="${test_exec_path}.exe"
fi
declare -r test_base_dir
declare -rx test_exec_path

declare -x _ignore
declare -rx dry_run

# Verify artifacts exist, if not - rebuild the project (mostly for local runs)
if [[ ! -s "${test_exec_path}" && "$dry_run" != "true" ]]; then
    warning "Cached test executable '${test_exec_path}' was not found. Rebuilding the test project"
    execute dotnet clean "$test_project" --configuration "$configuration" || true
    if ! execute dotnet build "$test_project" \
            --configuration "$configuration" \
            -p:preprocessor_symbols="$preprocessor_symbols" \
            -p:MinVerTagPrefix="$minver_tag_prefix" \
            -p:MinVerPrereleaseIdentifiers="$minver_prerelease_id"; then
        error "Building $test_project failed."
        exit_if_has_errors
    fi
fi


trace "Running tests from ${test_project}..."

# Build coverage command arguments
coverage_args=(
    --config-file "$test_config_path"
    --results-directory "${artifacts_dir}"
    --coverage-settings "${coverage_settings_path}"
    --report-trx
    --coverage
    --coverage-output-format "cobertura"
    --coverage-output "$coverage_source_path"
)

##########################################
### Run the tests with coverage collection
##########################################
if ! execute "${test_exec_path}" "${coverage_args[@]}"; then
    error "Tests failed in project '$test_project'."
    exit 2
fi

if [[ $dry_run != "true" ]]; then
    if [[ ! -s "$coverage_source_path" ]]; then
        error "Coverage file '$coverage_source_path' not found or is empty."
        exit 2
    fi
fi

# shellcheck disable=SC2154 # ci is referenced but not assigned.
if [[ "$ci" == true ]]; then
    trace "Running in CI environment, skipping coverage report generation - will be generated later by an action."

    # Export variables to GitHub Actions output
    to_github_output test_name proj-name
    args_to_github_output \
        artifacts_dir \
        coverage_source_path \
        coverage_reports_dir

    exit 0
fi

trace "Generating coverage reports..."

uninstall_reportgenerator=false
if ! execute dotnet tool list dotnet-reportgenerator-globaltool --global > "$_ignore"; then
    trace "Installing the tool 'reportgenerator'..."
    execute dotnet tool install dotnet-reportgenerator-globaltool --global --version "5.5.*"
    uninstall_reportgenerator=true
else
    trace "The tool 'reportgenerator' is already installed."
fi

# Execute the tool in this directory so that it can pick up the .netconfig file for filters specific to this project
execute reportgenerator \
    -reports:"$coverage_source_path" \
    -targetdir:"$coverage_reports_dir" \
    -reporttypes:TextSummary,html_dark,MarkdownSummaryGithub,Badges \
    minimumCoverageThresholds:lineCoverage=80 \
    minimumCoverageThresholds:branchCoverage=80 \
    minimumCoverageThresholds:methodCoverage=80 \
    minimumCoverageThresholds:fullMethodCoverage=80

if [[ "$uninstall_reportgenerator" = "true" ]]; then
    trace "Uninstalling the tool 'reportgenerator'..."
    execute dotnet tool uninstall dotnet-reportgenerator-globaltool --global
fi
