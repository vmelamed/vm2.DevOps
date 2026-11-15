#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/re-tag.args.sh (with re-tag.usage.sh), following the seams of the get_arguments() pipeline
# (see test_diff_shared_args.bats, the reference implementation): parse_arguments(), verify_environment(),
# resolve_arguments(), and get_arguments() end to end. Each test sources core.sh and the files under test in a fresh,
# ambient-environment-free ('env -i') bash subshell.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx err_missing_argument
declare -gx err_unknown_argument
declare -gx err_too_many_arguments

declare -gx git_tags_ns

declare BATS_TEST_TMPDIR

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# An empty git repository, the default directory of _rt. A sandbox rather than the directory bats was started from: that
# one is not necessarily inside a git working tree (e.g. bats run from /tmp, or from an IDE). The user's hooks are
# disabled ('git init' already runs the reference-transaction hook).
_repo_dir() {
    local _dir="$BATS_TEST_TMPDIR/repo"
    [[ -d $_dir/.git ]] || git -c core.hooksPath=/dev/null init --quiet "$_dir"
    echo "$_dir"
}

# Runs the snippet $1 in the directory $2 (default: an empty git repository, see _repo_dir).
_rt() {
    local _dir=${2:-$(_repo_dir)}
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        cd '$_dir' || exit 99
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/re-tag.args.sh'
        source '$_src_dir/re-tag.usage.sh'
        $1
    "
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _rt "parse_arguments
             declare -p delete_mode del_tag old_tag new_tag"
    assert_success
    assert_output --partial 'delete_mode="false"'
    assert_output --partial 'del_tag=""'
    assert_output --partial 'old_tag=""'
    assert_output --partial 'new_tag=""'
}

@test "parse_arguments: two positional arguments are the old and the new tag (rename mode)" {
    run _rt "parse_arguments v1.0.0-preview.1 v1.0.1-preview.1
             declare -p delete_mode old_tag new_tag"
    assert_success
    assert_output --partial 'delete_mode="false"'
    assert_output --partial 'old_tag="v1.0.0-preview.1"'
    assert_output --partial 'new_tag="v1.0.1-preview.1"'
}

@test "parse_arguments: keeps the tags as given; canonicalizing them is resolve_arguments' job" {
    run _rt "parse_arguments ${git_tags_ns}v1.0.0 ${git_tags_ns}v2.0.0
             declare -p old_tag new_tag"
    assert_success
    assert_output --partial "old_tag=\"${git_tags_ns}v1.0.0\""
    assert_output --partial "new_tag=\"${git_tags_ns}v2.0.0\""

    run _rt "parse_arguments --delete ${git_tags_ns}v1.0.0
             declare -p del_tag"
    assert_success
    assert_output --partial "del_tag=\"${git_tags_ns}v1.0.0\""
}

@test "parse_arguments: --delete and -d select delete mode and take the tag" {
    local _option
    for _option in --delete -d --DELETE; do
        run _rt "parse_arguments $_option v1.0.0
                 declare -p delete_mode del_tag old_tag"
        assert_success
        assert_output --partial 'delete_mode="true"'
        assert_output --partial 'del_tag="v1.0.0"'
        assert_output --partial 'old_tag=""'
    done
}

@test "parse_arguments: --delete without a tag fails with usage" {
    run _rt "parse_arguments --delete"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing value for --delete"
}

@test "parse_arguments: --delete after an old tag is rejected" {
    run _rt "parse_arguments v1.0.0 --delete v2.0.0; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "'--delete' takes exactly one tag and cannot be combined with other tags or another '--delete'."
    refute_output --partial "AFTER"
}

@test "parse_arguments: a positional tag after --delete is rejected" {
    run _rt "parse_arguments --delete v1.0.0 v2.0.0; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "'v2.0.0'"
    refute_output --partial "AFTER"
}

@test "parse_arguments: a second --delete is rejected" {
    run _rt "parse_arguments --delete v1.0.0 --delete v2.0.0; echo AFTER"
    assert_failure "$err_too_many_arguments"
    refute_output --partial "AFTER"
}

