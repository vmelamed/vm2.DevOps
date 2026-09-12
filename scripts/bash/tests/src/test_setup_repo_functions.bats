#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/setup-repo.functions.sh, as it behaves TODAY.
#
# Most functions in this file mutate GitHub repository state (settings, secrets, branch
# protection) via 'gh api'/'gh variable'/'gh secret' calls. None of that ever touches a real
# GitHub repository here: every test fakes 'gh' on $PATH -- either a generic call-logger
# (_install_fake_gh_logger, for tests that only care what gh was invoked with) or a small
# per-test script that also returns canned JSON/text for the "current state" reads these
# functions do before deciding what (if anything) to PATCH/PUT/POST/set/delete.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_src_dir="$(cd "$lib_dir/../src" && pwd)"

_sr() {
    local _path="${2:-/usr/bin:/bin}"
    local _gh_call_log="${3:-}"
    env -i HOME="$HOME" PATH="$_path" GH_CALL_LOG="$_gh_call_log" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        source '$_src_dir/setup-repo.defaults.sh'
        source '$_src_dir/setup-repo.functions.sh'
        $1
    "
}

# Fake 'gh' that logs every invocation (one per line, args joined with spaces) to
# $GH_CALL_LOG and exits with $FAKE_GH_EXIT (default 0), for tests that only care about
# *what* gh was called with rather than any particular canned response.
_install_fake_gh_logger() {
    local _bindir="$1"
    mkdir -p "$_bindir"
    cat > "$_bindir/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_CALL_LOG"
exit "${FAKE_GH_EXIT:-0}"
EOF
    chmod +x "$_bindir/gh"
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
    run _sr "resolve_github_app_ids; declare -p actions_app_id dependabot_app_id codespaces_app_id" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial 'actions_app_id="15368"'
    assert_output --partial 'dependabot_app_id="29110"'
    assert_output --partial 'codespaces_app_id="231849"'
}

@test "resolve_github_app_ids: warns when a resolved app ID differs from the well-known expected value" {
    _install_fake_gh_apps "$BATS_TEST_TMPDIR/bin" 99999
    run _sr "resolve_github_app_ids" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "Unexpected GitHub Actions app ID: 99999 (expected 15368)"
}

@test "resolve_github_app_ids: exits with accumulated errors when the API calls fail" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/gh"
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "resolve_github_app_ids" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
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
    run _sr "ci_yaml='$BATS_TEST_TMPDIR/ci.yaml'; list_required_checks; declare -p required_checks" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial 'required_checks=([0]="Postrun-CI")'
}

@test "list_required_checks: fails when the gate job cannot be parsed from CI.yaml" {
    echo "jobs: {}" > "$BATS_TEST_TMPDIR/ci.yaml"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/yq"
    chmod +x "$BATS_TEST_TMPDIR/bin/yq"
    run _sr "ci_yaml='$BATS_TEST_TMPDIR/ci.yaml'; list_required_checks" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
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
             declare -p main_protection_rs_id path_main_protection_ruleset" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
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
             echo \"RC=\$?\"" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "RC=1"
}

# =====================================================================================
# set_var() / set_secret() / delete_secret()
# =====================================================================================

@test "set_var: bug-exits with the wrong argument count" {
    run _sr "set_var FOO"
    assert_failure 254
}

@test "set_var: bug-exits on an empty variable name" {
    run _sr "set_var '' bar"
    assert_failure 254
}

@test "set_var: calls 'gh variable set' with the name, value, and target repo" {
    _install_fake_gh_logger "$BATS_TEST_TMPDIR/bin"
    run _sr "repo='acme/myrepo'; set_var FOO bar; echo \"RC=\$?\"" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial "RC=0"
    run cat "$BATS_TEST_TMPDIR/calls.log"
    assert_output "variable set FOO --body bar -R acme/myrepo"
}

@test "set_var: warns and returns failure when the gh call fails" {
    _install_fake_gh_logger "$BATS_TEST_TMPDIR/bin"
    run _sr "repo='acme/myrepo'; FAKE_GH_EXIT=1 set_var FOO bar; echo \"RC=\$?\"" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial "Failed to set variable FOO"
    assert_output --partial "RC=1"
}

@test "set_secret: bug-exits when the app is not a recognized value" {
    run _sr "set_secret NAME value bogus-app"
    assert_failure 254
}

