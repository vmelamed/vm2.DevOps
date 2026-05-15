#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")
# freeze them!
declare -rx script_name
declare -rx script_dir
declare -rx lib_dir

#===============================
# Imported constants
#===============================
# imported environment variables and defaults:
declare -rx default_sot
declare -rxa sources_of_truth
declare -rxa vm2_repositories
declare -rx semverTagReleaseRegex
declare -rx vm2_devops_repo_name

# import outcomes and error codes
declare -rxi success
declare -rxi failure
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_found
declare -rxi err_not_file
declare -rxi err_not_directory
declare -rxi err_not_git_root
declare -rxi err_behind_latest_stable_tag
declare -rxi err_invalid_repo
declare -rxi err_found_too_many
declare -rxi err_repo_with_no_ci
declare -rxi err_dir_with_no_ci
declare -rxi err_not_git_directory
declare -rxi err_dir_with_ci
declare -rxi err_logic_error

# shellcheck disable=SC1091
{
    source "$lib_dir/core.sh"
    source "$lib_dir/_git_vm2.sh"
}

#===============================
# Script shared variables:
#===============================
declare -xi rc
declare -x vm2_repos=${VM2_REPOS:-}   # the parent directory where all the vm2 repositories are cloned. It can be set as an environment variable or passed as an argument with '--vm2-repos' option.
declare -x summary_file

#===============================
# Script start:
#===============================

vm2_repos=$(resolve_vm2_repos "$vm2_repos") || {
    rc=$?
    usage -ec "$rc" \
          "Could not find the parent directory for the vm2 repositories. Please, set the VM2_REPOS environment variable or provide the path as an argument with '--vm2-repos' option."
}
trace "All vm2 repositories are expected to be in '$vm2_repos'"
declare -rx vm2_repos

# ensure vm2.DevOps is a valid Git repository and is not behind the latest stable tag:
rc="$success"
validate_repo_root "$vm2_repos" "$vm2_devops_repo_name" "main" || rc=$?
(( rc != success )) &&
    error -ec "$err_logic_error" "The repository in '$vm2_devops_repo_name' cannot be used." "$rc"

exit_if_has_errors

summary_file=$(mktemp -p /tmp "restore-force-eval-log-$(date +%Y%m%d-%H%M%S)-XXXXXX.md")
trap 'rm -f "$summary_file"' EXIT
declare -rx summary_file

for repo in "${vm2_repositories[@]}"; do
    project_dir="$repo_root/../$project"
    if [[ ! -d "$project_dir" ]]; then
        echo "Warning: Project directory not found: $project_dir" >&2
        continue
    fi
    cd "$project_dir"
    echo "Restoring project: $project"
    dotnet restore --force-evaluate "$@"

    echo "Verifying lock files: $project"
    if ! dotnet restore --locked-mode > /dev/null 2>&1; then
        echo "Error: Lock file verification failed for $project" >&2
        continue
    fi

    # Stage updated lock files
    lock_files=$(git diff --name-only -- '**/packages.lock.json' 2>/dev/null || true)
    if [[ -n "$lock_files" ]]; then
        git add ./**/packages.lock.json
        echo "Staged lock files: $project"
    else
        echo "No lock file changes: $project"
    fi

    if gh workflow view ClearCache.yaml --repo "vmelamed/$project" &>/dev/null; then
        if ! gh workflow run ClearCache.yaml \
            --repo "vmelamed/$project" \
            --raw-field reason="Change in $project dependencies." \
            --raw-field cache-pattern="nuget-"; then
            echo "Warning: Failed to trigger workflow for $project" >&2
        fi
    else
        echo "Info: No ClearCache workflow for $project, skipping cache clear" >&2
    fi
done
