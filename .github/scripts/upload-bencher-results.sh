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
declare -x secret_str
declare -xr key_repo

# Declare error codes defined in the core library
declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_tool_error

declare -xri default_max_regression_pct=20
declare -xri default_max_gen1_collects=2
declare -xri default_max_gen2_collects=1

# parameters specific to this script only with initial values from environment variables or defaults
declare -x results_dir=${RESULTS_DIR:-}
declare -x testbed=${TESTBED:-}
declare -x repository=${REPOSITORY:-"${GITHUB_REPOSITORY:-}"}
declare -x event_name=${EVENT_NAME:-"${GITHUB_EVENT_NAME:-}"}
declare -x ref_name=${REF_NAME:-"${GITHUB_REF_NAME:-}"}
declare -x head_ref=${HEAD_REF:-"${GITHUB_HEAD_REF:-}"}
declare -x pr_number=${PR_NUMBER:-}
declare -x pr_base_sha=${PR_BASE_SHA:-}
declare -xi max_regression_pct=${MAX_REGRESSION_PCT:-"$default_max_regression_pct"}
declare -xi max_gen1_collects=${MAX_GEN1_COLLECTS:-"$default_max_gen1_collects"}
declare -xi max_gen2_collects=${MAX_GEN2_COLLECTS:-"$default_max_gen2_collects"}
declare -x reset_thresholds=${RESET_THRESHOLDS:-false}

source "$script_dir/upload-bencher-results.usage.sh"
source "$script_dir/upload-bencher-results.args.sh"

get_arguments "$@"

# Sensible standalone defaults for GitHub-context values that otherwise only exist automatically
# inside GitHub Actions -- every vm2.DevOps CI script must also run cleanly from a developer
# machine, so fall back to the local git remote/branch instead of forcing these to be typed in.
[[ -n $event_name ]] || event_name="push"
[[ -n $testbed ]]    || testbed="local"

if [[ -z $repository ]]; then
    declare _repo_root
    _repo_root=$(git rev-parse --show-toplevel 2>"$_ignore") || true
    if [[ -n ${_repo_root:-} ]]; then
        declare -A _repo_state=()
        get_repo_state "$_repo_root" _repo_state false || true
        repository=${_repo_state[$key_repo]:-}
    fi
fi

[[ -n $ref_name ]] || ref_name=$(git branch --show-current 2>"$_ignore") || true

# validate the values of the variables. results_dir is NOT run through is_safe_path/is_safe_existing_path: those
# reject absolute paths by design (the framework's convention for user-facing --artifacts-path-style inputs), but
# this value is an internal, already-resolved absolute path handed off from run-benchmarks.sh's own output, not a
# raw CLI/env path a caller is expected to type in relative form.
[[ -n $results_dir ]]                       || error -ec "$err_missing_argument" "The results directory is required."
[[ -d $results_dir ]]                       || error -ec "$err_argument_value" "The results directory '$results_dir' is not a directory."
[[ -n $testbed ]]                           || error -ec "$err_missing_argument" "--testbed is required."
[[ $repository == */* ]]                    || error -ec "$err_argument_value" "--repository must be in 'owner/repo' form (provided '${repository:-<none>}')."
[[ -n $event_name ]]                        || error -ec "$err_missing_argument" "--event-name is required."
[[ -n $ref_name ]]                          || error -ec "$err_missing_argument" "--ref-name is required."
is_safe_max_regression_pct "$max_regression_pct" || true
is_safe_integer "$max_gen1_collects"        || true
(( max_gen1_collects >= 0 ))                || error -ec "$err_argument_value" "--max-gen1-collects must be a non-negative integer (got '$max_gen1_collects')."
is_safe_integer "$max_gen2_collects"        || true
(( max_gen2_collects >= 0 ))                || error -ec "$err_argument_value" "--max-gen2-collects must be a non-negative integer (got '$max_gen2_collects')."
is_safe_boolean "$reset_thresholds"         || true

if [[ $event_name == "pull_request" ]]; then
    [[ -n $head_ref ]]    || error -ec "$err_missing_argument" "--head-ref is required when --event-name is 'pull_request'."
    [[ -n $pr_number ]]   || error -ec "$err_missing_argument" "--pr-number is required when --event-name is 'pull_request'."
    [[ -n $pr_base_sha ]] || error -ec "$err_missing_argument" "--pr-base-sha is required when --event-name is 'pull_request'."
    [[ -n ${GH_TOKEN:-} ]] || error -ec "$err_missing_argument" "The GH_TOKEN environment variable is required when --event-name is 'pull_request'."
fi

[[ -n ${BENCHER_API_TOKEN:-} ]] || error -ec "$err_missing_argument" "The BENCHER_API_TOKEN environment variable is required."

exit_if_has_errors

# freeze the parameters
declare -xr results_dir
declare -xr testbed
declare -xr repository
declare -xr event_name
declare -xr ref_name
declare -xr head_ref
declare -xr pr_number
declare -xr pr_base_sha
declare -xri max_regression_pct
declare -xri max_gen1_collects
declare -xri max_gen2_collects
declare -xr reset_thresholds

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
(( _files_added > 0 )) || error -ec "$err_argument_value" "No benchmark result files (*-report-full-compressed.json) found in '$results_dir'."
exit_if_has_errors

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
bencher_output=$(bencher run "${bencher_args[@]}" 2>&1); bencher_rc=$?
set -e

printf '%s\n' "$bencher_output"   # surface bencher's output in the job log

if (( bencher_rc == 0 )); then
    info "The upload to Bencher completed successfully with no alerts."
elif [[ $bencher_output == *"Alerts detected"* ]]; then
    warning "Bencher uploaded results but detected threshold alerts."
    remove_traps
    exit "$bencher_rc"
else
    exit_with_error -ec "$err_tool_error" "Bencher run failed before completing successfully."
fi
