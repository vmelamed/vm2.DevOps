#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
source "${lib_dir}/core.sh"

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

# Save the current head

declare -x old_branch_name=""
declare -x new_branch_name=""

source "$script_dir/rename-branch.args.sh"
source "$script_dir/rename-branch.usage.sh"

get_arguments "$@"

[[ -n "$new_branch_name" ]] || usage -ec "$err_missing_argument" "No new branch name provided."

if [[ -z "$old_branch_name" ]]; then
    # Get the current branch name if old_branch_name was not provided
    # shellcheck disable=SC2154 # _ignore is referenced but not assigned.
    old_branch_name=$(git branch --show-current 2>"$_ignore") || usage -ec "$err_missing_argument" "Old name not specified, HEAD is detached, or not in a repo."
    [[ -n "$old_branch_name" ]] || usage -ec "$err_missing_argument" "Old name not specified, HEAD is detached, or not in a repo."
fi

# The same names?
[[ "$old_branch_name" != "$new_branch_name" ]] || usage -ec "$err_argument_value" "The new branch name is the same as the old branch name."

# Fetch latest remote refs
git fetch origin 1>"$_ignore" || usage -ec "$err_tool_error" "Failed to fetch from remote."

# Check if it is a valid git branch name?
# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
git check-ref-format --branch "$new_branch_name" 1>"$_ignore" || usage -ec "$err_argument_value" "Invalid branch name '$new_branch_name'."
# Make sure that a local branch with the new name does not already exist:
git show-ref --verify --quiet "refs/heads/$new_branch_name" 1>"$_ignore" && usage -ec "$err_argument_value" "Branch '$new_branch_name' already exists locally."

# Check if a remote branch with the new name already exists:
git show-ref --verify --quiet "refs/remotes/origin/$new_branch_name" 1>"$_ignore" && usage -ec "$err_argument_value" "Branch '$new_branch_name' already exists on remote."

# valid name?
git check-ref-format --branch "$old_branch_name" 1>"$_ignore" || usage -ec "$err_argument_value" "Invalid branch name '$old_branch_name'."
# Check if the old branch exists locally:
git show-ref --verify --quiet "refs/heads/$old_branch_name" 1>"$_ignore" || usage -ec "$err_argument_value" "Branch '$old_branch_name' does not exist locally."
# Check if the old branch exists remotely:
git show-ref --verify --quiet "refs/remotes/origin/$old_branch_name" 1>"$_ignore" || usage -ec "$err_argument_value" "Branch '$old_branch_name' does not exist remotely."

# ==============================================================================
# input validated, now do the work:

# 1. We don't need to switch to the old branch that we want to rename
# 2. Rename the branch locally
git branch -m "$old_branch_name" "$new_branch_name" 1> "$_ignore" || usage -ec "$err_tool_error" "Failed to rename branch '$old_branch_name' to '$new_branch_name'."
# 3. Push the new name to remote
git push origin "$new_branch_name" 1> "$_ignore" ||  usage -ec "$err_tool_error" "Failed to push branch '$new_branch_name' to remote."
# 4. Delete the old branch on remote
git push origin --delete "$old_branch_name" 1> "$_ignore" ||
    warning "Failed to delete old branch '$old_branch_name' on remote. Please clean up manually; otherwise both branches will coexist and that may lead to confusion."


# 5. Reset the upstream tracking
git branch --set-upstream-to="origin/$new_branch_name" "$new_branch_name" 1> "$_ignore" || usage -ec "$err_tool_error" "Failed to set upstream tracking for '$new_branch_name'."

info "Branch '$old_branch_name' successfully renamed to '$new_branch_name'."
