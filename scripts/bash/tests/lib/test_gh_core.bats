#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_invalid_arguments
declare -gxi err_invalid_nameref

# --- gh_escape ------------------------------------------------------------

@test "gh_escape: leaves ordinary text unchanged" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; gh_escape 'Pre-release: fixed a bug, added tests (see #42)'"
    assert_success
    assert_output "Pre-release: fixed a bug, added tests (see #42)"
}

@test "gh_escape: escapes a literal percent sign to %25" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; gh_escape '100% done'"
    assert_success
    assert_output "100%25 done"
}

@test "gh_escape: escapes a carriage return to %0D" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; gh_escape \$'before\rafter'"
    assert_success
    assert_output "before%0Dafter"
}

@test "gh_escape: escapes a line feed to %0A" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; gh_escape \$'before\nafter'"
    assert_success
    assert_output "before%0Aafter"
}

@test "gh_escape: escapes % before CR/LF substitution, so the introduced % is not re-escaped" {
    # if '%' were escaped AFTER '\n' -> '%0A', the '%' from that substitution would itself become
    # '%25', corrupting the escape into '%250A'. The order in the implementation must avoid this.
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; gh_escape \$'line1\nline2'"
    assert_success
    assert_output "line1%0Aline2"
    refute_output --partial "%250A"
}

@test "gh_escape: neutralizes an embedded fake workflow command so it never reaches its own output line" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; gh_escape \$'legit reason\n::error::fake injected error\r::add-mask::secret'"
    assert_success
    # exactly one line of output -- the injected '::error::'/'::add-mask::' text is now inert data
    # on that same line, not a separate line a workflow-command parser could act on
    [[ $(echo "$output" | wc -l) -eq 1 ]]
    assert_output "legit reason%0A::error::fake injected error%0D::add-mask::secret"
}

@test "gh_escape: bug-exits with the wrong argument count" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; gh_escape"
    assert_failure "$err_invalid_arguments"
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; gh_escape 'a' 'b'"
    assert_failure "$err_invalid_arguments"
}

# --- to_summary (gh_core.sh's GitHub-Actions-aware override) ---------------------------------

@test "to_summary: writes '## Summary' plus each line to stdout, and tees to \$GITHUB_STEP_SUMMARY under GITHUB_ACTIONS" {
    local _summary="$BATS_TEST_TMPDIR/summary.md"
    run bash -c "CI=true GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY='$_summary' source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; printf 'hello\n' | to_summary"
    assert_success
    assert_line --index 0 "## Summary"
    assert_line --index 1 "hello"
    [[ "$(cat "$_summary")" == "$(printf '## Summary\nhello')" ]]
}

@test "to_summary: does not write to \$GITHUB_STEP_SUMMARY outside GITHUB_ACTIONS (local run)" {
    local _summary="$BATS_TEST_TMPDIR/summary.md"
    run bash -c "CI=true GITHUB_ACTIONS=false GITHUB_STEP_SUMMARY='$_summary' source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; printf 'hello\n' | to_summary"
    assert_success
    [[ ! -e "$_summary" ]]
}

# --- args_to_github_output -------------------------------------------------------------------

@test "args_to_github_output: writes kebab-case key=value pairs to stdout for each variable" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; build_version=1.2.3; package_count=5; args_to_github_output build_version package_count"
    assert_success
    assert_line --index 0 "build-version=1.2.3"
    assert_line --index 1 "package-count=5"
}

@test "args_to_github_output: also writes the same key=value pairs to \$GITHUB_OUTPUT under GITHUB_ACTIONS" {
    local _out="$BATS_TEST_TMPDIR/gh_output"
    run bash -c "GITHUB_ACTIONS=true GITHUB_OUTPUT='$_out' source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; build_version=1.2.3; args_to_github_output build_version"
    assert_success
    [[ "$(cat "$_out")" == "build-version=1.2.3" ]]
}

@test "args_to_github_output: strips a leading underscore and lower-cases the transformed key" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; _MyVar=x; args_to_github_output _MyVar"
    assert_success
    assert_output --partial "myvar=x"
}

@test "args_to_github_output: bug-exits with no arguments" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; args_to_github_output"
    assert_failure "$err_invalid_arguments"
}

@test "args_to_github_output: bug-exits when an argument is not a valid variable name" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; args_to_github_output 'not a var'"
    assert_failure "$err_invalid_nameref"
}
