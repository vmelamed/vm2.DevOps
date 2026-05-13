# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xri admin_role_id=5

declare -xr secret_placeholder="UPDATE+ME/==" # valid base64 placeholder

declare -xrA repo_state_queries=(
    ["key_repo_id"]=".id"
    ["key_owner"]=".owner.login"
    ["key_default_branch"]=".default_branch"
    ["key_url"]=".html_url"
    ["key_ssh_url"]=".ssh_url"
    ["key_name"]=".name"
    ["key_repo"]=".full_name"
)

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

declare -xrA default_actions_secrets=(
    ["BENCHER_API_TOKEN"]="$secret_placeholder"
    ["CODECOV_TOKEN"]="$secret_placeholder"
    ["RELEASE_PAT"]="$secret_placeholder"
    ["REPORTGENERATOR_LICENSE"]="$secret_placeholder"
    ["NUGET_API_KEY"]="$secret_placeholder"
)

declare -xrA default_dependabot_secrets=(
    ["GH_PACKAGES_TOKEN"]="$secret_placeholder"
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
    ["MINVERTAGPREFIX"]="validate_semverTagComponents"
    ["MIN_COVERAGE_PCT"]="is_valid_percentage"
    ["NUGET_SERVER"]="is_valid_nuget_server"
    ["RESET_BENCHMARK_THRESHOLDS"]="validate_boolean"
    ["SAVE_PACKAGE_ARTIFACTS"]="validate_boolean"
    ["VERBOSE"]="validate_boolean"
)

declare -xa default_local_git_settings_order=(
    "core.hooksPath"
    "commit.template"
    "fetch.prune"
    "merge.ff"
    "pull.rebase"
    "push.autoSetupRemote"
)

declare -xr VM2_REPOS

# shellcheck disable=SC2154
declare -xA default_local_git_settings=(
    ["core.hooksPath"]="$VM2_REPOS/$vm2_devops_repo_name/scripts/githooks"
    ["commit.template"]="$(get_vm2_sot_path "$VM2_REPOS" "$sot")/.gitmessage"
    ["pull.rebase"]=true
    ["fetch.prune"]=true
    ["push.autoSetupRemote"]=true
    ["merge.ff"]="only" # Enforce fast-forward merges to maintain linear history, which is required by the branch protection rules. If you need to merge a PR with a merge commit, you can do so locally with 'git merge --no-ff'
)

declare -rxi err_invalid_arguments=2    # The number of the arguments is invalid or more than one type of parameter error code is present
declare -rxi err_not_directory=17       # Parameter value is not a directory

function init_default_local_git_settings()
{
    [[ $# -eq 1 && -n "$1" ]] || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 non-empty argument: the path to the parent directory where '$vm2_devops_repo_name' is cloned, e.g. the value of \$VM2_REPOS or the parameter of --vm2-repos."
        return "$err_invalid_arguments"
    }
    [[ -d $1 ]]  || {
        error 3 "${FUNCNAME[0]}() must be an existing directory. Provided: '$1'"
        return "$err_not_directory"
    }

    local repos=$1
    local shared
    shared=$(get_vm2_sot_path "$repos" "$sot")

    # cement the paths in the default_local_git_settings that depend on the location of the vm2_repos ($1):
    default_local_git_settings["core.hooksPath"]="$repos/$vm2_devops_repo_name/scripts/githooks"
    default_local_git_settings["commit.template"]="$shared/.gitmessage"

    declare -xrA default_local_git_settings
}
