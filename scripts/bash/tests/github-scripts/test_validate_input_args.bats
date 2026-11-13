#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/validate-input.args.sh (with validate-input.usage.sh), following the seams of the
# get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each
# test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell, started
# in a scratch directory with a few project files (setup).
#
# resolve_arguments() ends by handing the first existing project to sanitize_common_dotnet_args(), which resolves the
# artifacts path with a real MSBuild evaluation. The tests replace it with a stub that only reports which project it got:
# they are about this script's own arguments; the common dotnet arguments have their own tests (test_dotnet_args.bats).
# A fake 'gh' (version + auth status only) stands in for the real one.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_unknown_argument

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 in $BATS_TEST_TMPDIR/work, with the optional environment assignments $2 (several, space-separated).
_vi() {
    # shellcheck disable=SC2086 # $2 holds zero or more assignments: word splitting is intended
    (cd "$BATS_TEST_TMPDIR/work" && env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:-} bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/validate-input.usage.sh'
        source '$_gh_scripts_dir/validate-input.args.sh'
        sanitize_common_dotnet_args() { echo \"SANITIZE \$1\"; }
        $1
    ")
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/work/src" "$BATS_TEST_TMPDIR/work/tests"
    # non-empty: is_safe_existing_file rejects an empty file
    echo '<Project />' > "$BATS_TEST_TMPDIR/work/src/App.csproj"
    echo '<Project />' > "$BATS_TEST_TMPDIR/work/tests/App.Tests.csproj"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} != version && ${1:-} != --version ]] || { echo "gh version $gh_min_version"; exit 0; }
[[ "$*" == "auth status" ]] && exit 0
exit 99
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}

_all_vars='build_projects test_projects benchmark_projects package_projects runners_os min_coverage_pct max_regression_pct'
_all_vars+=' max_gen1_collects max_gen2_collects reset_benchmark_thresholds skip_build skip_tests skip_benchmarks skip_packages'

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments and no variables are given" {
    run _vi "parse_arguments
             declare -p $_all_vars"
    assert_success
    assert_output --partial 'build_projects="[]"'
    assert_output --partial 'test_projects="[]"'
    assert_output --partial 'benchmark_projects="[]"'
    assert_output --partial 'package_projects="[]"'
    assert_output --partial 'runners_os="[\"ubuntu-latest\"]"'
    assert_output --partial 'min_coverage_pct="80"'
    assert_output --partial 'max_regression_pct="20"'
    assert_output --partial 'max_gen1_collects="2"'
    assert_output --partial 'max_gen2_collects="1"'
    assert_output --partial 'reset_benchmark_thresholds="false"'
    assert_output --partial 'skip_build="false"'
    assert_output --partial 'skip_tests="false"'
    assert_output --partial 'skip_benchmarks="false"'
    assert_output --partial 'skip_packages="false"'
}

@test "parse_arguments: the defaults come from the corresponding environment variables" {
    run _vi "parse_arguments
             declare -p test_projects runners_os min_coverage_pct skip_tests" \
            'TEST_PROJECTS=["tests/App.Tests.csproj"] RUNNERS_OS=["windows-latest"] MIN_COVERAGE_PCT=90 SKIP_TESTS=true'
    assert_success
    assert_output --partial 'test_projects="[\"tests/App.Tests.csproj\"]"'
    assert_output --partial 'runners_os="[\"windows-latest\"]"'
    assert_output --partial 'min_coverage_pct="90"'
    assert_output --partial 'skip_tests="true"'
}

@test "parse_arguments: the long options set the corresponding variables" {
    run _vi "parse_arguments --build-projects b --test-projects t --benchmark-projects m --package-projects p \
                             --runners-os o --min-coverage-pct 90 --max-regression-pct 10 --max-gen1-collects 3 \
                             --max-gen2-collects 4 --reset-benchmark-thresholds true --skip-build true --skip-tests true \
                             --skip-benchmarks true --skip-packages true
             declare -p $_all_vars"
    assert_success
    assert_output --partial 'build_projects="b"'
    assert_output --partial 'test_projects="t"'
    assert_output --partial 'benchmark_projects="m"'
    assert_output --partial 'package_projects="p"'
    assert_output --partial 'runners_os="o"'
    assert_output --partial 'min_coverage_pct="90"'
    assert_output --partial 'max_regression_pct="10"'
    assert_output --partial 'max_gen1_collects="3"'
    assert_output --partial 'max_gen2_collects="4"'
    assert_output --partial 'reset_benchmark_thresholds="true"'
    assert_output --partial 'skip_build="true"'
    assert_output --partial 'skip_tests="true"'
    assert_output --partial 'skip_benchmarks="true"'
    assert_output --partial 'skip_packages="true"'
}

@test "parse_arguments: the short options set the corresponding variables, case-insensitively" {
    run _vi "parse_arguments -BP b -tp t -bmp m -pp p -OS o -min 90 -max 10 -g1 3 -G2 4 -rt true -sb true -st true \
                             -sbm true -sp true
             declare -p $_all_vars"
    assert_success
    assert_output --partial 'build_projects="b"'
    assert_output --partial 'test_projects="t"'
    assert_output --partial 'benchmark_projects="m"'
    assert_output --partial 'package_projects="p"'
    assert_output --partial 'runners_os="o"'
    assert_output --partial 'min_coverage_pct="90"'
    assert_output --partial 'max_regression_pct="10"'
    assert_output --partial 'max_gen1_collects="3"'
    assert_output --partial 'max_gen2_collects="4"'
    assert_output --partial 'reset_benchmark_thresholds="true"'
    assert_output --partial 'skip_build="true"'
    assert_output --partial 'skip_tests="true"'
    assert_output --partial 'skip_benchmarks="true"'
    assert_output --partial 'skip_packages="true"'
}

