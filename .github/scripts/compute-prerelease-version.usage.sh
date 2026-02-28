#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned
function usage_text()
{
    local std_switches=""
    local std_vars=""

    if [[ $1 == true ]]; then
        std_switches="
Switches:
$common_switches"
        std_vars=$common_vars
    fi

    cat << EOF
Usage: ${script_name} [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Computes the next prerelease version based on conventional commits. Analyzes commit messages since the last stable tag to
determine the appropriate semantic version bump, then appends a prerelease suffix:
  - BREAKING CHANGE or feat! -> major bump
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
$std_switches
Environment Variables:
    MINVERTAGPREFIX             Git tag prefix to be recognized by MinVer
                                (default: 'v')
    MINVERDEFAULTPRERELEASEIDENTIFIERS
                                MinVer default pre-release identifiers
                                (default: 'preview.0')
    REASON                      Reason for the prerelease build
                                (default: 'pre-release')
$std_vars
Outputs (to GITHUB_OUTPUT):
  prerelease-version            The computed version (e.g., '1.2.3-preview.1')
  prerelease-tag                The full tag (e.g., 'v1.2.3-preview.1')
  reason                        The reason for the prerelease build
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
