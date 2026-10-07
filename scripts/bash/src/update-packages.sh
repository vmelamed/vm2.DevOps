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

[[ -n $summary_file ]] || {
    summary_file=$(mktemp -p /tmp "update-packages-summary-$(date +%Y%m%d-%H%M%S)-XXXXXX.md")
    trap 'rm -f "$summary_file"' EXIT
}

declare -gi search_us=0 search_count=0 restore_us=0
now_us() { local _t=$EPOCHREALTIME; echo "${_t/./}"; }
run_started_us=$(now_us)

declare -a summary_rows=()
declare -a scope=()
declare -a targets=()
declare -A mode=()
declare -A reason=()
declare -a warnings=()

declare -i phase_one=0
declare sot_path shared_file root_file branch name repo_file m r
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

# decide, before anything is written, how each repository may be changed
for name in "${targets[@]}"; do
    classify_repo "$vm2_repos/$name" m r
    mode[$name]=$m
    reason[$name]=$r
done

# the shared block is copied from the SoT, so a skipped SoT means no fan-out at all
if (( phase_one == 1 )) && [[ ${mode[$vm2_sot_repo_name]:-} == skip ]]; then
    warnings+=("'$vm2_sot_repo_name' has uncommitted changes: the SoT and the fan-out were skipped.")
    phase_one=0
fi

# a publish repository gets its upgrade branch now, before any file is written
for name in "${targets[@]}"; do
    [[ ${mode[$name]} == publish ]] || continue
    if is_dry_run; then
        continue
    fi
    if ! start_publish_branch "$vm2_repos/$name" "$branch"; then
        mode[$name]=inplace
        reason[$name]="could not create branch '$branch'; edited in place, nothing committed"
    fi
done

# phase 1: the shared block in the SoT, then the fan-out to the repositories
phase1_us=0 fanout_us=0 phase2_us=0 lock_us=0 commit_us=0
phase_start_us=$(now_us)
if (( phase_one == 1 )); then
    update_section_versions "$shared_file" shared "$vm2_sot_repo_name (SoT)" summary_rows
    update_section_versions "$root_file" shared "$vm2_sot_repo_name (root)" summary_rows
    phase1_us=$(( $(now_us) - phase_start_us ))

    fanout_start_us=$(now_us)
    if ! is_dry_run; then
        fan_out_names=()
        for name in "${targets[@]}"; do
            [[ ${mode[$name]} == skip ]] || fan_out_names+=("$name")
        done
        if (( ${#fan_out_names[@]} > 0 )); then
            diff_shared_cmd=("$diff_shared_script" --vm2-repos "$vm2_repos" --current-branch "${fan_out_names[@]}"
                              --file Directory.Packages.props --summary "$summary_file" --quiet)
            info "Running: ${diff_shared_cmd[*]}"
            "${diff_shared_cmd[@]}" ||
                error -ec "$err_tool_error" "diff-shared.sh failed while copying the shared block to the repositories."
        fi
        exit_if_has_errors false
    fi
    fanout_us=$(( $(now_us) - fanout_start_us ))
fi

# phase 2: each repository's own section, then the lock files
phase2_start_us=$(now_us)
for name in "${targets[@]}"; do
    [[ ${mode[$name]} == skip ]] && continue
    update_section_versions "$vm2_repos/$name/Directory.Packages.props" repo "$name" summary_rows
done
phase2_us=$(( $(now_us) - phase2_start_us ))

if ! is_dry_run; then
    lock_start_us=$(now_us)
    for name in "${targets[@]}"; do
        [[ ${mode[$name]} == skip ]] && continue
        refresh_lock_files "$vm2_repos/$name" || error -ec "$err_tool_error" "Failed to regenerate packages.lock.json in '$name'."
    done
    lock_us=$(( $(now_us) - lock_start_us ))
    exit_if_has_errors false

    # only 'publish' repositories are committed, pushed, and get a pull request
    declare -A pr_url=()
    commit_start_us=$(now_us)
    for name in "${targets[@]}"; do
        [[ ${mode[$name]} == publish ]] || continue
        paths=("Directory.Packages.props" "*packages.lock.json")
        if [[ $name == "$vm2_sot_repo_name" ]] && (( phase_one == 1 )); then
            paths+=("templates/AddNewPackage/content/Directory.Packages.props")
        fi
        commit_package_versions "$vm2_repos/$name" "chore(deps): update NuGet package versions in Directory.Packages.props" "${paths[@]}" ||
            error -ec "$err_tool_error" "Failed to commit the package versions in '$name'."
        git -C "$vm2_repos/$name" push --quiet -u origin "$branch" 2>"$_ignore" ||
            error -ec "$err_tool_error" "Failed to push '$branch' in '$name'."

        pr_url[$name]=''
        if open_pull_request "$vm2_repos/$name" "$branch" _pr_link; then
            pr_url[$name]=$_pr_link
            reason[$name]="📬 PR opened: $m -- please see it through"
        else
            warning "'$name': the branch was pushed, but opening a PR failed. Run 'gh pr create' in '$vm2_repos/$name'."
            reason[$name]="pushed to '$branch', but the PR was not created -- open it yourself"
        fi
    done
    commit_us=$(( $(now_us) - commit_start_us ))
    exit_if_has_errors false
fi

for w in "${warnings[@]}"; do
    warning "$w"
done
for name in "${targets[@]}"; do
    if [[ ${mode[$name]} == inplace ]]; then
        warning "'$name' was edited in place: review the changes, commit them yourself if you want them."
    fi
    if [[ ${mode[$name]} == skip ]]; then
        warning "'$name' was left untouched: commit or stash your changes, then run the script again."
    fi
done


{
    echo "## Package versions"
    echo
    echo "| Repository | Package | Current | New | Result |"
    echo "|:-----------|:--------|:--------|:----|:-------|"
    for row in "${summary_rows[@]}"; do
        IFS='|' read -r _label _package _current _new _result <<< "$row"
        echo "| $_label | $_package | $_current | $_new | $_result |"
    done
    echo
    echo "## Repository status"
    echo
    echo "| Repository | Mode | Status |"
    echo "|:-----------|:-----|:-------|"
    for name in "${targets[@]}"; do
        case "${mode[$name]}" in
            publish ) glyph="✅" ;;
            inplace ) glyph="✏️" ;;
            skip    ) glyph="⛔" ;;
            *       ) glyph="" ;;
        esac
        echo "| $name | $glyph ${mode[$name]} | ${reason[$name]} |"
    done
} >> "$summary_file"

