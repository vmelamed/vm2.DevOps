#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_sanitize.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir

declare -gx success
declare -gx failure
declare -gx positive
declare -gx negative
declare -gx err_invalid_arguments
declare -gx err_invalid_nameref
declare -gx err_non_existent_path
declare -gx err_argument_type
declare -gx err_not_file
declare -gx err_invalid_json
declare -gx err_unsafe_argument
declare -gx err_argument_value
declare -gx err_logic_error

declare BATS_TEST_TMPDIR

# --- ltrim / rtrim / trim ------------------------------------------------------------------

@test "ltrim: removes only leading whitespace" {
    run ltrim "  hi  "
    assert_success
    assert_output "hi  "
}

@test "rtrim: removes only trailing whitespace" {
    run rtrim "  hi  "
    assert_success
    assert_output "  hi"
}

@test "trim: removes leading and trailing whitespace" {
    run trim "  hi  "
    assert_success
    assert_output "hi"
}

@test "ltrim/rtrim/trim: bug-exit with wrong argument count" {
    run ltrim
    assert_failure "$err_invalid_arguments"
    run rtrim
    assert_failure "$err_invalid_arguments"
    run trim
    assert_failure "$err_invalid_arguments"
}

@test "ltrim_var/rtrim_var/trim_var: trim the referenced variable in place" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='  hi  '; ltrim_var v; echo \"[\$v]\""
    assert_output "[hi  ]"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='  hi  '; rtrim_var v; echo \"[\$v]\""
    assert_output "[  hi]"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='  hi  '; trim_var v; echo \"[\$v]\""
    assert_output "[hi]"
}

@test "trim_var: bug-exits on an undefined variable name" {
    run trim_var definitely_not_defined_xyz
    assert_failure "$err_invalid_nameref"
}

# --- is_safe_input -----------------------------------------------------------------------------

@test "is_safe_input: accepts empty and plain alphanumeric input" {
    run is_safe_input ""
    assert_success
    run is_safe_input "hello123"
    assert_success
}

@test "is_safe_input: rejects dangerous shell metacharacters" {
    run is_safe_input 'hi; rm -rf /'
    assert_failure "$err_unsafe_argument"
    run is_safe_input 'hi$(whoami)'
    assert_failure "$err_unsafe_argument"
}

@test "is_safe_input: rejects spaces by default but allows them when arg 2 is true" {
    run is_safe_input "hello world"
    assert_failure "$err_unsafe_argument"
    run is_safe_input "hello world" true
    assert_success
}

@test "is_safe_input: bug-exits with more than two arguments" {
    # NOTE: is_safe_input() accumulates two bugs here (arity, then argument 2 not a valid
    # boolean since "b" is passed positionally as if it were the allow-spaces flag) --
    # exit_if_has_bugs now reports the LAST one recorded (err_argument_type), not the generic
    # err_has_bugs.
    run is_safe_input a b c
    assert_failure "$err_argument_type"
}

# --- is_valid_boolean / is_valid_integer -----------------------------------------------------

@test "is_valid_boolean: accepts true/false, rejects anything else" {
    run is_valid_boolean true
    assert_success
    run is_valid_boolean false
    assert_success
    run is_valid_boolean maybe
    assert_failure 11
}

@test "is_valid_integer: accepts integers, rejects non-integers" {
    run is_valid_integer 42
    assert_success
    run is_valid_integer -7
    assert_success
    run is_valid_integer "abc"
    assert_failure 11
}

# --- is_valid_path / is_safe_path / is_safe_existing_* -----------------------------------------

@test "is_valid_path: accepts a syntactically valid path, even an unsafe one" {
    run is_valid_path "some/relative/path.txt"
    assert_success
    run is_valid_path "../outside/the/tree"
    assert_success
}

@test "is_valid_path: rejects an empty string with err_argument_value and an 'Invalid path' error" {
    run is_valid_path ""
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid path ''"
}

@test "is_valid_path: called directly under 'set -u', reports instead of dying on an unbound variable" {
    # regression: it once read its caller's local \$_path, which exists only when is_safe_path calls it
    run bash -c "set -u; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; is_valid_path ''"
    assert_failure "$err_argument_value"
    refute_output --partial "unbound variable"
    assert_output --partial "Invalid path ''"
}

@test "is_safe_path: accepts a plain relative path" {
    run is_safe_path "some/relative/path.txt"
    assert_success
}

@test "is_safe_path: rejects an empty string as an invalid path (err_argument_value), not as an unsafe one" {
    run is_safe_path ""
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid path ''"
}

@test "is_safe_path: rejects traversal, absolute paths, and dangerous characters" {
    run is_safe_path "../etc/passwd"
    assert_failure "$err_unsafe_argument"
    run is_safe_path "/etc/passwd"
    assert_failure "$err_unsafe_argument"
    run is_safe_path 'foo;rm -rf /'
    assert_failure "$err_unsafe_argument"
}

@test "is_safe_existing_path: succeeds for an existing path, fails for a non-existent one" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir' && is_safe_existing_path core.sh"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir' && is_safe_existing_path definitely/does/not/exist.txt"
    assert_failure "$err_non_existent_path"
}

@test "is_safe_existing_directory: succeeds for a directory, fails for a file" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir/..' && is_safe_existing_directory lib"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir' && is_safe_existing_directory core.sh"
    assert_failure 17
}

@test "is_safe_existing_file: succeeds for a non-empty file, fails for a directory" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir' && is_safe_existing_file core.sh"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir/..' && is_safe_existing_file lib"
    assert_failure "$err_not_file"
}

# --- escape_ere ----------------------------------------------------------------------------------

@test "escape_ere: escapes ERE special characters" {
    run escape_ere 'a.b*c[d]'
    assert_success
    assert_output 'a\.b\*c\[d\]'
}

@test "escape_ere: bug-exits with wrong argument count" {
    run escape_ere
    assert_failure "$err_invalid_arguments"
}
