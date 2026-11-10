#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/diff-shared.functions.sh, as it behaves TODAY.
#
# These files are designed to be 'source'd from diff-shared.sh, after core.sh has already established
# script_name/script_dir/lib_dir as readonly globals. They are exercised the same way as the scripts/bash/lib/*.sh
# characterization tests: each test spawns a fresh, ambient-environment-free ('env -i HOME="$HOME" PATH=...') bash
# subshell that sources core.sh and then the file(s) under test, so every test starts from a pristine, deterministic state.
#
# diff-shared.sh proper (the top-level orchestrator) is not exercised end-to-end here -- it is an interactive tool that
# shells out to real diff/merge tools and prompts the user via 'confirm'/'choose'. Its logic lives almost entirely in the
# functions tested in test_diff_shared_*.bats; the top-level script itself is a thin driver loop over them.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_invalid_arguments
declare -gxi err_invalid_nameref
declare -gxi err_not_directory
declare -gxi err_not_file
declare -gxi err_not_found
declare -gxi err_logic_error
declare -gxi err_argument_type
declare -gxi positive

# shared_equal/shared_not_equal are defined in diff-shared.functions.sh itself, not core.sh, so ../helpers/setup does not
# transplant them into this outer scope -- only the fresh env -i subshell _ds() spawns per test actually sources that file.
# Assertions against these two outcomes therefore use their literal values (2 and 3, per diff-shared.functions.sh)
# directly.

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# Sources core.sh, then diff-shared.configuration.sh, diff-shared.functions.sh, and diff-shared.summary.sh inside a fresh
# env -i subshell, then runs the caller-supplied bash snippet.
_ds() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/diff-shared.configuration.sh'
        source '$_src_dir/diff-shared.functions.sh'
        source '$_src_dir/diff-shared.summary.sh'
        $1
    "
}

_make_ci_repo() {
    local _dir="$1"
    mkdir -p "$_dir/.github/workflows"
    git -C "$_dir" init --quiet --initial-branch=main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo "name: CI" > "$_dir/.github/workflows/ci.yaml"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: init"
}

# =====================================================================================
# are_different()
# =====================================================================================

@test "are_different: bug-exits with the wrong argument count" {
    # arg1 also fails its own existence check (the file doesn't exist), so err_not_file --
    # not the arity code -- is the "last" bug reported.
    run _ds "are_different '$BATS_TEST_TMPDIR/a'"
    assert_failure "$err_not_file"
}

@test "are_different: bug-exits when either file does not exist" {
    touch "$BATS_TEST_TMPDIR/a.txt"
    run _ds "are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/missing.txt' false true"
    assert_failure "$err_not_file"
}

@test "are_different: bug-exits on a non-boolean display-diff or warn-no-markers flag" {
    touch "$BATS_TEST_TMPDIR/a.txt" "$BATS_TEST_TMPDIR/b.txt"
    run _ds "are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' notabool true"
    assert_failure "$err_argument_type"
    run _ds "are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' true notabool"
    assert_failure "$err_argument_type"
}

@test "are_different: returns failure (negative) and counts 'identical' for two identical files" {
    echo "same" > "$BATS_TEST_TMPDIR/a.txt"
    echo "same" > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "declare -i summary_identical_count=0 summary_diff_count=0
             are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false true
             echo \"RC=\$?\"
             declare -p summary_identical_count summary_diff_count"
    assert_success
    assert_output --partial "RC=1"
    assert_output --partial 'summary_identical_count="1"'
    assert_output --partial 'summary_diff_count="0"'
}

@test "are_different: returns success (positive) and counts 'diff' for two different files" {
    echo "one" > "$BATS_TEST_TMPDIR/a.txt"
    echo "two" > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "declare -i summary_identical_count=0 summary_diff_count=0
             are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false true
             echo \"RC=\$?\"
             declare -p summary_identical_count summary_diff_count"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'summary_diff_count="1"'
    assert_output --partial 'summary_identical_count="0"'
}

@test "are_different: returns \$shared_equal when the files differ but their shared blocks match" {
    printf 'private A\n<<<===\nshared 1\nshared 2\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/a.txt"
    printf 'DIFFERENT private A\n<<<===\nshared 1\nshared 2\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false true"
    assert_failure 2 # $shared_equal
}

