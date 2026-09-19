#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/validate-commits.sh, as it behaves TODAY.
#
# validate-commits.sh is designed to run identically standalone and in GitHub Actions (it
# sources gh_core.sh, whose to_stdout/to_stderr/to_output helpers write to
# $GITHUB_STEP_SUMMARY/$GITHUB_OUTPUT when set, and harmlessly to /dev/null otherwise) -- so
# these tests exercise it the same way in both "modes": every test runs under a clean
# 'env -i HOME="$HOME" PATH=...' (no ambient GITHUB_ACTIONS/GITHUB_STEP_SUMMARY), and one test
# explicitly sets GITHUB_STEP_SUMMARY to confirm the exact same output also lands there.
#
# All git history is built in throwaway repos under $BATS_TEST_TMPDIR -- no network, no real
# GitHub interaction (validate-commits.sh itself never calls gh/git remote anything).

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_validate_commits="$_gh_scripts_dir/validate-commits.sh"

_make_repo_with_commits() {
    local _dir="$1"; shift
    mkdir -p "$_dir"
    git -C "$_dir" init --quiet --initial-branch=main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo "init" > "$_dir/f.txt"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: init"
    git -C "$_dir" tag base

    local _subject
    for _subject in "$@"; do
        echo "$_subject" >> "$_dir/f.txt"
        git -C "$_dir" commit --quiet --allow-empty -am "$_subject"
    done
}

_run_validate_commits() {
    local _dir="$1"; shift
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "cd '$_dir' && bash '$_validate_commits' $*"
}

# --- happy path ---------------------------------------------------------------------------

@test "validate-commits: succeeds when every commit follows Conventional Commits" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "feat: add a thing" "fix(api): correct a bug" "chore(deps): bump deps"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" base --quiet
    assert_success
    assert_output --partial "All commit messages follow Conventional Commits format"
}

@test "validate-commits: matches commit types case-insensitively" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "FEAT(api): add uppercase type"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" base --quiet
    assert_success
}

@test "validate-commits: skips Merge and Revert commits" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" \
        "Merge branch 'x' into main" \
        "Revert \"feat: add a thing\""
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" base --quiet
    assert_success
}

@test "validate-commits: accepts a breaking-change '!' marker and a scoped type" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "refactor(core)!: redesign the API"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" base --quiet
    assert_success
}

# --- bad commits ---------------------------------------------------------------------------

@test "validate-commits: fails and reports every non-conforming commit message" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "not a valid message" "feat: this one is fine" "also bad"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" base --quiet
    assert_failure
    # Each bad subject is now prefixed with its abbreviated commit hash (e.g. "f5437c44 not a
    # valid message"), so match on the subject text rather than the old exact "prefix: subject".
    assert_output --regexp "Bad commit message: [0-9a-f]{8} not a valid message"
    assert_output --regexp "Bad commit message: [0-9a-f]{8} also bad"
    refute_output --partial "feat: this one is fine"
}

@test "validate-commits: rejects an unknown/unrecognized commit type" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "bogus: not a real type"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" base --quiet
    assert_failure
    assert_output --regexp "Bad commit message: [0-9a-f]{8} bogus: not a real type"
}

@test "validate-commits: prints the remediation steps (rebase -i, force-push) on failure" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "not conventional"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" base --quiet
    assert_failure
    # The rebase now starts at the offending commit's own parent (a full SHA + "^"), not the
    # literal base-ref name -- tighter than "git rebase -i base" but not textually identical to it.
    assert_output --regexp "git rebase -i [0-9a-f]{40}\^"
    assert_output --partial "Commits needing reword"
    assert_output --partial "git push --force-with-lease origin main"
}

# --- argument handling ---------------------------------------------------------------------

@test "validate-commits: fails with a clear error when no base-ref is given and \$BASE_REF is unset" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "feat: fine"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" --quiet
    assert_failure
    assert_output --partial "No base ref provided"
}

@test "validate-commits: falls back to the \$BASE_REF environment variable when no base-ref is given" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "feat: fine"
    run env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" BASE_REF=base bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_validate_commits' --quiet"
    assert_success
    assert_output --partial "All commit messages follow Conventional Commits format"
}

@test "validate-commits: an explicit positional base-ref overrides \$BASE_REF" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "feat: fine"
    run env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" BASE_REF=does-not-exist bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_validate_commits' base --quiet"
    assert_success
}

@test "validate-commits: fails on an unknown option" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "feat: fine"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" --bogus --quiet
    assert_failure
    assert_output --partial "Unknown argument: --bogus"
}

@test "validate-commits: rejects a second positional argument as too many arguments" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "feat: fine"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" base extra --quiet
    assert_failure
    assert_output --partial "Unknown argument: extra"
}

@test "validate-commits: -h prints usage and exits 0" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "feat: fine"
    run _run_validate_commits "$BATS_TEST_TMPDIR/repo" -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "validate-commits: in CI mode (GITHUB_STEP_SUMMARY set), the same result also lands in the step summary file" {
    _make_repo_with_commits "$BATS_TEST_TMPDIR/repo" "not conventional"
    run env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_validate_commits' base --quiet"
    assert_failure
    assert_output --regexp "Bad commit message: [0-9a-f]{8} not conventional"
    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --regexp "Bad commit message: [0-9a-f]{8} not conventional"
}
