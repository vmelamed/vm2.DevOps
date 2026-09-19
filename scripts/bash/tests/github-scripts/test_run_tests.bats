#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/run-tests.sh, as it behaves TODAY.
#
# run-tests.sh is designed to run identically standalone and in GitHub Actions (it sources
# gh_core.sh) -- these tests exercise both: the CI branch (CI=true, skips reportgenerator,
# writes GITHUB_OUTPUT) and the local branch (reportgenerator faked, since installing/running
# the real tool is not run-tests.sh's own logic to characterize).
#
# Real `dotnet`, the actual test executable, and `reportgenerator` are all faked:
#   - fake `dotnet` logs every invocation to $DOTNET_CALL_LOG; its `msbuild -getProperty:
#     TargetPath` case (used by get_target_path) prints $FAKE_TARGET_PATH, so the test controls
#     exactly which "already built" executable run-tests.sh will look for.
#   - the fake test executable ($FAKE_TARGET_PATH itself, a plain script -- not a .dll run
#     through `dotnet`) logs its invocation and, unless $FAKE_TEST_EXIT is non-zero, writes a
#     dummy coverage file at the path given via --coverage-output.
#   - fake `reportgenerator` writes dummy Summary.txt/SummaryGithub.md files under -targetdir:.
#
# get_artifacts_path/root_working_tree need a real Git working tree, and testconfig.json /
# coverage.settings.xml are looked up at the repo root, so every fixture is a real (local-only)
# git repo with those two files pre-created.
#
# The test project is deliberately named 'App.Tests.csproj' (17 characters) -- this used to
# fail is_valid_path's `pathchk -p` (POSIX's 14-char-per-component "portable filename" rule,
# fixed in _predicates.sh) exactly like the real vm2.*.Tests.csproj files did; keeping this
# realistic name here guards against that regressing.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_run_tests="$_gh_scripts_dir/run-tests.sh"

_install_fake_dotnet() {
    local _dir="$1/fakebin"
    mkdir -p "$_dir"
    cat > "$_dir/dotnet" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$DOTNET_CALL_LOG"
case "$1" in
    nuget)   exit "${FAKE_DOTNET_NUGET_EXIT:-0}" ;;
    clean)   exit "${FAKE_DOTNET_CLEAN_EXIT:-0}" ;;
    restore) exit "${FAKE_DOTNET_RESTORE_EXIT:-0}" ;;
    tool)    exit 0 ;;
    build)
        echo "Build succeeded."
        exit "${FAKE_DOTNET_BUILD_EXIT:-0}"
        ;;
    msbuild)
        echo "$FAKE_TARGET_PATH"
        exit 0
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$_dir/dotnet"

    cat > "$_dir/reportgenerator" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$REPORTGEN_CALL_LOG"
_targetdir=""
for a in "$@"; do
    [[ "$a" == -targetdir:* ]] && _targetdir="${a#-targetdir:}"
done
if [[ -n "$_targetdir" ]]; then
    mkdir -p "$_targetdir"
    echo "Line coverage: 100%" > "$_targetdir/Summary.txt"
    echo "# Coverage" > "$_targetdir/SummaryGithub.md"
fi
exit 0
EOF
    chmod +x "$_dir/reportgenerator"
}

# Installs the fake "already built" test executable and points $FAKE_TARGET_PATH at it.
_install_fake_test_exec() {
    local _path="$1"
    mkdir -p "$(dirname "$_path")"
    cat > "$_path" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$TEST_EXEC_CALL_LOG"
_cov="" _prev=""
for a in "$@"; do
    [[ "$_prev" == "--coverage-output" ]] && _cov="$a"
    _prev="$a"
done
if [[ -n "$_cov" && "${FAKE_TEST_EXIT:-0}" == "0" ]]; then
    mkdir -p "$(dirname "$_cov")"
    printf '<coverage/>' > "$_cov"
fi
exit "${FAKE_TEST_EXIT:-0}"
EOF
    chmod +x "$_path"
}

_make_repo_with_test_project() {
    local _dir="$1"
    mkdir -p "$_dir/tests/App.Tests"
    git -C "$_dir" init --quiet
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo '{}' > "$_dir/testconfig.json"
    echo '<Settings/>' > "$_dir/coverage.settings.xml"
    echo '<Project />' > "$_dir/tests/App.Tests/App.Tests.csproj"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "init"
}

# $1 = repo dir, $2 = env-var assignments to prepend, $@ (rest) = CLI arguments. Sets up
# $FAKE_TARGET_PATH to the fake, already-built test executable unless the caller's $2 overrides
# FAKE_TARGET_PATH itself.
_run_run_tests() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="$_dir/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$_dir/dotnet.log" TEST_EXEC_CALL_LOG="$_dir/testexec.log" REPORTGEN_CALL_LOG="$_dir/reportgen.log" \
        FAKE_TARGET_PATH="$_dir/testexec.sh" \
        bash -c "
            cd '$_dir' && $_env_vars bash '$_run_tests' $*
        "
}

# --- happy path ---------------------------------------------------------------------------

