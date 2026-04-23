# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

function usage_text()
{
    local long_text=$1
    local switches=""
    local vars=""

    if $long_text; then
        switches="Switches:"$'\n'"$common_switches"
        vars="$common_vars"
    fi

    cat <<EOF
Usage:
  $script_name <old-tag> <new-tag> [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
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
$switches
Environment Variables:
$vars

Examples:
  $script_name v3.1.0-preview.5 v3.1.1-preview.2
  $script_name --delete v3.1.0-preview.4
  $script_name --dry-run v1.1.0-preview.6 v1.1.1-preview.3
EOF
}
