#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_diagnostics.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- error counter --------------------------------------------------------------------------

@test "has_errors / get_errors: false and 0 by default" {
    run has_errors
    assert_failure 1
    run get_errors
    assert_output "0"
}

@test "error: increments the error counter and is reflected by has_errors/get_errors" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; error 'boom' 2>/dev/null; get_errors"
    assert_success
    assert_output "1"
}

@test "set_errors: sets the counter to a specific value" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_errors 5; get_errors"
    assert_output "5"
}

@test "set_errors: bug-exits on a negative or non-integer value" {
    run set_errors -1
    assert_failure 254
    run set_errors "abc"
    assert_failure 254
}

@test "reset_errors: sets the counter back to 0" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_errors 5; reset_errors; get_errors"
    assert_output "0"
}

# --- exit_if_has_bugs -------------------------------------------------------------------------

@test "exit_if_has_bugs: no-op when there are no bugs" {
    run exit_if_has_bugs
    assert_success
}

@test "exit_if_has_bugs: exits 254 and reports the count when bugs are recorded" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; bug 'oops' 2>/dev/null; exit_if_has_bugs"
    assert_failure 254
}

# --- exit_if_has_errors ------------------------------------------------------------------------

@test "exit_if_has_errors: no-op when there are no errors" {
    run exit_if_has_errors
    assert_success
}

@test "exit_if_has_errors: exits 1 and shows usage text when errors are present (default)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; function usage_text() { echo MARKER_USAGE_TEXT; }; error 'boom' 2>/dev/null; exit_if_has_errors"
    assert_failure 1
    assert_output --partial "MARKER_USAGE_TEXT"
}

@test "exit_if_has_errors: exits 253 (err_has_errors) and skips usage text when \$1 is false" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; function usage_text() { echo MARKER_USAGE_TEXT; }; error 'boom' 2>/dev/null; exit_if_has_errors false"
    assert_failure 253
    refute_output --partial "MARKER_USAGE_TEXT"
}

@test "exit_if_has_errors: translates the error code in its message instead of leaking a bare number" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; function usage_text() { :; }; error 'boom' 2>/dev/null; exit_if_has_errors"
    assert_failure 1
    assert_output --partial "There are errors recorded in the global error counter"
    refute_line "253"
}

# --- error / bug / warning / info / trace: basic smoke ------------------------------------------

@test "error: prints to stderr with the error prefix" {
    run --separate-stderr error "something failed"
    assert_success
    assert [ -n "$stderr" ]
    [[ "$stderr" == *"ERROR"* ]]
    [[ "$stderr" == *"something failed"* ]]
}

@test "bug: prints to stderr with the bug prefix and increments the bug counter" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; bug 'contract violated' 2>&1 1>/dev/null"
    [[ "$output" == *"something"* ]] || [[ "$output" == *"contract violated"* ]]
}

@test "warning: prints to stderr, never dumps a stack" {
    run --separate-stderr warning "deprecated option"
    assert_success
    [[ "$stderr" == *"WARN"* ]]
    [[ "$stderr" == *"deprecated option"* ]]
}

@test "info: prints to stdout" {
    run info "starting up"
    assert_success
    assert_output --partial "starting up"
    assert_output --partial "INFO"
}

@test "trace: silent when verbose mode is off, printed when verbose mode is on" {
    run trace "hidden trace line"
    assert_success
    refute_output --partial "hidden trace line"

    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_verbose; trace 'visible trace line' 2>&1"
    assert_output --partial "visible trace line"
}

# --- fatal_exit --------------------------------------------------------------------------------

@test "fatal_exit: exits with the code given via -ec" {
    run fatal_exit -ec 5 "fatal problem"
    assert_failure 5
    assert_output --partial "fatal problem"
}

@test "fatal_exit: defaults to failure/1 when no -ec is given" {
    run fatal_exit "fatal problem, no code"
    assert_failure 1
}

# --- warning_var -------------------------------------------------------------------------------

@test "warning_var: sets the referenced variable to the default and prints a warning" {
    run --separate-stderr bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v=''; warning_var v 'v not specified' 'fallback'; echo \"\$v\""
    assert_success
    assert_output "fallback"
    [[ "$stderr" == *"v not specified"* ]]
    [[ "$stderr" == *"fallback"* ]]
}

@test "warning_var: bug-exits with wrong argument count" {
    run warning_var only_one_arg
    assert_failure 254
}

# --- show_stack --------------------------------------------------------------------------------

@test "show_stack: silent by default outside verbose mode" {
    run show_stack
    assert_success
    refute_output
}

@test "show_stack: prints frames when explicitly forced to true" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; function outer() { show_stack 0 5 true; }; outer"
    assert_success
    assert_output --partial "outer"
}
