#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- escape_workflow_command_value ------------------------------------------------------------

@test "escape_workflow_command_value: leaves ordinary text unchanged" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; escape_workflow_command_value 'Pre-release: fixed a bug, added tests (see #42)'"
    assert_success
    assert_output "Pre-release: fixed a bug, added tests (see #42)"
}

@test "escape_workflow_command_value: escapes a literal percent sign to %25" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; escape_workflow_command_value '100% done'"
    assert_success
    assert_output "100%25 done"
}

@test "escape_workflow_command_value: escapes a carriage return to %0D" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; escape_workflow_command_value \$'before\rafter'"
    assert_success
    assert_output "before%0Dafter"
}

@test "escape_workflow_command_value: escapes a line feed to %0A" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; escape_workflow_command_value \$'before\nafter'"
    assert_success
    assert_output "before%0Aafter"
}

@test "escape_workflow_command_value: escapes % before CR/LF substitution, so the introduced % is not re-escaped" {
    # if '%' were escaped AFTER '\n' -> '%0A', the '%' from that substitution would itself become
    # '%25', corrupting the escape into '%250A'. The order in the implementation must avoid this.
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; escape_workflow_command_value \$'line1\nline2'"
    assert_success
    assert_output "line1%0Aline2"
    refute_output --partial "%250A"
}

@test "escape_workflow_command_value: neutralizes an embedded fake workflow command so it never reaches its own output line" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; escape_workflow_command_value \$'legit reason\n::error::fake injected error\r::add-mask::secret'"
    assert_success
    # exactly one line of output -- the injected '::error::'/'::add-mask::' text is now inert data
    # on that same line, not a separate line a workflow-command parser could act on
    [[ $(echo "$output" | wc -l) -eq 1 ]]
    assert_output "legit reason%0A::error::fake injected error%0D::add-mask::secret"
}

@test "escape_workflow_command_value: bug-exits with the wrong argument count" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; escape_workflow_command_value"
    assert_failure 254
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; escape_workflow_command_value 'a' 'b'"
    assert_failure 254
}
