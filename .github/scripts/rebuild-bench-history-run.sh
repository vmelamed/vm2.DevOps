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

# core lib
source "$lib_dir/gh_core.sh"

# core lib exit codes
declare -xri err_logic_error

# core lib constants

# core lib defaults

# core lib variables
declare -x preprocessor_symbols
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x artifacts

declare BENCHER_API_TOKEN

source "$script_dir/rebuild-bench-history-run.usage.sh"
source "$script_dir/rebuild-bench-history-run.args.sh"

# this script arguments
get_arguments "$@"
declare -xra benchmark_projects

declare -xr bencher_project
declare -xr bencher_testbed
declare -xr bencher_branch
declare -xr bencher_adapter
declare -xri repeat

# this script variables
declare -x artifacts_benchmarks_dir
declare -x results_dir

artifacts_benchmarks_dir=$artifacts/benchmarks
results_dir="$artifacts_benchmarks_dir/results"

readonly artifacts_benchmarks_dir
readonly results_dir

# Re-record each benchmark project $repeat times. Each iteration is an independent process run, so the recorded spread
# captures the real run-to-run variance of the runner -- exactly the history a statistical threshold needs to learn "normal".
declare -i uploaded=0
declare -ri total=$(( ${#benchmark_projects[@]} * repeat ))
declare project

for project in "${benchmark_projects[@]}"; do
    for (( i=1; i <= repeat; i++ )); do
        echo "▶ [$project] run $i of $repeat (Bencher branch '$bencher_branch')..." | to_stdout

        if ! run-benchmarks.sh \
                "$project" \
                --define "$preprocessor_symbols" \
                --minver-tag-prefix "$minver_tag_prefix" \
                --minver-prerelease-id "$minver_prerelease_id"; then
            warning "Benchmark run $i of '$project' failed; skipping the Bencher upload for this iteration."
            continue
        fi

        json_files=("$results_dir"/*-report-full-compressed.json)
        if [[ ! -f "${json_files[0]}" ]]; then
            warning "No JSON results found after run $i of '$project' in '$results_dir'; skipping the Bencher upload."
            continue
        fi

        bencher_args=(
            --project "$bencher_project"
            --token "$BENCHER_API_TOKEN"
            --testbed "$bencher_testbed"
            --adapter "$bencher_adapter"
            --branch "$bencher_branch"
        )
        for f in "${json_files[@]}"; do
            [[ -s "$f" ]] && bencher_args+=(--file "$f")
        done

        # Record-only: deliberately NO --threshold-* and NO --err. We are establishing the baseline, so a noisy point
        # must never fail the job and halt the loop.
        if execute bencher run "${bencher_args[@]}"; then
            uploaded=$(( uploaded + 1 ))
            info "Recorded data point $i of $repeat for '$project'."
        else
            warning "Bencher upload failed for run $i of '$project' (continuing with the remaining runs)."
        fi
    done
done

{
    echo "### 📈 Benchmark history rebuild"
    echo ""
    echo "Projects (${#benchmark_projects[@]}): $(printf '%s ' "${benchmark_projects[@]}")"
    echo "Bencher: **$bencher_project** · testbed **$bencher_testbed** · branch **$bencher_branch**"
    echo "Recorded **$uploaded** of **$total** runs ($repeat per project)."
} | to_summary

(( uploaded > 0 )) || error "No data points were recorded to Bencher." -ec "$err_logic_error"

exit_if_has_errors

args_to_github_output artifacts
