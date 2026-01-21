#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
function usage_text()
{
    cat << EOF
Usage:

    ${script_name} [--<long option> <value>|-<short option> <value> |
                    --<long switch>|-<short switch> ]*

    Creates and pushes a release tag to the git repository.

Parameters:
    None

Switches:$common_switches
Options:
    --release-tag | -t
        Specifies the release tag to create (required, e.g., 'v1.2.3').
        Initial value from \$RELEASE_TAG

    --minver-tag-prefix | -p
        Specifies the MinVer tag prefix (e.g., 'v').
        Initial value from \$MINVERTAGPREFIX or default 'v'

    --reason | -r
        Specifies the reason for the release (included in tag annotation).
        Initial value from \$REASON or default 'stable release'

Environment Variables:
    RELEASE_TAG         The release tag (e.g., 'v1.2.3')
    REASON              Release reason
    GITHUB_STEP_SUMMARY Path to write GitHub Actions summary

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
