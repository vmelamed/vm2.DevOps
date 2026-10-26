# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

declare -xr default_interval
declare -xr default_timeout

#---------------------------------------------------------------------------------------------
# @description Builds and prints the usage/help text for 'show-pr-comments.sh'. When '$1' is true, appends the common switches
# and environment variables sections; otherwise prints only the short usage summary.
#
# @arg $1 bool Whether to include the long-form help (common switches and environment variables sections).
#
# @exitcode success=0: Always.
#
# @stdout The usage text for 'show-pr-comments.sh'.
#---------------------------------------------------------------------------------------------
function usage_text()
{
    (( $# == 1 ))   || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1-<missing>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text && _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage:
  $script_name [<pr-number>] [ --<long option> <value> | -<short option> <value> | --<long switch> | -<short switch> ]*

Prints the reviews and the inline review comments of a GitHub pull request -- Copilot's and everyone else's -- straight
from the GitHub API, without waiting for an editor's comment panel to sync. Read-only: it changes nothing.

Arguments:
  <pr-number>                   The number of the pull request. If omitted, the pull request of the current branch is
                                used (then '--repo' must be omitted too).

Options:
  -r, --repo <owner/repo>       The repository of the pull request. If omitted, the repository of the current directory.
  -w, --watch                   Wait until the latest commit of the pull request has at least one review (e.g. Copilot's),
                                then print. Polls every '--interval' seconds, for at most '--timeout' seconds.
  -i, --interval <seconds>      The polling interval for '--watch' (default: $default_interval).
  -t, --timeout <seconds>       The longest wait for '--watch' (default: $default_timeout); then the script fails.

Examples:
  $script_name                  # the PR of the current branch
  $script_name 54
  $script_name 41 --repo vmelamed/vm2.Templates
  $script_name --watch          # right after pushing: wait for Copilot's review of the new commit, then print it
$_common_args
EOF
}
