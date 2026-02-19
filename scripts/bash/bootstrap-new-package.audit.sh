#!/usr/bin/env bash

declare -xr script_name
declare -xr lib_dir

declare -xr package_name
declare -xr org
declare -xr repo
declare -xr visibility
declare -xr branch
declare -xr configure_only
declare -xr skip_secrets
declare -xr skip_variables
declare -xr audit
declare -xa required_checks

audit_repo()
{
    local pass=0
    local fail=0

    # --- Repo settings ---
    info "Checking repository settings..."
    local repo_json
    repo_json=$(gh api "repos/${repo}" 2>/dev/null) || { error "Cannot read repo settings."; return 1; }

    local -A repo_checks=(
        ["delete_branch_on_merge"]="true"
        ["allow_squash_merge"]="true"
        ["allow_merge_commit"]="false"
        ["allow_rebase_merge"]="false"
        ["allow_auto_merge"]="true"
        ["has_wiki"]="false"
        ["has_projects"]="false"
    )

    local key
    local actual
    for key in "${!repo_checks[@]}"; do
        actual=$(echo "$repo_json" | jq -r ".${key}" || true)
        trace "Repo setting '${key}': actual='${actual}', expected='${repo_checks[$key]}'"
        if [[ "$actual" == "${repo_checks[$key]}" ]]; then
            info "  ✅ '${key}' = '${actual}'"
            (( pass++ ))
        else
            warning "  ❌ '${key}' = '${actual}' (expected: '${repo_checks[$key]}')"
            (( fail++ ))
        fi
    done

    # --- Actions permissions ---
    info "Checking Actions permissions..."
    local actions_json
    actions_json=$(gh api "repos/${repo}/actions/permissions/workflow" 2>/dev/null) || { warning "Cannot read Actions permissions."; }

    if [[ -n "${actions_json:-}" ]]; then
        local default_perms
        default_perms=$(echo "$actions_json" | jq -r '.default_workflow_permissions')
        trace "Actions permissions: actual='${default_perms}', expected='read'"
        if [[ "$default_perms" == "read" ]]; then
            info "  ✅ default_workflow_permissions = read"
            (( pass++ ))
        else
            warning "  ❌ default_workflow_permissions = '${default_perms}' (expected: 'read')"
            (( fail++ ))
        fi
    fi

    # --- Secrets ---
    info "Checking secrets exist..."
    local secrets_json
    secrets_json=$(gh api "repos/${repo}/actions/secrets" 2>/dev/null) || { warning "Cannot read secrets."; }

    if [[ -n "${secrets_json:-}" ]]; then
        local -a expected_secrets=(
            CODECOV_TOKEN BENCHER_API_TOKEN REPORTGENERATOR_LICENSE
            NUGET_API_GITHUB_KEY NUGET_API_NUGET_KEY NUGET_API_KEY RELEASE_PAT
        )
        for secret in "${expected_secrets[@]}"; do
            if echo "$secrets_json" | jq -e ".secrets[] | select(.name == \"${secret}\")" &>/dev/null; then
                info "  ✅ ${secret} exists"
                (( pass++ ))
            else
                warning "  ❌ ${secret} missing"
                (( fail++ ))
            fi
        done
    fi

    # --- Variables ---
    info "Checking variables..."
    local vars_json
    vars_json=$(gh api "repos/${repo}/actions/variables" 2>/dev/null) || { warning "Cannot read variables."; }

    if [[ -n "${vars_json:-}" ]]; then
        local -A expected_vars=(
            ["DOTNET_VERSION"]="10.0.x"
            ["CONFIGURATION"]="Release"
            ["MAX_REGRESSION_PCT"]="20"
            ["MIN_COVERAGE_PCT"]="80"
            ["MINVERTAGPREFIX"]="v"
            ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="preview.0"
            ["NUGET_SERVER"]="github"
            ["SAVE_PACKAGE_ARTIFACTS"]="false"
            ["VERBOSE"]="false"
        )
        for var in "${!expected_vars[@]}"; do
            local actual
            actual=$(echo "$vars_json" | jq -r ".variables[] | select(.name == \"${var}\") | .value" 2>/dev/null)
            if [[ -z "$actual" ]]; then
                warning "  ❌ ${var} missing"
                (( fail++ ))
            elif [[ "$actual" == "${expected_vars[$var]}" ]]; then
                info "  ✅ ${var} = ${actual}"
                (( pass++ ))
            else
                info "  ⚠️  ${var} = ${actual} (default: ${expected_vars[$var]}) — custom value"
                (( pass++ ))  # custom is fine, just informational
            fi
        done
    fi

    # --- Branch protection ---
    info "Checking branch protection for '${branch}'..."
    local bp_json
    bp_json=$(gh api "repos/${repo}/branches/${branch}/protection" 2>/dev/null) || { warning "No branch protection found on '${branch}'."; (( fail++ )); }

    if [[ -n "${bp_json:-}" ]]; then
        local linear
        linear=$(echo "$bp_json" | jq -r '.required_linear_history.enabled // false')
        if [[ "$linear" == "true" ]]; then
            info "  ✅ required_linear_history = true"
            (( pass++ ))
        else
            warning "  ❌ required_linear_history = ${linear} (expected: true)"
            (( fail++ ))
        fi

        local strict
        strict=$(echo "$bp_json" | jq -r '.required_status_checks.strict // false')
        if [[ "$strict" == "true" ]]; then
            info "  ✅ require_up_to_date = true"
            (( pass++ ))
        else
            warning "  ❌ require_up_to_date = ${strict} (expected: true)"
            (( fail++ ))
        fi

        local contexts
        contexts=$(echo "$bp_json" | jq -r '.required_status_checks.contexts[]? // empty' 2>/dev/null)
        detect_required_checks
        for check in "${required_checks[@]}"; do
            if echo "$contexts" | grep -qx "$check"; then
                info "  ✅ required check: ${check}"
                (( pass++ ))
            else
                warning "  ❌ required check missing: ${check}"
                (( fail++ ))
            fi
        done

        local dismiss_stale
        dismiss_stale=$(echo "$bp_json" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')
        if [[ "$dismiss_stale" == "true" ]]; then
            info "  ✅ dismiss_stale_reviews = true"
            (( pass++ ))
        else
            warning "  ❌ dismiss_stale_reviews = ${dismiss_stale} (expected: true)"
            (( fail++ ))
        fi

        local approvals
        approvals=$(echo "$bp_json" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
        if [[ "$approvals" -ge 1 ]]; then
            info "  ✅ required_approving_review_count = ${approvals}"
            (( pass++ ))
        else
            warning "  ❌ required_approving_review_count = ${approvals} (expected: >= 1)"
            (( fail++ ))
        fi
    fi

    # --- Summary ---
    echo ""
    info "Audit complete: ${pass} passed, ${fail} failed."
    if (( fail > 0 )); then
        warning "Run without --audit to fix mismatches (use --configure-only --skip-secrets for existing repos)."
        return 1
    fi
}
