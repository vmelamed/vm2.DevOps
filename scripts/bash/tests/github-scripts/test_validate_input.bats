#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/validate-input.sh, as it behaves TODAY.
#
# validate-input.sh is designed to run identically standalone and in GitHub Actions (it sources
# gh_core.sh) -- these tests run it the same way in both "modes": every test runs under a clean
# 'env -i HOME="$HOME" PATH=...' (no ambient GITHUB_ACTIONS/GITHUB_STEP_SUMMARY/GITHUB_OUTPUT),
# and one test explicitly sets all three CI variables to confirm the same output also lands
# there.
#
# validate-input.sh's own tool-prerequisite check calls `command -v -p jq`/`command -v -p gh`.
# The `-p` flag makes `command` ignore $PATH entirely and use the shell's compiled-in default
# path (`getconf PATH`, e.g. "/bin:/usr/bin" -- notably NOT /usr/local/bin, where this box's
# real jq/yq actually live). That means ordinary PATH-prepending tricks cannot simulate
# "jq/gh present" or "missing" for this specific check. Instead, every test exports a `command`
# shell function (via `export -f`, which bash subprocesses -- including a plain `bash
# script.sh` child -- import automatically) that intercepts exactly the `-v -p jq`/`-v -p gh`
# forms and falls back to the real builtin (`builtin command "$@"`) for everything else. This
# also sidesteps ever actually invoking apt-get/curl/sudo for real.
#
# All environment variables consumed by validate-input.sh (BUILD_PROJECTS, TEST_PROJECTS, etc.)
# are passed INSIDE the `bash -c` string below, not as a prefix on the bats `run` call --
# `_run_validate_input` starts a fresh process via `env -i`, which would otherwise strip them.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_validate_input="$_gh_scripts_dir/validate-input.sh"

# Intercepts `command -v -p jq` / `command -v -p gh` to report both tools present (at their
# real locations on this box), without ever touching $PATH-based lookup. Everything else falls
# through to the real `command` builtin.
_tools_present_override='
command() {
    if [[ "$*" == "-v -p jq" ]]; then echo /usr/local/bin/jq; return 0; fi
    if [[ "$*" == "-v -p gh" ]]; then echo /usr/bin/gh; return 0; fi
    builtin command "$@"
}
export -f command
'

_make_repo_with_project() {
    local _dir="$1"
    mkdir -p "$_dir/src"
    git -C "$_dir" init --quiet
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo '<Project />' > "$_dir/src/App.csproj"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "init"
}

# $1 = repo dir, $2 = env-var assignments to prepend before invoking the script (e.g.
# "BUILD_PROJECTS='[]' TEST_PROJECTS='[\"a\"]'"), $@ (rest) = CLI arguments.
_run_validate_input() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        $_tools_present_override
        cd '$_dir' && $_env_vars bash '$_validate_input' $*
    "
}

# --- happy path ---------------------------------------------------------------------------

@test "validate-input: succeeds with valid build/test projects and reports success" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'BUILD_PROJECTS="[\"src/App.csproj\"]" TEST_PROJECTS="[\"src/App.csproj\"]"' --quiet
    assert_success
    assert_output --partial "All parameters validated successfully"
}

@test "validate-input: an empty (default) build-projects array succeeds -- does not crash" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" 'TEST_PROJECTS="[\"src/App.csproj\"]"' --quiet
    assert_success
    assert_output --partial "All parameters validated successfully"
    assert_output --partial "build-projects=[]"
}

@test "validate-input: writes every validated value as a key=value pair (kebab-case) to stdout" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'BUILD_PROJECTS="[\"src/App.csproj\"]" TEST_PROJECTS="[\"src/App.csproj\"]"' --quiet
    assert_success
    assert_output --partial 'build-projects=["src/App.csproj"]'
    assert_output --partial 'test-projects=["src/App.csproj"]'
    assert_output --partial 'runners-os=["ubuntu-latest"]'
    assert_output --partial 'min-coverage-pct=80'
    assert_output --partial 'skip-tests=false'
}

@test "validate-input: --build-projects on the command line overrides \$BUILD_PROJECTS" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'BUILD_PROJECTS="[\"src/App.csproj\"]" TEST_PROJECTS="[\"src/App.csproj\"]"' \
        --quiet --build-projects '[]'
    assert_success
    assert_output --partial 'build-projects=[]'
}

# --- validation failures (accumulate-then-gate) -------------------------------------------

