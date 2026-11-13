#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for the predicates in scripts/bash/lib/_predicates_tools.sh: the ones that probe external tools (presence,
# version, authentication) or delegate to one (jq for JSON validation).
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

declare -gxi failure
declare -gxi err_invalid_arguments
declare -gxi err_invalid_path
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

# --- is_git_present ------------------------------------------------------------------------------

# A fake git that answers its version query (both '-v' and '--version', so the tests do not pin which one the predicate
# uses) with "git version $1" plus the optional suffix $2, and fails everything else.
_fake_git() {
    _fake_tool git "[[ \$1 == -v || \$1 == --version ]] && { echo 'git version $1${2:+ $2}'; exit 0; }; exit 99"
}

@test "is_git_present: true when git reports exactly the minimum version" {
    _fake_git "$git_min_version"

    run _with_fakes is_git_present
    assert_success
    assert_output ''
}

@test "is_git_present: true when git reports a newer version than the minimum" {
    _fake_git 99.0.0

    run _with_fakes is_git_present
    assert_success
}

@test "is_git_present: true for the macOS form of the version ('git version 99.0.0 (Apple Git-154)')" {
    _fake_git 99.0.0 '(Apple Git-154)'

    run _with_fakes is_git_present
    assert_success
}

@test "is_git_present: false, with an upgrade hint, when git reports an older version than the minimum" {
    _fake_git 2.0.0

    run _with_fakes is_git_present
    assert_failure "$failure"
    assert_output --partial "'git' version $git_min_version or greater is required."
}

@test "is_git_present: false, with an upgrade hint, when the version query itself fails (e.g. an old git without '-v')" {
    _fake_tool git 'echo "unknown option: -v" >&2; exit 129'

    run _with_fakes is_git_present
    assert_failure "$failure"
    assert_output --partial "'git' version $git_min_version or greater is required."
}

@test "is_git_present: false, with an install hint, when git is not on PATH (and never checks the version)" {
    run _without_tools is_git_present
    assert_failure "$failure"
    assert_output --partial "'git' is not installed"
    refute_output --partial "'git' version"
}

# --- is_gh_present -------------------------------------------------------------------------------

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

@test "is_gh_present: true when gh reports exactly the minimum version and is authenticated" {
    _fake_gh 'exit 0'

    run _with_fakes is_gh_present
    assert_success
    assert_output ''
}

@test "is_gh_present: true when gh reports a newer version than the minimum" {
    _fake_gh 'exit 0' 99.0.0

    run _with_fakes is_gh_present
    assert_success
}

@test "is_gh_present: takes the FIRST version in the output, not any other one on the same line or the next" {
    # Regression: 'head -n1 | grep -o' still returned two versions from the Debian form of the first line. Here the
    # later occurrence is older than the minimum, so taking it -- or passing all of them on -- fails the check.
    _fake_gh 'exit 0' 99.0.0 1.0.0

    run _with_fakes is_gh_present
    assert_success
}

@test "is_gh_present: false, with an upgrade hint, when gh reports an older version (and never asks for the auth status)" {
    _fake_gh 'echo AUTH-STATUS-CALLED >&2; exit 0' 2.0.0

    run _with_fakes is_gh_present
    assert_failure "$failure"
    assert_output --partial "'gh' version $gh_min_version or greater is required."
    refute_output --partial "AUTH-STATUS-CALLED"
}

@test "is_gh_present: false, with an upgrade hint, when the version query itself fails" {
    _fake_tool gh 'exit 1'

    run _with_fakes is_gh_present
    assert_failure "$failure"
    assert_output --partial "'gh' version $gh_min_version or greater is required."
}

@test "is_gh_present: false, with a login hint, when gh is recent enough but not authenticated" {
    _fake_gh 'exit 1'

    run _with_fakes is_gh_present
    assert_failure "$failure"
    assert_output --partial "'gh' is not authenticated"
}

@test "is_gh_present: false, with an install hint, when gh is not on PATH (and never checks the version or the auth status)" {
    run _without_tools is_gh_present
    assert_failure "$failure"
    assert_output --partial "'gh' is not installed"
    refute_output --partial "'gh' version"
    refute_output --partial "not authenticated"
}

# --- is_jq_present -------------------------------------------------------------------------------

@test "is_jq_present: true for jq 1.8.x" {
    _fake_tool jq 'echo jq-1.8.1'

    run _with_fakes is_jq_present
    assert_success
}

