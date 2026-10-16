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

declare -xr edit_em
declare -xr check_em
declare -xr no_entry_em
declare -xr error_em

declare -xr dpp_file_name="Directory.Packages.props"

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

declare -A target_repos=()      # dictionary repo name - repo path
declare -a target_dpp_files=()  # Directory.Packages.props files
declare -a summary_rows=()
declare -A modes=()
declare -A reasons=()
declare -a warnings=()

declare -i phase_one=0 _commit_rc=0
declare sot_path shared_file new_branch repo dpp_file m r _pr_link

new_branch="deps/update-packages-$(date +%Y-%m-%d)"
shared_file="$sot_path/Directory.Packages.props"
readonly new_branch shared_file

is_in "$vm2_sot_repo_name" "${!target_repos[@]}" && phase_one=1 || phase_one=0

for repo in "${!target_repos[@]}"; do
    dpp_file="${target_repos[$repo]}/$dpp_file_name"
    # shellcheck disable=SC2015 # A && B || C is not if-then-else. C may run when A is true but B is false.
    [[ -f $dpp_file ]] && target_dpp_files+=("$dpp_file") || trace "Skipping '$repo': it has no '$dpp_file_name' file."
done

# decide, before anything is written, how each repository may be changed
info "Checking the status of ${#target_dpp_files[@]} repositories (branch, working tree, sync with origin/main)..."
for repo in "${!target_repos[@]}"; do
    info "  $repo: checking..."
    classify_repo "${target_repos[$repo]}" m r
    modes[$repo]=$m
    reasons[$repo]=$r
done

# the shared block is copied from the SoT, so a skipped SoT means no fan-out at all
if (( phase_one == 1 )) && [[ ${modes[$vm2_sot_repo_name]:-} == skip ]]; then
    warnings+=("'$vm2_sot_repo_name' has uncommitted changes: the SoT and the fan-out were skipped.")
    phase_one=0
fi

# a publish repository gets its upgrade branch now, before any file is written
publish_count=0
for repo in "${!target_repos[@]}"; do
    [[ ${modes[$repo]} == publish ]] && (( ++publish_count ))
done

(( publish_count > 0 )) && info "Creating branch '$new_branch' in $publish_count repositor$([[ $publish_count == 1 ]] && echo y || echo ies)..."
for repo in "${!target_repos[@]}"; do
    [[ ${modes[$repo]} == publish ]] || continue
    is_dry_run && continue
    if ! start_publish_branch "$vm2_repos/$repo" "$new_branch"; then
        modes[$repo]=inplace
        reasons[$repo]="could not create branch '$new_branch'; edited in place, nothing committed"
    fi
done

