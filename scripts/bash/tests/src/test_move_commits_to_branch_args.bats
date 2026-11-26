#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/move-commits-to-branch.args.sh (with move-commits-to-branch.usage.sh), following the seams of
# the get_arguments() pipeline (see test_diff_shared_args.bats, the reference implementation). Each test sources core.sh
# and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell.
#
#
# verify_environment() and resolve_arguments() query the repository in the current directory (its branch, its working
# tree, its commits, its origin), so those tests run inside a sandbox (_make_repo): a clone of a local bare repository, so
# 'git fetch' never reaches the network. The origin is not GitHub, so the tests stub get_repo_state(), which would ask the
# GitHub API for the default branch (_github_default_branch, _github_not_found, _github_unreachable).

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx err_missing_argument
declare -gx err_unknown_argument

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
# A clone of a local bare repository ('origin'), on 'main', with two commits pushed; $_sha is the first one. The user's
# hooks are disabled in both repositories' own configs, which override a global or system core.hooksPath ('-c' on 'git
# init' too: creating a repository already runs the reference-transaction hook).
_make_repo() {
    _origin="$BATS_TEST_TMPDIR/origin.git"
    _repo="$BATS_TEST_TMPDIR/repo"
    git -c core.hooksPath=/dev/null init --quiet --bare --initial-branch=main "$_origin"
    git -C "$_origin" config core.hooksPath /dev/null
    git clone --quiet -c core.hooksPath=/dev/null "$_origin" "$_repo" 2> /dev/null
    git -C "$_repo" config user.email "test@test.local"
    git -C "$_repo" config user.name "test"
    git -C "$_repo" switch --quiet -C main
    echo one > "$_repo/a.txt"; git -C "$_repo" add -A; git -C "$_repo" commit --quiet -m "chore: one"
    _sha=$(git -C "$_repo" rev-parse HEAD)
    echo two > "$_repo/a.txt"; git -C "$_repo" commit --quiet -am "chore: two"
    git -C "$_repo" push --quiet -u origin main 2> /dev/null
}

# Pushes a new commit to origin's 'main' from a second clone, so the sandbox's 'main' is behind 'origin/main'.
_advance_origin() {
    local _other="$BATS_TEST_TMPDIR/other"
    git clone --quiet -c core.hooksPath=/dev/null "$_origin" "$_other" 2> /dev/null
    git -C "$_other" -c user.name=test -c user.email=test@test.local commit --quiet --allow-empty -m "chore: three"
    git -C "$_other" push --quiet origin main 2> /dev/null
}

# Stubs of get_repo_state() in place of the GitHub API: $1 is the default branch it reports (it does not have to be 'main').
_github_default_branch() {
    echo "get_repo_state() { local -n __stub_state=\$2; __stub_state[\$key_default_branch]='$1'; }"
}
_github_not_found='get_repo_state() { return 0; }'      # origin is not GitHub: success, but no default branch
_github_unreachable='get_repo_state() { return 1; }'

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

@test "verify_environment: succeeds silently on a clean default branch, and captures the current and the default branch" {
    _make_repo
    run _mc "$(_github_default_branch main)
             verify_environment; echo \"rc=\$?\"
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p current_branch default_branch" "$_repo"
    assert_success
    assert_output --partial "rc=0"
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'current_branch="main"'
    assert_output --partial 'default_branch="main"'
}

@test "verify_environment: reports a branch other than the default and returns instead of exiting" {
    _make_repo
    git -C "$_repo" switch --quiet -c feature
    run _mc "$(_github_default_branch main)
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Invalid current branch 'feature': it must be the default branch 'main'."
    refute_output --partial "is behind"     # the branch check comes first: being behind is about the wrong branch here
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: the default branch is the one GitHub reports, not a hard-coded 'main'" {
    _make_repo
    run _mc "$(_github_default_branch develop)
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Invalid current branch 'main': it must be the default branch 'develop'."
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports a local default branch that is behind origin" {
    _make_repo
    _advance_origin
    run _mc "$(_github_default_branch main)
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Local 'main' is behind 'origin/main'. Pull first."
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: a local default branch ahead of origin is fine" {
    _make_repo
    git -C "$_repo" commit --quiet --allow-empty -m "chore: local only"
    run _mc "$(_github_default_branch main)
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "NO_ERRORS"
}

