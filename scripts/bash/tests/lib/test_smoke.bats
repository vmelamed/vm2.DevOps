#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

@test "smoke: core.sh loads and is_boolean is callable" {
    run is_boolean true
    assert_success
}

@test "smoke: bug-exit on bad args is caught by run, not the whole suite" {
    run is_boolean
    assert_failure
}
