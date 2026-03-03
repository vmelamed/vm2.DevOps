# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# shellcheck disable=SC2154 # common_switches is referenced but not assigned
function usage_text()
{
    local std_switches=""

    if [[ $1 == true ]]; then
        std_switches="
Switches:
$common_switches"
    fi

    cat << EOF
Usage: ${script_name} [<old_branch_name>] <new_branch_name>
Renames a Git branch both locally and remotely.

Arguments:
  <old_branch_name>             The name of the existing branch to be renamed. If not specified, the current branch is used.
  <new_branch_name>             The new name for the branch. This must be a valid Git branch name and must not already exist.

$std_switches
EOF
}

function usage()
{
    local long_help=true
    if [[ $# -gt 0 && ($1 == true || $1 == false) ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
