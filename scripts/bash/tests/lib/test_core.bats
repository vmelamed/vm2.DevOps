#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/core.sh, as it behaves TODAY.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi failure
declare -gxi err_invalid_arguments
declare -gxi err_argument_type
declare -gxi err_argument_value

# --- trap setup / remove_traps -----------------------------------------------------------------

@test "core.sh: sets the ERR and EXIT traps by default" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        [[ -n \$(trap -p ERR) ]]  || { echo 'ERR trap not set'; exit 1; }
        [[ -n \$(trap -p EXIT) ]] || { echo 'EXIT trap not set'; exit 1; }
        echo OK
    "
    assert_success
    assert_output "OK"
}

@test "core.sh --no-trap: suppresses the ERR and EXIT traps" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        [[ -z \$(trap -p ERR) ]]  || { echo 'ERR trap set despite --no-trap'; exit 1; }
        [[ -z \$(trap -p EXIT) ]] || { echo 'EXIT trap set despite --no-trap'; exit 1; }
        echo OK
    "
    assert_success
    assert_output "OK"
}

@test "remove_traps: the ERR trap fires before it is called, as a sanity precondition" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        false
        echo 'reached after false'
    "
    assert_output --partial "ON ERROR post-mortem"
}

@test "remove_traps: suppresses the ERR trap so a subsequent failing command no longer reports it" {
    # Functional check, not a trap -p introspection: trap - ERR (reset-to-default) does not
    # reliably clear an ERR trap when called from inside a function -- remove_traps always is
    # one -- even though trap -p ERR can look "cleared" either way depending on how it's done.
    # What matters is whether the handler actually still runs; this checks exactly that.
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        remove_traps
        false
        echo 'reached after false'
    "
    assert_success
    assert_output "reached after false"
    refute_output --partial "ON ERROR post-mortem"
}

@test "remove_traps: the EXIT trap fires before it is called, as a sanity precondition" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        false
    "
    assert_failure "$failure"
    assert_output --partial "EXIT: the command 'false' failed"
}

@test "remove_traps: suppresses the EXIT trap so on_exit no longer reports the failing command" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        remove_traps
        false
    "
    assert_failure "$failure"
    refute_output --partial "EXIT: the command"
    refute_output --partial "ON ERROR post-mortem"
}

@test "remove_traps: is a harmless no-op when no traps were set" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        remove_traps
        echo OK
    "
    assert_success
    assert_output "OK"
}

# --- execute -------------------------------------------------------------------------------

@test "execute: bug-exits with no arguments" {
    run execute
    assert_failure "$err_invalid_arguments"
}

@test "execute: runs the command and forwards its stdout and exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute echo 'ran for real'"
    assert_success
    assert_output "ran for real"
}

@test "execute: in dry-run mode, prints the would-be command instead of running it" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute touch '$BATS_TEST_TMPDIR/should-not-exist'"
    assert_success
    assert_output "dry-run\$ touch $BATS_TEST_TMPDIR/should-not-exist"
    [[ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]]
}

@test "execute: forwards the failing command's own exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute bash -c 'exit 7'"
    assert_failure 7
}

# --- execute_with_retry ---------------------------------------------------------------------

@test "execute_with_retry: bug-exits with fewer than three arguments" {
    run execute_with_retry 3 1
    assert_failure "$err_invalid_arguments"
}

@test "execute_with_retry: bug-exits on a non-natural max-attempts or delay" {
    run execute_with_retry 0 1 echo hi
    assert_failure "$err_argument_type"
    run execute_with_retry 3 -1 echo hi
    assert_failure "$err_argument_type"
}

@test "execute_with_retry: succeeds without retrying when the command succeeds immediately" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 3 1 echo hi"
    assert_success
    refute_output --partial "Retrying"
}

