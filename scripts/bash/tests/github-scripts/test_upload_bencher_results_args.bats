#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/upload-bencher-results.args.sh (with upload-bencher-results.usage.sh), following the seams of
# the get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation).
# Each test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell,
# started in a scratch directory that is NOT a git repository -- so the fallbacks that ask git for the repository and the
# branch find nothing, unless a test gives the values. A fake 'bencher' in $BATS_TEST_TMPDIR/bin stands in for the real
# one.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_too_many_arguments
declare -gxi err_unknown_argument

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 in $BATS_TEST_TMPDIR/work, with the environment assignments $2 (default: a dummy
# BENCHER_API_TOKEN; pass e.g. "TESTBED=" to run without it).
_ub() {
    local _env=${2-"BENCHER_API_TOKEN=dummy"}
    # shellcheck disable=SC2086 # $_env holds one or more assignments: word splitting is intended
    (cd "$BATS_TEST_TMPDIR/work" && env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" $_env bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/upload-bencher-results.usage.sh'
        source '$_gh_scripts_dir/upload-bencher-results.args.sh'
        $1
    ")
}

setup() {
    _tmp=$(realpath "$BATS_TEST_TMPDIR")
    mkdir -p "$_tmp/bin" "$_tmp/work/results"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$_tmp/bin/bencher"
    chmod +x "$_tmp/bin/bencher"
}

# The arguments resolve_arguments() needs to succeed for a push (the results directory is relative to the current one).
_valid="results_dir=results repository=acme/repo ref_name=main"

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments and no variables are given" {
    run _ub "parse_arguments
             declare -p results_dir testbed repository event_name ref_name head_ref pr_number pr_base_sha \
                        max_regression_pct max_gen1_collects max_gen2_collects reset_thresholds"
    assert_success
    assert_output --partial 'results_dir=""'
    assert_output --partial 'testbed=""'
    assert_output --partial 'repository=""'
    assert_output --partial 'event_name=""'
    assert_output --partial 'ref_name=""'
    assert_output --partial 'head_ref=""'
    assert_output --partial 'pr_number=""'
    assert_output --partial 'pr_base_sha=""'
    assert_output --partial 'max_regression_pct="20"'
    assert_output --partial 'max_gen1_collects="2"'
    assert_output --partial 'max_gen2_collects="1"'
    assert_output --partial 'reset_thresholds="false"'
}

@test "parse_arguments: the defaults come from the script's own variables, then from GitHub's" {
    run _ub "parse_arguments
             declare -p repository event_name ref_name head_ref" \
            "GITHUB_REPOSITORY=gh/repo GITHUB_EVENT_NAME=pull_request GITHUB_REF_NAME=gh-ref GITHUB_HEAD_REF=gh-head"
    assert_success
    assert_output --partial 'repository="gh/repo"'
    assert_output --partial 'event_name="pull_request"'
    assert_output --partial 'ref_name="gh-ref"'
    assert_output --partial 'head_ref="gh-head"'

    run _ub "parse_arguments
             declare -p repository event_name ref_name head_ref" \
            "GITHUB_REPOSITORY=gh/repo REPOSITORY=own/repo EVENT_NAME=push REF_NAME=own-ref HEAD_REF=own-head"
    assert_success
    assert_output --partial 'repository="own/repo"'
    assert_output --partial 'event_name="push"'
    assert_output --partial 'ref_name="own-ref"'
    assert_output --partial 'head_ref="own-head"'
}

@test "parse_arguments: every option and the positional results directory set the corresponding variables" {
    run _ub "parse_arguments --testbed tb --repository acme/repo --event-name pull_request --ref-name 7/merge --head-ref feat \
                             --pr-number 7 --pr-base-sha abc --max-regression-pct 15 --max-gen1-collects 3 \
                             --max-gen2-collects 0 --reset-thresholds true results
             declare -p results_dir testbed repository event_name ref_name head_ref pr_number pr_base_sha \
                        max_regression_pct max_gen1_collects max_gen2_collects reset_thresholds"
    assert_success
    assert_output --partial 'results_dir="results"'
    assert_output --partial 'testbed="tb"'
    assert_output --partial 'repository="acme/repo"'
    assert_output --partial 'event_name="pull_request"'
    assert_output --partial 'ref_name="7/merge"'
    assert_output --partial 'head_ref="feat"'
    assert_output --partial 'pr_number="7"'
    assert_output --partial 'pr_base_sha="abc"'
    assert_output --partial 'max_regression_pct="15"'
    assert_output --partial 'max_gen1_collects="3"'
    assert_output --partial 'max_gen2_collects="0"'
    assert_output --partial 'reset_thresholds="true"'
}

@test "parse_arguments: matches the option names case-insensitively" {
    run _ub "parse_arguments --TESTBED tb --Repository acme/repo
             declare -p testbed repository"
    assert_success
    assert_output --partial 'testbed="tb"'
    assert_output --partial 'repository="acme/repo"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --testbed --repository --event-name --ref-name --head-ref --pr-number --pr-base-sha \
                   --max-regression-pct --max-gen1-collects --max-gen2-collects; do
        run _ub "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done

    run _ub "parse_arguments --reset-thresholds"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing boolean value for --reset-thresholds"
}

@test "parse_arguments: a second results directory is rejected" {
    run _ub "parse_arguments one two; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Multiple results directories specified: two"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the results directory" {
    run _ub "parse_arguments --bogus; declare -p results_dir"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "results_dir="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _ub "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _ub "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently with \$BENCHER_API_TOKEN, bc, and bencher" {
    run _ub "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing token, bc, and bencher together, and returns instead of exiting" {
    run _ub "is_tool_present() { [[ \$1 != bc && \$1 != bencher ]]; }
             verify_environment
             echo REACHED
             echo \"errors=\$(get_errors)\"" "TESTBED="
    assert_success
    assert_output --partial "The BENCHER_API_TOKEN environment variable is required."
    assert_output --partial "'bc' is not installed"
    assert_output --partial "'bencher' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "errors=3"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: defaults the event to 'push' and the testbed to 'local', and freezes the arguments" {
    run _ub "$_valid
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p results_dir testbed repository event_name ref_name reset_thresholds"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx results_dir="results"'
    assert_output --partial 'declare -rx testbed="local"'
    assert_output --partial 'declare -rx repository="acme/repo"'
    assert_output --partial 'declare -rx event_name="push"'
    assert_output --partial 'declare -rx ref_name="main"'
    assert_output --partial 'declare -rx reset_thresholds="false"'
}

@test "resolve_arguments: without a repository and a branch, takes them from git (here: none, so both are reported)" {
    run _ub "results_dir='$_tmp/work/results'
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "--repository must be in 'owner/repo' form (provided '<empty>')."
    assert_output --partial "--ref-name is required."
    assert_output --partial "errors=2"
}

@test "resolve_arguments: without a branch, takes the current branch of the git repository in the current directory" {
    git -C "$_tmp/work" init --quiet --initial-branch=feature
    run _ub "results_dir='$_tmp/work/results' repository=acme/repo
             resolve_arguments
             declare -p ref_name"
    assert_success
    assert_output --partial 'declare -rx ref_name="feature"'
}

@test "resolve_arguments: reports a missing results directory, and one that is not a directory" {
    run _ub "repository=acme/repo ref_name=main
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "The results directory is required."
    assert_output --partial "HAS_ERRORS"

    run _ub "results_dir='$_tmp/work/not-there' repository=acme/repo ref_name=main
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "The results directory '$_tmp/work/not-there' is not a directory."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports every invalid threshold and boolean together, and returns" {
    run _ub "$_valid max_regression_pct=101 max_gen1_collects=-1 max_gen2_collects=x reset_thresholds=yes
             resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "The max regression percentage '101' must be an integer number between 0 and 100."
    assert_output --partial "--max-gen1-collects must be a non-negative integer (got '-1')."
    assert_output --partial "--max-gen2-collects must be a non-negative integer (got 'x')."
    assert_output --partial "The input 'yes' is not a valid boolean."
    assert_output --partial "REACHED"
    assert_output --partial "errors=4"
}

@test "resolve_arguments: a pull request needs the head ref, the PR number, the base SHA, and \$GH_TOKEN" {
    run _ub "$_valid event_name=pull_request
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "--head-ref is required when --event-name is 'pull_request'."
    assert_output --partial "--pr-number is required when --event-name is 'pull_request'."
    assert_output --partial "--pr-base-sha is required when --event-name is 'pull_request'."
    assert_output --partial "The GH_TOKEN environment variable is required when --event-name is 'pull_request'."
    assert_output --partial "errors=4"
}

@test "resolve_arguments: rejects a PR number that is not a natural number" {
    local _pr
    for _pr in 0 -1 07 abc '7 8' '\$(echo INJ)'; do
        run _ub "$_valid event_name=pull_request head_ref=feat pr_number='$_pr' pr_base_sha=abc
                 resolve_arguments
                 echo \"errors=\$(get_errors)\"" "BENCHER_API_TOKEN=dummy GH_TOKEN=dummy"
        assert_success
        assert_output --partial "The PR number must be a natural number."
        refute_output --partial "--pr-number is required"
        assert_output --partial "errors=1"
    done
}

@test "resolve_arguments: does not validate the PR number outside a pull request" {
    run _ub "$_valid pr_number=abc
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "NO_ERRORS"
}

@test "resolve_arguments: a complete pull request resolves without errors" {
    run _ub "$_valid event_name=pull_request head_ref=feat pr_number=7 pr_base_sha=abc
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "BENCHER_API_TOKEN=dummy GH_TOKEN=dummy"
    assert_success
    assert_output --partial "NO_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _ub "get_arguments --repository acme/repo --ref-name main --testbed ubuntu-latest results
             declare -p results_dir testbed"
    assert_success
    assert_output --partial 'declare -rx results_dir="results"'
    assert_output --partial 'declare -rx testbed="ubuntu-latest"'
}

@test "get_arguments: -h prints the usage and exits 0, even without the token and the required arguments" {
    run _ub "get_arguments -h; echo AFTER" "TESTBED="
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: reports the environment and the argument errors together, then exits with the usage" {
    run _ub "get_arguments --repository acme/repo --ref-name main; echo AFTER" "TESTBED="
    assert_failure
    assert_output --partial "The BENCHER_API_TOKEN environment variable is required."
    assert_output --partial "The results directory is required."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
