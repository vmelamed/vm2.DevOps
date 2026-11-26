#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/add-spdx.args.sh (with add-spdx.usage.sh), following the seams of the get_arguments()
# pipeline (see test_diff_shared_args.bats, the reference implementation). Each test sources core.sh and the files under
# test in a fresh, ambient-environment-free ('env -i') bash subshell, started in $BATS_TEST_TMPDIR -- so the default
# directory ($initial_cwd) is that one.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx err_missing_argument
declare -gx err_too_many_arguments
declare -gx err_unknown_argument

declare BATS_TEST_TMPDIR

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# Runs the snippet $1 with the optional environment assignments $2 (e.g. "LICENSE=Apache-2.0").
_as() {
    (cd "$BATS_TEST_TMPDIR" && env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" ${2:+"$2"} bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/add-spdx.args.sh'
        source '$_src_dir/add-spdx.usage.sh'
        $1
    ")
}

setup() {
    _tmp=$(realpath "$BATS_TEST_TMPDIR")
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: defaults to the current directory and the MIT license" {
    run _as "parse_arguments
             declare -p dir license"
    assert_success
    assert_output --partial "dir=\"$_tmp\""
    assert_output --partial 'license="MIT"'
}

@test "parse_arguments: the default license comes from \$LICENSE when it is set" {
    run _as "parse_arguments
             declare -p license" "LICENSE=Apache-2.0"
    assert_success
    assert_output --partial 'license="Apache-2.0"'
}

@test "parse_arguments: the positional argument is the directory, --license and -l set the license" {
    local _option
    for _option in --license -l --LICENSE; do
        run _as "parse_arguments /some/dir $_option BSD-3-Clause
                 declare -p dir license"
        assert_success
        assert_output --partial 'dir="/some/dir"'
        assert_output --partial 'license="BSD-3-Clause"'
    done
}

@test "parse_arguments: --license without a value fails with usage" {
    run _as "parse_arguments --license"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing value for --license"
}

@test "parse_arguments: a second directory is rejected" {
    run _as "parse_arguments /one /two; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Multiple directories specified - /two"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the directory" {
    run _as "parse_arguments --bogus; declare -p dir"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "dir="
}

@test "parse_arguments: does not validate the directory (a non-existent one is taken as is)" {
    run _as "parse_arguments /definitely/not/there
             declare -p dir"
    assert_success
    assert_output --partial 'dir="/definitely/not/there"'
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _as "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _as "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when git is present" {
    run _as "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing git and returns instead of exiting" {
    run _as "is_tool_present() { [[ \$1 != git ]]; }
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

@test "resolve_arguments: accepts an existing directory and freezes the arguments" {
    mkdir -p "$_tmp/src"
    run _as "dir='$_tmp/src'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p dir license"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial "declare -rx dir=\"$_tmp/src\""
    assert_output --partial 'declare -rx license="MIT"'
}

@test "resolve_arguments: reports a missing directory and an empty license together, and returns" {
    run _as "dir='$_tmp/not-there'
             license=''
             resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "Invalid directory '$_tmp/not-there': it does not exist."
    assert_output --partial "The license (--license) must not be empty."
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

@test "resolve_arguments: reports a regular file given as the directory" {
    touch "$_tmp/file.txt"
    run _as "dir='$_tmp/file.txt'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "Invalid directory '$_tmp/file.txt': it does not exist."
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    mkdir -p "$_tmp/src"
    run _as "get_arguments '$_tmp/src' --license Apache-2.0
             declare -p dir license"
    assert_success
    assert_output --partial "declare -rx dir=\"$_tmp/src\""
    assert_output --partial 'declare -rx license="Apache-2.0"'
}

@test "get_arguments: -h prints the usage and exits 0, even for a directory that does not exist" {
    run _as "get_arguments -h /definitely/not/there; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: reports a missing directory, then exits with the usage" {
    run _as "get_arguments /definitely/not/there; echo AFTER"
    assert_failure
    assert_output --partial "Invalid directory '/definitely/not/there': it does not exist."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
