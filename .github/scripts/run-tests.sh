#!/usr/bin/env bash

# shellcheck disable=SC2119

set -euo pipefail
declare -x TZ="${TZ:-America/New_York}"

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(realpath -e "$(dirname "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")
declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -rxi success
declare -rxi failure
declare -rxi err_tool_error
declare -rxi err_logic_error

declare -x _ignore
declare -x dry_run

declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"
declare -xr default_artifacts_dir="artifacts"
declare -ixr default_min_coverage_pct=80
declare -ixr default_min_branch_coverage_pct=75
declare -ixr default_min_method_coverage_pct=80

declare -x test_project=""
declare -x configuration=${CONFIGURATION:="$default_configuration"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}
declare -x artifacts=${ARTIFACTS_DIR:-"$default_artifacts_dir"}
declare -ix min_coverage_pct=${MIN_COVERAGE_PCT:-"$default_min_coverage_pct"}
declare -ix min_branch_coverage_pct=${MIN_BRANCH_COVERAGE_PCT:-"$default_min_branch_coverage_pct"}
declare -ix min_method_coverage_pct=${MIN_BRANCH_COVERAGE_PCT:-"$default_min_branch_coverage_pct"}

source "$script_dir/run-tests.usage.sh"
source "$script_dir/run-tests.args.sh"

get_arguments "$@"
test_project=${test_project:-"$TEST_PROJECT"}

# validate input parameters
is_safe_existing_file "$test_project" || true
test_name=$(basename "${test_project}" .csproj)                                 # the base name of the test project (without the path and file extension)
test_dir=$(realpath -e "${test_project%/*}")                                    # the absolute path to the test project directory
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
is_safe_min_coverage_pct "$min_coverage_pct" || true
min_branch_coverage_pct=$((min_coverage_pct - 5))
validate_semverTagComponents "$minver_tag_prefix" "$minver_prerelease_id" || true
is_safe_path "$artifacts" || true

repo_root="$(root_working_tree "$test_dir")"
test_config_path="$repo_root/testconfig.json"
coverage_settings_path="$repo_root/coverage.settings.xml"                       # path to coverage settings file                ~/repos/vm2.Glob/coverage.settings.xml

if [[ ! -s "$test_config_path" ]]; then
    error -ec "$err_logic_error" "Test config file not found at: $test_config_path"
fi
if [[ ! -s "$coverage_settings_path" ]]; then
    error -ec "$err_logic_error" "Coverage settings file not found at: $coverage_settings_path"
fi

exit_if_has_errors

artifacts=$(get_artifacts_path "$test_project" "$artifacts")
artifacts_tests_dir=$(realpath -m "$artifacts/tests")
artifacts_test_dir="$artifacts_tests_dir/$test_name"
coverage_source_path="$artifacts_test_dir/coverage.cobertura.xml"              # path to the raw coverage file                 ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/coverage.cobertura.xml
coverage_reports_dir="$artifacts_test_dir/reports"                             # directory for coverage reports                ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/reports
coverage_files="$artifacts_tests_dir/*/coverage.cobertura.xml"

dump_vars --force --quiet \
    --header "Test output directories and files:" \
    artifacts \
    artifacts_tests_dir \
    artifacts_test_dir \
    coverage_source_path \
    coverage_reports_dir \
    coverage_files

# Freeze the variables
declare -xr test_project
declare -xr configuration
declare -xr preprocessor_symbols
declare -xr min_coverage_pct
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr test_name
declare -xr test_dir
declare -xr test_config_path
declare -xr artifacts
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
        choice=$(choose \
                    "The test results directory '$artifacts_test_dir' already exists. What do you want to do?" \
                        "Delete the directory and continue" \
                        "Rename the directory to '$renamed_artifacts_dir' and continue" \
                        "Exit the script") || exit $?

        trace "User selected option: $choice"
        case $choice in
            1)  echo "Deleting the directory '$artifacts_test_dir'..."
                execute rm -rf "$artifacts_test_dir"
                ;;
            2)  echo "Renaming the directory '$artifacts_test_dir' to '$renamed_artifacts_dir'..."
                execute mv "$artifacts_test_dir" "$renamed_artifacts_dir"
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

declare rc=$success
test_exe_path=$(get_assembly_path "$test_project" "" "$configuration")
trace "Expected test executable: $test_exe_path"

# Verify artifacts exist, if not - rebuild the project (mostly for local runs)
if [[ ! -s $test_exe_path ]]; then
    if ! $dry_run; then
        warning "Cached test executable '$test_exe_path' was not found. Rebuilding the test project"

        # shellcheck disable=SC2034 # build_info appears unused. Verify use (or export if used externally). Used as a nameref.
        declare -a build_args=(
            "$test_project"
            --configuration "$configuration"
            "-p:preprocessor_symbols=\"$preprocessor_symbols\""
            "-p:MinVerTagPrefix=\"$minver_tag_prefix\""
            "-p:MinVerPrereleaseIdentifiers=\"$minver_prerelease_id\""
        )

        # shellcheck disable=SC2034 # build_info appears unused. Verify use (or export if used externally). Used as a nameref.
        declare -A build_info=()

        execute dotnet clean "$test_project" --configuration "$configuration" || true
        dotnet_build build_args build_info || rc=$?

        trace "New expected test executable: $test_exe_path"
        [[ -s $test_exe_path ]] || error -sd 3 -ec "$err_tool_error" "After rebuilding the project, the test executable '$test_exe_path' was still NOT FOUND."
        exit_if_has_errors
    fi
    rc=$success
fi
declare -rx test_exe_path
trace "Test executable: $test_exe_path"

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
if ! execute "$test_exe_path" "${test_args[@]}"; then
    error -ec "$err_tool_error" "Tests failed in project '$test_project'."
    exit 2
fi

if [[ $dry_run != true ]]; then
    if [[ ! -s "$coverage_source_path" ]]; then
        error -ec "$err_tool_error" "Coverage file '$coverage_source_path' not found or is empty."
        exit 2
    fi
fi

# shellcheck disable=SC2154 # ci is referenced but not assigned.
if $ci; then
    # Set outputs for merged coverage
    # shellcheck disable=SC2034 # proj_name appears unused. Verify use (or export if used externally).
    args_to_github_output \
        "coverage_files" \
        "coverage_reports_dir"

    trace "Running in CI environment, skipping coverage report generation - will be generated later by an action."
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
    minimumCoverageThresholds:branchCoverage="$min_branch_coverage_pct" || rc=$?

if [[ -s "$coverage_reports_dir/Summary.txt" ]]; then
    if command -v -p "glow" > "$_ignore" || which "glow" &>"$_ignore"; then
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