@test "run-tests: in CI mode, runs the tests, reports success, and writes coverage outputs" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_test_exec "$BATS_TEST_TMPDIR/repo/testexec.sh"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" 'CI=true' tests/App.Tests/App.Tests.csproj
    assert_success
    assert_output --partial "coverage-files="
    assert_output --partial "coverage-reports-dir="
}

@test "run-tests: locally (non-CI), generates and prints a coverage report via reportgenerator" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_test_exec "$BATS_TEST_TMPDIR/repo/testexec.sh"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' --quiet tests/App.Tests/App.Tests.csproj
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/reportgen.log"
    assert_output --partial "-reports:"
    assert_output --partial "minimumCoverageThresholds:lineCoverage=80"
}

@test "run-tests: an already-existing, non-empty results directory is cleared before running (--quiet auto-picks delete)" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_test_exec "$BATS_TEST_TMPDIR/repo/testexec.sh"
    mkdir -p "$BATS_TEST_TMPDIR/repo/artifacts/tests/App.Tests"
    touch "$BATS_TEST_TMPDIR/repo/artifacts/tests/App.Tests/stale.txt"

    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' --quiet tests/App.Tests/App.Tests.csproj
    assert_success
    [[ ! -e "$BATS_TEST_TMPDIR/repo/artifacts/tests/App.Tests/stale.txt" ]]
}

# --- validation failures ---------------------------------------------------------------------

@test "run-tests: rejects a non-.csproj test project (e.g. a solution or unrelated file)" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' testconfig.json
    assert_failure
    assert_output --partial "accepts only project files (*.csproj)"
}

@test "run-tests: rejects a test project path that does not exist" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' tests/App.Tests/DoesNotExist.csproj
    assert_failure
}

@test "run-tests: rejects an out-of-range --min-coverage-pct" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' --min-coverage-pct 150 tests/App.Tests/App.Tests.csproj
    assert_failure
}

@test "run-tests: reports both a missing testconfig.json and a missing coverage.settings.xml together" {
    mkdir -p "$BATS_TEST_TMPDIR/repo/tests/App.Tests"
    git -C "$BATS_TEST_TMPDIR/repo" init --quiet
    git -C "$BATS_TEST_TMPDIR/repo" config user.email "test@test.local"
    git -C "$BATS_TEST_TMPDIR/repo" config user.name "test"
    echo '<Project />' > "$BATS_TEST_TMPDIR/repo/tests/App.Tests/App.Tests.csproj"
    git -C "$BATS_TEST_TMPDIR/repo" add -A
    git -C "$BATS_TEST_TMPDIR/repo" commit --quiet -m "init"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"

    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' tests/App.Tests/App.Tests.csproj
    assert_failure
    assert_output --partial "Test config file not found"
    assert_output --partial "Coverage settings file not found"
}

# --- rebuild-if-missing ----------------------------------------------------------------------

@test "run-tests: rebuilds the test project when its executable is missing, and reports if it is still not found" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    # deliberately do NOT install the fake test executable -- FAKE_TARGET_PATH points nowhere
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/repo/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$BATS_TEST_TMPDIR/repo/dotnet.log" \
        FAKE_TARGET_PATH="$BATS_TEST_TMPDIR/repo/does-not-exist/App.Tests.dll" \
        CI=true \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_run_tests' --quiet tests/App.Tests/App.Tests.csproj"
    assert_failure
    assert_output --partial "Rebuilding the test project"
    assert_output --partial "still NOT FOUND"

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    assert_output --partial "clean tests/App.Tests/App.Tests.csproj"
    assert_output --partial "restore tests/App.Tests/App.Tests.csproj"
    assert_output --partial "build tests/App.Tests/App.Tests.csproj"
}

# --- test/coverage failures ------------------------------------------------------------------

@test "run-tests: reports a failed test run" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_test_exec "$BATS_TEST_TMPDIR/repo/testexec.sh"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" 'CI=true FAKE_TEST_EXIT=1' tests/App.Tests/App.Tests.csproj
    assert_failure
    assert_output --partial "Tests failed in project"
}

@test "run-tests: reports a missing coverage file even when the test run itself succeeds" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    # a test executable that exits 0 but never writes a coverage file
    cat > "$BATS_TEST_TMPDIR/repo/testexec.sh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$TEST_EXEC_CALL_LOG"
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/repo/testexec.sh"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" 'CI=true' tests/App.Tests/App.Tests.csproj
    assert_failure
    assert_output --partial "Coverage file"
    assert_output --partial "not found or is empty"
}

# --- argument handling ---------------------------------------------------------------------

@test "run-tests: fails when more than one test project is given" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' tests/App.Tests/App.Tests.csproj Other.csproj
    assert_failure
    assert_output --partial "Multiple test projects specified"
}

@test "run-tests: fails on an unknown option" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' --bogus
    assert_failure
    assert_output --partial "Unknown option: --bogus"
}

@test "run-tests: -h prints usage and exits 0" {
    _make_repo_with_test_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_tests "$BATS_TEST_TMPDIR/repo" '' -h
    assert_success
    assert_output --partial "Usage:"
}
