#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -x script_name
declare -x script_dir
declare -x lib_dir

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
declare -x git_heads_ns
declare -x git_remotes_ns

# vm2 core lib variables
declare -x noise_sink

#-----------------------------------------------------------------------------------------------
# @description Renames a Git branch both locally and on the 'origin' remote, and re-points the local branch's upstream
# tracking to the new remote name.
#
# The script validates both names before making any change: the new name must be a syntactically valid Git branch name and
# must not already exist locally or on 'origin'; the old name (explicit or the current branch) must be a syntactically valid
# Git branch name that exists both locally and on 'origin'.
#
# Notes:
#   - If <old_branch_name> is omitted, the current branch (HEAD) is renamed.
#   - The old branch is not checked out before the rename — 'git branch -m' can rename a branch that is not currently
#     checked out.
#   - If deleting the old branch on 'origin' fails after the new branch has been pushed, the script logs a warning and
#     continues rather than failing, since the rename itself already succeeded.
#
# @arg $1 string The name of the existing branch to rename (optional; defaults to the current branch).
# @arg $2 string The new name for the branch. Required. Must be a valid Git branch name and must not already exist locally or
#   on 'origin'.
#
# @exitcode success=0: The branch was renamed and pushed successfully.
# @exitcode err_missing_argument: No new branch name was given, or the old branch name could not be determined
#   (detached HEAD or not in a repo).
# @exitcode err_argument_value: The branch names are identical, a name is not a valid Git branch name, the new
#   name already exists (locally or on 'origin'), or the old name does not exist (locally or on 'origin').
# @exitcode err_tool_error: A git operation ('fetch', 'branch -m', 'push', or 'branch --set-upstream-to') failed.
#
# @stdout Progress/info messages (e.g. the final "Branch '<old>' successfully renamed to '<new>'." confirmation).
#
# @example
#   rename-branch.sh feature/old-name feature/new-name
# @example
#   rename-branch.sh feature/new-name   # renames the current branch
#-----------------------------------------------------------------------------------------------

source "$script_dir/rename-branch.args.sh"
source "$script_dir/rename-branch.usage.sh"

# this script arguments
get_arguments "$@"
declare -x old_branch_name
declare -x new_branch_name

declare -i _rc=$success

# 1. We don't need to switch to the old branch that we want to rename
# 2. Rename the branch locally
execute --quiet git branch -m "$old_branch_name" "$new_branch_name"             || with_error _rc "$err_tool_error" "Failed to rename branch '$old_branch_name' to '$new_branch_name'."
# 3. Push the new name to remote
(( _rc != success )) || execute --quiet git push origin "${git_heads_ns}$new_branch_name" \
                                                                                || with_error _rc "$err_tool_error" "Failed to push branch '$new_branch_name' to remote."
# 4. Delete the old branch on remote
(( _rc != success )) || execute --quiet git push origin --delete "${git_heads_ns}$old_branch_name" \
                                                                                || warning "Failed to delete old branch '$old_branch_name' on remote. Clean up manually; otherwise both branches will coexist and that may lead to confusion."

# 5. Reset the upstream tracking
(( _rc != success )) || execute --quiet git branch --set-upstream-to="origin/$new_branch_name" "$new_branch_name" \
                                                                                || with_error _rc "$err_tool_error" "Failed to set upstream tracking for '$new_branch_name'."

# shellcheck disable=SC2015 # Info: Note that A && B || C is not if-then-else. C may run when A is true.
(( _rc != success )) || { is_dry_run &&
                            info "Branch '$old_branch_name' would be renamed to '$new_branch_name'." ||
                            info "Branch '$old_branch_name' successfully renamed to '$new_branch_name'."; }

exit_if_has_errors false
