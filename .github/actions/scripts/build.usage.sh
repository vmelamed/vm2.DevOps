#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.

## Outputs the usage text for this script to /dev/stdout.
## Usage: usage_text
function usage_text()
{
    cat << EOF
Usage:

    ${script_name} [--<long option> <value>|-<short option> <value> |
                    --<long switch>|-<short switch> ]*

    This script builds the specified solution or project using the provided
    configuration.

Parameters: All parameters are optional if the corresponding environment
    variables are set. If both are specified, the command line arguments
    take precedence.

Switches:$common_switches

Options:
    --build-project | -b
        Paths to the projects to be built. Can be empty string, in which case
        the solution in the repository root will be built.
        Initial value from \$BUILD_PROJECT

    --configuration | -c
        Build configuration ('Release' or 'Debug').
        Initial value from \$CONFIGURATION or default 'Release'

    --preprocessor-symbols | -d
        Pre-processor symbols for compilation.
        Initial value from \$PREPROCESSOR_SYMBOLS or default ''

    --minver-tag-prefix | -f
        Specifies the git tag prefix used by MinVer (e.g., 'v').
        Initial value from \$MINVERTAGPREFIX environment variable or 'v'.

    --minver-prerelease-id | -i
        Default semver pre-release identifiers used by MinVer (e.g.,
        'preview.0').
        Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS environment
        variable or 'preview.0'.

    --nuget-username
        Username for authenticating with the NuGet repository if needed.
        Initial value from \$GITHUB_ACTOR or ''

    --nuget-password
        Password or token for authenticating with the NuGet repository if needed.
        Initial value from \$GITHUB_TOKEN or ''

Environment Variables:
    BUILD_PROJECT           Path to the solution/project to build.

    CONFIGURATION           Build configuration ('Release' or 'Debug').

    PREPROCESSOR_SYMBOLS    Pre-processor symbols for compilation.

    MINVERTAGPREFIX         Prefix for MinVer version git tags.

    MINVERDEFAULTPRERELEASEIDENTIFIERS
                            Default semver pre-release identifiers for MinVer.

    GITHUB_ACTOR            Username for authenticating with the NuGet repository if needed.

    GITHUB_TOKEN            Password or token for authenticating with the NuGet repository if needed.

    GITHUB_STEP_SUMMARY     Path to the file to which step summary is written.

Outputs (to GITHUB_OUTPUT):
    none

EOF
}

## Displays a usage message with the provided text (above)
## Usage: display_usage_msg "<usage text>" "[<additional info>]"
function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
