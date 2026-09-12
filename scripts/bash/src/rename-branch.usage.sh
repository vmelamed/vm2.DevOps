# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_switches
declare -xr common_vars
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
    local _long_text=$1
    local _common_switches=""
    local _common_vars=""

    if $_long_text; then
        _common_switches="\

$common_switches"

        _common_vars="\

$common_vars"
    fi

    cat << EOF
Usage: $script_name [<old_branch_name>] <new_branch_name>
Renames a Git branch both locally and remotely.

Arguments:
  <old_branch_name>             The name of the existing branch to be renamed. If not specified, the current branch is used.
  <new_branch_name>             The new name for the branch. This must be a valid Git branch name and must not already exist.
Switches:
$_common_switches
Environment Variables:
$_common_vars
EOF
}
