#!/bin/bash
set -euo pipefail

this_script=${BASH_SOURCE[0]}
declare -xr this_script

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

source "$script_dir/_common.sh"

declare -x bm_project=${BM_PROJECT:-}
declare -x configuration=${CONFIGURATION:="Release"}
declare -x defined_symbols=${DEFINED_SYMBOLS:-" "}
declare -ix max_regression_pct=${MAX_REGRESSION_PCT:-10}
declare -x force_new_baseline=${FORCE_NEW_BASELINE:-false}
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
declare -r defined_symbols
declare -r max_regression_pct
declare -r force_new_baseline

solution_dir="$(realpath -e "$(dirname "$bm_project")/../..")" # assuming <solution-root>/benchmarks/<benchmark-project>/benchmark-project.csproj
artifacts_dir=$(realpath -m "${artifacts_dir:-"$solution_dir/BmArtifacts"}")  # ensure it's an absolute path
results_dir="$artifacts_dir/results"
summaries_dir=$(realpath -m "${SUMMARIES_DIR:-"$artifacts_dir/summaries"}")  # ensure it's an absolute path

baseline_dir=$(realpath -m "${BASELINE_DIR:-"$artifacts_dir/baseline"}")  # ensure it's an absolute path
baseline_summaries_dir="$baseline_dir/summaries"

declare -r solution_dir
declare -r artifacts_dir
declare -rx results_dir
declare -r summaries_dir
declare -r baseline_dir
declare -r baseline_summaries_dir

renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"
declare -r renamed_artifacts_dir

dump_all_variables

if [[ -d "$artifacts_dir" && -n "$(ls -A "$artifacts_dir")" ]]; then
    choice=$(choose \
                "The benchmark results directory '$artifacts_dir' already exists. What do you want to do?" \
                    "Clobber the directory '$artifacts_dir' with the new contents" \
                    "Move the contents of the directory to '$renamed_artifacts_dir', except for the base line '$baseline_dir', and continue" \
                    "Delete the contents of the directory, except for the base line '$baseline_dir', and continue" \
                    "Exit the script") || exit $?

    trace "User selected option: $choice"
    case $choice in
        1)  echo "Clobbering the directory '$artifacts_dir' with the new contents..."
            ;;
        2)  echo "Moving the contents of the directory '$artifacts_dir' to '$renamed_artifacts_dir', except for the base line '$baseline_dir' (if exists)..."
            execute mkdir -p "$renamed_artifacts_dir"
            execute mv "$summaries_dir" "$renamed_artifacts_dir"
            execute mv "$results_dir" "$renamed_artifacts_dir"
            execute mv "$artifacts_dir/*.log" "$renamed_artifacts_dir"
            ;;
        3)  echo "Deleting the contents of the directory, except for the base line '$baseline_dir'...";
            execute rm -rf "$summaries_dir"
            execute rm -rf "$results_dir"
            execute rm -rf "$artifacts_dir/*.log"
            ;;
        4)  echo "Exiting the script.";
            exit 0
            ;;
        *)  echo "Invalid option $choice. Exiting." >&2;
            exit 2
            ;;
    esac
fi

trace "Creating directory(s)..."
execute mkdir -p "$summaries_dir"

trace "Running benchmark tests in project '$bm_project' with build configuration '$configuration'..."
execute mkdir -p "$artifacts_dir"
execute dotnet run \
    /p:DefineConstants="$defined_symbols" \
    --project "$bm_project" \
    --configuration "$configuration" \
    --filter '*' \
    --memory \
    --exporters JSON \
    --artifacts "$artifacts_dir"

if ! command -v jq >"$_ignore" 2>&1; then
    execute sudo apt-get update && sudo apt-get install -y jq
    echo "jq successfully installed."
fi

# shellcheck disable=SC2154

if [[ $dry_run != "true" ]]; then

    declare -a files

    mapfile -t -d " " files < <(list_of_files "$results_dir/*-report.json")

    if [[ ${#files[@]} == 0 ]]; then
        echo "❌ No JSON reports found." | tee >> "$GITHUB_STEP_SUMMARY" >&2
        exit 2
    fi
    for f in "${files[@]}"; do
        sf=$(sed -nE 's/(.*)-report.json/\1-summary.json/p' <<< "$(basename "$f")")
        jq -f "$script_dir/summary.jq" "$f" > "$summaries_dir/$sf"
    done
fi

trace "Sum up the means from all summary files"
mapfile -t -d " " files < <(list_of_files "$summaries_dir/*-summary.json")
if [[ ${#files[@]} == 0 ]]; then
    echo "❌ No current benchmark result JSON files found." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    exit 2
fi
sum_cur=0
for f in "${files[@]}"; do
    VAL=$(jq '( .Totals.Mean // 0)' "$f")
    sum_cur=$(( sum_cur + VAL ))
done
if (( sum_cur == 0 )); then
    echo "❌ Current sum is invalid ($sum_cur)." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    exit 2
fi

trace "Sum up the means from all baseline summary files"
mapfile -t -d " " files < <(list_of_files "$baseline_summaries_dir/*-summary.json")
if [[ ${#files[@]} == 0 ]]; then
    echo "❌ Baseline summary reports were not found at $baseline_summaries_dir." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    if is_defined "GITHUB_ENV"; then
        echo "⚠️ Creating a new baseline from the current results." | tee >> "$GITHUB_STEP_SUMMARY"
        # shellcheck disable=SC2154
        echo "FORCE_NEW_BASELINE=true" >> "$GITHUB_ENV"
    fi
    exit 0
fi
sum_base=0
for f in "${files[@]}"; do
    VAL=$(jq '( .Totals.Mean // 0)' "$f")
    sum_base=$(( sum_base + VAL ))
done
if (( sum_base == 0 )); then
    echo "❌ Baseline sum is invalid ($sum_base)." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    exit 2
fi

trace "Calculating the percent change vs baseline"
pct=$(( (sum_cur - sum_base) * 100 / sum_base ))
echo "Change in performance vs baseline: $pct% (allowed: $max_regression_pct%)" | tee >> "$GITHUB_STEP_SUMMARY"

if (( pct > max_regression_pct )); then
    echo "❌ Performance regression exceeds threshold" | tee >> "$GITHUB_STEP_SUMMARY" >&2
    if [[ $force_new_baseline == "true" ]] && is_defined "GITHUB_ENV"; then
        echo "❌ Significant regression of $pct% over baseline. Updating the baseline." | tee >> "$GITHUB_STEP_SUMMARY"
        # shellcheck disable=SC2154
        echo "FORCE_NEW_BASELINE=true" | tee >> "$GITHUB_ENV"
        sync
        exit 0
    fi
    echo "⚠️ If this was expected, please update the baseline by setting the variable 'FORCE_NEW_BASELINE=true'." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    sync
    exit 2
elif (( pct >= 0 )); then
    echo "✅ Performance regression within acceptable threshold." | tee >> "$GITHUB_STEP_SUMMARY"
elif (( pct < 0 )); then
    pct=$(( -pct ))
    if (( pct >= max_regression_pct )); then
        if is_defined "GITHUB_ENV"; then
            echo "✅ Significant improvement of $pct% below the baseline. Updating the baseline." | tee >> "$GITHUB_STEP_SUMMARY"
            # shellcheck disable=SC2154
            echo "FORCE_NEW_BASELINE=true" | tee >> "$GITHUB_ENV"
        fi
    else
        echo "✅ Improvement of $pct% below the baseline." | tee >> "$GITHUB_STEP_SUMMARY"
    fi
fi
sync
