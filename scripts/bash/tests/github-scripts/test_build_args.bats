#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/build.args.sh (with build.usage.sh), following the seams of the get_arguments() pipeline (see
# scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each test sources gh_core.sh and the
# files under test in a fresh, ambient-environment-free ('env -i') bash subshell, started in $BATS_TEST_TMPDIR/work.
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
_bd() {
    # shellcheck disable=SC2086 # $2 holds zero or more assignments: word splitting is intended
    (cd "$BATS_TEST_TMPDIR/work" && env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:-} bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/build.args.sh'
        source '$_gh_scripts_dir/build.usage.sh'
        sanitize_common_dotnet_args() { echo \"SANITIZE \$1\"; }
        $1
    ")
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/work"
    printf '#!/usr/bin/env bash\n[[ $1 == --version ]] && echo "$dotnet_min_version"\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/dotnet"
    chmod +x "$BATS_TEST_TMPDIR/bin/dotnet"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the build project empty when no arguments are given" {
    run _bd "parse_arguments
             declare -p build_project"
    assert_success
    assert_output --partial 'build_project=""'
}

@test "parse_arguments: the default build project comes from \$BUILD_PROJECT when it is set" {
    run _bd "parse_arguments
             declare -p build_project" "BUILD_PROJECT=App.slnx"
    assert_success
    assert_output --partial 'build_project="App.slnx"'
}

@test "parse_arguments: the positional argument is the build project; the common dotnet options are recorded" {
    run _bd "parse_arguments --define SHORT_RUN App.slnx --configuration Debug
             declare -p build_project preprocessor_symbols configuration"
    assert_success
    assert_output --partial 'build_project="App.slnx"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'
    assert_output --partial 'configuration="Debug"'
}

@test "parse_arguments: a second build project is rejected" {
    run _bd "parse_arguments One.slnx Two.slnx; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Multiple build projects specified: Two.slnx"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the build project" {
    run _bd "parse_arguments --bogus; declare -p build_project"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "build_project="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _bd "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _bd "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when dotnet is present" {
    run _bd "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing dotnet and returns instead of exiting" {
    run _bd "is_tool_present() { [[ \$1 != dotnet ]]; }
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

@test "resolve_arguments: keeps a given build project, sanitizes the common arguments with it, and freezes it" {
    run _bd "build_project=src/App.csproj
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p build_project"
    assert_success
    assert_output --partial "SANITIZE src/App.csproj"
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -r build_project="src/App.csproj"'
}

@test "resolve_arguments: without a build project, prefers a .slnx in the current directory, then a .sln, then a .csproj" {
    touch "$BATS_TEST_TMPDIR/work/App.csproj" "$BATS_TEST_TMPDIR/work/App.sln" "$BATS_TEST_TMPDIR/work/App.slnx"
    run _bd "resolve_arguments; declare -p build_project"
    assert_success
    assert_output --partial 'build_project="./App.slnx"'

    rm "$BATS_TEST_TMPDIR/work/App.slnx"
    run _bd "resolve_arguments; declare -p build_project"
    assert_success
    assert_output --partial 'build_project="./App.sln"'

    rm "$BATS_TEST_TMPDIR/work/App.sln"
    run _bd "resolve_arguments; declare -p build_project"
    assert_success
    assert_output --partial 'build_project="./App.csproj"'
}

@test "resolve_arguments: with several candidates of the same kind, takes the first one and warns" {
    touch "$BATS_TEST_TMPDIR/work/A.slnx" "$BATS_TEST_TMPDIR/work/B.slnx"
    run _bd "resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p build_project"
    assert_success
    assert_output --partial "Multiple projects found"
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'build_project="./A.slnx"'
}

@test "resolve_arguments: reports that no build project was given or found" {
    run _bd "resolve_arguments
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_output --partial "No build project (*.slnx, *.sln, *.csproj) was specified or found in the current directory."
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports an unsafe build project path" {
    run _bd "build_project='../outside/App.slnx'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_output --partial "The path '../outside/App.slnx' contains directory traversal sequences"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    touch "$BATS_TEST_TMPDIR/work/App.slnx"
    run _bd "get_arguments --define SHORT_RUN
             declare -p build_project preprocessor_symbols"
    assert_success
    assert_output --partial 'declare -r build_project="./App.slnx"'
    assert_output --partial 'preprocessor_symbols="SHORT_RUN"'
}

@test "get_arguments: -h prints the usage and exits 0, even with no project to build" {
    run _bd "get_arguments -h; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: no project to build ends the run with the error and the usage" {
    run _bd "get_arguments; echo AFTER"
    assert_failure
    assert_output --partial "No build project (*.slnx, *.sln, *.csproj) was specified or found"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: under 'set -euo pipefail' (as in build.sh), an unsafe path is reported with the usage, not aborted on" {
    # A validation call without '|| true' trips errexit: the run would end at the first failed check, before
    # exit_if_has_errors could report everything and show the usage.
    run _bd "set -euo pipefail
             get_arguments ../outside/App.slnx; echo AFTER"
    assert_failure
    assert_output --partial "contains directory traversal sequences"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
