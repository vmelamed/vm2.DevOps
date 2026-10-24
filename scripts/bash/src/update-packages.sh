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

# core constants
declare -xr edit_em
declare -xr check_em
declare -xr no_entry_em
declare -xr error_em
declare -xr warn_em

declare -xr vm2_sot_repo_name   # vm2.Templates

# script constants
declare -xr dpp_file_name="Directory.Packages.props"
declare -x diff_shared_script="${UPDATE_PACKAGES_DIFF_SHARED:-$script_dir/diff-shared.sh}"    # overridable so the tests can replace the fan-out step with a fake

source "$script_dir/update-packages.functions.sh"
source "$script_dir/update-packages.repos.sh"
source "$script_dir/update-packages.args.sh"
source "$script_dir/update-packages.usage.sh"

# script arguments
declare -x vm2_repos            # the path to the folder containing all vm2 repositories, usually '$VM2_REPOS'
declare -x sot                  # the source of truth name, usually 'AddNewPackages'
declare -x sot_path             # the path to the source of truth folder, usually '$VM2_REPOS/vm2.Templates/templates/<sot>/content'
declare -A target_repos         # dictionary: repo name => repo path
declare -x summary_file         # the path to the summary file for the update operation(s)

# timing variables for performance measurement. us stands for microseconds.
declare -xi search_us=0
declare -xi restore_us=0
declare -xi search_count=0

declare -a summary_rows=()
declare -A modes=()
declare -A reasons=()
declare -a warnings=()

get_arguments "$@"

info "All vm2 repositories are expected to be in '$vm2_repos'"
info "The Source of Truth '$sot' folder is in '$sot_path'"

run_started_us=$(now_us)

declare include_sot_repo=true

is_in "$vm2_sot_repo_name" "${!target_repos[@]}" || include_sot_repo=false

# decide, before anything is written, how each repository may be changed
declare repo_path
declare mode
declare reason
declare -i publish_count=0

# Classify all repositories before making any changes:
# publish: on 'main', clean, and identical to 'origin/main' after a fetch, so a branch can be created, committed, and pushed.
# inplace: the files are edited in the current branch and nothing is committed.
# skip: uncommitted changes exist, so the repository is left untouched.
for repo in "${!target_repos[@]}"; do
    repo_path=${target_repos[$repo]}
    info "  $repo: checking..."
    classify_repo "${target_repos[$repo]}" mode reason
    modes[$repo]=$mode
    reasons[$repo]=$reason
    [[ $mode == publish ]] && (( ++publish_count ))
done
info "Checked the status of ${#target_repos[@]} repositories (branch, working tree, sync with origin/main)..."

# the shared block is copied from the SoT, if it is skipped, then no fan-out at all
if $include_sot_repo && [[ ${modes[$vm2_sot_repo_name]:-} != publish ]]; then
    warnings+=("'$vm2_sot_repo_name' ${reasons[$vm2_sot_repo_name]}: the SoT and the fan-out were skipped.")
    include_sot_repo=false
fi

declare new_branch
new_branch="deps/update-packages-$(date +%Y-%m-%d-%H-%M-%S)"
readonly new_branch

# Create the new branch in all repositories marked for publishing
trace "Creating branch '$new_branch' in the repositories marked for publishing..."
for repo in "${!target_repos[@]}"; do
    [[ ${modes[$repo]} == publish ]] ||
        continue
    if ! start_publish_branch "${target_repos[$repo]}" "$new_branch"; then
        modes[$repo]=inplace
        reasons[$repo]="could not create branch '$new_branch'; edited in place, nothing committed"
    fi
done
(( publish_count > 0 )) && info "Created branch '$new_branch' in $publish_count repositor$([[ $publish_count == 1 ]] && echo y || echo ies)..."

# PHASE 1: the shared block in the SoT, then the fan-out to the repositories
declare -i phase1_us=0
declare -i phase2_us=0
declare -i fanout_us=0
declare -i lock_us=0
declare -i commit_us=0

