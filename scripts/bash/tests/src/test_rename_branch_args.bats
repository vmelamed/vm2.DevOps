#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/rename-branch.args.sh (with rename-branch.usage.sh), following the seams of the
# get_arguments() pipeline (see test_diff_shared_args.bats, the reference implementation), plus end-to-end runs of
# rename-branch.sh itself. Each test sources core.sh and the files under test in a fresh, ambient-environment-free
# ('env -i') bash subshell.
#
# Every test that touches git runs in a sandbox: a clone of a local bare repository, so 'git fetch' and 'git push' never
# reach the network, and the real clone of vm2.DevOps is never modified. The sandbox's branches:
#
#   main          local and on origin (the default branch, which must not be renamed)
#   old           local and on origin, checked out (the branch the tests rename)
#   taken         local and on origin (a new name that already exists)
#   remote-only   only on origin (a new name that exists only on the remote)
#   local-only    only local (an old name that does not exist on the remote)

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx err_too_many_arguments
declare -gx err_unknown_argument
declare -gx err_argument_value

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# $1: the commands to run after sourcing the files under test; $2: the directory to run them in (default: the sandbox).
_rb() {
    local _dir=${2:-$BATS_TEST_TMPDIR/repo}
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        cd '$_dir' || exit 99
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/rename-branch.args.sh'
        source '$_src_dir/rename-branch.usage.sh'
        $1
    "
}

# Runs rename-branch.sh itself in the sandbox with the given arguments.
_run_script() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        cd '$BATS_TEST_TMPDIR/repo' && bash '$_src_dir/rename-branch.sh' $*
    "
}

# git in the sandbox, isolated from the user's hooks and identity.
_git() {
    git -C "$BATS_TEST_TMPDIR/repo" -c core.hooksPath=/dev/null -c user.name=test -c user.email=test@example.com "$@"
}

_make_sandbox() {
    git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
    git clone -q "$BATS_TEST_TMPDIR/origin.git" "$BATS_TEST_TMPDIR/repo" 2> /dev/null
    _git symbolic-ref HEAD refs/heads/main
    _git commit -q --allow-empty -m "init"
    local _b
    for _b in main old taken remote-only; do
        _git push -q origin "HEAD:refs/heads/$_b" 2> /dev/null
    done
    _git branch -q --track old origin/old
    _git branch -q --track taken origin/taken
    _git branch -q local-only
    _git switch -q old
    # remote-only must not exist locally; its remote-tracking ref (refs/remotes/origin/remote-only) stays
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves both names empty when no arguments are given" {
    run _rb "parse_arguments
             declare -p old_branch_name new_branch_name" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output --partial 'old_branch_name=""'
    assert_output --partial 'new_branch_name=""'
}

@test "parse_arguments: a single positional argument is the new name (the old one is the current branch)" {
    run _rb "parse_arguments feature/new
             declare -p old_branch_name new_branch_name" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output --partial 'old_branch_name=""'
    assert_output --partial 'new_branch_name="feature/new"'
}

@test "parse_arguments: two positional arguments are the old and the new name, in that order" {
    run _rb "parse_arguments feature/old feature/new
             declare -p old_branch_name new_branch_name" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output --partial 'old_branch_name="feature/old"'
    assert_output --partial 'new_branch_name="feature/new"'
}

@test "parse_arguments: strips the refs/heads/ prefix from both names" {
    run _rb "parse_arguments refs/heads/feature/old refs/heads/feature/new
             declare -p old_branch_name new_branch_name" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output --partial 'old_branch_name="feature/old"'
    assert_output --partial 'new_branch_name="feature/new"'
}

