#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/compute-prerelease-version.sh, as it behaves
# TODAY.
#
# This is a CI-only script driven entirely by real Git state (tags, commit history) -- no
# external tool needs mocking. Each fixture is a real repo with a real local bare "origin"
# remote (the script does `git fetch --tags --force`, which needs a remote to fetch from, even
# though nothing is pushed here).

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_compute_prerelease="$_gh_scripts_dir/compute-prerelease-version.sh"

_make_fixture() {
    local _dir="$1"
    mkdir -p "$_dir/origin.git" "$_dir/repo"
    git init --quiet --bare "$_dir/origin.git"
    git -C "$_dir/repo" init --quiet -b main
    git -C "$_dir/repo" config user.email "test@test.local"
    git -C "$_dir/repo" config user.name "test"
    git -C "$_dir/repo" remote add origin "$_dir/origin.git"
    echo hi > "$_dir/repo/f.txt"
    git -C "$_dir/repo" add -A
    git -C "$_dir/repo" commit --quiet -m "chore: init"
    git -C "$_dir/repo" push --quiet -u origin main
}

_commit() {
    local _dir="$1" _message="$2"
    echo "$RANDOM" >> "$_dir/f.txt"
    git -C "$_dir" commit --quiet -am "$_message"
}

_tag() {
    local _dir="$1" _tag="$2"
    git -C "$_dir" tag "$_tag"
    git -C "$_dir" push --quiet origin "$_tag"
}

# $1 = repo dir, $@ (rest) = CLI arguments.
_run_compute_prerelease() {
    local _dir="$1"; shift
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        cd '$_dir' && bash '$_compute_prerelease' $*
    "
}

# --- bump type detection ---------------------------------------------------------------------

@test "compute-prerelease-version: with no prior tags, computes 1.0.0-preview.1 (SemVer floor)" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "prerelease-version=1.0.0-preview.1"
    assert_output --partial "prerelease-tag=v1.0.0-preview.1"
    assert_output --partial "adjusted to 1.0.0 for SemVer compliance"
}

@test "compute-prerelease-version: a feat commit since the last stable tag bumps minor" {
    _make_fixture "$BATS_TEST_TMPDIR"
    _tag "$BATS_TEST_TMPDIR/repo" v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "feat: add a thing"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "prerelease-version=1.1.0-preview.1"
    assert_output --partial "minor (new features detected)"
}

@test "compute-prerelease-version: a fix commit since the last stable tag bumps patch" {
    _make_fixture "$BATS_TEST_TMPDIR"
    _tag "$BATS_TEST_TMPDIR/repo" v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "fix: correct a bug"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "prerelease-version=1.0.1-preview.1"
    assert_output --partial "patch (fixes or other changes detected)"
}

@test "compute-prerelease-version: a breaking change (type!:) since the last stable tag bumps major" {
    _make_fixture "$BATS_TEST_TMPDIR"
    _tag "$BATS_TEST_TMPDIR/repo" v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "refactor!: redesign the API"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "prerelease-version=2.0.0-preview.1"
    assert_output --partial "major (breaking changes detected)"
}

@test "compute-prerelease-version: non-code-only commits still produce a base version strictly greater than the last stable tag" {
    _make_fixture "$BATS_TEST_TMPDIR"
    _tag "$BATS_TEST_TMPDIR/repo" v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "chore: bump a dependency"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "prerelease-version=1.0.1-preview.1"
    assert_output --partial "minimum bump: no code changes since stable"
}

# --- prerelease counter -----------------------------------------------------------------------

@test "compute-prerelease-version: the counter increments when the base version matches the latest prerelease" {
    _make_fixture "$BATS_TEST_TMPDIR"
    _tag "$BATS_TEST_TMPDIR/repo" v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "feat: add a thing"
    _tag "$BATS_TEST_TMPDIR/repo" v1.1.0-preview.1
    _commit "$BATS_TEST_TMPDIR/repo" "feat: add another thing"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "prerelease-version=1.1.0-preview.2"
}

@test "compute-prerelease-version: the counter resets to 1 when the base version changes" {
    _make_fixture "$BATS_TEST_TMPDIR"
    _tag "$BATS_TEST_TMPDIR/repo" v1.0.0
    _commit "$BATS_TEST_TMPDIR/repo" "fix: a patch"
    _tag "$BATS_TEST_TMPDIR/repo" v1.0.1-preview.5
    _commit "$BATS_TEST_TMPDIR/repo" "feat: a bigger change"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet
    assert_success
    assert_output --partial "prerelease-version=1.1.0-preview.1"
}

# --- prerelease identifier ---------------------------------------------------------------------

@test "compute-prerelease-version: an explicit --minver-prerelease-id changes the suffix (height seed stripped)" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet --minver-prerelease-id alpha.0
    assert_success
    assert_output --partial "prerelease-version=1.0.0-alpha.1"
}

# --- validation failures ---------------------------------------------------------------------

@test "compute-prerelease-version: fails when HEAD is already tagged" {
    _make_fixture "$BATS_TEST_TMPDIR"
    _tag "$BATS_TEST_TMPDIR/repo" v1.0.0-preview.1
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet
    assert_failure
    assert_output --partial "The HEAD is already tagged with 'v1.0.0-preview.1'"
}

@test "compute-prerelease-version: rejects an unsafe --reason value" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet --reason "'-hack'"
    assert_failure
}

# --- argument handling ---------------------------------------------------------------------

@test "compute-prerelease-version: fails with a clear error when a value-taking option is given without a value" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet --minver-tag-prefix
    assert_failure
    assert_output --partial "Missing value for --minver-tag-prefix"
}

@test "compute-prerelease-version: fails on an unknown option" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" --quiet --bogus
    assert_failure
    assert_output --partial "Unknown argument: --bogus"
}

@test "compute-prerelease-version: -h prints usage and exits 0" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_compute_prerelease "$BATS_TEST_TMPDIR/repo" -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "compute-prerelease-version: in CI mode, the summary also lands in the step summary and GITHUB_OUTPUT files" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output.txt" \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_compute_prerelease' --quiet"
    assert_success

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "Prerelease Version"

    run cat "$BATS_TEST_TMPDIR/output.txt"
    assert_output --partial "prerelease-version=1.0.0-preview.1"
    assert_output --partial "prerelease-tag=v1.0.0-preview.1"
}