@test "verify_environment: reports uncommitted changes" {
    _make_repo
    echo dirty >> "$_repo/a.txt"
    run _mc "$(_github_default_branch main)
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "You have uncommitted changes"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports an origin that is not a GitHub repository" {
    _make_repo
    run _mc "$_github_not_found
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Origin is not a GitHub repository: cannot determine its default branch."
    refute_output --partial "is behind"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports a failure to get the repository state from GitHub" {
    _make_repo
    run _mc "$_github_unreachable
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Failed to obtain the name of the default branch from GitHub."
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports a failed fetch, and checks nothing that depends on it" {
    _make_repo
    rm -rf "$_origin"
    run _mc "$(_github_default_branch main)
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Failed to fetch from remote."
    refute_output --partial "is behind"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: a missing git ends the run right there (circuit breaker)" {
    _make_repo
    run _mc "is_tool_present() { [[ \$1 != git ]]; }
             verify_environment
             echo REACHED" "$_repo"
    assert_failure
    assert_output --partial "'git' is not installed"
    refute_output --partial "REACHED"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: accepts a valid new branch and an existing commit, and freezes the variables" {
    _make_repo
    run _mc "new_branch=feature/x
             commit_sha=${_sha:0:7}
             current_branch=main
             default_branch=main
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p new_branch commit_sha check_out_new_branch current_branch default_branch" "$_repo"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx new_branch="feature/x"'
    assert_output --partial "declare -rx commit_sha=\"${_sha:0:7}\""
    assert_output --partial 'declare -rx check_out_new_branch="false"'
    assert_output --partial 'declare -rx current_branch="main"'
    assert_output --partial 'declare -rx default_branch="main"'
}

@test "resolve_arguments: reports a missing --branch and a missing --commit-sha together" {
    _make_repo
    run _mc "resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\"" "$_repo"
    assert_success
    assert_output --partial "The option '--branch' is mandatory."
    assert_output --partial "The option '--commit-sha' is mandatory."
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

@test "resolve_arguments: rejects the default branch as the new branch" {
    _make_repo
    run _mc "new_branch=main
             commit_sha=$_sha
             default_branch=main
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Invalid new branch name 'main': it cannot be the default branch."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: the forbidden new branch is the default branch, whatever its name" {
    _make_repo
    run _mc "new_branch=develop
             commit_sha=$_sha
             current_branch=main
             default_branch=develop
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Invalid new branch name 'develop': it cannot be the default branch."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects a commit SHA that is not hexadecimal" {
    _make_repo
    run _mc "new_branch=feature/x
             commit_sha=not-a-sha
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Invalid commit SHA"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects a well-formed SHA of a commit that does not exist" {
    _make_repo
    run _mc "new_branch=feature/x
             commit_sha=deadbeefdeadbeef
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Invalid commit 'deadbeefdeadbeef': it does not exist."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects an existing commit that is not on the current branch" {
    _make_repo
    git -C "$_repo" switch --quiet -c elsewhere "$_sha"
    git -C "$_repo" commit --quiet --allow-empty -m "chore: elsewhere"
    local _elsewhere
    _elsewhere=$(git -C "$_repo" rev-parse HEAD)
    git -C "$_repo" switch --quiet main
    run _mc "new_branch=feature/x
             commit_sha=$_elsewhere
             current_branch=main
             default_branch=main
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_repo"
    assert_success
    assert_output --partial "Commit '$_elsewhere' is not on 'main'."
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, verifies, resolves, and freezes the arguments in one call" {
    _make_repo
    run _mc "$(_github_default_branch main)
             get_arguments --branch feature/x --commit-sha $_sha
             declare -p new_branch commit_sha default_branch" "$_repo"
    assert_success
    assert_output --partial 'declare -rx new_branch="feature/x"'
    assert_output --partial "declare -rx commit_sha=\"$_sha\""
    assert_output --partial 'declare -rx default_branch="main"'
}

@test "get_arguments: a failed fetch leaves no unset current branch behind (regression: set -u aborted the run)" {
    _make_repo
    git -C "$_repo" switch --quiet -c elsewhere "$_sha"
    git -C "$_repo" commit --quiet --allow-empty -m "chore: elsewhere"
    local _elsewhere
    _elsewhere=$(git -C "$_repo" rev-parse HEAD)
    git -C "$_repo" switch --quiet main
    rm -rf "$_origin"
    # verify_environment fails before it sets current_branch; resolve_arguments still runs, and its message for a commit
    # that is not on the current branch expands current_branch. The script itself runs with 'set -euo pipefail'.
    run _mc "set -euo pipefail
             $(_github_default_branch main)
             get_arguments --branch feature/x --commit-sha $_elsewhere; echo AFTER" "$_repo"
    assert_failure
    refute_output --partial "unbound variable"
    assert_output --partial "Failed to fetch from remote."
    assert_output --partial "Commit '$_elsewhere' is not on 'HEAD'."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: -h prints the usage and exits 0, even off the default branch with a dirty tree" {
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
    run _mc "$(_github_default_branch main)
             get_arguments --branch main --commit-sha deadbeef; echo AFTER" "$_repo"
    assert_failure
    assert_output --partial "Invalid current branch 'feature': it must be the default branch 'main'."
    assert_output --partial "Invalid new branch name 'main': it cannot be the default branch."
    assert_output --partial "Invalid commit 'deadbeef': it does not exist."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
