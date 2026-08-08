#!/usr/bin/env bash

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

function usage_text()
{
    local _long_text=$1
    local _switches=""
    local _vars=""

    if $_long_text; then
        _switches=$'\n'"Switches:"$'\n'"$common_switches"
        _vars=$common_vars
    fi

    cat << EOF
Usage: $script_name [<bm-project-path>] | [--<long option> <value> | -<short option> <value> |
                                             --<long switch> | -<short switch> ]*
Runs the benchmark tests in the specified project. It assumes that the solution folder is two levels up from the project
directory, i.e., <solution-root>/benchmarks/<benchmark-project-dir>/<benchmark-project>.csproj All parameters are optional if
the corresponding environment variables are set. If both are specified, the command line arguments take precedence

Arguments:
  <benchmark-project-path>      The path to the benchmark project file.
                                Initial value from \$BENCHMARK_PROJECT environment variable (see below)

Options:
  -c, --configuration           Specifies the build configuration to use ('Debug' or 'Release')
                                Initial value from \$CONFIGURATION or default 'Release'
  -d, --define                  Defines one or more user-defined, space, comma, or semicolon-separated pre-processor symbols.
                                Initial value from \$PREPROCESSOR_SYMBOLS or default ''
  -mp, --minver-tag-prefix      Specifies the git tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX environment variable or 'v'
  -mi, --minver-prerelease-id   Default semver pre-release identifiers for MinVer (e.g., 'preview.0')
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS environment
                                variable or 'preview.0'
  -max, --max-regression-pct    Specifies the maximum acceptable regression percentage (0-50) when comparing to a previous,
                                base-line benchmark results
                                Initial value from \$MAX_REGRESSION_PCT or default 20
  -a, --artifacts               Specifies the directory where to create the benchmark artifacts: results, summaries, base lines,
                                etc. The benchmark artifacts will be saved in a 'benchmarks' subdirectory within this directory
                                and the results will be stored in the 'results' subdirectory within the 'benchmarks'
                                subdirectory.
                                Initial value: '<solution root>/artifacts'
$_switches
Environment Variables:
  BENCHMARK_PROJECT             Path to the benchmark project file
  ARTIFACTS_DIR                 Directory where benchmark artifacts will be created (see --artifacts above)
  CONFIGURATION                 Build configuration ('Debug' or 'Release')
  PREPROCESSOR_SYMBOLS          Pre-processor symbols to define when building the benchmark project
  MAX_REGRESSION_PCT            Maximum acceptable regression percentage when comparing to previous benchmark results
  MINVERTAGPREFIX               Git tag prefix used by MinVer (e.g., 'v')
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Default semver pre-release identifiers for MinVer
$_vars
Outputs (to GITHUB_OUTPUT):
  results-dir                   The directory where benchmark results are stored
EOF
}
