#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed


declare -xr common_args_usage
declare -xr script_name

declare -xr common_dotnet_parameters
declare -xr common_dotnet_vars
declare -xr common_dotnet_output

function usage_text()
{
    (( $# ==1 ))    || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage: $script_name [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Validates and sets up CI variables for GitHub Actions workflows. It validates all inputs and outputs them to GITHUB_OUTPUT for
use by the subsequent workflow jobs

All parameters are optional if the corresponding environment variables are set. If both are specified, the command line arguments
take precedence.

Options:
  -bp, --build-projects <JSON array projects/solution paths>
                                String containing a JSON array of strings - paths to the projects to be built. Can be empty
                                string, or string representing null or empty array, in which case the solution in the repository
                                root will be built
                                Initial value from \$BUILD_PROJECTS
  -tp, --test-projects <JSON array projects paths>
                                String containing a JSON array of strings - paths to the test projects to be run. Cannot be
                                empty string, or string representing null, or empty array. Tests are mandatory
                                Initial value from \$TEST_PROJECTS
  -bmp, --benchmark-projects <JSON array projects paths>
                                String containing a JSON array of strings - paths to the benchmark project files to be run. Can
                                be empty string, or string representing null or empty array, in which case no benchmark tests
                                will be run
                                Initial value from \$BENCHMARK_PROJECTS
  -pp, --package-projects <JSON array projects paths>
                                String containing a JSON array of strings - paths to the projects to pack. Can be empty string,
                                or string representing null or empty array, in which case pack validation will be skipped
                                Initial value from \$PACKAGE_PROJECTS
  -os, --runners-os <JSON array runner OSes>
                                String containing a JSON array of strings - runner OSes (e.g. from a GitHub actions matrix).
                                Can be empty string, or string representing null or empty array, in which case
                                '["ubuntu-latest"]' will be used
                                Initial value from \$RUNNERSOS or default '["ubuntu-latest"]'
  -min, --min-coverage-pct <percentage>
                                Minimum acceptable code coverage percentage (50-100)
                                Initial value from \$MIN_COVERAGE_PCT or default 80
  -max, --max-regression-pct <percentage>
                                Maximum acceptable performance regression percentage (0-50)
                                Initial value from \$MAX_REGRESSION_PCT or default 20
  -g1, --max-gen1-collects <number>
                                Maximum acceptable Gen1 GC collections per 1000 operations (non-negative integer, Bencher
                                static threshold)
                                Initial value from \$MAX_GEN1_COLLECTS or default 2
  -g2, --max-gen2-collects <number>
                                Maximum acceptable Gen2 GC collections per 1000 operations (non-negative integer, Bencher
                                static threshold)
                                Initial value from \$MAX_GEN2_COLLECTS or default 1
  -r, --reset-benchmark-thresholds [true|false]
                                Whether to reset Bencher thresholds if some degradation is expected. Expected 'true' or 'false'
                                Initial value from \$RESET_BENCHMARK_THRESHOLDS or default 'false'
  -st, --skip-build [true|false]
                                Whether to skip building. Expected 'true' or 'false'
                                Initial value from \$SKIP_BUILD or default 'false'
  -st, --skip-tests [true|false]
                                Whether to skip running tests. Expected 'true' or 'false'
                                Initial value from \$SKIP_TESTS or default 'false'
  -sbm, --skip-benchmarks [true|false]
                                Whether to skip running benchmarks. Expected 'true' or 'false'
                                Initial value from \$SKIP_BENCHMARKS or default 'false'
  -sp, --skip-packages [true|false]
                                Whether to skip packing projects. Expected 'true' or 'false'
                                Initial value from \$SKIP_PACKAGES or default 'false'
$common_dotnet_parameters
Environment Variables:
  BUILD_PROJECTS                JSON array of paths to projects to build
  TEST_PROJECTS                 JSON array of paths to test projects to run
  BENCHMARK_PROJECTS            JSON array of paths to benchmark projects to run
  PACKAGE_PROJECTS              JSON array of paths to projects to pack
  RUNNERS_OS                    JSON array of target OS-es
  MIN_COVERAGE_PCT              Minimum acceptable code coverage percentage
  MAX_REGRESSION_PCT            Maximum acceptable performance regression percentage
  MAX_GEN1_COLLECTS             Maximum acceptable Gen1 GC collections per 1000 operations
  MAX_GEN2_COLLECTS             Maximum acceptable Gen2 GC collections per 1000 operations
  RESET_BENCHMARK_THRESHOLDS    Whether to reset Bencher thresholds if some degradation is expected
  SKIP_BUILD                    Whether to skip building
  SKIP_TESTS                    Whether to skip running tests
  SKIP_BENCHMARKS               Whether to skip running benchmarks
  SKIP_PACKAGES                 Whether to skip packing projects
$common_dotnet_vars
Outputs (to GITHUB_OUTPUT):
  build-projects                JSON array of paths to projects to build
  test-projects                 JSON array of paths to test projects to run
  benchmark-projects            JSON array of paths to benchmark projects to run
  package-projects              JSON array of paths to projects to pack
  runners-os                    JSON array of target OS-es
  min-coverage-pct              Minimum acceptable code coverage percentage
  max-regression-pct            Maximum acceptable performance regression percentage
  max-gen1-collects             Maximum acceptable Gen1 GC collections per 1000 operations
  max-gen2-collects             Maximum acceptable Gen2 GC collections per 1000 operations
  reset-benchmark-thresholds    Whether to reset Bencher thresholds if some degradation is expected
  skip-build                    Whether to skip building
  skip-tests                    Whether to skip running tests
  skip-benchmarks               Whether to skip running benchmarks
  skip-packages                 Whether to skip packing projects
$common_dotnet_output
$_common_args
EOF
}
