#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/lib/_dotnet.predicates.sh: build configuration, TFM, RID, preprocessor symbols, coverage and
# regression percentages, MinVer tag prefix and prerelease identifier, NuGet server.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx err_invalid_arguments
declare -gx err_argument_type
declare -gx err_argument_value
declare -gx err_logic_error

# --- allow-lists: build configuration, framework, runtime ---------------------------------------

@test "is_valid_build_configuration: accepts Debug and Release, rejects any other value, lowercase ones included" {
    run is_valid_build_configuration "Release"
    assert_success
    assert_output ""
    run is_valid_build_configuration "release"
    assert_failure
    assert_output --partial "Invalid build configuration 'release': use one of Debug,Release"
}

@test "is_valid_framework: accepts a TFM in use and empty, rejects any other value" {
    run is_valid_framework ""
    assert_success
    run is_valid_framework "net10.0"
    assert_success
    run is_valid_framework "net8.0"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid Target Framework Moniker (TFM) 'net8.0': use one of"
    run is_valid_framework "NET10.0"
    assert_failure "$err_argument_value"
}

@test "is_valid_runtime: accepts a RID in use and empty, rejects any other value, injection-shaped ones included" {
    run is_valid_runtime ""
    assert_success
    run is_valid_runtime "linux-x64"
    assert_success
    run is_valid_runtime "linux-x64; rm -rf /"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid Runtime Identifier (RID) 'linux-x64; rm -rf /': use one of"
    run is_valid_runtime "Linux-x64"
    assert_failure "$err_argument_value"
}

# --- is_preprocessor_symbol / is_valid_preprocessor_symbol ------------------------------------------

@test "is_preprocessor_symbol: true for a C# identifier, false otherwise, without a message" {
    local symbol
    for symbol in "DEBUG" "SHORT_RUN" "_x1"; do
        run is_preprocessor_symbol "$symbol"
        assert_success
    done
    for symbol in "1BAD" "BAD-SYMBOL" "" "A B"; do
        run is_preprocessor_symbol "$symbol"
        assert_failure
        assert_output ""
    done
}

@test "is_valid_preprocessor_symbol: accepts a C# identifier, rejects anything else with an 'Invalid preprocessor symbol' error" {
    run is_valid_preprocessor_symbol "SHORT_RUN"
    assert_success
    assert_output ""
    run is_valid_preprocessor_symbol "1BAD"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid preprocessor symbol '1BAD'"
}

@test "is_valid_preprocessor_symbol: bug-exits with the wrong argument count" {
    run is_valid_preprocessor_symbol
    assert_failure "$err_invalid_arguments"
}

# --- validate_preprocessor_symbols -----------------------------------------------------------

@test "validate_preprocessor_symbols: accepts empty input" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s=''; validate_preprocessor_symbols s; echo \"[\$s]\""
    assert_success
    assert_output "[]"
}

@test "validate_preprocessor_symbols: normalizes separators to semicolons and dedupes consecutive separators" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s='DEBUG, TRACE:: FOO'; validate_preprocessor_symbols s; echo \"[\$s]\""
    assert_success
    assert_output "[DEBUG;TRACE;FOO]"
}

@test "validate_preprocessor_symbols: rejects an invalid symbol" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s='1BAD'; validate_preprocessor_symbols s"
    assert_failure "$err_argument_value"
}

@test "validate_preprocessor_symbols: reports every invalid symbol, not just the first, and leaves the variable unchanged" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s='1BAD OK 2BAD'; validate_preprocessor_symbols s; rc=\$?; echo \"[\$s]\"; exit \$rc"
    assert_failure "$err_argument_value"
    assert_output --partial "'1BAD'"
    assert_output --partial "'2BAD'"
    assert_output --partial "[1BAD OK 2BAD]"
}

# --- percentage validation ---------------------------------------------------------------------

@test "is_valid_min_coverage_pct, is_valid_max_regression_pct: accept 0-100, reject anything else" {
    run is_valid_min_coverage_pct 80
    assert_success
    run is_valid_max_regression_pct 20
    assert_success
    run is_valid_min_coverage_pct 150
    assert_failure "$err_argument_value"
    run is_valid_max_regression_pct 101
    assert_failure "$err_argument_value"
}
