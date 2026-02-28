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
Validates that a .NET project can be successfully packed into a NuGet package (dry-run pack without publishing)

Options:
  -pp, --package-project        Path to the project to pack. The file must exist and cannot be empty.
                                Initial value from the \$PACKAGE_PROJECT environment variable.
  -c, --configuration           Build configuration ('Release' or 'Debug')
                                Initial value from \$CONFIGURATION or default 'Release'
  -d, --define                  Defines one or more user-defined, space, comma, or semicolon-separated pre-processor symbols.
                                Initial value from \$PREPROCESSOR_SYMBOLS or default ''
  -mp, --minver-tag-prefix      Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX environment variable or 'v'
  -mi, --minver-prerelease-id   Default semver pre-release identifiers for MinVer (e.g., 'preview.0')
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS environment variable or 'preview.0'

$std_switches
Environment Variables:
  PACKAGE_PROJECT               Path to the project to pack
  CONFIGURATION                 Build configuration ('Release' or 'Debug')
                                (default: 'Release')
  PREPROCESSOR_SYMBOLS          Pre-processor symbols for compilation
                                (default: '')
  MINVERTAGPREFIX               Git tag prefix to be recognized by MinVer
                                (default: 'v')
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Default semver pre-release identifiers for MinVer
                                (default: 'preview.0')
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
