#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/run-benchmarks.sh, as it behaves TODAY.
#
# run-benchmarks.sh is designed to run identically standalone and in GitHub Actions (it sources
# gh_core.sh) -- these tests run it the same way in both "modes", with one test explicitly
# setting the CI variables to confirm the summary/output land there too.
#
# Real `dotnet` and the actual BenchmarkDotNet executable are both faked:
#   - fake `dotnet` logs every invocation to $DOTNET_CALL_LOG; its `msbuild -getProperty:
#     TargetPath` case (used by get_target_path) prints $FAKE_TARGET_PATH.
#   - the fake benchmark executable ($FAKE_TARGET_PATH itself, a plain script -- not a .dll run
#     through `dotnet`) logs its invocation and, unless $FAKE_BM_EXIT is non-zero, writes the
#     two report files (*-report-full-compressed.json, *-report-github.md) BenchmarkDotNet would
#     produce under "<--artifacts value>/results/".
#
# get_artifacts_path/root_working_tree need a real Git working tree, so every fixture is a real
# (local-only) git repo.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_run_benchmarks="$_gh_scripts_dir/run-benchmarks.sh"

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
}

# Installs the fake "already built" benchmark executable and points it at $_path.
_install_fake_benchmark_exec() {
    local _path="$1"
    mkdir -p "$(dirname "$_path")"
    cat > "$_path" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$BM_EXEC_CALL_LOG"
if [[ "${FAKE_BM_EXIT:-0}" == "0" ]]; then
    _artifacts="" _prev=""
    for a in "$@"; do
        [[ "$_prev" == "--artifacts" ]] && _artifacts="$a"
        _prev="$a"
    done
    if [[ -n "$_artifacts" ]]; then
        mkdir -p "$_artifacts/results"
        echo '{}' > "$_artifacts/results/App.Benchmarks-report-full-compressed.json"
        echo '# Results' > "$_artifacts/results/App.Benchmarks-report-github.md"
    fi
fi
exit "${FAKE_BM_EXIT:-0}"
EOF
    chmod +x "$_path"
}

_make_repo_with_benchmark_project() {
    local _dir="$1"
    mkdir -p "$_dir/benchmarks/App.Benchmarks"
    git -C "$_dir" init --quiet
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo '<Project />' > "$_dir/benchmarks/App.Benchmarks/App.Benchmarks.csproj"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "init"
}

# $1 = repo dir, $2 = env-var assignments to prepend, $@ (rest) = CLI arguments. Points
# $FAKE_TARGET_PATH at the fake, already-built benchmark executable unless $2 overrides it.
_run_run_benchmarks() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="$_dir/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$_dir/dotnet.log" BM_EXEC_CALL_LOG="$_dir/bmexec.log" \
        FAKE_TARGET_PATH="$_dir/bmexec.sh" \
        bash -c "
            cd '$_dir' && $_env_vars bash '$_run_benchmarks' $*
        "
}

# --- happy path ---------------------------------------------------------------------------

@test "run-benchmarks: in CI mode, runs the benchmarks and reports the JSON/markdown results" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_benchmark_exec "$BATS_TEST_TMPDIR/repo/bmexec.sh"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" 'CI=true' benchmarks/App.Benchmarks/App.Benchmarks.csproj
    assert_success
    assert_output --partial "Benchmark tests completed successfully"
    assert_output --partial "App.Benchmarks-report-full-compressed.json"
    assert_output --partial "results-dir="
}

@test "run-benchmarks: locally (non-CI), also runs successfully" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_benchmark_exec "$BATS_TEST_TMPDIR/repo/bmexec.sh"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" '' --quiet benchmarks/App.Benchmarks/App.Benchmarks.csproj
    assert_success
    assert_output --partial "Benchmark tests completed successfully"
}

@test "run-benchmarks: an already-existing, non-empty results directory is cleared before running (--quiet auto-picks delete)" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_benchmark_exec "$BATS_TEST_TMPDIR/repo/bmexec.sh"
    mkdir -p "$BATS_TEST_TMPDIR/repo/artifacts/benchmarks"
    touch "$BATS_TEST_TMPDIR/repo/artifacts/benchmarks/stale.txt"

    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" '' --quiet benchmarks/App.Benchmarks/App.Benchmarks.csproj
    assert_success
    [[ ! -e "$BATS_TEST_TMPDIR/repo/artifacts/benchmarks/stale.txt" ]]
}

