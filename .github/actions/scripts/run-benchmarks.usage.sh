#!/bin/bash

function usage_text()
{
    # shellcheck disable=SC2154 # variable is referenced but not assigned.
    cat << EOF
Usage:

    ${script_name} [<bm-project-path>] |
       [--<long option> <value> | -<short option> <value> |
        --<long switch> | -<short switch> ]*

    This script runs the benchmark tests in the specified project. It assumes
    that the solution folder is two levels up from the project directory, i.e.,
    <solution-root>/benchmarks/<benchmark-project-dir>/<benchmark-project>.csproj.
    All parameters are optional if the corresponding environment variables are
    set. If both are specified, the command line arguments take precedence.

Parameters:
    <bm-project-path>
        The path to the benchmark project file. Optional if the environment
        variable BM_PROJECT is set.

Switches:$common_switches
    --short-run | -s
        A shortcut for '--define SHORT_RUN'. See below.
        The initial value from \$PREPROCESSOR_SYMBOLS or '' will be preserved and
        appended with 'SHORT_RUN' if not already present.

    --force-new-baseline | -f
        When specified, a new baseline will be created even if a previous
        baseline already exists.
        Initial value from \$FORCE_NEW_BASELINE or 'false'

Options:
    --artifacts | -a
        Specifies the directory where to create the benchmark artifacts:
        results, summaries, base lines, etc.
        Initial value: '<solution root>/BmArtifacts'.

    --configuration | -c
        Specifies the build configuration to use ('Debug' or 'Release').
        Initial value from \$CONFIGURATION or 'Release'

    --define | -d
        Defines one or more user-defined pre-processor symbols to be used when
        building the benchmark project, e.g. 'SHORT_RUN'. Which generates a
        shorter and faster, but less accurate benchmark run. You can specify
        this option multiple times to defined multiple symbols.
        Initial value from \$PREPROCESSOR_SYMBOLS or ''

    --max-regression-pct | -r
        Specifies the maximum acceptable regression percentage (0-50) when
        comparing to a previous, base-line benchmark results.
        Initial value from \$MAX_REGRESSION_PCT or 20

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
