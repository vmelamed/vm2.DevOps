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
Usage:
  ${script_name} [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Validates and sets up CI variables for GitHub Actions workflows. It validates all inputs and outputs them to GITHUB_OUTPUT for
use by subsequent workflow jobs

All options are optional if the corresponding environment variables are set. If both are specified, the command line arguments
take precedence

Options:
  -bp, --build-projects         String containing a JSON array of strings - paths to the projects to be built. Can be empty
                                string, or string representing null or empty array, in which case the solution in the repository
                                root will be built
                                Initial value from \$BUILD_PROJECTS
  -tp, --test-projects          String containing a JSON array of strings - paths to the test projects to be run. Cannot be
                                empty string, or string representing null, or empty array. Tests are mandatory
                                Initial value from \$TEST_PROJECTS
  -bmp, --benchmark-projects    String containing a JSON array of strings - paths to the benchmark project files to be run. Can
                                be empty string, or string representing null or empty array, in which case no benchmark tests
                                will be run
                                Initial value from \$BENCHMARK_PROJECTS
  -pp, --package-projects       String containing a JSON array of strings - paths to the projects to pack. Can be empty string,
                                or string representing null or empty array, in which case pack validation will be skipped
                                Initial value from \$PACKAGE_PROJECTS
  -os, --runners-os             String containing a JSON array of strings - target OS-es (e.g. from a GitHub actions matrix).
                                Can be empty string, or string representing null or empty array, in which case
                                '["ubuntu-latest"]' will be used
                                Initial value from \$RUNNERSOS or default '["ubuntu-latest"]'
  -dn, --dotnet-version         Version of .NET SDK to use
                                Initial value from \$DOTNET_VERSION or default '10.0.x'
  -c, --configuration           Build configuration ('Release' or 'Debug')
                                Initial value from \$CONFIGURATION or default 'Release'
  -d, --define                  Defines one or more user-defined, space, comma, or semicolon-separated pre-processor symbols.
                                Initial value from \$PREPROCESSOR_SYMBOLS or default ''
  -min, --min-coverage-pct      Minimum acceptable code coverage percentage (50-100)
                                Initial value from \$MIN_COVERAGE_PCT or default 80
  -max, --max-regression-pct    Maximum acceptable performance regression percentage (0-50)
                                Initial value from \$MAX_REGRESSION_PCT or default 20
  -mp, --minver-tag-prefix      Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX environment variable or 'v'
  -mi, --minver-prerelease-id   Default semver pre-release identifiers for MinVer (e.g., 'preview.0', 'alpha', 'beta', 'rc1', etc.)
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS environment variable or 'preview.0'

$std_switches
Environment Variables:
    BUILD_PROJECTS              JSON array of paths to projects to build
    TEST_PROJECTS               JSON array of paths to test projects to run
    BENCHMARK_PROJECTS          JSON array of paths to benchmark projects to run
    PACKAGE_PROJECTS            JSON array of paths to projects to pack
    RUNNERS_OS                  JSON array of target OS-es
    DOTNET_VERSION              Version of .NET SDK to use
    CONFIGURATION               Build configuration ('Release' or 'Debug')
    PREPROCESSOR_SYMBOLS        Pre-processor symbols for compilation
    MIN_COVERAGE_PCT            Minimum acceptable code coverage percentage
    MAX_REGRESSION_PCT          Maximum acceptable performance regression percentage
    MINVERTAGPREFIX             Prefix for MinVer version git tags
    MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Default semver pre-release identifiers for MinVer
$std_vars
Outputs (to GITHUB_OUTPUT):
    build-projects              JSON array of paths to projects to build
    test-projects               JSON array of paths to test projects to run
    benchmark-projects          JSON array of paths to benchmark projects to run
    package-projects            JSON array of paths to projects to pack
    runners-os                  JSON array of target OS-es
    dotnet-version              Version of .NET SDK to use
    configuration               Build configuration ('Release' or 'Debug')
    preprocessor-symbols        Pre-processor symbols for compilation
    min-coverage-pct            Minimum acceptable code coverage percentage
    max-regression-pct          Maximum acceptable performance regression percentage
    minver-tag-prefix           Prefix for MinVer version git tags
    minver-prerelease-id        Default semver pre-release identifiers for MinVer

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
