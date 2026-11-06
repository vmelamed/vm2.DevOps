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
declare -gxi err_argument_value
declare -gxi err_logic_error
declare -gxi err_tool_error

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
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_core_args.sh'; function usage_text() { echo MARKER_USAGE_TEXT; }; error 'boom' 2>/dev/null; exit_if_has_errors"
    assert_failure "$failure"
    assert_output --partial "MARKER_USAGE_TEXT"
}

@test "exit_if_has_errors: exits with the last error's own code and skips usage text when \$1 is false" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_core_args.sh'; function usage_text() { echo MARKER_USAGE_TEXT; }; error 'boom' 2>/dev/null; exit_if_has_errors false"
    assert_failure "$failure"
    assert_output --partial "$(error_message "$failure")"
    refute_output --partial "MARKER_USAGE_TEXT"
}

@test "exit_if_has_errors: translates the error code in its message instead of leaking a bare number" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_core_args.sh'; function usage_text() { :; }; error 'boom' 2>/dev/null; exit_if_has_errors"
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

# The message functions scan ALL of their arguments for options (an off-by-one once missed the last position), so an
# option is honored wherever it appears -- also after the message, and also with no message at all.
@test "error: a trailing -ec after the message sets the last error code, and is not printed as text" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; error 'boom' -ec 7 2>&1; echo \"last=\$__last_error\""
    assert_success
    assert_line "last=7"
    assert_output --partial "boom"
    refute_output --partial "-ec 7"
}

@test "error: a trailing --error-code after the message sets the last error code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; error 'boom' --error-code 9 2>/dev/null; echo \"last=\$__last_error\""
    assert_success
    assert_output "last=9"
}

@test "error: a code-only -ec (no message) still sets the last error code and counts the error" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; error -ec 5 2>/dev/null; echo \"last=\$__last_error errors=\$(get_errors)\""
    assert_success
    assert_output "last=5 errors=1"
}

@test "bug: a trailing --error-code after the message sets the last bug code, and is not printed as text" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; bug 'broken' --error-code 11 2>&1; echo \"last=\$__last_bug\""
    assert_success
    assert_line "last=11"
    assert_output --partial "broken"
    refute_output --partial "--error-code"
}

@test "bug: a code-only -ec (no message) still sets the last bug code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; bug -ec 12 2>/dev/null; echo \"last=\$__last_bug\""
    assert_success
    assert_output "last=12"
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

# --- exit_with_bug -----------------------------------------------------------------------

@test "exit_with_bug: exits with the code given via -ec, logging via bug (not fatal_exit)" {
    run exit_with_bug -ec 5 "some problem"
    assert_failure 5
    assert_output --partial "some problem"
    assert_output --partial "BUG"
    refute_output --partial "FATAL"
}

@test "exit_with_bug: defaults to failure/1 when no -ec is given" {
    run exit_with_bug "problem, no code"
    assert_failure "$failure"
}

@test "exit_with_bug: removes the ERR/EXIT traps first, so no ON ERROR post-mortem noise follows" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        exit_with_bug -ec 5 'boom'
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

# --- with_error -----------------------------------------------------------------------------

# Writes the test's script body (stdin) after a 3-line prologue that sources core.sh, and runs it
# in a clean environment. A real file (not 'bash -c') is needed: several tests assert the source
# file and line number that with_error reports, so the user's first body line is always line 4.
_run_with_error_script()
{
    local _script="$BATS_TEST_TMPDIR/with_error.sh"
    {
        printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1"
        cat
    } > "$_script"
    run env -i HOME="$HOME" PATH="$PATH" bash "$_script"
}

@test "with_error: sets the variable to the given code and returns success, so the chain continues" {
    _run_with_error_script <<'EOF'
declare -i rc=0
false || with_error "$err_tool_error" rc "the tool failed"
echo "status=$? rc=$rc"
EOF
    assert_success
    assert_output --partial "status=0 rc=$err_tool_error"
}

@test "with_error: prints the message, then the failed command's exit code, then the code's message" {
    _run_with_error_script <<'EOF'
declare -i rc=0
(exit 4) || with_error "$err_tool_error" rc "the tool failed"
EOF
    assert_success
    assert_line --index 0 --partial "the tool failed @ "
    assert_line --index 1 --partial "Exit code: 4"
    assert_line --index 2 --partial "($err_tool_error)"
}

@test "with_error: omits the 'Exit code' line when the previous command succeeded" {
    _run_with_error_script <<'EOF'
declare -i rc=0
with_error "$err_tool_error" rc "reported without a failed command"
EOF
    assert_success
    assert_output --partial "reported without a failed command"
    refute_output --partial "Exit code:"
}

@test "with_error: the guarded steps after a failure are skipped, and exit_if_has_errors exits with the code" {
    _run_with_error_script <<'EOF'
declare -i rc=0
false                     || with_error "$err_tool_error" rc "step 1 failed"
(( rc != success )) || echo "step 2 ran"
(( rc != success )) || echo "step 3 ran"
exit_if_has_errors false
EOF
    assert_failure "$err_tool_error"
    assert_output --partial "step 1 failed"
    refute_output --partial "step 2 ran"
    refute_output --partial "step 3 ran"
}