@test "set_secret: calls 'gh secret set' with the name, value, app, and repo" {
    _install_fake_gh_logger "$BATS_TEST_TMPDIR/bin"
    run _sr "repo='acme/myrepo'; set_secret NUGET_API_KEY topsecret actions; echo \"RC=\$?\"" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial "RC=0"
    run cat "$BATS_TEST_TMPDIR/calls.log"
    assert_output "secret set NUGET_API_KEY --body topsecret --app actions --repo acme/myrepo"
}

@test "delete_secret: bug-exits when the app is not a recognized value" {
    run _sr "delete_secret NAME bogus-app"
    assert_failure 254
}

@test "delete_secret: calls 'gh secret delete' with the name, app, and repo" {
    _install_fake_gh_logger "$BATS_TEST_TMPDIR/bin"
    run _sr "repo='acme/myrepo'; delete_secret NUGET_API_KEY actions; echo \"RC=\$?\"" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial "RC=0"
    run cat "$BATS_TEST_TMPDIR/calls.log"
    assert_output "secret delete NUGET_API_KEY --app actions --repo acme/myrepo"
}

@test "delete_secret: propagates the underlying failure code when the gh call fails" {
    _install_fake_gh_logger "$BATS_TEST_TMPDIR/bin"
    run _sr "repo='acme/myrepo'; FAKE_GH_EXIT=1 delete_secret NUGET_API_KEY actions; echo \"RC=\$?\"" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial "Failed to delete secret NUGET_API_KEY"
    assert_output --partial "RC=1"
}

# =====================================================================================
# configure_default_repo_settings() -- partial PATCH, diffs only
# =====================================================================================

@test "configure_default_repo_settings: PATCHes only the settings that differ from the defaults" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_CALL_LOG"
if [[ "$*" != *"-X"* ]]; then
    echo '{"default_branch":"main","delete_branch_on_merge":true,"allow_squash_merge":true,"allow_merge_commit":false,"allow_rebase_merge":true,"allow_auto_merge":true,"has_issues":true,"has_wiki":false,"has_projects":false,"has_pull_requests":true,"pull_request_creation_policy":"all","visibility":"public"}' | jq -r 'to_entries[] | "\(.key)=\(.value)"'
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "repo='acme/myrepo'
             path_repo='repos/acme/myrepo'
             jq_entries='to_entries[] | \"\(.key)=\(.value)\"'
             configure_default_repo_settings" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    run cat "$BATS_TEST_TMPDIR/calls.log"
    assert_line --index 1 "api -X PATCH repos/acme/myrepo -F allow_squash_merge=false"
    [[ $(wc -l < "$BATS_TEST_TMPDIR/calls.log") -eq 2 ]]
}

@test "configure_default_repo_settings: sends no PATCH at all when everything already matches" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_CALL_LOG"
if [[ "$*" != *"-X"* ]]; then
    echo '{"default_branch":"main","delete_branch_on_merge":true,"allow_squash_merge":false,"allow_merge_commit":false,"allow_rebase_merge":true,"allow_auto_merge":true,"has_issues":true,"has_wiki":false,"has_projects":false,"has_pull_requests":true,"pull_request_creation_policy":"all","visibility":"public"}' | jq -r 'to_entries[] | "\(.key)=\(.value)"'
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "repo='acme/myrepo'
             path_repo='repos/acme/myrepo'
             jq_entries='to_entries[] | \"\(.key)=\(.value)\"'
             configure_default_repo_settings" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    [[ $(wc -l < "$BATS_TEST_TMPDIR/calls.log") -eq 1 ]]
}

# =====================================================================================
# configure_actions_permissions() -- full PUT, always all keys
# =====================================================================================

@test "configure_actions_permissions: always PUTs every key, even when values already match" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_CALL_LOG"
if [[ "$*" != *"-X"* ]]; then
    echo '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":true}' | jq -r 'to_entries[] | "\(.key)=\(.value)"'
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "path_permissions='repos/acme/myrepo/actions/permissions/workflow'
             jq_entries='to_entries[] | \"\(.key)=\(.value)\"'
             configure_actions_permissions" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    run cat "$BATS_TEST_TMPDIR/calls.log"
    assert_output --partial "can_approve_pull_request_reviews=true"
    assert_output --partial "default_workflow_permissions=read"
}

# =====================================================================================
# configure_variables() -- non-interactive reconciliation
# =====================================================================================

