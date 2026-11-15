#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

#-----------------------------------------------------------------------------------------------
# @description Moves all commits from a given commit SHA (inclusive) onwards on the current default branch (main) to a new
#   branch, then resets the default branch back to the commit before that SHA and force-pushes it. Use this to split a chain of
#   commits that was accidentally accumulated on the default branch into its own feature branch.
#
# The script must be run from the default branch branch with a clean working tree. It prompts for confirmation (default: no) after
# showing the commits that would be moved, before making any destructive change.
#
# Steps performed once confirmed:
#   1. Create '<new_branch>' at the current HEAD (so it carries all the commits from '<commit_sha>' onwards).
#   2. Reset the default branch to the commit before '<commit_sha>' ('git reset --hard <commit_sha>^').
#   3. Push '<new_branch>' to 'origin' (sets upstream tracking).
#   4. Force-push the rewound the default branch to 'origin'.
#   5. If '--check-out-new' was given, check out '<new_branch>'.
#
# Notes:
#   - This rewrites the history of 'origin/$default_branch' via a force push — coordinate with anyone else using the repository
#     before running this.
#
# @arg $@ string Named options: '--commit-sha|-c <sha>' (required), '--branch|-b <name>' (required),
#   '--check-out-new|-n' (optional switch).
#
# @exitcode success=0: The commits were moved and the default branch was reset and force-pushed successfully.
# @exitcode failure=1: The user declined the confirmation prompt (see the 'confirm' check below).
# @exitcode err_argument_value: Missing/invalid arguments, not on the default branch, or the commit SHA does not exist.
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

declare -x script_name
declare -x script_dir
declare -x lib_dir

# vm2 core lib
source "$lib_dir/core.sh"

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_argument_type
declare -x err_argument_value
declare -x err_invalid_nameref
declare -x err_missing_argument
declare -x err_too_many_arguments
declare -x err_unknown_argument
declare -x err_tool_error

# vm2 core lib constants

# vm2 core lib variables
declare -x _ignore

# this script's components
source "$script_dir/move-commits-to-branch.args.sh"
source "$script_dir/move-commits-to-branch.usage.sh"

# this script's arguments
get_arguments "$@"
declare -x commit_sha
declare -x new_branch
declare -x check_out_new_branch

# this script's variables
declare -x current_branch
declare -x default_branch

# Show the commits that will be moved
echo "Commits from $commit_sha onwards that would be moved to '$new_branch':"
git log --oneline "$commit_sha^..$current_branch"
echo ""
confirm "Do you want to continue?" "n" || exit "$failure"

echo ""
info "Step 1: Creating branch '$new_branch' at current HEAD..."
execute git branch "$new_branch"

info "Step 2: Resetting '$default_branch' to commit before $commit_sha..."
execute git reset --hard "$commit_sha^"

info "Step 3: Pushing new branch to the origin (GitHub)..."
execute git push -u origin "$new_branch"

info "Step 4: Force pushing '$default_branch' to the origin (GitHub)..."
execute git push --force-with-lease origin "$default_branch"

if [[ "$check_out_new_branch" == true ]]; then
    info "Step 5: Checking out the new branch '$new_branch'..."
    execute git checkout "$new_branch"
fi
echo ""
# shellcheck disable=SC2015 # Info: Note that A && B || C is not if-then-else. C may run when A is true.
is_dry_run &&
    info "Nothing done in dry-run mode!" ||
    info "Done! To switch to the new branch do: 'git checkout $new_branch'"
