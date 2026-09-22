#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/compute-release-version.sh, as it behaves TODAY.
#
# This is a CI-only script driven entirely by real Git state (tags, commit history) -- no
# external tool needs mocking, and (unlike compute-prerelease-version.sh) it never fetches or
# pushes, so fixtures don't need a remote at all.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_compute_release="$_gh_scripts_dir/compute-release-version.sh"

_make_fixture() {
    local _dir="$1"
    mkdir -p "$_dir"
    git -C "$_dir" init --quiet -b main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo hi > "$_dir/f.txt"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: init"
}

_commit() {
    local _dir="$1" _message="$2"
    echo "$RANDOM" >> "$_dir/f.txt"
    git -C "$_dir" commit --quiet -am "$_message"
}

# $1 = repo dir, $@ (rest) = CLI arguments.
_run_compute_release() {
    local _dir="$1"; shift
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        cd '$_dir' && bash '$_compute_release' $*
    "
}

# --- bump type detection ---------------------------------------------------------------------

@test "compute-release-version: with no prior tags, computes 1.0.0 (SemVer floor)" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "release-version=1.0.0"
    assert_output --partial "release-tag=v1.0.0"
    assert_output --partial "needs-empty-commit=false"
}

@test "compute-release-version: a feat commit since the last stable tag bumps minor" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" tag v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "feat: add a thing"
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "release-version=1.1.0"
    assert_output --partial "minor (new features detected)"
}

@test "compute-release-version: a breaking change (type!:) since the last stable tag bumps major" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" tag v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "refactor!: redesign the API"
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "release-version=2.0.0"
    assert_output --partial "major (breaking changes detected)"
}

@test "compute-release-version: unlike prereleases, even a chore-only commit still bumps patch (no 'none' bump type)" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" tag v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "chore: bump a dependency"
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "release-version=1.0.1"
    assert_output --partial "patch (fixes or other changes)"
}

# --- promoting a prerelease to stable -----------------------------------------------------

@test "compute-release-version: HEAD tagged with a prerelease promotes it to stable and requests an empty commit" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" tag v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "feat: add a thing"
    git -C "$BATS_TEST_TMPDIR/repo" tag v1.1.0-preview.1
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "release-version=1.1.0"
    assert_output --partial "needs-empty-commit=true"
    assert_output --partial "Promoting prerelease"
    assert_output --partial "v1.1.0-preview.1"
}

# --- validation failures ---------------------------------------------------------------------

@test "compute-release-version: fails when HEAD is already tagged with a stable release" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" tag v1.0.0
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet
    assert_failure
    assert_output --partial "already tagged with stable tag 'v1.0.0'"
}

@test "compute-release-version: fails when HEAD is tagged with something that isn't a recognized semver tag" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" tag not-a-semver
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet
    assert_failure
    assert_output --partial "not a recognized semver tag"
}

@test "compute-release-version: rejects an unsafe --reason value" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet --reason "'-hack'"
    assert_failure
}

# --- argument handling ---------------------------------------------------------------------

@test "compute-release-version: fails with a clear error when a value-taking option is given without a value" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet --minver-tag-prefix
    assert_failure
    assert_output --partial "Missing value for --minver-tag-prefix"
}

@test "compute-release-version: fails on an unknown option" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" --quiet --bogus
    assert_failure
    assert_output --partial "Unknown argument: --bogus"
}

@test "compute-release-version: -h prints usage and exits 0" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    run _run_compute_release "$BATS_TEST_TMPDIR/repo" -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "compute-release-version: in CI mode, the summary also lands in the step summary and GITHUB_OUTPUT files" {
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    run env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output.txt" \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_compute_release' --quiet"
    assert_success

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "Release Version"

    run cat "$BATS_TEST_TMPDIR/output.txt"
    assert_output --partial "release-version=1.0.0"
    assert_output --partial "release-tag=v1.0.0"
}

@test "compute-release-version: a reason containing '%' is workflow-command-escaped in the step summary" {
    # '%' passes is_safe_reason (it is not a shell metacharacter), so it reaches the summary line
    # unfiltered by argument validation -- gh_escape must still neutralize it there, since '%' has
    # parsing significance for GitHub Actions workflow commands.
    _make_fixture "$BATS_TEST_TMPDIR/repo"
    run env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output.txt" \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_compute_release' --quiet --reason 'Fixed 50% of the bugs'"
    assert_success

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "Fixed 50%25 of the bugs"
    refute_output --partial "Fixed 50% of the bugs"

    run cat "$BATS_TEST_TMPDIR/output.txt"
    assert_output --partial "reason=Fixed 50% of the bugs"
}
