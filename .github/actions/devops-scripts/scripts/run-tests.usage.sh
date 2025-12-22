#!/bin/bash

function usage_text()
{
    # shellcheck disable=SC2154 # solution_dir is referenced but not assigned.
    cat << EOF
Usage:

    ${script_name} [<test-project-path>] |
        [--<long option> <value>|-<short option> <value> |
         --<long switch>|-<short switch> ]*

    This script runs the tests in the specified test project and collects code
    coverage information. It assumes that the solution folder is two levels up
    from the project directory, i.e.,
    <solution-root>/test/<test-project-dir>/<test-project>.csproj.
    All parameters are optional if the corresponding environment variables are
    set. If both are specified, the command line arguments take precedence.


Parameters:
    <test-project-path>
        The path to the benchmark project file. Optional if the environment
        variable TEST_PROJECT is set.

Switches:$common_switches
    --cached_dependencies
        When specified, the benchmark project dependencies are retrieved from a
        CI cache and will not be restored before building the project.
        Initial value from \$CACHED_DEPENDENCIES or 'false'

    --cached_artifacts
        When specified, the benchmark built artifacts are retrieved from a CI
        cache and will not be restored before building the project.
        Initial value from \$NO_BUILD or 'false'

Options:
    --artifacts | -a
        Specifies the directory where to create the script's artifacts: summary,
        report files, etc.
        Initial value: '<solution root>/TestArtifacts'.

    --configuration | -c
        Specifies the build configuration to use ('Debug' or 'Release').
        Initial value from \$CONFIGURATION or 'Release'

    --define | -d
        Defines one or more user-defined pre-processor symbols to be used when
        building the benchmark project, e.g. 'STAGING'. You can specify this
        option multiple times to define multiple symbols.
        Initial value from \$PREPROCESSOR_SYMBOLS or ''

    --min-coverage-pct | -t
        Specifies the minimum acceptable code coverage percentage (50-100).
        Initial value from \$MIN_COVERAGE_PCT or 80

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
