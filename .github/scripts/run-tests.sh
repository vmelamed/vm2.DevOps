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

# core lib
source "$lib_dir/gh_core.sh"

# core lib exit codes
declare -xri success
declare -xri failure
declare -xri err_tool_error
declare -xri err_logic_error
declare -xri err_unknown_argument
declare -xri err_io_failure

# core lib constants
declare -xr ci

# core lib defaults

# core lib variables
declare -x _ignore

# core lib variables - dotnet
declare -x preprocessor_symbols
declare -x configuration
declare -x framework
declare -x runtime
declare -x artifacts
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password

# this script's components
source "$script_dir/run-tests.usage.sh"
source "$script_dir/run-tests.args.sh"

# this script's variables
get_arguments "$@"
declare -xr test_project
declare -xri min_line_coverage_pct
declare -xri min_branch_coverage_pct
declare -xri min_method_coverage_pct

# other script specific variables
declare test_exec_path
get_target_path "$test_project" test_exec_path
trace "Expecting test executable: $test_exec_path"

test_name=$(basename "${test_project}" .csproj)                                 # the base name of the test project (without the path and file extension)
test_dir=$(realpath -e "${test_project%/*}")                                    # the absolute path to the test project directory

declare repo_root
root_working_tree "$test_dir" repo_root || true
test_config_path="$repo_root/testconfig.json"
coverage_settings_path="$repo_root/coverage.settings.xml"                       # path to coverage settings file    ~/repos/vm2.Glob/coverage.settings.xml

if [[ ! -s "$test_config_path" ]]; then
    error "Test config file not found at: $test_config_path" -ec "$err_logic_error"
fi
if [[ ! -s "$coverage_settings_path" ]]; then
    error "Coverage settings file not found at: $coverage_settings_path" -ec "$err_logic_error"
fi

exit_if_has_errors

artifacts_tests_dir=$(realpath -m "$artifacts/tests")
artifacts_test_dir="$artifacts_tests_dir/$test_name"
coverage_source_path="$artifacts_test_dir/coverage.cobertura.xml"              # path to the raw coverage file      ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/coverage.cobertura.xml
coverage_reports_dir="$artifacts_test_dir/reports"                             # directory for coverage reports     ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/reports
coverage_files="$artifacts_tests_dir/*/coverage.cobertura.xml"

# Freeze the variables
readonly test_exec_path
readonly test_name
readonly test_dir
readonly artifacts_tests_dir
readonly test_config_path
readonly artifacts_test_dir
readonly coverage_source_path
readonly coverage_settings_path
readonly coverage_reports_dir
# shellcheck disable=SC2034 # coverage_files appears unused. Verify use (or export if used externally).
readonly coverage_files

declare rc=$success

dump_vars --force --quiet \
    --header "Test output directories and files:" \
    artifacts \
    artifacts_tests_dir \
    artifacts_test_dir \
    coverage_source_path \
    coverage_reports_dir \
    coverage_files

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
                   "Exit the script"

        trace "User selected option: '$choice'"
        case $choice in
            1)  warning "Deleting the directory '$artifacts_test_dir'..."
                execute rm -rf "$artifacts_test_dir"
                ;;
            2)  info "Renaming the directory '$artifacts_test_dir' to '$renamed_artifacts_dir'..."
                execute mv "$artifacts_test_dir" "$renamed_artifacts_dir"       || with_error rc "$err_io_failure" "Failed to copy '$artifacts_test_dir' to '$renamed_artifacts_dir'"
                ;;
            3)  trace "Exiting the script."
                exit 0
                ;;
            *)  error -sd 3 "Invalid option '$choice'. Exiting." -ec "$err_unknown_argument"
                exit "$err_unknown_argument"
                ;;
        esac
    fi
fi
exit_if_has_errors

# Verify build artifacts exist, if not - rebuild the project (mostly for local runs)
if [[ ! -s $test_exec_path ]]; then
    if ! is_dry_run; then
        warning "Test executable '$test_exec_path' was not found in the artifacts directory. Rebuilding the test project..."

        update_nuget_sources_with_github_vm2 || exit_with_error "Updating the NuGet sources with GitHub packages from vm2 failed." -ec "$err_tool_error"
        dotnet_clean "$test_project"         || exit_with_error "Cleaning the test project failed." -ec "$err_tool_error"
        dotnet_restore "$test_project"       || exit_with_error "Restoring the test project failed." -ec "$err_tool_error"
        dotnet_build "$test_project"         || exit_with_error -sd 3 "Building the test project failed." -ec "$err_tool_error"
        [[ -s $test_exec_path ]]             || exit_with_error -sd 3 "After rebuilding the project, the test executable '$test_exec_path' was still NOT FOUND." -ec "$err_tool_error"
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
rc=$success

if [[ "$test_exec_path" == *.dll ]]; then
    dotnet "$test_exec_path" "${test_args[@]}" || rc=$?
else
    # *.exe or *. (Linux)
    "$test_exec_path" "${test_args[@]}" || rc=$?
fi
(( rc == 0 )) ||
    exit_with_error "Tests failed in project '$test_project' with exit code $rc." -ec "$err_tool_error"
[[ -s "$coverage_source_path" ]] ||
    exit_with_error "Coverage file '$coverage_source_path' not found or is empty." -ec "$err_tool_error"

if $ci; then
    # Set outputs for merged coverage
    args_to_github_output \
        "coverage_files" \
        "coverage_reports_dir"

    trace "Running in CI environment, skipping coverage report generation - it will be generated later by an action."
    exit 0
fi

trace "Generating coverage reports outside CI/CD..."
declare -a reportgenerator_command

if dotnet tool list dotnet-reportgenerator-globaltool --global > "$_ignore" 2>&1; then
    reportgenerator_command=(reportgenerator)
elif dotnet tool list dotnet-reportgenerator-globaltool --local > "$_ignore" 2>&1; then
    reportgenerator_command=(dotnet tool run reportgenerator --)
else
    reportgenerator_command=(dotnet tool execute --yes dotnet-reportgenerator-globaltool --version '5.5.*' --)
fi

reportgenerator_command+=(
    "-reports:$coverage_source_path"
    "-targetdir:$coverage_reports_dir"
    "-reporttypes:TextSummary,html_dark,MarkdownSummaryGithub"
    "minimumCoverageThresholds:lineCoverage=$min_coverage_pct"
    "minimumCoverageThresholds:branchCoverage=$min_branch_coverage_pct"
    "minimumCoverageThresholds:methodCoverage=$min_method_coverage_pct"
)

execute "${reportgenerator_command[@]}" || rc=$?

if [[ -s "$coverage_reports_dir/Summary.txt" ]]; then
    if is_tool_present glow; then
        glow -w 150 "$coverage_reports_dir/SummaryGithub.md"
    else
        cat "$coverage_reports_dir/Summary.txt"
    fi
else
    warning "Summary.txt not found in coverage output directory '$coverage_source_path'."
fi

exit "$rc"
