# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xri admin_role_id=5

declare -xr secret_placeholder="UPDATE+ME/==" # valid base64 placeholder

declare -xrA default_repo_settings=(
    ["default_branch"]="main"
    ["delete_branch_on_merge"]=true
    ["allow_squash_merge"]=false
    ["allow_merge_commit"]=false
    ["allow_rebase_merge"]=true
    ["allow_auto_merge"]=true
    ["has_issues"]=true
    ["has_wiki"]=false
    ["has_projects"]=false
    ["has_pull_requests"]=true
    ["pull_request_creation_policy"]="all"
    ["visibility"]="public"
)

declare -xra default_repo_settings_order=(
    "default_branch"
    "has_wiki"
    "has_issues"
    "has_projects"
    "has_pull_requests"
    "pull_request_creation_policy"
    "allow_merge_commit"
    "allow_squash_merge"
    "allow_rebase_merge"
    "allow_auto_merge"
    "delete_branch_on_merge"
    "visibility"
)

declare -xrA default_repo_permissions=(
    ["default_workflow_permissions"]="read"
    ["can_approve_pull_request_reviews"]=false
)

declare -xrA default_ruleset=(
    ["enforcement"]="active"
    ["repository_admin_bypass"]="present"
    ["deletion"]="present"
    ["required_linear_history"]="present"
    ["pull_request"]="present"
    ["required_approving_review_count"]="present"
    ["dismiss_stale_reviews_on_push"]="present"
    ["require_code_owner_review"]="present"
    ["require_last_push_approval"]="present"
    ["required_review_thread_resolution"]="present"
    ["required_reviewers"]="present"
    ["allowed_merge_methods"]="present"
    ["required_status_checks"]="present"
    ["do_not_enforce_on_create"]="present"
    ["strict_required_status_checks_policy"]="present"
    ["non_fast_forward"]="present"
)

declare -xra default_ruleset_order=(            # UI: Order in which rules appear in the GitHub UI "Rulesets/main protection"
    "enforcement"                               # Enforcement status: Active/Disabled ▾
    "repository_admin_bypass"                   # Bypass actors section
    "deletion"                                  # Restrict deletions
    "required_linear_history"                   # Require linear history
    "pull_request"                              # Require a pull request ▾
    "required_approving_review_count"           #   ↳ Required approvals
    "dismiss_stale_reviews_on_push"             #   ↳ Dismiss stale reviews
    "require_code_owner_review"                 #   ↳ Require Code Owners review
    "require_last_push_approval"                #   ↳ Require last push approval
    "required_review_thread_resolution"         #   ↳ Require conversation resolution
    "required_reviewers"                        #   ↳ Reviewers list
    "allowed_merge_methods"                     #   ↳ Allowed merge methods
    "required_status_checks"                    # Require status checks ▾
    "do_not_enforce_on_create"                  #   ↳ Do not enforce on create
    "strict_required_status_checks_policy"      #   ↳ Require up-to-date branches
    "non_fast_forward"                          # Block force pushes
)

declare -xrA default_secrets=(
    ["BENCHER_API_TOKEN"]="$secret_placeholder"
    ["CODECOV_TOKEN"]="$secret_placeholder"
    ["RELEASE_PAT"]="$secret_placeholder"
    ["REPORTGENERATOR_LICENSE"]="$secret_placeholder"
    ["NUGET_API_GITHUB_KEY"]="$secret_placeholder"
    ["NUGET_API_KEY"]="$secret_placeholder"
    ["NUGET_API_NUGET_KEY"]="$secret_placeholder"
)

declare -xrA default_vars=(
    ["ACTIONS_RUNNER_DEBUG"]=false
    ["ACTIONS_STEP_DEBUG"]=false
    ["CONFIGURATION"]="Release"
    ["DOTNET_VERSION"]="10.0.x"
    ["MAX_REGRESSION_PCT"]="20"
    ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="preview.0"
    ["MINVERTAGPREFIX"]="v"
    ["MIN_COVERAGE_PCT"]="80"
    ["NUGET_SERVER"]="github"
    ["RESET_BENCHMARK_THRESHOLDS"]=false
    ["SAVE_PACKAGE_ARTIFACTS"]=false
    ["VERBOSE"]=false
)

declare -xrA var_validators=(
    ["ACTIONS_RUNNER_DEBUG"]="validate_boolean"
    ["ACTIONS_STEP_DEBUG"]="validate_boolean"
    ["CONFIGURATION"]="is_valid_configuration"
    ["DOTNET_VERSION"]="is_valid_dotnet_version"
    ["MAX_REGRESSION_PCT"]="is_valid_percentage"
    ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="is_valid_minverPrereleaseId"
    ["MINVERTAGPREFIX"]="validate_minverTagPrefix"
    ["MIN_COVERAGE_PCT"]="is_valid_percentage"
    ["NUGET_SERVER"]="is_valid_nuget_server"
    ["RESET_BENCHMARK_THRESHOLDS"]="validate_boolean"
    ["SAVE_PACKAGE_ARTIFACTS"]="validate_boolean"
    ["VERBOSE"]="validate_boolean"
)
