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

declare -xr default_configuration="Release"
declare -ixr default_min_coverage_pct=80
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"

declare -x benchmark_project=${BENCHMARK_PROJECT:-}
declare -x configuration=${CONFIGURATION:-"${default_configuration}"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"${default_minver_tag_prefix}"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"${default_minver_prerelease_id}"}
declare -x artifacts_dir=${ARTIFACTS_DIR:-"${BENCHMARK_PROJECT%/*}/BenchmarkArtifacts"}

source "$script_dir/run-benchmarks.usage.sh"
source "$script_dir/run-benchmarks.args.sh"

get_arguments "$@"

is_safe_existing_path "$benchmark_project" || true
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
validate_minverTagPrefix "$minver_tag_prefix" || true
is_safe_minverPrereleaseId "$minver_prerelease_id" || true
is_safe_path "$artifacts_dir" || true

exit_if_has_errors

benchmark_name=$(basename "${benchmark_project%.*}")            # the base name of the benchmark project (without the path and file extension)
benchmark_dir=$(realpath -e "$(dirname "$benchmark_project")")  # the directory of the benchmark project
artifacts_dir="${artifacts_dir:-"$benchmark_dir/BenchmarkArtifacts"}"
results_dir="$artifacts_dir/results"
renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"

# Freeze variables
declare -xr benchmark_project
declare -xr benchmark_name
declare -xr benchmark_dir
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
                    "The benchmarks results directory '$artifacts_dir' already exists. What do you want to do?" \
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

# Determine the benchmark executable paths. TODO: determine RID and use it to find the correct path
benchmark_executables_pathname="${benchmark_dir}/bin/${configuration}/net10.0/${benchmark_name}"
os_name="$(uname -s)"
if [[ "$os_name" == "Windows_NT" || "$os_name" == *MINGW* || "$os_name" == *MSYS* ]]; then
    benchmark_exe_path="${benchmark_executables_pathname}.exe"
else
    benchmark_exe_path="${benchmark_executables_pathname}"
fi
benchmark_dll_path="${benchmark_executables_pathname}.dll"

declare -r benchmark_executables_pathname
declare -r benchmark_dll_path
declare -r benchmark_exe_path

# Verify executables exist
# shellcheck disable=SC2154 # variable is referenced but not assigned.
if [[ (! -f "${benchmark_exe_path}" || ! -f "${benchmark_dll_path}") && "$dry_run" != "true" ]]; then
    error "Cached benchmark executables '${benchmark_exe_path}' or '${benchmark_dll_path}' were not found."
    exit 2
fi

# Run benchmarks with JSON export for Bencher
trace "Running benchmark tests in project '$benchmark_project' with build configuration '$configuration'..."
if ! execute dotnet run \
        --project "$benchmark_project" \
        --configuration "$configuration" \
        --no-build \
        --filter '*' \
        --memory \
        --exporters JSON \
        --artifacts "$artifacts_dir" \
        --join \
        -p:preprocessor_symbols="$preprocessor_symbols" \
        -p:MinVerTagPrefix="$minver_tag_prefix" \
        -p:MinVerPrereleaseIdentifiers="$minver_prerelease_id"; then
    error "Benchmarks failed in project '$benchmark_project'."
    exit 2
fi

# Verify JSON results were created
# shellcheck disable=SC2154 # variable is referenced but not assigned.
if [[ $dry_run != "true" ]]; then
    json_files=("$results_dir"/*-report.json)
    if [[ ! -f "${json_files[0]}" ]]; then
        error "No JSON benchmark reports found in $results_dir"
        exit 2
    fi

    {
        echo "✅ Benchmark tests completed successfully"
        echo "✅ Benchmark results generated:"
        for file in "${json_files[@]}"; do
            echo "   - $(basename "$file")"
        done
    } | to_summary
fi

to_github_output results_dir
