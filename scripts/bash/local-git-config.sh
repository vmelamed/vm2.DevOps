#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
{
    source "${lib_dir}/core.sh"
    source "${lib_dir}/_git_vm2.sh"
}

info "Configuring local git settings..."

#===============================
# Find and validate vm2_repos:
#===============================
vm2_repos=$(resolve_vm2_repos "$vm2_repos") ||
    usage "$rc" "Could not find the parent directory for the vm2 repositories." \
          "Please, set the VM2_REPOS environment variable or provide the path as an argument with '--vm2-repos' option."

trace "All vm2 repositories are expected in '$vm2_repos'"

# make sure we are seeing .github and vm2.DevOps properly through vm2_repos
[[ -d "$vm2_repos/.github" && -d "$vm2_repos/vm2.DevOps" ]] ||
    usage "$err_not_found" "The GitHub Actions workflow templates directory .github and/or the vm2.DevOps directory is missing in '$vm2_repos', Please clone the repositories into '$vm2_repos'."

validate_repo_root "$vm2_repos/.github" "$vm2_repos" "main" || rc=$?
(( rc == err_behind_latest_stable_tag )) &&
    error "The repository in '$vm2_repos/.github' is behind the latest stable tag. Please update it to the latest commit on the main branch."

rc="$success"
validate_repo_root "$vm2_repos/vm2.DevOps" "$vm2_repos" "main" || rc=$?
(( rc == err_behind_latest_stable_tag )) &&
    error "The repository in '$vm2_repos/vm2.DevOps' is behind the latest stable tag. Please update it to the latest commit on the main branch."

declare -x _ci_yaml=''

_ci_yaml="$vm2_repos/vm2.DevOps/.github/workflows/_ci.yaml"
[[ -s "$_ci_yaml" ]] || error "Could not find _ci.yaml GitHub Actions reusable workflow file in ${vm2_repos}."

declare -xr _ci_yaml

exit_if_has_errors


trace "Repository path: '$repo_path'"


# make sure we are seeing .github and vm2.DevOps properly through vm2_repos
validate_repo_root ".github" "$vm2_repos" "main"
validate_repo_root "vm2.DevOps" "$vm2_repos" "main"
exit_if_has_errors
ensure_fresh_git_state ".github"
ensure_fresh_git_state "vm2.DevOps"

declare -xr hooks_path="${vm2_repos}/vm2.DevOps/scripts/githooks"
declare -xr commit_template="${hooks_path}/.gitmessage"

info "  ...setting core.hooksPath to '${hooks_path}';"
execute git -C "$repo_path" config --local core.hooksPath "$hooks_path"             && trace "core.hooksPath set to '${hooks_path}'."

info "  ...setting commit.template to '${commit_template}';"
execute git -C "$repo_path" config --local commit.template "$commit_template"       && trace "commit.template set to '${commit_template}'."

info "  ...setting pull.rebase to 'true';"
execute git -C "$repo_path" config --local pull.rebase true                         && trace "pull.rebase set to 'true'."

info "  ...setting fetch.prune to 'true';"
execute git -C "$repo_path" config --local fetch.prune true                         && trace "fetch.prune set to 'true'."

info "  ...setting push.autoSetupRemote to 'true';"
execute git -C "$repo_path" config --local push.autoSetupRemote true                && trace "push.autoSetupRemote set to 'true'."

info "...local git settings configured."
