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
        _common_vars="$common_vars"
        _common_switches="\

Switches:
$common_switches"
    fi

    cat << EOF
Usage: $script_name [<test-project-path>] | [--<long option> <value> | -<short option> <value> |
                                             --<long switch> | -<short switch> ]*
Runs the tests in the specified test project and collects code coverage information. It assumes that the solution folder is two
levels up from the project directory, i.e., <solution-root>/tests/<test-project-dir>/<test-project>.csproj. All parameters are
optional if the corresponding environment variables are set. If both are specified, the command line arguments take precedence.

Arguments:
  <test-project-path>           The path to the test project file.
                                Overrides the initial value from the environment value \$TEST_PROJECT environment variable

Options:
$common_dotnet_parameters
$_common_switches
Environment Variables:
  TEST_PROJECT                  Path to the test project file
  MIN_COVERAGE_PCT              Minimum acceptable code coverage percentage
$common_dotnet_vars
$_common_vars
Outputs (to \$GITHUB_OUTPUT or stdout):
  results-dir                   The directory where the test results are stored
EOF
}
