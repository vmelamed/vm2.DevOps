# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

declare -xr common_dotnet_parameters
declare -xr common_dotnet_vars

function usage_text()
{
    (( $# ==1 ))    || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage:
  $script_name [<package project>] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

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

Environment Variables:
  PACKAGE_PROJECT               Path to the project to pack
  BUILD                         When 'true', build the project before packing
                                (default: 'false')
$common_dotnet_vars
$_common_args
EOF
}
