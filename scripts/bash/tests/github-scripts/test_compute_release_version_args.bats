#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/compute-release-version.args.sh (with compute-release-version.usage.sh), following the seams
# of the get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation).
# Each test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_unknown_argument
declare -gx  default_minver_tag_prefix

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 with the optional environment assignments $2 (e.g. "REASON=hotfix").
_cr() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" ${2:+"$2"} bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/compute-release-version.usage.sh'
        source '$_gh_scripts_dir/compute-release-version.args.sh'
        $1
    "
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _cr "parse_arguments
             declare -p minver_tag_prefix reason"
    assert_success
    assert_output --partial "minver_tag_prefix=\"$default_minver_tag_prefix\""
    assert_output --partial 'reason="release build"'
}

@test "parse_arguments: the defaults come from \$MINVERTAGPREFIX and \$REASON when they are set" {
    run _cr "parse_arguments
             declare -p minver_tag_prefix" "MINVERTAGPREFIX=rel"
    assert_success
    assert_output --partial 'minver_tag_prefix="rel"'

    run _cr "parse_arguments
             declare -p reason" "REASON=hotfix"
    assert_success
    assert_output --partial 'reason="hotfix"'
}

@test "parse_arguments: --minver-tag-prefix/-mp and --reason/-r set the corresponding variables, case-insensitively" {
    run _cr "parse_arguments --minver-tag-prefix rel --reason 'a fix'
             declare -p minver_tag_prefix reason"
    assert_success
    assert_output --partial 'minver_tag_prefix="rel"'
    assert_output --partial 'reason="a fix"'

    run _cr "parse_arguments -MP ver -R 'another fix'
             declare -p minver_tag_prefix reason"
    assert_success
    assert_output --partial 'minver_tag_prefix="ver"'
    assert_output --partial 'reason="another fix"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --minver-tag-prefix --reason; do
        run _cr "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: rejects an unknown option and any positional argument" {
    run _cr "parse_arguments --bogus; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "AFTER"

    run _cr "parse_arguments v1.0.0; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: v1.0.0"
    refute_output --partial "AFTER"
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _cr "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _cr "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when git is present" {
    run _cr "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing git and returns instead of exiting" {
    run _cr "is_tool_present() { [[ \$1 != git ]]; }
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: accepts valid values and freezes them" {
    run _cr "resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p minver_tag_prefix reason"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial "declare -rx minver_tag_prefix=\"$default_minver_tag_prefix\""
    assert_output --partial 'declare -rx reason="release build"'
}

@test "resolve_arguments: reports an invalid tag prefix and an unsafe reason together, and returns" {
    run _cr "minver_tag_prefix='a b'
             reason='-rf /'
             resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "the MinVer tag prefix"
    assert_output --partial "(provided 'a b')"
    assert_output --partial "The reason '-rf /' appears to be a command or contains unsafe characters."
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _cr "get_arguments --minver-tag-prefix rel --reason 'a fix'
             declare -p minver_tag_prefix reason"
    assert_success
    assert_output --partial 'declare -rx minver_tag_prefix="rel"'
    assert_output --partial 'declare -rx reason="a fix"'
}

@test "get_arguments: -h prints the usage and exits 0, even with invalid values" {
    run _cr "get_arguments -h --minver-tag-prefix 'a b'; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: an invalid value ends the run with the error and the usage" {
    run _cr "get_arguments --minver-tag-prefix 'a b'; echo AFTER"
    assert_failure
    assert_output --partial "(provided 'a b')"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
