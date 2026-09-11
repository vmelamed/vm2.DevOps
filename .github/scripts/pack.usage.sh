# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

declare -xr common_dotnet_parameters
declare -xr common_dotnet_vars

function usage_text()
{
    local _long_text=$1
    local _common_switches=""
    local _common_vars=""

    if $_long_text; then
        _common_vars=$common_vars
        _common_switches="\

Switches:
$common_switches"
    fi

    cat << EOF
Usage: $script_name [<package project>] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Validates that a .NET project can be successfully packed into a NuGet package (dry-run pack without publishing). All parameters
are optional if the corresponding environment variables are set. If both are specified, the command line arguments take
precedence.

Arguments:
  <package project>             Path to the project to pack. The file must exist and cannot be empty.
                                Initial value from the \$PACKAGE_PROJECT environment variable.

Options:
  -r, --reason <reason text>    Reason for release (e.g., "prerelease", "stable release", "hotfix", etc.). The reason is also
                                added as a release note in the package metadata.
                                Initial value from \$REASON or default "release build".
  -b, --build [true|false]      Whether to build the project before packing.
                                Initial value from \$BUILD or default 'false'.
$common_dotnet_parameters
$_common_switches
Environment Variables:
  PACKAGE_PROJECT               Path to the project to pack
  BUILD                         When 'true', build the project before packing
                                (default: 'false')
$common_dotnet_vars
$_common_vars
EOF
}