@test "parse_arguments: a third positional argument is rejected" {
    run _rb "parse_arguments a b c; echo AFTER" "$BATS_TEST_TMPDIR"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Too many positional arguments: c"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as a branch name" {
    run _rb "parse_arguments --bogus; declare -p new_branch_name" "$BATS_TEST_TMPDIR"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "new_branch_name="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _rb "parse_arguments -h; echo \"requested=\$usage_requested\"" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output "requested=short"

    run _rb "parse_arguments --help; echo \"requested=\$usage_requested\"" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when origin can be fetched" {
    _make_sandbox
    run _rb "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a failed fetch and returns instead of exiting" {
    _make_sandbox
    _git remote set-url origin "$BATS_TEST_TMPDIR/no-such-origin.git"
    run _rb "verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "Failed to fetch from remote."
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports a missing git and returns instead of exiting" {
    run _rb "is_tool_present() { [[ \$1 != git ]]; }
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

# $1: the arguments; the output ends with the error state and both (frozen) names
_resolve() {
    _rb "parse_arguments $1
         resolve_arguments
         has_errors && echo HAS_ERRORS || echo NO_ERRORS
         declare -p old_branch_name new_branch_name"
}

@test "resolve_arguments: accepts an explicit old name and freezes both names" {
    _make_sandbox
    run _resolve "old feature/new"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx old_branch_name="old"'
    assert_output --partial 'declare -rx new_branch_name="feature/new"'
}

@test "resolve_arguments: with one argument, the old name is the current branch" {
    _make_sandbox
    run _resolve "feature/new"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx old_branch_name="old"'
}

@test "resolve_arguments: reports a missing new name" {
    _make_sandbox
    run _resolve ""
    assert_output --partial "No new branch name provided."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: the same name is reported once, without 'already exists'" {
    _make_sandbox
    run _resolve "old old"
    assert_output --partial "The new branch name is the same as the old branch name."
    refute_output --partial "already exists"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects an invalid new name" {
    _make_sandbox
    run _resolve "old bad..name"
    assert_output --partial "Invalid branch name 'bad..name'."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects a new name that exists locally" {
    _make_sandbox
    run _resolve "old taken"
    assert_output --partial "Branch 'taken' already exists locally."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects a new name that exists only on the remote" {
    _make_sandbox
    run _resolve "old remote-only"
    assert_output --partial "Branch 'remote-only' already exists on remote."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects an invalid old name" {
    _make_sandbox
    run _resolve "bad..name feature/new"
    assert_output --partial "Invalid branch name 'bad..name'."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: a detached HEAD without an old name is reported" {
    _make_sandbox
    _git switch -q --detach
    run _resolve "feature/new"
    assert_output --partial "HEAD is detached, so there is no current branch to rename."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: refuses to rename the default branch" {
    _make_sandbox
    run _resolve "main feature/new"
    assert_output --partial "Cannot rename the default branch 'main'."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects an old name that does not exist locally" {
    _make_sandbox
    run _resolve "ghost feature/new"
    assert_output --partial "Branch 'ghost' does not exist locally."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects an old name that exists locally but not on the remote" {
    _make_sandbox
    run _resolve "local-only feature/new"
    assert_output --partial "Branch 'local-only' does not exist remotely."
    refute_output --partial "does not exist locally"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports a bad new name and a bad old name together" {
    _make_sandbox
    run _resolve "ghost taken"
    assert_output --partial "Branch 'taken' already exists locally."
    assert_output --partial "Branch 'ghost' does not exist locally."
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses and freezes the arguments in one call" {
    _make_sandbox
    run _rb "get_arguments old feature/new
             declare -p new_branch_name"
    assert_success
    assert_output --partial 'declare -rx new_branch_name="feature/new"'
}

@test "get_arguments: -h prints the usage and exits 0 without running anything after it" {
    run _rb "get_arguments -h old new; echo AFTER" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: a missing git ends the run with the error and the usage" {
    run _rb "is_tool_present() { [[ \$1 != git ]]; }
             get_arguments old new; echo AFTER" "$BATS_TEST_TMPDIR"
    assert_failure
    assert_output --partial "'git' is not installed"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: an invalid argument ends the run with the error code and the usage" {
    _make_sandbox
    run _rb "get_arguments old taken; echo AFTER"
    assert_failure "$err_argument_value"
    assert_output --partial "Branch 'taken' already exists locally."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

# =====================================================================================
# rename-branch.sh end to end
# =====================================================================================

@test "rename-branch: renames the branch locally and on origin, and tracks the new remote branch" {
    _make_sandbox
    run _run_script --quiet old feature/new
    assert_success

    run _git for-each-ref --format='%(refname)' refs/heads/old refs/heads/feature/new
    assert_output "refs/heads/feature/new"
    run git -C "$BATS_TEST_TMPDIR/origin.git" for-each-ref --format='%(refname)' refs/heads/old refs/heads/feature/new
    assert_output "refs/heads/feature/new"
    run _git rev-parse --abbrev-ref 'feature/new@{upstream}'
    assert_output "origin/feature/new"
}

@test "rename-branch: renames the current branch when only the new name is given" {
    _make_sandbox
    run _run_script --quiet feature/new
    assert_success
    run _git branch --show-current
    assert_output "feature/new"
}

@test "rename-branch: --dry-run prints the commands and changes nothing" {
    _make_sandbox
    run _run_script --dry-run old feature/new
    assert_success
    assert_output --partial "dry-run$ git branch -m old feature/new"
    assert_output --partial "dry-run$ git push origin --delete refs/heads/old"

    run _git for-each-ref --format='%(refname)' refs/heads/old refs/heads/feature/new
    assert_output "refs/heads/old"
    run git -C "$BATS_TEST_TMPDIR/origin.git" for-each-ref --format='%(refname)' refs/heads/old refs/heads/feature/new
    assert_output "refs/heads/old"
}

@test "rename-branch: an invalid argument changes nothing" {
    _make_sandbox
    run _run_script --quiet old taken
    assert_failure "$err_argument_value"
    run _git for-each-ref --format='%(refname)' refs/heads/old
    assert_output "refs/heads/old"
}
