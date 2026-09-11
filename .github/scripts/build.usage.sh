# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

declare -xr common_dotnet_parameters
declare -xr common_dotnet_vars

#---------------------------------------------------------------------------------------------
# @description Outputs the usage text for this script to stdout.
#
# @arg $1 bool Whether to include the long-form help text (switches and environment variables
#   list).
#
# @stdout The usage/help text for this script.
#
# @example
#   usage_text true
#---------------------------------------------------------------------------------------------
function usage_text()
{
    local _long_text=$1
    local _switches=""
    local _vars=""

    if $_long_text; then
        _vars=$common_vars
        _switches="
Switches:
$common_switches"
    fi

    cat << EOF
Usage: $script_name [<project|solution>] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Builds a solution or project specified with the positional argument <project|solution> (see below for details). All parameters
are optional if the corresponding environment variables are set. If both are specified, the command line arguments take
precedence.

Arguments:
  <project|solution>            Path to the project to be built. Can be empty string, in which case the solution in the
                                repository root will be built.
                                Overrides the initial value from the environment value \$BUILD_PROJECT.

Options:
$common_dotnet_parameters
$_switches
Environment Variables:
  BUILD_PROJECT                 Path to the solution/project to build
$common_dotnet_vars
$_vars
EOF
}
