#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/upload-bencher-results.sh, as it behaves TODAY.
#
# upload-bencher-results.sh is designed to run identically standalone and in GitHub Actions (it
# sources gh_core.sh) -- these tests run it the same way in both "modes".
#
# The real `bencher` CLI is faked: it logs every invocation to $BENCHER_CALL_LOG and prints
# $FAKE_BENCHER_OUTPUT (default: a plain success line) while exiting with $FAKE_BENCHER_EXIT
# (default: 0). No real Git repo or .NET tooling is needed -- this script only shells out to
# `bencher` and `bc`, and reads a directory of pre-existing JSON files.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_upload="$_gh_scripts_dir/upload-bencher-results.sh"

_install_fake_bencher() {
    local _dir="$1/fakebin"
    mkdir -p "$_dir"
    cat > "$_dir/bencher" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$BENCHER_CALL_LOG"
echo "${FAKE_BENCHER_OUTPUT:-Success}"
exit "${FAKE_BENCHER_EXIT:-0}"
EOF
    chmod +x "$_dir/bencher"
}

_make_results_dir() {
    local _dir="$1"
    mkdir -p "$_dir"
    echo '{}' > "$_dir/App.Benchmarks-report-full-compressed.json"
}

# $1 = results dir, $2 = env-var assignments to prepend, $@ (rest) = CLI arguments.
_run_upload() {
    local _results_dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/fakebin:/usr/local/bin:/usr/bin:/bin" \
        BENCHER_CALL_LOG="$BATS_TEST_TMPDIR/bencher.log" \
        BENCHER_API_TOKEN=tok \
        bash -c "
            cd '$BATS_TEST_TMPDIR' && $_env_vars bash '$_upload' '$_results_dir' $*
        "
}

# --- happy path ---------------------------------------------------------------------------

@test "upload-bencher-results: push to main uploads with --branch main and no start-point" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main
    assert_success
    assert_output --partial "The upload to Bencher completed successfully with no alerts."

    run cat "$BATS_TEST_TMPDIR/bencher.log"
    assert_output --partial "--project vm2-devops"
    assert_output --partial "--testbed ubuntu-latest"
    assert_output --partial "--branch main"
    refute_output --partial "--start-point"
    assert_output --partial "--file $BATS_TEST_TMPDIR/results/App.Benchmarks-report-full-compressed.json"
}

@test "upload-bencher-results: push to a non-main branch forks from main and clones thresholds" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name feature/x
    assert_success

    run cat "$BATS_TEST_TMPDIR/bencher.log"
    assert_output --partial "--branch feature/x"
    assert_output --partial "--start-point main"
    assert_output --partial "--start-point-clone-thresholds"
    refute_output --partial "--start-point-reset"
}

@test "upload-bencher-results: a pull_request event tracks its own head branch with a pinned start-point" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" 'GH_TOKEN=ghtok' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name pull_request --ref-name main \
        --head-ref feature/x --pr-number 42 --pr-base-sha deadbeef
    assert_success

    run cat "$BATS_TEST_TMPDIR/bencher.log"
    assert_output --partial "--branch feature/x"
    assert_output --partial "--start-point main"
    assert_output --partial "--start-point-clone-thresholds"
    assert_output --partial "--start-point-reset"
    assert_output --partial "--start-point-hash deadbeef"
    assert_output --partial "--github-actions ghtok"
    assert_output --partial "--ci-number 42"
}

@test "upload-bencher-results: --reset-thresholds true adds --thresholds-reset" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main \
        --reset-thresholds true
    assert_success

    run cat "$BATS_TEST_TMPDIR/bencher.log"
    assert_output --partial "--thresholds-reset"
}

@test "upload-bencher-results: falls back to the GITHUB_* ambient environment variables Actions sets automatically" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" \
        'GITHUB_REPOSITORY=vmelamed/vm2.DevOps GITHUB_EVENT_NAME=push GITHUB_REF_NAME=main' \
        --testbed ubuntu-latest
    assert_success

    run cat "$BATS_TEST_TMPDIR/bencher.log"
    assert_output --partial "--project vm2-devops"
    assert_output --partial "--branch main"
}

