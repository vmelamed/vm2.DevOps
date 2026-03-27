#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned
function usage_text()
{
    local switches=""
    local vars=""

    if [[ $1 == true ]]; then
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

## Displays a usage message with the provided text (above)
## Usage: display_usage_msg "<usage text>" "[<additional info>]"
function usage()
{
    local long_help=true
    if [[ $# -gt 0 && ($1 == true || $1 == false) ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