@test "are_different: returns \$shared_not_equal when the files differ and their shared blocks also differ" {
    printf 'private A\n<<<===\nshared 1\nshared 2\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/a.txt"
    printf 'private A\n<<<===\nCHANGED shared 1\nshared 2\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false true"
    assert_failure 3 # $shared_not_equal
}

@test "are_different: works under 'set -u', as in the real script (regression: undeclared _rc on the success path)" {
    printf 'private A\n<<<===\nshared 1\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/a.txt"
    printf 'DIFFERENT private A\n<<<===\nshared 1\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "declare -i summary_shared_identical_count=0
             declare vm2_repos=''
             set -u
             are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false true"
    assert_failure 2 # $shared_equal
    refute_output --partial "unbound variable"
}

@test "are_different: falls back to plain \$positive and warns when a marker is missing from either file, if asked to" {
    # $positive is 0/success -- are_different()'s normal "different" outcome -- so, like the
    # existing 'returns success (positive)' test above, this asserts success plus an explicit
    # RC echo, not assert_failure.
    printf 'private A\n<<<===\nshared 1\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/a.txt"
    printf 'no markers at all here\n' > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false true
             echo \"RC=\$?\""
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial "Could not find a single, well-formed shared-content marker pair"
}

@test "are_different: falls back to plain \$positive silently (no warning) when told not to warn" {
    # Actions that don't understand shared blocks at all (plain 'copy'/'merge'/'ignore') pass
    # warn_no_markers=false, since almost no file has markers and the warning would otherwise
    # fire on every such file. It still traces at the lower verbosity level, just doesn't warn.
    printf 'private A\n<<<===\nshared 1\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/a.txt"
    printf 'no markers at all here\n' > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false false
             echo \"RC=\$?\""
    assert_success
    assert_output --partial "RC=0"
    refute_output --partial "WARN"
}

# =====================================================================================
# __find_shared_markers() / get_shared_block()
# =====================================================================================

@test "get_shared_block: extracts the content strictly between the marker lines" {
    printf 'private A\n<<<===\nshared 1\nshared 2\n===>>>\nprivate B\n' > "$BATS_TEST_TMPDIR/f.txt"
    run _ds "declare content
             get_shared_block '$BATS_TEST_TMPDIR/f.txt' content
             echo \"RC=\$?\"
             printf '[%s]' \"\$content\""
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial "[shared 1
shared 2]"
}

@test "get_shared_block: ignores trailing descriptive text on the marker lines" {
    printf 'private A\n# <<<=== Beginning of shared content\nshared 1\n# ===>>> End of shared content\nprivate B\n' > "$BATS_TEST_TMPDIR/f.txt"
    run _ds "declare content
             get_shared_block '$BATS_TEST_TMPDIR/f.txt' content
             printf '[%s]' \"\$content\""
    assert_success
    assert_output "[shared 1]"
}

@test "get_shared_block: fails (not a bug) when a marker is missing" {
    printf 'no markers here\n' > "$BATS_TEST_TMPDIR/f.txt"
    run _ds "declare content
             get_shared_block '$BATS_TEST_TMPDIR/f.txt' content
             echo \"RC=\$?\""
    assert_success
    assert_output --partial "RC=1"
}

@test "get_shared_block: fails when there is more than one begin or end marker" {
    printf -- '<<<===\na\n===>>>\n<<<===\nb\n===>>>\n' > "$BATS_TEST_TMPDIR/f.txt"
    run _ds "declare content
             get_shared_block '$BATS_TEST_TMPDIR/f.txt' content
             echo \"RC=\$?\""
    assert_success
    assert_output --partial "RC=1"
}

@test "get_shared_block: bug-exits with the wrong argument count" {
    # arg1's own existence check also fires (the file exists here, so only the arity bug fires).
    touch "$BATS_TEST_TMPDIR/f.txt"
    run _ds "get_shared_block '$BATS_TEST_TMPDIR/f.txt'"
    assert_failure "$err_invalid_arguments"
}

# =====================================================================================
# merge()
# =====================================================================================

@test "merge: bug-exits with the wrong argument count" {
    # arg1 also fails its own existence check (the file doesn't exist), so err_not_file --
    # not the arity code -- is the "last" bug reported.
    run _ds "merge '$BATS_TEST_TMPDIR/a.txt'"
    assert_failure "$err_not_file"
}

