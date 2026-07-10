# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -rxi err_argument_value

declare -rxi admin_role_id=5

declare -xr secret_str

declare -xr missing_state="<missing>"
declare -xr present_state="<present>"
declare -xr undefined_default="<undefined>"

declare -rxA default_repo_settings=(
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

declare -rxa default_repo_settings_order=(
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

declare -rxA default_repo_permissions=(
    ["default_workflow_permissions"]="read"
    ["can_approve_pull_request_reviews"]=true
)

declare -rxA default_ruleset=(
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

declare -rxa default_ruleset_order=(            # UI: Order in which rules appear in the GitHub UI "Rulesets/main protection"
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

declare -rxa apps_with_secrets=(
    "actions"
    "dependabot"
    "agents"
    "codespaces"
)

declare -rxA actions_secrets=(
    ["REPORTGENERATOR_LICENSE"]="$secret_str"
    ["CODECOV_TOKEN"]="$secret_str"
    ["BENCHER_API_TOKEN"]="$secret_str"
    ["BENCH_DISPATCH_PAT"]="$secret_str"
    ["GH_PACKAGES_TOKEN"]="$secret_str"
    ["NUGET_API_KEY"]="$secret_str"
    ["RELEASE_PAT"]="$secret_str"
)
declare -rxA dependabot_secrets=()
declare -rxA agents_secrets=()
declare -rxA codespaces_secrets=()

declare -rxA actions_default_vars=(
    ["ACTIONS_RUNNER_DEBUG"]=false
    ["ACTIONS_STEP_DEBUG"]=false
    ["CONFIGURATION"]="Release"
    ["DOTNET_VERSION"]="10.0.x"
    ["MAX_REGRESSION_PCT"]="20"
    ["MAX_GEN1_COLLECTS"]="2"
    ["MAX_GEN2_COLLECTS"]="1"
    ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="preview.0"
    ["MINVERTAGPREFIX"]="v"
    ["MIN_COVERAGE_PCT"]="80"
    ["NUGET_SERVER"]="github"
    ["RESET_BENCHMARK_THRESHOLDS"]=false
    ["SAVE_PACKAGE_ARTIFACTS"]=false
    ["VERBOSE"]=false
)

declare -rxA actions_var_validators=(
    ["ACTIONS_RUNNER_DEBUG"]="validate_boolean"
    ["ACTIONS_STEP_DEBUG"]="validate_boolean"
    ["CONFIGURATION"]="is_valid_configuration"
    ["DOTNET_VERSION"]="is_valid_dotnet_version"
    ["MAX_REGRESSION_PCT"]="is_valid_percentage"
    ["MAX_GEN1_COLLECTS"]="is_non_negative"
    ["MAX_GEN2_COLLECTS"]="is_non_negative"
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
    "merge.ff"
    "pull.rebase"
    "fetch.prune"
    "push.autoSetupRemote"
    "rerere.enabled"
    "rerere.autoUpdate"
    "rebase.autoStash"
    "merge.conflictstyle"
    "push.useForceIfIncludes"
    "tag.sort"
    "merge.nugetlock.name"
    "merge.nugetlock.driver"
)

declare -xr VM2_REPOS

# shellcheck disable=SC2154
declare -xA default_local_git_settings=(
    # Set the hooks path to a githooks directory in the vm2_devops_repo, which can contain custom Git hooks for the team. This
    # allows for consistent enforcement of policies and automation of tasks such as pre-commit checks, commit message
    # validation, or post-merge actions across all team members who clone the repository.
    ["core.hooksPath"]="$VM2_REPOS/$vm2_devops_repo_name/scripts/githooks"

    # Set the commit template to a .gitmessage file located in the SOT directory, which can be customized by the user to provide
    # a consistent commit message format across the team. This helps ensure that all commits include necessary information such
    # as the type of change, scope, and a brief description, improving readability and traceability in the commit history.
    ["commit.template"]="$(get_vm2_sot_path "$VM2_REPOS" "$sot")/.gitmessage"

    # Enforce fast-forward merges to maintain linear history, which is required by the branch protection rules. If you need to
    # merge a PR with a merge commit, you can do so locally with 'git merge --no-ff'
    ["merge.ff"]="only"

    # Enable rebasing by default when pulling to maintain a cleaner commit history, which is especially beneficial for feature
    # branches and when the team prefers a linear history. This setting can be overridden on a per-branch basis if needed.
    ["pull.rebase"]=true

    # Automatically remove remote-tracking references that no longer exist on the remote when fetching, to keep the local
    # repository clean and up-to-date.
    ["fetch.prune"]=true

    # Automatically set up tracking information when pushing a new branch to the remote, so that 'git pull' and 'git push' will
    # work without additional parameters.
    ["push.autoSetupRemote"]=true

    # Enable reuse of recorded resolution for conflicted merges (rerere) to streamline conflict resolution when rebasing or
    # merging branches with a shared history.
    ["rerere.enabled"]=true

    # Automatically stages files that have been resolved by rerere, which can further streamline the conflict resolution process
    # during rebases and merges.
    # AI: "Companion to rerere.enabled: also STAGE the auto-resolved files. Without it, rerere resolves the
    # conflict but leaves it unstaged — you still stop at every commit just to 'git add'."
    ["rerere.autoUpdate"]=true

    # Stash dirty working tree automatically before rebase/pull --rebase and reapply after. Removes the
    # "cannot rebase: you have unstaged changes" interruption mid-flow. (Promised in GIT_PLAYBOOK.md.)
    ["rebase.autoStash"]=true

    # Show the merged-base version in conflict hunks (3-way + base, compacted). You see WHAT both sides
    # changed relative to the common ancestor, not just the two results. (Promised in GIT_PLAYBOOK.md.)
    ["merge.conflictstyle"]="zdiff3"

    # Refuse a force-with-lease push if the remote has commits you haven't even fetched yet —
    # closes the race where dependabot/automation pushed while you were rebasing.
    ["push.useForceIfIncludes"]=true

    # Sort tags as versions, so 'git tag' lists v1.10.0 after v1.9.0, not before it.
    ["tag.sort"]="version:refname"

    # Custom merge driver for NuGet lockfiles, bound by the shared .gitattributes line
    # 'packages.lock.json merge=nugetlock'. Lockfiles are generated — merging them by hand is always wrong.
    # The driver takes the incoming side (%B — during a rebase that is the commit being replayed, i.e. the
    # same side as 'git checkout --theirs'), so a lockfile conflict never stops a rebase or merge; the file
    # must still be regenerated with 'dotnet restore --force-evaluate' before pushing (CI's locked-mode
    # restore catches a forgotten regeneration). In repos where the driver is not configured (clone without
    # setup-repo.sh), git falls back to the normal text merge — same behavior as before.
    ["merge.nugetlock.name"]="NuGet lockfile - take the incoming side and regenerate"
    ["merge.nugetlock.driver"]='cp -f %B %A && echo "vm2: %P auto-resolved (took the incoming side) - regenerate with: dotnet restore --force-evaluate" >&2'
)

declare -rxi success                    # Operation completed successfully
declare -rxi err_invalid_arguments      # The number of the arguments is invalid or more than one type of parameter error code is present
declare -rxi err_not_directory          # Parameter value is not a directory

declare -xri default_sot

#-------------------------------------------------------------------------------
# @description Finalizes the `default_local_git_settings` associative array by resolving the two entries whose values
# depend on the caller's environment: `core.hooksPath` (derived from the vm2 repos parent directory) and
# `commit.template` (derived from the source-of-truth directory). After computing these values, the array is
# re-declared read-only so no later code can accidentally change the shared defaults.
#
# @arg $1 string Path to the parent directory where the `vm2.DevOps` repository is cloned (e.g. the value of
#   $VM2_REPOS or the `--vm2-repos` option). Must be an existing directory.
# @arg $2 string Path to the source-of-truth (SOT) directory, e.g. `$VM2_REPOS/$default_sot`. Must be an existing
#   directory.
#
# @exitcode 0 Success; `default_local_git_settings` updated and frozen.
# @exitcode 2 Invalid arguments (wrong count, empty value, or a value that is not an existing directory).
#-------------------------------------------------------------------------------
function init_default_local_git_settings()
{
    local -i rc="$success"

    [[ $# -eq 2 && -n "$1" && -n "$2" ]] || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 2 non-empty arguments:" \
                              "- the path to the parent directory where '$vm2_devops_repo_name' is cloned, e.g. the value of \$VM2_REPOS or the parameter of --vm2-repos." \
                              "- the path to the source of truth (SOT) directory, $VM2_REPOS/$default_sot."
    }
    [[ $# -lt 1 || -d $1 ]]  || {
        rc="$err_not_directory"
        error -sd 3 -ec "$rc" "The first parameter of ${FUNCNAME[0]}() must be an existing directory. Provided: '$1'"
    }
    [[ $# -lt 2 || -d $2 ]]  || {
        rc="$err_not_directory"
        error -sd 3 -ec "$rc" "The second parameter of ${FUNCNAME[0]}() must be an existing directory. Provided: '$2'"
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local repos=$1
    local shared=$2

    # cement the paths in the default_local_git_settings that depend on the location of the vm2_repos ($1):
    default_local_git_settings["core.hooksPath"]="$repos/$vm2_devops_repo_name/scripts/githooks"
    default_local_git_settings["commit.template"]="$shared/.gitmessage"

    declare -rxA default_local_git_settings
}