# --- validation failures ---------------------------------------------------------------------

@test "run-benchmarks: rejects a benchmark project path that does not exist" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" '' does-not-exist.csproj
    assert_failure
}

@test "run-benchmarks: rejects a non-.csproj benchmark project (e.g. a solution)" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    touch "$BATS_TEST_TMPDIR/repo/App.sln"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" '' App.sln
    assert_failure
    assert_output --partial "accepts only project files (*.csproj)"
}

# --- rebuild-if-missing ----------------------------------------------------------------------

@test "run-benchmarks: rebuilds the project when its executable is missing, and reports if it is still not found" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    # deliberately do NOT install the fake benchmark executable -- FAKE_TARGET_PATH points nowhere
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/repo/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$BATS_TEST_TMPDIR/repo/dotnet.log" \
        FAKE_TARGET_PATH="$BATS_TEST_TMPDIR/repo/does-not-exist/App.Benchmarks.dll" \
        CI=true \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_run_benchmarks' --quiet benchmarks/App.Benchmarks/App.Benchmarks.csproj"
    assert_failure
    assert_output --partial "Rebuilding the benchmarks project"
    assert_output --partial "still NOT FOUND"

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    assert_output --partial "clean benchmarks/App.Benchmarks/App.Benchmarks.csproj"
    assert_output --partial "restore benchmarks/App.Benchmarks/App.Benchmarks.csproj"
    assert_output --partial "build benchmarks/App.Benchmarks/App.Benchmarks.csproj"
}

# --- run/report failures -----------------------------------------------------------------

@test "run-benchmarks: reports a failed benchmark run" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_benchmark_exec "$BATS_TEST_TMPDIR/repo/bmexec.sh"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" 'CI=true FAKE_BM_EXIT=1' benchmarks/App.Benchmarks/App.Benchmarks.csproj
    assert_failure
    assert_output --partial "Tests failed in project"
}

@test "run-benchmarks: reports missing JSON reports even when the run itself succeeds" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    # a benchmark executable that exits 0 but never writes any report files
    cat > "$BATS_TEST_TMPDIR/repo/bmexec.sh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$BM_EXEC_CALL_LOG"
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/repo/bmexec.sh"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" 'CI=true' benchmarks/App.Benchmarks/App.Benchmarks.csproj
    assert_failure
    assert_output --partial "No JSON benchmark reports found"
}

# --- argument handling ---------------------------------------------------------------------

@test "run-benchmarks: fails when more than one benchmark project is given" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" '' benchmarks/App.Benchmarks/App.Benchmarks.csproj Other.csproj
    assert_failure
    assert_output --partial "Multiple benchmark projects specified"
}

@test "run-benchmarks: fails on an unknown option" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" '' --bogus
    assert_failure
    assert_output --partial "Unknown option: --bogus"
}

@test "run-benchmarks: -h prints usage and exits 0" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_run_benchmarks "$BATS_TEST_TMPDIR/repo" '' -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "run-benchmarks: in CI mode, the summary and outputs also land in the step summary and GITHUB_OUTPUT files" {
    _make_repo_with_benchmark_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    _install_fake_benchmark_exec "$BATS_TEST_TMPDIR/repo/bmexec.sh"
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/repo/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$BATS_TEST_TMPDIR/repo/dotnet.log" BM_EXEC_CALL_LOG="$BATS_TEST_TMPDIR/repo/bmexec.log" \
        FAKE_TARGET_PATH="$BATS_TEST_TMPDIR/repo/bmexec.sh" \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output.txt" \
        CI=true \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_run_benchmarks' --quiet benchmarks/App.Benchmarks/App.Benchmarks.csproj"
    assert_success

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "Benchmark tests completed successfully"
    assert_output --partial "# Results"

    run cat "$BATS_TEST_TMPDIR/output.txt"
    assert_output --partial "results-dir="
}
