#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Regression test for the library's circular-include-guard mechanism (the
# `(( ${__VM2_LIB_*_SH_LOADED:-0} == 1 )) && return 0` / `declare -r[i] __VM2_LIB_*_SH_LOADED=1`
# pattern at the top of every lib file).
#
# Every guard variable used to be exported (`declare -xri`/`declare -xr`). That leaks it into
# the environment of any CHILD PROCESS forked from a shell that already sourced the library --
# e.g. a workflow step that does `source gh_core.sh` for its own info()/error() calls and then
# invokes a vm2.DevOps entry-point script (run-tests.sh, pack.sh, ...) as a plain command. The
# child process inherits the exported guard already set to 1, so its own `source gh_core.sh`
# short-circuits on every module without defining a single function -- "get_common_arg: command
# not found" and friends. Caught live on 2026-09-16 via vm2.Ulid's CI run: _test.yaml's "Verify
# the artifacts..." step sources gh_core.sh and then calls run-tests.sh, which silently got none
# of its own library functions.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

@test "include guards: are not exported, so a child process sourcing the library independently still gets every function" {
    run bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        bash -c 'source \"$lib_dir/gh_core.sh\" --no-trap > /dev/null 2>&1; type -t get_common_arg'
    "
    assert_success
    assert_output "function"
}

@test "include guards: none of the __VM2_LIB_*_SH_LOADED variables are exported" {
    # env -i, not just a plain bash -c: the invoking shell (or an earlier ad-hoc debugging
    # session in it) may itself have exported one of these guards, which would otherwise leak
    # in here and mask exactly the bug this file exists to catch.
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        export -p | grep -c '__VM2_LIB_.*_SH_LOADED' || true
    "
    assert_success
    assert_output "0"
}
