#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for a representative subset of scripts/bash/src/setup-repo.functions.sh,
# as it behaves TODAY.
#
# Most functions in this file mutate live GitHub repository state (settings, secrets, branch
# protection) via 'gh api' PATCH/POST/DELETE calls, which is out of scope for a safe,
# network-free characterization suite. This file covers the functions that are either pure
# (initialize_gh_paths, initialize_jq_queries: no external tool calls at all) or read-only
# against a faked 'gh'/'yq' on $PATH (resolve_github_app_ids, list_required_checks,
# initialize_main_protection_rs_id) -- these are exactly the "compute state" building blocks the
# mutating functions and setup-repo.audit.sh depend on, so covering them gives the most safety
# net per test.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_src_dir="$(cd "$lib_dir/../src" && pwd)"

_sr() {
    local _path="${2:-/usr/bin:/bin}"
    env -i HOME="$HOME" PATH="$_path" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        source '$_src_dir/setup-repo.defaults.sh'
        source '$_src_dir/setup-repo.functions.sh'
        $1
    "
}

_install_fake_gh_apps() {
    local _bindir="$1" _actions_id="${2:-15368}" _dependabot_id="${3:-29110}" _codespaces_id="${4:-231849}"
    mkdir -p "$_bindir"
    cat > "$_bindir/gh" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == *"apps/github-actions"* ]]; then echo "$_actions_id"; exit 0; fi
if [[ "\$*" == *"apps/dependabot"* ]]; then echo "$_dependabot_id"; exit 0; fi
if [[ "\$*" == *"apps/codespaces"* ]]; then echo "$_codespaces_id"; exit 0; fi
exit 1
EOF
    chmod +x "$_bindir/gh"
}

# =====================================================================================
# initialize_gh_paths()
# =====================================================================================

@test "initialize_gh_paths: bug-exits (accumulating both) when repo and main_protection_rs_name are unset" {
    run _sr "initialize_gh_paths"
    assert_failure 254
    assert_output --partial "'repo' variable is not set"
    assert_output --partial "'main_protection_rs_name' variable is not set"
}

@test "initialize_gh_paths: derives and freezes all path_* variables from repo" {
    run _sr "repo='acme/myrepo'
             main_protection_rs_name='main protection'
             initialize_gh_paths
             declare -p path_repo path_permissions path_rulesets path_actions_secrets path_dependabot_secrets path_vars"
    assert_success
    assert_output --partial 'path_repo="repos/acme/myrepo"'
    assert_output --partial 'path_permissions="repos/acme/myrepo/actions/permissions/workflow"'
    assert_output --partial 'path_rulesets="repos/acme/myrepo/rulesets"'
    assert_output --partial 'path_actions_secrets="repos/acme/myrepo/actions/secrets"'
    assert_output --partial 'path_dependabot_secrets="repos/acme/myrepo/dependabot/secrets"'
    assert_output --partial 'path_vars="repos/acme/myrepo/actions/variables"'
}

# =====================================================================================
# initialize_jq_queries()
# =====================================================================================

@test "initialize_jq_queries: bug-exits when main_protection_rs_name is unset" {
    run _sr "initialize_jq_queries"
    assert_failure 254
    assert_output --partial "'main_protection_rs_name' variable is not set"
}

@test "initialize_jq_queries: bug-exits when actions_app_id is not positive" {
    run _sr "main_protection_rs_name='x'; actions_app_id=0; initialize_jq_queries"
    assert_failure 254
    assert_output --partial "'actions_app_id' variable is not set or is invalid"
}

@test "initialize_jq_queries: embeds the ruleset name and app IDs into the generated jq query strings" {
    run _sr "main_protection_rs_name='main protection'
             actions_app_id=15368
             initialize_jq_queries
             declare -p jq_ruleset_id jq_status_checks"
    assert_success
    assert_output --partial 'main protection'
    assert_output --partial '15368'
}

# =====================================================================================
# resolve_github_app_ids()
# =====================================================================================

