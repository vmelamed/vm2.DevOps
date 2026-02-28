# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x _ignore
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
declare -xr main_protection_rs_name

declare -xr ci_yaml
declare -xr _ci_yaml

declare -xrA repo_settings=(
    ["delete_branch_on_merge"]="true"
    ["allow_squash_merge"]="false"
    ["allow_merge_commit"]="true"
    ["allow_rebase_merge"]="false"
    ["allow_auto_merge"]="true"
    ["has_wiki"]="false"
    ["has_projects"]="false"
)

declare -xrA repo_permissions=(
    ["default_workflow_permissions"]="read"
    ["can_approve_pull_request_reviews"]="false"
)

declare -xrA vars_defaults=(
    ["DOTNET_VERSION"]="10.0.x"
    ["CONFIGURATION"]="Release"
    ["MAX_REGRESSION_PCT"]="20"
    ["MIN_COVERAGE_PCT"]="80"
    ["MINVERTAGPREFIX"]="v"
    ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="preview.0"
    ["NUGET_SERVER"]="github"
    ["ACTIONS_RUNNER_DEBUG"]="false"
    ["ACTIONS_STEP_DEBUG"]="false"
    ["SAVE_PACKAGE_ARTIFACTS"]="false"
)

declare -xra expected_secrets=(
    CODECOV_TOKEN
    BENCHER_API_TOKEN
    REPORTGENERATOR_LICENSE
    RELEASE_PAT
    NUGET_API_GITHUB_KEY
    NUGET_API_NUGET_KEY
    NUGET_API_KEY
)

declare -xrA projects_jobs=(
    ["BUILD_PROJECTS"]="build"
    ["TEST_PROJECTS"]="test"
    ["BENCHMARK_PROJECTS"]="benchmarks"
    ["PACKAGE_PROJECTS"]="pack"
)

declare -xa required_checks

# ------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------
function detect_required_checks()
{
    local check_top build_source projects

    check_top=$(yq -r .jobs.call-ci.name "$ci_yaml" || {
        error "Failed to parse CI.yaml workflow file to detect required checks. Make sure the file exists and is valid YAML." >&2;
    })
    build_source=$(yq -r .jobs.build.name "$_ci_yaml" || {
        error "Failed to parse CI.yaml workflow file to detect required checks. Make sure the file exists and is valid YAML." >&2;
    })

    exit_if_has_errors

    required_checks+=("${check_top} / ${build_source}")

    for projects_key in "${!projects_jobs[@]}"; do
        local job_name="${projects_jobs[$projects_key]}"
        projects=$(yq -r ".env.${projects_key} // \"\"" "$ci_yaml") || error "Failed to parse CI.yaml for env key '${projects_key}'." >&2
        if [[ -n "$projects" && "$projects" != "null" && "$projects" != "[]" ]]; then
            local source_name
            source_name=$(yq -r ".jobs.${job_name}.name" "$_ci_yaml") || {
                warning "Failed to parse _ci.yaml for job '${job_name}'." >&2
            }
            required_checks+=("${check_top} / ${source_name}")
        fi
    done
    trace "Required checks: ${required_checks[*]}"
}

function configure_repo_settings()
{
    info "Configuring repository settings..."
    local -a rs
    for key in "${!repo_settings[@]}"; do
        rs+=("-f ${key}=${repo_settings[$key]}")
    done
    execute gh api -X PATCH "repos/${repo}" "${rs[@]}" >"$_ignore"
    info "Repository settings configured."
}

function configure_actions_permissions()
{
    info "Configuring Actions workflow permissions..."
    if execute gh api -X PUT "repos/${repo}/actions/permissions/workflow" \
        -H "Accept: application/vnd.github+json" \
        -f default_workflow_permissions=read \
        >"$_ignore"; then
        info "Configured Actions workflow permissions (GITHUB_TOKEN default=read)."
    else
        warning "Could not configure Actions workflow permissions (possibly restricted by owner policy)."
    fi
}

function configure_branch_protection()
{
    info "Configuring branch ruleset for '${branch}'..."

    # Build required status checks array
    local status_checks_json=""
    if [[ ${#required_checks[@]} -gt 0 ]]; then
        local entries=()
        for check in "${required_checks[@]}"; do
            entries+=("{\"context\":\"${check}\",\"integration_id\":null}")
        done
        local IFS=','
        status_checks_json="${entries[*]}"
    fi

    # Check if a ruleset named "main protection" already exists
    local existing_id
    existing_id=$(gh api "repos/${repo}/rulesets" 2>"$_ignore" \
        | jq -r '.[] | select(.name == "main protection") | .id // empty' 2>"$_ignore" || true)

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
    "name": "main protection",
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
            "type": "pull_request",
            "parameters": {
                "required_approving_review_count": 0,
                "dismiss_stale_reviews_on_push": true,
                "require_code_owner_review": false,
                "require_last_push_approval": false,
                "required_review_thread_resolution": true
            }
        },
        {
            "type": "required_status_checks",
            "parameters": {
                "strict_required_status_checks_policy": true,
                "required_status_checks": [${status_checks_json}]
            }
        },
        {
            "type": "required_linear_history"
        },
        {
            "type": "non_fast_forward"
        },
        {
            "type": "deletion"
        }
    ]
}
JSON
    info "Branch ruleset configured."
}

function configure_secrets()
{
    info "Configuring repository secrets..."

    for entry in "${expected_secrets[@]}"; do
        execute gh secret set "$entry" --body "UPDATE-ME" -R "$repo" >"$_ignore"
        trace "Set secret: ${entry}"
    done
    warning "Secrets configured with placeholder values — you must update them with real values."
}

function configure_variables()
{
    info "Configuring repository variables..."

    # Get existing variables as name=value pairs
    declare -A existing_vars
    while IFS='=' read -r name value; do
        existing_vars["$name"]="$value"
    done < <(gh variable list -R "$repo" --json name,value -q '.[] | "\(.name)=\(.value)"')

    local skipped=0
    for name in "${!vars_defaults[@]}"; do
        local default_value="${vars_defaults[$name]}"

        if [[ -v "existing_vars[$name]" ]]; then
            if [[ "${existing_vars[$name]}" != "$default_value" && "$force_defaults" != true ]]; then
                info "Skipping variable '${name}' — already set to '${existing_vars[$name]}' (differs from the default '${default_value}')."
                (( ++skipped ))
                continue
            fi
        fi

        execute gh variable set "$name" --body "$default_value" -R "$repo" >"$_ignore"
        trace "Set variable: ${name}=${default_value}"
    done

    if (( skipped > 0 )); then
        warning "${skipped} variable(s) skipped — already set to non-default values. Use '--force-defaults' to overwrite."
    fi
    info "Variables configured."
}
