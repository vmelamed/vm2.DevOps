#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for the predicates in scripts/bash/lib/_predicates.tools.sh: the ones that probe external tools (presence,
# version, authentication). The JSON predicates are tested in test_predicates_json.bats.
#
# The is_<tool>_present tests never depend on what is installed on the machine: each one puts a FAKE tool in a
# directory at the head of PATH (shadowing the real one), or runs with a PATH that holds no such tool at all.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir

declare -gx failure
declare -gx err_invalid_arguments
declare -gx err_invalid_path
declare -gx err_argument_value

declare -gx  dotnet_min_version
declare -gx  jq_min_version
declare -gx  git_min_version
declare -gx  gh_min_version

# --- helpers -------------------------------------------------------------------------------------

# Creates an executable fake tool $1 in $BATS_TEST_TMPDIR/bin whose body is $2.
_fake_tool() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\n%s\n' "$2" > "$BATS_TEST_TMPDIR/bin/$1"
    chmod +x "$BATS_TEST_TMPDIR/bin/$1"
}

# Runs "${@:2}" with PATH replaced by $1 for the duration of the call only (a local PATH also resets bash's command
# hash table, so no lookup cached from the outer PATH can leak in).
_with_path() {
    local PATH=$1
    shift
    "$@"
}

# Runs "$@" with the fake tools in $BATS_TEST_TMPDIR/bin shadowing the real ones.
_with_fakes() {
    _with_path "$BATS_TEST_TMPDIR/bin:$PATH" "$@"
}

# Runs "$@" with a PATH that contains no tools at all.
_without_tools() {
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    _with_path "$BATS_TEST_TMPDIR/empty" "$@"
}

# --- is_tool_present -----------------------------------------------------------------------------

@test "is_tool_present: true for a tool on PATH, false for one that isn't" {
    run is_tool_present bash
    assert_success
    run is_tool_present definitely-not-a-real-tool-xyz
    assert_failure "$failure"
}

@test "is_tool_present: bug-exits with the wrong argument count" {
    run is_tool_present
    assert_failure "$err_invalid_arguments"
}

@test "is_tool_present: true for an executable in a directory on PATH that is not on the system default PATH" {
    # e.g. bencher in ~/.cargo/bin, dotnet in ~/.dotnet: 'command -v -p' would miss these
    _fake_tool fake-tool ''

    run _with_fakes is_tool_present fake-tool
    assert_success
}

@test "is_tool_present: false for a standard tool (in /usr/bin) when it is not on PATH" {
    # Regression: 'command -v -p' searched the system default PATH, so it reported a tool the script could not run
    run _without_tools is_tool_present ls
    assert_failure "$failure"
}

@test "is_tool_present: true for a shell function (the way some test doubles fake a tool)" {
    fake-function-tool() { :; }

    run is_tool_present fake-function-tool
    assert_success
}

# --- verify_git ------------------------------------------------------------------------------

# A fake git that answers its version query (both '-v' and '--version', so the tests do not pin which one the predicate
# uses) with "git version $1" plus the optional suffix $2, and fails everything else.
_fake_git() {
    _fake_tool git "[[ \$1 == -v || \$1 == --version ]] && { echo 'git version $1${2:+ $2}'; exit 0; }; exit 99"
}

@test "verify_git: true when git reports exactly the minimum version" {
    _fake_git "$git_min_version"

    run _with_fakes verify_git
    assert_success
    assert_output ''
}

@test "verify_git: true when git reports a newer version than the minimum" {
    _fake_git 99.0.0

    run _with_fakes verify_git
    assert_success
}

@test "verify_git: true for the macOS form of the version ('git version 99.0.0 (Apple Git-154)')" {
    _fake_git 99.0.0 '(Apple Git-154)'

    run _with_fakes verify_git
    assert_success
}

@test "verify_git: false, with an upgrade hint, when git reports an older version than the minimum" {
    _fake_git 2.0.0

    run _with_fakes verify_git
    assert_failure "$failure"
    assert_output --partial "Invalid 'git' version '2.0.0': use '$git_min_version' or greater."
}

@test "verify_git: false, with an upgrade hint, when the version query itself fails (e.g. an old git without '-v')" {
    _fake_tool git 'echo "unknown option: -v" >&2; exit 129'

    run _with_fakes verify_git
    assert_failure "$failure"
    assert_output --partial "Invalid 'git' version '': use '$git_min_version' or greater."
}

@test "verify_git: false, with an install hint, when git is not on PATH (and never checks the version)" {
    run _without_tools verify_git
    assert_failure "$failure"
    assert_output --partial "'git' is not installed"
    refute_output --partial "'git' version"
}

# --- verify_gh -------------------------------------------------------------------------------

