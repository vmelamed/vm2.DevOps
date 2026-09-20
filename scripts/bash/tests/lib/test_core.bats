#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/core.sh, as it behaves TODAY.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

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
    assert_failure 1
    assert_output --partial "EXIT: the command 'false' failed"
}

@test "remove_traps: suppresses the EXIT trap so on_exit no longer reports the failing command" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        remove_traps
        false
    "
    assert_failure 1
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
