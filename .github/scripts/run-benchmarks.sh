#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2119

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
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

declare -rix default_min_coverage_pct=80
declare -rx default_minver_tag_prefix='v'
declare -rx default_minver_prerelease_id="preview.0"

declare -x benchmark_project=""
declare -x configuration=${CONFIGURATION:-"Release"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"${default_minver_tag_prefix}"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"${default_minver_prerelease_id}"}
declare -x artifacts_dir=${ARTIFACTS_DIR:-"./BenchmarkArtifacts"}

source "$script_dir/run-benchmarks.usage.sh"
source "$script_dir/run-benchmarks.args.sh"

get_arguments "$@"
benchmark_project=${benchmark_project:-"$BENCHMARK_PROJECT"}

is_safe_existing_path "$benchmark_project" || true
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
validate_semverTagComponents "$minver_tag_prefix" "$minver_prerelease_id" || true
is_safe_path "$artifacts_dir" || true

exit_if_has_errors

results_dir="$artifacts_dir/results"
renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"

# Freeze variables
declare -xr benchmark_project
declare -xr configuration
declare -xr preprocessor_symbols
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr artifacts_dir
declare -xr results_dir
declare -r renamed_artifacts_dir

if [[ -d "$artifacts_dir" && -n "$(ls -A "$artifacts_dir")" ]]; then
    if [[ -n "${CI:-}" ]]; then
        # Auto-delete in CI
        echo "Deleting existing artifacts directory (running in CI)..."
        execute rm -rf "$artifacts_dir"
    else
        choice=$(choose \
                    "The benchmark results directory '$artifacts_dir' already exists. What do you want to do?" \
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

trace "Creating artifacts directory(s)..."
execute mkdir -p "$results_dir"

declare rc=$success
benchmark_exe_path=$(assembly_path "$benchmark_project") || rc=$?
declare -rx benchmark_exe_path

((rc <= failure)) || exit_if_has_errors

if (( rc == failure )); then
    if ! $dry_run; then
        warning "Cached benchmark executable '${benchmark_exe_path}' was not found. Rebuilding the benchmark project"
        execute dotnet clean "$benchmark_project" --configuration "$configuration" || true
        execute dotnet build "$benchmark_project" \
                --verbosity detailed \
                --configuration "$configuration" \
                -p:preprocessor_symbols="$preprocessor_symbols" \
                -p:MinVerTagPrefix="$minver_tag_prefix" \
                -p:MinVerPrereleaseIdentifiers="$minver_prerelease_id" 2>&1 |
                extractDotnetBuildInfo |
                displayDotnetBuildSummary |
                to_summary || true # prevent pipefail from exiting before we can capture the exit code
        rc=${PIPESTATUS[0]}
        [[ $rc == "$success" ]] || error -ec "$err_tool_error" "Building '$benchmark_project' failed."
        [[ -s $benchmark_exe_path ]] || error -ec "$err_tool_error" "Benchmark executable '$benchmark_exe_path' was still NOT FOUND after rebuilding the project."
        exit_if_has_errors
    fi
else
    chmod +x "$benchmark_exe_path" || error "Failed to make test executable '$benchmark_exe_path' executable."
    exit_if_has_errors
fi

# Run benchmark with JSON export for Bencher
trace "Running benchmark tests in project '$benchmark_project' with build configuration '$configuration'..."

benchmark_args=(
    --filter '*'
    --join
    --exporters json markdown
    --memory
    --artifacts "$artifacts_dir"
)

if ! execute "${benchmark_exe_path}" "${benchmark_args[@]}"; then
    error -ec "$err_logic_error" "Benchmark failed in project '$benchmark_project'."
    exit 2
fi

# Verify JSON results were created
# shellcheck disable=SC2154 # variable is referenced but not assigned.
if ! $dry_run; then
    json_files=("$results_dir"/*-report-full-compressed.json)
    if [[ ! -f "${json_files[0]}" ]]; then
        error -ec "$err_tool_error" "No JSON benchmark reports found in $results_dir"
        exit 2
    fi

    trace "Benchmark tests completed successfully. Found JSON benchmark results."
    # shellcheck disable=SC2119
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
fi

args_to_github_output \
    results_dir
