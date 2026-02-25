# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xr repo_name
declare -xr owner
declare -xr repo
declare -xr visibility
declare -xr branch
declare -xr configure_only
declare -xr skip_secrets
declare -xr skip_variables
declare -xr audit
declare -xr force_defaults
declare -xa required_checks

# default values for GitHub vars
declare -xr DEFAULT_DOTNET_VERSION
declare -xr DEFAULT_CONFIGURATION
declare -xr DEFAULT_MAX_REGRESSION_PCT
declare -xr DEFAULT_MIN_COVERAGE_PCT
declare -xr DEFAULT_MINVERTAGPREFIX
declare -xr DEFAULT_MINVERDEFAULTPRERELEASEIDENTIFIERS
declare -xr DEFAULT_NUGET_SERVER
declare -xr DEFAULT_ACTIONS_RUNNER_DEBUG
declare -xr DEFAULT_ACTIONS_STEP_DEBUG
declare -xr DEFAULT_SAVE_PACKAGE_ARTIFACTS
declare -xr DEFAULT_VERBOSE

declare -xr ci_yaml
declare -xr _ci_yaml

declare -xrA repo_settings
declare -xra expected_secrets
declare -xrA default_vars

function audit_repo()
{
    local pass=0
    local fail=0

    # --- Repo settings ---
    info "Checking repository settings..."
    local repo_json
    # shellcheck disable=SC2154 # _ignore is referenced but not assigned.
    repo_json=$(gh api "repos/${repo}" 2>"$_ignore") || { error "Cannot read repo settings."; return 1; }

    local key
    local actual
    for key in "${!repo_settings[@]}"; do
        actual=$(echo "$repo_json" | jq -r ".${key}" || true)
        trace "Repo setting '${key}': actual='${actual}', expected='${repo_settings[$key]}'"
        if [[ "$actual" == "${repo_settings[$key]}" ]]; then
            info "  ✅ '${key}' = '${actual}'"
            (( ++pass ))
        else
            warning "  ❌ '${key}' = '${actual}' (expected: '${repo_settings[$key]}')"
            (( ++fail ))
        fi
    done

    # --- Actions permissions ---
    info "Checking Actions permissions..."
    local actions_json
    actions_json=$(gh api "repos/${repo}/actions/permissions/workflow" 2>"$_ignore") || { error "Cannot read Actions permissions."; return 1; }

    if [[ -n "${actions_json:-}" ]]; then
        local default_perms
        default_perms=$(echo "$actions_json" | jq -r '.default_workflow_permissions')
        trace "Actions permissions: actual='${default_perms}', expected='read'"
        if [[ "$default_perms" == "read" ]]; then
            info "  ✅ default_workflow_permissions = read"
            (( ++pass ))
        else
            warning "  ❌ default_workflow_permissions = '${default_perms}' (expected: 'read')"
            (( ++fail ))
        fi
    fi

    # --- Secrets ---
    info "Checking secrets exist..."
    local secrets_json
    secrets_json=$(gh api "repos/${repo}/actions/secrets" 2>"$_ignore") || { error "Cannot read secrets."; }

    if [[ -n "${secrets_json:-}" ]]; then
        local secret
        for secret in "${expected_secrets[@]}"; do
            trace "Checking for secret: ${secret}"
            if echo "$secrets_json" | jq -e ".secrets[] | select(.name == \"${secret}\")" &>"$_ignore"; then
                info "  ✅ ${secret} exists"
                (( ++pass ))
            else
                warning "  ⚠️ ${secret} missing"
                (( ++fail ))
            fi
        done
    fi

    # --- Variables ---
    info "Checking variables..."
    local vars_json
    vars_json=$(gh api "repos/${repo}/actions/variables" 2>"$_ignore") || { error "Cannot read variables."; return 1; }

    if [[ -n "${vars_json:-}" ]]; then
        for var in "${!default_vars[@]}"; do
            local actual
            actual=$(echo "$vars_json" | jq -r ".variables[] | select(.name == \"${var}\") | .value" 2>"$_ignore")
            if [[ -z "$actual" ]]; then
                warning "  ❌ ${var} missing"
                (( ++fail ))
            elif [[ "$actual" == "${default_vars[$var]}" ]]; then
                info "  ✅ ${var} = ${actual}"
                (( ++pass ))
            else
                info "  ⚠️  ${var} = ${actual} (default: ${default_vars[$var]}) — custom value"
                (( ++pass ))  # custom is fine, just informational
            fi
        done
    fi

    # --- Branch ruleset ---
    info "Checking branch ruleset for '${branch}'..."
    local rulesets_json
    rulesets_json=$(gh api "repos/${repo}/rulesets" 2>"$_ignore") || { warning "Cannot read rulesets."; (( ++fail )); }

    if [[ -n "${rulesets_json:-}" ]]; then
        local ruleset_id
        ruleset_id=$(echo "$rulesets_json" | jq -r '.[] | select(.name == "main protection") | .id // empty' 2>/dev/null)

        if [[ -z "$ruleset_id" ]]; then
            warning "  ❌ No ruleset named 'main protection' found"
            (( ++fail ))
        else
            info "  ✅ Ruleset 'main protection' exists (id: ${ruleset_id})"
            (( ++pass ))

            # Fetch full ruleset details
            local rs_json
            rs_json=$(gh api "repos/${repo}/rulesets/${ruleset_id}" 2>"$_ignore") || { warning "Cannot read ruleset details."; }

            if [[ -n "${rs_json:-}" ]]; then
                # Check enforcement
                local enforcement
                enforcement=$(echo "$rs_json" | jq -r '.enforcement // "disabled"')
                if [[ "$enforcement" == "active" ]]; then
                    info "  ✅ enforcement = active"
                    (( ++pass ))
                else
                    warning "  ❌ enforcement = ${enforcement} (expected: active)"
                    (( ++fail ))
                fi

                # Check bypass actors include Repository Admin (actor_id 5)
                local has_admin_bypass
                has_admin_bypass=$(echo "$rs_json" | jq '[.bypass_actors[] | select(.actor_id == 5 and .actor_type == "RepositoryRole")] | length' 2>/dev/null || echo "0")
                if [[ "$has_admin_bypass" -ge 1 ]]; then
                    info "  ✅ Repository admin bypass configured"
                    (( ++pass ))
                else
                    warning "  ❌ Repository admin bypass missing"
                    (( ++fail ))
                fi

                # Check rules exist
                local has_pull_request has_status_checks has_linear_history has_non_ff has_deletion
                has_pull_request=$(echo "$rs_json" | jq '[.rules[] | select(.type == "pull_request")] | length' 2>/dev/null || echo "0")
                has_status_checks=$(echo "$rs_json" | jq '[.rules[] | select(.type == "required_status_checks")] | length' 2>/dev/null || echo "0")
                has_linear_history=$(echo "$rs_json" | jq '[.rules[] | select(.type == "required_linear_history")] | length' 2>/dev/null || echo "0")
                has_non_ff=$(echo "$rs_json" | jq '[.rules[] | select(.type == "non_fast_forward")] | length' 2>/dev/null || echo "0")
                has_deletion=$(echo "$rs_json" | jq '[.rules[] | select(.type == "deletion")] | length' 2>/dev/null || echo "0")

                local -A rule_checks=(
                    ["pull_request"]="$has_pull_request"
                    ["required_status_checks"]="$has_status_checks"
                    ["required_linear_history"]="$has_linear_history"
                    ["non_fast_forward"]="$has_non_ff"
                    ["deletion"]="$has_deletion"
                )

                local rule
                for rule in "${!rule_checks[@]}"; do
                    if [[ "${rule_checks[$rule]}" -ge 1 ]]; then
                        info "  ✅ rule: ${rule}"
                        (( ++pass ))
                    else
                        warning "  ❌ rule missing: ${rule}"
                        (( ++fail ))
                    fi
                done

                # Check dismiss stale reviews
                local dismiss_stale
                dismiss_stale=$(echo "$rs_json" | jq -r '.rules[] | select(.type == "pull_request") | .parameters.dismiss_stale_reviews_on_push // false' 2>/dev/null)
                if [[ "$dismiss_stale" == "true" ]]; then
                    info "  ✅ dismiss_stale_reviews_on_push = true"
                    (( ++pass ))
                else
                    warning "  ❌ dismiss_stale_reviews_on_push = ${dismiss_stale:-missing} (expected: true)"
                    (( ++fail ))
                fi

                # Check required status checks include detected checks
                detect_required_checks
                local configured_checks
                configured_checks=$(echo "$rs_json" | jq -r '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context' 2>/dev/null || true)
                for check in "${required_checks[@]}"; do
                    if echo "$configured_checks" | grep -qx "$check"; then
                        info "  ✅ required check: ${check}"
                        (( ++pass ))
                    else
                        warning "  ❌ required check missing: ${check}"
                        (( ++fail ))
                    fi
                done
            fi
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
