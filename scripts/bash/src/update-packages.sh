#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

source "$lib_dir/core.sh"

declare -xr default_vm2_repos_path
declare -xr vm2_sot_repo_name
declare -xra vm2_repositories

declare -x vm2_repos="${VM2_REPOS:-$default_vm2_repos_path}"
# overridable so the tests can replace the fan-out step with a fake
declare -x diff_shared_script="${UPDATE_PACKAGES_DIFF_SHARED:-$script_dir/diff-shared.sh}"

source "$script_dir/update-packages.functions.sh"
source "$script_dir/update-packages.repos.sh"
source "$script_dir/update-packages.args.sh"
source "$script_dir/update-packages.usage.sh"

get_arguments "$@"

declare -a summary_rows=()
declare -a scope=()
declare -a targets=()
declare -a fan_out_names=()

declare -i phase_one=0
declare sot_path shared_file root_file branch name repo_file
branch="deps/update-packages-$(date +%Y-%m-%d)"
sot_path="$vm2_repos/$vm2_sot_repo_name"
shared_file="$sot_path/templates/AddNewPackage/content/Directory.Packages.props"
root_file="$sot_path/Directory.Packages.props"
readonly branch sot_path shared_file root_file

if (( ${#requested_repos[@]} == 0 )); then
    scope=("${vm2_repositories[@]}")
    phase_one=1
else
    scope=("${requested_repos[@]}")
    is_in "$vm2_sot_repo_name" "${scope[@]}" && phase_one=1 || phase_one=0
fi

for name in "${scope[@]}"; do
    repo_file="$vm2_repos/$name/Directory.Packages.props"
    [[ -f $repo_file ]] && targets+=("$name") || trace "Skipping '$name': it has no Directory.Packages.props."
done

if ! is_dry_run; then
    for name in "${targets[@]}"; do
        prepare_upgrade_branch "$vm2_repos/$name" "$branch" || error -ec "$err_tool_error" "Failed to create branch '$branch' in '$name'."
    done
    exit_if_has_errors false
fi

# phase 1: the shared block in the SoT, then the fan-out to the repositories
if (( phase_one == 1 )); then
    update_section_versions "$shared_file" shared "$vm2_sot_repo_name (SoT)" summary_rows
    update_section_versions "$root_file" shared "$vm2_sot_repo_name (root)" summary_rows

    if ! is_dry_run; then
        for name in "${targets[@]}"; do
            [[ $name == "$vm2_sot_repo_name" ]] || fan_out_names+=("$name")
        done
        if [[ ${#requested_repos[@]} == 0 ]]; then
            "$diff_shared_script" --vm2-repos "$vm2_repos" --current-branch --all-repos --file Directory.Packages.props --quiet ||
                error -ec "$err_tool_error" "diff-shared.sh failed while copying the shared block to the repositories."
        elif (( ${#fan_out_names[@]} > 0 )); then
            "$diff_shared_script" --vm2-repos "$vm2_repos" --current-branch "${fan_out_names[@]}" --file Directory.Packages.props --quiet ||
                error -ec "$err_tool_error" "diff-shared.sh failed while copying the shared block to the repositories."
        fi
        exit_if_has_errors false
    fi
fi

# phase 2: each repository's own section
for name in "${targets[@]}"; do
    update_section_versions "$vm2_repos/$name/Directory.Packages.props" repo "$name" summary_rows
done

if ! is_dry_run; then
    for name in "${targets[@]}"; do
        if [[ $name == "$vm2_sot_repo_name" ]] && (( phase_one == 1 )); then
            commit_package_versions "$vm2_repos/$name" "chore(deps): update NuGet package versions in Directory.Packages.props" \
                "templates/AddNewPackage/content/Directory.Packages.props" "Directory.Packages.props" ||
                error -ec "$err_tool_error" "Failed to commit the package versions in '$name'."
        else
            commit_package_versions "$vm2_repos/$name" "chore(deps): update NuGet package versions in Directory.Packages.props" \
                "Directory.Packages.props" ||
                error -ec "$err_tool_error" "Failed to commit the package versions in '$name'."
        fi
    done
    exit_if_has_errors false
fi

print_upgrade_summary "${summary_rows[@]}"

if is_dry_run; then
    info "Dry run: no files were changed, no branches were created, and nothing was committed."
else
    info "Changes are committed on branch '$branch' in: ${targets[*]}. Nothing was pushed."
fi

exit_if_has_errors
