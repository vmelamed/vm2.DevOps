#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
source "${lib_dir}/core.sh"

# defaults
declare -x package_name=""
declare -x org="vmelamed"
declare -x repo=""
declare -x visibility="public"
declare -x branch="main"
declare -x configure_only=false
declare -x skip_secrets=false
declare -x skip_variables=false
declare -x audit=false

# required checks enforced by branch protection; extended dynamically
declare -xa required_checks=("build")

source "${script_dir}/bootstrap-new-package.utils.sh"
source "${script_dir}/bootstrap-new-package.usage.sh"

get_arguments "$@"

# derive repo name
if [[ -n "$repo" && -n "$package_name" ]]; then
    usage false "Specify either '--repo', '--name', or run from within a repo directory — not both '--repo' and '--name'."
fi

if [[ -z "$repo" && -z "$package_name" ]]; then
    # try to detect from current git remote
    # shellcheck disable=SC2154 # _ignore is referenced but not assigned.
    if git -C "." rev-parse --is-inside-work-tree &> "$_ignore"; then
        local_remote=$(git remote get-url origin 2>/dev/null || true)
        trace "Detected git remote URL: ${local_remote}"
        if [[ -n "$local_remote" && "$local_remote" =~ .*[:/]([^/]+)/([^/]+)(\.git) ]]; then
            # extract owner/repo from SSH or HTTPS URL
            org="${BASH_REMATCH[1]}"
            package_name="${BASH_REMATCH[2]}"
            repo="${org}/${package_name}"
            info "Auto-detected repo from git remote: ${repo}"
        fi
    fi

    if [[ -z "$repo" || -z "$org" || -z "$package_name" ]]; then
        usage false "Either '--repo <owner/repo>', '--name <PackageName>', or run from within a git repo with an origin remote."
    fi
fi

if [[ -z "$repo" ]]; then
    repo="${org}/${package_name}"
fi

