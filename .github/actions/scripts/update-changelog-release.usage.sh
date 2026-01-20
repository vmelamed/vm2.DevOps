#!/bin/bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
function usage_text()
{
    cat << EOF
Usage:

    ${script_name} [--<long option> <value>|-<short option> <value> |
                    --<long switch>|-<short switch> ]*

    Updates CHANGELOG.md for a release using git-cliff. Generates changelog
    entries from commits since the last stable release tag.

Parameters:
    None

Switches:$common_switches

Options:
    --release-tag | -t
        Specifies the release tag to use for changelog generation (required).
        Initial value from \$RELEASE_TAG

    --minver-tag-prefix | -p
        Specifies the tag prefix used by MinVer (e.g., 'v').
        Initial value from \$MINVERTAGPREFIX or default 'v'

Environment Variables:
    RELEASE_TAG         The release tag (e.g., 'v1.2.3')

    MINVERTAGPREFIX   Tag prefix (default: 'v')

Requirements:
    - git-cliff must be installed
    - changelog/cliff.release-header.toml must exist

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
