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
        switches=$'\n'"Switches:"$'\n'"$common_switches"
        vars=$common_vars
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
  -b, --build                   Build the project before packing (default: use pre-built artifacts).
                                Use when no prior build job cached the artifacts (e.g., template projects).
                                Initial value from \$BUILD or default 'false'
$switches
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
  BUILD                         When 'true', build the project before packing
                                (default: 'false')
$vars
EOF
}
