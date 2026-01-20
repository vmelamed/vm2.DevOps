#!/bin/bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.

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
        Initial value from \$OS or default '["ubuntu-latest"]'

    --dotnet-version
        Version of .NET SDK to use.
        Initial value from \$DOTNET_VERSION or default '10.0.x'

    --configuration | -c
        Build configuration ('Release' or 'Debug').
        Initial value from \$CONFIGURATION or default 'Release'

    --preprocessor-symbols | -d
        Pre-processor symbols for compilation.
        Initial value from \$PREPROCESSOR_SYMBOLS or default ''

    --min-coverage-pct | -min
        Minimum acceptable code coverage percentage (50-100).
        Initial value from \$MIN_COVERAGE_PCT or default 80

    --max-regression-pct | -max
        Maximum acceptable performance regression percentage (0-50).
        Initial value from \$MAX_REGRESSION_PCT or default 20

    --minver-tag-prefix | -f
        Specifies the tag prefix used by MinVer (e.g., 'v').
        Initial value from \$MINVERTAGPREFIX environment variable or 'v'.

    --minver-prerelease-id | -i
        Default semver pre-release identifiers for MinVer (e.g., 'preview.1').
        Initial value from \$MinVerDefaultPreReleaseIdentifiers environment
        variable or 'preview.1'.

Environment Variables:
    BUILD_PROJECTS          JSON array of paths to projects to build.
    TEST_PROJECTS           JSON array of paths to test projects to run.
    BENCHMARK_PROJECTS      JSON array of paths to benchmark projects to run.
    OS                      JSON array of target OS-es.
    DOTNET_VERSION          Version of .NET SDK to use.
    CONFIGURATION           Build configuration ('Release' or 'Debug').
    PREPROCESSOR_SYMBOLS    Pre-processor symbols for compilation.
    MIN_COVERAGE_PCT        Minimum acceptable code coverage percentage.
    MAX_REGRESSION_PCT      Maximum acceptable performance regression percentage.
    MINVERTAGPREFIX         Prefix for MinVer version git tags.
    MinVerDefaultPreReleaseIdentifiers
                            Default semver pre-release identifiers for MinVer.
    VERBOSE                 Is verbose output enabled?

Outputs (to GITHUB_OUTPUT):
    build-projects          JSON array of paths to projects to build.
    test-projects           JSON array of paths to test projects to run.
    benchmark-projects      JSON array of paths to benchmark projects to run.
    os                      JSON array of target OS-es.
    dotnet-version          Version of .NET SDK to use.
    configuration           Build configuration ('Release' or 'Debug').
    preprocessor-symbols    Pre-processor symbols for compilation.
    min-coverage-pct        Minimum acceptable code coverage percentage.
    max-regression-pct      Maximum acceptable performance regression percentage.
    verbose                 Is verbose output enabled?
    minver-tag-prefix       Prefix for MinVer version git tags.
    minver-prerelease-id    Default semver pre-release identifiers for MinVer.

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