# phase 1: the shared block in the SoT, then the fan-out to the repositories
phase1_us=0 fanout_us=0 phase2_us=0 lock_us=0 commit_us=0
phase_start_us=$(now_us)
if (( phase_one == 1 )); then
    info "Phase 1: checking the shared block's packages against NuGet (run with --verbose to see each one)..."
    update_section_versions "$shared_file" shared "$vm2_sot_repo_name (SoT)" summary_rows
    phase1_us=$(( $(now_us) - phase_start_us ))

    fanout_start_us=$(now_us)
    if ! is_dry_run; then
        fan_out_names=()
        for repo in "${target_dpp_files[@]}"; do
            [[ ${modes[$repo]} == skip ]] || fan_out_names+=("$repo")
        done
        if (( ${#fan_out_names[@]} > 0 )); then
            diff_shared_cmd=("$diff_shared_script" --vm2-repos "$vm2_repos" --current-branch "${fan_out_names[@]}"
                              --file Directory.Packages.props --summary-file "$summary_file" --quiet)
            info "Running: ${diff_shared_cmd[*]}"
            "${diff_shared_cmd[@]}" ||
                error -ec "$err_tool_error" "diff-shared.sh failed while copying the shared block to the repositories."
        fi
        exit_if_has_errors false
    fi
    fanout_us=$(( $(now_us) - fanout_start_us ))
fi

# phase 2: each repository's own section, then the lock files
info "Phase 2: checking each repository's own packages against NuGet..."
phase2_start_us=$(now_us)
for repo in "${target_dpp_files[@]}"; do
    [[ ${modes[$repo]} == skip ]] && continue
    info "  $repo: checking its own packages..."
    update_section_versions "$vm2_repos/$repo/Directory.Packages.props" repo "$repo" summary_rows
done
phase2_us=$(( $(now_us) - phase2_start_us ))

if ! is_dry_run; then
    info "Regenerating packages.lock.json in each repository (this runs 'dotnet restore --force-evaluate')..."
    lock_start_us=$(now_us)
    for repo in "${target_dpp_files[@]}"; do
        [[ ${modes[$repo]} == skip ]] && continue
        info "  $repo: running dotnet restore --force-evaluate..."
        refresh_lock_files "$vm2_repos/$repo" || error -ec "$err_tool_error" "Failed to regenerate packages.lock.json in '$repo'."
    done
    lock_us=$(( $(now_us) - lock_start_us ))
    exit_if_has_errors false

    # only 'publish' repositories are committed, pushed, and get a pull request
    (( publish_count > 0 )) && info "Committing, pushing, and opening pull requests for $publish_count repositor$([[ $publish_count == 1 ]] && echo y || echo ies)..."
    commit_start_us=$(now_us)
    for repo in "${target_dpp_files[@]}"; do
        [[ ${modes[$repo]} == publish ]] || continue
        info "  $repo: committing, pushing, and opening a pull request..."
        paths=("Directory.Packages.props" "*packages.lock.json")
        if [[ $repo == "$vm2_sot_repo_name" ]] && (( phase_one == 1 )); then
            paths+=("templates/AddNewPackage/content/Directory.Packages.props")
        fi

        commit_package_versions "$vm2_repos/$repo" "chore(deps): update NuGet package versions in Directory.Packages.props" "${paths[@]}" &&
            _commit_rc=$success || _commit_rc=$?
        if (( _commit_rc == negative )); then
            reasons[$repo]="$check_em already up to date -- nothing to commit"
            continue
        elif (( _commit_rc != success )); then
            error -ec "$err_tool_error" "Failed to commit the package versions in '$repo'."
            continue
        fi

        git -C "$vm2_repos/$repo" push --quiet -u origin "$new_branch" 2>"$_ignore" || {
            error -ec "$err_tool_error" "Failed to push '$new_branch' in '$repo'."
            continue
        }

        if open_pull_request "$vm2_repos/$repo" "$new_branch" _pr_link; then
            reasons[$repo]="📬 PR opened: $_pr_link -- please see it through"
        else
            warning "'$repo': the branch was pushed, but opening a PR failed. Run 'gh pr create' in '$vm2_repos/$repo'."
            reasons[$repo]="pushed to '$new_branch', but the PR was not created -- open it yourself"
        fi
    done
    commit_us=$(( $(now_us) - commit_start_us ))
    exit_if_has_errors false
fi

for w in "${warnings[@]}"; do
    warning "$w"
done
for repo in "${target_dpp_files[@]}"; do
    if [[ ${modes[$repo]} == inplace ]]; then
        warning "'$repo' was edited in place: review the changes, commit them yourself if you want them."
    fi
    if [[ ${modes[$repo]} == skip ]]; then
        warning "'$repo' was left untouched: commit or stash your changes, then run the script again."
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
    for repo in "${target_dpp_files[@]}"; do
        case "${modes[$repo]}" in
            publish ) glyph=$check_em ;;
            inplace ) glyph=$edit_em ;;
            skip    ) glyph=$no_entry_em ;;
            *       ) glyph=$error_em ;;
        esac
        echo "| $repo | $glyph ${modes[$repo]} | ${reasons[$repo]} |"
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
