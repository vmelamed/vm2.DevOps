# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x script_name

declare -x common_args_usage

#-----------------------------------------------------------------------------------------------
# @description Builds and prints the usage/help text for 're-tag.sh'. When '$1' is true, appends the common switches and
# environment variables sections; otherwise prints only the short usage summary.
#
# @arg $1 bool Whether to include the long-form help (common switches and environment variables sections).
#
# @exitcode success=0: Always.
#
# @stdout The usage text for 're-tag.sh'.
#-----------------------------------------------------------------------------------------------
function usage_text()
{
    assert_usage_text_args "$@"

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat <<EOF
Usage:
  $script_name <old-tag> <new-tag> [--<long option> <value> | -<short option> <value> | --<long switch> | -<short switch> ]*
  $script_name --delete <tag> [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Replaces an existing (old) git tag with a new one: deletes the old tag locally and on origin, then tags the same commit with the
new name and pushes it to origin. With '--delete', only deletes the tag, locally and on origin.

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
