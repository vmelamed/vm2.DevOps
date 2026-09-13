#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/rebuild-bench-history-run.sh, as it behaves TODAY.
#
# Was previously broken (hung forever on the very first loop iteration): line 107 called
# `to_stdout "some message"`, but to_stdout is a pure stdin-consuming filter (per its own doc:
# reads lines from stdin, takes no arguments) -- it ignored the argument and blocked on `read`
# forever, since nothing piped into it and stdin was never closed. Reproduced directly: the
# process sat in state S with an open stdin fd, zero CPU, never returning. Fixed to
# `echo "..." | to_stdout`, matching every other correct use of it in the codebase.
#
# `run-benchmarks.sh` and `bencher` are both faked (this script's own job is orchestrating
# repeated calls to them and interpreting their results, not re-testing run-benchmarks.sh's own
# behavior, already covered by its own test file, or Bencher's CLI). Every test uses a `timeout`
# wrapper as a safety net against any future regression of the exact hang this file exists to
# catch.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_rebuild_run="$_gh_scripts_dir/rebuild-bench-history-run.sh"

_install_fakes() {
    local _dir="$1/fakebin"
    mkdir -p "$_dir"
    cat > "$_dir/run-benchmarks.sh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$RUN_BENCHMARKS_CALL_LOG"
_artifacts="" _prev=""
for a in "$@"; do
    [[ "$_prev" == "--artifacts" ]] && _artifacts="$a"
    _prev="$a"
done
if [[ "${FAKE_RUN_BENCHMARKS_EXIT:-0}" == "0" && -n "$_artifacts" ]]; then
    mkdir -p "$_artifacts/results"
    echo '{}' > "$_artifacts/results/App-report-full-compressed.json"
fi
exit "${FAKE_RUN_BENCHMARKS_EXIT:-0}"
EOF
    chmod +x "$_dir/run-benchmarks.sh"

    cat > "$_dir/bencher" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$BENCHER_CALL_LOG"
exit "${FAKE_BENCHER_EXIT:-0}"
EOF
    chmod +x "$_dir/bencher"
}

_make_benchmark_project() {
    local _dir="$1" _name="${2:-App}"
    mkdir -p "$_dir/benchmarks/$_name"
    echo '<Project />' > "$_dir/benchmarks/$_name/$_name.Benchmarks.csproj"
}

# $1 = repo dir, $2 = env-var assignments to prepend, $@ (rest) = CLI arguments. A 20s timeout
# guards every invocation against the exact hang this file exists to catch.
_run_rebuild() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    timeout 20 env -i HOME="$HOME" PATH="$_dir/fakebin:/usr/local/bin:/usr/bin:/bin" \
        RUN_BENCHMARKS_CALL_LOG="$_dir/rb.log" BENCHER_CALL_LOG="$_dir/bencher.log" bash -c "
            cd '$_dir' && $_env_vars bash '$_rebuild_run' $*
        "
}

# --- happy path ---------------------------------------------------------------------------

@test "rebuild-bench-history-run: records the given project once and reports success (does not hang)" {
    _install_fakes "$BATS_TEST_TMPDIR"
    _make_benchmark_project "$BATS_TEST_TMPDIR"
    run _run_rebuild "$BATS_TEST_TMPDIR" 'BENCHER_API_TOKEN=tok' --quiet --repeat 1 --bencher-project p --bencher-testbed t benchmarks/App/App.Benchmarks.csproj
    assert_success
    assert_output --partial "Recorded data point 1 of 1"
    assert_output --partial "Recorded **1** of **1** runs"
}

@test "rebuild-bench-history-run: auto-discovers every *.csproj under benchmarks/, excluding bin/obj" {
    _install_fakes "$BATS_TEST_TMPDIR"
    _make_benchmark_project "$BATS_TEST_TMPDIR" App1
    _make_benchmark_project "$BATS_TEST_TMPDIR" App2
    mkdir -p "$BATS_TEST_TMPDIR/benchmarks/App2/bin"
    echo '<Project />' > "$BATS_TEST_TMPDIR/benchmarks/App2/bin/Generated.csproj"

    run _run_rebuild "$BATS_TEST_TMPDIR" 'BENCHER_API_TOKEN=tok' --quiet --repeat 1 --bencher-project p --bencher-testbed t
    assert_success

    run cat "$BATS_TEST_TMPDIR/rb.log"
    assert_line --index 0 --partial "benchmarks/App1/App1.Benchmarks.csproj"
    assert_line --index 1 --partial "benchmarks/App2/App2.Benchmarks.csproj"
    refute_output --partial "Generated.csproj"
}

# --- partial failure handling ------------------------------------------------------------

@test "rebuild-bench-history-run: a failed benchmark run is skipped with a warning, not fatal by itself" {
    _install_fakes "$BATS_TEST_TMPDIR"
    _make_benchmark_project "$BATS_TEST_TMPDIR"
    run _run_rebuild "$BATS_TEST_TMPDIR" 'BENCHER_API_TOKEN=tok FAKE_RUN_BENCHMARKS_EXIT=1' --quiet --repeat 1 --bencher-project p --bencher-testbed t
    assert_failure
    assert_output --partial "failed; skipping the Bencher upload"
    assert_output --partial "No data points were recorded to Bencher"
}