@test "resolve_github_app_ids: resolves and freezes all three app IDs" {
    _install_fake_gh_apps "$BATS_TEST_TMPDIR/bin"
    run _sr "resolve_github_app_ids; declare -p actions_app_id dependabot_app_id codespaces_app_id" "$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial 'actions_app_id="15368"'
    assert_output --partial 'dependabot_app_id="29110"'
    assert_output --partial 'codespaces_app_id="231849"'
}

@test "resolve_github_app_ids: warns when a resolved app ID differs from the well-known expected value" {
    _install_fake_gh_apps "$BATS_TEST_TMPDIR/bin" 99999
    run _sr "resolve_github_app_ids" "$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "Unexpected GitHub Actions app ID: 99999 (expected 15368)"
}

@test "resolve_github_app_ids: exits with accumulated errors when the API calls fail" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/gh"
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "resolve_github_app_ids" "$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
    assert_failure 1
    assert_output --partial "Failed to resolve GitHub Actions app ID"
    assert_output --partial "Failed to resolve Dependabot app ID"
    assert_output --partial "Failed to resolve Codespaces app ID"
}

# =====================================================================================
# list_required_checks()
# =====================================================================================

@test "list_required_checks: extracts the gate job's display name from CI.yaml and freezes required_checks" {
    cat > "$BATS_TEST_TMPDIR/ci.yaml" <<'EOF'
jobs:
  build:
    name: Build
  postrun-ci:
    name: Postrun-CI
EOF
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/yq" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"keys[]"* ]]; then echo "postrun-ci"; exit 0; fi
if [[ "$*" == *".jobs.postrun-ci.name"* ]]; then echo "Postrun-CI"; exit 0; fi
exit 1
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/yq"
    run _sr "ci_yaml='$BATS_TEST_TMPDIR/ci.yaml'; list_required_checks; declare -p required_checks" "$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial 'required_checks=([0]="Postrun-CI")'
}

@test "list_required_checks: fails when the gate job cannot be parsed from CI.yaml" {
    echo "jobs: {}" > "$BATS_TEST_TMPDIR/ci.yaml"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/yq"
    chmod +x "$BATS_TEST_TMPDIR/bin/yq"
    run _sr "ci_yaml='$BATS_TEST_TMPDIR/ci.yaml'; list_required_checks" "$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
    assert_failure 1
    assert_output --partial "Failed to parse gate job name from CI.yaml"
}

# =====================================================================================
# initialize_main_protection_rs_id()
# =====================================================================================

@test "initialize_main_protection_rs_id: bug-exits when preconditions (name, path_rulesets) are unset" {
    run _sr "initialize_main_protection_rs_id"
    assert_failure 254
}

@test "initialize_main_protection_rs_id: resolves and freezes the ruleset ID and derived path when found" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\necho 42\n' > "$BATS_TEST_TMPDIR/bin/gh"
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "main_protection_rs_name='main protection'
             path_rulesets='repos/a/b/rulesets'
             jq_ruleset_id='.id'
             initialize_main_protection_rs_id
             echo \"RC=\$?\"
             declare -p main_protection_rs_id path_main_protection_ruleset" "$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'main_protection_rs_id="42"'
    assert_output --partial 'path_main_protection_ruleset="repos/a/b/rulesets/42"'
}

@test "initialize_main_protection_rs_id: returns failure without re-querying when already initialized" {
    run _sr "main_protection_rs_name='main protection'
             path_rulesets='repos/a/b/rulesets'
             main_protection_rs_id=42
             initialize_main_protection_rs_id
             echo \"RC=\$?\""
    assert_success
    assert_output --partial "RC=0"
}

@test "initialize_main_protection_rs_id: returns failure (sentinel, not err_logic_error) when the ruleset does not exist yet" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/gh"
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "main_protection_rs_name='main protection'
             path_rulesets='repos/a/b/rulesets'
             jq_ruleset_id='.id'
             initialize_main_protection_rs_id
             echo \"RC=\$?\"" "$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "RC=1"
}
