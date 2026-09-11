#!/usr/bin/env bash

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
Usage: $script_name [<bm-project-path>] | [--<long option> <value> | -<short option> <value> |
                                           --<long switch>|-<short switch> ]*

Runs the benchmark tests in the specified project. It assumes that the solution folder is two levels up from the project
directory, i.e., <solution-root>/benchmarks/<benchmark-project-dir>/<benchmark-project>.csproj. All parameters are optional if
the corresponding environment variables are set. If both are specified, the command line arguments take precedence

Arguments:
  <bm-project-path>             Path to the benchmark project file.
                                Overrides the initial value from the environment value \$BENCHMARK_PROJECT.

Options:
$common_dotnet_parameters
$_common_switches
Environment Variables:
  BENCHMARK_PROJECT             Path to the benchmark project file
$common_dotnet_vars
$_common_vars
Outputs (to GITHUB_OUTPUT):
  results-dir                   The directory where benchmark results are stored
EOF
}