@test "validate-input: reports every validation failure together, then fails" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'TEST_PROJECTS="[\"does-not-exist.csproj\"]" RUNNERS_OS="[\"bogus-os\"]" MAX_GEN1_COLLECTS=-5' \
        --quiet
    assert_failure
    assert_output --partial "The path 'does-not-exist.csproj' is not valid"
    assert_output --partial "The runner OS 'bogus-os' is not allowed"
    assert_output --partial "max-gen1-collects must be a non-negative integer"
    assert_output --partial "5 error(s) encountered"
}

@test "validate-input: rejects a non-boolean skip-tests value" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'TEST_PROJECTS="[\"src/App.csproj\"]" SKIP_TESTS=maybe' --quiet
    assert_failure
    assert_output --partial "is not a valid boolean"
}

@test "validate-input: rejects a negative max-gen2-collects value" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'TEST_PROJECTS="[\"src/App.csproj\"]" MAX_GEN2_COLLECTS=-1' --quiet
    assert_failure
    assert_output --partial "max-gen2-collects must be a non-negative integer"
}

# --- out-of-range warnings fall back to defaults, without failing ---------------------------

@test "validate-input: an out-of-range min-coverage-pct warns and falls back to the default, without failing" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'TEST_PROJECTS="[\"src/App.csproj\"]" MIN_COVERAGE_PCT=10' --quiet
    assert_success
    assert_output --partial "min-coverage-pct must be between 50-100"
    assert_output --partial "min-coverage-pct=80"
}

@test "validate-input: an out-of-range max-regression-pct warns and falls back to the default, without failing" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'TEST_PROJECTS="[\"src/App.csproj\"]" MAX_REGRESSION_PCT=99' --quiet
    assert_success
    assert_output --partial "max-regression-pct must be between 0-50"
    assert_output --partial "max-regression-pct=20"
}

# --- tool prerequisites ---------------------------------------------------------------------

@test "validate-input: fails with a clear error when jq cannot be found or installed" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/sudo"
    chmod +x "$BATS_TEST_TMPDIR/bin/sudo"

    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" bash -c "
        command() {
            if [[ \"\$*\" == '-v -p jq' ]]; then return 1; fi
            if [[ \"\$*\" == '-v -p gh' ]]; then echo /usr/bin/gh; return 0; fi
            builtin command \"\$@\"
        }
        export -f command
        cd '$BATS_TEST_TMPDIR/repo' && TEST_PROJECTS='[\"src/App.csproj\"]' bash '$_validate_input' --quiet
    "
    assert_failure
    assert_output --partial "'jq' was not found and could not install it"
}

@test "validate-input: fails with a clear error when gh cannot be found or installed" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/sudo"
    chmod +x "$BATS_TEST_TMPDIR/bin/sudo"

    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" bash -c "
        command() {
            if [[ \"\$*\" == '-v -p jq' ]]; then echo /usr/local/bin/jq; return 0; fi
            if [[ \"\$*\" == '-v -p gh' ]]; then return 1; fi
            builtin command \"\$@\"
        }
        export -f command
        cd '$BATS_TEST_TMPDIR/repo' && TEST_PROJECTS='[\"src/App.csproj\"]' bash '$_validate_input' --quiet
    "
    assert_failure
    assert_output --partial "'gh' was not found and could not install it"
}

# --- argument handling ---------------------------------------------------------------------

@test "validate-input: fails on an unknown option" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'TEST_PROJECTS="[\"src/App.csproj\"]"' --bogus
    assert_failure
    assert_output --partial "Unknown argument: --bogus"
}

@test "validate-input: fails with a clear error when a value-taking option is given without a value" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" \
        'TEST_PROJECTS="[\"src/App.csproj\"]"' --build-projects
    assert_failure
    assert_output --partial "Missing value for --build-projects"
}

@test "validate-input: -h prints usage and exits 0" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run _run_validate_input "$BATS_TEST_TMPDIR/repo" '' -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "validate-input: in CI mode, the same success message and outputs also land in the step summary and GITHUB_OUTPUT files" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    run env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output.txt" \
        bash -c "
            $_tools_present_override
            cd '$BATS_TEST_TMPDIR/repo' && BUILD_PROJECTS='[\"src/App.csproj\"]' TEST_PROJECTS='[\"src/App.csproj\"]' bash '$_validate_input' --quiet
        "
    assert_success
    assert_output --partial "All parameters validated successfully"
    assert_output --partial 'build-projects=["src/App.csproj"]'

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "All parameters validated successfully"

    run cat "$BATS_TEST_TMPDIR/output.txt"
    assert_output --partial 'build-projects=["src/App.csproj"]'
    assert_output --partial 'test-projects=["src/App.csproj"]'
}
