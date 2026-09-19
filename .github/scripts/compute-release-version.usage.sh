#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed


declare -xr common_args_usage
declare -xr script_name

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
  $script_name [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Computes the next release version of the current Git repository based on the conventional commits or manual input. Analyzes the
commit messages since the last stable tag to determine the appropriate semantic version bump:
  - <type>! (e.g. feat!, refactor!) -> major bump
  - feat: -> minor bump
  - fix: or other -> patch bump

Options:
  -mp, --minver-tag-prefix <prefix>
                                Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or default 'v'
  -r, --reason <reason text>    Reason for release (e.g., "stable release", "hotfix", etc.)
                                Initial value from \$REASON or default "release build"

Environment Variables:
  MINVERTAGPREFIX               Git tag prefix to be recognized by MinVer
                                (default: 'v')
  REASON                        Reason for the release build and possibly overriding the natural versioning
                                (default: 'release build')

Outputs (to GITHUB_OUTPUT):
  release-version               The computed version (e.g., '1.2.3')
  release-tag                   The full tag (e.g., 'v1.2.3')
  reason                        The reason for the release build and possibly overriding the natural versioning
                                (default: 'release build')
  needs-empty-commit            'true' if HEAD is tagged with a prerelease and an empty commit is needed
                                to advance HEAD before creating the stable tag; 'false' otherwise
$_common_args
EOF
}
