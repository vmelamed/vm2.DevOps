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
    --target-os | -o
        JSON array of OS runners for the build matrix.
        Initial value from \$MATRIX_OS or '["ubuntu-latest"]'

    --dotnet-version
        Version of .NET SDK to use.
        Initial value from \$DOTNET_VERSION or '9.0.x'

    --configuration | -c
        Build configuration ('Release' or 'Debug').
        Initial value from \$CONFIGURATION or 'Release'

    --define-symbols | -d
        Pre-processor symbols for compilation.
        Initial value from \$DEFINED_SYMBOLS or ''

    --test-project | -t
        Path to the test project file.
        Initial value from \$TEST_PROJECT or './test/UlidType.Tests/UlidType.Tests.csproj'

    --min-coverage-pct | -m
        Minimum acceptable code coverage percentage (50-100).
        Initial value from \$MIN_COVERAGE_PCT or 80

    --run-benchmarks | -b
        Whether to run benchmarks (true/false).
        Initial value from \$RUN_BENCHMARKS or true

    --benchmark-project | -p
        Path to the benchmark project file.
        Initial value from \$BENCHMARK_PROJECT or './benchmarks/UlidType.Benchmarks/UlidType.Benchmarks.csproj'

    --force-new-baseline | -f
        Whether to force new baseline (true/false).
        Initial value from \$FORCE_NEW_BASELINE or false

    --max-regression-pct | -r
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
