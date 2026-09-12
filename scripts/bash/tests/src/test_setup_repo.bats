#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/setup-repo.sh, the top-level orchestrator, as it
# behaves TODAY.
#
# setup-repo.sh's own logic in this file's scope is the pre-flight sequence: tool-prerequisite
# checks, resolving $vm2_repos and the SoT/DevOps paths, resolving the target repo path, and the
# final validation block (branch/visibility/owner regexes, --audit preconditions) -- all of it
# reachable, deterministically, WITHOUT ever calling the real GitHub API: every check exercised
# here happens before the script's first '$actual' GitHub-repository-specific API call
# (resolve_github_app_ids(), which only runs after the final validation block's
# exit_if_has_errors passes). The repo-creation and repo-configuration flows further down
# setup-repo.sh (git init/push, gh repo create, configure_default_repo_settings() and friends)
# are exercised at the function level in test_setup_repo_functions.bats instead -- driving them
# end-to-end from this top-level script would mean re-mocking the same 'gh' surface for a much
# larger, much more fragile test with no extra coverage.
#
# Every test here runs the real setup-repo.sh, but with $PATH built from a full symlink mirror
# of /usr/bin minus whichever tool(s) the test wants to appear "not installed" (see
# _make_path_excluding), plus a fixture $VM2_REPOS (see _make_vm2_repos_fixture) so the tests
# never depend on this machine's real ~/repos/vm2 checkout being on any particular branch.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_src_dir="$(cd "$lib_dir/../src" && pwd)"
_setup_repo="$_src_dir/setup-repo.sh"

