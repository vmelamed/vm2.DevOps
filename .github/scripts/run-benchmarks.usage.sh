#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed


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
  $script_name [<bm-project>] | [--<long option> <value> | -<short option> <value> | --<long switch>|-<short switch> ]*

Runs the benchmark tests in the specified project. It assumes that the solution folder is two levels up from the project
directory, i.e., <solution-root>/benchmarks/<benchmark-project-dir>/<benchmark-project>.csproj. All parameters are optional if
the corresponding environment variables are set. If both are specified, the command line arguments take precedence

Arguments:
  <bm-project>                  Path to the benchmark project file.
                                Overrides the initial value from the environment value \$BENCHMARK_PROJECT.

Options:
$common_dotnet_parameters

Environment Variables:
  BENCHMARK_PROJECT             Path to the benchmark project file

$common_dotnet_vars
Outputs (to GITHUB_OUTPUT):
  results-dir                   The directory where benchmark results are stored
$_common_args
EOF
}
