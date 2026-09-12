#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/create-pr.sh, as it behaves TODAY.
#
# create-pr.sh is a standalone top-level script (not sourced, does not use the vm2 bash
# library) that is normally registered as a `gh` alias. It shells out to the real `gh` and
# `git` binaries and, as its very last step, `exec`s into `gh pr create`. To test it
# deterministically and without a real GitHub round-trip:
#   - a throwaway local repo with a local (file://-less, plain bare-repo) "origin" remote
#     provides real, network-free git history
#   - a fake `gh` executable placed first on $PATH intercepts `gh repo view` (to supply the
#     default branch name) and `gh pr create` (printing the arguments and body it received
#     instead of contacting GitHub, then exiting 0 -- since the real script `exec`s into this
#     as its last command, its exit code becomes the test's exit code)
#
# The whole thing runs under `env -i HOME="$HOME" PATH=...` (only HOME/PATH and the fakebin
# directory), for the same reason as the lib characterization tests: the invoking shell may
# have unrelated ambient PATH/profile contamination that would otherwise shadow the fake `gh`
# or change behavior non-deterministically.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'

_script_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../src" && pwd)"
_create_pr="$_script_dir/create-pr.sh"

# Fake `gh` that answers `repo view` with a configurable default branch and echoes back
# whatever `pr create` receives (arguments and, distinctly, the --body value) so assertions
# can check both without going near the network.
_install_fake_gh() {
    local _bindir="$1" _default_branch="${2:-main}"
    mkdir -p "$_bindir"
    cat > "$_bindir/gh" <<EOF
#!/usr/bin/env bash
if [[ "\$1 \$2" == "repo view" ]]; then
    echo "$_default_branch"
    exit 0
fi
if [[ "\$1 \$2" == "pr create" ]]; then
    echo "PR-CREATE-ARGS: \$*"
    args=("\$@")
    for i in "\${!args[@]}"; do
        if [[ "\${args[\$i]}" == "--body" ]]; then
            echo "---BODY-START---"
            echo "\${args[\$((i+1))]}"
            echo "---BODY-END---"
        fi
    done
    exit 0
fi
exit 1
EOF
    chmod +x "$_bindir/gh"
}

# A fake `gh` whose `repo view` always fails (simulates being outside GitHub, or gh not
# authenticated) so the script's `|| echo main` fallback path can be exercised.
_install_fake_gh_no_repo_view() {
    local _bindir="$1"
    mkdir -p "$_bindir"
    cat > "$_bindir/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "repo view" ]]; then
    exit 1
fi
if [[ "$1 $2" == "pr create" ]]; then
    echo "PR-CREATE-ARGS: $*"
    exit 0
fi
exit 1
EOF
    chmod +x "$_bindir/gh"
}

# Builds a local repo with a real "origin" remote (a bare repo, no network), `main` pushed,
# and a `feature` branch checked out with one extra commit ahead of `origin/main`.
_make_repo_with_feature_branch() {
    local _dir="$1"
    git init --quiet --bare "$_dir/origin.git"
    git clone --quiet "$_dir/origin.git" "$_dir/repo"
    git -C "$_dir/repo" config user.email "test@test.local"
    git -C "$_dir/repo" config user.name "test"
    echo "hi" > "$_dir/repo/f.txt"
    git -C "$_dir/repo" add -A
    git -C "$_dir/repo" commit --quiet -m "chore: init"
    git -C "$_dir/repo" push --quiet origin main
    git -C "$_dir/repo" checkout --quiet -b feature
    echo "more" >> "$_dir/repo/f.txt"
    git -C "$_dir/repo" commit --quiet -am "feat: add more"
}

_run_create_pr() {
    local _repo="$1"; shift
    (cd "$_repo" && env -i HOME="$HOME" PATH="$_repo/fakebin:/usr/bin:/bin" bash "$_create_pr" "$@")
}

# --- fallback template ---------------------------------------------------------------------

@test "create-pr: falls back to the hard-coded template and warns when no PR template file exists" {
    _make_repo_with_feature_branch "$BATS_TEST_TMPDIR"
    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin"
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_success
    assert_output --partial "No PR template found"
    assert_output --partial "## Checklist"
    assert_output --partial "- feat: add more"
}

@test "create-pr: forwards extra CLI arguments verbatim to 'gh pr create'" {
    _make_repo_with_feature_branch "$BATS_TEST_TMPDIR"
    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin"
    run _run_create_pr "$BATS_TEST_TMPDIR/repo" --web --reviewer someone
    assert_success
    assert_output --partial "PR-CREATE-ARGS:"
    assert_output --partial "--web"
    assert_output --partial "--reviewer someone"
}

# --- repository PR template -----------------------------------------------------------------

@test "create-pr: uses .github/PULL_REQUEST_TEMPLATE.md when present, without warning" {
    _make_repo_with_feature_branch "$BATS_TEST_TMPDIR"
    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin"
    mkdir -p "$BATS_TEST_TMPDIR/repo/.github"
    cat > "$BATS_TEST_TMPDIR/repo/.github/PULL_REQUEST_TEMPLATE.md" <<'EOF'
## Description

<!-- commit-list -->

## Notes
EOF
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_success
    refute_output --partial "No PR template found"
    assert_output --partial "## Description"
    assert_output --partial "- feat: add more"
    assert_output --partial "## Notes"
}

