#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

# shellcheck disable=SC2119

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")
declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -rxa vm2_repositories
declare -rx key_owner

declare -rxi success
declare -rxi err_argument_value
declare -rxi err_tool_error

declare -x _ignore
declare -x dry_run

declare -rix default_repeat=10
declare -rx default_workflow="RebuildBenchHistory.yaml"

declare -x owner=""
declare -xi repeat=${REPEAT:-$default_repeat}
declare -x workflow=$default_workflow

source "$script_dir/rebuild-bench-history.usage.sh"
source "$script_dir/rebuild-bench-history.args.sh"

get_arguments "$@"

# Resolve the GitHub owner: --owner, else $GITHUB_REPOSITORY_OWNER (set by Actions), else derive from this repo's remote.
[[ -n "$owner" ]] || owner="${GITHUB_REPOSITORY_OWNER:-}"
if [[ -z "$owner" ]]; then
    self_root=$(root_working_tree "$script_dir") || true
    if [[ -n "${self_root:-}" ]]; then
        declare -A self_state=()
        get_repo_state "$self_root" self_state false || true
        owner="${self_state[$key_owner]:-}"
    fi
fi

(( repeat >= 1 )) || error -ec "$err_argument_value" "repeat must be a positive integer (got '$repeat')."
[[ -n "$owner" ]] || error -ec "$err_argument_value" "Could not determine the GitHub owner. Pass --owner or set \$GITHUB_REPOSITORY_OWNER."
command -v gh &> "$_ignore" || error -ec "$err_tool_error" "The GitHub CLI 'gh' was not found on PATH."
exit_if_has_errors

declare -rx owner

# Authentication: in a workflow the caller exports the BENCH_DISPATCH_PAT secret as GH_TOKEN; locally, export
# BENCH_DISPATCH_PAT yourself (it is an env var, NOT a repo secret) or rely on the ambient 'gh auth' credentials.
[[ -z "${BENCH_DISPATCH_PAT:-}" ]] || export GH_TOKEN="${GH_TOKEN:-$BENCH_DISPATCH_PAT}"
[[ -n "${GH_TOKEN:-}" ]] || warning "Neither \$GH_TOKEN nor \$BENCH_DISPATCH_PAT is set; relying on the ambient 'gh auth' credentials."

declare -i dispatched=0
declare -i no_bench=0
declare -i failed=0
declare -a dispatched_repos=()
declare name

# Fire-and-forget fan-out: one dispatch per repo. Each repo's own workflow loops $repeat times in its own Actions, so the
# repos run in parallel and this script returns immediately -- nothing to wait on.
for name in "${vm2_repositories[@]}"; do
    # Read-only remote probe for a benchmarks/ directory. Run directly (not via the dry-run-aware wrapper) so --dry-run
    # still reports an accurate target list.
    if ! gh api "repos/$owner/$name/contents/benchmarks" --silent &> "$_ignore"; then
        info "'$owner/$name' has no 'benchmarks/' directory (or is unreachable); skipping."
        no_bench=$(( no_bench + 1 ))
        continue
    fi

    info "▶ Dispatching '$workflow' for '$owner/$name' (repeat=$repeat)..."
    if execute_gh_with_retry 3 5 workflow run "$workflow" --repo "$owner/$name" -f repeat="$repeat"; then
        dispatched=$(( dispatched + 1 ))
        dispatched_repos+=("$owner/$name")
    else
        warning "  Failed to dispatch '$workflow' for '$owner/$name' (is it present on the repo's default branch?)."
        failed=$(( failed + 1 ))
    fi
done

dispatched_list=""
(( ${#dispatched_repos[@]} > 0 )) && dispatched_list=" — ${dispatched_repos[*]}"

# Summary
{
    echo "### Benchmark-history rebuild dispatch (owner=$owner, repeat=$repeat):"
    echo "  dispatched : $dispatched$dispatched_list"
    echo "  no benchmarks/skipped : $no_bench"
    echo "  failed : $failed"
    $dry_run &&
    echo "  (dry run — workflows were NOT dispatched; the benchmarks/ probe still ran)" || true
} | to_summary
