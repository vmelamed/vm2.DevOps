#!/usr/bin/env bash

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

function usage_text()
{
    local long_text=$1
    local switches=""
    local vars=""

    if $long_text; then
        switches=$'\n'"Switches:"$'\n'"$common_switches"
        vars=$common_vars
    fi

    cat << EOF
Usage: $script_name [<bm-project-path>] | [--<long option> <value> | -<short option> <value> |
                                            --<long switch> | -<short switch> ]*
Re-records a benchmark's results to Bencher.dev N times to rebuild its performance history (e.g. after a runner-image
change or a benchmark restructure invalidates the old baseline). Each repetition is an independent process run, so the
recorded spread reflects the real run-to-run variance. Results are recorded only: NO thresholds are applied and the run
never fails on an alert. All parameters are optional if the corresponding environment variables are set; command line
arguments take precedence.

Arguments:
  <benchmark-project-path>      The path to the benchmark project file.
                                Initial value from \$BENCHMARK_PROJECT environment variable (see below)

Options:
  -n, --repeat                  How many independent runs to record (positive integer)
                                Initial value from \$REPEAT or default 10
  -c, --configuration           Specifies the build configuration to use ('Debug' or 'Release')
                                Initial value from \$CONFIGURATION or default 'Release'
  -d, --define                  Defines one or more user-defined, space, comma, or semicolon-separated pre-processor
                                symbols. Leave empty for full (non-SHORT_RUN) runs that match release-time numbers.
                                Initial value from \$PREPROCESSOR_SYMBOLS or default ''
  -mp, --minver-tag-prefix      Specifies the git tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX environment variable or 'v'
  -mi, --minver-prerelease-id   Default semver pre-release identifiers for MinVer (e.g., 'preview.0')
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS environment variable or 'preview.0'
  -a, --artifacts               Specifies the directory where to create the benchmark artifacts.
                                Initial value: '<solution root>/BenchmarkArtifacts'
  -bp, --bencher-project        The Bencher.dev project slug to record results to (required)
                                Initial value from \$BENCHER_PROJECT
  -tb, --bencher-testbed        The Bencher.dev testbed name (e.g., the runner OS) (required)
                                Initial value from \$BENCHER_TESTBED
  -br, --bencher-branch         The Bencher.dev branch to record results to
                                Initial value from \$BENCHER_BRANCH or default 'main'
  -ad, --bencher-adapter        The Bencher.dev adapter used to parse the results
                                Initial value from \$BENCHER_ADAPTER or default 'c_sharp_dot_net'
$switches
Environment Variables:
  BENCHER_API_TOKEN             Bencher.dev API token used to upload results (required)
  BENCHMARK_PROJECT             Path to the benchmark project file
  REPEAT                        Number of independent runs to record
  ARTIFACTS_DIR                 Directory where benchmark artifacts will be created
  CONFIGURATION                 Build configuration ('Debug' or 'Release')
  PREPROCESSOR_SYMBOLS          Pre-processor symbols to define when building the benchmark project
  MINVERTAGPREFIX               Git tag prefix used by MinVer (e.g., 'v')
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Default semver pre-release identifiers for MinVer
  BENCHER_PROJECT               Bencher.dev project slug
  BENCHER_TESTBED               Bencher.dev testbed name
  BENCHER_BRANCH                Bencher.dev branch (default 'main')
  BENCHER_ADAPTER               Bencher.dev adapter (default 'c_sharp_dot_net')
$vars
EOF
}
