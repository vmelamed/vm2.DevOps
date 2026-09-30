#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_git_vm2.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.
#
# __validate_repo_root/resolve_vm2_repos chain into ensure_fresh_git_state, which can perform a
# real `git fetch` when it decides local metadata is stale. To keep these tests deterministic
# and network-free, the "full success path" scenarios build a throwaway LOCAL-ONLY repo (no
# origin remote at all) -- should_fetch_for_latest_stable_tag safely short-circuits to "no fetch
# needed" the moment it can't resolve a remote-tracking ref, with zero network activity. Only
# formal argument validation is exercised against the real vm2.DevOps/vm2.Templates repos.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_invalid_arguments
declare -gxi err_argument_value
declare -gxi err_invalid_nameref
declare -gxi err_invalid_path
declare -gxi err_not_directory
declare -gxi err_invalid_branch
declare -gxi err_not_found
declare -gxi err_repo_with_no_ci

setup() {
    _repo_root="$(cd "$lib_dir/../../.." && pwd)"
}

# Builds a minimal local-only (no origin remote) git repo with CI config and one stable tag, so
# __validate_repo_root's full logic can be exercised without any network activity.
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

# --- __validate_repo_root --------------------------------------------------------------------------

@test "__validate_repo_root: bug-exits with the wrong argument count" {
    # NOTE: __validate_repo_root() requires at least 2 arguments (repo name + vm2_repos parent);
    # this used to assume a 1-arg call falls through to a graceful "not found" runtime error (9),
    # but the arity check itself now correctly rejects fewer than 2 arguments as a caller bug.
    run __validate_repo_root "vm2.DevOps"
    assert_failure "$err_invalid_arguments"
}

@test "__validate_repo_root: bug-exits on an empty repo name" {
    run __validate_repo_root "" "$_repo_root/.."
    assert_failure "$err_argument_value"
}

@test "__validate_repo_root: bug-exits on a non-existent vm2_repos parent directory" {
    run __validate_repo_root "vm2.DevOps" "/definitely/not/a/real/path"
    assert_failure "$err_not_directory"
}

@test "__validate_repo_root: bug-exits on an invalid branch name" {
    run __validate_repo_root "vm2.DevOps" "$_repo_root/.." "..bad..branch.."
    assert_failure "$err_invalid_branch"
}

@test "__validate_repo_root: fails with err_not_found for a repo that doesn't exist anywhere" {
    run __validate_repo_root "definitely-not-a-real-repo-xyz" "$_repo_root/.."
    assert_failure "$err_not_found"
}

@test "__validate_repo_root: fails with err_repo_with_no_ci for a repo with no .github/workflows" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        parent='$BATS_TEST_TMPDIR/norepo-parent'
        mkdir -p \"\$parent/some-repo\"
        git -C \"\$parent/some-repo\" init --quiet --initial-branch=main
        git -C \"\$parent/some-repo\" config user.email t@t.local
        git -C \"\$parent/some-repo\" config user.name t
        echo hi > \"\$parent/some-repo/f.txt\"
        git -C \"\$parent/some-repo\" add -A
        git -C \"\$parent/some-repo\" commit --quiet -m 'chore: init'
        __validate_repo_root some-repo \"\$parent\"
    "
    assert_failure "$err_repo_with_no_ci"
}

@test "__validate_repo_root: fails with err_invalid_branch when the repo is on the wrong branch" {
    local parent="$BATS_TEST_TMPDIR/wrongbranch-parent"
    mkdir -p "$parent"
    _make_local_repo "$parent/some-repo"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; __validate_repo_root some-repo '$parent' not-main"
    assert_failure "$err_invalid_branch"
}

@test "__validate_repo_root: succeeds for a well-formed local-only repo on the expected branch" {
    local parent="$BATS_TEST_TMPDIR/good-parent"
    mkdir -p "$parent"
    _make_local_repo "$parent/some-repo"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; __validate_repo_root some-repo '$parent' main"
    assert_success
}