@test "rebuild-bench-history-run: fails overall only when NO data points were recorded across all runs" {
    _install_fakes "$BATS_TEST_TMPDIR"
    _make_benchmark_project "$BATS_TEST_TMPDIR"
    # bencher fails on the 1st call, succeeds on the 2nd
    cat > "$BATS_TEST_TMPDIR/fakebin/bencher" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$BENCHER_CALL_LOG"
_n=$(wc -l < "$BENCHER_CALL_LOG")
(( _n == 1 )) && exit 1 || exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/fakebin/bencher"
    run _run_rebuild "$BATS_TEST_TMPDIR" 'BENCHER_API_TOKEN=tok' --quiet --repeat 2 --bencher-project p --bencher-testbed t
    assert_success
    assert_output --partial "Bencher upload failed for run 1"
    assert_output --partial "Recorded data point 2 of 2"
    assert_output --partial "Recorded **1** of **2** runs"
}

# --- validation failures ---------------------------------------------------------------------

@test "rebuild-bench-history-run: fails when no benchmark project is given and none is found under benchmarks/" {
    _install_fakes "$BATS_TEST_TMPDIR"
    run _run_rebuild "$BATS_TEST_TMPDIR" 'BENCHER_API_TOKEN=tok' --quiet --bencher-project p --bencher-testbed t
    assert_failure
    assert_output --partial "No benchmark projects found under 'benchmarks/'"
}

@test "rebuild-bench-history-run: requires --bencher-project, --bencher-testbed, and \$BENCHER_API_TOKEN together" {
    _install_fakes "$BATS_TEST_TMPDIR"
    _make_benchmark_project "$BATS_TEST_TMPDIR"
    run _run_rebuild "$BATS_TEST_TMPDIR" '' --quiet --repeat 1
    assert_failure
    assert_output --partial "Bencher project (--bencher-project) is required"
    assert_output --partial "Bencher testbed (--bencher-testbed) is required"
    assert_output --partial "BENCHER_API_TOKEN environment variable is required"
}

@test "rebuild-bench-history-run: rejects a non-positive --repeat" {
    _install_fakes "$BATS_TEST_TMPDIR"
    _make_benchmark_project "$BATS_TEST_TMPDIR"
    run _run_rebuild "$BATS_TEST_TMPDIR" 'BENCHER_API_TOKEN=tok' --quiet --repeat 0 --bencher-project p --bencher-testbed t
    assert_failure
    assert_output --partial "repeat must be a positive integer"
}

@test "rebuild-bench-history-run: fails cleanly when the bencher CLI is not on PATH" {
    _make_benchmark_project "$BATS_TEST_TMPDIR"
    run timeout 15 env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" BENCHER_API_TOKEN=tok bash -c "
        cd '$BATS_TEST_TMPDIR' && bash '$_rebuild_run' --quiet --repeat 1 --bencher-project p --bencher-testbed t
    "
    assert_failure
    assert_output --partial "The 'bencher' CLI was not found on PATH"
}

# --- argument handling ---------------------------------------------------------------------

@test "rebuild-bench-history-run: fails when more than one benchmark project is given" {
    _install_fakes "$BATS_TEST_TMPDIR"
    _make_benchmark_project "$BATS_TEST_TMPDIR"
    run _run_rebuild "$BATS_TEST_TMPDIR" 'BENCHER_API_TOKEN=tok' --quiet --bencher-project p --bencher-testbed t benchmarks/App/App.Benchmarks.csproj Other.csproj
    assert_failure
    assert_output --partial "Multiple benchmark projects specified"
}

@test "rebuild-bench-history-run: fails on an unknown option" {
    _install_fakes "$BATS_TEST_TMPDIR"
    run _run_rebuild "$BATS_TEST_TMPDIR" '' --quiet --bogus
    assert_failure
    assert_output --partial "Unknown option: --bogus"
}

@test "rebuild-bench-history-run: -h prints usage and exits 0" {
    _install_fakes "$BATS_TEST_TMPDIR"
    run _run_rebuild "$BATS_TEST_TMPDIR" '' -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "rebuild-bench-history-run: in CI mode, the summary also lands in the step summary file" {
    _install_fakes "$BATS_TEST_TMPDIR"
    _make_benchmark_project "$BATS_TEST_TMPDIR"
    run timeout 20 env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/fakebin:/usr/local/bin:/usr/bin:/bin" \
        RUN_BENCHMARKS_CALL_LOG="$BATS_TEST_TMPDIR/rb.log" BENCHER_CALL_LOG="$BATS_TEST_TMPDIR/bencher.log" \
        BENCHER_API_TOKEN=tok GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" \
        bash -c "cd '$BATS_TEST_TMPDIR' && bash '$_rebuild_run' --quiet --repeat 1 --bencher-project p --bencher-testbed t"
    assert_success

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "Benchmark history rebuild"
}
