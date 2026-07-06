#!/usr/bin/env bash

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

function usage_text()
{
    local long_text=$1
    local switches=""
    local vars=""

    if $long_text; then
        switches=$'\n'"Switches:"$'\n'"$common_switches"
        vars=$common_vars
    fi

    cat << EOF
Usage: $script_name [--<long option> <value> | -<short option> <value> | --<long switch> | -<short switch> ]*

Fans out a benchmark-history rebuild across all vm2 repositories that have a 'benchmarks/' directory. For each such repo it
triggers that repo's 'RebuildBenchHistory.yaml' workflow (via 'gh workflow run -f repeat=N'), which re-records the benchmark
results to Bencher.dev N times. Fire-and-forget: it dispatches the cloud workflows and returns immediately -- the runs proceed
on GitHub's runners in parallel, so there is nothing to wait on.

Repositories are taken from the \$vm2_repositories list; the 'benchmarks/' directory is detected remotely via 'gh api' (no
local clones are needed), so the script runs identically from a CLI and from a GitHub Actions workflow.

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
$switches
Environment Variables:
  BENCH_DISPATCH_PAT            Fine-grained PAT ('Actions: write' + 'Contents: read' on the target repos) used to
                                authenticate 'gh'. Optional - falls back to \$GH_TOKEN or the ambient 'gh auth'.
  GH_TOKEN                      Token used by 'gh' (set automatically from BENCH_DISPATCH_PAT when that is provided)
  GITHUB_REPOSITORY_OWNER       The GitHub owner of the target repositories (set automatically inside Actions)
  REPEAT                        How many independent runs to record per benchmark
$vars
EOF
}
