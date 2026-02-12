#!/usr/bin/env bash

# shellcheck disable=SC2154 # var is referenced but not assigned
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
Usage: ${script_name} [<test-project-path>] | [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Runs the tests in the specified test project and collects code coverage information. It assumes that the solution folder is two
levels up from the project directory, i.e., <solution-root>/test/<test-project-dir>/<test-project>.csproj. All parameters are
optional if the corresponding environment variables are set. If both are specified, the command line arguments take precedence

Arguments:
  <test-project-path>           The path to the test project file. Optional if the environment variable TEST_PROJECT is set

Options:
  -c, --configuration           Specifies the build configuration to use ('Debug' or 'Release')
                                Initial value from \$CONFIGURATION or default 'Release'
  -d, --define                  Defines one or more user-defined pre-processor symbols to be used when building the test
                                project, e.g. 'STAGING'. You can specify this option multiple times to define multiple symbols
                                Initial value from \$PREPROCESSOR_SYMBOLS or default ''
  -min, --min-coverage-pct      Specifies the minimum acceptable code coverage percentage (50-100)
                                Initial value from \$MIN_COVERAGE_PCT or default 80
  -mp, --minver-tag-prefix      Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX environment variable or 'v'
  -mi, --minver-prerelease-id   Default semver pre-release identifiers for MinVer (e.g., 'preview.1')
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS environment variable or 'preview.0'
  -a, --artifacts               Specifies the root directory (preferably relative to the repository root) where to create the
                                script's artifacts: summaries, report files, etc. The artifacts will be in a subdirectory of the
                                artifacts root directory named after the test project, e.g. <artifacts-root>/<test-project-name>/*
                                Initial value from \$TEST_ARTIFACTS_DIR environment variable or '<solution-root>/TestArtifacts'
$std_switches
Environment Variables:
  TEST_PROJECT                  Path to the test project file
  TEST_ARTIFACTS_DIR            Directory relative to the repository root where to create the script's artifacts
  CONFIGURATION                 Build configuration ('Release' or 'Debug')
  PREPROCESSOR_SYMBOLS          Pre-processor symbols to define when building the test project
  MIN_COVERAGE_PCT              Minimum acceptable code coverage percentage
$std_vars
Outputs (to GITHUB_OUTPUT):
  results-dir                   The directory where test results are stored
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
