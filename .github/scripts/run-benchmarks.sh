#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following
source "$lib_dir/gh_core.sh"

# Declare variables defined in the core library.
declare -xr ci
declare -x _ignore

# Declare error codes defined in the core library
declare -xri success
declare -xri failure
declare -xri err_tool_error
declare -xri err_logic_error

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
declare -x benchmark_project=""

source "$script_dir/run-benchmarks.usage.sh"
source "$script_dir/run-benchmarks.args.sh"

get_arguments "$@"
benchmark_project=${benchmark_project:-"${BENCHMARK_PROJECT:-}"}

# validate input parameters
is_safe_existing_path "$benchmark_project"   || true
[[ $benchmark_project == *.csproj ]]         || error "The script '${script_name}' accepts only project files (*.csproj) - not solutions (*.sln or *.slnx)."

exit_if_has_errors

sanitize_common_dotnet_args "$benchmark_project" || true

artifacts_benchmarks="$artifacts/benchmarks"
results_dir="$artifacts_benchmarks/results"

dump_vars --force --quiet \
    --header "Benchmarks output directories and files:" \
    artifacts \
    artifacts_benchmarks \
    results_dir

exit_if_has_errors

renamed_artifacts_dir="$artifacts_benchmarks-$(date -u +"%Y%m%dT%H%M%S")"

# Freeze variables
declare -xr benchmark_project
declare -xr results_dir
declare -r renamed_artifacts_dir

if [[ -d "$artifacts_benchmarks" && -n "$(ls -A "$artifacts_benchmarks")" ]]; then
    if [[ -n "${CI:-}" ]]; then
        # Auto-delete in CI
        echo "Deleting existing artifacts directory (running in CI)..."
        execute rm -rf "$artifacts_benchmarks"
    else
        declare choice
        choose "The benchmark results directory '$artifacts_benchmarks' already exists. What do you want to do?" \
               choice \
                   "Delete the directory and continue" \
                   "Rename the directory to '$renamed_artifacts_dir' and continue" \
                   "Exit the script" || exit $?

        trace "User selected option: $choice"
        case $choice in
            1)  echo "Deleting the directory '$artifacts_benchmarks'..."
                execute rm -rf "$artifacts_benchmarks"
                ;;
            2)  echo "Renaming the directory '$artifacts_benchmarks' to '$renamed_artifacts_dir'..."
                execute mv "$artifacts_benchmarks" "$renamed_artifacts_dir"
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

trace "Creating artifacts directory(s)..."
execute mkdir -p "$results_dir"

declare -x benchmark_exec_path
get_target_path "$benchmark_project" benchmark_exec_path
declare -xr benchmark_exec_path
trace "Expecting test executable: $benchmark_exec_path"

exit_if_has_errors

# Verify build artifacts exist, if not - rebuild the project (mostly for local runs)
if [[ ! -s $benchmark_exec_path ]]; then
    if ! is_dry_run; then
        warning "Test executable '$benchmark_exec_path' was not found in the artifacts directory. Rebuilding the benchmarks project..."

        update_nuget_sources_with_github_vm2 || error -ec "$err_tool_error" "Updating the NuGet sources with GitHub packages from vm2 failed."
        dotnet_clean "$benchmark_project"    || error -ec "$err_tool_error" "Cleaning the benchmark project failed."
        dotnet_restore "$benchmark_project"  || error -ec "$err_tool_error" "Restoring the benchmark project failed."
        dotnet_build "$benchmark_project"    || error -ec "$err_tool_error" "Building the test project failed."
        [[ -s $benchmark_exec_path ]]        || error -ec "$err_tool_error" "After rebuilding the project, the benchmarks executable '$benchmark_exec_path' was still NOT FOUND."

        exit_if_has_errors
    fi
fi

# Run benchmark with JSON export for Bencher
trace "Running benchmark tests from project '$benchmark_project'..."

benchmark_args=(
    --filter '*'
    --join
    --exporters json markdown
    --memory
    --artifacts "$artifacts_benchmarks"
)

##########################################
### Run the tests with coverage collection
##########################################
declare rc=$success

if [[ "$benchmark_exec_path" == *.dll ]]; then
    trace "Executing benchmark tests: dotnet $benchmark_exec_path ${benchmark_args[*]}"
    dotnet "$benchmark_exec_path" "${benchmark_args[@]}" || rc=$?
else
    # *.exe or *. (Linux)
    trace "Executing benchmark tests: $benchmark_exec_path ${benchmark_args[*]}"
    "$benchmark_exec_path" "${benchmark_args[@]}" || rc=$?
fi

if (( rc != 0 )); then
    error -ec "$err_tool_error" "Tests failed in project '$benchmark_project' with exit code $rc."
    exit "$err_tool_error"
fi

# Verify JSON results were created
json_files=("$results_dir"/*-report-full-compressed.json)
if [[ ! -f "${json_files[0]}" ]]; then
    error -ec "$err_tool_error" "No JSON benchmark reports found in $results_dir"
    exit "$err_tool_error"
fi

trace "Benchmark tests completed successfully. Found JSON benchmark results."
{
    echo "✅ Benchmark tests completed successfully. Generated benchmark results:"
    for file in "${json_files[@]}"; do
        echo "   - $(basename "$file")"
    done
} | to_summary

trace "Processing benchmark results for Bencher.dev upload and GitHub summary report generation..."
# Append markdown benchmark tables to the step summary
md_files=("$results_dir"/*-report-github.md)
if [[ -f "${md_files[0]}" ]]; then
    {
        for file in "${md_files[@]}"; do
            echo ""
            cat "$file"
            echo ""
        done
    } | to_summary
fi

args_to_github_output \
    results_dir
