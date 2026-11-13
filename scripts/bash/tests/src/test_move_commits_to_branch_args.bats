#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/move-commits-to-branch.args.sh (with move-commits-to-branch.usage.sh), following the seams of
# the get_arguments() pipeline (see test_diff_shared_args.bats, the reference implementation). Each test sources core.sh
# and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell.
#
# verify_environment() and resolve_arguments() query the repository in the current directory (its branch, its working
# tree, its commits), so those tests run inside a local-only scratch repository (_make_repo).

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_unknown_argument

declare BATS_TEST_TMPDIR

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# Runs the snippet $1 in the directory $2 (default: $BATS_TEST_TMPDIR).
_mc() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        cd '${2:-$BATS_TEST_TMPDIR}' || exit 99
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/move-commits-to-branch.args.sh'
        source '$_src_dir/move-commits-to-branch.usage.sh'
        $1
    "
}

# A local-only git repository on 'main' with two commits; $_sha is the first one.
_make_repo() {
    _repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$_repo"
    git -C "$_repo" init --quiet --initial-branch=main
    git -C "$_repo" config user.email "test@test.local"
    git -C "$_repo" config user.name "test"
    echo one > "$_repo/a.txt"; git -C "$_repo" add -A; git -C "$_repo" commit --quiet -m "chore: one"
    _sha=$(git -C "$_repo" rev-parse HEAD)
    echo two > "$_repo/a.txt"; git -C "$_repo" commit --quiet -am "chore: two"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _mc "parse_arguments
             declare -p new_branch commit_sha check_out_new_branch"
    assert_success
    assert_output --partial 'new_branch=""'
    assert_output --partial 'commit_sha=""'
    assert_output --partial 'check_out_new_branch="false"'
}

@test "parse_arguments: --branch, --commit-sha, and --check-out-new set the corresponding variables" {
    run _mc "parse_arguments --branch feature/x --commit-sha abc1234 --check-out-new
             declare -p new_branch commit_sha check_out_new_branch"
    assert_success
    assert_output --partial 'new_branch="feature/x"'
    assert_output --partial 'commit_sha="abc1234"'
    assert_output --partial 'check_out_new_branch="true"'
}

@test "parse_arguments: -b, -c, and -n set the corresponding variables, case-insensitively" {
    run _mc "parse_arguments -B feature/x -c abc1234 -N
             declare -p new_branch commit_sha check_out_new_branch"
    assert_success
    assert_output --partial 'new_branch="feature/x"'
    assert_output --partial 'commit_sha="abc1234"'
    assert_output --partial 'check_out_new_branch="true"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    run _mc "parse_arguments --branch"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing branch name after '--branch'."

    run _mc "parse_arguments --commit-sha"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing commit SHA after '--commit-sha'."
}

@test "parse_arguments: rejects an unknown option and any positional argument" {
    run _mc "parse_arguments --bogus; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument '--bogus'."
    refute_output --partial "AFTER"

    run _mc "parse_arguments feature/x; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument 'feature/x'."
    refute_output --partial "AFTER"
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _mc "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _mc "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently on a clean 'main', and captures the current branch" {
    _make_repo
    run _mc "verify_environment; echo \"rc=\$?\"
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p current_branch" "$_repo"
    assert_success
    assert_output --partial "rc=0"
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'current_branch="main"'
}

@test "verify_environment: reports a branch other than 'main' and returns instead of exiting" {
    _make_repo
    git -C "$_repo" switch --quiet -c feature
    run _mc "verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "You must be on the 'main' branch. Currently on 'feature'"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports uncommitted changes" {
    _make_repo
    echo dirty >> "$_repo/a.txt"
    run _mc "verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "You have uncommitted changes"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports a missing git and returns instead of exiting" {
    _make_repo
    run _mc "is_tool_present() { [[ \$1 != git ]]; }
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: accepts a valid new branch and an existing commit, and freezes the variables" {
    _make_repo
    run _mc "new_branch=feature/x
             commit_sha=${_sha:0:7}
             current_branch=main
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p new_branch commit_sha check_out_new_branch current_branch" "$_repo"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx new_branch="feature/x"'
    assert_output --partial "declare -rx commit_sha=\"${_sha:0:7}\""
    assert_output --partial 'declare -rx check_out_new_branch="false"'
    assert_output --partial 'declare -rx current_branch="main"'
}

@test "resolve_arguments: reports a missing --branch and a missing --commit-sha together" {
    _make_repo
    run _mc "resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\"" "$_repo"
    assert_success
    assert_output --partial "The option '--branch' is mandatory"
    assert_output --partial "The '--commit-sha' is mandatory"
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

@test "resolve_arguments: rejects 'main' as the new branch" {
    _make_repo
    run _mc "new_branch=main
             commit_sha=$_sha
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "The new branch name cannot be 'main'"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects a commit SHA that is not hexadecimal" {
    _make_repo
    run _mc "new_branch=feature/x
             commit_sha=not-a-sha
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "The '--commit-sha' is mandatory"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects a well-formed SHA of a commit that does not exist" {
    _make_repo
    run _mc "new_branch=feature/x
             commit_sha=deadbeefdeadbeef
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Commit 'deadbeefdeadbeef' does not exist"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, verifies, resolves, and freezes the arguments in one call" {
    _make_repo
    run _mc "get_arguments --branch feature/x --commit-sha $_sha
             declare -p new_branch commit_sha" "$_repo"
    assert_success
    assert_output --partial 'declare -rx new_branch="feature/x"'
    assert_output --partial "declare -rx commit_sha=\"$_sha\""
}

@test "get_arguments: -h prints the usage and exits 0, even off 'main' with a dirty tree" {
    _make_repo
    git -C "$_repo" switch --quiet -c feature
    echo dirty >> "$_repo/a.txt"
    run _mc "get_arguments -h --branch feature/x; echo AFTER" "$_repo"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: reports the environment and the argument errors together, then exits with the usage" {
    _make_repo
    git -C "$_repo" switch --quiet -c feature
    run _mc "get_arguments --branch main --commit-sha deadbeef; echo AFTER" "$_repo"
    assert_failure
    assert_output --partial "Currently on 'feature'"
    assert_output --partial "The new branch name cannot be 'main'"
    assert_output --partial "Commit 'deadbeef' does not exist"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
