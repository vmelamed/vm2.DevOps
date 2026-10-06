#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for the tier-A (is_*/has_*) predicates in scripts/bash/lib/_predicates.sh,
# as they behave TODAY -- written before the tier-4 predicate/validator convention refactor so the
# refactor has a safety net. Every predicate here must: validate its own formal argument count via
# `bug`/`exit_if_has_bugs` (never `error()`), and always return 0/1 -- never anything else.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required, not just '-x'/'-xi': bats sources this file's top-level code from
# inside a function frame, so a scope-less 'declare' means "local", and bash refuses to
# shadow-declare a local with the same name as an existing readonly global (which is exactly
# what these are, post-transplant). See feedback_bats_declare_g_readonly memory for the full
# root-cause writeup.
declare -gx lib_dir

declare -gxi failure
declare -gxi err_invalid_arguments
declare -gxi err_invalid_nameref
declare -gxi err_invalid_path

# --- is_variable_name ---------------------------------------------------------------------------

@test "is_variable_name: accepts a valid identifier" {
    run is_variable_name "my_var1"
    assert_success
}

@test "is_variable_name: rejects a string starting with a digit" {
    run is_variable_name "1abc"
    assert_failure "$failure"
}

@test "is_variable_name: rejects a string with a dash" {
    run is_variable_name "my-var"
    assert_failure "$failure"
}

@test "is_variable_name: bug-exits with no arguments" {
    run is_variable_name
    assert_failure "$err_invalid_arguments"
}

# --- is_variable -------------------------------------------------------------------------

@test "is_variable: true for a declared variable" {
    declare foo=bar
    run is_variable foo
    assert_success
}

@test "is_variable: false for an undeclared name" {
    run is_variable definitely_not_declared_xyz
    assert_failure "$failure"
}

# --- is_indexed_array / is_associative_array / is_array ------------------

@test "is_indexed_array: true for an indexed array" {
    # shellcheck disable=SC2190 # Elements in associative arrays need index, e.g. array=( [index]=value ) .
    declare -a arr=(a b c)
    run is_indexed_array arr
    assert_success
}

@test "is_indexed_array: false for an associative array" {
    declare -A arr=([a]=1)
    run is_indexed_array arr
    assert_failure "$failure"
}

@test "is_associative_array: true for an associative array" {
    declare -A arr=([a]=1)
    run is_associative_array arr
    assert_success
}

@test "is_associative_array: false for an indexed array" {
    # shellcheck disable=SC2190 # Elements in associative arrays need index, e.g. array=( [index]=value ) .
    declare -a arr=(a b c)
    run is_associative_array arr
    assert_failure "$failure"
}

@test "is_associative_array: does not recurse/hang (regression for the save_state cycle)" {
    declare -A arr=([a]=1)
    run --separate-stderr timeout 5 bash -c '
        # shellcheck disable=SC2154 # lib_dir is referenced but not assigned.
        source "'"$lib_dir"'/core.sh" --no-trap > /dev/null 2>&1
        declare -A arr=([a]=1)
        is_associative_array arr
    '
    assert_success
}

# shellcheck disable=SC2034 # idx appears unused. Verify use (or export if used externally).
@test "is_array: true for either an indexed or an associative array" {
    declare -a idx=(a b c)
    declare -A assoc=([a]=1)
    run is_array idx
    assert_success
    run is_array assoc
    assert_success
}

@test "is_array: false for a plain scalar" {
    declare foo=bar
    run is_array foo
    assert_failure "$failure"
}

# --- is_empty_array -------------------------------------------------------------------------------

@test "is_empty_array: true for an empty indexed array" {
    declare -a arr=()
    run is_empty_array arr
    assert_success
}

@test "is_empty_array: false for a non-empty array" {
    # shellcheck disable=SC2034
    # shellcheck disable=SC2190
    declare -a arr=(a)
    run is_empty_array arr
    assert_failure "$failure"
}

@test "is_empty_array: bug-exits when the name is not an array" {
    # shellcheck disable=SC2034
    declare foo=bar
    run is_empty_array foo
    assert_failure "$err_invalid_nameref"
}

# --- is_function -------------------------------------------------------------------------

@test "is_function: true for a defined function" {
    run is_function is_boolean
    assert_success
}

@test "is_function: false for a name that is not a function" {
    run is_function definitely_not_a_function_xyz
    assert_failure "$failure"
}

# --- is_boolean -------------------------------------------------------------------------------

@test "is_boolean: accepts true and false" {
    run is_boolean true
    assert_success
    run is_boolean false
    assert_success
}

@test "is_boolean: rejects anything else" {
    run is_boolean maybe
    assert_failure "$failure"
    run is_boolean "True"
    assert_failure "$failure"
}

@test "is_boolean: bug-exits with no arguments" {
    run is_boolean
    assert_failure "$err_invalid_arguments"
}

# --- is_natural / is_non_negative / is_positive / is_non_positive / is_negative / is_integer -----

@test "is_natural: accepts positive integers, rejects zero and negatives" {
    run is_natural 5
    assert_success
    run is_natural 0
    assert_failure "$failure"
    run is_natural -5
    assert_failure "$failure"
}

@test "is_non_negative: accepts zero and positive integers, rejects negatives" {
    run is_non_negative 0
    assert_success
    run is_non_negative 5
    assert_success
    run is_non_negative -1
    assert_failure "$failure"
}

@test "is_positive: accepts a leading plus, rejects zero" {
    run is_positive "+5"
    assert_success
    run is_positive 0
    assert_failure "$failure"
}

