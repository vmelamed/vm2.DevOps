#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

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
if [[ -z "$vm2_repos" ]]; then
    vm2_repos=$(resolve_vm2_repos)
    rc=$?
else
    vm2_repos=$(resolve_vm2_repos "$vm2_repos")
    rc=$?
fi
(( rc == success ))  ||  exit "$rc"

repo_path=$(resolve_repo_root "$repo_root" "$vm2_repos")
rc=$?
(( rc == success )) ||
    usage false "Could not resolve the repository root for '$repo_root' within '$vm2_repos'."

trace "Repository path: '$repo_path'"


# make sure we are seeing .github and vm2.DevOps properly through vm2_repos
validate_repo ".github" "$vm2_repos"
validate_repo "vm2.DevOps" "$vm2_repos"
exit_if_has_errors

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