@test "is_jq_present: true for jq newer than 1.8 (1.9, 2.0)" {
    # Regression: the version check was the regex 'jq-1\.8\.[0-9]+', which rejected every later release
    _fake_tool jq 'echo jq-1.9.0'
    run _with_fakes is_jq_present
    assert_success

    _fake_tool jq 'echo jq-2.0.0'
    run _with_fakes is_jq_present
    assert_success
}

@test "is_jq_present: false, with an upgrade hint, for jq older than 1.8" {
    _fake_tool jq 'echo jq-1.7.1'

    run _with_fakes is_jq_present
    assert_failure "$failure"
    assert_output --partial "'jq' version $jq_min_version or greater is required."
}

@test "is_jq_present: false, with an install hint, when jq is not on PATH (and never checks the version)" {
    run _without_tools is_jq_present
    assert_failure "$failure"
    assert_output --partial "'jq' is not installed"
    refute_output --partial "'jq' version $jq_min_version or greater is required."
}

# --- is_yq_present -------------------------------------------------------------------------------

@test "is_yq_present: true for Mike Farah's yq" {
    _fake_tool yq 'echo "yq (https://github.com/mikefarah/yq/) version v4.53.6"'

    run _with_fakes is_yq_present
    assert_success
}

@test "is_yq_present: false, with a pointer to Mike Farah's yq, for a different yq (e.g. the Python one)" {
    _fake_tool yq 'echo "yq 3.4.3"'

    run _with_fakes is_yq_present
    assert_failure "$failure"
    assert_output --partial "requires 'yq' by Mike Farah"
}

@test "is_yq_present: false, with an install hint, when yq is not on PATH (and never checks the flavor)" {
    run _without_tools is_yq_present
    assert_failure "$failure"
    assert_output --partial "'yq' is not installed"
    refute_output --partial "requires 'yq' by Mike Farah"
}

# --- is_dotnet_present ---------------------------------------------------------------------------

@test "is_dotnet_present: true when dotnet reports exactly the minimum version" {
    _fake_tool dotnet "echo $dotnet_min_version"

    run _with_fakes is_dotnet_present
    assert_success
    assert_output ''
}

@test "is_dotnet_present: true when dotnet reports a newer major version than the minimum" {
    _fake_tool dotnet 'echo 99.0.100'

    run _with_fakes is_dotnet_present
    assert_success
}

@test "is_dotnet_present: false, with an upgrade hint, when dotnet reports an older version than the minimum" {
    _fake_tool dotnet 'echo 1.0.100'

    run _with_fakes is_dotnet_present
    assert_failure "$failure"
    assert_output --partial "requires 'dotnet' version $dotnet_min_version"
}

@test "is_dotnet_present: false when 'dotnet --version' itself fails (e.g. global.json pins an SDK that is not installed)" {
    _fake_tool dotnet 'echo "A compatible .NET SDK was not found." >&2; exit 145'

    run _with_fakes is_dotnet_present
    assert_failure "$failure"
    assert_output --partial "requires 'dotnet' version $dotnet_min_version"
}

@test "is_dotnet_present: false, with an install hint, when dotnet is not on PATH (and never checks the version)" {
    run _without_tools is_dotnet_present
    assert_failure "$failure"
    assert_output --partial "'dotnet' is not installed"
    refute_output --partial "requires 'dotnet' version"
}

# --- is_valid_json / is_valid_json_file ----------------------------------------------------------

@test "is_valid_json: accepts a well-formed JSON string, rejects garbage" {
    run is_valid_json '{"a":1}'
    assert_success
    run is_valid_json 'not json'
    assert_failure "$failure"
}

@test "is_valid_json: bug-exits with the wrong argument count" {
    run is_valid_json
    assert_failure "$err_invalid_arguments"
}

@test "is_valid_json_file: accepts a file with well-formed JSON, rejects one with malformed JSON" {
    echo '{"a":1}' > "$BATS_TEST_TMPDIR/valid.json"
    echo 'not json' > "$BATS_TEST_TMPDIR/invalid.json"
    run is_valid_json_file "$BATS_TEST_TMPDIR/valid.json"
    assert_success
    run is_valid_json_file "$BATS_TEST_TMPDIR/invalid.json"
    assert_failure "$failure"
}

@test "is_valid_json_file: fails for a non-existent file" {
    run is_valid_json_file "$BATS_TEST_TMPDIR/does-not-exist.json"
    assert_failure "$failure"
}

@test "is_valid_json_file: bug-exits on the wrong argument count or an invalid path" {
    run is_valid_json_file
    assert_failure "$err_invalid_arguments"
    run is_valid_json_file ""
    assert_failure "$err_invalid_path"
}
