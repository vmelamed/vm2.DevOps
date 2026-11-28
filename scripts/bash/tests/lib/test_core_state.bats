#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/core.state.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir

declare -gx failure
declare -gx err_invalid_arguments
declare -gx err_invalid_nameref
declare -gx err_argument_value
declare -gx err_argument_type
declare -gx err_logic_error
declare -gx BATS_TEST_TMPDIR

# --- ci_system / ci -------------------------------------------------------------------------

# Runs a clean bash (no inherited CI variables) with the given environment assignments, sources core.sh, and prints
# "$ci_system $ci".
function _ci_probe()
{
    env -u CI -u GITHUB_ACTIONS -u TF_BUILD "$@" \
        bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; echo \"\$ci_system \$ci\""
}

@test "ci_system: 'none' and ci false when no CI variable is set" {
    run _ci_probe
    assert_success
    assert_output "none false"
}

@test "ci_system: 'github' only when GITHUB_ACTIONS is exactly 'true'" {
    run _ci_probe GITHUB_ACTIONS=true
    assert_output "github true"
    run _ci_probe GITHUB_ACTIONS=false
    assert_output "none false"
    run _ci_probe GITHUB_ACTIONS=True
    assert_output "none false"
}

@test "ci_system: 'azure' for TF_BUILD 'True' (Azure DevOps capitalizes it) or 'true'" {
    run _ci_probe TF_BUILD=True
    assert_output "azure true"
    run _ci_probe TF_BUILD=true
    assert_output "azure true"
    run _ci_probe TF_BUILD=False
    assert_output "none false"
}

@test "ci_system: 'other' for CI 'true', 'True', or '1'; not for 'false' or '0'" {
    local value
    for value in true True 1; do
        run _ci_probe CI="$value"
        assert_output "other true"
    done
    for value in false 0; do
        run _ci_probe CI="$value"
        assert_output "none false"
    done
}

@test "ci_system: GitHub wins over the generic CI variable (GitHub Actions sets both)" {
    run _ci_probe GITHUB_ACTIONS=true CI=true
    assert_output "github true"
}

@test "ci_system, ci: readonly" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; ci_system=github 2>&1; ci=true 2>&1"
    assert_output --partial "ci_system: readonly variable"
}

@test "ci_system: does not run the value of CI as a command" {
    # regression: the old 'ci=\${CI:-…}' followed by 'if \$ci' executed whatever CI contained
    run _ci_probe CI='touch '"$BATS_TEST_TMPDIR"'/pwned'
    assert_output "none false"
    [[ ! -e $BATS_TEST_TMPDIR/pwned ]]
}

# --- verbose mode ---------------------------------------------------------------------------

@test "is_verbose: false by default" {
    run is_verbose
    assert_failure "$failure"
}

@test "set_verbose / unset_verbose: toggle is_verbose" {
    # shellcheck disable=SC2154
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_verbose; is_verbose"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_verbose; unset_verbose; is_verbose"
    assert_failure "$failure"
}

# --- quiet mode -------------------------------------------------------------------------------

@test "is_quiet: false by default outside CI" {
    run is_quiet
    assert_failure "$failure"
}

@test "set_quiet / unset_quiet: toggle is_quiet" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_quiet; is_quiet"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_quiet; unset_quiet; is_quiet"
    assert_failure "$failure"
}

# --- dry-run mode -----------------------------------------------------------------------------

@test "is_dry_run: false by default" {
    run is_dry_run
    assert_failure "$failure"
}

@test "set_dry_run / unset_dry_run: toggle is_dry_run" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; is_dry_run"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; unset_dry_run; is_dry_run"
    assert_failure "$failure"
}

# --- ignored output ---------------------------------------------------------------------------

@test "show_noise_sink: no argument redirects to /dev/stderr" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; show_noise_sink; echo \"\$noise_sink\""
    assert_success
    assert_output "/dev/stderr"
}

@test "show_noise_sink: explicit argument redirects there" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; show_noise_sink /tmp/foo; echo \"\$noise_sink\""
    assert_success
    assert_output "/tmp/foo"
}

@test "show_noise_sink: warns (but still redirects) when targeting /dev/stdout" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; show_noise_sink /dev/stdout; echo \"\$noise_sink\""
    assert_success
    assert_output --partial "/dev/stdout"
}

@test "show_noise_sink: bug-exits with more than one argument" {
    run show_noise_sink a b
    assert_failure "$err_invalid_arguments"
}

