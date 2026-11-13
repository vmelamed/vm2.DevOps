#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/rebuild-bench-history-run.args.sh (with rebuild-bench-history-run.usage.sh), following the
# seams of the get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference
# implementation). Each test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i')
# bash subshell, started in a scratch directory with a 'benchmarks/' tree (_make_benchmarks).
#
# resolve_arguments() resolves $artifacts with get_artifacts_path(), a real MSBuild evaluation. The tests here replace it
# with a stub that answers '/fake/artifacts': they are about the arguments, and the real evaluation is covered end to end
# in test_rebuild_bench_history_run.bats. A fake 'bencher' in $BATS_TEST_TMPDIR/bin stands in for the real one.

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
declare -gx  default_minver_tag_prefix

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 in $BATS_TEST_TMPDIR/work, with the environment assignments $2 (default: a dummy
# BENCHER_API_TOKEN; pass e.g. "REPEAT=10" to run without it).
_rr() {
    local _env=${2-"BENCHER_API_TOKEN=dummy"}
    # shellcheck disable=SC2086 # $_env holds one or more assignments: word splitting is intended
    (cd "$BATS_TEST_TMPDIR/work" && env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" $_env bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/rebuild-bench-history-run.usage.sh'
        source '$_gh_scripts_dir/rebuild-bench-history-run.args.sh'
        get_artifacts_path() { local -n _stub_artifacts=\$2; _stub_artifacts=/fake/artifacts; }
        $1
    ")
}

setup() {
    _tmp=$(realpath "$BATS_TEST_TMPDIR")
    mkdir -p "$_tmp/bin" "$_tmp/work"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$_tmp/bin/bencher"
    chmod +x "$_tmp/bin/bencher"
}

# Two benchmark projects under $BATS_TEST_TMPDIR/work/benchmarks, plus build output that must not be picked up.
_make_benchmarks() {
    mkdir -p "$_tmp/work/benchmarks/A" "$_tmp/work/benchmarks/B" "$_tmp/work/benchmarks/A/obj"
    touch "$_tmp/work/benchmarks/A/A.Benchmarks.csproj" "$_tmp/work/benchmarks/B/B.Benchmarks.csproj"
    touch "$_tmp/work/benchmarks/A/obj/Stale.csproj"
}

# The arguments resolve_arguments() needs to succeed.
_valid='bencher_project=vm2-ulid bencher_testbed=ubuntu-latest'

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _rr "parse_arguments
             declare -p repeat preprocessor_symbols minver_tag_prefix minver_prerelease_id bencher_project bencher_testbed \
                        bencher_branch bencher_adapter benchmark_project"
    assert_success
    assert_output --partial 'repeat="10"'
    assert_output --partial 'preprocessor_symbols=""'
    assert_output --partial "minver_tag_prefix=\"$default_minver_tag_prefix\""
    assert_output --partial 'minver_prerelease_id=""'
    assert_output --partial 'bencher_project=""'
    assert_output --partial 'bencher_testbed=""'
    assert_output --partial 'bencher_branch="main"'
    assert_output --partial 'bencher_adapter="c_sharp_dot_net"'
    assert_output --partial 'benchmark_project=""'
}

@test "parse_arguments: the defaults come from the corresponding environment variables" {
    run _rr "parse_arguments
             declare -p repeat preprocessor_symbols bencher_project bencher_testbed bencher_branch bencher_adapter benchmark_project" \
            "REPEAT=3 PREPROCESSOR_SYMBOLS=SHORT_RUN BENCHER_PROJECT=p BENCHER_TESTBED=t BENCHER_BRANCH=b BENCHER_ADAPTER=a BENCHMARK_PROJECT=x.csproj"
    assert_success
    assert_output --partial 'repeat="3"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'
    assert_output --partial 'bencher_project="p"'
    assert_output --partial 'bencher_testbed="t"'
    assert_output --partial 'bencher_branch="b"'
    assert_output --partial 'bencher_adapter="a"'
    assert_output --partial 'benchmark_project="x.csproj"'
}

@test "parse_arguments: the long options and the positional benchmark project set the corresponding variables" {
    run _rr "parse_arguments --repeat 3 --define SHORT_RUN --minver-tag-prefix rel --minver-prerelease-id rc.0 \
                             --bencher-project p --bencher-testbed t --bencher-branch b --bencher-adapter a x.csproj
             declare -p repeat preprocessor_symbols minver_tag_prefix minver_prerelease_id bencher_project bencher_testbed \
                        bencher_branch bencher_adapter benchmark_project"
    assert_success
    assert_output --partial 'repeat="3"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'
    assert_output --partial 'minver_tag_prefix="rel"'
    assert_output --partial 'minver_prerelease_id="rc.0"'
    assert_output --partial 'bencher_project="p"'
    assert_output --partial 'bencher_testbed="t"'
    assert_output --partial 'bencher_branch="b"'
    assert_output --partial 'bencher_adapter="a"'
    assert_output --partial 'benchmark_project="x.csproj"'
}

@test "parse_arguments: the short options set the corresponding variables, case-insensitively" {
    run _rr "parse_arguments -N 3 -d SHORT_RUN -MP rel -mi rc.0 -BP p -tb t -br b -AD a
             declare -p repeat preprocessor_symbols minver_tag_prefix minver_prerelease_id bencher_project bencher_testbed \
                        bencher_branch bencher_adapter"
    assert_success
    assert_output --partial 'repeat="3"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'
    assert_output --partial 'minver_tag_prefix="rel"'
    assert_output --partial 'minver_prerelease_id="rc.0"'
    assert_output --partial 'bencher_project="p"'
    assert_output --partial 'bencher_testbed="t"'
    assert_output --partial 'bencher_branch="b"'
    assert_output --partial 'bencher_adapter="a"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --repeat --define --minver-tag-prefix --minver-prerelease-id \
                   --bencher-project --bencher-testbed --bencher-branch --bencher-adapter; do
        run _rr "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: a second benchmark project is rejected" {
    run _rr "parse_arguments a.csproj b.csproj; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Multiple benchmark projects specified: b.csproj"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the benchmark project" {
    run _rr "parse_arguments --bogus; declare -p benchmark_project"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "benchmark_project="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _rr "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _rr "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently with bencher and \$BENCHER_API_TOKEN" {
    run _rr "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing bencher and a missing \$BENCHER_API_TOKEN together, and returns" {
    run _rr "is_tool_present() { [[ \$1 != bencher ]]; }
             verify_environment
             echo REACHED
             echo \"errors=\$(get_errors)\"" "REPEAT=10"
    assert_success
    assert_output --partial "'bencher' is not installed"
    assert_output --partial "The BENCHER_API_TOKEN environment variable is required."
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: auto-detects the benchmark projects under benchmarks/, skipping build output" {
    _make_benchmarks
    run _rr "$_valid
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p benchmark_projects artifacts"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'benchmark_projects=([0]="benchmarks/A/A.Benchmarks.csproj" [1]="benchmarks/B/B.Benchmarks.csproj")'
    refute_output --partial "Stale.csproj"
    assert_output --partial 'artifacts="/fake/artifacts"'
}

@test "resolve_arguments: a given benchmark project is the only one, even when benchmarks/ has others" {
    _make_benchmarks
    run _rr "$_valid benchmark_project=benchmarks/B/B.Benchmarks.csproj
             resolve_arguments
             declare -p benchmark_projects"
    assert_success
    assert_output --partial 'benchmark_projects=([0]="benchmarks/B/B.Benchmarks.csproj")'
}

@test "resolve_arguments: freezes the resolved arguments" {
    _make_benchmarks
    run _rr "$_valid
             resolve_arguments
             declare -p preprocessor_symbols minver_tag_prefix minver_prerelease_id artifacts benchmark_projects \
                        bencher_project bencher_testbed bencher_branch bencher_adapter repeat"
    assert_success
    assert_output --partial "declare -rx preprocessor_symbols="
    assert_output --partial "declare -rx minver_tag_prefix="
    assert_output --partial "declare -rx minver_prerelease_id="
    assert_output --partial "declare -rx artifacts="
    assert_output --partial "declare -arx benchmark_projects="
    assert_output --partial "declare -rx bencher_project="
    assert_output --partial "declare -rx bencher_testbed="
    assert_output --partial "declare -rx bencher_branch="
    assert_output --partial "declare -rx bencher_adapter="
    assert_output --partial "declare -rx repeat="
}

@test "resolve_arguments: reports no benchmark projects at all" {
    run _rr "$_valid
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "No benchmark projects found under 'benchmarks/' and none specified."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports every invalid value together, and returns" {
    _make_benchmarks
    run _rr "repeat=0 bencher_project='1bad' bencher_testbed='has space' bencher_adapter='not-an-identifier'
             resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "repeat must be a positive integer (got '0')."
    assert_output --partial "The Bencher project '1bad' is not a valid project name (slug)."
    assert_output --partial "The Bencher testbed 'has space' is not a valid testbed name."
    assert_output --partial "The Bencher adapter 'not-an-identifier' is not a valid adapter name."
    assert_output --partial "REACHED"
    assert_output --partial "errors=4"
}

@test "resolve_arguments: reports a missing Bencher project and testbed" {
    _make_benchmarks
    run _rr "resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "Bencher project (--bencher-project) is required"
    assert_output --partial "Bencher testbed (--bencher-testbed) is required"
    assert_output --partial "errors=2"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    _make_benchmarks
    run _rr "get_arguments --bencher-project p --bencher-testbed t --repeat 2 benchmarks/A/A.Benchmarks.csproj
             declare -p repeat benchmark_projects"
    assert_success
    assert_output --partial 'declare -rx repeat="2"'
    assert_output --partial 'benchmark_projects=([0]="benchmarks/A/A.Benchmarks.csproj")'
}

@test "get_arguments: -h prints the usage and exits 0, even without the token and the required options" {
    run _rr "get_arguments -h; echo AFTER" "REPEAT=10"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: reports the environment and the argument errors together, then exits with the usage" {
    _make_benchmarks
    run _rr "get_arguments --repeat 0; echo AFTER" "REPEAT=10"
    assert_failure
    assert_output --partial "The BENCHER_API_TOKEN environment variable is required."
    assert_output --partial "repeat must be a positive integer (got '0')."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
