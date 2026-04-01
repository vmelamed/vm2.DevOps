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
        switches="
Switches:
$common_switches"
        vars=$common_vars
    fi

    cat << EOF
Usage: ${script_name} [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Computes the next release version based on conventional commits or manual input. Analyzes commit messages since the last
stable tag to determine the appropriate semantic version bump:
  - <type>! (e.g. feat!, refactor!) -> major bump
  - feat: -> minor bump
  - fix: or other -> patch bump

Options:
  -mp, --minver-tag-prefix      Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or default 'v'
  -r, --reason                  Reason for release (e.g., "stable release", "hotfix", etc.)
                                Initial value from \$REASON or default "release build"
$switches
Environment Variables:
  MINVERTAGPREFIX               Git tag prefix to be recognized by MinVer
                                (default: 'v')
  REASON                        Reason for the release build and possibly overriding the natural versioning
                                (default: 'release build')
$vars
Outputs (to GITHUB_OUTPUT):
  release-version               The computed version (e.g., '1.2.3')
  release-tag                   The full tag (e.g., 'v1.2.3')
  reason                        The reason for the release build and possibly overriding the natural versioning
                                (default: 'release build')
  needs-empty-commit            'true' if HEAD is tagged with a prerelease and an empty commit is needed
                                to advance HEAD before creating the stable tag; 'false' otherwise
EOF
}
