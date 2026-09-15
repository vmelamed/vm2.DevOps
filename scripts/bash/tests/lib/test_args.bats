#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_args.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- get_common_arg -----------------------------------------------------------------------------

@test "get_common_arg: recognizes --verbose/-v and sets verbose mode" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg --verbose; is_verbose"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg -v; is_verbose"
    assert_success
}

@test "get_common_arg: recognizes -q/--quiet and sets quiet mode" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg --quiet; is_quiet"
    assert_success
}

@test "get_common_arg: recognizes -y/--dry-run and sets dry-run mode" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg --dry-run; is_dry_run"
    assert_success
}

@test "get_common_arg: recognizes -gr/-md and sets table format" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg -md; get_table_format"
    assert_success
    assert_output "markdown"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg -gr; get_table_format"
    assert_success
    assert_output "graphical"
}

@test "get_common_arg: is case-insensitive" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg '--VERBOSE'; is_verbose"
    assert_success
}

@test "get_common_arg: records --help/-h/-? into \$usage_requested" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg --help; echo \"\$usage_requested\""
    assert_output "long"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg -h; echo \"\$usage_requested\""
    assert_output "short"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg -?; echo \"\$usage_requested\""
    assert_output "short"
}

@test "get_common_arg: returns failure (not processed) for an unrecognized argument" {
    run get_common_arg "--not-a-common-flag"
    assert_failure 1
}

@test "get_common_arg: bug-exits with wrong argument count" {
    run get_common_arg
    assert_failure 254
    run get_common_arg a b
    assert_failure 254
}

# --- usage_if_requested --------------------------------------------------------------------------

@test "usage_if_requested: no-op when no usage was requested" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage_if_requested; echo done"
    assert_success
    assert_output "done"
}

@test "usage_if_requested: exits (via usage) when --help was recorded" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; get_common_arg --help; usage_if_requested; echo not-reached"
    assert_success
    refute_output --partial "not-reached"
}

# --- usage ----------------------------------------------------------------------------------------

@test "usage: exits 0 with no error messages and no explicit exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage"
    assert_success
}

@test "usage: exits 1 (failure) when error messages are given but no explicit exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage true 'something went wrong'"
    assert_failure 1
    assert_output --partial "something went wrong"
}

@test "usage: preserves an explicitly-provided exit code, even alongside error messages" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage true 42 'custom error'"
    assert_failure 42
    assert_output --partial "custom error"
}

@test "usage: shows the long usage text (including common switches) only when \$1 is true" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage true"
    assert_output --partial "Common switches:"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage false"
    refute_output --partial "Common switches:"
}

# --- usage_text (default placeholder implementation) ---------------------------------------------

@test "usage_text: prints the override-me placeholder, naming the script" {
    run bash -c "script_name='my-script.sh'; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage_text false"
    assert_success
    assert_output --partial "my-script.sh"
    assert_output --partial "OVERRIDE THE FUNCTION usage_text()"
}

@test "usage_text: includes Switches and Environment Variables sections only when \$1 is true" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage_text true"
    assert_output --partial "Common switches:"
    assert_output --partial "Common environment variables:"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/_args.sh'; usage_text false"
    refute_output --partial "Common switches:"
    refute_output --partial "Common environment variables:"
}
