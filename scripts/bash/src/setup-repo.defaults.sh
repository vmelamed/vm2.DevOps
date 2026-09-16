# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xri err_argument_value

declare -x vm2_devops_repo_name

declare -xri admin_role_id=5

declare -xr secret_str

declare -xr missing_state="<none>"
declare -xr present_state=$secret_str
declare -xr undefined_default="<undefined>"

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
    ["can_approve_pull_request_reviews"]=true
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

declare -xra apps_with_secrets=(
    "actions"
    "dependabot"
    "agents"
    "codespaces"
)

declare -xra nuget_servers=(
    "nuget"
    "github"
)

declare -xr default_nuget_server

declare -xA actions_secrets=(
    # GitHub tokens and secrets:
    ["GH_PACKAGES_TOKEN"]="$secret_str"         # The GitHub Packages token used to update the local GitHub Packages (used by
                                                # Dependabot)
    ["NUGET_API_KEY"]="$secret_str"             # The NuGet API key for the selected NuGet server. Note that nuget.org uses a
                                                # different authentication mechanism - Trusted Publishing
                                                # (see https://learn.microsoft.com/en-us/nuget/nuget-org/trusted-publishing)
    ["RELEASE_PAT"]="$secret_str"               # PAT for a user listed as a bypass actor (e.g. Admin) in the branch ruleset
                                                # protecting main. Required to push changelog commits and version tags directly
                                                # to main
    ["CODECOV_TOKEN"]="$secret_str"             # Token used by Codecov to upload coverage reports - different for different
                                                # projects
    ["REPORTGENERATOR_LICENSE"]="$secret_str"   # License key used by ReportGenerator for generating coverage reports
    ["BENCHER_API_TOKEN"]="$secret_str"         # API token used by Bencher for authentication
    ["BENCH_DISPATCH_PAT"]="$secret_str"        # Fine-grained PAT with `Actions: write` + `Contents: read` on the package repos.
                                                # Used by `RebuildBenchHistory.yaml` to dispatch each repo's benchmark-history
                                                # rebuild
)
declare -xrA dependabot_secrets=()
declare -xrA agents_secrets=()
declare -xrA codespaces_secrets=()

declare -xrA actions_default_vars=(
    # Build and Pack:
    ["MINVERTAGPREFIX"]="v"
    ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="preview.0"
    # ["CONFIGURATION"]="Release"
    # ["FRAMEWORK"]="net10.0"
    # ["RUNTIME"]=""
    # ["ARTIFACTS_PATH"]="artifacts"
    # Test:
    ["MIN_COVERAGE_PCT"]="80"
    # Benchmarks:
    ["MAX_REGRESSION_PCT"]="20"
    ["MAX_GEN1_COLLECTS"]="2"
    ["MAX_GEN2_COLLECTS"]="1"
    ["RESET_BENCHMARK_THRESHOLDS"]=false
    # NuGet:
    ["NUGET_SERVER"]="nuget"                # The default NuGet server to use for publishing packages. Can be 'nuget', 'github', or a custom server URL.
    ["NUGET_USERNAME"]="valo"               # The default username to use for the selected NuGet server. github - vmelamed, nuget - your NuGet.org username, custom server - as required.
    # Trace:
    ["VERBOSE"]=false
    # GitHub Actions diagnostics
    ["ACTIONS_RUNNER_DEBUG"]=false
    ["ACTIONS_STEP_DEBUG"]=false
)

declare -xra actions_default_vars_order=(
    "--Build and Pack:"
    "MINVERTAGPREFIX"
    "MINVERDEFAULTPRERELEASEIDENTIFIERS"
    # "CONFIGURATION"
    # "FRAMEWORK"
    # "RUNTIME"
    # "ARTIFACTS_PATH"
    "--Test:"
    "MIN_COVERAGE_PCT"
    "--Benchmarks:"
    "MAX_REGRESSION_PCT"
    "MAX_GEN1_COLLECTS"
    "MAX_GEN2_COLLECTS"
    "RESET_BENCHMARK_THRESHOLDS"
    "--Nuget:"
    "NUGET_SERVER"
    "NUGET_USERNAME"
    "--Trace:"
    "VERBOSE"
    "--GitHub Actions diagnostics:"
    "ACTIONS_RUNNER_DEBUG"
    "ACTIONS_STEP_DEBUG"
)

declare -xrA actions_var_validators=(
    # Build and Pack
    ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="is_valid_minverPrereleaseId"
    ["MINVERTAGPREFIX"]="validate_semverTagComponents"
    # ["CONFIGURATION"]="is_valid_configuration"
    # ["FRAMEWORK"]="is_valid_framework"
    # ["RUNTIME"]="is_valid_runtime"
    # ["ARTIFACTS_PATH"]="is_safe_valid_path"
    # Test
    ["MIN_COVERAGE_PCT"]="is_valid_percentage"
    # Benchmarks
    ["MAX_REGRESSION_PCT"]="is_valid_percentage"
    ["MAX_GEN1_COLLECTS"]="is_non_negative"
    ["MAX_GEN2_COLLECTS"]="is_non_negative"
    ["RESET_BENCHMARK_THRESHOLDS"]="is_boolean"
    # NuGet
    ["NUGET_SERVER"]="is_one_of_nuget_servers"
    ["NUGET_USERNAME"]="is_safe_input"
    # Trace
    ["VERBOSE"]="is_boolean"
    # GitHub Actions diagnostics
    ["ACTIONS_RUNNER_DEBUG"]="is_boolean"
    ["ACTIONS_STEP_DEBUG"]="is_boolean"
)

declare -xr vm2_repos
declare -xr vm2_sot_repo_name

declare -xrA default_local_git_settings=(
    # Set the default branch name for new repositories. This ensures that all new repositories initialized locally will have a
    # consistent default branch name "main".
    ["init.defaultBranch"]="main"

    # Set the hooks path to a githooks directory in the vm2_devops_repo, which can contain custom Git hooks for the team. This
    # allows for consistent enforcement of policies and automation of tasks such as pre-commit checks, commit message
    # validation, or post-merge actions across all team members who clone the repository.
    ["core.hooksPath"]="$vm2_repos/$vm2_devops_repo_name/scripts/githooks"

    # Set the commit template to a .gitmessage file located in the SOT directory, which can be customized by the user to provide
    # a consistent commit message format across the team. This helps ensure that all commits include necessary information such
    # as the type of change, scope, and a brief description, improving readability and traceability in the commit history.
    ["commit.template"]="$vm2_repos/$vm2_sot_repo_name/templates/$default_sot/content/.gitmessage"

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

declare -xa default_local_git_settings_order=(
    "init.defaultBranch"
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

declare -xri success                    # Operation completed successfully
declare -xri err_invalid_arguments      # The number of the arguments is invalid or more than one type of parameter error code is present
declare -xri err_not_directory          # Parameter value is not a directory

declare -xri default_sot

#---------------------------------------------------------------------------------------------
# @description Checks if the given server is one of the valid NuGet servers.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string The server to check.
#
# @exitcode success/positive=0: The server is one of the valid NuGet servers.
# @exitcode failure/negative=1: The server is not one of the valid NuGet servers.
#---------------------------------------------------------------------------------------------
function is_one_of_nuget_servers()
{
    (( $# == 1 ))                              || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the NuGet server to check."
    [[ ! -v 1 ]] || is_valid_nuget_server "$1" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid NuGet server (provided '${1:-<none>}')."

    exit_if_has_bugs

    is_in "$1" "${nuget_servers[@]}"
}