@test "parse_arguments: hands the common dotnet options to get_common_dotnet_arg, values included" {
    run _vi "parse_arguments --define SHORT_RUN --minver-tag-prefix rel --test-projects t
             declare -p preprocessor_symbols minver_tag_prefix test_projects"
    assert_success
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'
    assert_output --partial 'minver_tag_prefix="rel"'
    assert_output --partial 'test_projects="t"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --build-projects --test-projects --benchmark-projects --package-projects --runners-os \
                   --min-coverage-pct --max-regression-pct --max-gen1-collects --max-gen2-collects \
                   --reset-benchmark-thresholds --skip-build --skip-tests --skip-benchmarks --skip-packages; do
        run _vi "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: rejects an unknown option and any positional argument" {
    run _vi "parse_arguments --bogus; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "AFTER"

    run _vi "parse_arguments src/App.csproj; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: src/App.csproj"
    refute_output --partial "AFTER"
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _vi "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _vi "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when jq and an authenticated gh are present" {
    run _vi "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing jq and a missing gh together, and returns instead of exiting" {
    run _vi "is_tool_present() { [[ \$1 != jq && \$1 != gh ]]; }
             verify_environment
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "'jq' is not installed"
    assert_output --partial "'gh' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: accepts the defaults without errors, and sanitizes no project when there is none" {
    run _vi "resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "NO_ERRORS"
}

@test "resolve_arguments: normalizes a JSON string into a one-item JSON array" {
    run _vi "test_projects='\"tests/App.Tests.csproj\"'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p test_projects"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'test_projects="[\"tests/App.Tests.csproj\"]"'
}

@test "resolve_arguments: hands the first existing project, across all the lists, to sanitize_common_dotnet_args" {
    run _vi "build_projects='[]'
             test_projects='[\"tests/App.Tests.csproj\"]'
             package_projects='[\"src/App.csproj\"]'
             resolve_arguments"
    assert_success
    assert_output --partial "SANITIZE tests/App.Tests.csproj"
    refute_output --partial "SANITIZE src/App.csproj"
}

@test "resolve_arguments: reports a project that does not exist and a runner OS that is not allowed" {
    run _vi "build_projects='[\"src/NotThere.csproj\"]'
             runners_os='[\"ubuntu-latest\",\"bogus-os\"]'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "src/NotThere.csproj"
    assert_output --partial "The runner OS 'bogus-os' is not allowed."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports a value that is not a JSON array or string" {
    run _vi "test_projects='tests/App.Tests.csproj'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "The input must be a JSON array of strings"
    assert_output --partial "(provided 'tests/App.Tests.csproj')"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: replaces an out-of-range coverage or regression percentage with its default, with a warning" {
    run _vi "min_coverage_pct=40
             max_regression_pct=70
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p min_coverage_pct max_regression_pct"
    assert_success
    assert_output --partial "min-coverage-pct must be between 50-100."
    assert_output --partial "max-regression-pct must be between 0-50."
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'min_coverage_pct="80"'
    assert_output --partial 'max_regression_pct="20"'
}

@test "resolve_arguments: reports negative GC-collection limits and non-boolean switches" {
    run _vi "max_gen1_collects=-1 max_gen2_collects=-2 skip_build=yes reset_benchmark_thresholds=1
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "max-gen1-collects must be a non-negative integer (got '-1')."
    assert_output --partial "max-gen2-collects must be a non-negative integer (got '-2')."
    assert_output --partial "The input 'yes' is not a valid boolean."
    assert_output --partial "The input '1' is not a valid boolean."
    assert_output --partial "errors=4"
}

@test "resolve_arguments: never evaluates an invalid numeric value as arithmetic (no command substitution)" {
    # Regression guard: '(( min_coverage_pct >= 50 ... ))' on an unvalidated value runs any '$(...)' inside an array
    # subscript in it -- a command injection through a workflow input. A rejected value must be reported, never run.
    local _value
    for _value in min_coverage_pct max_regression_pct max_gen1_collects max_gen2_collects; do
        # the command prints 'INJECTED' only when it runs: the value itself spells it 'INJ ECTED'
        run _vi "$_value='x[\$(printf %s%s INJ ECTED >&2)]'
                 resolve_arguments
                 has_errors && echo HAS_ERRORS || echo NO_ERRORS"
        assert_output --partial "HAS_ERRORS"
        refute_output --partial "INJECTED"
    done
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses and resolves the arguments in one call" {
    run _vi "get_arguments --test-projects '[\"tests/App.Tests.csproj\"]' --skip-benchmarks true
             declare -p test_projects skip_benchmarks"
    assert_success
    assert_output --partial "SANITIZE tests/App.Tests.csproj"
    assert_output --partial 'test_projects="[\"tests/App.Tests.csproj\"]"'
    assert_output --partial 'skip_benchmarks="true"'
}

@test "get_arguments: -h prints the usage and exits 0, even with invalid values" {
    run _vi "get_arguments -h --runners-os bogus-os; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: invalid values end the run with the errors and the usage" {
    run _vi "get_arguments --runners-os '[\"bogus-os\"]' --skip-tests maybe; echo AFTER"
    assert_failure
    assert_output --partial "The runner OS 'bogus-os' is not allowed."
    assert_output --partial "The input 'maybe' is not a valid boolean."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
