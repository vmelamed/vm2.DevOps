#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed


declare -x common_args_usage

declare -x script_name

#-----------------------------------------------------------------------------------------------
# @description Outputs the usage text for this script to stdout.
#
# @arg $1 bool Whether to include the long-form help text (switches and environment variables
#   list).
#
# @exitcode success=0: Always.
#
# @stdout The usage/help text for this script.
#
# @example
#   usage_text true
#-----------------------------------------------------------------------------------------------
function usage_text()
{
    assert_usage_text_args "$@"

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
