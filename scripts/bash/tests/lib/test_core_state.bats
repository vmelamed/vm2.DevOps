#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_core_state.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- verbose mode ---------------------------------------------------------------------------

@test "is_verbose: false by default" {
    run is_verbose
    assert_failure 1
}

@test "set_verbose / unset_verbose: toggle is_verbose" {
    # shellcheck disable=SC2154
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_verbose; is_verbose"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_verbose; unset_verbose; is_verbose"
    assert_failure 1
}

# --- quiet mode -------------------------------------------------------------------------------

@test "is_quiet: false by default outside CI" {
    run is_quiet
    assert_failure 1
}

@test "set_quiet / unset_quiet: toggle is_quiet" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_quiet; is_quiet"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_quiet; unset_quiet; is_quiet"
    assert_failure 1
}

# --- dry-run mode -----------------------------------------------------------------------------

@test "is_dry_run: false by default" {
    run is_dry_run
    assert_failure 1
}

@test "set_dry_run / unset_dry_run: toggle is_dry_run" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_dry_run; is_dry_run"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_dry_run; unset_dry_run; is_dry_run"
    assert_failure 1
}

# --- ignored output ---------------------------------------------------------------------------

@test "show_ignored_output: no argument redirects to /dev/stderr" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; show_ignored_output; echo \"\$_ignore\""
    assert_success
    assert_output "/dev/stderr"
}

@test "show_ignored_output: explicit argument redirects there" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; show_ignored_output /tmp/foo; echo \"\$_ignore\""
    assert_success
    assert_output "/tmp/foo"
}

@test "show_ignored_output: warns (but still redirects) when targeting /dev/stdout" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; show_ignored_output /dev/stdout; echo \"\$_ignore\""
    assert_success
    assert_output --partial "/dev/stdout"
}

@test "show_ignored_output: bug-exits with more than one argument" {
    run show_ignored_output a b
    assert_failure 254
}

@test "hide_ignored_output: restores /dev/null" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; show_ignored_output; hide_ignored_output; echo \"\$_ignore\""
    assert_success
    assert_output "/dev/null"
}

# --- trace mode -------------------------------------------------------------------------------

@test "set_trace_enabled / unset_trace_enabled: toggle is_trace_enabled" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_trace_enabled 2> /dev/null; is_trace_enabled"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_trace_enabled 2> /dev/null; unset_trace_enabled; is_trace_enabled"
    assert_failure 1
}

@test "is_trace_enabled: false by default" {
    run is_trace_enabled
    assert_failure 1
}

# --- table format -----------------------------------------------------------------------------

@test "get_table_format: 'graphical' by default outside CI" {
    run get_table_format
    assert_success
    assert_output "graphical"
}

@test "set_table_format: accepts 'markdown' and 'graphical', case-insensitively" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_table_format MarkDown; get_table_format"
    assert_success
    assert_output "markdown"
}

@test "set_table_format: bug-exits on an invalid format" {
    run set_table_format "csv"
    assert_failure 254
}

@test "set_table_format: bug-exits with no arguments" {
    run set_table_format
    assert_failure 254
}

# --- save_state / restore_state -----------------------------------------------------------------

@test "save_state / restore_state: round-trips verbose, quiet, dry-run, and table format" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        declare -A state=()
        set_verbose; set_quiet; set_dry_run; set_table_format markdown
        save_state state
        unset_verbose; unset_quiet; unset_dry_run; set_table_format graphical
        restore_state state
        is_verbose && echo verbose=true || echo verbose=false
        is_quiet && echo quiet=true || echo quiet=false
        is_dry_run && echo dry_run=true || echo dry_run=false
        get_table_format
    "
    assert_success
    assert_line --index 0 "verbose=true"
    assert_line --index 1 "quiet=true"
    assert_line --index 2 "dry_run=true"
    assert_line --index 3 "markdown"
}

@test "save_state: bug-exits when given a non-associative-array name" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare -a arr=(); save_state arr"
    assert_failure 254
}

@test "save_state: bug-exits when called twice on the same unrestored state" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        declare -A state=()
        save_state state
        save_state state
    "
    assert_failure 254
}

@test "restore_state: bug-exits on a state array that was never saved" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare -A state=(); restore_state state"
    assert_failure 254
}

@test "restore_state: does not recurse/hang (regression for the save_state cycle)" {
    run --separate-stderr timeout 5 bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        declare -A state=()
        save_state state
        restore_state state
    "
    assert_success
}

# --- case sensitivity / globstar / nullglob shopt toggles ---------------------------------------

@test "set_case_sensitive: toggles the nocasematch shopt" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_case_sensitive false; shopt -q nocasematch"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_case_sensitive true; shopt -q nocasematch"
    assert_failure
}

@test "set_case_sensitive: bug-exits on a non-boolean argument" {
    run set_case_sensitive "maybe"
    assert_failure 254
}

@test "set_glob_star: toggles the globstar shopt" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_glob_star true; shopt -q globstar"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_glob_star false; shopt -q globstar"
    assert_failure
}

@test "set_null_glob: toggles the nullglob shopt" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_null_glob true; shopt -q nullglob"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_null_glob false; shopt -q nullglob"
    assert_failure
}
