# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x _ignore
declare -x script_name
declare -x lib_dir

declare -x repo_name
declare -x owner
declare -x repo
declare -x visibility
declare -x branch
declare -x audit
declare -x force_defaults
declare -x main_protection_rs_name

declare -xri admin_role_id
declare -xr secret_placeholder
declare -xrA default_repo_settings
declare -xra default_repo_settings_order
declare -xrA default_secrets
declare -xrA default_vars
declare -xrA default_ruleset
declare -xra default_ruleset_order

declare -x ci_yaml
declare -x _ci_yaml

declare -xa required_checks
declare -xi github_actions_app_id
declare -x enter_secrets

declare -xr github_url_regex
declare -xri url_authority
declare -xri url_owner
declare -xri url_name

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository exists, it is a git repository, and is at or ahead of the latest stable tag.
# Parameters:
#   $1: repository name (e.g. "vm2.DevOps")
# Returns:
#   Exit code:
#     0 - if the repository exists and meets the above criteria, or
#     2 - if the repository is invalid or does not meet the criteria
# Environment variables:
#   vm2_repos:
#     the parent directory where the repository is expected to have been cloned to, e.g. $VM2_REPOS or "$HOME/repos/vm2"
# Dependencies:
#   git CLI (functions root_working_tree, is_on_or_after_latest_stable_tag)
# Usage:
#   validate_source_repo "vm2.DevOps"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function validate_source_repo()
{
    if [[ $# -lt 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires at least 1 argument: the name of a repository."
        return 2
    fi

    local repo_name=$1
    local dir="${vm2_repos}/${repo_name}"

    [[ -d "${dir}" ]] || error "The '${repo_name}' repository was not cloned or is not under ${vm2_repos}."

    if [[ "$dir" == $(root_working_tree "$dir") ]]; then
        is_on_or_after_latest_stable_tag "$dir" "$semverTagReleaseRegex" || error "The HEAD of the '${repo_name}' repository is before the latest stable tag. Please synchronize."
    else
        confirm "The ${repo_name} repository at '$dir' is not a git repository. Do you want to continue?" "n" || error "The ${repo_name} repository at '$dir' is not a git repository."
    fi
}

function resolve_github_actions_app_id()
{
    # Resolve the GitHub Actions app ID dynamically via the API.
    # Used to pin required status checks to GitHub Actions specifically.
    github_actions_app_id=$(gh api apps/github-actions --jq '.id' 2>"$_ignore") || error "Failed to resolve GitHub Actions app ID from the API."
    exit_if_has_errors
    trace "GitHub Actions app ID: ${github_actions_app_id}"
    [[ "$github_actions_app_id" == "15368" ]] || warning "Unexpected GitHub Actions app ID: ${github_actions_app_id} (expected 15368). Required status check matching may not work correctly."
}

function detect_required_checks()
{
    # With reusable workflows + matrix strategies, GitHub Actions produces check names that include the workflow prefix, matrix
    # params, inner job names, and event suffixes — making them impossible to predict for branch protection rules. Instead, each
    # CI.yaml has a lightweight gate job that depends on all other jobs and reports a single, stable check name.
    #
    # The GitHub UI decorates check names as "Workflow / JobName (event)" but the check-runs API returns bare names and ruleset
    # matching uses the bare check-run name field. So we extract just the gate job's `name:` property from CI.yaml.
    local gate_job
    local gate_name

    # Find the gate job: look for postrun-ci first, fall back to ci-gate
    gate_job=$(yq -r '.jobs | keys[] | select(test("postrun|ci-gate"))' "$ci_yaml" | head -n 1) || error "Failed to parse gate job from CI.yaml."
    gate_name=$(yq -r ".jobs.${gate_job:-postrun-ci}.name" "$ci_yaml")                          || error "Failed to parse gate job name from CI.yaml."
    exit_if_has_errors

    required_checks+=(
        "${gate_name}"
    )

    declare -xra required_checks

    trace "Required checks: ${required_checks[*]}"
}

function configure_default_repo_settings()
{
    info "Configuring repository settings..."
    local -a rs
    for key in "${!default_repo_settings[@]}"; do
        rs+=("-f ${key}=${default_repo_settings[$key]}")
    done
    execute gh api -X PATCH "repos/${repo}" "${rs[@]}" >"$_ignore"
    info "Repository settings configured."
}

declare -xrA default_repo_permissions=(
    ["default_workflow_permissions"]="read"
    ["can_approve_pull_request_reviews"]=false
)

function configure_actions_permissions()
{
    info "Configuring Actions workflow permissions..."
    if execute gh api -X PUT "repos/${repo}/actions/permissions/workflow" -H "Accept: application/vnd.github+json" \
        -f default_workflow_permissions=read \
        >"$_ignore"; then
        info "Configured Actions workflow permissions (GITHUB_TOKEN default=read)."
    else
        warning "Could not configure Actions workflow permissions (possibly restricted by owner policy)."
    fi
}

function configure_secrets()
{
    # get the names of the existing secrets
    local -a existing_secrets
    while IFS='=' read -r name; do
        existing_secrets+=("$name")
    done < <(gh api "repos/${repo}/actions/secrets" -q '.secrets[] | .name')

    info "Configuring repository secrets..."
    local placeholders=0    # number of secrets configured with placeholder values
    local name      # of a secret
    local value     # of a secret
    local exists    # whether the $name secret already exists on GitHub
    for name in "${!default_secrets[@]}"; do
        is_in "$name" "${existing_secrets[@]}" && exists=true || exists=false
        $exists && ! "$enter_secrets" && continue # name exists and we are not entering secrets - continue with the next secret

        # get the value for the secret or use the placeholder if we are not entering secrets
        $enter_secrets && value=$(enter_value "Enter value for secret ${name}: " secret_placeholder true validate_secret) ||
                          value=$secret_placeholder

        if [[ $value != "$secret_placeholder" ]] || ! $exists; then
            # send the new value to GitHub if it is not a placeholder or if it does not exist yet (50% likely - with default placeholder)
            execute gh secret set "$name" --body "$value" -R "$repo" >"$_ignore"
            trace "Set secret: ${name}"
            [[ $value == "$secret_placeholder" ]] && (( ++placeholders ))
        fi
    done

    if (( placeholders > 0 )); then
        warning "${placeholders} secrets configured with placeholder values — you must update them with real values."
    fi
}

function configure_variables()
{
    info "Configuring repository variables..."

    # Get existing variables as name=value pairs
    local -A existing_vars
    local name value

    while IFS='=' read -r name value; do
        existing_vars["$name"]="$value"
    done < <(gh variable list -R "$repo" --json name,value -q '.[] | "\(.name)=\(.value)"')

    local default_value=""
    local skipped=0
    local added=0
    local exists
    for name in "${!default_vars[@]}"; do
        default_value="${default_vars[$name]}"
        is_in "$name" "${!existing_vars[@]}" && exists=true || exists=false

        if "$exists"; then
            value="${existing_vars[$name]}"
            [[ $value == "$default_value" ]] && continue
            if "$force_defaults"; then
                if ! confirm "Variable '${name}' — already set to '${existing_vars[$name]}' (differs from the default '${default_value}'). Do you want to set it to the default?" "n"; then
                    (( ++skipped ))
                    continue
                fi
            else
                (( ++skipped ))
                continue
            fi
        else
            (( ++added ))
        fi
        value="$default_value"
        execute gh variable set "$name" --body "$value" -R "$repo" >"$_ignore"
        trace "Set variable: ${name}=${value}"
    done

    if (( skipped > 0 )); then
        warning "${skipped} variable(s) set to non-default value."
    fi
    info "Added ${added} variables."
}

function configure_branch_protection()
{
    info "Configuring branch ruleset for '${branch}'..."

    # Build required status checks array
    local status_checks_json=""
    if [[ ${#required_checks[@]} -gt 0 ]]; then
        local entries=()
        for check in "${required_checks[@]}"; do
            entries+=("{\"context\":\"${check}\",\"integration_id\":${github_actions_app_id}}")
        done
        local IFS=','
        status_checks_json="${entries[*]}"
        status_checks_json="[$status_checks_json]"
    fi

    # Check if a ruleset named "main protection" already exists
    local existing_id
    existing_id=$(gh api "repos/${repo}/rulesets" 2>"$_ignore" \
        | jq -r '.[] | select(.name == "'"${main_protection_rs_name}"'") | .id // empty' 2>"$_ignore" || true)

    local method="POST"
    local endpoint="repos/${repo}/rulesets"
    if [[ -n "$existing_id" ]]; then
        method="PUT"
        endpoint="repos/${repo}/rulesets/${existing_id}"
        info "Updating existing ruleset (id: ${existing_id})..."
    fi

    execute gh api -X "${method}" "${endpoint}" \
        -H "Accept: application/vnd.github+json" \
        --input - >"$_ignore" <<JSON
{
    "name": "$main_protection_rs_name",
    "target": "branch",
    "enforcement": "active",
    "conditions": {
        "ref_name": {
            "include": ["refs/heads/${branch}"],
            "exclude": []
        }
    },
    "bypass_actors": [
        {
            "actor_id": 5,
            "actor_type": "RepositoryRole",
            "bypass_mode": "always"
        }
    ],
    "rules": [
        {
            "type": "deletion"
        },
        {
            "type": "non_fast_forward"
        },
        {
            "type": "pull_request",
            "parameters": {
                "allowed_merge_methods": [
                    "rebase"
                ],
                "dismiss_stale_reviews_on_push": true,
                "required_approving_review_count": 0,
                "required_reviewers": [],
                "require_code_owner_review": false,
                "require_last_push_approval": false,
                "required_review_thread_resolution": true
            }
        },
        {
            "type": "required_status_checks",
            "parameters": {
                "do_not_enforce_on_create": true,
                "strict_required_status_checks_policy": true,
                "required_status_checks": ${status_checks_json}
            }
        },
        {
            "type": "required_linear_history"
        }
    ]
}
JSON
    info "Branch ruleset configured."
}