@test "create-pr: falls back to lowercase .github/pull_request_template.md" {
    _make_repo_with_feature_branch "$BATS_TEST_TMPDIR"
    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin"
    mkdir -p "$BATS_TEST_TMPDIR/repo/.github"
    cat > "$BATS_TEST_TMPDIR/repo/.github/pull_request_template.md" <<'EOF'
Lowercase template: <!-- commit-list -->
EOF
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_success
    refute_output --partial "No PR template found"
    assert_output --partial "Lowercase template: - feat: add more"
}

@test "create-pr: prefers the uppercase template over the lowercase one when both exist" {
    _make_repo_with_feature_branch "$BATS_TEST_TMPDIR"
    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin"
    mkdir -p "$BATS_TEST_TMPDIR/repo/.github"
    echo "UPPER: <!-- commit-list -->" > "$BATS_TEST_TMPDIR/repo/.github/PULL_REQUEST_TEMPLATE.md"
    echo "lower: <!-- commit-list -->" > "$BATS_TEST_TMPDIR/repo/.github/pull_request_template.md"
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_success
    assert_output --partial "UPPER:"
    refute_output --partial "lower:"
}

# --- commit list content ---------------------------------------------------------------------

@test "create-pr: renders '_(no commits)_' when the current branch has nothing new since the default branch" {
    _make_repo_with_feature_branch "$BATS_TEST_TMPDIR"
    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin"
    git -C "$BATS_TEST_TMPDIR/repo" checkout --quiet main
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_success
    assert_output --partial "_(no commits)_"
}

@test "create-pr: lists multiple commits oldest-first" {
    _make_repo_with_feature_branch "$BATS_TEST_TMPDIR"
    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin"
    echo "even-more" >> "$BATS_TEST_TMPDIR/repo/f.txt"
    git -C "$BATS_TEST_TMPDIR/repo" commit --quiet -am "fix: a follow-up"
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_success
    local _first_line_no _second_line_no
    _first_line_no=$(grep -n -- "- feat: add more" <<< "$output" | head -1 | cut -d: -f1)
    _second_line_no=$(grep -n -- "- fix: a follow-up" <<< "$output" | head -1 | cut -d: -f1)
    [[ $_first_line_no -lt $_second_line_no ]]
}

# --- default branch resolution ----------------------------------------------------------------

@test "create-pr: falls back to 'main' as the base branch when 'gh repo view' fails" {
    _make_repo_with_feature_branch "$BATS_TEST_TMPDIR"
    _install_fake_gh_no_repo_view "$BATS_TEST_TMPDIR/repo/fakebin"
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_success
    assert_output --partial "- feat: add more"
}

@test "create-pr: uses the default branch reported by 'gh repo view' rather than always 'main' (regression)" {
    # Build a repo whose real default/upstream branch is NOT named 'main', to prove the
    # script actually reads gh's answer instead of hard-coding 'main'.
    git init --quiet --bare "$BATS_TEST_TMPDIR/origin.git"
    git clone --quiet "$BATS_TEST_TMPDIR/origin.git" "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" config user.email "test@test.local"
    git -C "$BATS_TEST_TMPDIR/repo" config user.name "test"
    git -C "$BATS_TEST_TMPDIR/repo" checkout --quiet -b trunk
    echo hi > "$BATS_TEST_TMPDIR/repo/f.txt"
    git -C "$BATS_TEST_TMPDIR/repo" add -A
    git -C "$BATS_TEST_TMPDIR/repo" commit --quiet -m "chore: init"
    git -C "$BATS_TEST_TMPDIR/repo" push --quiet origin trunk
    git -C "$BATS_TEST_TMPDIR/repo" checkout --quiet -b feature
    echo more >> "$BATS_TEST_TMPDIR/repo/f.txt"
    git -C "$BATS_TEST_TMPDIR/repo" commit --quiet -am "feat: trunk-based work"

    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin" "trunk"
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_success
    assert_output --partial "- feat: trunk-based work"
}

# --- documented crash (characterization, not endorsement) --------------------------------------

@test "create-pr: exits non-zero (set -euo pipefail propagates git's failure) when origin/<base> does not exist" {
    # Regression/characterization: 'commits=\"\$(git log ... origin/\$base..HEAD)\"' is a plain
    # assignment, so under 'set -e' a failing git invocation (unresolvable revision range,
    # e.g. no such remote-tracking ref) aborts the whole script instead of degrading to
    # '_(no commits)_'. This is today's actual behavior, not necessarily desirable behavior.
    mkdir -p "$BATS_TEST_TMPDIR/repo/fakebin"
    git init --quiet --initial-branch=main "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" config user.email "test@test.local"
    git -C "$BATS_TEST_TMPDIR/repo" config user.name "test"
    echo hi > "$BATS_TEST_TMPDIR/repo/f.txt"
    git -C "$BATS_TEST_TMPDIR/repo" add -A
    git -C "$BATS_TEST_TMPDIR/repo" commit --quiet -m "chore: init"
    _install_fake_gh "$BATS_TEST_TMPDIR/repo/fakebin"
    run _run_create_pr "$BATS_TEST_TMPDIR/repo"
    assert_failure 128
}
