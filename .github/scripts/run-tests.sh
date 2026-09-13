#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail
declare -x TZ="${TZ:-America/New_York}"

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(realpath -e "$(dirname "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following
source "$lib_dir/gh_core.sh"

# Declare variables defined in the core library.
declare -xr ci
declare -x _ignore
declare -xr glow_present

# Declare error codes defined in the core library
declare -xri success
declare -xri failure
declare -xri err_tool_error
declare -xri err_logic_error
declare -xri err_unknown_argument

# define default constants specific for this script only
declare -xri default_min_coverage_pct=80
declare -xri default_min_branch_coverage_pct=75
declare -xri default_min_method_coverage_pct=80

# Define CI common variables passed in as common dotnet arguments
declare -x preprocessor_symbols
declare -x configuration
declare -x framework
declare -x runtime
declare -x artifacts
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password

# parameters specific to this script only with initial values from environment variables or defaults
declare -x test_project=""
declare -xi min_coverage_pct=${MIN_COVERAGE_PCT:-"$default_min_coverage_pct"}
declare -xi min_branch_coverage_pct=${MIN_BRANCH_COVERAGE_PCT:-"$default_min_branch_coverage_pct"}
declare -xi min_method_coverage_pct=${MIN_METHOD_COVERAGE_PCT:-"$default_min_method_coverage_pct"}

source "$script_dir/run-tests.usage.sh"
source "$script_dir/run-tests.args.sh"

get_arguments "$@"
test_project=${test_project:-"${TEST_PROJECT:-}"}

# validate the values of the variables common for many vm2.DevOps scripts,
# usually set from CLI arguments, environment variables, or defaults
is_safe_existing_file "$test_project"        || true
[[ $test_project == *.csproj ]]              || error "The script '${script_name}' accepts only project files (*.csproj) - not solutions (*.sln or *.slnx)."
is_safe_min_coverage_pct "$min_coverage_pct" || true

exit_if_has_errors

sanitize_common_dotnet_args "$test_project"  || true

# other script specific variables
# Derive the branch-coverage threshold from the line-coverage threshold, unless the caller
# explicitly set $MIN_BRANCH_COVERAGE_PCT.
[[ -n ${MIN_BRANCH_COVERAGE_PCT:-} ]] || min_branch_coverage_pct=$((min_coverage_pct - 5))
test_name=$(basename "${test_project}" .csproj)                                 # the base name of the test project (without the path and file extension)
test_dir=$(realpath -e "${test_project%/*}")                                    # the absolute path to the test project directory
declare repo_root
root_working_tree "$test_dir" repo_root || true
test_config_path="$repo_root/testconfig.json"
coverage_settings_path="$repo_root/coverage.settings.xml"                       # path to coverage settings file    ~/repos/vm2.Glob/coverage.settings.xml

if [[ ! -s "$test_config_path" ]]; then
    error -ec "$err_logic_error" "Test config file not found at: $test_config_path"
fi
if [[ ! -s "$coverage_settings_path" ]]; then
    error -ec "$err_logic_error" "Coverage settings file not found at: $coverage_settings_path"
fi

artifacts_tests_dir=$(realpath -m "$artifacts/tests")
artifacts_test_dir="$artifacts_tests_dir/$test_name"
coverage_source_path="$artifacts_test_dir/coverage.cobertura.xml"              # path to the raw coverage file      ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/coverage.cobertura.xml
coverage_reports_dir="$artifacts_test_dir/reports"                             # directory for coverage reports     ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/reports
coverage_files="$artifacts_tests_dir/*/coverage.cobertura.xml"

dump_vars --force --quiet \
    --header "Test output directories and files:" \
    artifacts \
    artifacts_tests_dir \
    artifacts_test_dir \
    coverage_source_path \
    coverage_reports_dir \
    coverage_files

exit_if_has_errors

# Freeze the variables
declare -xr test_project
declare -xr min_coverage_pct
declare -xr test_name
declare -xr test_dir
declare -xr test_config_path
declare -xr artifacts_tests_dir
declare -xr artifacts_test_dir
declare -xr coverage_source_path
declare -xr coverage_settings_path
declare -xr coverage_files
declare -xr coverage_reports_dir

if [[ -d "$artifacts_test_dir" && -n "$(ls -A "$artifacts_test_dir")" ]]; then
    if [[ -n "${CI:-}" ]]; then
        # Auto-delete in CI
        echo "Deleting existing artifacts directory (running in CI)..."
        execute rm -rf "$artifacts_test_dir"
    else
        renamed_artifacts_dir="$artifacts_test_dir-$(date -u +"%Y%m%dT%H%M%S")"

        declare choice=''

        choose "The test results directory '$artifacts_test_dir' already exists. What do you want to do?" \
               choice \
                   "Delete the directory and continue" \
                   "Rename the directory to '$renamed_artifacts_dir' and continue" \
                   "Exit the script" || exit $?

        trace "User selected option: '$choice'"
        case $choice in
            1)  info "Deleting the directory '$artifacts_test_dir'..."
                execute rm -rf "$artifacts_test_dir"
                ;;
            2)  info "Renaming the directory '$artifacts_test_dir' to '$renamed_artifacts_dir'..."
                execute mv "$artifacts_test_dir" "$renamed_artifacts_dir"
                ;;
            3)  info "Exiting the script."
                exit 0
                ;;
            *)  error -sd 3 -ec "$err_unknown_argument" "Invalid option '$choice'. Exiting."
                exit "$err_unknown_argument"
                ;;
        esac
    fi