@test "hide_noise_sink: restores /dev/null" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; show_noise_sink; hide_noise_sink; echo \"\$noise_sink\""
    assert_success
    assert_output "/dev/null"
}

# --- trace mode -------------------------------------------------------------------------------

@test "set_trace_enabled / unset_trace_enabled: toggle is_trace_enabled" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_trace_enabled 2> /dev/null; is_trace_enabled"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_trace_enabled 2> /dev/null; unset_trace_enabled; is_trace_enabled"
    assert_failure "$failure"
}

@test "is_trace_enabled: false by default" {
    run is_trace_enabled
    assert_failure "$failure"
}

# --- table format -----------------------------------------------------------------------------

@test "get_table_format: exits with failure when no arguments are provided" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_table_format"
    assert_failure "$err_invalid_arguments"
}

@test "get_table_format: exits with failure when given an invalid argument" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_table_format 123"
    assert_failure "$err_invalid_nameref"
}

@test "get_table_format: 'graphical' by default outside CI" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare format=''; get_table_format format; echo \"\$format\""
    assert_success
    assert_output "graphical"
}

@test "set_table_format: accepts 'markdown' and 'graphical', case-insensitively" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_table_format MarkDown; declare format=''; get_table_format format; echo \"\$format\""
    assert_success
    assert_output "markdown"
}

@test "set_table_format: bug-exits on an invalid format" {
    run set_table_format "csv"
    assert_failure "$err_argument_value"
}

@test "set_table_format: bug-exits with no arguments" {
    run set_table_format
    assert_failure "$err_invalid_arguments"
}

# --- save_state / restore_state -----------------------------------------------------------------

@test "save_state / restore_state: round-trips verbose, quiet, dry-run, and table format" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        declare -A state=()
        set_verbose; set_quiet; set_dry_run; set_table_format markdown
        save_state state
        unset_verbose; unset_quiet; unset_dry_run; set_table_format graphical
        restore_state state
        is_verbose && echo verbose=true || echo verbose=false
        is_quiet && echo quiet=true || echo quiet=false
        is_dry_run && echo dry_run=true || echo dry_run=false
        declare format=''
        get_table_format format
        echo \"\$format\"
    "
    assert_success
    assert_line --index 0 "verbose=true"
    assert_line --index 1 "quiet=true"
    assert_line --index 2 "dry_run=true"
    assert_line --index 3 "markdown"
}

@test "save_state: bug-exits when given a non-associative-array name" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a arr=(); save_state arr"
    assert_failure "$err_invalid_nameref"
}

@test "save_state: bug-exits when called twice on the same unrestored state" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        declare -A state=()
        save_state state
        save_state state
    "
    assert_failure "$err_logic_error"
}

@test "restore_state: bug-exits on a state array that was never saved" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); restore_state state"
    assert_failure "$err_logic_error"
}

@test "save_state, restore_state: bug-exit on a readonly state array" {
    # restore_state writes the array too: it marks the state as restored
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -rA state=(); save_state state"
    assert_failure "$err_invalid_nameref"
    assert_output --partial "requires argument 1 to name a writable associative array"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); save_state state; readonly state; restore_state state"
    assert_failure "$err_invalid_nameref"
    assert_output --partial "requires argument 1 to name a writable associative array"
}

@test "restore_state: does not recurse/hang (regression for the save_state cycle)" {
    run --separate-stderr timeout 5 bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        declare -A state=()
        save_state state
        restore_state state
    "
    assert_success
}

# --- case sensitivity / globstar / nullglob shopt toggles ---------------------------------------
#
# NOTE: set_case_sensitive()/set_case_insensitive() (in _predicates.sh) are simple, no-argument
# setters -- siblings of set_verbose/set_quiet/set_dry_run above. To change an option temporarily,
# wrap the change in begin_scope/end_scope (tested below).

@test "set_case_sensitive / set_case_insensitive: toggle the nocasematch shopt" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_case_sensitive; shopt -q nocasematch"
    assert_failure
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_case_insensitive; shopt -q nocasematch"
    assert_success
}

@test "is_case_sensitive: reflects the current nocasematch shopt state" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_case_sensitive; is_case_sensitive"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_case_insensitive; is_case_sensitive"
    assert_failure
}

@test "set_glob_star: toggles the globstar shopt" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_glob_star true; shopt -q globstar"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_glob_star false; shopt -q globstar"
    assert_failure
}

@test "set_null_glob: toggles the nullglob shopt" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_null_glob true; shopt -q nullglob"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_null_glob false; shopt -q nullglob"
    assert_failure
}

