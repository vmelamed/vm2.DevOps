#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/run-tests.args.sh (with run-tests.usage.sh), following the seams of the get_arguments()
# pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each test sources
# gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell, started in
# $BATS_TEST_TMPDIR/work.
#
# resolve_arguments() calls sanitize_common_dotnet_args(), which resolves the artifacts path with a real MSBuild
# evaluation. The tests replace it with a stub that only reports which project it got: they are about this script's own
# arguments; the common dotnet arguments have their own tests (test_dotnet_args.bats). A fake 'dotnet' that reports
# $dotnet_min_version stands in for the real one.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_too_many_arguments
declare -gxi err_unknown_argument

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 in $BATS_TEST_TMPDIR/work, with the optional environment assignments $2 (several, space-separated).
_rt() {
    # shellcheck disable=SC2086 # $2 holds zero or more assignments: word splitting is intended
    (cd "$BATS_TEST_TMPDIR/work" && env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:-} bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/run-tests.usage.sh'
        source '$_gh_scripts_dir/run-tests.args.sh'
        sanitize_common_dotnet_args() { echo \"SANITIZE \$1\"; }
        $1
    ")
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/work/tests/App"
    printf '#!/usr/bin/env bash\n[[ $1 == --version ]] && echo "$dotnet_min_version"\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/dotnet"
    chmod +x "$BATS_TEST_TMPDIR/bin/dotnet"
    echo '<Project />' > "$BATS_TEST_TMPDIR/work/tests/App/App.Tests.csproj"
    echo '<Solution />' > "$BATS_TEST_TMPDIR/work/App.slnx"
}

_project='test_project=tests/App/App.Tests.csproj'

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _rt "parse_arguments
             declare -p test_project min_coverage_pct min_branch_coverage_pct min_method_coverage_pct"
    assert_success
    assert_output --partial 'test_project=""'
    assert_output --partial 'min_coverage_pct="80"'
    assert_output --partial 'min_branch_coverage_pct=""'
    assert_output --partial 'min_method_coverage_pct=""'
}

@test "parse_arguments: the defaults come from \$TEST_PROJECT and \$MIN_COVERAGE_PCT when they are set" {
    run _rt "parse_arguments
             declare -p test_project min_coverage_pct" "TEST_PROJECT=x.csproj MIN_COVERAGE_PCT=90"
    assert_success
    assert_output --partial 'test_project="x.csproj"'
    assert_output --partial 'min_coverage_pct="90"'
}

@test "parse_arguments: the positional argument is the test project; --min-coverage-pct and -min set the threshold" {
    run _rt "parse_arguments x.csproj --min-coverage-pct 90 --define SHORT_RUN
             declare -p test_project min_coverage_pct preprocessor_symbols"
    assert_success
    assert_output --partial 'test_project="x.csproj"'
    assert_output --partial 'min_coverage_pct="90"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'

    run _rt "parse_arguments -MIN 85
             declare -p min_coverage_pct"
    assert_success
    assert_output --partial 'min_coverage_pct="85"'
}

@test "parse_arguments: --min-coverage-pct without a value fails with usage" {
    run _rt "parse_arguments --min-coverage-pct"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing value for --min-coverage-pct"
}

@test "parse_arguments: a second test project is rejected" {
    run _rt "parse_arguments a.csproj b.csproj; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Multiple test projects specified: b.csproj"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the test project" {
    run _rt "parse_arguments --bogus; declare -p test_project"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "test_project="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _rt "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _rt "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when dotnet is present" {
    run _rt "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing dotnet and returns instead of exiting" {
    run _rt "is_tool_present() { [[ \$1 != dotnet ]]; }
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "'dotnet' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: derives the branch (5 lower) and the method (equal) thresholds, and freezes everything" {
    run _rt "$_project min_coverage_pct=90
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p test_project min_coverage_pct min_branch_coverage_pct min_method_coverage_pct"
    assert_success
    assert_output --partial "SANITIZE tests/App/App.Tests.csproj"
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx test_project="tests/App/App.Tests.csproj"'
    assert_output --partial 'declare -rx min_coverage_pct="90"'
    assert_output --partial 'declare -rx min_branch_coverage_pct="85"'
    assert_output --partial 'declare -rx min_method_coverage_pct="90"'
}

@test "resolve_arguments: \$MIN_BRANCH_COVERAGE_PCT and \$MIN_METHOD_COVERAGE_PCT override the derived thresholds" {
    run _rt "$_project
             resolve_arguments
             declare -p min_branch_coverage_pct min_method_coverage_pct" "MIN_BRANCH_COVERAGE_PCT=60 MIN_METHOD_COVERAGE_PCT=70"
    assert_success
    assert_output --partial 'min_branch_coverage_pct="60"'
    assert_output --partial 'min_method_coverage_pct="70"'
}

@test "resolve_arguments: reports a coverage threshold below 50, and derives no other threshold" {
    run _rt "$_project min_coverage_pct=40
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p min_branch_coverage_pct"
    assert_output --partial "min-coverage-pct must be between 50-100."
    assert_output --partial "HAS_ERRORS"
    assert_output --partial 'min_branch_coverage_pct=""'
}

@test "resolve_arguments: reports a coverage threshold that is not a percentage, and never evaluates it" {
    run _rt "$_project min_coverage_pct='x[\$(printf %s%s INJ ECTED >&2)]'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_output --partial "must be an integer number between 0 and 100"
    assert_output --partial "HAS_ERRORS"
    refute_output --partial "INJECTED"
}

@test "resolve_arguments: reports an invalid overriding branch threshold" {
    run _rt "$_project
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "MIN_BRANCH_COVERAGE_PCT=101"
    assert_output --partial "The min coverage percentage '101' must be an integer number between 0 and 100."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: rejects a solution, a project that does not exist, and a missing project" {
    local _value
    for _value in App.slnx tests/NotThere.csproj ''; do
        run _rt "test_project='$_value'
                 resolve_arguments
                 has_errors && echo HAS_ERRORS || echo NO_ERRORS"
        assert_output --partial "HAS_ERRORS"
    done
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _rt "get_arguments tests/App/App.Tests.csproj --min-coverage-pct 70
             declare -p test_project min_branch_coverage_pct"
    assert_success
    assert_output --partial 'declare -rx test_project="tests/App/App.Tests.csproj"'
    assert_output --partial 'declare -rx min_branch_coverage_pct="65"'
}

@test "get_arguments: -h prints the usage and exits 0, even without a project" {
    run _rt "get_arguments -h; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: under 'set -euo pipefail' (as in run-tests.sh), a low threshold is reported with the usage" {
    run _rt "set -euo pipefail
             get_arguments tests/App/App.Tests.csproj --min-coverage-pct 40; echo AFTER"
    assert_failure
    assert_output --partial "min-coverage-pct must be between 50-100."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