fi

declare -x test_exec_path
get_target_path "$test_project" test_exec_path
declare -xr test_exec_path
trace "Expecting test executable: $test_exec_path"

exit_if_has_errors

# Verify build artifacts exist, if not - rebuild the project (mostly for local runs)
if [[ ! -s $test_exec_path ]]; then
    if ! is_dry_run; then
        warning "Test executable '$test_exec_path' was not found in the artifacts directory. Rebuilding the test project..."

        update_nuget_sources_with_github_vm2 || error -ec "$err_tool_error" "Updating the NuGet sources with GitHub packages from vm2 failed."
        dotnet_clean "$test_project"         || error -ec "$err_tool_error" "Cleaning the test project failed."
        dotnet_restore "$test_project"       || error -ec "$err_tool_error" "Restoring the test project failed."
        dotnet_build "$test_project"         || error -ec "$err_tool_error" -sd 3 "Building the test project failed."
        [[ -s $test_exec_path ]]             || error -ec "$err_tool_error" -sd 3 "After rebuilding the project, the test executable '$test_exec_path' was still NOT FOUND."

        exit_if_has_errors
    fi
fi

trace "Running tests from $test_project..."

# Build test and coverage command arguments
test_args=(
    --config-file "$test_config_path"
    --results-directory "$artifacts_test_dir"
    --coverage-settings "$coverage_settings_path"
    --report-trx
    --coverage
    --coverage-output-format "cobertura"
    --coverage-output "$coverage_source_path"
)

##########################################
### Run the tests with coverage collection
##########################################
declare rc=$success

if [[ "$test_exec_path" == *.dll ]]; then
    dotnet "$test_exec_path" "${test_args[@]}" || rc=$?
else
    # *.exe or *. (Linux)
    "$test_exec_path" "${test_args[@]}" || rc=$?
fi
if (( rc != 0 )); then
    error -ec "$err_tool_error" "Tests failed in project '$test_project' with exit code $rc."
    exit "$err_tool_error"
fi
if [[ ! -s "$coverage_source_path" ]]; then
    error -ec "$err_tool_error" "Coverage file '$coverage_source_path' not found or is empty."
    exit "$err_tool_error"
fi

if $ci; then
    # Set outputs for merged coverage
    args_to_github_output \
        "coverage_files" \
        "coverage_reports_dir"

    trace "Running in CI environment, skipping coverage report generation - it will be generated later by an action."
    exit 0
fi

trace "Generating coverage reports outside CI/CD..."

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
    -reporttypes:TextSummary,html_dark,MarkdownSummaryGithub \
    minimumCoverageThresholds:lineCoverage="$min_coverage_pct" \
    minimumCoverageThresholds:branchCoverage="$min_branch_coverage_pct" \
    minimumCoverageThresholds:methodCoverage="$min_method_coverage_pct" || rc=$?

if [[ -s "$coverage_reports_dir/Summary.txt" ]]; then
    if $glow_present; then
        glow -w 150 "$coverage_reports_dir/SummaryGithub.md"
    else
        cat "$coverage_reports_dir/Summary.txt"
    fi
else
    warning "Summary.txt not found in coverage output directory '$coverage_source_path'."
fi

if [[ "$uninstall_reportgenerator" = true ]]; then
    trace "Uninstalling the tool 'reportgenerator'..."
    execute dotnet tool uninstall dotnet-reportgenerator-globaltool --global
fi

exit "$rc"
