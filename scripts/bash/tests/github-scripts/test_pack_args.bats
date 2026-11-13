#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/pack.args.sh (with pack.usage.sh), following the seams of the get_arguments() pipeline (see
# scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each test sources gh_core.sh and the
# files under test in a fresh, ambient-environment-free ('env -i') bash subshell, started in $BATS_TEST_TMPDIR/work.
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
_pk() {
    # shellcheck disable=SC2086 # $2 holds zero or more assignments: word splitting is intended
    (cd "$BATS_TEST_TMPDIR/work" && env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:-} bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/pack.usage.sh'
        source '$_gh_scripts_dir/pack.args.sh'
        sanitize_common_dotnet_args() { echo \"SANITIZE \$1\"; }
        $1
    ")
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/work/src/App"
    printf '#!/usr/bin/env bash\n[[ $1 == --version ]] && echo "$dotnet_min_version"\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/dotnet"
    chmod +x "$BATS_TEST_TMPDIR/bin/dotnet"
    echo '<Project />' > "$BATS_TEST_TMPDIR/work/src/App/App.csproj"
    echo '<Solution />' > "$BATS_TEST_TMPDIR/work/App.slnx"
}

_project='package_project=src/App/App.csproj'

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _pk "parse_arguments
             declare -p package_project build reason"
    assert_success
    assert_output --partial 'package_project=""'
    assert_output --partial 'build="false"'
    assert_output --partial 'reason=""'
}

@test "parse_arguments: the defaults come from \$PACKAGE_PROJECT, \$BUILD, and \$REASON when they are set" {
    run _pk "parse_arguments
             declare -p package_project build reason" "PACKAGE_PROJECT=x.csproj BUILD=true REASON=release"
    assert_success
    assert_output --partial 'package_project="x.csproj"'
    assert_output --partial 'build="true"'
    assert_output --partial 'reason="release"'
}

@test "parse_arguments: the positional argument is the package project; --build/-b and --reason/-r set the variables" {
    run _pk "parse_arguments x.csproj --build true --reason 'a release' --define SHORT_RUN
             declare -p package_project build reason preprocessor_symbols"
    assert_success
    assert_output --partial 'package_project="x.csproj"'
    assert_output --partial 'build="true"'
    assert_output --partial 'reason="a release"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'

    run _pk "parse_arguments -B true -R other
             declare -p build reason"
    assert_success
    assert_output --partial 'build="true"'
    assert_output --partial 'reason="other"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    run _pk "parse_arguments --reason"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing value for --reason"

    run _pk "parse_arguments --build"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing boolean value for --build"
}

@test "parse_arguments: a second package project is rejected" {
    run _pk "parse_arguments a.csproj b.csproj; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Multiple package projects specified: b.csproj"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the package project" {
    run _pk "parse_arguments --bogus; declare -p package_project"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "package_project="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _pk "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _pk "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when dotnet is present" {
    run _pk "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing dotnet and returns instead of exiting" {
    run _pk "is_tool_present() { [[ \$1 != dotnet ]]; }
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

@test "resolve_arguments: accepts an existing project file, sanitizes the common arguments with it, and freezes everything" {
    run _pk "$_project build=true reason='a release'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p package_project build reason"
    assert_success
    assert_output --partial "SANITIZE src/App/App.csproj"
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx package_project="src/App/App.csproj"'
    assert_output --partial 'declare -rx build="true"'
    assert_output --partial 'declare -rx reason="a release"'
}

@test "resolve_arguments: reports a non-boolean --build and an unsafe reason together, and returns" {
    run _pk "$_project build=yes reason='-rf /'
             resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "The input 'yes' is not a valid boolean."
    assert_output --partial "The reason '-rf /' appears to be a command or contains unsafe characters."
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

@test "resolve_arguments: rejects a solution, a project that does not exist, and a missing project" {
    local _value
    for _value in App.slnx src/NotThere.csproj ''; do
        run _pk "package_project='$_value'
                 resolve_arguments
                 has_errors && echo HAS_ERRORS || echo NO_ERRORS"
        assert_output --partial "HAS_ERRORS"
    done

    run _pk "package_project=App.slnx
             resolve_arguments"
    assert_output --partial "accepts only project files (*.csproj)"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _pk "get_arguments src/App/App.csproj --build true
             declare -p package_project build"
    assert_success
    assert_output --partial 'declare -rx package_project="src/App/App.csproj"'
    assert_output --partial 'declare -rx build="true"'
}

@test "get_arguments: -h prints the usage and exits 0, even without a project" {
    run _pk "get_arguments -h; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: under 'set -euo pipefail' (as in pack.sh), every invalid value is reported with the usage" {
    run _pk "set -euo pipefail
             get_arguments App.slnx --build yes; echo AFTER"
    assert_failure
    assert_output --partial "accepts only project files (*.csproj)"
    assert_output --partial "The input 'yes' is not a valid boolean."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