@test "parse_arguments: a third positional argument is rejected" {
    run _rt "parse_arguments a b c; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Too many arguments: 'c'."
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as a tag" {
    run _rt "parse_arguments --bogus; declare -p old_tag"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "old_tag="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _rt "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _rt "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when git is present" {
    run _rt "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing git and returns instead of exiting" {
    run _rt "is_tool_present() { [[ \$1 != git ]]; }
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports a directory that is not a git repository, and returns instead of exiting" {
    run _rt "verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output --partial "The current directory is not a git repository."
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: freezes the mode and the tags" {
    run _rt "parse_arguments v1 v2
             resolve_arguments
             declare -p delete_mode old_tag new_tag"
    assert_success
    assert_output --partial 'declare -rx delete_mode="false"'
    assert_output --partial 'declare -rx old_tag="v1"'
    assert_output --partial 'declare -rx new_tag="v2"'
}

@test "resolve_arguments: accepts a valid tag in delete mode, and freezes the arguments" {
    run _rt "parse_arguments --delete v1.0.0-preview.1
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p delete_mode del_tag"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx delete_mode="true"'
    assert_output --partial 'declare -rx del_tag="v1.0.0-preview.1"'
}

@test "resolve_arguments: strips a leading 'refs/tags/' from every tag" {
    run _rt "parse_arguments ${git_tags_ns}v1.0.0 ${git_tags_ns}v2.0.0
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p old_tag new_tag"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx old_tag="v1.0.0"'
    assert_output --partial 'declare -rx new_tag="v2.0.0"'

    run _rt "parse_arguments --delete ${git_tags_ns}v1.0.0
             resolve_arguments
             declare -p del_tag"
    assert_success
    assert_output --partial 'declare -rx del_tag="v1.0.0"'
}

@test "resolve_arguments: validates the tag without its 'refs/tags/' prefix (refs/tags/-v1 is -v1), and reports it as given" {
    run _rt "parse_arguments --delete ${git_tags_ns}-v1
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "Invalid tag to delete argument: '${git_tags_ns}-v1'."
    assert_output --partial "errors=1"
}

@test "resolve_arguments: strips 'refs/tags/' exactly once (regression: the parser and the validator both stripped it)" {
    run _rt "parse_arguments --delete ${git_tags_ns}${git_tags_ns}-v1
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p del_tag"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial "declare -rx del_tag=\"${git_tags_ns}-v1\""
}

@test "resolve_arguments: reports an empty tag to delete, and returns instead of exiting" {
    run _rt "parse_arguments --delete ''
             resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "Missing required tag to delete argument."
    refute_output --partial "Invalid tag to delete argument: "
    assert_output --partial "REACHED"
    assert_output --partial "errors=1"
}

@test "resolve_arguments: reports an invalid tag to delete" {
    run _rt "parse_arguments --delete 'bad..tag'
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "Invalid tag to delete argument: 'bad..tag'."
    assert_output --partial "errors=1"
}

@test "resolve_arguments: reports a missing old tag and a missing new tag together" {
    run _rt "resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "Missing required old tag argument."
    assert_output --partial "Missing required new tag argument."
    refute_output --partial "Invalid"
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

@test "resolve_arguments: reports a missing new tag after a valid old tag" {
    run _rt "parse_arguments v1.0.0
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    refute_output --partial "old tag"
    assert_output --partial "Missing required new tag argument."
    assert_output --partial "errors=1"
}

@test "resolve_arguments: reports an invalid old tag and an invalid new tag together" {
    run _rt "parse_arguments 'bad..old' 'bad new'
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "Invalid old tag argument: "
    assert_output --partial "Invalid new tag argument: "
    assert_output --partial "errors=2"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses and freezes the arguments in one call" {
    run _rt "get_arguments --delete v1.0.0
             declare -p delete_mode"
    assert_success
    assert_output --partial 'declare -rx delete_mode="true"'
}

@test "get_arguments: -h prints the usage and exits 0 without running anything after it" {
    run _rt "get_arguments -h v1 v2; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: a missing git ends the run with the error and the usage" {
    run _rt "is_tool_present() { [[ \$1 != git ]]; }
             get_arguments v1 v2; echo AFTER"
    assert_failure
    assert_output --partial "'git' is not installed"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: a non-repository directory ends the run before the tags are checked (circuit breaker)" {
    run _rt "get_arguments --delete 'bad..tag'; echo AFTER" "$BATS_TEST_TMPDIR"
    assert_failure
    assert_output --partial "The current directory is not a git repository."
    refute_output --partial "Invalid tag to delete argument"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