ms() { local _us=$1; printf '%d.%01ds' $(( _us / 1000000 )) $(( (_us % 1000000) / 100000 )); }

{
    echo
    echo "## Timing"
    echo
    echo "| Step | Time |"
    echo "|:-----|:-----|"
    echo "| total | $(ms $(( $(now_us) - run_started_us ))) |"
    echo "| phase 1 (SoT) | $(ms "$phase1_us") |"
    echo "| fan-out (diff-shared) | $(ms "$fanout_us") |"
    echo "| phase 2 (repos) | $(ms "$phase2_us") |"
    echo "| lock refresh (of which \`dotnet restore\`) | $(ms "$lock_us") ($(ms "$restore_us")) |"
    echo "| commit and push | $(ms "${commit_us:-0}") |"
    echo "| package searches | $search_count calls, $(ms "$search_us") total |"
} >> "$summary_file"

# shellcheck disable=SC2015 # A && B || C is not if-then-else. C may run when A is true but B is false.
is_tool_present glow &&
    glow "$summary_file" -w 180 ||
    cat "$summary_file"

trace "Timing (seconds):"
trace "  total                 $(ms $(( $(now_us) - run_started_us )))"
trace "  phase 1 (SoT)         $(ms "$phase1_us")"
trace "  fan-out (diff-shared) $(ms "$fanout_us")"
trace "  phase 2 (repos)       $(ms "$phase2_us")"
trace "  lock refresh          $(ms "$lock_us")  (of which dotnet restore: $(ms "$restore_us"))"
trace "  commit and push       $(ms "${commit_us:-0}")"
trace "  package searches      $search_count calls, $(ms "$search_us") total"

if is_dry_run; then
    info "Dry run: no files were changed, no branches were created, and nothing was committed or pushed."
fi

exit_if_has_errors
