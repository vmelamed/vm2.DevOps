#!/usr/bin/env bash

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
        vars=$common_vars
    fi

    cat << EOF
Usage: ${script_name} [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Computes the next prerelease version based on conventional commits. Analyzes commit messages since the last stable tag to
determine the appropriate semantic version bump, then appends a prerelease suffix:
  - <type>! (e.g. feat!, refactor!) -> major bump
  - feat: -> minor bump
  - fix: or other -> patch bump

The prerelease counter increments when the base version matches the latest prerelease tag, or resets to 1 when the base version
changes.

Options:
  -mp, --minver-tag-prefix      Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or default 'v'
  -mi, --minver-prerelease-id   MinVer pre-release identifiers (e.g., 'preview.0', 'alpha', 'rc.0')
                                The height seed (trailing '.N') is stripped to derive the prefix.
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS or default 'preview.0'
  -r, --reason                  Reason for prerelease (e.g., "pre-release", "manual prerelease", etc.)
                                Initial value from \$REASON or default "pre-release"

$switches
Environment Variables:
  MINVERTAGPREFIX               Git tag prefix to be recognized by MinVer
                                (default: 'v')
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                MinVer default pre-release identifiers
                                (default: 'preview.0')
  REASON                        Reason for the prerelease build
                                (default: 'pre-release')
$vars
Outputs (to GITHUB_OUTPUT):
  prerelease-version            The computed version (e.g., '1.2.3-preview.1')
  prerelease-tag                The full tag (e.g., 'v1.2.3-preview.1')
  reason                        The reason for the prerelease build
EOF
}
