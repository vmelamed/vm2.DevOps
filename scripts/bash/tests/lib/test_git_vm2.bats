#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_git_vm2.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.
#
# validate_repo_root/resolve_vm2_repos chain into ensure_fresh_git_state, which can perform a
# real `git fetch` when it decides local metadata is stale. To keep these tests deterministic
# and network-free, the "full success path" scenarios build a throwaway LOCAL-ONLY repo (no
# origin remote at all) -- should_fetch_for_latest_stable_tag safely short-circuits to "no fetch
# needed" the moment it can't resolve a remote-tracking ref, with zero network activity. Only
# formal argument validation is exercised against the real vm2.DevOps/vm2.Templates repos.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

setup() {
    _repo_root="$(cd "$lib_dir/../../.." && pwd)"
}

# Builds a minimal local-only (no origin remote) git repo with CI config and one stable tag, so
# validate_repo_root's full logic can be exercised without any network activity.
_make_local_repo() {
    local _dir="$1"
    mkdir -p "$_dir/.github/workflows"
    git -C "$_dir" init --quiet --initial-branch=main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo "name: CI" > "$_dir/.github/workflows/ci.yaml"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: initial commit"
    git -C "$_dir" tag v1.0.0
}

# --- validate_repo_root --------------------------------------------------------------------------

@test "validate_repo_root: bug-exits with the wrong argument count" {
    run validate_repo_root "vm2.DevOps"
    assert_failure 254
}

@test "validate_repo_root: bug-exits on an empty repo name" {
    run validate_repo_root "" "$_repo_root/.."
    assert_failure 254
}

@test "validate_repo_root: bug-exits on a non-existent vm2_repos parent directory" {
    run validate_repo_root "vm2.DevOps" "/definitely/not/a/real/path"
    assert_failure 254
}

@test "validate_repo_root: bug-exits on an invalid branch name" {
    run validate_repo_root "vm2.DevOps" "$_repo_root/.." "..bad..branch.."
    assert_failure 254
}

@test "validate_repo_root: fails with err_not_found for a repo that doesn't exist anywhere" {
    run validate_repo_root "definitely-not-a-real-repo-xyz" "$_repo_root/.."
    assert_failure 9
}

@test "validate_repo_root: fails with err_repo_with_no_ci for a repo with no .github/workflows" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        parent='$BATS_TEST_TMPDIR/norepo-parent'
        mkdir -p \"\$parent/some-repo\"
        git -C \"\$parent/some-repo\" init --quiet --initial-branch=main
        git -C \"\$parent/some-repo\" config user.email t@t.local
        git -C \"\$parent/some-repo\" config user.name t
        echo hi > \"\$parent/some-repo/f.txt\"
        git -C \"\$parent/some-repo\" add -A
        git -C \"\$parent/some-repo\" commit --quiet -m 'chore: init'
        validate_repo_root some-repo \"\$parent\"
    "
    assert_failure 85
}

@test "validate_repo_root: fails with err_invalid_branch when the repo is on the wrong branch" {
    local parent="$BATS_TEST_TMPDIR/wrongbranch-parent"
    mkdir -p "$parent"
    _make_local_repo "$parent/some-repo"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; validate_repo_root some-repo '$parent' not-main"
    assert_failure 84
}

@test "validate_repo_root: succeeds for a well-formed local-only repo on the expected branch" {
    local parent="$BATS_TEST_TMPDIR/good-parent"
    mkdir -p "$parent"
    _make_local_repo "$parent/some-repo"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; validate_repo_root some-repo '$parent' main"
    assert_success
}

# --- resolve_vm2_repos (formal validation only -- the real success path hits real repos) --------

@test "resolve_vm2_repos: bug-exits with too many arguments" {
    run resolve_vm2_repos "a" "b" "c"
    assert_failure 254
}

@test "resolve_vm2_repos: bug-exits on a non-existent directory argument" {
    run resolve_vm2_repos "/definitely/not/a/real/path" vm2_repos
    assert_failure 254
}

