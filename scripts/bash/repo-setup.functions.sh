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
declare -x configure_only
declare -x skip_secrets
declare -x skip_variables
declare -x audit
declare -x force_defaults
declare -x main_protection_rs_name

declare -x ci_yaml
declare -x _ci_yaml

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
    ["RESET_BENCHMARK_THRESHOLDS"]="false"
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
declare -xi github_actions_app_id

# ------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------

## Validates that the given directory is a root of a repository working tree, and its HEAD is on or after the latest stable tag.
## Otherwise confirm with the user that they want to continue
## Usage: validate_source_repo <root-repo>
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function validate_source_repo()
{
    if [[ $# -lt 1 ]]; then
        error "${FUNCNAME[0]}() requires at least 1 argument: the name of a repository." >&2
        return 2
    fi

    local repo_name=$1
    local dir="${git_repos}/${repo_name}"

    if [[ ! -d "${dir}" ]]; then
        error "The '${repo_name}' repository was not cloned or is not under ${git_repos}."
        exit 2
    fi

    if [[ "$dir" == $(root_working_tree "$dir") ]]; then
        is_on_or_after_latest_stable_tag "$dir" "$semverTagReleaseRegex" || {
            error "The HEAD of the '${repo_name}' repository is before the latest stable tag. Please synchronize."
            exit 2
        }
    else
        confirm "The ${repo_name} repository at '$dir' is not a git repository. Do you want to continue?" "n" ||
            exit 2
    fi
}

function resolve_github_actions_app_id()
{
    # Resolve the GitHub Actions app ID dynamically via the API.
    # Used to pin required status checks to GitHub Actions specifically.
    github_actions_app_id=$(gh api apps/github-actions --jq '.id' 2>"$_ignore") || {
        error "Failed to resolve GitHub Actions app ID from the API." >&2
    }
    exit_if_has_errors
    trace "GitHub Actions app ID: ${github_actions_app_id}"
}

function detect_required_checks()
{
    # With reusable workflows + matrix strategies, GitHub Actions produces check names that
    # include the workflow prefix, matrix params, inner job names, and event suffixes — making
    # them impossible to predict for branch protection rules. Instead, each CI.yaml has a
    # lightweight gate job that depends on all other jobs and reports a single, stable check name.
    #
    # The GitHub UI decorates check names as "Workflow / JobName (event)" but the check-runs
    # API returns bare names and ruleset matching uses the bare check-run name field.
    # So we extract just the gate job's `name:` property from CI.yaml.
    local gate_name gate_job

    # Find the gate job: look for postrun-ci first, fall back to ci-gate
    gate_job=$(yq -r '.jobs | keys[] | select(test("postrun|ci-gate"))' "$ci_yaml" | head -1) || true
    gate_name=$(yq -r ".jobs.${gate_job:-postrun-ci}.name // \"Postrun-CI\"" "$ci_yaml") || {
        error "Failed to parse gate job name from CI.yaml." >&2
    }

    exit_if_has_errors

    required_checks+=("${gate_name}")
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
            entries+=("{\"context\":\"${check}\",\"integration_id\":${github_actions_app_id}}")
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
