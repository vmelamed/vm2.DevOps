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

source "$lib_dir/gh_core.sh"

# Declare variables defined in the core library.
declare -xr ci
declare -x _ignore
declare -x secret_str
declare -xr key_repo

# Declare error codes defined in the core library
declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_tool_error

# parameters specific to this script only with initial values from environment variables or defaults
declare -x results_dir
declare -x testbed
declare -x repository
declare -x event_name
declare -x ref_name
declare -x head_ref
declare -x pr_number
declare -x pr_base_sha
declare -x max_regression_pct
declare -x max_gen1_collects
declare -x max_gen2_collects
declare -x reset_thresholds

source "$script_dir/upload-bencher-results.usage.sh"
source "$script_dir/upload-bencher-results.args.sh"

get_arguments "$@"

trace "Preparing to upload results to Bencher.dev with max regression threshold of ±${max_regression_pct}%."

# Calculate the regression threshold as a decimal (e.g., 10% -> 0.10)
threshold_decimal=$(echo "scale=4; $max_regression_pct / 100" | bc)

# Compute the Bencher project slug from the repository name, e.g., vmelamed/vm2.DevOps -> vm2-devops
bencher_slug=$(echo "${repository#*/}" | tr '[:upper:]' '[:lower:]' | tr '.' '-')

bencher_static=(
    --project "$bencher_slug"
    --token "$BENCHER_API_TOKEN"
    --testbed "$testbed"
    --adapter c_sharp_dot_net
    # --iter/--fold only matter when more than one result file is uploaded in a single run (Bencher treats each
    # --file as a separate iteration). BenchmarkDotNet's --join normally yields one file, so these are usually
    # inert; when multiple files do appear, median folds them. We avoid mean because Bencher discourages it here.
    --iter 1
    --fold median
    --err
)

threshold_latency=(
    --threshold-measure latency
    --threshold-test percentage
    --threshold-max-sample-size 64
    --threshold-lower-boundary _
    --threshold-upper-boundary "$threshold_decimal"
)

threshold_throughput=(
    --threshold-measure throughput
    --threshold-test percentage
    --threshold-max-sample-size 64
    --threshold-lower-boundary "$threshold_decimal"
    --threshold-upper-boundary _
)

threshold_allocated=(
    --threshold-measure allocated
    --threshold-test percentage
    --threshold-max-sample-size 64
    --threshold-lower-boundary _
    --threshold-upper-boundary "$threshold_decimal"
)

threshold_gen1_collects=(
    --threshold-measure gen1-collects
    --threshold-test static
    --threshold-lower-boundary _
    --threshold-upper-boundary "$max_gen1_collects"
)

threshold_gen2_collects=(
    --threshold-measure gen2-collects
    --threshold-test static
    --threshold-lower-boundary _
    --threshold-upper-boundary "$max_gen2_collects"
)

bencher_args=(
    "${bencher_static[@]}"
    "${threshold_latency[@]}"
    "${threshold_throughput[@]}"
    "${threshold_allocated[@]}"
    "${threshold_gen1_collects[@]}"
    "${threshold_gen2_collects[@]}"
)

# Determine the Bencher branch strategy: a pull request tracks its own ephemeral branch (forked from main with
# main's thresholds cloned onto it, rebuilt fresh every run); a push to a non-main branch accumulates its own
# history across pushes (also forked from main); a push to main is main.
if [[ $event_name == "pull_request" ]]; then
    bencher_args+=(
        --branch "$head_ref"
        --start-point main
        --start-point-clone-thresholds
        --start-point-reset                # rebuilds the branch from the start point every run -- compare "PR vs main"
        --start-point-hash "$pr_base_sha"  # pin the baseline to the exact commit the PR branched from
        --github-actions "$GH_TOKEN"       # authenticate to GitHub for commenting on the PR and creating checks
        --ci-number "$pr_number"
    )
elif [[ $ref_name != "main" ]]; then
    bencher_args+=(
        --branch "$ref_name"
        --start-point main
        --start-point-clone-thresholds
    )
else
    bencher_args+=(
        --branch main
    )
fi

# Only reset thresholds when explicitly requested
if [[ $reset_thresholds == "true" ]]; then
    trace "Resetting Bencher thresholds (reset-thresholds=true)"
    bencher_args+=(--thresholds-reset)
fi

# Add all benchmark result files. The glob MUST be unquoted here so the shell expands it to the matching files --
# quoting it turns the loop into a single iteration over the literal, non-existent pattern string, silently adding
# no --file argument at all.
declare -i _files_added=0
for file in "$results_dir"/*-report-full-compressed.json; do
    if [[ -s "$file" ]]; then
        trace "Adding benchmark result file: $file"
        bencher_args+=(--file "$file")
        (( ++_files_added ))
    fi
done
(( _files_added > 0 )) ||
    exit_with_error -ec "$err_argument_value" "No benchmark result files (*-report-full-compressed.json) found in '$results_dir'."

if is_verbose; then
    trace "Looking for benchmark result files matching: $results_dir/*-report-full-compressed.json:"
    trace "$(ls -l "$results_dir"/*-report-full-compressed.json)"

    declare -a sanitized_bencher_args=("${bencher_args[@]}")

    for i in "${!sanitized_bencher_args[@]}"; do
        if [[ "${sanitized_bencher_args[$i]}" == "--token" ||
              "${sanitized_bencher_args[$i]}" == "--github-actions" ]] &&
           (( i + 1 < ${#sanitized_bencher_args[@]} )); then
            sanitized_bencher_args[i + 1]="$secret_str"
        fi
    done

    trace "Running command: bencher run ${sanitized_bencher_args[*]}"
fi

# Capture Bencher's output so we can echo it to the log and tell threshold alerts apart from transport failures.
# set +e so a non-zero bencher (alerts via --err, or a real failure) does not abort the script before we read its
# exit code.
set +e
bencher_output=$(execute bencher run "${bencher_args[@]}" 2>&1); bencher_rc=$?
set -e
if is_dry_run; then
    # the capture swallowed execute's dry-run$ line: show it, it is the point of a dry run
    printf '%s\n' "$bencher_output" >&2
    info "The benchmark results in '$results_dir' would have been uploaded to bencher.dev."
    exit "$success"
fi

printf '%s\n' "$bencher_output"   # surface bencher's output in the job log

if (( bencher_rc == 0 )); then
    info "The benchmark results in '$results_dir' were successfully uploaded to bencher.dev."
elif [[ $bencher_output == *"Alerts detected"* ]]; then
    warning "The benchmark results in '$results_dir' were successfully uploaded to bencher.dev but threshold alerts were detected."
    exit "$bencher_rc"
else
    exit_with_error -ec "$err_tool_error" "Bencher run failed uploading the benchmark results in '$results_dir' before completing successfully."
fi
