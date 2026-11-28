# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x script_name

declare -x common_args_usage

#-----------------------------------------------------------------------------------------------
# @description Builds and prints the usage/help text for 'rename-branch.sh'. When '$1' is true, appends the common switches
# and environment variables sections; otherwise prints only the short usage summary.
#
# @arg $1 bool Whether to include the long-form help (common switches and environment variables sections).
#
# @exitcode success=0: Always.
#
# @stdout The usage text for 'rename-branch.sh'.
#-----------------------------------------------------------------------------------------------
function usage_text()
{
    assert_usage_text_args "$@"

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage:
  $script_name [<old_branch_name>] <new_branch_name> [ --<long switch> | -<short switch> ]*

Renames a Git branch both locally and remotely.

Arguments:
  <old_branch_name>             The name of the existing branch to be renamed. If not specified, the current branch is used.
  <new_branch_name>             The new name for the branch. This must be a valid Git branch name and must not already exist.
$_common_args
EOF
}
