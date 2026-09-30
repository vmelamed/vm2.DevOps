#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_diagnostics.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these (and every other core.sh
# constant) into this file's scope at load time -- see that file's own comment for why. A plain
# 'declare -x'/'declare -xi' re-declaration (no '-g') fails here: bats sources this file's
# top-level code from inside a function frame, so a scope-less 'declare' means "local", and bash
# refuses to shadow-declare a local with the same name as an existing readonly global (which is
# exactly what these are, post-transplant). '-g' avoids that: it re-declares the name in the
# global scope bash already put it in, which is always allowed regardless of readonly-ness.
declare -gx lib_dir

declare -gxi failure
declare -gxi err_has_bugs
declare -gxi err_has_errors
declare -gxi err_argument_type
declare -gxi err_invalid_arguments

# --- error counter --------------------------------------------------------------------------

@test "has_errors / get_errors: false and 0 by default" {
    run has_errors
    assert_failure "$failure"
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
    # NOTE: exit_if_has_bugs now reports the last bug's own specific code (here err_argument_type,
    # from set_errors()'s own 'bug -ec "$err_argument_type" ...' check) rather than always the
    # generic err_has_bugs -- see the summary note on this behavior fix.
    run set_errors -1
    assert_failure "$err_argument_type"
    run set_errors "abc"
    assert_failure "$err_argument_type"
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

@test "exit_if_has_bugs: exits with the last bug's own code (defaults to failure/1) and reports the count" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; bug 'oops' 2>/dev/null; exit_if_has_bugs"
    assert_failure "$failure"
}

# --- exit_if_has_errors ------------------------------------------------------------------------

@test "exit_if_has_errors: no-op when there are no errors" {
    run exit_if_has_errors
    assert_success
}

@test "exit_if_has_errors: exits 1 and shows usage text when errors are present (default)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; function usage_text() { echo MARKER_USAGE_TEXT; }; error 'boom' 2>/dev/null; exit_if_has_errors"
    assert_failure "$failure"
    assert_output --partial "MARKER_USAGE_TEXT"
}

@test "exit_if_has_errors: exits with the last error's own code and skips usage text when \$1 is false" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; function usage_text() { echo MARKER_USAGE_TEXT; }; error 'boom' 2>/dev/null; exit_if_has_errors false"
    assert_failure "$failure"
    assert_output --partial "$(error_message "$failure")"
    refute_output --partial "MARKER_USAGE_TEXT"
}

@test "exit_if_has_errors: translates the error code in its message instead of leaking a bare number" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; function usage_text() { :; }; error 'boom' 2>/dev/null; exit_if_has_errors"
    assert_failure "$failure"
    assert_output --partial "$(error_message "$failure")"
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
    assert_failure "$failure"
}

# --- exit_with_error -----------------------------------------------------------------------

@test "exit_with_error: exits with the code given via -ec, logging via error (not fatal_exit)" {
    run exit_with_error -ec 5 "some problem"
    assert_failure 5
    assert_output --partial "some problem"
    assert_output --partial "ERROR"
    refute_output --partial "FATAL"
}

@test "exit_with_error: defaults to failure/1 when no -ec is given" {
    run exit_with_error "problem, no code"
    assert_failure "$failure"
}

@test "exit_with_error: removes the ERR/EXIT traps first, so no ON ERROR post-mortem noise follows" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        exit_with_error -ec 5 'boom'
    "
    assert_failure 5
    assert_output --partial "boom"
    refute_output --partial "ON ERROR post-mortem"
    refute_output --partial "EXIT: the command"
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
    assert_failure "$err_invalid_arguments"
}

# --- show_stack --------------------------------------------------------------------------------

@test "show_stack: silent by default outside verbose mode" {
    run show_stack
    assert_success
    assert_output --partial "↑ run"
}

@test "show_stack: prints frames" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; function outer() { show_stack 0 5; }; outer"
    assert_success
    assert_output --partial "↑ outer"
}
