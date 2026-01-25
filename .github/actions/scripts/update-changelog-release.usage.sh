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
Updates CHANGELOG.md for a release using git-cliff. Generates changelog entries from commits since the last stable release tag
Requirements:
  - git-cliff must be installed
  - changelog/cliff.release-header.toml must exist

Options:
  -t, --release-tag             Specifies the release tag to use for changelog generation (required)
                                Initial value from \$RELEASE_TAG
  -p, --minver-tag-prefix       Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or default 'v'
$std_switches
Environment Variables:
  RELEASE_TAG                   The release tag (e.g., 'v1.2.3')
  MINVERTAGPREFIX               Tag prefix (default: 'v')
$std_vars
EOF
}

function usage()
{
    local long_help=true
    if [[ $# -gt 0 && ($1 == true || $1 == false) ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