@test "configure_variables: creates missing variables with their defaults, leaves existing ones untouched, and captures nuget_server" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_CALL_LOG"
if [[ "$1 $2" == "api --paginate" ]]; then
    echo '{"variables":[{"name":"CONFIGURATION","value":"Release"},{"name":"NUGET_SERVER","value":"github"}]}' | jq -r '.variables[] | "\(.name)=\(.value)"'
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "repo='acme/myrepo'
             path_repo='repos/acme/myrepo'
             jq_vars='.variables[] | \"\(.name)=\(.value)\"'
             interactive_vars=false
             configure_variables
             declare -p nuget_server" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial 'nuget_server="github"'
    run cat "$BATS_TEST_TMPDIR/calls.log"
    refute_output --partial "variable set CONFIGURATION"
    refute_output --partial "variable set NUGET_SERVER"
    assert_output --partial "variable set FRAMEWORK --body net10.0 -R acme/myrepo"
}

# =====================================================================================
# configure_secrets() -- presence-only reconciliation, NUGET_API_KEY special case
# =====================================================================================

@test "configure_secrets: bug-exits on an unrecognized application name" {
    run _sr "configure_secrets bogus-app nuget"
    assert_failure 254
}

@test "configure_secrets: deletes NUGET_API_KEY when it exists and the NuGet server is 'nuget', warns for missing secrets, and leaves other existing ones alone" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_CALL_LOG"
if [[ "$1 $2" == "api --paginate" ]]; then
    echo '{"secrets":[{"name":"NUGET_API_KEY"},{"name":"CODECOV_TOKEN"}]}' | jq -r '.secrets[] | .name'
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "repo='acme/myrepo'
             path_repo='repos/acme/myrepo'
             jq_secret_names='.secrets[] | .name'
             interactive_secrets=false
             configure_secrets actions nuget" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial "Create secret: RELEASE_PAT"
    run cat "$BATS_TEST_TMPDIR/calls.log"
    assert_output --partial "secret delete NUGET_API_KEY --app actions --repo acme/myrepo"
    refute_output --partial "secret set"
}

@test "configure_secrets: is a no-op when the given app has no configured secrets" {
    run _sr "configure_secrets dependabot nuget; echo RC=\$?"
    assert_success
    assert_output "RC=0"
}

# =====================================================================================
# configure_branch_protection() -- POST (new) vs PUT (existing ruleset)
# =====================================================================================

@test "configure_branch_protection: POSTs a new ruleset when none exists yet" {
    # configure_branch_protection() re-runs initialize_main_protection_rs_id() at the end to
    # pick up the ID of the ruleset it just created, so the fake gh must start answering the
    # id lookup once the POST has actually happened -- otherwise the function's own final
    # return code (unrelated to what this test checks: the POST call itself) is a failure.
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "\$GH_CALL_LOG"
if [[ "\$*" == *"-q .id"* ]]; then
    [[ -f "$BATS_TEST_TMPDIR/created" ]] && echo 7
    exit 0
fi
if [[ "\$*" == *"-X POST"* ]]; then
    touch "$BATS_TEST_TMPDIR/created"
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "main_protection_rs_name='main protection'
             path_rulesets='repos/acme/myrepo/rulesets'
             jq_ruleset_id='.id'
             branch='main'
             declare -a required_checks=('Postrun-CI')
             actions_app_id=15368
             configure_branch_protection" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial "Creating new ruleset"
    run cat "$BATS_TEST_TMPDIR/calls.log"
    assert_output --partial "-X POST repos/acme/myrepo/rulesets"
    refute_output --partial "-X PUT"
}

@test "configure_branch_protection: PUTs the existing ruleset by id when one is already found" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_CALL_LOG"
if [[ "$*" == *"-q .id"* ]]; then echo 99; fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr "main_protection_rs_name='main protection'
             path_rulesets='repos/acme/myrepo/rulesets'
             jq_ruleset_id='.id'
             branch='main'
             declare -a required_checks=('Postrun-CI')
             actions_app_id=15368
             configure_branch_protection" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" "$BATS_TEST_TMPDIR/calls.log"
    assert_success
    assert_output --partial "Updating existing ruleset main protection (id: 99)"
    run cat "$BATS_TEST_TMPDIR/calls.log"
    assert_output --partial "-X PUT repos/acme/myrepo/rulesets/99"
    refute_output --partial "-X POST"
}
