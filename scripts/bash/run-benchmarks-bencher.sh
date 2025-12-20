#!/bin/bash
set -euo pipefail

# Script to run BenchmarkDotNet benchmarks for Bencher.dev integration
# This is a simplified version that only runs benchmarks and exports JSON

declare -xr this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

source "$script_dir/_common.sh"

declare -x bm_project=${BM_PROJECT:-}
declare -x configuration=${CONFIGURATION:="Release"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-" "}
declare -x artifacts_dir=${ARTIFACTS_DIR:-}
declare -x cached_dependencies=${CACHED_DEPENDENCIES:-false}
declare -x cached_artifacts=${CACHED_ARTIFACTS:-false}

source "$script_dir/run-benchmarks.usage.sh"
source "$script_dir/run-benchmarks.utils.sh"

get_arguments "$@"

if [[ ! -s "$bm_project" ]]; then
    usage "The specified benchmark project file '$bm_project' does not exist." >&2
    exit 2
fi

declare -r bm_project
declare -r configuration
declare -r preprocessor_symbols
declare -r cached_dependencies
declare -r cached_artifacts

solution_dir="$(realpath -e "$(dirname "$bm_project")/../..")"
artifacts_dir=$(realpath -m "${artifacts_dir:-"$solution_dir/BmArtifacts"}")
results_dir="$artifacts_dir/results"

declare -r solution_dir
declare -r artifacts_dir
declare -r results_dir

dump_all_variables

# Create artifacts directory
trace "Creating directory(s)..."
execute mkdir -p "$results_dir"

# Determine benchmark executable paths
bm_base_path="$(dirname "$bm_project")/bin/${configuration}/net10.0/$(basename "${bm_project%.*}")"
bm_dll_path="${bm_base_path}.dll"
os_name="$(uname -s)"
if [[ "$os_name" == "Windows_NT" || "$os_name" == *MINGW* || "$os_name" == *MSYS* ]]; then
    bm_exe_path="${bm_base_path}.exe"
else
    bm_exe_path="${bm_base_path}"
fi
declare -r bm_base_path
declare -r bm_dll_path
declare -r bm_exe_path

# Restore dependencies if not cached
trace "Restore dependencies if not cached"
if [[ $cached_dependencies != "true" ]]; then
    execute dotnet restore
fi

# Build if not cached
trace "Build if not cached"
if [[ $cached_artifacts != "true" ]]; then
    execute dotnet build  \
        --project "$bm_project" \
        --configuration "$configuration" \
        --no-restore \
        /p:DefineConstants="$preprocessor_symbols"
fi

# Verify executables exist
# shellcheck disable=SC2154
if [[ (! -f "${bm_exe_path}" || ! -f "${bm_dll_path}") && "$dry_run" != "true" ]]; then
    echo "❌ Benchmark executables '${bm_exe_path}' or '${bm_dll_path}' were not found." | tee -a "$GITHUB_STEP_SUMMARY" >&2
    exit 2
fi

# Run benchmarks with JSON export for Bencher
trace "Running benchmark tests in project '$bm_project' with build configuration '$configuration'..."
execute dotnet run \
    --project "$bm_project" \
    --configuration "$configuration" \
    --no-build \
    --filter '*' \
    --memory \
    --exporters JSON \
    --artifacts "$artifacts_dir"

# Verify JSON results were created
# shellcheck disable=SC2154
if [[ $dry_run != "true" ]]; then
    json_files=("$results_dir"/*-report.json)
    if [[ ! -f "${json_files[0]}" ]]; then
        echo "❌ No JSON benchmark reports found in $results_dir" | tee -a "$GITHUB_STEP_SUMMARY" >&2
        exit 2
    fi

    echo "✅ Benchmark results generated:" | tee -a "$GITHUB_STEP_SUMMARY"
    for file in "${json_files[@]}"; do
        echo "   - $(basename "$file")" | tee -a "$GITHUB_STEP_SUMMARY"
    done
fi

echo "✅ Benchmarks completed successfully" | tee -a "$GITHUB_STEP_SUMMARY"
sync
