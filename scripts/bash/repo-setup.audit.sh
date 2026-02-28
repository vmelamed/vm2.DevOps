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

declare -xr ci_yaml
declare -xr _ci_yaml

declare -xrA repo_settings
declare -xra vars_defaults
declare -xra expected_secrets
declare -xrA vars_defaults

declare -x errors

declare -xr jq_transform_default='to_entries[] | "\(.key)=\(.value)"'

function compare_settings()
{
    local -n expecteds="$1"
    local hq_path="$2"
    local jq_transform="${3:-jq_transform_default}"
    local json
    if ! json=$(gh api "$hq_path"); then
        error "Failed to fetch data from GitHub API: $hq_path"
        return 1
    fi

    local -A actuals
    local key actual expected
    local -i pass=0 miss=0 errs=0

    while IFS='=' read -r key actual; do
        actuals["$key"]="$actual"
    done < <(jq -r "$jq_transform" <<< "$json")

    for key in "${!expecteds[@]}"; do
        expected="${expecteds[$key]}"
        actual="${actuals[$key]}"
        if [[ ! -v actuals[$key] ]]; then
            error "'${key}' is missing (expected: '${expected}')"
            (( errors--, ++errs ))  # unchanged the global errors count
        else
            if [[ "$actual" != "$expected" ]]; then
                warning "'${key}' => '${actual}' (expected: '${expected}')"
                ((++miss))
            else
                info "'${key}' => '${actual}'"
                ((++pass))
            fi
        fi
    done
    echo -e "$pass $miss $errs"
    return 0
}

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
function audit_repo()
{
    local pass=0
    local miss=0
    local errs=0
    local p=0
    local m=0
    local e=0

    # --- Repo settings ---
    info "Checking repository settings..."
    read -r p m e < <(compare_settings repo_settings "repos/${repo}")
    (( pass += p, miss += m, errs += e ))

    # --- Actions permissions ---
    info "Checking Actions permissions..."
    read -r p m e < <(compare_settings repo_permissions "repos/${repo}/actions/permissions/workflow")
    (( pass += p, miss += m, errs += e ))

    # --- Secrets ---
    info "Checking secrets exist..."
    read -r p m e < <(compare_settings expected_secrets "repos/${repo}/actions/secrets")
    (( pass += p, miss += m, errs += e ))

    # --- Variables ---
    info "Checking variables..."
    read -r p m e < <(compare_settings vars_defaults "repos/${repo}/actions/variables" '.variables[] | "\(.name)=\(.value)"')
    (( pass += p, miss += m, errs += e ))

    # --- Branch ruleset ---
    info "Checking branch ruleset for '${branch}'..."
    local rulesets_json
    rulesets_json=$(gh api "repos/${repo}/rulesets") || { warning "Could not read the rulesets."; (( ++fail )); }

    if [[ -z "${rulesets_json:-}" ]]; then
        error "Could not read the repository rulesets."
        (( ++errs ))
        exit 1
    fi

    local ruleset_id
    ruleset_id=$(jq -r '.[] | select(.name == "'"$main_protection_rs_name"'") | .id // empty' <<< "$rulesets_json" 2>"$_ignore")

    [[ -z "$ruleset_id" ]] && { error "No ruleset named '$main_protection_rs_name' found."; exit 1; }

    info "Ruleset '$main_protection_rs_name' exists (id: ${ruleset_id})"
    (( ++pass ))

    # Fetch full ruleset details
    local rs_json
    rs_json=$(gh api "repos/${repo}/rulesets/${ruleset_id}") || { error "Could not read the ruleset details."; exit 1; }

    # Check enforcement
    local enforcement
    enforcement=$(jq -r '.enforcement // "disabled"' <<< "$rs_json")
    if [[ "$enforcement" == "active" ]]; then
        info "enforcement = active"
        (( ++pass ))
    else
        error "enforcement = ${enforcement} (expected: active)"
        (( ++errs ))
    fi

    # Check bypass actors include Repository Admin (actor_id 5)
    local has_admin_bypass
    has_admin_bypass=$(jq '[.bypass_actors[] | select(.actor_id == '"$admin_role"' and .actor_type == "RepositoryRole")] | length' <<< "$rs_json" 2>"$_ignore" || echo "0")
    if [[ "$has_admin_bypass" -ge 1 ]]; then
        info "Repository admin bypass configured"
        (( ++pass ))
    else
        error "  ❌ Repository admin bypass missing"
        (( ++errs ))
    fi

    # Check rules exist
    local -A rule_checks
    while IFS='=' read -r rule count; do
        rule_checks["$rule"]="$count"
    done < <(jq -r '{
        pull_request: [.rules[] | select(.type == "pull_request")] | length,
        required_status_checks: [.rules[] | select(.type == "required_status_checks")] | length,
        required_linear_history: [.rules[] | select(.type == "required_linear_history")] | length,
        non_fast_forward: [.rules[] | select(.type == "non_fast_forward")] | length,
        deletion: [.rules[] | select(.type == "deletion")] | length,
        dismiss_stale_reviews_on_push: [.rules[] | select(.type == "pull_request") | .parameters.dismiss_stale_reviews_on_push] // false
        required_status_checks: .rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context
    } | to_entries[] | "\(.key)=\(.value)"' <<< "$rs_json")

    local rule
    for rule in "${!rule_checks[@]}"; do
        if [[ "${rule_checks[$rule]}" -ge 1 ]]; then
            info "  ✅ rule: ${rule}"
            (( ++pass ))
        else
            warning "  ❌ missed rule: ${rule}"
            (( ++fail ))
        fi
    done

    # Check dismiss stale reviews
    local dismiss_stale
    dismiss_stale=$(jq -r '.rules[] | select(.type == "pull_request") | .parameters.dismiss_stale_reviews_on_push // false' <<< "$rs_json" 2>"$_ignore")
    if [[ "$dismiss_stale" == "true" ]]; then
        info "  ✅ dismiss_stale_reviews_on_push = true"
        (( ++pass ))
    else
        warning "  ❌ dismiss_stale_reviews_on_push = ${dismiss_stale:-missing} (expected: true)"
        (( ++fail ))
    fi

    # Check required status checks include detected checks
    local configured_checks
    configured_checks=$(jq -r '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context' <<< "$rs_json" 2>"$_ignore" || true)
    for check in "${required_checks[@]}"; do
        if echo "$configured_checks" | grep -qx "$check"; then
            info "  ✅ required check: ${check}"
            (( ++pass ))
        else
            warning "  ❌ required check missing: ${check}"
            (( ++fail ))
        fi
    done

    # --- Summary ---
    echo ""
    info "Audit complete: ${pass}: passed, ${miss}: value is different from default, ${errs}: errors."
    if (( errs > 0 )); then
        warning "Run without --audit to fix mismatches (use --configure-only --skip-secrets for existing repos)."
        return 1
    fi
}
