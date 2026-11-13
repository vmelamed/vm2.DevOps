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

# vm2 core lib
source "$lib_dir/gh_core.sh"

# vm2 core lib exit codes
declare -xri success
declare -xri err_argument_value

# vm2 core lib constants
declare -xra vm2_repositories

# vm2 core lib defaults

# vm2 core lib variables
declare -x _ignore

# vm2 core lib constants
declare -xr key_artifacts_path

# this script's components
source "$script_dir/rebuild-bench-history.usage.sh"
source "$script_dir/rebuild-bench-history.args.sh"

# this script's arguments
get_arguments "$@"
declare -xr owner
declare -xri repeat
declare -xr workflow

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
    is_dry_run &&
    echo "  (dry run — workflows were NOT dispatched; the benchmarks/ probe still ran)" || true
} | to_summary
