#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_git.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.
#
# Functions that make real network calls (execute_gh_with_retry, execute_gh_api_with_retry, the
# full-info branch of get_repo_state, ensure_fresh_git_state's actual fetch) are only exercised
# for their formal argument validation here, not their real network behavior -- these tests run
# against the actual vm2.DevOps repository (read-only git operations only) for everything else.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

setup() {
    _repo_root="$(cd "$lib_dir/../../.." && pwd)"
}

# --- validate_gh_repo_owner / validate_gh_repo_name / validate_gh_repo_description --------------

@test "validate_gh_repo_owner: accepts empty and a valid owner, rejects an invalid one" {
    run validate_gh_repo_owner ""
    assert_success
    run validate_gh_repo_owner "vmelamed"
    assert_success
    run validate_gh_repo_owner "-leading-hyphen"
    assert_failure 4
}

@test "validate_gh_repo_owner: bug-exits with the wrong argument count" {
    run validate_gh_repo_owner
    assert_failure 254
}

@test "validate_gh_repo_name: rejects empty, rejects .git suffix, accepts a valid name" {
    run validate_gh_repo_name ""
    assert_failure 4
    run validate_gh_repo_name "vm2.DevOps.git"
    assert_failure 4
    run validate_gh_repo_name "vm2.DevOps"
    assert_success
}

@test "validate_gh_repo_description: enforces the 3-350 character range" {
    run validate_gh_repo_description "ab"
    assert_failure 4
    run validate_gh_repo_description "A valid description"
    assert_success
    run validate_gh_repo_description "$(printf 'a%.0s' {1..351})"
    assert_failure 4
}

# --- validate_branch_name -----------------------------------------------------------------------

@test "validate_branch_name: accepts a valid branch name, rejects an invalid one" {
    run validate_branch_name "main"
    assert_success
    run validate_branch_name "feature/foo"
    assert_success
    run validate_branch_name "..bad..name"
    assert_failure 4
}

@test "validate_branch_name: bug-exits with the wrong argument count" {
    run validate_branch_name
    assert_failure 254
}

# --- initialize_repo_state -----------------------------------------------------------------------

@test "initialize_repo_state: populates every predefined key with an empty string" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; for k in \"\${!state[@]}\"; do echo \"\$k=[\${state[\$k]}]\"; done | sort"
    assert_success
    assert_line "name=[]"
    assert_line "owner=[]"
    assert_line "repo=[]"
    assert_line "root=[]"
    assert_line "url=[]"
}

@test "initialize_repo_state: bug-exits on a non-associative-array argument" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a arr=(); initialize_repo_state arr"
    assert_failure 254
}

# --- get_repo_state (local git only, full_info=false to avoid network calls) --------------------

@test "get_repo_state: populates local fields for the real vm2.DevOps repo, without calling the GitHub API" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo_root' state false; echo \"root=[\${state[root]}]\"; echo \"owner=[\${state[owner]}]\"; echo \"name=[\${state[name]}]\"; echo \"repo_id=[\${state[repo_id]}]\""
    assert_success
    assert_output --partial "root=[$_repo_root]"
    assert_output --partial "name=[vm2.DevOps]"
    assert_output --partial "repo_id=[]"
}

@test "get_repo_state: bug-exits on a non-existent directory" {
    run get_repo_state "/definitely/not/a/real/path" state false
    assert_failure 254
}

@test "get_repo_state: bug-exits with the wrong argument count" {
    run get_repo_state "$_repo_root"
    assert_failure 254
}

# --- has_local_repo / has_remote_repo / has_github_remote ---------------------------------------

@test "has_local_repo / has_remote_repo: true for the real vm2.DevOps repo state" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo_root' state false; has_local_repo state"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo_root' state false; has_remote_repo state"
    assert_success
}

@test "has_local_repo: false for a freshly-initialized (empty) repo state" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; has_local_repo state"
    assert_failure 1
}

@test "has_github_remote: false without full repo-id info (full_info=false never populates it)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo_root' state false; has_github_remote state"
    assert_failure 1
}

# --- read_repo_state / print_repo_state ----------------------------------------------------------

@test "read_repo_state: deserializes key=value lines into the repo state" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); read_repo_state state < <(printf 'owner=acme\nname=widget\n'); echo \"owner=[\${state[owner]}] name=[\${state[name]}]\""
    assert_success
    assert_output "owner=[acme] name=[widget]"
}

@test "print_repo_state: prints every predefined key" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; state[owner]=acme; print_repo_state state"
    assert_success
    assert_output --partial "owner: acme"
    assert_output --partial "root:"
}

