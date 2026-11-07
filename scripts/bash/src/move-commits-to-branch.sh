#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

#-----------------------------------------------------------------------------------------------
# @description Moves all commits from a given commit SHA (inclusive) onwards on the current 'main' branch to a new branch,
# then resets 'main' back to the commit before that SHA and force-pushes it. Use this to split a chain of commits that was
# accidentally accumulated on 'main' into its own feature branch.
#
# The script must be run from the 'main' branch with a clean working tree. It prompts for confirmation (default: no) after
# showing the commits that would be moved, before making any destructive change.
#
# Steps performed once confirmed:
#   1. Create '<new_branch>' at the current HEAD (so it carries all the commits from '<commit_sha>' onwards).
#   2. Reset 'main' to the commit before '<commit_sha>' ('git reset --hard <commit_sha>^').
#   3. Push '<new_branch>' to 'origin' (sets upstream tracking).
#   4. Force-push the rewound 'main' to 'origin'.
#   5. If '--check-out-new' was given, check out '<new_branch>'.
#
# Notes:
#   - This rewrites the history of 'origin/main' via a force push — coordinate with anyone else using the repository before
#     running this.
#
# @arg $@ string Named options: '--commit-sha|-c <sha>' (required), '--branch|-b <name>' (required),
#   '--check-out-new|-n' (optional switch).
#
# @exitcode success=0: The commits were moved and 'main' was reset and force-pushed successfully.
# @exitcode failure=1: The user declined the confirmation prompt (see the 'confirm' check below).
# @exitcode err_argument_value: Missing/invalid arguments, not on 'main', or the commit SHA does not exist.
# @exitcode err_tool_error: Uncommitted changes are present in the working tree.
#
# @stdout The list of commits that will be moved, a confirmation prompt, and progress/info messages for each step.
#
# @example
#   move-commits-to-branch.sh --commit-sha ff5c2d182c0d3a01c1f1dfd66c9267f0569d9802 --branch feature/my-feature
# @example
#   move-commits-to-branch.sh -c ff5c2d1 -b feature/my-feature -n
#-----------------------------------------------------------------------------------------------
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# core lib
source "$lib_dir/core.sh"

# core lib exit codes
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_tool_error

# core lib constants

# core lib variables
declare -x _ignore

# this script's components
source "$script_dir/move-commits-to-branch.args.sh"
source "$script_dir/move-commits-to-branch.usage.sh"

# this script's arguments
get_arguments "$@"
declare -xr commit_sha
declare -xr new_branch
declare -xr check_out_new_branch

# this script's variables
declare -xr current_branch

# Show the commits that will be moved
echo "Commits from $commit_sha onwards that would be moved to '$new_branch':"
git log --oneline "$commit_sha^..$current_branch"
echo ""
confirm "Do you want to continue?" "n" || exit "$failure"

echo ""
info "Step 1: Creating branch '$new_branch' at current HEAD..."
git branch "$new_branch"

info "Step 2: Resetting main to commit before $commit_sha..."
git reset --hard "$commit_sha^"

info "Step 3: Pushing new branch to the origin (GitHub)..."
git push -u origin "$new_branch"

info "Step 4: Force pushing main to the origin (GitHub)..."
git push --force origin main

if [[ "$check_out_new_branch" == true ]]; then
    info "Step 5: Checking out the new branch '$new_branch'..."
    git checkout "$new_branch"
fi
echo ""
info "Done! To switch to the new branch do: 'git checkout $new_branch'"
