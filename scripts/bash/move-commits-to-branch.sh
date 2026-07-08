#!/usr/bin/env bash
#-------------------------------------------------------------------------------
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
# @exitcode 0 The commits were moved and 'main' was reset and force-pushed successfully, or the user declined to continue
#   (in which case the script exits with 1 — see the 'confirm' check below).
# @exitcode non-zero Missing/invalid arguments, not on 'main', uncommitted changes present, or the commit SHA does not exist
#   (see 'err_argument_value', 'err_tool_error' in '_error_codes.sh').
#
# @stdout The list of commits that will be moved, a confirmation prompt, and progress/info messages for each step.
#
# @example
#   move-commits-to-branch.sh --commit-sha ff5c2d182c0d3a01c1f1dfd66c9267f0569d9802 --branch feature/my-feature
# @example
#   move-commits-to-branch.sh -c ff5c2d1 -b feature/my-feature -n
#-------------------------------------------------------------------------------
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
source "$lib_dir/core.sh"
declare -x commit_sha=""
declare -x new_branch=""
declare -x check_out_new_branch=false

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_invalid_nameref
declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument
declare -rxi err_tool_error

source "$script_dir/move-commits-to-branch.args.sh"
source "$script_dir/move-commits-to-branch.usage.sh"

get_arguments "$@"

# freeze the arguments
declare -rx commit_sha
declare -rx new_branch
declare -rx check_out_new_branch

if [[ -z "$commit_sha" || -z "$new_branch" ]]; then
    usage -ec "$err_argument_value" "The options '--commit-sha' and '--branch' are mandatory and cannot be null or empty"
fi

if [[ ! "$commit_sha" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    usage -ec "$err_argument_value" "The commit SHA must be a valid 7 to 40 hexadecimal digits string"
fi

if [[ "$new_branch" == "main" ]]; then
    usage -ec "$err_argument_value" "The new branch name cannot be 'main'"
fi
# Verify we're on main branch
current_branch=$(git branch --show-current)
if [[ "$current_branch" != "main" ]]; then
    usage -ec "$err_argument_value" "You must be on the 'main' branch. Currently on '$current_branch'"
fi
# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    usage -ec "$err_tool_error" "You have uncommitted changes. Please commit or stash them first."
fi
# Verify the commit exists
# shellcheck disable=SC2154
if ! git cat-file -e "$commit_sha^{commit}" 2>"$_ignore"; then
    usage -ec "$err_argument_value" "Commit '$commit_sha' does not exist"
fi

# Show the commits that will be moved
echo "Commits from $commit_sha onwards that would be moved to '$new_branch':"
git log --oneline "$commit_sha^..$current_branch"
echo ""
if ! confirm "Do you want to continue?" "n"; then
    exit 1
fi

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
info "Done! To switch to the new branch: git checkout $new_branch"
