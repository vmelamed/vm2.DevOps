#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_error_codes.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- error code constants ----------------------------------------------------------------------

@test "error code constants: are set to their documented numeric values" {
    [[ $success == 0 ]]
    [[ $failure == 1 ]]
    [[ $positive == 0 ]]
    [[ $negative == 1 ]]
    [[ $err_invalid_arguments == 2 ]]
    [[ $err_has_errors == 253 ]]
    [[ $err_has_bugs == 254 ]]
    [[ $err_unknown == 255 ]]
}

@test "bug_prefix and friends: are set to their real (non-empty) values, not stuck on a forward-declare placeholder" {
    [[ -n $bug_prefix ]]
    [[ -n $error_prefix ]]
    [[ -n $warning_prefix ]]
    [[ -n $info_prefix ]]
    [[ -n $trace_prefix ]]
}

# --- error_message ----------------------------------------------------------------------------

@test "error_message: returns the code and message for a known error code" {
    run error_message "$err_not_found"
    assert_success
    assert_output "$err_not_found: Could not find an item matching the criteria."
}

@test "error_message: falls back to the 'unknown error' message for an unrecognized code" {
    run error_message 250
    assert_success
    assert_output "250: An unknown error occurred."
}

@test "error_message: exits (does not just print 'command not found') with no arguments" {
    run error_message
    assert_failure 2
    refute_output --partial "command not found"
}

@test "error_message: exits with a non-numeric argument, without falling through to print a bogus message" {
    run error_message "not-a-number"
    assert_failure 3
    refute_output --partial "command not found"
    refute_output --partial "An unknown error occurred"
}

# --- error_name -------------------------------------------------------------------------------

@test "error_name: returns the \$-prefixed name for a known error code" {
    run error_name "$err_not_found"
    assert_success
    assert_output '$err_not_found'
}

@test "error_name: falls back to 'err_unknown' for an unrecognized code" {
    run error_name 250
    assert_success
    assert_output "err_unknown"
}

@test "error_name: exits with no arguments" {
    run error_name
    assert_failure 2
}

@test "error_name: exits with a non-numeric argument" {
    run error_name "not-a-number"
    assert_failure 3
}