@test "execute_with_retry: a command literally named 'true'/'false' is consumed as the output-suppression flag, not run (accepted, documented ambiguity)" {
    # is_boolean "$1" && $1 && _output=... always treats a bare 'true'/'false' as the optional
    # output-suppression flag (core.sh:230-231), so it can never be the command itself -- see the
    # function's own doc comment for why this is accepted rather than fixed (retrying the literal
    # command 'true' or 'false' is never something a real caller would want).
    run execute_with_retry 3 1 true
    assert_failure "$err_invalid_arguments"
}

@test "execute_with_retry: retries on failure and returns success once the command succeeds" {
    local _counter="$BATS_TEST_TMPDIR/counter"
    local _script="$BATS_TEST_TMPDIR/attempt.sh"
    echo 0 > "$_counter"
    cat > "$_script" <<'SCRIPT'
#!/usr/bin/env bash
n=$(<"$1")
n=$((n + 1))
echo "$n" > "$1"
(( n >= 2 ))
SCRIPT
    chmod +x "$_script"

    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 3 1 bash '$_script' '$_counter'"
    assert_success
    assert_output --partial "Command failed (attempt 1/3). Retrying in 1s."
    [[ "$(cat "$_counter")" == 2 ]]
}

@test "execute_with_retry: returns the command's own exit code after exhausting all attempts" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 2 1 bash -c 'exit 7'"
    assert_failure 7
    assert_output --partial "Command failed (attempt 1/2)."
}

@test "execute_with_retry: redirects the command's stdout to \$_ignore when the output-suppression flag is true" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 3 1 true echo should-be-suppressed"
    assert_success
    refute_output --partial "should-be-suppressed"
}

@test "execute_with_retry: leaves the command's stdout visible when the output-suppression flag is false" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 3 1 false echo should-be-visible"
    assert_success
    assert_output --partial "should-be-visible"
}

@test "execute_with_retry: in dry-run mode, never executes the command" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute_with_retry 3 1 touch '$BATS_TEST_TMPDIR/should-not-exist'"
    assert_success
    assert_output --partial "dry-run\$ touch"
    [[ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]]
}

# --- list_of_files ---------------------------------------------------------------------------

@test "list_of_files: bug-exits with the wrong argument count" {
    run list_of_files
    assert_failure "$err_invalid_arguments"
}

@test "list_of_files: bug-exits on an empty pattern" {
    run list_of_files ""
    assert_failure "$err_argument_value"
}

@test "list_of_files: expands a glob pattern to its matching files" {
    mkdir -p "$BATS_TEST_TMPDIR/glob"
    touch "$BATS_TEST_TMPDIR/glob/a.txt" "$BATS_TEST_TMPDIR/glob/b.txt"
    run bash -c "cd '$BATS_TEST_TMPDIR/glob' && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; list_of_files '*.txt'"
    assert_success
    assert_output "a.txt b.txt"
}

@test "list_of_files: a pattern with no matches expands to an empty string (nullglob)" {
    mkdir -p "$BATS_TEST_TMPDIR/glob-empty"
    run bash -c "cd '$BATS_TEST_TMPDIR/glob-empty' && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; list_of_files 'nomatch*.zzz'"
    assert_success
    assert_output ""
}

@test "list_of_files: a '**' pattern matches recursively into subdirectories (globstar)" {
    mkdir -p "$BATS_TEST_TMPDIR/glob-recursive/sub"
    touch "$BATS_TEST_TMPDIR/glob-recursive/a.txt" "$BATS_TEST_TMPDIR/glob-recursive/sub/c.txt"
    run bash -c "cd '$BATS_TEST_TMPDIR/glob-recursive' && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; list_of_files '**/*.txt'"
    assert_success
    assert_output "a.txt sub/c.txt"
}

# --- to_summary (core.sh's plain, non-GitHub-Actions form) ------------------------------------

@test "to_summary: prepends a '## Summary' heading and passes each stdin line through" {
    run bash -c "CI=true; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; printf 'line1\nline2\n' | to_summary"
    assert_success
    assert_line --index 0 "## Summary"
    assert_line --index 1 "line1"
    assert_line --index 2 "line2"
}