# validate repo format
if [[ ! "$repo" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    usage false "Invalid repo format '${repo}'. Expected '<owner>/<repo>'."
fi

declare -rx repo
declare -rx branch
declare -rx configure_only
declare -rx skip_secrets
declare -rx skip_variables
declare -rx audit

# ------------------------------------------------------------------
# Prerequisites
# ------------------------------------------------------------------
# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
if ! command -v jq &> "$_ignore"; then
    error "'jq' is not installed. Please install it first."
    exit 1
fi

if ! command -v gh &> "$_ignore"; then
    error "'gh' is not installed. Please install it first."
    exit 1
fi

if ! gh auth status &> "$_ignore"; then
    error "'gh' is not authenticated. Run 'gh auth login' first."
    exit 1
fi

# ------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------
detect_required_checks()
{
    required_checks=("build")

    if [[ -n $(find . -maxdepth 3 -type d \( -name "test" -o -name "tests" \) -print -quit 2>/dev/null) ]] \
        || [[ -n $(find . -maxdepth 5 -name "*.Tests.csproj" -print -quit 2>/dev/null) ]]; then
        required_checks+=("test")
        info "Detected test projects — adding 'test' to required checks."
    fi

    if [[ -n $(find . -maxdepth 3 -type d -iname "benchmarks" -print -quit 2>/dev/null) ]] \
        || [[ -n $(find . -maxdepth 5 -iname "*.Benchmarks.csproj" -print -quit 2>/dev/null) ]]; then
        required_checks+=("benchmarks")
        info "Detected benchmark projects — adding 'benchmarks' to required checks."
    fi

    info "Required checks: ${required_checks[*]}"
}

configure_repo_settings()
{
    info "Configuring repository settings..."
    execute gh api -X PATCH "repos/${repo}" \
        -f delete_branch_on_merge=true \
        -f allow_squash_merge=true \
        -f allow_merge_commit=false \
        -f allow_rebase_merge=false \
        -f allow_auto_merge=true \
        -f has_wiki=false \
        -f has_projects=false \
        >/dev/null
    info "Repository settings configured."
}

configure_actions_permissions()
{
    info "Configuring Actions workflow permissions..."
    if execute gh api -X PUT "repos/${repo}/actions/permissions/workflow" \
        -H "Accept: application/vnd.github+json" \
        -f default_workflow_permissions=read \
        >/dev/null; then
        info "Configured Actions workflow permissions (GITHUB_TOKEN default=read)."
    else
        warning "Could not configure Actions workflow permissions (possibly restricted by org policy)."
    fi
}

configure_branch_protection()
{
    info "Configuring branch protection for '${branch}'..."

    local contexts_json="[]"
    if [[ ${#required_checks[@]} -gt 0 ]]; then
        contexts_json=$(printf '"%s",' "${required_checks[@]}")
        contexts_json="[${contexts_json%,}]"
    fi

    execute gh api -X PUT "repos/${repo}/branches/${branch}/protection" \
        -H "Accept: application/vnd.github+json" \
        --input - >/dev/null <<JSON
{
    "required_status_checks": {
        "strict": true,
        "contexts": ${contexts_json}
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
        "dismiss_stale_reviews": true,
        "require_code_owner_reviews": false,
        "required_approving_review_count": 1,
        "require_last_push_approval": false,
        "bypass_pull_request_allowances": {
            "users": [],
            "teams": [],
            "apps": []
        }
    },
    "restrictions": null,
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "block_creations": false,
    "required_conversation_resolution": true,
    "lock_branch": false
}
JSON
    info "Branch protection configured."
}

configure_secrets()
{
    info "Configuring repository secrets..."
    local -a secrets=(
        "CODECOV_TOKEN:codecov-secret"
        "BENCHER_API_TOKEN:bencher-secret"
        "REPORTGENERATOR_LICENSE:reportgenerator-secret"
        "NUGET_API_GITHUB_KEY:github-secret"
        "NUGET_API_NUGET_KEY:nuget-secret"
        "NUGET_API_KEY:custom-secret"
        "RELEASE_PAT:release-pat-secret"
    )

    for entry in "${secrets[@]}"; do
        local name="${entry%%:*}"
        local value="${entry#*:}"
        execute gh secret set "$name" --body "$value" -R "$repo" >/dev/null
        trace "Set secret: ${name}"
    done
    info "Secrets configured with placeholder values — update them with real values."
}

configure_variables()
{
    info "Configuring repository variables..."
    local -a variables=(
        "DOTNET_VERSION:10.0.x"
        "CONFIGURATION:Release"
        "MAX_REGRESSION_PCT:20"
        "MIN_COVERAGE_PCT:80"
        "MINVERTAGPREFIX:v"
        "MINVERDEFAULTPRERELEASEIDENTIFIERS:preview.0"
        "NUGET_SERVER:github"
        "ACTIONS_RUNNER_DEBUG:false"
        "ACTIONS_STEP_DEBUG:false"
        "SAVE_PACKAGE_ARTIFACTS:false"
        "VERBOSE:false"
    )

    for entry in "${variables[@]}"; do
        local name="${entry%%:*}"
        local value="${entry#*:}"
        execute gh variable set "$name" --body "$value" -R "$repo" >/dev/null
        trace "Set variable: ${name}=${value}"
    done
    info "Variables configured."
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

if [[ "$audit" == true ]]; then
    source "${script_dir}/bootstrap-new-package.audit.sh"
    info "Audit mode — reading current settings for ${repo}..."
    audit_repo
    exit 0
fi

if [[ "$configure_only" != true ]]; then
    # Ensure git initialized
    if [[ ! -d .git ]]; then
        execute git init
        execute git checkout -b "${branch}"
    fi

    execute git add .
    if ! git diff --cached --quiet; then
        execute git commit -m "chore: initial scaffold" || true
    fi

    if gh repo view "$repo" &> "$_ignore"; then
        info "Repo ${repo} already exists; skipping creation."
    else
        info "Creating repository ${repo}..."
        execute gh repo create "$repo" "--${visibility}" --source . --remote origin --push --branch "${branch}"
    fi

    execute git remote set-url origin "git@github.com:${repo}.git"
    execute git push -u origin "${branch}"
fi

detect_required_checks

if [[ "$skip_secrets" != true ]]; then
    configure_secrets
fi

if [[ "$skip_variables" != true ]]; then
    configure_variables
fi

configure_repo_settings
configure_actions_permissions
configure_branch_protection

info "Repository ready: https://github.com/${repo}"
if [[ "$skip_secrets" != true ]]; then
    warning "All secrets have placeholder values — update them with real values."
fi