@test "print_repo_state: bug-exits with the wrong argument count (regression: was missing exit_if_has_bugs)" {
    run print_repo_state
    assert_failure 254
    run print_repo_state a b
    assert_failure 254
}

# --- is_inside_work_tree / root_working_tree -----------------------------------------------------

@test "is_inside_work_tree: true for the real vm2.DevOps repo, false for /tmp" {
    run is_inside_work_tree "$_repo_root"
    assert_success
    run is_inside_work_tree /tmp
    assert_failure 1
}

@test "is_inside_work_tree: bug-exits on a non-existent directory" {
    run is_inside_work_tree "/definitely/not/a/real/path"
    assert_failure 254
}

@test "root_working_tree: resolves the real repo root" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare root=''; root_working_tree '$_repo_root/scripts' root; echo \"\$root\""
    assert_success
    assert_output "$_repo_root"
}

@test "root_working_tree: bug-exits on an invalid (empty) nameref, without a raw bash crash (regression)" {
    run root_working_tree "$_repo_root" ""
    assert_failure 254
    refute_output --partial "not a valid identifier"
}

@test "root_working_tree: bug-exits on a directory outside any Git work tree" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare root=''; root_working_tree /tmp root"
    assert_failure 254
}

# --- should_fetch_for_latest_stable_tag (read-only against the real repo) -----------------------

@test "should_fetch_for_latest_stable_tag: runs cleanly (success or failure) against the real repo without bug-exiting" {
    run should_fetch_for_latest_stable_tag "$_repo_root" "main"
    [[ $status -eq 0 || $status -eq 1 ]]
}

@test "should_fetch_for_latest_stable_tag: bug-exits on an invalid branch name" {
    run should_fetch_for_latest_stable_tag "$_repo_root" "..bad..branch.."
    assert_failure 254
}

@test "should_fetch_for_latest_stable_tag: bug-exits with too many arguments" {
    run should_fetch_for_latest_stable_tag "$_repo_root" "main" "extra"
    assert_failure 254
}

# --- get_latest_stable_tag_hash / is_after_latest_stable_tag / is_on_or_after_latest_stable_tag -

@test "get_latest_stable_tag_hash: resolves a commit hash for the real repo without fetching" {
    run get_latest_stable_tag_hash "$_repo_root" false
    assert_success
    [[ ${#output} -eq 40 ]]
}

@test "get_latest_stable_tag_hash: bug-exits on a non-boolean fetch flag" {
    run get_latest_stable_tag_hash "$_repo_root" "maybe"
    assert_failure 254
}

@test "get_latest_stable_tag_hash: bug-exits with too many arguments" {
    run get_latest_stable_tag_hash "$_repo_root" false "extra"
    assert_failure 254
}

@test "is_after_latest_stable_tag / is_on_or_after_latest_stable_tag: run cleanly against the real repo without fetching" {
    run is_after_latest_stable_tag "$_repo_root" false
    [[ $status -eq 0 || $status -eq 1 ]]
    run is_on_or_after_latest_stable_tag "$_repo_root" false
    [[ $status -eq 0 || $status -eq 1 ]]
}

# --- execute_gh_with_retry / execute_gh_api_with_retry (formal validation only, no network) ------

@test "execute_gh_with_retry: bug-exits with too few arguments" {
    run execute_gh_with_retry 3 2
    assert_failure 254
}

@test "execute_gh_with_retry: bug-exits on a non-natural max-attempts or delay" {
    run execute_gh_with_retry -1 2 repo view
    assert_failure 254
    run execute_gh_with_retry 3 -1 repo view
    assert_failure 254
}

@test "execute_gh_with_retry: honors dry-run without invoking gh for real" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute_gh_with_retry 3 2 repo delete some/nonexistent-repo --yes"
    assert_success
    assert_output --partial "dry-run"
}

@test "execute_gh_api_with_retry: bug-exits with too few arguments" {
    run execute_gh_api_with_retry 3 2
    assert_failure 254
}

@test "execute_gh_api_with_retry: honors dry-run without invoking gh for real" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute_gh_api_with_retry 3 2 repos/acme/nonexistent"
    assert_success
    assert_output --partial "dry-run"
}

# --- ensure_fresh_git_state (formal validation only, no real fetch) ------------------------------

@test "ensure_fresh_git_state: bug-exits on an invalid branch name (via should_fetch_for_latest_stable_tag)" {
    run ensure_fresh_git_state "$_repo_root" "..bad..branch.."
    assert_failure 254
}
