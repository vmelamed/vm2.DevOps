#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/lib/_git.sh: plain git, no GitHub (see test_git_gh.bats for that).
#
# The fetch in ensure_fresh_git_state is only exercised for its formal argument validation; everything else runs
# read-only git operations against the actual vm2.DevOps repository.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx failure
declare -gx err_invalid_arguments
declare -gx err_invalid_nameref
declare -gx err_argument_value
declare -gx err_argument_type
declare -gx err_not_directory
declare -gx err_not_git_directory
declare -gx err_invalid_branch
declare -gx err_invalid_branch_name
declare -gx err_invalid_tag
declare -gx err_invalid_sha
declare -gx err_invalid_repo

setup() {
    _repo_root="$(cd "$lib_dir/../../.." && pwd)"
    # Hermetic git: ignore the developer's ~/.gitconfig. E.g. a 'url.git@github.com:.insteadOf https://github.com/'
    # rule makes 'git remote get-url' return SSH URLs for HTTPS remotes, which once hid an HTTPS-only bug in
    # get_repo_state (the '.git' suffix was stripped for SSH only) -- the tests passed locally for the wrong reason.
    export GIT_CONFIG_GLOBAL=/dev/null
}

# --- is_valid_branch_name -----------------------------------------------------------------------

@test "is_valid_branch_name: accepts a valid branch name, rejects an invalid one" {
    run is_valid_branch_name "main"
    assert_success
    run is_valid_branch_name "feature/foo"
    assert_success
    run is_valid_branch_name "..bad..name"
    assert_failure "$err_invalid_branch_name"
    assert_output --partial "Invalid branch name '..bad..name'"
}

@test "is_valid_branch_name: bug-exits with the wrong argument count" {
    run is_valid_branch_name
    assert_failure "$err_invalid_arguments"
}

# --- is_branch_name -------------------------------------------------------------------

@test "is_branch_name: true for a valid branch name, false for an invalid one" {
    run is_branch_name "feature/foo"
    assert_success
    run is_branch_name "..bad..name"
    assert_failure "$failure"
}

@test "is_branch_name: validates the name without its refs/heads/ prefix" {
    run is_branch_name "refs/heads/feature/foo"
    assert_success
    # '-bad' is not a valid branch name, though 'refs/heads/-bad' is a valid ref
    run is_branch_name "refs/heads/-bad"
    assert_failure
}

@test "is_branch_name: false (not a bug) for an empty branch name" {
    run is_branch_name ""
    assert_failure "$failure"
}

@test "is_branch_name: bug-exits with the wrong argument count" {
    run is_branch_name
    assert_failure "$err_invalid_arguments"
}

# --- is_tag_name -----------------------------------------------------------------------

@test "is_tag_name: true for ordinary tag names, including hierarchical ones" {
    local _tag
    for _tag in v1.2.3 v1.2.3-preview.4 v1.2.3+build.5 release/1.0 a 'ü'; do
        run is_tag_name "$_tag"
        assert_success
    done
}

@test "is_tag_name: false (not a bug) for an empty name" {
    run is_tag_name ""
    assert_failure "$failure"
}

@test "is_tag_name: false for the names git's ref-format rules reject" {
    local _tag
    for _tag in 'bad..tag' 'a b' $'a\tb' $'a\nb' 'a~b' 'a^b' 'a:b' 'a?b' 'a*b' 'a[b' 'a\b' \
                'a@{b' '.v1' 'v1.' 'v1.lock' 'v1/' '/v1' 'a//b'; do
        run is_tag_name "$_tag"
        assert_failure "$failure"
    done
}

@test "is_tag_name: false for '@{-1}' -- validated as a tag, it is not expanded to the previous branch" {
    run is_tag_name '@{-1}'
    assert_failure "$failure"
}

@test "is_tag_name: false for a name that starts with '-' -- 'git tag' refuses it, although 'git check-ref-format' accepts it" {
    local _tag
    for _tag in -v1 --delete -; do
        run is_tag_name "$_tag"
        assert_failure "$failure"
    done
}

@test "is_tag_name: true for HEAD and @ -- 'git tag' creates them; callers must address them as 'refs/tags/<name>'" {
    local _tag
    for _tag in HEAD @; do
        run is_tag_name "$_tag"
        assert_success
    done
}

@test "is_tag_name: works outside a git repository" {
    run bash -c "cd '$BATS_TEST_TMPDIR' && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
                 is_tag_name v1.2.3 && echo VALID
                 is_tag_name 'bad..tag' || echo INVALID"
    assert_success
    assert_output --partial "VALID"
    assert_output --partial "INVALID"
}

@test "is_tag_name: bug-exits with the wrong argument count" {
    run is_tag_name
    assert_failure "$err_invalid_arguments"
    run is_tag_name v1 v2
    assert_failure "$err_invalid_arguments"
}

# --- is_valid_tag_name ---------------------------------------------------------------------

@test "is_valid_tag_name: accepts a valid tag name, with or without 'refs/tags/', without a message" {
    run is_valid_tag_name "v1.2.3"
    assert_success
    assert_output ""
    run is_valid_tag_name "refs/tags/v1.2.3-preview.4"
    assert_success
    assert_output ""
}

@test "is_valid_tag_name: rejects an empty name, a leading '-', and a malformed name with err_invalid_tag and an error" {
    local tag
    for tag in "" "-v1.2.3" "bad..tag"; do
        run is_valid_tag_name "$tag"
        assert_failure "$err_invalid_tag"
        assert_output --partial "'$tag'"
    done
}

@test "is_valid_tag_name: bug-exits with the wrong argument count" {
    run is_valid_tag_name
    assert_failure "$err_invalid_arguments"
}