# A fake gh. Its version query ('gh version' or 'gh --version', so the tests do not pin which one the predicate uses)
# prints gh's real two-line format, with the first line in the Debian package's form:
#     gh version <v> (2026-01-01 Debian <debian-v>-3)
#     https://github.com/cli/cli/releases/tag/v<v>
# i.e. the version appears three times, on two lines. <v> is $2 (default: $gh_min_version), <debian-v> is $3 (default:
# <v>). 'gh auth status' runs the body $1. Every other call fails.
_fake_gh() {
    local _v=${2:-$gh_min_version}
    local _debian_v=${3:-$_v}
    _fake_tool gh "[[ \$1 == version || \$1 == --version ]] && { printf 'gh version %s (2026-01-01 Debian %s-3)\\nhttps://github.com/cli/cli/releases/tag/v%s\\n' '$_v' '$_debian_v' '$_v'; exit 0; }
[[ \"\$*\" == 'auth status' ]] && { $1; }
exit 99"
}

@test "verify_gh: true when gh reports exactly the minimum version and is authenticated" {
    _fake_gh 'exit 0'

    run _with_fakes verify_gh
    assert_success
    assert_output ''
}

@test "verify_gh: true when gh reports a newer version than the minimum" {
    _fake_gh 'exit 0' 99.0.0

    run _with_fakes verify_gh
    assert_success
}

@test "verify_gh: takes the FIRST version in the output, not any other one on the same line or the next" {
    # Regression: 'head -n1 | grep -o' still returned two versions from the Debian form of the first line. Here the
    # later occurrence is older than the minimum, so taking it -- or passing all of them on -- fails the check.
    _fake_gh 'exit 0' 99.0.0 1.0.0

    run _with_fakes verify_gh
    assert_success
}

@test "verify_gh: false, with an upgrade hint, when gh reports an older version (and never asks for the auth status)" {
    _fake_gh 'echo AUTH-STATUS-CALLED >&2; exit 0' 2.0.0

    run _with_fakes verify_gh
    assert_failure "$failure"
    assert_output --partial "Invalid 'gh' version '2.0.0': use '$gh_min_version' or greater."
    refute_output --partial "AUTH-STATUS-CALLED"
}

@test "verify_gh: false, with an upgrade hint, when the version query itself fails" {
    _fake_tool gh 'exit 1'

    run _with_fakes verify_gh
    assert_failure "$failure"
    # with pipefail the failed 'gh --version' fails the capture; without it, the empty version fails the release check
    assert_output --regexp "Failed to get the version of 'gh'\\.|Invalid 'gh' version '': use a release version\\."
}

@test "verify_gh: false, with a login hint, when gh is recent enough but not authenticated" {
    _fake_gh 'exit 1'

    run _with_fakes verify_gh
    assert_failure "$failure"
    assert_output --partial "'gh' is not authenticated"
}

@test "verify_gh: false, with an install hint, when gh is not on PATH (and never checks the version or the auth status)" {
    run _without_tools verify_gh
    assert_failure "$failure"
    assert_output --partial "'gh' is not installed"
    refute_output --partial "'gh' version"
    refute_output --partial "not authenticated"
}

# --- verify_jq -------------------------------------------------------------------------------

@test "verify_jq: true for jq 1.8.x" {
    _fake_tool jq 'echo jq-1.8.1'

    run _with_fakes verify_jq
    assert_success
}

@test "verify_jq: true for jq newer than 1.8 (1.9, 2.0)" {
    # Regression: the version check was the regex 'jq-1\.8\.[0-9]+', which rejected every later release
    _fake_tool jq 'echo jq-1.9.0'
    run _with_fakes verify_jq
    assert_success

    _fake_tool jq 'echo jq-2.0.0'
    run _with_fakes verify_jq
    assert_success
}

@test "verify_jq: false, with an upgrade hint, for jq older than 1.8" {
    _fake_tool jq 'echo jq-1.7.1'

    run _with_fakes verify_jq
    assert_failure "$failure"
    assert_output --partial "Invalid 'jq' version '1.7.1': use '$jq_min_version' or greater."
}

@test "verify_jq: false, with an install hint, when jq is not on PATH (and never checks the version)" {
    run _without_tools verify_jq
    assert_failure "$failure"
    assert_output --partial "'jq' is not installed"
    refute_output --partial "Invalid 'jq' version"
}

# --- verify_yq -------------------------------------------------------------------------------

@test "verify_yq: true for Mike Farah's yq" {
    _fake_tool yq 'echo "yq (https://github.com/mikefarah/yq/) version v4.53.6"'

    run _with_fakes verify_yq
    assert_success
}

@test "verify_yq: false, with a pointer to Mike Farah's yq, for a different yq (e.g. the Python one)" {
    _fake_tool yq 'echo "yq 3.4.3"'

    run _with_fakes verify_yq
    assert_failure "$failure"
    assert_output --partial "it is not Mike Farah's 'yq'."
}

@test "verify_yq: false, with an install hint, when yq is not on PATH (and never checks the flavor)" {
    run _without_tools verify_yq
    assert_failure "$failure"
    assert_output --partial "'yq' is not installed"
    refute_output --partial "it is not Mike Farah's 'yq'."
}

# --- verify_dotnet ---------------------------------------------------------------------------

@test "verify_dotnet: true when dotnet reports exactly the minimum version" {
    _fake_tool dotnet "echo $dotnet_min_version"

    run _with_fakes verify_dotnet
    assert_success
    assert_output ''
}

@test "verify_dotnet: true when dotnet reports a newer major version than the minimum" {
    _fake_tool dotnet 'echo 99.0.100'

    run _with_fakes verify_dotnet
    assert_success
}

@test "verify_dotnet: false when 'dotnet --version' itself fails (e.g. global.json pins an SDK that is not installed)" {
    _fake_tool dotnet 'echo "A compatible .NET SDK was not found." >&2; exit 145'

    run _with_fakes verify_dotnet
    assert_failure "$failure"
    assert_output --partial "Failed to find the .NET SDK that this directory requires."
}

@test "verify_dotnet: false, with an install hint, when dotnet is not on PATH (and never checks the version)" {
    run _without_tools verify_dotnet
    assert_failure "$failure"
    assert_output --partial "'dotnet' is not installed"
    refute_output --partial "requires 'dotnet' version"
}