@test "is_non_positive: accepts zero and negatives, rejects positives" {
    run is_non_positive 0
    assert_success
    run is_non_positive -5
    assert_success
    run is_non_positive 5
    assert_failure "$failure"
}

@test "is_negative: accepts negative integers only" {
    run is_negative -5
    assert_success
    run is_negative 5
    assert_failure "$failure"
    run is_negative 0
    assert_failure "$failure"
}

@test "is_integer: accepts signed and unsigned whole numbers, rejects decimals" {
    run is_integer 5
    assert_success
    run is_integer -5
    assert_success
    run is_integer "+5"
    assert_success
    run is_integer 5.5
    assert_failure "$failure"
}

@test "is_exit_code: accepts 0-255, rejects out of range" {
    run is_exit_code 0
    assert_success
    run is_exit_code 255
    assert_success
    run is_exit_code 256
    assert_failure "$failure"
    run is_exit_code -1
    assert_failure "$failure"
}

# --- is_decimal -------------------------------------------------------------------------------

@test "is_decimal: accepts integers and decimals" {
    run is_decimal 5
    assert_success
    run is_decimal 5.5
    assert_success
    run is_decimal -5.5
    assert_success
}

@test "is_decimal: rejects non-numeric input" {
    run is_decimal "abc"
    assert_failure "$failure"
}

# --- is_base64 -------------------------------------------------------------------------------

@test "is_base64: accepts valid base64" {
    run is_base64 "aGVsbG8="
    assert_success
}

@test "is_base64: rejects invalid base64" {
    run is_base64 "not base64!!"
    assert_failure "$failure"
}

# --- is_in -------------------------------------------------------------------------------

@test "is_in: true when the value is among the options" {
    run is_in "green" "red" "green" "blue"
    assert_success
}

@test "is_in: false when the value is not among the options" {
    run is_in "yellow" "red" "green" "blue"
    assert_failure "$failure"
}

@test "is_in: false for an empty option list (no options is a valid, empty set)" {
    run is_in "anything"
    assert_failure "$failure"
}

@test "is_in: bug-exits with no arguments" {
    run is_in
    assert_failure "$err_invalid_arguments"
}

# --- is_windows -------------------------------------------------------------------------------

@test "is_windows: false on this Linux test runner" {
    run is_windows
    assert_failure "$failure"
}

# --- is_valid_filename / is_valid_path ---------------------------------------------------------

@test "is_valid_filename: accepts a plain filename, rejects path separators and . / .." {
    run is_valid_filename "file.txt"
    assert_success
    run is_valid_filename "dir/file.txt"
    assert_failure "$failure"
    run is_valid_filename "."
    assert_failure "$failure"
    run is_valid_filename ".."
    assert_failure "$failure"
    run is_valid_filename ""
    assert_failure "$failure"
}

@test "is_valid_path: accepts a syntactically valid path" {
    run is_valid_path "some/relative/path.txt"
    assert_success
}

# --- is_valid_secret -------------------------------------------------------------------------------

@test "is_valid_secret: accepts a non-empty value with no control characters" {
    run is_valid_secret "s3cr3t-Value123"
    assert_success
}

@test "is_valid_secret: rejects empty values and control characters" {
    run is_valid_secret ""
    assert_failure "$failure"
    run is_valid_secret "$(printf 'bad\x01value')"
    assert_failure "$failure"
}

# --- is_valid_dotnet_version -------------------------------------------------------------------

@test "is_valid_dotnet_version: accepts a well-formed SDK version, rejects garbage" {
    run is_valid_dotnet_version "10.0.100"
    assert_success
    run is_valid_dotnet_version "garbage"
    assert_failure "$failure"
}

@test "is_valid_dotnet_version: bug-exits with the wrong argument count" {
    run is_valid_dotnet_version
    assert_failure "$err_invalid_arguments"
}

# --- is_tool_present -----------------------------------------------------------------------------

@test "is_tool_present: true for a tool on PATH, false for one that isn't" {
    run is_tool_present bash
    assert_success
    run is_tool_present definitely-not-a-real-tool-xyz
    assert_failure "$failure"
}

@test "is_tool_present: bug-exits with the wrong argument count" {
    run is_tool_present
    assert_failure "$err_invalid_arguments"
}

# --- is_valid_json / is_valid_json_file -----------------------------------------------------------

@test "is_valid_json: accepts a well-formed JSON string, rejects garbage" {
    run is_valid_json '{"a":1}'
    assert_success
    run is_valid_json 'not json'
    assert_failure "$failure"
}

@test "is_valid_json: bug-exits with the wrong argument count" {
    run is_valid_json
    assert_failure "$err_invalid_arguments"
}

@test "is_valid_json_file: accepts a file with well-formed JSON, rejects one with malformed JSON" {
    echo '{"a":1}' > "$BATS_TEST_TMPDIR/valid.json"
    echo 'not json' > "$BATS_TEST_TMPDIR/invalid.json"
    run is_valid_json_file "$BATS_TEST_TMPDIR/valid.json"
    assert_success
    run is_valid_json_file "$BATS_TEST_TMPDIR/invalid.json"
    assert_failure "$failure"
}

@test "is_valid_json_file: fails for a non-existent file" {
    run is_valid_json_file "$BATS_TEST_TMPDIR/does-not-exist.json"
    assert_failure "$failure"
}

@test "is_valid_json_file: bug-exits on the wrong argument count or an invalid path" {
    run is_valid_json_file
    assert_failure "$err_invalid_arguments"
    run is_valid_json_file ""
    assert_failure "$err_invalid_path"
}
