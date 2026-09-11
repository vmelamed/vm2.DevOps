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

# --- is_variable_name ---------------------------------------------------------------------------

@test "is_variable_name: accepts a valid identifier" {
    run is_variable_name "my_var1"
    assert_success
}

@test "is_variable_name: rejects a string starting with a digit" {
    run is_variable_name "1abc"
    assert_failure 1
}

@test "is_variable_name: rejects a string with a dash" {
    run is_variable_name "my-var"
    assert_failure 1
}

@test "is_variable_name: bug-exits with no arguments" {
    run is_variable_name
    assert_failure 254
}

# --- is_defined_variable -------------------------------------------------------------------------

@test "is_defined_variable: true for a declared variable" {
    declare foo=bar
    run is_defined_variable foo
    assert_success
}

@test "is_defined_variable: false for an undeclared name" {
    run is_defined_variable definitely_not_declared_xyz
    assert_failure 1
}

# --- is_defined_indexed_array / is_defined_associative_array / is_defined_array ------------------

@test "is_defined_indexed_array: true for an indexed array" {
    # shellcheck disable=SC2190 # Elements in associative arrays need index, e.g. array=( [index]=value ) .
    declare -a arr=(a b c)
    run is_defined_indexed_array arr
    assert_success
}

@test "is_defined_indexed_array: false for an associative array" {
    declare -A arr=([a]=1)
    run is_defined_indexed_array arr
    assert_failure 1
}

@test "is_defined_associative_array: true for an associative array" {
    declare -A arr=([a]=1)
    run is_defined_associative_array arr
    assert_success
}

@test "is_defined_associative_array: false for an indexed array" {
    # shellcheck disable=SC2190 # Elements in associative arrays need index, e.g. array=( [index]=value ) .
    declare -a arr=(a b c)
    run is_defined_associative_array arr
    assert_failure 1
}

@test "is_defined_associative_array: does not recurse/hang (regression for the save_state cycle)" {
    declare -A arr=([a]=1)
    run --separate-stderr timeout 5 bash -c '
        # shellcheck disable=SC2154 # lib_dir is referenced but not assigned.
        source "'"$lib_dir"'/core.sh" --no-trap > /dev/null
        declare -A arr=([a]=1)
        is_defined_associative_array arr
    '
    assert_success
}

# shellcheck disable=SC2034 # idx appears unused. Verify use (or export if used externally).
@test "is_defined_array: true for either an indexed or an associative array" {
    declare -a idx=(a b c)
    declare -A assoc=([a]=1)
    run is_defined_array idx
    assert_success
    run is_defined_array assoc
    assert_success
}

@test "is_defined_array: false for a plain scalar" {
    declare foo=bar
    run is_defined_array foo
    assert_failure 1
}

# --- is_array_empty -------------------------------------------------------------------------------

@test "is_array_empty: true for an empty indexed array" {
    declare -a arr=()
    run is_array_empty arr
    assert_success
}

@test "is_array_empty: false for a non-empty array" {
    # shellcheck disable=SC2034
    # shellcheck disable=SC2190
    declare -a arr=(a)
    run is_array_empty arr
    assert_failure 1
}

@test "is_array_empty: bug-exits when the name is not an array" {
    # shellcheck disable=SC2034
    declare foo=bar
    run is_array_empty foo
    assert_failure 254
}

# --- is_defined_function -------------------------------------------------------------------------

@test "is_defined_function: true for a defined function" {
    run is_defined_function is_boolean
    assert_success
}

@test "is_defined_function: false for a name that is not a function" {
    run is_defined_function definitely_not_a_function_xyz
    assert_failure 1
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
    assert_failure 1
    run is_boolean "True"
    assert_failure 1
}

@test "is_boolean: bug-exits with no arguments" {
    run is_boolean
    assert_failure 254
}

# --- is_natural / is_non_negative / is_positive / is_non_positive / is_negative / is_integer -----

@test "is_natural: accepts positive integers, rejects zero and negatives" {
    run is_natural 5
    assert_success
    run is_natural 0
    assert_failure 1
    run is_natural -5
    assert_failure 1
}

@test "is_non_negative: accepts zero and positive integers, rejects negatives" {
    run is_non_negative 0
    assert_success
    run is_non_negative 5
    assert_success
    run is_non_negative -1
    assert_failure 1
}

@test "is_positive: accepts a leading plus, rejects zero" {
    run is_positive "+5"
    assert_success
    run is_positive 0
    assert_failure 1
}

@test "is_non_positive: accepts zero and negatives, rejects positives" {
    run is_non_positive 0
    assert_success
    run is_non_positive -5
    assert_success
    run is_non_positive 5
    assert_failure 1
}

@test "is_negative: accepts negative integers only" {
    run is_negative -5
    assert_success
    run is_negative 5
    assert_failure 1
    run is_negative 0
    assert_failure 1
}

@test "is_integer: accepts signed and unsigned whole numbers, rejects decimals" {
    run is_integer 5
    assert_success
    run is_integer -5
    assert_success
    run is_integer "+5"
    assert_success
    run is_integer 5.5
    assert_failure 1
}

@test "is_exit_code: accepts 0-255, rejects out of range" {
    run is_exit_code 0
    assert_success
    run is_exit_code 255
    assert_success
    run is_exit_code 256
    assert_failure 1
    run is_exit_code -1
    assert_failure 1
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
    assert_failure 1
}

# --- is_base64 -------------------------------------------------------------------------------

@test "is_base64: accepts valid base64" {
    run is_base64 "aGVsbG8="
    assert_success
}

@test "is_base64: rejects invalid base64" {
    run is_base64 "not base64!!"
    assert_failure 1
}

# --- is_in -------------------------------------------------------------------------------

@test "is_in: true when the value is among the options" {
    run is_in "green" "red" "green" "blue"
    assert_success
}

@test "is_in: false when the value is not among the options" {
    run is_in "yellow" "red" "green" "blue"
    assert_failure 1
}

@test "is_in: bug-exits with fewer than 2 arguments" {
    run is_in "only-one"
    assert_failure 254
}

# --- is_windows -------------------------------------------------------------------------------

@test "is_windows: false on this Linux test runner" {
    run is_windows
    assert_failure 1
}

# --- is_valid_filename / is_valid_path ---------------------------------------------------------

@test "is_valid_filename: accepts a plain filename, rejects path separators and . / .." {
    run is_valid_filename "file.txt"
    assert_success
    run is_valid_filename "dir/file.txt"
    assert_failure 1
    run is_valid_filename "."
    assert_failure 1
    run is_valid_filename ".."
    assert_failure 1
    run is_valid_filename ""
    assert_failure 1
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
    assert_failure 1
    run is_valid_secret "$(printf 'bad\x01value')"
    assert_failure 1
}
