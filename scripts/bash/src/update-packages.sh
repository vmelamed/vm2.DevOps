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

declare -gi search_us=0 search_count=0 restore_us=0
now_us() { local _t=$EPOCHREALTIME; echo "${_t/./}"; }
run_started_us=$(now_us)

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

declare -A starting_branch=()
base_branch=main
(( on_current_branch == 1 )) && base_branch=''
for name in "${targets[@]}"; do
    starting_branch[$name]=$(git -C "$vm2_repos/$name" branch --show-current)
done

if ! is_dry_run; then
    for name in "${targets[@]}"; do
        prepare_upgrade_branch "$vm2_repos/$name" "$branch" "$base_branch" || error -ec "$err_tool_error" "Failed to create branch '$branch' in '$name'."
    done
    exit_if_has_errors false
fi

# phase 1: the shared block in the SoT, then the fan-out to the repositories
phase1_us=0 fanout_us=0 phase2_us=0 lock_us=0
phase_start_us=$(now_us)
if (( phase_one == 1 )); then
    update_section_versions "$shared_file" shared "$vm2_sot_repo_name (SoT)" summary_rows
    update_section_versions "$root_file" shared "$vm2_sot_repo_name (root)" summary_rows

    phase1_us=$(( $(now_us) - phase_start_us ))
    fanout_start_us=$(now_us)
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

fanout_us=$(( $(now_us) - ${fanout_start_us:-$(now_us)} ))

# phase 2: each repository's own section
phase2_start_us=$(now_us)
for name in "${targets[@]}"; do
    update_section_versions "$vm2_repos/$name/Directory.Packages.props" repo "$name" summary_rows
done

phase2_us=$(( $(now_us) - phase2_start_us ))

if ! is_dry_run; then
    lock_start_us=$(now_us)
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

    lock_us=$(( $(now_us) - lock_start_us ))
    for name in "${targets[@]}"; do
        refresh_lock_files "$vm2_repos/$name" || error -ec "$err_tool_error" "Failed to restore or commit packages.lock.json in '$name'."
    done
    exit_if_has_errors false
fi

if ! is_dry_run && (( on_current_branch == 1 )); then
    for name in "${targets[@]}"; do
        merge_back_to_starting_branch "$vm2_repos/$name" "${starting_branch[$name]}" "$branch" ||
            error -ec "$err_tool_error" "Failed to merge '$branch' back into '${starting_branch[$name]}' in '$name'."
    done
    exit_if_has_errors false
fi

print_upgrade_summary "${summary_rows[@]}"

ms() { local _us=$1; printf '%d.%01ds' $(( _us / 1000000 )) $(( (_us % 1000000) / 100000 )); }
info "Timing (seconds):"
info "  total                 $(ms $(( $(now_us) - run_started_us )))"
info "  phase 1 (SoT)         $(ms "$phase1_us")"
info "  fan-out (diff-shared) $(ms "$fanout_us")"
info "  phase 2 (repos)       $(ms "$phase2_us")"
info "  lock refresh          $(ms "$lock_us")  (of which dotnet restore: $(ms "$restore_us"))"
info "  package searches      $search_count calls, $(ms "$search_us") total"

if is_dry_run; then
    info "Dry run: no files were changed, no branches were created, and nothing was committed."
else
    if (( on_current_branch == 1 )); then
        info "Changes were merged into each repository's starting branch (${targets[*]}). Nothing was pushed."
    else
        info "Changes are committed on branch '$branch' in: ${targets[*]}. Nothing was pushed."
    fi
fi

exit_if_has_errors
