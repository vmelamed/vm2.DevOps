#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/run-benchmarks.args.sh (with run-benchmarks.usage.sh), following the seams of the
# get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each
# test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell, started
# in $BATS_TEST_TMPDIR/work.
#
# resolve_arguments() ends with sanitize_common_dotnet_args(), which resolves the artifacts path with a real MSBuild
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
declare -gxi err_too_many_arguments
declare -gxi err_unknown_argument

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 in $BATS_TEST_TMPDIR/work, with the optional environment assignments $2 (several, space-separated).
_rb() {
    # shellcheck disable=SC2086 # $2 holds zero or more assignments: word splitting is intended
    (cd "$BATS_TEST_TMPDIR/work" && env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:-} bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/run-benchmarks.usage.sh'
        source '$_gh_scripts_dir/run-benchmarks.args.sh'
        sanitize_common_dotnet_args() { echo \"SANITIZE \$1\"; }
        $1
    ")
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/work/benchmarks/App"
    printf '#!/usr/bin/env bash\n[[ $1 == --version ]] && echo "$dotnet_min_version"\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/dotnet"
    chmod +x "$BATS_TEST_TMPDIR/bin/dotnet"
    echo '<Project />' > "$BATS_TEST_TMPDIR/work/benchmarks/App/App.Benchmarks.csproj"
    echo '<Solution />' > "$BATS_TEST_TMPDIR/work/App.slnx"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the benchmark project empty when no arguments are given" {
    run _rb "parse_arguments
             declare -p benchmark_project"
    assert_success
    assert_output --partial 'benchmark_project=""'
}

@test "parse_arguments: the default benchmark project comes from \$BENCHMARK_PROJECT when it is set" {
    run _rb "parse_arguments
             declare -p benchmark_project" "BENCHMARK_PROJECT=x.csproj"
    assert_success
    assert_output --partial 'benchmark_project="x.csproj"'
}

@test "parse_arguments: the positional argument is the benchmark project; the common dotnet options are recorded" {
    run _rb "parse_arguments --define SHORT_RUN x.csproj --minver-tag-prefix rel
             declare -p benchmark_project preprocessor_symbols minver_tag_prefix"
    assert_success
    assert_output --partial 'benchmark_project="x.csproj"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'
    assert_output --partial 'minver_tag_prefix="rel"'
}

@test "parse_arguments: a second benchmark project is rejected" {
    run _rb "parse_arguments a.csproj b.csproj; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Multiple benchmark projects specified: b.csproj"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the benchmark project" {
    run _rb "parse_arguments --bogus; declare -p benchmark_project"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "benchmark_project="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _rb "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _rb "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when dotnet is present" {
    run _rb "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing dotnet and returns instead of exiting" {
    run _rb "is_tool_present() { [[ \$1 != dotnet ]]; }
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

@test "resolve_arguments: accepts an existing project file, sanitizes the common arguments with it, and freezes it" {
    run _rb "benchmark_project=benchmarks/App/App.Benchmarks.csproj
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p benchmark_project"
    assert_success
    assert_output --partial "SANITIZE benchmarks/App/App.Benchmarks.csproj"
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx benchmark_project="benchmarks/App/App.Benchmarks.csproj"'
}

@test "resolve_arguments: rejects a solution: only project files are accepted" {
    run _rb "benchmark_project=App.slnx
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_output --partial "accepts only project files (*.csproj)"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports a project that does not exist, and a missing project" {
    run _rb "benchmark_project=benchmarks/NotThere/NotThere.csproj
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_output --partial "benchmarks/NotThere/NotThere.csproj"
    assert_output --partial "HAS_ERRORS"

    run _rb "resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_output --partial "accepts only project files (*.csproj)"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _rb "get_arguments benchmarks/App/App.Benchmarks.csproj --define SHORT_RUN
             declare -p benchmark_project preprocessor_symbols"
    assert_success
    assert_output --partial 'declare -rx benchmark_project="benchmarks/App/App.Benchmarks.csproj"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'
}

@test "get_arguments: -h prints the usage and exits 0, even without a project" {
    run _rb "get_arguments -h; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: under 'set -euo pipefail' (as in run-benchmarks.sh), a solution is reported with the usage" {
    run _rb "set -euo pipefail
             get_arguments App.slnx; echo AFTER"
    assert_failure
    assert_output --partial "accepts only project files (*.csproj)"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
