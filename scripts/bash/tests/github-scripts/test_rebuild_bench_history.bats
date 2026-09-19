#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/rebuild-bench-history.sh, as it behaves TODAY.
#
# Was previously broken: line 42 (now 43) called `root_working_tree "$script_dir" self_root ||
# true` without ever declaring `self_root` first. root_working_tree's formal precondition
# requires argument 2 to name an already-declared variable, so this crashed with a `bug` (exit
# 254) any time --owner and $GITHUB_REPOSITORY_OWNER were both absent -- exactly the documented
# fallback path ("derived from this repository's origin remote"). Fixed by declaring
# `self_root` before the call, matching every other script's nameref-output convention.
#
# `gh` is faked (this script is pure `gh api`/`gh workflow run` orchestration over a fixed,
# hardcoded $vm2_repositories list -- no git/dotnet involved). One test needs the REAL `gh`
# absent from PATH (to exercise the "gh not found" guard), which needs the
# _make_path_excluding symlink-mirror trick from test_setup_repo.bats: this box has a real gh
# on PATH, so simply using a short PATH string doesn't hide it.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_rebuild_history="$_gh_scripts_dir/rebuild-bench-history.sh"

# Builds $1/bin as a full symlink mirror of every executable in /usr/local/bin and /usr/bin,
# except the names listed in the remaining arguments -- so "command -v <name>" behaves as
# though that tool were not installed, while every other tool still works normally.
_make_path_excluding() {
    local _dir="$1/bin"; shift
    local _exclude=("$@")
    mkdir -p "$_dir"
    local _f _name _skip _e
    for _f in /usr/local/bin/* /usr/bin/*; do
        [[ -f "$_f" && -x "$_f" ]] || continue
        _name="$(basename "$_f")"
        [[ -e "$_dir/$_name" ]] && continue
        _skip=false
        for _e in "${_exclude[@]}"; do
            [[ "$_name" == "$_e" ]] && _skip=true && break
        done
        $_skip || ln -sf "$_f" "$_dir/$_name" 2>/dev/null
    done
    echo "$_dir"
}

# Fake `gh` covering the two calls this script makes: the read-only `contents/benchmarks`
# probe (succeeds only for repos listed in $HAS_BENCHMARKS, space-separated) and
# `workflow run` (fails for repos listed in $FAIL_DISPATCH_FOR, with a non-transient-looking
# stderr message so execute_gh_with_retry doesn't waste time retrying).
_install_fake_gh() {
    local _dir="$1/fakebin"
    mkdir -p "$_dir"
    cat > "$_dir/gh" <<'EOF'
#!/usr/bin/env bash
_all="$*"
echo "$_all" >> "$GH_CALL_LOG"
case "$_all" in
    api\ repos/*/contents/benchmarks\ --silent)
        _rest="${_all#api repos/}"
        _repo="${_rest%%/contents*}"
        _name="${_repo#*/}"
        [[ " $HAS_BENCHMARKS " == *" $_name "* ]] && exit 0 || exit 1
        ;;
    workflow\ run\ *)
        for bad in $FAIL_DISPATCH_FOR; do
            [[ "$_all" == *"--repo "*"/$bad "* ]] && { echo "workflow file not found" >&2; exit 1; }
        done
        exit "${FAKE_DISPATCH_EXIT:-0}"
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$_dir/gh"
}

# $1 = dir, $2 = env-var assignments to prepend, $@ (rest) = CLI arguments.
_run_rebuild_history() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="$_dir/fakebin:/usr/local/bin:/usr/bin:/bin" GH_CALL_LOG="$_dir/gh.log" bash -c "
        cd '$_dir' && $_env_vars bash '$_rebuild_history' $*
    "
}

# --- happy path ---------------------------------------------------------------------------