# Builds $1/bin as a full symlink mirror of every executable in /usr/bin (this system's real
# tools), except the names listed in the remaining arguments -- so "command -v <name>" behaves
# as though that tool were not installed, while every other tool (git, jq, yq, sed, mkdir, ...)
# still works normally.
_make_path_excluding() {
    local _dir="$1/bin"; shift
    local _exclude=("$@")
    mkdir -p "$_dir"
    local _f _name _skip _e
    for _f in /usr/bin/*; do
        [[ -f "$_f" && -x "$_f" ]] || continue
        _name="$(basename "$_f")"
        _skip=false
        for _e in "${_exclude[@]}"; do
            [[ "$_name" == "$_e" ]] && _skip=true && break
        done
        $_skip || ln -sf "$_f" "$_dir/$_name" 2>/dev/null
    done
    echo "$_dir"
}

# A fake 'gh' that only answers 'gh auth status' (needed by setup-repo.sh's own tool-prerequisite
# check) -- every test in this file exits (via exit_if_has_errors in the final validation block,
# or earlier) before setup-repo.sh makes any repository-specific 'gh api' call.
_install_fake_gh_auth_only() {
    local _bindir="$1"
    mkdir -p "$_bindir"
    cat > "$_bindir/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "auth status" ]] && exit 0
echo "unexpected gh call: $*" >&2
exit 1
EOF
    chmod +x "$_bindir/gh"
}

# Builds a minimal but valid $1/vm2.DevOps and $1/vm2.Templates -- both real git repos on
# 'main' with '.github/workflows' present (satisfying validate_repo_root(), as used by
# test_git_vm2.bats), so resolve_vm2_repos() and get_vm2_sot_path() succeed against a
# throwaway fixture instead of depending on this machine's actual ~/repos/vm2 checkout (which,
# mid-development, may not even be on 'main').
_make_vm2_repos_fixture() {
    local _parent="$1"

    mkdir -p "$_parent/vm2.DevOps/.github/workflows"
    git -C "$_parent/vm2.DevOps" init --quiet --initial-branch=main
    git -C "$_parent/vm2.DevOps" config user.email "test@test.local"
    git -C "$_parent/vm2.DevOps" config user.name "test"
    cat > "$_parent/vm2.DevOps/.github/workflows/_ci.yaml" <<'EOF'
name: CI
jobs:
  postrun-ci:
    name: Postrun-CI
EOF
    git -C "$_parent/vm2.DevOps" add -A
    git -C "$_parent/vm2.DevOps" commit --quiet -m "chore: init"
    git -C "$_parent/vm2.DevOps" tag v1.0.0

    mkdir -p "$_parent/vm2.Templates/.github/workflows" \
             "$_parent/vm2.Templates/templates/AddNewPackage/content"
    git -C "$_parent/vm2.Templates" init --quiet --initial-branch=main
    git -C "$_parent/vm2.Templates" config user.email "test@test.local"
    git -C "$_parent/vm2.Templates" config user.name "test"
    echo "name: CI" > "$_parent/vm2.Templates/.github/workflows/ci.yaml"
    touch "$_parent/vm2.Templates/templates/AddNewPackage/content/.gitmessage"
    git -C "$_parent/vm2.Templates" add -A
    git -C "$_parent/vm2.Templates" commit --quiet -m "chore: init"
    git -C "$_parent/vm2.Templates" tag v1.0.0
}

# Builds a target project directory: an initialized (local-only, no remote) git repo with a
# '.github/workflows/CI.yaml' containing a gate job, so has_local_repo() is true, has_remote_repo()
# is false (no GitHub API calls needed to resolve its state), and list_required_checks() can
# parse a gate job name from it.
_make_target_repo() {
    local _dir="$1"

    mkdir -p "$_dir/.github/workflows"
    git -C "$_dir" init --quiet --initial-branch=main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    cat > "$_dir/.github/workflows/CI.yaml" <<'EOF'
name: CI
jobs:
  postrun-ci:
    name: Postrun-CI
EOF
    echo "hello" > "$_dir/README.md"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: initial scaffold"
}

_run_setup_repo() {
    local _pathdir="$1"; shift
    env -i HOME="$HOME" PATH="$_pathdir" bash "$_setup_repo" "$@"
}

# =====================================================================================
# Tool prerequisite checks
# =====================================================================================

@test "setup-repo: fails when 'jq' is not installed" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/nojq" jq)"
    _install_fake_gh_auth_only "$BATS_TEST_TMPDIR/gh-bin"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "'jq' is not installed"
}

@test "setup-repo: fails when 'gh' is not installed" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/nogh" gh)"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "'gh' is not installed"
}

@test "setup-repo: fails when 'gh' is not authenticated" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/nogh" gh)"
    mkdir -p "$BATS_TEST_TMPDIR/gh-bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/gh-bin/gh"
    chmod +x "$BATS_TEST_TMPDIR/gh-bin/gh"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "'gh' is not authenticated"
}

@test "setup-repo: fails when 'yq' is not installed" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/noyq" yq)"
    _install_fake_gh_auth_only "$BATS_TEST_TMPDIR/gh-bin"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "'yq' is not installed"
}

# =====================================================================================
# vm2_repos / SoT / _ci.yaml resolution
# =====================================================================================

@test "setup-repo: fails when the vm2.DevOps repo has no _ci.yaml reusable workflow" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/bin")"
    _install_fake_gh_auth_only "$BATS_TEST_TMPDIR/gh-bin"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    rm "$BATS_TEST_TMPDIR/vm2repos/vm2.DevOps/.github/workflows/_ci.yaml"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "Could not find _ci.yaml"
}

# =====================================================================================
# Final validation block
# =====================================================================================

@test "setup-repo: fails when the target has a .github/workflows dir but no CI.yaml file in it" {
    # resolve_repo_root()'s own check is coarser -- it only requires the '.github/workflows'
    # DIRECTORY to exist, so a repo with that directory but no CI.yaml file specifically
    # (e.g. only other workflow files) sails through it; the final validation block's own
    # '[[ -s "$ci_yaml" ]]' check is what actually catches this narrower case.
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/bin")"
    _install_fake_gh_auth_only "$BATS_TEST_TMPDIR/gh-bin"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    mkdir -p "$BATS_TEST_TMPDIR/vm2repos/target/.github/workflows"
    git -C "$BATS_TEST_TMPDIR/vm2repos/target" init --quiet --initial-branch=main
    git -C "$BATS_TEST_TMPDIR/vm2repos/target" config user.email t@t.local
    git -C "$BATS_TEST_TMPDIR/vm2repos/target" config user.name t
    echo "name: Other" > "$BATS_TEST_TMPDIR/vm2repos/target/.github/workflows/other.yaml"
    git -C "$BATS_TEST_TMPDIR/vm2repos/target" add -A
    git -C "$BATS_TEST_TMPDIR/vm2repos/target" commit --quiet -m "chore: init"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "missing .github/workflows/CI.yaml"
}

@test "setup-repo: fails on an invalid branch name" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/bin")"
    _install_fake_gh_auth_only "$BATS_TEST_TMPDIR/gh-bin"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" --branch '..bad..' "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "Invalid branch name"
}

@test "setup-repo: fails on an invalid visibility" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/bin")"
    _install_fake_gh_auth_only "$BATS_TEST_TMPDIR/gh-bin"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" --visibility bogus "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "Invalid visibility 'bogus'"
}

@test "setup-repo: --audit without a GitHub remote fails (cannot audit an unlinked repo)" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/bin")"
    _install_fake_gh_auth_only "$BATS_TEST_TMPDIR/gh-bin"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" --audit "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    assert_output --partial "not linked to a GitHub remote"
}

@test "setup-repo: --audit combined with --interactive-vars fails (cannot prompt during a read-only audit)" {
    local _bin; _bin="$(_make_path_excluding "$BATS_TEST_TMPDIR/bin")"
    _install_fake_gh_auth_only "$BATS_TEST_TMPDIR/gh-bin"
    _make_vm2_repos_fixture "$BATS_TEST_TMPDIR/vm2repos"
    _make_target_repo "$BATS_TEST_TMPDIR/vm2repos/target"
    run _run_setup_repo "$BATS_TEST_TMPDIR/gh-bin:$_bin" --quiet --vm2-repos "$BATS_TEST_TMPDIR/vm2repos" --audit --interactive-vars "$BATS_TEST_TMPDIR/vm2repos/target"
    assert_failure
    # Both preconditions fail here (accumulate-then-gate: this target has no GitHub remote at
    # all, so it can't be audited regardless), but the interactive-vars-during-audit message is
    # the one this test actually targets.
    assert_output --partial "not linked to a GitHub remote"
    assert_output --partial "Secrets and variables cannot be interactively set during audit"
}
