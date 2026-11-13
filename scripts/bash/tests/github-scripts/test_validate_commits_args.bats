#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/validate-commits.args.sh (with validate-commits.usage.sh), following the seams of the
# get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each
# test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell, started
# in the directory given (the default repo_path is the current directory, captured when the args file is sourced).

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_unknown_argument

declare -gx git_remotes_ns

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 in the directory $2 (default: $BATS_TEST_TMPDIR), with the optional environment assignments $3.
_vc() {
    (cd "${2:-$BATS_TEST_TMPDIR}" && env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" ${3:+"$3"} bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/validate-commits.usage.sh'
        source '$_gh_scripts_dir/validate-commits.args.sh'
        $1
    ")
}

setup() {
    _tmp=$(realpath "$BATS_TEST_TMPDIR")
}

# A local-only repository with a 'main' (2 commits) and a 'feature' branch (1 more commit), checked out on 'feature'.
# $_main_sha is main's tip -- the merge-base of the two.
_make_repo() {
    _repo="$_tmp/repo"
    mkdir -p "$_repo"
    git -C "$_repo" init --quiet --initial-branch=main
    git -C "$_repo" config user.email "test@test.local"
    git -C "$_repo" config user.name "test"
    git -C "$_repo" commit --quiet --allow-empty -m "chore: one"
    git -C "$_repo" commit --quiet --allow-empty -m "chore: two"
    _main_sha=$(git -C "$_repo" rev-parse HEAD)
    git -C "$_repo" switch --quiet -c feature
    git -C "$_repo" commit --quiet --allow-empty -m "feat: three"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: defaults to the current directory and an empty base ref" {
    run _vc "parse_arguments
             declare -p repo_path base_ref"
    assert_success
    assert_output --partial "repo_path=\"$_tmp\""
    assert_output --partial 'base_ref=""'
}

@test "parse_arguments: the default base ref comes from \$BASE_REF when it is set" {
    run _vc "parse_arguments
             declare -p base_ref" "" "BASE_REF=origin/main"
    assert_success
    assert_output --partial 'base_ref="origin/main"'
}

@test "parse_arguments: --repo-dir/-r and --base-ref/-b set the corresponding variables, case-insensitively" {
    run _vc "parse_arguments --repo-dir /some/repo --base-ref v1.0.0
             declare -p repo_path base_ref"
    assert_success
    assert_output --partial 'repo_path="/some/repo"'
    assert_output --partial 'base_ref="v1.0.0"'

    run _vc "parse_arguments -R /other/repo -B abc1234
             declare -p repo_path base_ref"
    assert_success
    assert_output --partial 'repo_path="/other/repo"'
    assert_output --partial 'base_ref="abc1234"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --repo-dir --base-ref; do
        run _vc "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for '$_option'"
    done
}

@test "parse_arguments: rejects an unknown option and any positional argument" {
    run _vc "parse_arguments --bogus; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "AFTER"

    run _vc "parse_arguments some-dir; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: some-dir"
    refute_output --partial "AFTER"
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _vc "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _vc "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when git is present" {
    run _vc "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing git and returns instead of exiting" {
    run _vc "is_tool_present() { [[ \$1 != git ]]; }
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: keeps a given base ref and freezes the arguments" {
    _make_repo
    run _vc "repo_path='$_repo'
             base_ref=v9.9.9
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p repo_path base_ref"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial "declare -rx repo_path=\"$_repo\""
    assert_output --partial 'declare -rx base_ref="v9.9.9"'
}

@test "resolve_arguments: without a base ref, defaults to the merge-base with the upstream branch" {
    _make_repo
    git -C "$_repo" branch --quiet --set-upstream-to=main feature
    run _vc "repo_path='$_repo'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p base_ref"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial "declare -rx base_ref=\"$_main_sha\""
}

@test "resolve_arguments: without a base ref, prefers origin/HEAD over the upstream branch" {
    _make_repo
    # a fake 'origin' whose HEAD is main: just the refs, no remote repository is needed
    git -C "$_repo" update-ref "${git_remotes_ns}origin/main" "$_main_sha"
    git -C "$_repo" symbolic-ref "${git_remotes_ns}origin/HEAD" "${git_remotes_ns}origin/main"
    # an upstream at feature's own tip: had it won, the merge-base would be that tip, not main's
    git -C "$_repo" branch --quiet tip
    git -C "$_repo" branch --quiet --set-upstream-to=tip feature
    run _vc "repo_path='$_repo'
             resolve_arguments
             declare -p base_ref"
    assert_success
    assert_output --partial "declare -rx base_ref=\"$_main_sha\""
}

@test "resolve_arguments: without a base ref, origin/HEAD, or an upstream branch, reports that a base ref is needed" {
    _make_repo
    run _vc "repo_path='$_repo'
             resolve_arguments
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "No base ref provided"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports a directory that does not exist" {
    run _vc "repo_path='$_tmp/not-there'
             base_ref=main
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "Invalid directory: '$_tmp/not-there'"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports a directory that is not in a git working tree" {
    mkdir -p "$_tmp/plain"
    run _vc "repo_path='$_tmp/plain'
             base_ref=main
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "The directory '$_tmp/plain' is not inside Git repository working tree"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    _make_repo
    run _vc "get_arguments --base-ref main
             declare -p repo_path base_ref" "$_repo"
    assert_success
    assert_output --partial "declare -rx repo_path=\"$_repo\""
    assert_output --partial 'declare -rx base_ref="main"'
}

@test "get_arguments: -h prints the usage and exits 0, even outside a git repository" {
    run _vc "get_arguments -h; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: a directory outside a git repository ends the run with the error and the usage" {
    mkdir -p "$_tmp/plain"
    run _vc "get_arguments --repo-dir '$_tmp/plain'; echo AFTER"
    assert_failure
    assert_output --partial "is not inside Git repository working tree"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