# --- resolve_vm2_repos (formal validation only -- the real success path hits real repos) --------
#
# NOTE: this doc comment and several tests below previously assumed a signature of (directory,
# output-nameref, devops-branch, SoT-branch) -- 1 to 4 arguments, directory first. That does not
# match either the current implementation or the real call sites (setup-repo.sh, diff-shared.sh),
# which both pass the output nameref FIRST. See the summary note.
#
# resolve_vm2_repos() takes 1 to 3 positional arguments: the output nameref variable name (which
# the caller must pre-declare, holding an optional existing vm2_repos directory path or empty),
# and two optional branch names ($2 for vm2.DevOps, $3 for vm2.Templates/SoT) that override the
# "current branch" default -- e.g. diff-shared.sh's --not-main passes '' for both (accept
# whatever branch each repo is on), while setup-repo.sh always passes 'main' 'main'.

@test "resolve_vm2_repos: bug-exits with too many arguments" {
    # NOTE: 'a' must be a real pre-declared variable, or a second bug (arg-1 nameref) accumulates
    # alongside the intended arity bug, and exit_if_has_bugs reports the LAST one recorded
    # (err_invalid_nameref), not this test's intended err_invalid_arguments.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare a=''; resolve_vm2_repos a 'b' 'c' 'd'"
    assert_failure "$err_invalid_arguments"
}

@test "resolve_vm2_repos: accepts 2 or 3 arguments without an arity bug" {
    # an invalid branch name still fails for the branch-validation reason, not an arity mismatch --
    # proving 2 and 3 arguments are both within the valid 1-3 range.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_git_vm2.sh'; declare vm2_repos=''; resolve_vm2_repos vm2_repos '..bad..branch..'"
    assert_failure "$err_invalid_branch"
    assert_output --partial "requires argument 2, if provided, to be a valid branch name (provided '..bad..branch..')"

    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_git_vm2.sh'; declare vm2_repos=''; resolve_vm2_repos vm2_repos '' '..bad..branch..'"
    assert_failure "$err_invalid_branch"
    assert_output --partial "requires argument 3, if provided, to be a valid branch name (provided '..bad..branch..')"
}

@test "resolve_vm2_repos: fails when the pre-set directory value does not exist" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_git_vm2.sh'; declare vm2_repos='/definitely/not/a/real/path'; resolve_vm2_repos vm2_repos"
    assert_failure "$err_not_directory"
    assert_output --partial "requires argument 1, if not empty, to hold an existing directory"
}

@test "resolve_vm2_repos: bug-exits on an undefined output variable name" {
    run resolve_vm2_repos "not_a_defined_var"
    assert_failure "$err_invalid_nameref"
}

@test "resolve_vm2_repos: rejects an invalid branch name in argument 2 (devops branch)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_git_vm2.sh'; declare vm2_repos=''; resolve_vm2_repos vm2_repos '..bad..branch..'"
    assert_failure "$err_invalid_branch"
    assert_output --partial "requires argument 2, if provided, to be a valid branch name (provided '..bad..branch..')"
}

@test "resolve_vm2_repos: rejects an invalid branch name in argument 3 (SoT/vm2.Templates branch)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_git_vm2.sh'; declare vm2_repos=''; resolve_vm2_repos vm2_repos '' '..bad..branch..'"
    assert_failure "$err_invalid_branch"
    assert_output --partial "requires argument 3, if provided, to be a valid branch name (provided '..bad..branch..')"
}

@test "resolve_vm2_repos: an empty branch name in argument 2 or 3 is accepted (means 'current branch')" {
    # empty string is explicitly allowed (skips validate_branch_name) -- only reaches the directory
    # error, never a branch-related error.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_git_vm2.sh'; declare vm2_repos='/definitely/not/a/real/path'; resolve_vm2_repos vm2_repos '' ''"
    assert_failure "$err_not_directory"
    assert_output --partial "requires argument 1, if not empty, to hold an existing directory"
    refute_output --partial "valid branch name"
}

# --- __search_repo_dir (real, read-only against the vm2.DevOps checkout) --------------------------

