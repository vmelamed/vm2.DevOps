#!/bin/bash

# shellcheck disable=SC2154

function usage_text()
{
    cat << EOF
Usage:

    ${script_name} [--<long option> <value>|-<short option> <value> |
                    --<long switch>|-<short switch> ]*

    This script validates and sets up CI variables for GitHub Actions workflows.
    It validates all inputs and outputs them to GITHUB_OUTPUT for use by
    subsequent workflow jobs.

Parameters: All parameters are optional if the corresponding environment
    variables are set. If both are specified, the command line arguments
    take precedence.

Switches:$common_switches

Options:
    --build-projects | -b
        String representing a JSON array of strings - paths to the projects to
        be built. Can be empty string, or string representing null or empty
        array, in which case the solution in the repository root will be built.
        Initial value from \$BUILD_PROJECTS

    --test-projects | -t
        String representing a JSON array of strings - paths to the test projects
        to be run. Cannot be empty string, or string representing null, or empty
        array. Tests are mandatory.
        Initial value from \$TEST_PROJECTS

    --benchmark-projects | -p
        String representing a JSON array of strings - paths to the benchmark
        project files to be run. Can be empty string, or string representing
        null or empty array, in which case no benchmark tests will be run.
        Initial value from \$BENCHMARK_PROJECTS

    --os | -o
        String representing a JSON array of strings - target OS-es (e.g. from a
        GitHub actions matrix). Can be empty string, or string representing
        null or empty array, in which case '["ubuntu-latest"]' will be used.
        Initial value from \$OS or '["ubuntu-latest"]'

    --dotnet-version
        Version of .NET SDK to use.
        Initial value from \$DOTNET_VERSION or '10.0.x'

    --configuration | -c
        Build configuration ('Release' or 'Debug').
        Initial value from \$CONFIGURATION or 'Release'

    --preprocessor-symbols | -d
        Pre-processor symbols for compilation.
        Initial value from \$PREPROCESSOR_SYMBOLS or ''

    --min-coverage-pct | -min
        Minimum acceptable code coverage percentage (50-100).
        Initial value from \$MIN_COVERAGE_PCT or 80

    --force-new-baseline | -f
        Whether to force new baseline (true/false).
        Initial value from \$FORCE_NEW_BASELINE or false

    --max-regression-pct | -max
        Maximum acceptable performance regression percentage (0-50).
        Initial value from \$MAX_REGRESSION_PCT or 10

    --verbose | -v
        Whether to enable verbose logging (true/false).
        Initial value from \$VERBOSE or false

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