# --- is_valid_commit_sha ---------------------------------------------------------------------

@test "is_valid_commit_sha: accepts the lengths git can accept: 4 to 64 hexadecimal digits, in either case, without a message" {
    local sha
    for sha in "$(printf 'a%.0s' {1..4})" "$(printf 'a%.0s' {1..40})" "$(printf 'a%.0s' {1..64})" "94F1ABE56"; do
        run is_valid_commit_sha "$sha"
        assert_success
        assert_output ""
    done
}

@test "is_valid_commit_sha: rejects a SHA outside the 4 to 64 digits range with err_invalid_sha and an 'Invalid commit SHA' error" {
    local sha
    for sha in "abc" "$(printf 'a%.0s' {1..65})"; do
        run is_valid_commit_sha "$sha"
        assert_failure "$err_invalid_sha"
        assert_output --partial "Invalid commit SHA '$sha'"
    done
}

@test "is_valid_commit_sha: rejects (does not bug-exit on) an empty string or a non-hexadecimal character" {
    local sha
    for sha in "" "94f1abg56"; do
        run is_valid_commit_sha "$sha"
        assert_failure "$err_invalid_sha"
        assert_output --partial "Invalid commit SHA '$sha'"
    done
}

@test "is_valid_commit_sha: checks the format only -- it does not ask git whether the commit exists" {
    run bash -c "cd '$BATS_TEST_TMPDIR' && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; is_valid_commit_sha 'deadbeef'"
    assert_success
}

@test "is_valid_commit_sha: bug-exits with the wrong argument count" {
    run is_valid_commit_sha
    assert_failure "$err_invalid_arguments"
}

# --- is_inside_work_tree / root_working_tree -----------------------------------------------------

@test "is_inside_work_tree: true for the real vm2.DevOps repo, false for /tmp" {
    run is_inside_work_tree "$_repo_root"
    assert_success
    run is_inside_work_tree /tmp
    assert_failure "$failure"
}

@test "is_inside_work_tree: bug-exits on a non-existent directory" {
    run is_inside_work_tree "/definitely/not/a/real/path"
    assert_failure "$err_not_directory"
}

@test "root_working_tree: resolves the real repo root" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare root=''; root_working_tree '$_repo_root/scripts' root; echo \"\$root\""
    assert_success
    assert_output "$_repo_root"
}

@test "root_working_tree: bug-exits on an invalid (empty) nameref, without a raw bash crash (regression)" {
    run root_working_tree "$_repo_root" ""
    assert_failure "$err_invalid_nameref"
    refute_output --partial "not a valid identifier"
}

@test "root_working_tree: bug-exits on a directory outside any Git work tree" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare root=''; root_working_tree /tmp root"
    assert_failure "$err_not_git_directory"
}

# --- should_fetch_for_latest_stable_tag (read-only against the real repo) -----------------------

@test "should_fetch_for_latest_stable_tag: runs cleanly (success or failure) against the real repo without bug-exiting" {
    run should_fetch_for_latest_stable_tag "$_repo_root" "main"
    [[ $status -eq 0 || $status -eq 1 ]]
}

@test "should_fetch_for_latest_stable_tag: bug-exits on an invalid branch name" {
    run should_fetch_for_latest_stable_tag "$_repo_root" "..bad..branch.."
    assert_failure "$err_argument_value"
}

@test "should_fetch_for_latest_stable_tag: bug-exits with too many arguments" {
    run should_fetch_for_latest_stable_tag "$_repo_root" "main" "extra"
    assert_failure "$err_invalid_arguments"
}

# --- get_latest_stable_tag_hash / verify_after_latest_stable_tag / verify_on_or_after_latest_stable_tag -

@test "get_latest_stable_tag_hash: resolves a commit hash for the real repo without fetching" {
    local hash=''
    get_latest_stable_tag_hash "$_repo_root" false hash     # in-process: a nameref does not cross 'run'
    [[ $hash =~ ^[0-9a-f]{40}$ ]]
}

@test "get_latest_stable_tag_hash: bug-exits on a non-boolean fetch flag" {
    local hash=''
    run get_latest_stable_tag_hash "$_repo_root" "maybe" hash
    assert_failure "$err_argument_type"
}

@test "get_latest_stable_tag_hash: bug-exits on an undeclared output variable" {
    run get_latest_stable_tag_hash "$_repo_root" false "no_such_variable"
    assert_failure "$err_invalid_nameref"
}

@test "get_latest_stable_tag_hash: bug-exits with too few arguments" {
    run get_latest_stable_tag_hash "$_repo_root" false
    assert_failure "$err_invalid_arguments"
}

@test "get_latest_stable_tag_hash: bug-exits with too many arguments" {
    local hash=''
    run get_latest_stable_tag_hash "$_repo_root" false hash "extra"
    assert_failure "$err_invalid_arguments"
}

@test "verify_after_latest_stable_tag / verify_on_or_after_latest_stable_tag: run cleanly against the real repo without fetching" {
    run verify_after_latest_stable_tag "$_repo_root" false
    [[ $status -eq 0 || $status -eq $err_not_after_latest_stable_tag ]]
    run verify_on_or_after_latest_stable_tag "$_repo_root" false
    [[ $status -eq 0 || $status -eq $err_behind_latest_stable_tag ]]
}

# --- ensure_fresh_git_state (formal validation only, no real fetch) ------------------------------

@test "ensure_fresh_git_state: bug-exits on an invalid branch name (via should_fetch_for_latest_stable_tag)" {
    run ensure_fresh_git_state "$_repo_root" "..bad..branch.."
    assert_failure "$err_argument_value"
}