@test "with_error: the stack dump starts at the caller, not at with_error itself" {
    _run_with_error_script <<'EOF'
declare -i rc=0
f() { false || with_error "$err_tool_error" rc "boom"; }
f
EOF
    assert_success
    assert_output --partial "↑ f "
    refute_output --partial "↑ with_error"
}

@test "with_error: '@ file (line)' points at the caller's line, not at with_error itself" {
    _run_with_error_script <<'EOF'
declare -i rc=0
f() { false || with_error "$err_tool_error" rc "boom"; }
f
EOF
    assert_success
    assert_line --index 0 --partial "boom @ $BATS_TEST_TMPDIR/with_error.sh (5):"
}

@test "with_error: an error it records belongs to its caller -- a callee's exit_if_has_errors defers it" {
    # Same contract as calling 'error' directly: the error is the caller's to report, so a gate in
    # a function the caller calls next must not claim it (and exit).
    _run_with_error_script <<'EOF'
declare -i rc=0
child() { exit_if_has_errors false; echo "child deferred"; }
parent() { false || with_error "$err_tool_error" rc "parent's error"; child; }
parent
echo "parent returned"
EOF
    assert_success
    assert_output --partial "child deferred"
    assert_output --partial "parent returned"
}

@test "with_error: bug-exits with fewer than two arguments" {
    _run_with_error_script <<'EOF'
false || with_error "$err_tool_error"
EOF
    assert_failure "$err_invalid_arguments"
    assert_output --partial "with_error() requires at least two arguments"
}

@test "with_error: bug-exits when argument 1 is not an exit code" {
    _run_with_error_script <<'EOF'
declare -i rc=0
false || with_error "not-a-code" rc "boom"
EOF
    assert_failure "$err_argument_value"
    assert_output --partial "requires argument 1"
}

@test "with_error: bug-exits when argument 1 is 0 -- the chain would continue as if nothing failed" {
    _run_with_error_script <<'EOF'
declare -i rc=0
false || with_error 0 rc "boom"
echo "continued with rc=$rc"
EOF
    assert_failure "$err_argument_value"
    assert_output --partial "requires argument 1"
    refute_output --partial "continued with"
}

@test "with_error: accepts the smallest error code, \$failure (1)" {
    _run_with_error_script <<'EOF'
declare -i rc=0
false || with_error "$failure" rc "generic failure"
echo "rc=$rc"
EOF
    assert_success
    assert_output --partial "rc=1"
}

@test "with_error: bug-exits when argument 2 is not the name of a declared variable" {
    _run_with_error_script <<'EOF'
false || with_error "$err_tool_error" undeclared_rc "boom"
EOF
    assert_failure "$err_argument_value"
    assert_output --partial "requires argument 2"
}

@test "with_error: reports a dotnet exit code passed with -dec, and still records the vm2 code" {
    _run_with_error_script <<'EOF'
declare -i rc=0
(exit 2) || with_error "$err_tool_error" rc "msbuild failed" -dec "$?"
EOF
    assert_success
    assert_line --index 0 --partial "msbuild failed @ "
    assert_line --index 1 --partial 'Dotnet $dotnet_err_test_failure (2): '
    assert_line --index 2 --partial "Exit code: 2"
    assert_line --index 3 --partial 'vm2 $err_tool_error ('
}

# --- error: --dotnet-error-code ---------------------------------------------------------------

@test "error: -dec and --dotnet-error-code print the dotnet code's message where the flag appears" {
    _run_with_error_script <<'EOF'
error "first" -dec 2 "last"
EOF
    assert_success
    assert_line --index 0 --partial "first @ "
    assert_line --index 1 --partial 'Dotnet $dotnet_err_test_failure (2): At least one test failure occurred'
    assert_line --index 2 --partial "last"

    _run_with_error_script <<'EOF'
error "long form" --dotnet-error-code 8
EOF
    assert_success
    assert_output --partial 'Dotnet $dotnet_err_no_test_ran (8): '
}

@test "error: -dec falls back to the unknown-code message for an unrecognized dotnet code" {
    _run_with_error_script <<'EOF'
error "boom" -dec 99
EOF
    assert_success
    assert_output --partial 'Dotnet $dotnet_err_unknown (99): Unknown dotnet error code'
}

@test "error: -dec does not become the script's exit code -- only -ec does" {
    # a dotnet code and a vm2 code with the same number mean different things
    _run_with_error_script <<'EOF'
error "only dotnet" -dec 8
echo "last_error=$__last_error"
error "both" -dec 8 -ec "$err_tool_error"
exit_if_has_errors false
EOF
    assert_failure "$err_tool_error"
    assert_output --partial "last_error=$failure"
}

@test "error: -dec with an invalid code says so instead of failing" {
    _run_with_error_script <<'EOF'
error "boom" -dec not-a-code
echo "continued"
EOF
    assert_success
    assert_output --partial "Expected an error code (0..255) after the '--dotnet-error-code' flag, provided: 'not-a-code'"
    assert_output --partial "continued"
}