@test "upload-bencher-results: standalone (no GITHUB_* env, no --repository/--ref-name) derives them from the local git repo" {
    local _repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$_repo"
    git -C "$_repo" init --quiet
    git -C "$_repo" config user.email "test@test.local"
    git -C "$_repo" config user.name "test"
    git -C "$_repo" commit --quiet --allow-empty -m init
    git -C "$_repo" checkout --quiet -b feature/local-test
    git -C "$_repo" remote add origin "https://github.com/vmelamed/vm2.DevOps.git"

    _make_results_dir "$_repo/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/fakebin:/usr/local/bin:/usr/bin:/bin" \
        BENCHER_CALL_LOG="$BATS_TEST_TMPDIR/bencher.log" BENCHER_API_TOKEN=tok \
        bash -c "cd '$_repo' && bash '$_upload' '$_repo/results'"
    assert_success

    run cat "$BATS_TEST_TMPDIR/bencher.log"
    assert_output --partial "--project vm2-devops"
    assert_output --partial "--testbed local"
    assert_output --partial "--branch feature/local-test"
}

# --- alerts / failures ------------------------------------------------------------------------

@test "upload-bencher-results: a detected alert warns and fails, but still surfaces bencher's output" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" 'FAKE_BENCHER_EXIT=1 FAKE_BENCHER_OUTPUT="Alerts detected: regression"' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main
    assert_failure
    assert_output --partial "Alerts detected: regression"
    assert_output --partial "Bencher uploaded results but detected threshold alerts."
}

@test "upload-bencher-results: a transport/tool failure (no alert text) reports a hard failure" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" 'FAKE_BENCHER_EXIT=1 FAKE_BENCHER_OUTPUT="connection refused"' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main
    assert_failure
    assert_output --partial "connection refused"
    assert_output --partial "Bencher run failed before completing successfully."
}

@test "upload-bencher-results: fails when the results directory has no matching JSON files" {
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/empty" '' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main
    assert_failure
    assert_output --partial "No benchmark result files"
}

# --- validation failures ---------------------------------------------------------------------

@test "upload-bencher-results: rejects a results directory that does not exist" {
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/does-not-exist" '' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main
    assert_failure
    assert_output --partial "is not a directory"
}

@test "upload-bencher-results: defaults --testbed to 'local' outside of GitHub Actions" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' \
        --repository vmelamed/vm2.DevOps --event-name push --ref-name main
    assert_success

    run cat "$BATS_TEST_TMPDIR/bencher.log"
    assert_output --partial "--testbed local"
}

@test "upload-bencher-results: rejects a --repository not in owner/repo form" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' \
        --testbed ubuntu-latest --repository vm2.DevOps --event-name push --ref-name main
    assert_failure
    assert_output --partial "must be in 'owner/repo' form"
}

@test "upload-bencher-results: a pull_request event without --head-ref/--pr-number/--pr-base-sha/GH_TOKEN fails" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name pull_request --ref-name main
    assert_failure
    assert_output --partial "--head-ref is required"
    assert_output --partial "--pr-number is required"
    assert_output --partial "--pr-base-sha is required"
    assert_output --partial "GH_TOKEN environment variable is required"
}

@test "upload-bencher-results: fails without BENCHER_API_TOKEN" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/fakebin:/usr/local/bin:/usr/bin:/bin" \
        BENCHER_CALL_LOG="$BATS_TEST_TMPDIR/bencher.log" \
        bash -c "cd '$BATS_TEST_TMPDIR' && bash '$_upload' '$BATS_TEST_TMPDIR/results' --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main"
    assert_failure
    assert_output --partial "BENCHER_API_TOKEN environment variable is required"
}

@test "upload-bencher-results: rejects an out-of-range --max-regression-pct" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main \
        --max-regression-pct 150
    assert_failure
    assert_output --partial "must be an integer number between 0 and 100"
}

@test "upload-bencher-results: rejects a negative --max-gen1-collects" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main \
        --max-gen1-collects -1
    assert_failure
    assert_output --partial "--max-gen1-collects must be a non-negative integer"
}

# --- argument handling ---------------------------------------------------------------------

@test "upload-bencher-results: fails when more than one results directory is given" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' "$BATS_TEST_TMPDIR/results" \
        --testbed ubuntu-latest --repository vmelamed/vm2.DevOps --event-name push --ref-name main
    assert_failure
    assert_output --partial "Multiple results directories specified"
}

@test "upload-bencher-results: fails on an unknown option" {
    _make_results_dir "$BATS_TEST_TMPDIR/results"
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' --bogus
    assert_failure
    assert_output --partial "Unknown option: --bogus"
}

@test "upload-bencher-results: -h prints usage and exits 0" {
    _install_fake_bencher "$BATS_TEST_TMPDIR"
    run _run_upload "$BATS_TEST_TMPDIR/results" '' -h
    assert_success
    assert_output --partial "Usage:"
}