@test "resolve_vm2_repos: bug-exits on an undefined output variable name" {
    run resolve_vm2_repos "" "not_a_defined_var"
    assert_failure 254
}

# --- search_repo_dir (real, read-only against the vm2.DevOps checkout) --------------------------

@test "search_repo_dir: finds a known real subdirectory inside a Git repository" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare found=''; search_repo_dir '$_repo_root/..' 'vm2.DevOps/scripts/bash/lib' found; realpath -e \"\$found\""
    assert_success
    assert_output "$lib_dir"
}

@test "search_repo_dir: fails with err_not_found for a name that doesn't exist" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare found=''; search_repo_dir '$_repo_root/..' 'definitely-not-a-real-subdir-xyz' found"
    assert_failure 9
}

@test "search_repo_dir: bug-exits with the wrong argument count" {
    run search_repo_dir "$_repo_root"
    assert_failure 254
}

@test "search_repo_dir: bug-exits on a non-existent search root" {
    run search_repo_dir "/definitely/not/a/real/path" "foo" found
    assert_failure 254
}

# --- resolve_repo_root (real, read-only) ----------------------------------------------------------

@test "resolve_repo_root: resolves the vm2.DevOps repo root and found directory" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare root='' found=''; resolve_repo_root '$_repo_root/..' 'vm2.DevOps' root found; realpath -e \"\$root\"; realpath -e \"\$found\""
    assert_success
    assert_line "$_repo_root"
    [[ $(echo "$output" | wc -l) -eq 2 ]]
}

@test "resolve_repo_root: bug-exits with the wrong argument count" {
    run resolve_repo_root "$_repo_root/.." "vm2.DevOps" root
    assert_failure 254
}

# --- get_vm2_sot_path -------------------------------------------------------------------------

@test "get_vm2_sot_path: bug-exits when the vm2_repos parent argument is empty (regression: was compounding two bugs for one problem)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare sot=''; get_vm2_sot_path '' AddNewPackage sot"
    assert_failure 254
    output_lines_count=$(grep -c "🪲" <<< "$output")
    [[ $output_lines_count -eq 1 ]]
}

@test "get_vm2_sot_path: bug-exits on a non-existent vm2_repos directory" {
    run get_vm2_sot_path "/definitely/not/a/real/path" AddNewPackage sot
    assert_failure 254
}

@test "get_vm2_sot_path: resolves the SoT path when it exists on disk" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        parent='$BATS_TEST_TMPDIR/sot-parent'
        mkdir -p \"\$parent/vm2.Templates/templates/AddNewPackage/content\"
        declare sot=''
        get_vm2_sot_path \"\$parent\" AddNewPackage sot
        echo \"\$sot\"
    "
    assert_success
    assert_output "$BATS_TEST_TMPDIR/sot-parent/vm2.Templates/templates/AddNewPackage/content"
}

@test "get_vm2_sot_path: fails when the SoT directory does not exist" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        parent='$BATS_TEST_TMPDIR/sot-parent-missing'
        mkdir -p \"\$parent\"
        declare sot=''
        get_vm2_sot_path \"\$parent\" AddNewPackage sot
    "
    assert_failure 17
}

@test "get_vm2_sot_path: bug-exits with the wrong argument count" {
    run get_vm2_sot_path "$_repo_root" "AddNewPackage"
    assert_failure 254
}

# --- get_artifacts_path (real, read-only) ---------------------------------------------------------

@test "get_artifacts_path: resolves a relative artifacts path against the real repo root" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare art='artifacts'; get_artifacts_path '$lib_dir/core.sh' art; echo \"\$art\""
    assert_success
    assert_output "$_repo_root/artifacts"
}

@test "get_artifacts_path: bug-exits on a non-existent argument 1" {
    run get_artifacts_path "/definitely/not/a/real/path" art
    assert_failure 254
}

@test "get_artifacts_path: bug-exits with the wrong argument count" {
    run get_artifacts_path "$lib_dir/core.sh"
    assert_failure 254
}
