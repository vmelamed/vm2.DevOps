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

Computes the next prerelease version of the current Git repository based on conventional commits. Analyzes the commit messages
since the last stable tag to determine the appropriate semantic version bump, then appends a prerelease suffix:
  - <type>! (e.g. feat!, refactor!) -> major bump
  - feat: -> minor bump
  - fix: or other -> patch bump

The prerelease counter increments when the base version matches the latest prerelease tag, or resets to 1 when the base version
changes.

Options:
  -mp, --minver-tag-prefix <prefix>
                                Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or default 'v'
  -mi, --minver-prerelease-id  <id>
                                MinVer pre-release identifiers (e.g., 'preview.0', 'alpha', 'rc.0')
                                The height seed (trailing '.N') is stripped to derive the prefix.
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS or default 'preview.0'
  -r, --reason <reason text>    Reason for prerelease (e.g., "pre-release", "manual prerelease", etc.)
                                Initial value from \$REASON or default "pre-release"

Environment Variables:
  MINVERTAGPREFIX               Git tag prefix to be recognized by MinVer
                                (default: 'v')
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                MinVer default pre-release identifiers
                                (default: 'preview.0')
  REASON                        Reason for the prerelease build
                                (default: 'pre-release')

Outputs (to GITHUB_OUTPUT):
  prerelease-version            The computed version (e.g., '1.2.3-preview.1')
  prerelease-tag                The full tag (e.g., 'v1.2.3-preview.1')
  reason                        The reason for the prerelease build
$_common_args
EOF
}
