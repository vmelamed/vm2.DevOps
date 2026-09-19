# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

#---------------------------------------------------------------------------------------------
# @description Builds and prints the usage/help text for 'rename-branch.sh'. When '$1' is true, appends the common switches
# and environment variables sections; otherwise prints only the short usage summary.
#
# @arg $1 bool Whether to include the long-form help (common switches and environment variables sections).
#
# @exitcode success/positive=0
#
# @stdout The usage text for 'rename-branch.sh'.
#---------------------------------------------------------------------------------------------
function usage_text()
{
    (( $# ==1 ))    || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

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
