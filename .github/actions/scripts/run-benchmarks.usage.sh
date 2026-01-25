#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned
function usage_text()
{
    local std_switches=""
    local std_vars=""

    if [[ $1 == true ]]; then
        std_switches=$common_switches
        std_vars=$common_vars
    fi

    cat << EOF
Usage: ${script_name} [<bm-project-path>] | [--<long option> <value> | -<short option> <value> |
                                             --<long switch> | -<short switch> ]*
Runs the benchmark tests in the specified project. It assumes that the solution folder is two levels up from the project
directory, i.e., <solution-root>/benchmarks/<benchmark-project-dir>/<benchmark-project>.csproj All parameters are optional if
the corresponding environment variables are set. If both are specified, the command line arguments take precedence

Arguments:
  <bm-project-path>             The path to the benchmark project file. Optional if the environment variable \$BM_PROJECT is set

Options:
  -a, --artifacts               Specifies the directory where to create the benchmark artifacts: results, summaries, base lines,
                                etc.
                                Initial value: '<solution root>/BmArtifacts'
  -c, --configuration           Specifies the build configuration to use ('Debug' or 'Release')
                                Initial value from \$CONFIGURATION or default 'Release'
  -d, --define                  Defines one or more user-defined pre-processor symbols to be used when building the benchmark
                                project, e.g. 'SHORT_RUN'. Which generates a shorter and faster, but less accurate benchmark
                                run. You can specify this option multiple times to defined multiple symbols
                                Initial value from \$PREPROCESSOR_SYMBOLS or default ''
  -r, --max-regression-pct      Specifies the maximum acceptable regression percentage (0-50) when comparing to a previous,
                                base-line benchmark results
                                Initial value from \$MAX_REGRESSION_PCT or default 20
  -f, --minver-tag-prefix       Specifies the git tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX environment variable or 'v'
  -i, --minver-prerelease-id    Default semver pre-release identifiers for MinVer (e.g., 'preview.0')
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS environment
                                variable or 'preview.0'

Switches:
  -s, --short-run               A shortcut for '--define SHORT_RUN'. See above.
                                The initial value from \$PREPROCESSOR_SYMBOLS or default '' will be preserved and appended with
                                'SHORT_RUN' if not already present
$std_switches
Environment Variables:
  BM_PROJECT                    Path to the benchmark project file
  ARTIFACT_DIR                  Directory where benchmark artifacts will be created
  CONFIGURATION                 Build configuration ('Debug' or 'Release')
  PREPROCESSOR_SYMBOLS          Pre-processor symbols to define when building the benchmark project
  MAX_REGRESSION_PCT            Maximum acceptable regression percentage when comparing to previous benchmark results
  MINVERTAGPREFIX               Git tag prefix used by MinVer (e.g., 'v')
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Default semver pre-release identifiers for MinVer
$std_vars
Outputs (to GITHUB_OUTPUT):
  results-dir                   The directory where benchmark results are stored
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
