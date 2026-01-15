#!/bin/bash
set -euo pipefail

declare -xr this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

source "$script_dir/_common_github.sh"

declare -x bm_project=${BM_PROJECT:-}
declare -x configuration=${CONFIGURATION:="Release"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x artifacts_dir=${ARTIFACTS_DIR:-}

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

solution_dir="$(realpath -e "$(dirname "$bm_project")/../..")"
artifacts_dir=$(realpath -m "${artifacts_dir:-"$solution_dir/BmArtifacts"}")
results_dir="$artifacts_dir/results"

declare -r solution_dir
declare -r artifacts_dir
declare -r results_dir

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
        /p:DefineConstants="$preprocessor_symbols"; then
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
        echo "✅ Benchmark results generated:"
        for file in "${json_files[@]}"; do
            echo "   - $(basename "$file")"
        done
    } | tee -a "$github_step_summary"
fi

info "✅ Benchmarks completed successfully" | tee -a "$github_step_summary"

to_github_output results_dir
