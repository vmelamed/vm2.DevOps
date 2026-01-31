#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned

## Outputs the usage text for this script to /dev/stdout
## Usage: usage_text
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
Usage: ${script_name} [<project|solution>] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Builds a solution or project specified with '--build-project' (see below)

Options:
  -bp, --build-project          Path to the project to be built. Can be empty string, in which case the solution in the
                                repository root will be built
                                Initial value from \$BUILD_PROJECT
  -c, --configuration           Build configuration ('Release' or 'Debug')
                                Initial value from \$CONFIGURATION or default 'Release'
  -d, --define                  Defines one or more user-defined, space, comma, or semicolon-separated pre-processor symbols.
                                Initial value from \$PREPROCESSOR_SYMBOLS or default ''
  -mp, --minver-tag-prefix      Specifies the git tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or 'v'
  -mi, --minver-prerelease-id   Default semver pre-release identifiers used by MinVer (e.g., 'preview.0')
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS or 'preview.0'
  --nuget-username              Username for authenticating with the NuGet repository if needed
                                Initial value from \$GITHUB_ACTOR or ''
  --nuget-password              Password or token for authenticating with the NuGet repository if needed
                                Initial value from \$GITHUB_TOKEN or ''
$std_switches
Environment Variables:
  BUILD_PROJECT                 Path to the solution/project to build
  CONFIGURATION                 Build configuration ('Release' or 'Debug')
  PREPROCESSOR_SYMBOLS          Pre-processor symbols for compilation
  MINVERTAGPREFIX               Prefix for MinVer version git tags
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Default semver pre-release identifiers for MinVer
  GITHUB_ACTOR                  Username for authenticating with the NuGet repository if needed
  GITHUB_TOKEN                  Password or token for authenticating with the NuGet repository if needed
  GITHUB_STEP_SUMMARY           Path to the file to which step summary is written
$std_vars
EOF
}

## Displays a usage message with the provided text (above)
## Usage: display_usage_msg "<usage text>" "[<additional info>]"
function usage()
{
    local long_help=false
    if [[ $# -gt 0 && ("$1" == true || "$1" == false) ]]; then
        long_help="$1"
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
