# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

function usage_text()
{
    (( $# == 1 ))   || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text && _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage:
  $script_name <results directory> --testbed <name> [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Uploads BenchmarkDotNet JSON results (*-report-full-compressed.json, produced by run-benchmarks.sh) to Bencher.dev,
tracking regressions against latency, throughput, allocation, and GC-collection thresholds.

Arguments:
  <results directory>           Directory containing the *-report-full-compressed.json files to upload. Must exist.
                                Initial value from the \$RESULTS_DIR environment variable.

Options:
  --testbed <name>              Bencher testbed name (typically the runner OS).
                                Initial value from \$TESTBED, or the default 'local' outside of GitHub Actions.
  --repository <owner/repo>     GitHub repository in 'owner/repo' form, used to derive the Bencher project slug
                                (e.g. 'vmelamed/vm2.DevOps' -> 'vm2-devops').
                                Initial value from \$REPOSITORY, the \$GITHUB_REPOSITORY environment variable that GitHub
                                Actions sets automatically, or else derived from the local git remote 'origin'.
  --event-name <name>           The triggering GitHub event name (e.g. 'push', 'pull_request', 'workflow_dispatch').
                                Initial value from \$EVENT_NAME, the \$GITHUB_EVENT_NAME environment variable that GitHub
                                Actions sets automatically, or else the default 'push' outside of GitHub Actions.
  --ref-name <name>             The Git ref name (e.g. 'main', a feature branch). Used as the Bencher branch outside of pull
                                requests.
                                Initial value from \$REF_NAME, the \$GITHUB_REF_NAME environment variable that GitHub Actions
                                sets automatically, or else the current local git branch.
  --head-ref <name>             The pull request's own head branch name. Only meaningful (and required) when --event-name is
                                'pull_request'.
                                Initial value from \$HEAD_REF, or the \$GITHUB_HEAD_REF environment variable that GitHub Actions
                                sets automatically.
  --pr-number <n>               The pull request number. Required when --event-name is 'pull_request'.
                                Initial value from \$PR_NUMBER.
  --pr-base-sha <sha>           The commit SHA the pull request branched from. Required when --event-name is
                                'pull_request'.
                                Initial value from \$PR_BASE_SHA.
  --max-regression-pct <pct>    Maximum acceptable performance regression, as a percentage (0-100). Applied as a
                                percentage threshold to latency, throughput, and allocation.
                                Initial value from \$MAX_REGRESSION_PCT or default '20'.
  --max-gen1-collects <n>       Maximum acceptable Gen1 GC collections per 1000 operations. Applied as a static
                                (absolute) upper threshold, not a percentage.
                                Initial value from \$MAX_GEN1_COLLECTS or default '2'.
  --max-gen2-collects <n>       Maximum acceptable Gen2 GC collections per 1000 operations. Applied as a static
                                (absolute) upper threshold, not a percentage.
                                Initial value from \$MAX_GEN2_COLLECTS or default '1'.
  --reset-thresholds [true|false]
                                Reset Bencher's stored thresholds instead of testing against them (use when a
                                degradation is expected and the new baseline should replace the old one).
                                Initial value from \$RESET_THRESHOLDS or default 'false'.

Environment Variables:
  RESULTS_DIR                   Directory containing the benchmark JSON results.
  TESTBED                       Bencher testbed name.
  REPOSITORY                    GitHub repository in 'owner/repo' form.
  EVENT_NAME                    The triggering GitHub event name.
  REF_NAME                      The Git ref name.
  HEAD_REF                      The pull request's own head branch name.
  PR_NUMBER                     The pull request number.
  PR_BASE_SHA                   The commit SHA the pull request branched from.
  MAX_REGRESSION_PCT            Maximum acceptable performance regression percentage (default: '20').
  MAX_GEN1_COLLECTS             Maximum acceptable Gen1 GC collections per 1000 ops (default: '2').
  MAX_GEN2_COLLECTS             Maximum acceptable Gen2 GC collections per 1000 ops (default: '1').
  RESET_THRESHOLDS              When 'true', reset Bencher's stored thresholds instead of testing against them
                                (default: 'false').
  BENCHER_API_TOKEN             Bencher.dev API token. Required.
  GH_TOKEN                      GitHub token, used to authenticate Bencher's PR comments/checks. Required only
                                when --event-name is 'pull_request'.
$_common_args
EOF
}