if $include_sot_repo; then

    declare shared_file
    shared_file="$sot_path/$dpp_file_name"
    readonly shared_file

    info "Phase 1: checking the packages in the shared block of the SoT $dpp_file_name file against NuGet (run with --verbose to see each one)..."
    phase_0=$(now_us)
    update_section_versions "$shared_file" shared "$vm2_sot_repo_name (SoT)" summary_rows
    phase_1=$(now_us)
    phase1_us=$(( phase_1 - phase_0 ))

    fan_out_names=()
    for repo in "${!target_repos[@]}"; do
        [[ ${modes[$repo]} == skip ]] || fan_out_names+=("$repo")
    done
    if (( ${#fan_out_names[@]} > 0 )); then
        diff_shared_args=(
            "--vm2-repos" "$vm2_repos"
            "--current-branch"
            --file "$dpp_file_name"
            "${fan_out_names[@]}"
            --summary-file "$summary_file"
            --quiet
        )
        ! is_dry_run || diff_shared_args+=('--dry-run')
        info "Running: $diff_shared_script ${diff_shared_args[*]}"

        fanout_0=$(now_us)
        "$diff_shared_script" "${diff_shared_args[@]}" ||
            error -ec "$err_tool_error" "diff-shared.sh failed while copying the shared block to the repositories."
        fanout_1=$(now_us)
        fanout_us=$(( fanout_1 - fanout_0 ))
    fi
    exit_if_has_errors false
fi

# PHASE 2: each repository's own section, then the lock files
info "Phase 2: checking each repository's own packages against NuGet..."
phase_0=$(now_us)
for repo in "${!target_repos[@]}"; do
    [[ ${modes[$repo]} == skip ]] && continue
    info "  $repo: checking its own packages..."
    update_section_versions "${target_repos[$repo]}/$dpp_file_name" repo "$repo" summary_rows
done
phase_1=$(now_us)
phase2_us=$(( phase_1 - phase_0 ))

info "Regenerating packages.lock.json in each repository (this runs 'dotnet restore --force-evaluate')..."
lock_0=$(now_us)
for repo in "${!target_repos[@]}"; do
    [[ ${modes[$repo]} == skip ]] && continue
    info "  $repo: running dotnet restore --force-evaluate..."
    refresh_lock_files "${target_repos[$repo]}" || error -ec "$err_tool_error" "Failed to regenerate packages.lock.json in '$repo'."
done
lock_1=$(now_us)
lock_us=$(( lock_1 - lock_0 ))
exit_if_has_errors false

# only 'publish' repositories are committed, pushed, and get a pull request
(( publish_count > 0 )) && info "Committing, pushing, and opening pull requests for $publish_count repositor$([[ $publish_count == 1 ]] && echo y || echo ies)..."
commit_0=$(now_us)
declare _pr_link
for repo in "${!target_repos[@]}"; do
    [[ ${modes[$repo]} == publish ]] || continue
    info "  $repo: committing, pushing, and opening a pull request..."
    repo_path=${target_repos[$repo]}
    paths=("$dpp_file_name" "*packages.lock.json")
    if [[ $repo == "$vm2_sot_repo_name" ]] && $include_sot_repo; then
        paths+=("templates/$sot/content/$dpp_file_name")
    fi

    declare -i _commit_rc=$success

    commit_package_versions "$repo_path" "chore(deps): update NuGet package versions in '$dpp_file_name'" "${paths[@]}" || _commit_rc=$?

    if (( _commit_rc == negative )); then
        is_dry_run &&
            reasons[$repo]="dry run: would commit, push '$new_branch', and open a pull request" ||
            reasons[$repo]="$check_em already up to date -- nothing to commit"
        continue
    elif (( _commit_rc != success )); then
        error -ec "$err_tool_error" "Failed to commit the package versions in '$repo'."
        continue
    fi

    execute --quiet git -C "$repo_path" push --quiet -u origin "$new_branch" || {
        error -ec "$err_tool_error" "Failed to push '$new_branch' in '$repo'."
        continue
    }

    if open_pull_request "$repo_path" "$new_branch" _pr_link; then
        reasons[$repo]="📬 PR opened: $_pr_link -- please see it through"
    else
        warning "'$repo': the branch was pushed, but opening a PR failed. Run 'gh pr create' in '$repo_path'."
        reasons[$repo]="pushed to '$new_branch', but the PR was not created -- open it yourself"
    fi
done
commit_1=$(now_us)
commit_us=$(( commit_1 - commit_0 ))
exit_if_has_errors false

for w in "${warnings[@]}"; do
    warning "$w"
done

for repo in "${!target_repos[@]}"; do
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
    for repo in "${!target_repos[@]}"; do
        case "${modes[$repo]}" in
            publish ) glyph=$check_em ;;
            inplace ) glyph=$edit_em ;;
            skip    ) glyph=$no_entry_em ;;
            *       ) glyph=$error_em ;;
        esac
        echo "| $repo | $glyph ${modes[$repo]} | ${reasons[$repo]} |"
    done
} >> "$summary_file"

if ! is_empty_array warnings; then {
    echo "## $warn_em Warnings"
    echo
    for w in "${warnings[@]}"; do
        echo "1. $w"
    done
} >> "$summary_file"
fi

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

exit_if_has_errors