# --- begin_scope / end_scope / report_open_scopes --------------------------------------------------

@test "begin_scope / end_scope: restore the shell options changed inside the scope, in both directions" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        shopt -u nocasematch nullglob
        shopt -s globstar extglob
        begin_scope
        shopt -s nocasematch nullglob
        shopt -u globstar extglob
        end_scope
        shopt -p nocasematch nullglob globstar extglob || true    # returns 1 when any of them is off
    "
    assert_success
    assert_line "shopt -u nocasematch"
    assert_line "shopt -u nullglob"
    assert_line "shopt -s globstar"
    assert_line "shopt -s extglob"
}

@test "begin_scope / end_scope: nested scopes restore in reverse order" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        set_case_sensitive
        begin_scope
        set_case_insensitive
        begin_scope
        set_case_sensitive
        end_scope
        is_case_sensitive || echo 'INNER=restored'
        end_scope
        is_case_sensitive && echo 'OUTER=restored'
    "
    assert_success
    assert_line "INNER=restored"
    assert_line "OUTER=restored"
}

@test "begin_scope / end_scope: work at the top level of a script, outside any function" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        begin_scope
        set_null_glob true
        end_scope
        shopt -q nullglob || echo 'RESTORED'
    "
    assert_success
    assert_output "RESTORED"
}

@test "begin_scope / end_scope: a subshell's own scope does not touch the parent's scope stack" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        begin_scope
        set_case_insensitive
        ( begin_scope; set_case_sensitive; end_scope )
        end_scope
        is_case_sensitive && echo 'RESTORED'
    "
    assert_success
    assert_output "RESTORED"
}

@test "end_scope: bug-exits in the caller when a function returned without closing its scope" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        function leaky()  { begin_scope; set_case_insensitive; return 0; }
        function caller() { begin_scope; leaky; end_scope; }
        caller
        echo 'NOT REACHED'
    "
    assert_failure "$err_logic_error"
    assert_output --partial "end_scope() in 'caller': the innermost open scope belongs to 'leaky'"
    refute_output --partial "NOT REACHED"
}

@test "end_scope: bug-exits in a sibling function at the same call depth that did not open the scope" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        function opener() { begin_scope; }
        function closer() { end_scope; }
        function caller() { opener; closer; }
        caller
    "
    assert_failure "$err_logic_error"
    assert_output --partial "end_scope() in 'closer': the innermost open scope belongs to 'opener'"
}

@test "end_scope: compares function names case-sensitively, even under nocasematch" {
    # A leaked scope of 'foo' must not be closed silently by a sibling 'FOO' at the same depth.
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        function foo()    { begin_scope; set_case_insensitive; return 0; }
        function FOO()    { end_scope; }
        function caller() { foo; FOO; }
        caller
    "
    assert_failure "$err_logic_error"
    assert_output --partial "end_scope() in 'FOO': the innermost open scope belongs to 'foo'"
}

@test "end_scope: bug-exits in a subshell for a scope opened outside it" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        begin_scope
        ( end_scope )
        echo \"SUBSHELL_RC=\$?\"
    "
    assert_success
    assert_output --partial "the innermost open scope belongs to"
    assert_line "SUBSHELL_RC=$err_logic_error"
}

@test "end_scope: bug-exits when there is no open scope" {
    run end_scope
    assert_failure "$err_logic_error"
    assert_output --partial "there is no open scope"
}

@test "begin_scope / end_scope: bug-exit when given arguments" {
    run begin_scope nocasematch
    assert_failure "$err_invalid_arguments"
    run end_scope nocasematch
    assert_failure "$err_invalid_arguments"
}

@test "report_open_scopes: core.sh reports the scopes left open at exit, and fails after the script's cleanups ran" {
    run bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        add_trap 'echo CLEANUP' EXIT
        function leaky() { begin_scope; return 0; }
        leaky
        exit 0
    "
    assert_failure "$err_logic_error"
    assert_output --partial "The scope opened in 'leaky' at"
    assert_output --partial "was never closed"
    assert_line "CLEANUP"
}

@test "report_open_scopes: reports nothing when every scope was closed" {
    run bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        function tidy() { begin_scope; end_scope; }
        tidy
        exit 0
    "
    assert_success
    refute_output --partial "was never closed"
}

@test "report_open_scopes: a subshell does not report the scopes it inherited from its parent" {
    run bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        begin_scope
        ( report_open_scopes )
        end_scope
    "
    assert_success
    refute_output --partial "was never closed"
}
