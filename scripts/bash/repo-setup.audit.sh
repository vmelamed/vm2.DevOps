# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154

declare -x script_name
declare -x lib_dir

declare -x repo_name
declare -x owner
declare -x repo
declare -x visibility
declare -x branch
declare -x configure_only
declare -x skip_secrets
declare -x skip_variables
declare -x audit
declare -x force_defaults
declare -x required_checks

declare -x ci_yaml
declare -x _ci_yaml

declare -xrA repo_settings
declare -xrA expected_secrets
declare -xrA vars_defaults

declare -x errors

declare -r jq_transform_entries='to_entries[] | "\(.key)=\(.value)"'
declare -r jq_transform_secrets=".secrets[] | \"\(.name)=$masked\""
declare -r jq_transform_vars='.variables[] | "\(.name)=\(.value)"'
declare -r jq_ruleset_id='.[] | select(.name == "'"$main_protection_rs_name"'") | .id // empty'
declare -r jq_has_admin_bypass_rule='[.bypass_actors[] | select(.actor_id == '"$admin_role_id"' and .actor_type == "RepositoryRole")] | length'
declare -r jq_rulest_checks='{
        pull_request:                         [.rules[] | select(.type == "pull_request")]            | length,
        required_status_checks:               [.rules[] | select(.type == "required_status_checks")]  | length,
        required_linear_history:              [.rules[] | select(.type == "required_linear_history")] | length,
        non_fast_forward:                     [.rules[] | select(.type == "non_fast_forward")]        | length,
        deletion:                             [.rules[] | select(.type == "deletion")]                | length,
        dismiss_stale_reviews_on_push:        [.rules[] | select(.type == "pull_request" and
                                                                 .parameters.dismiss_stale_reviews_on_push)] | length,
        required_status_check_context:        [.rules[] | select(.type == "required_status_checks") |
                                                                 .parameters.required_status_checks[] |
                                                                    select(
                                                                        .context == "'"$required_status_check_context"'" and
                                                                        .integration_id == '"$github_actions_app_id"')] | length
} | to_entries[] | "\(.key)=\(.value)"'

function audit_repo()
{
    local -i pass=0 miss=0 errs=0
    local -i p=0 m=0 e=0
    local compare_settings_results=""

    echo "ℹ️ Audit"

    # --- Repo settings ---
    echo "  Repository settings:"
    compare_settings repo_settings "repos/${repo}" "$jq_transform_entries" compare_settings_results
    read -r p m e <<< "$compare_settings_results"
    (( pass += p, miss += m, errs += e, 1 ))

    # --- Actions permissions ---
    echo "  ℹ️ Actions permissions:"
    compare_settings repo_permissions "repos/${repo}/actions/permissions/workflow" "$jq_transform_entries" compare_settings_results
    read -r p m e <<< "$compare_settings_results"
    (( pass += p, miss += m, errs += e, 1 ))

    # --- Secrets ---
    echo "  ℹ️ Secrets:"
    compare_settings expected_secrets "repos/${repo}/actions/secrets" "$jq_transform_secrets" compare_settings_results
    read -r p m e <<< "$compare_settings_results"
    (( pass += p, miss += m, errs += e, 1 ))

    # --- Variables ---
    echo "  ℹ️ Variables:"
    compare_settings vars_defaults "repos/${repo}/actions/variables" "$jq_transform_vars" compare_settings_results
    read -r p m e <<< "$compare_settings_results"
    (( pass += p, miss += m, errs += e, 1 ))

    # --- Branch ruleset ---
    echo "  ℹ️ Ruleset for branch '${branch}':"
    local rulesets_json
    rulesets_json=$(gh api "repos/${repo}/rulesets") || { warning "Could not read the rulesets."; (( ++fail )); }

    if [[ -z "${rulesets_json:-}" ]]; then
        error "Could not read the repository rulesets."
        (( ++errs ))
        exit 1
    fi

    local ruleset_id
    ruleset_id=$(jq -r "$jq_ruleset_id" <<< "$rulesets_json" 2>"$_ignore")

    [[ -z "$ruleset_id" ]] && { error "No ruleset named '$main_protection_rs_name' found."; exit 1; }

    printf "      ✅  %-32s => %s\n" "Ruleset" "'$main_protection_rs_name' exists (id: ${ruleset_id})"
    (( ++pass ))

    # Fetch full ruleset details
    local ruleset_json
    ruleset_json=$(gh api "repos/${repo}/rulesets/${ruleset_id}") || {
        error "Could not read the ruleset details."
        exit 2
    }

    # Check enforcement
    local enforcement
    enforcement=$(jq -r '.enforcement // "disabled"' <<< "$ruleset_json")
    if [[ "$enforcement" == "active" ]]; then
        printf "      ✅  %-32s => %s\n" "Enforcement" "$enforcement"
        (( ++pass ))
    else
        printf "      ❌  %-32s => %s (expected: active)\n" "Enforcement" "$enforcement"
        (( ++errs ))
    fi

    # Check bypass actors include Repository Admin (actor_id 5)
    local has_admin_bypass
    has_admin_bypass=$(jq "$jq_has_admin_bypass_rule" <<< "$ruleset_json" 2>"$_ignore" || echo "0")
    if [[ "$has_admin_bypass" -ge 1 ]]; then
        printf "      ✅  %-32s => %s\n" "Repository admin bypass" "configured"
        (( ++pass ))
    else
        printf "      ❌  %-32s => %s\n" "Repository admin bypass" "missing"
        (( ++errs ))
    fi

    # Check if rules exist
    local -A rule_checks
    while IFS='=' read -r rule count; do
        rule_checks["$rule"]="$count"
    done < <(jq -r "$jq_rulest_checks" <<< "$ruleset_json")

    local rule
    for rule in "${!rule_checks[@]}"; do
        if [[ "${rule_checks["${rule}"]}" -ge 1 ]]; then
            printf "      ✅  %-32s => %s\n" "${rule}" "exists"
            (( ++pass ))
        else
            printf "      ❌  %-32s => %s\n" "${rule}'" "missing"
            (( ++errs ))
        fi
    done

    # --- Summary ---
    printf "
──────────────────────
ℹ️  Audit complete:
    ✅  passed:    %3d
    ❔  different: %3d
    ❌  missing:   %3d\n" "$pass" "$miss" "$errs"
    if (( errs > 0 )); then
        echo
        echo "❌  Run with '--configure-only' and '--skip-secrets' to fix discrepancies."
    fi
    return 0
}
