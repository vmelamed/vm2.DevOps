#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/core.args.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir

declare -gx failure
declare -gx err_invalid_arguments
declare -gx err_unknown_argument

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
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg -md; declare format=''; get_table_format format; echo \"\$format\""
    assert_success
    assert_output "markdown"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_arg -gr; declare format=''; get_table_format format; echo \"\$format\""
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
    assert_failure "$failure"
}

@test "get_common_arg: bug-exits with wrong argument count" {
    run get_common_arg
    assert_failure "$err_invalid_arguments"
    run get_common_arg a b
    assert_failure "$err_invalid_arguments"
}

# --- usage_if_requested --------------------------------------------------------------------------

@test "usage_if_requested: no-op when no usage was requested" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage_if_requested; echo done"
    assert_success
    assert_output "done"
}

@test "usage_if_requested: exits (via usage) when --help was recorded" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; get_common_arg --help; usage_if_requested; echo not-reached"
    assert_success
    refute_output --partial "not-reached"
}

# --- usage ----------------------------------------------------------------------------------------

@test "usage: exits 0 with no error messages and no explicit exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage"
    assert_success
}

@test "usage: exits 1 (failure) when error messages are given with neither an explicit exit code nor -ec" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage true 'something went wrong'"
    assert_failure "$failure"
    assert_output --partial "something went wrong"
}

@test "usage: preserves an explicitly-provided exit code, even alongside error messages" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage true 42 'custom error'"
    assert_failure 42
    assert_output --partial "custom error"
}

# Without an explicit exit code, usage() exits with the code of the first --error-code/-ec among the messages -- the same
# rule as exit_with_error/exit_with_bug. Every parser calls it as 'usage -ec "$err_x" "…"'.
@test "usage: exits with the -ec code of the messages when no explicit exit code is given" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage -ec \"\$err_unknown_argument\" 'Unknown option: --bogus'"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown option: --bogus"
}

@test "usage: a trailing -ec after the message sets the exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage 'Unknown option: --bogus' -ec \"\$err_unknown_argument\""
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown option: --bogus"
    refute_output --partial "-ec"
}

@test "usage: the long form --error-code sets the exit code too" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage --error-code \"\$err_unknown_argument\" 'Unknown option: --bogus'"
    assert_failure "$err_unknown_argument"
}

@test "usage: an explicit exit code wins over the -ec code of the messages" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage 42 -ec \"\$err_unknown_argument\" 'custom error'"
    assert_failure 42
}

@test "usage: an explicit 0 alongside error messages falls back to the -ec code (never exits 0 with errors)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage 0 -ec \"\$err_unknown_argument\" 'custom error'"
    assert_failure "$err_unknown_argument"
}

@test "usage: -ec 0 alongside error messages exits 1 (failure), never 0" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage -ec 0 'custom error'"
    assert_failure "$failure"
}

@test "usage: a leading code exits with that code, the same as a trailing -ec" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage \"\$err_unknown_argument\" 'Unknown option: --bogus' 2>&1"
    assert_failure "$err_unknown_argument"
    local _leading=$output
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage 'Unknown option: --bogus' -ec \"\$err_unknown_argument\" 2>&1"
    assert_failure "$err_unknown_argument"
    # the two forms print the same, except for the line number of the call in the location and the stack
    [[ ${_leading//[0-9]/} == "${output//[0-9]/}" ]]
}

@test "usage: a leading code after the boolean exits with that code and shows the long usage text" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage true \"\$err_unknown_argument\" 'Unknown option: --bogus'"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown option: --bogus"
    assert_output --partial "Common switches:"
}

@test "usage: without messages exits 0, even when an earlier error left a last error code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; error 7 'earlier' 2> /dev/null; usage true"
    assert_success
}

@test "usage: a leading 0 is a message part, not a code: it exits 1 (failure), never 0" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage 0 'custom error' 2>&1"
    assert_failure "$failure"
    assert_output --partial "ERROR: 0 @ "
}

@test "usage: the error's location is the caller of usage, not usage itself" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$lib_dir/core.args.sh'
        caller_of_usage() { usage 'from the caller'; }
        caller_of_usage 2>&1
    "
    assert_failure "$failure"
    assert_line --index 0 --regexp "^.*ERROR: from the caller @ (environment|bash|main|-c)? ?\\([0-9]+\\):\$"
    refute_output --partial "core.args.sh"
    refute_output --partial "_diagnostics.messages.sh"
    assert_output --partial "caller_of_usage"
}

@test "usage: -ns suppresses the location and the stack" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage \"\$err_unknown_argument\" 'no stack' -ns 2>&1"
    assert_failure "$err_unknown_argument"
    assert_line --index 0 --partial "ERROR: no stack"
    refute_output --partial " @ "
    refute_output --partial "↑ "
}

@test "usage: runs usage_text with tracing off" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$lib_dir/core.args.sh'
        usage_text() { [[ \$- == *x* ]] && echo 'usage_text: tracing ON' || echo 'usage_text: tracing OFF'; }
        exec 2> /dev/null   # the trace lines go to the shell's stderr, not to the command's
        set -x
        usage \"\$err_unknown_argument\" 'traced?'
    "
    assert_failure "$err_unknown_argument"
    assert_line "usage_text: tracing OFF"
}

@test "usage: shows the long usage text (including common switches) only when \$1 is true" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage true"
    assert_output --partial "Common switches:"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage false"
    refute_output --partial "Common switches:"
}

# --- usage_text (default placeholder implementation) ---------------------------------------------

@test "usage_text: prints the override-me placeholder, naming the script" {
    run bash -c "script_name='my-script.sh'; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage_text false"
    assert_success
    assert_output --partial "my-script.sh"
    assert_output --partial "OVERRIDE THE FUNCTION usage_text()"
}

@test "usage_text: includes Switches and Environment Variables sections only when \$1 is true" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage_text true"
    assert_output --partial "Common switches:"
    assert_output --partial "Common environment variables:"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; source '$lib_dir/core.args.sh'; usage_text false"
    refute_output --partial "Common switches:"
    refute_output --partial "Common environment variables:"
}
