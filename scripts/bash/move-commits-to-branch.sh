#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2154 # GIT_REPOS is referenced but not assigned. It is expected to be set in the environment.
this_script=${BASH_SOURCE[0]}

script_name=$(basename "$this_script")
script_dir=$(dirname "$(realpath -e "$this_script")")
common_dir=$(realpath "${script_dir%/}/../../.github/actions/scripts")

declare -xr script_name
declare -xr script_dir
declare -xr common_dir

# shellcheck disable=SC1091
source "${common_dir}/_common.sh"

declare -x commit_sha=""
declare -x new_branch=""
declare -x check_out_new_branch=false

source "${script_dir}/move-commits-to-branch.utils.sh"
source "${script_dir}/move-commits-to-branch.usage.sh"

get_arguments "$@"

# freeze the arguments
declare -rx commit_sha
declare -rx new_branch
declare -rx check_out_new_branch

if [[ -z "$commit_sha" || -z "$new_branch" ]]; then
    usage false "The options '--commit-sha' and '--branch' are mandatory and cannot be null or empty" >&2
fi

if [[ ! "$commit_sha" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    usage false "The commit SHA must be a valid 7 to 40 hexadecimal digits string" >&2
fi

if [[ "$new_branch" == "main" ]]; then
    usage false "The new branch name cannot be 'main'" >&2
fi
# Verify we're on main branch
current_branch=$(git branch --show-current)
if [[ "$current_branch" != "main" ]]; then
    usage false "You must be on the 'main' branch. Currently on '$current_branch'" >&2
fi
# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    usage false "You have uncommitted changes. Please commit or stash them first." >&2
    git status --short
fi
# Verify the commit exists
if ! git cat-file -e "$commit_sha^{commit}" 2>/dev/null; then
    usage false "Commit '$commit_sha' does not exist" >&2
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
