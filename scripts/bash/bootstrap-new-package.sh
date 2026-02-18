#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[-1]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[-1]}")")"
lib_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"

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
    if [[ -d .git ]] || git rev-parse --git-dir &>/dev/null; then
        local_remote=$(git remote get-url origin 2>/dev/null || true)
        if [[ -n "$local_remote" ]]; then
            # extract owner/repo from SSH or HTTPS URL
            repo=$(echo "$local_remote" | sed -E 's#^.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#')
            info "Auto-detected repo from git remote: ${repo}"
        fi
    fi

    if [[ -z "$repo" ]]; then
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

    for key in "${!repo_checks[@]}"; do
        local actual
        actual=$(echo "$repo_json" | jq -r ".${key}")
        if [[ "$actual" == "${repo_checks[$key]}" ]]; then
            info "  ✅ ${key} = ${actual}"
            (( pass++ ))
        else
            warning "  ❌ ${key} = ${actual} (expected: ${repo_checks[$key]})"
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
        if [[ "$default_perms" == "read" ]]; then
            info "  ✅ default_workflow_permissions = read"
            (( pass++ ))
        else
            warning "  ❌ default_workflow_permissions = ${default_perms} (expected: read)"
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

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

if [[ "$audit" == true ]]; then
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
