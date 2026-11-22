#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_error_codes.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

declare -gx success
declare -gx failure
declare -gx positive
declare -gx negative
declare -gx err_invalid_arguments
declare -gx err_has_errors
declare -gx err_has_bugs
declare -gx err_unknown
declare -gx err_io_failure
declare -gx err_not_found
declare -gx err_tool_error
declare -gx err_tool_unauthenticated
declare -gx err_access_denied
declare -gx err_argument_value
declare -gx err_invalid_nameref

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
    [[ $err_unknown == 250 ]]
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
    assert_output "vm2 \$err_not_found ($err_not_found): No item matches the criteria."
}

@test "error_message/error_name: know \$err_io_failure (21)" {
    [[ $err_io_failure == 21 ]]
    run error_message "$err_io_failure"
    assert_success
    assert_output "vm2 \$err_io_failure ($err_io_failure): An I/O operation failed."
    run error_name "$err_io_failure"
    assert_success
    assert_output "\$err_io_failure"
}

@test "error_message: falls back to the 'unknown error' message for an unrecognized code" {
    run error_message 250
    assert_success
    assert_output "vm2 \$err_unknown (250): An unknown error occurred."
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
    assert_output "\$err_not_found"
}

@test "error_name: falls back to '\$err_unknown' for an unrecognized code" {
    run error_name 250
    assert_success
    assert_output "\$err_unknown"
}

@test "error_name: exits with no arguments" {
    run error_name
    assert_failure 2
}

@test "error_name: exits with a non-numeric argument" {
    run error_name "not-a-number"
    assert_failure 3
}

# --- http_status_to_error_code -------------------------------------------------------------------

@test "http_status_to_error_code: 425, 429, 500, and 502-504 are transient (0)" {
    local _status _code
    for _status in 425 429 500 502 503 504; do
        _code=x
        http_status_to_error_code "$_status" _code
        [[ $_code == 0 ]] || fail "HTTP $_status -> '$_code', expected 0"
    done
}

@test "http_status_to_error_code: 401, 403, and 404 map to the codes a caller can branch on" {
    local _code
    http_status_to_error_code 401 _code; [[ $_code == "$err_tool_unauthenticated" ]]
    http_status_to_error_code 403 _code; [[ $_code == "$err_access_denied" ]]
    http_status_to_error_code 404 _code; [[ $_code == "$err_not_found" ]]
}

@test "http_status_to_error_code: any other status, 501 and 505 included, is err_tool_error" {
    local _status _code
    for _status in 400 409 422 501 505 302; do
        http_status_to_error_code "$_status" _code
        [[ $_code == "$err_tool_error" ]] || fail "HTTP $_status -> '$_code', expected $err_tool_error"
    done
}

@test "http_status_to_error_code: bug-exits with the wrong argument count, a status that is not one, or a bad nameref" {
    local code
    run http_status_to_error_code 404
    assert_failure "$err_invalid_arguments"
    run http_status_to_error_code 4040 code
    assert_failure "$err_argument_value"
    run http_status_to_error_code 404 'not a name'
    assert_failure "$err_invalid_nameref"
}

@test "err_access_denied: has a message and a name" {
    run error_name "$err_access_denied"
    assert_output "\$err_access_denied"
    run error_message "$err_access_denied"
    assert_output --partial "Access to a resource was denied"
}