@test "merge: returns success and counts 'merged' when the merge command changes the target file" {
    echo "sot content" > "$BATS_TEST_TMPDIR/sot.txt"
    echo "target content" > "$BATS_TEST_TMPDIR/target.txt"
    run _ds "declare -i summary_merged_count=0 summary_not_merged_count=0
             merge_command='cp \"\$REMOTE\" \"\$MERGED\"'
             merge '$BATS_TEST_TMPDIR/sot.txt' '$BATS_TEST_TMPDIR/target.txt'
             echo \"RC=\$?\"
             declare -p summary_merged_count summary_not_merged_count
             cat '$BATS_TEST_TMPDIR/target.txt'"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'summary_merged_count="1"'
    assert_output --partial "sot content"
}

@test "merge: returns failure and counts 'not merged' when the target file is unchanged" {
    echo "sot content" > "$BATS_TEST_TMPDIR/sot.txt"
    echo "target content" > "$BATS_TEST_TMPDIR/target.txt"
    run _ds "declare -i summary_merged_count=0 summary_not_merged_count=0
             merge_command='true'
             merge '$BATS_TEST_TMPDIR/sot.txt' '$BATS_TEST_TMPDIR/target.txt'
             echo \"RC=\$?\"
             declare -p summary_not_merged_count"
    assert_success
    assert_output --partial "RC=1"
    assert_output --partial 'summary_not_merged_count="1"'
}

# =====================================================================================
# copy_file()
# =====================================================================================

@test "copy_file: bug-exits with the wrong argument count" {
    touch "$BATS_TEST_TMPDIR/a.txt"
    run _ds "copy_file '$BATS_TEST_TMPDIR/a.txt'"
    assert_failure "$err_invalid_arguments"
}

@test "copy_file: bug-exits when the source file does not exist" {
    run _ds "copy_file '$BATS_TEST_TMPDIR/missing.txt' '$BATS_TEST_TMPDIR/dest.txt'"
    assert_failure "$err_not_file"
}

@test "copy_file: creates the destination directory and copies the file, counting the copy" {
    echo "content" > "$BATS_TEST_TMPDIR/src.txt"
    run _ds "declare -i summary_copied_count=0
             copy_file '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/newdir/dest.txt'
             declare -p summary_copied_count
             cat '$BATS_TEST_TMPDIR/newdir/dest.txt'"
    assert_success
    assert_output --partial 'summary_copied_count="1"'
    assert_output --partial "content"
}

@test "copy_file: in dry-run mode, prints what it would do and does not touch the filesystem" {
    echo "content" > "$BATS_TEST_TMPDIR/src.txt"
    run _ds "set_dry_run
             copy_file '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/dryrundir/dest.txt'
             [[ -e '$BATS_TEST_TMPDIR/dryrundir' ]] && echo EXISTS || echo NOT-CREATED"
    assert_success
    assert_output --partial "dry-run\$ mkdir -p"
    assert_output --partial "dry-run\$ cp"
    assert_output --partial "NOT-CREATED"
}

# =====================================================================================
# copy_shared_block()
# =====================================================================================

@test "copy_shared_block: bug-exits with the wrong argument count" {
    touch "$BATS_TEST_TMPDIR/a.txt"
    run _ds "copy_shared_block '$BATS_TEST_TMPDIR/a.txt'"
    assert_failure "$err_invalid_arguments"
}

@test "copy_shared_block: bug-exits when the source file does not exist" {
    touch "$BATS_TEST_TMPDIR/dest.txt"
    run _ds "copy_shared_block '$BATS_TEST_TMPDIR/missing.txt' '$BATS_TEST_TMPDIR/dest.txt'"
    assert_failure "$err_not_file"
}

@test "copy_shared_block: bug-exits (err_logic_error) when either file lacks well-formed markers" {
    printf -- '<<<===\nshared\n===>>>\n' > "$BATS_TEST_TMPDIR/src.txt"
    printf 'no markers here\n' > "$BATS_TEST_TMPDIR/dest.txt"
    run _ds "copy_shared_block '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/dest.txt'"
    assert_failure "$err_logic_error"
}

