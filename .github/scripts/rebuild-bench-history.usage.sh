#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed


declare -xr common_args_usage
declare -xr script_name

function usage_text()
{
    (( $# ==1 ))    || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage:
  $script_name [--<long option> <value> | -<short option> <value> | --<long switch> | -<short switch> ]*

Fans out a benchmark-history rebuild across all vm2 repositories that have a 'benchmarks/' directory. For each such repo it
triggers that repo's 'RebuildBenchHistory.yaml' workflow (via 'gh workflow run -f repeat=N'), which re-records the benchmark
results to Bencher.dev N times. Fire-and-forget: it dispatches the cloud workflows and returns immediately -- the runs proceed
on GitHub's runners in parallel, so there is nothing to wait on.

Repositories are taken from the \$vm2_repositories list; the 'benchmarks/' directory is detected remotely via 'gh api' (no local
clones are needed), so the script runs identically from a CLI and from a GitHub Actions workflow.

Authentication: the script uses \$GH_TOKEN (or \$BENCH_DISPATCH_PAT if set) for 'gh'. In a workflow, the caller exports the
BENCH_DISPATCH_PAT repository secret as GH_TOKEN. Locally, export BENCH_DISPATCH_PAT yourself (it is an environment variable,
NOT a repository secret) or rely on the ambient 'gh auth login' credentials. The token needs 'Actions: write' (to dispatch)
and 'Contents: read' (for the benchmarks/ probe) on the target repositories.

Options:
  -o, --owner                   The GitHub owner/organization of the target repositories
                                Initial value from \$GITHUB_REPOSITORY_OWNER, or derived from this repository's origin remote
  -n, --repeat                  How many independent runs to record per benchmark (positive integer)
                                Initial value from \$REPEAT or default 10
  -w, --workflow                The per-repo workflow file to dispatch in each target repository
                                Default 'RebuildBenchHistory.yaml'

Environment Variables:
  BENCH_DISPATCH_PAT            Fine-grained PAT ('Actions: write' + 'Contents: read' on the target repos) used to
                                authenticate 'gh'. Optional - falls back to \$GH_TOKEN or the ambient 'gh auth'.
  GH_TOKEN                      Token used by 'gh' (set automatically from BENCH_DISPATCH_PAT when that is provided)
  GITHUB_REPOSITORY_OWNER       The GitHub owner of the target repositories (set automatically inside Actions)
  REPEAT                        How many independent runs to record per benchmark
$_common_args
EOF
}
