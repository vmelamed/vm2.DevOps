#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
lib_dir="$script_dir/../../../scripts/bash/lib"

declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -x bm_project=${BM_PROJECT:-}
declare -x configuration=${CONFIGURATION:-"Release"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-'v'}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"preview.0"}
declare -x artifacts_dir=${ARTIFACTS_DIR:-}

source "$script_dir/run-benchmarks.usage.sh"
source "$script_dir/run-benchmarks.utils.sh"

get_arguments "$@"

if [[ ! -s "$bm_project" ]]; then
    usage false "The specified benchmark project file '$bm_project' does not exist." >&2
    exit 2
fi

is_safe_path "$bm_project" || true
is_safe_input "$configuration" || true
is_safe_input "$preprocessor_symbols" || true
is_safe_input "$minver_tag_prefix" || true
is_safe_input "$minver_prerelease_id" || true
is_safe_path "$artifacts_dir" || true

# Freeze variables
declare -xr bm_project
declare -xr configuration
declare -xr preprocessor_symbols
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr artifacts_dir

# Determine solution directory and artifacts directory
solution_dir="$(realpath -e "$(dirname "$bm_project")/../..")"
artifacts_dir=$(realpath -m "${artifacts_dir:-"$solution_dir/BmArtifacts"}")
results_dir="$artifacts_dir/results"

declare -xr solution_dir
declare -xr artifacts_dir
declare -xr results_dir

renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"
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

dump_all_variables
exit_if_has_errors

# Create artifacts directory
trace "Creating directory(s)..."
execute mkdir -p "$results_dir"

# Determine benchmark executable paths
bm_base_path="$(dirname "$bm_project")/bin/${configuration}/net10.0/$(basename "${bm_project%.*}")"
bm_dll_path="${bm_base_path}.dll"
os_name="$(uname -s)"
if [[ "$os_name" == "Windows_NT" || "$os_name" == *MINGW* || "$os_name" == *MSYS* ]]; then
    bm_exec_path="${bm_base_path}.exe"
else
    bm_exec_path="${bm_base_path}"
fi
declare -r bm_base_path
declare -r bm_dll_path
declare -r bm_exec_path

# Verify executables exist
# shellcheck disable=SC2154 # variable is referenced but not assigned.
if [[ (! -f "${bm_exec_path}" || ! -f "${bm_dll_path}") && "$dry_run" != "true" ]]; then
    error "Cached benchmark executables '${bm_exec_path}' or '${bm_dll_path}' were not found."
    exit 2
fi

# Run benchmarks with JSON export for Bencher
trace "Running benchmark tests in project '$bm_project' with build configuration '$configuration'..."
if ! execute dotnet run \
        --project "$bm_project" \
        --configuration "$configuration" \
        --no-build \
        --filter '*' \
        --memory \
        --exporters JSON \
        --artifacts "$artifacts_dir" \
        /p:DefineConstants="$preprocessor_symbols" \
        /p:MinVerTagPrefix="$minver_tag_prefix" \
        /p:MinVerPrereleaseIdentifiers="$minver_prerelease_id"; then
    error "Benchmarks failed in project '$bm_project'."
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
        echo "✅ Benchmarks completed successfully"
        echo "✅ Benchmark results generated:"
        for file in "${json_files[@]}"; do
            echo "   - $(basename "$file")"
        done
    } | summary
fi

to_github_output results_dir