@test "__search_repo_dir: finds a known real subdirectory inside a Git repository" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare found=''; __search_repo_dir '$_repo_root/..' 'vm2.DevOps/scripts/bash/lib' found; realpath -e \"\$found\""
    assert_success
    assert_output "$lib_dir"
}

@test "__search_repo_dir: fails with err_not_found for a name that doesn't exist" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare found=''; __search_repo_dir '$_repo_root/..' 'definitely-not-a-real-subdir-xyz' found"
    assert_failure 9
}

@test "__search_repo_dir: bug-exits with the wrong argument count" {
    run __search_repo_dir "$_repo_root"
    assert_failure "$err_invalid_arguments"
}

@test "__search_repo_dir: bug-exits on a non-existent search root" {
    # NOTE: 'found' must be a real pre-declared variable, or a second bug (arg-3 nameref)
    # accumulates alongside the intended err_not_directory bug and overrides it as the "last"
    # recorded bug (err_invalid_nameref).
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare found=''; __search_repo_dir '/definitely/not/a/real/path' 'foo' found"
    assert_failure "$err_not_directory"
}

# --- resolve_repo_root (real, read-only) ----------------------------------------------------------

@test "resolve_repo_root: resolves the vm2.DevOps repo root and found directory" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare root='' found=''; resolve_repo_root '$_repo_root/..' 'vm2.DevOps' root found; realpath -e \"\$root\"; realpath -e \"\$found\""
    assert_success
    assert_line "$_repo_root"
    [[ $(echo "$output" | wc -l) -eq 2 ]]
}

@test "resolve_repo_root: bug-exits with the wrong argument count" {
    # NOTE: 'root' must be a real pre-declared variable, or a second bug (arg-3 nameref)
    # accumulates alongside the intended arity bug, and exit_if_has_bugs reports the LAST one
    # recorded (err_invalid_nameref), not this test's intended err_invalid_arguments.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare root=''; resolve_repo_root '$_repo_root/..' 'vm2.DevOps' root"
    assert_failure "$err_invalid_arguments"
}

# --- get_vm2_sot_path -------------------------------------------------------------------------

@test "get_vm2_sot_path: bug-exits when the vm2_repos parent argument is empty (regression: was compounding two bugs for one problem)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare sot=''; get_vm2_sot_path '' AddNewPackage sot"
    assert_failure "$err_invalid_path"
    output_lines_count=$(grep -c "🪲" <<< "$output")
    [[ $output_lines_count -eq 1 ]]
}

@test "get_vm2_sot_path: fails on a non-existent vm2_repos directory" {
    # NOTE: 'sot' must be a real pre-declared variable, or a second bug (arg-3 nameref)
    # accumulates and overrides the intended runtime err_not_directory outcome.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare sot=''; get_vm2_sot_path '/definitely/not/a/real/path' AddNewPackage sot"
    assert_failure "$err_not_directory"
}

@test "get_vm2_sot_path: resolves the SoT path when it exists on disk" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
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
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        parent='$BATS_TEST_TMPDIR/sot-parent-missing'
        mkdir -p \"\$parent\"
        declare sot=''
        get_vm2_sot_path \"\$parent\" AddNewPackage sot
    "
    assert_failure "$err_not_directory"
}

@test "get_vm2_sot_path: bug-exits with the wrong argument count" {
    run get_vm2_sot_path "$_repo_root" "AddNewPackage"
    assert_failure "$err_invalid_arguments"
}

# get_artifacts_path() no longer lives in _git_vm2.sh -- it moved to _dotnet.sh as a thin wrapper
# over get_msbuild_property() (see test_dotnet_args.bats and test_dotnet.bats for its coverage).

# --- get_devops_parent -----------------------------------------------------------------------

@test "get_devops_parent: resolves the parent directory of the real vm2.DevOps checkout" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_devops_parent"
    assert_success
    assert_output "$(dirname "$_repo_root")"
}

@test "get_devops_parent: memoizes the result across repeated calls in the same process" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_devops_parent; get_devops_parent"
    assert_success
    assert_line --index 0 "$(dirname "$_repo_root")"
    assert_line --index 1 "$(dirname "$_repo_root")"
}