@test "rebuild-bench-history: dispatches only the repos that have a benchmarks/ directory" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" 'HAS_BENCHMARKS="vm2.Ulid vm2.Glob"' --quiet --owner acme --repeat 3
    assert_success
    assert_output --partial "Dispatching 'RebuildBenchHistory.yaml' for 'acme/vm2.Ulid' (repeat=3)"
    assert_output --partial "Dispatching 'RebuildBenchHistory.yaml' for 'acme/vm2.Glob' (repeat=3)"
    assert_output --partial "'acme/vm2.SemVer' has no 'benchmarks/' directory"
    assert_output --partial "dispatched : 2"
    assert_output --partial "no benchmarks/skipped : 8"
}

@test "rebuild-bench-history: a custom --workflow is dispatched instead of the default" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" 'HAS_BENCHMARKS="vm2.Ulid"' --quiet --owner acme --workflow Custom.yaml
    assert_success
    assert_output --partial "Dispatching 'Custom.yaml' for 'acme/vm2.Ulid'"
}

@test "rebuild-bench-history: --dry-run reports the target list without actually dispatching" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" 'HAS_BENCHMARKS="vm2.Ulid"' --quiet --owner acme --dry-run
    assert_success
    assert_output --partial "dispatched : 1"
    assert_output --partial "dry run — workflows were NOT dispatched"

    run cat "$BATS_TEST_TMPDIR/gh.log"
    refute_output --partial "workflow run"
}

@test "rebuild-bench-history: derives the owner from this repo's own origin remote when neither --owner nor \$GITHUB_REPOSITORY_OWNER is given" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" '' --quiet
    assert_success
    # this repo's own remote owner (vmelamed) -- confirms the fallback path resolves without
    # crashing (the bug this test file was written to catch) and picks up a real value.
    assert_output --partial "owner=vmelamed"
}

# --- partial failure handling ------------------------------------------------------------

@test "rebuild-bench-history: a failed dispatch for one repo is warned about, others still proceed" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" 'HAS_BENCHMARKS="vm2.Ulid vm2.Glob" FAIL_DISPATCH_FOR=vm2.Ulid' --quiet --owner acme
    assert_success
    assert_output --partial "Failed to dispatch 'RebuildBenchHistory.yaml' for 'acme/vm2.Ulid'"
    assert_output --partial "Dispatching 'RebuildBenchHistory.yaml' for 'acme/vm2.Glob'"
    assert_output --partial "dispatched : 1"
    assert_output --partial "failed : 1"
}

# --- validation failures ---------------------------------------------------------------------

@test "rebuild-bench-history: rejects a non-positive --repeat" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" '' --quiet --owner acme --repeat 0
    assert_failure
    assert_output --partial "repeat must be a positive integer"
}

@test "rebuild-bench-history: fails cleanly when the gh CLI is not on PATH" {
    local _bin
    _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR" gh)"
    run env -i HOME="$HOME" PATH="$_bin" bash -c "
        cd '$BATS_TEST_TMPDIR' && bash '$_rebuild_history' --quiet --owner acme
    "
    assert_failure
    assert_output --partial "The GitHub CLI 'gh' was not found on PATH"
}

# --- argument handling ---------------------------------------------------------------------

@test "rebuild-bench-history: fails with a clear error when a value-taking option is given without a value" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" '' --quiet --owner
    assert_failure
    assert_output --partial "Missing value for --owner"
}

@test "rebuild-bench-history: fails on an unknown option" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" '' --quiet --bogus
    assert_failure
    assert_output --partial "Unknown argument: --bogus"
}

@test "rebuild-bench-history: -h prints usage and exits 0" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run _run_rebuild_history "$BATS_TEST_TMPDIR" '' -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "rebuild-bench-history: in CI mode, the summary also lands in the step summary file" {
    _install_fake_gh "$BATS_TEST_TMPDIR"
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/fakebin:/usr/local/bin:/usr/bin:/bin" \
        GH_CALL_LOG="$BATS_TEST_TMPDIR/gh.log" HAS_BENCHMARKS="vm2.Ulid" \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" \
        bash -c "cd '$BATS_TEST_TMPDIR' && bash '$_rebuild_history' --quiet --owner acme"
    assert_success

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "Benchmark-history rebuild dispatch"
}
