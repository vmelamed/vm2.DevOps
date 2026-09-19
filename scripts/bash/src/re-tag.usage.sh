# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

#---------------------------------------------------------------------------------------------
# @description Builds and prints the usage/help text for 're-tag.sh'. When '$1' is true, appends the common switches and
# environment variables sections; otherwise prints only the short usage summary.
#
# @arg $1 bool Whether to include the long-form help (common switches and environment variables sections).
#
# @exitcode success/positive=0
#
# @stdout The usage text for 're-tag.sh'.
#---------------------------------------------------------------------------------------------
function usage_text()
{
    (( $# ==1 ))    || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat <<EOF
Usage:
  $script_name <old-tag> <new-tag> [--<long option> <value> | -<short option> <value> | --<long switch> | -<short switch> ]*
  $script_name --delete <tag> [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Replaces an existing git tag with a new tag or if '--delete' is specified - deletes it. The old tag is deleted locally and on
origin, and if '--delete' is not specified, the same commit is tagged with the new name and pushed to origin.

Note: the current working directory must be a git repository where you want to modify/delete tags, but it doesn't need to be the
root of the working tree.

Arguments:
  <old-tag>   The existing tag to rename or delete if '--delete' is specified.
  <new-tag>   The new tag name to create at the same commit. Ignored when '--delete' is specified and required when not using
              '--delete'
Options:
  --delete    Delete the tag following the option.
$_common_args
Examples:
  $script_name v3.1.0-preview.5 v3.1.1-preview.2
  $script_name --delete v3.1.0-preview.4
  $script_name --dry-run v1.1.0-preview.6 v1.1.1-preview.3
EOF
}