@test "copy_shared_block: splices the SoT's shared block into the target, leaving everything else untouched" {
    printf 'sot private A\n<<<===\nnew shared 1\nnew shared 2\n===>>>\nsot private B\n' > "$BATS_TEST_TMPDIR/src.txt"
    printf 'target private A\n# <<<=== begin\nold shared\n# ===>>> end\ntarget private B\n' > "$BATS_TEST_TMPDIR/dest.txt"
    run _ds "declare -i summary_copied_count=0 summary_shared_copied_count=0
             copy_shared_block '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/dest.txt'
             declare -p summary_copied_count summary_shared_copied_count
             cat '$BATS_TEST_TMPDIR/dest.txt'"
    assert_success
    assert_output --partial 'summary_copied_count="0"'
    assert_output --partial 'summary_shared_copied_count="1"'
    assert_output --partial "target private A"
    assert_output --partial "# <<<=== begin"
    assert_output --partial "new shared 1"
    assert_output --partial "new shared 2"
    assert_output --partial "# ===>>> end"
    assert_output --partial "target private B"
    refute_output --partial "old shared"
}

@test "copy_shared_block: works under 'set -u', as in the real script (regression: undeclared _rc on the success path)" {
    printf 'a\n<<<===\nnew shared\n===>>>\nb\n' > "$BATS_TEST_TMPDIR/src.txt"
    printf 'x\n<<<===\nold shared\n===>>>\ny\n' > "$BATS_TEST_TMPDIR/dest.txt"
    run _ds "declare -i summary_shared_copied_count=0
             declare vm2_repos=''
             set -u
             copy_shared_block '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/dest.txt'"
    assert_success
    refute_output --partial "unbound variable"
    run grep -c "new shared" "$BATS_TEST_TMPDIR/dest.txt"
    assert_output "1"
}

@test "copy_shared_block: in dry-run mode, prints what it would do and does not touch the target file" {
    printf -- '<<<===\nnew shared\n===>>>\n' > "$BATS_TEST_TMPDIR/src.txt"
    printf -- 'target A\n<<<===\nold shared\n===>>>\ntarget B\n' > "$BATS_TEST_TMPDIR/dest.txt"
    run _ds "set_dry_run
             copy_shared_block '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/dest.txt'
             cat '$BATS_TEST_TMPDIR/dest.txt'"
    assert_success
    assert_output --partial "dry-run\$ cp"
    assert_output --partial "old shared"
    refute_output --partial "new shared"
}

# =====================================================================================
# resolve_target()
# =====================================================================================

@test "resolve_target: bug-exits with the wrong argument count" {
    run _ds "declare root='' path=''; resolve_target '$BATS_TEST_TMPDIR' 'r' root"
    assert_failure "$err_invalid_arguments"
}

@test "resolve_target: bug-exits when the vm2-repos parent argument is not a directory" {
    run _ds "declare root='' path=''; resolve_target '/definitely/not/a/real/path' 'r' root path"
    assert_failure "$err_not_directory"
}

@test "resolve_target: bug-exits on undefined output nameref variables" {
    run _ds "resolve_target '$BATS_TEST_TMPDIR' 'r' not_a_var_1 not_a_var_2"
    assert_failure "$err_invalid_nameref"
}

@test "resolve_target: fails with err_not_found for a repo name that doesn't exist anywhere" {
    run _ds "declare root='' path=''; resolve_target '$BATS_TEST_TMPDIR' 'no-such-repo' root path"
    assert_failure "$err_not_found"
}

@test "resolve_target: resolves a well-formed local git repo with CI configured" {
    mkdir -p "$BATS_TEST_TMPDIR/parent"
    _make_ci_repo "$BATS_TEST_TMPDIR/parent/goodrepo"
    run _ds "declare root='' path=''
             resolve_target '$BATS_TEST_TMPDIR/parent' 'goodrepo' root path
             echo \"RC=\$?\"
             declare -p root path"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial "root=\"$BATS_TEST_TMPDIR/parent/goodrepo\""
}

@test "resolve_target: warns and succeeds for a directory with CI configured that isn't a git repo yet" {
    mkdir -p "$BATS_TEST_TMPDIR/parent/nocirepo/.github/workflows"
    echo "name: CI" > "$BATS_TEST_TMPDIR/parent/nocirepo/.github/workflows/ci.yaml"
    run _ds "declare root='' path=''
             resolve_target '$BATS_TEST_TMPDIR/parent' 'nocirepo' root path
             echo \"RC=\$?\""
    assert_success
    assert_output --partial "not a git repository yet"
    assert_output --partial "RC=0"
}

