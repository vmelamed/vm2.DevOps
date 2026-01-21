#!/usr/bin/env bash

# default values for common flags
declare -r default_quiet=false
declare -r default_dry_run=false
declare -r default_verbose=false
declare -r default_debugger=false
declare -r default__ignore=/dev/null
declare -r default_ci=false

declare -x debugger=${DEBUGGER:-$default_debugger}
declare -x verbose=${VERBOSE:-$default_verbose}
declare -x dry_run=${DRY_RUN:-$default_dry_run}
declare -x quiet=${QUIET:-$default_quiet}
declare -x _ignore=$default__ignore  # the file to redirect unwanted output to
declare -rx ci=${CI:-$default_ci}

## Sets the script to debugger mode
function set_debugger()
{
    if [[ $ci == true ]]; then
        # do not allow in CI mode - we cannot debug in CI
        debugger=false
    else
        debugger=true
        quiet=true
    fi
    return 0
}

## Enables trace mode for debugging
function set_trace_enabled()
{
    verbose=true
    _ignore=/dev/stdout
    set -x
    return 0
}

## Sets the script to dry-run mode (does not execute commands, only simulates)
function set_dry_run()
{
    dry_run=true
    return 0
}

## Sets the script to quiet mode (suppresses user prompts)
function set_quiet()
{
    quiet=true
    return 0
}

## Sets the script to verbose mode (enables detailed output)
function set_verbose()
{
    verbose=true
    return 0
}

## Sets the script to CI mode
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function set_ci()
{
    quiet=true
    dry_run=false
    verbose=false
    debugger=false
    _ignore=/dev/null
    set_table_format markdown
    set +x
    return 0
}

if [[ $ci == true ]]; then
    set_ci
fi

declare -xr default_table_format="graphical"

## table_format determines the format in which dump tables are displayed by the
## `dump_vars` function(with graphical ASCII characters or with markdown)
declare table_format=${TABLE_FORMAT:-$default_table_format}
declare -axr table_formats=("graphical" "markdown")

## Sets the table format for variable dumps
## Usage: set_table_format <format>
## where <format> is one of: "graphical", "markdown"
function set_table_format()
{
    for f in "${table_formats[@]}"; do
        if [[ "$f" == "${1,,}" ]]; then
            table_format="$f"
            return 0
        fi
    done
    error "Invalid table format: $1"

    return 0
}

function get_table_format()
{
    printf "%s" "$table_format"
    return 0
}

if [[ $debugger == true ]]; then
    set_debugger
fi
if [[ $dry_run == true ]]; then
    set_dry_run
fi
if [[ $quiet == true ]]; then
    set_quiet
fi
if [[ $verbose == true ]]; then
    set_verbose
fi

## Processes common command-line arguments like --debugger, --quiet, --verbose, --trace, --dry-run.
## Usage: get_common_arg <argument>
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
function get_common_arg()
{
    if [[ "${#}" -eq 0 ]]; then
        return 2
    fi
    # the calling scripts should not use short options:
    # --help|-h|-\?--debugger|-q|--quiet-v|--verbose-x|--trace-y|--dry-run
    case "${1,,}" in
        -h|--help|-\?   ) usage; exit 0 ;;
        --debugger      ) set_debugger ;;
        -q|--quiet      ) set_quiet ;;
        -v|--verbose    ) set_verbose ;;
        -x|--trace      ) set_trace_enabled ;;
        -y|--dry-run    ) set_dry_run ;;
        -gr|--graphical ) set_table_format "graphical" ;;
        -md|--markdown  ) set_table_format "markdown" ;;
        * ) return 1 ;;  # not a common argument
    esac
    return 0 # it was a common argument and was processed
}

## Displays a usage message and optionally an additional error message.
## Avoid calling this function directly; instead, override the usage() function in the calling script to provide custom usage
## information.
## Usage: display_usage_msg <usage_text> [<additional_message>]
function display_usage_msg()
{
    if [[ "${#}" -eq 0 || -z "$1" ]]; then
        error "There must be at least one parameter - the usage text" >&2
        exit 2
    fi

    # save the tracing state and disable tracing
    local set_tracing_on=0
    if [[ $- =~ .*x.* ]]; then
        set_tracing_on=1
    fi
    set +x

    echo "$1
"
    if [[ "${#}" -gt 1 && -n "$2" ]]; then
        echo "$2
"
    fi
    sync

    # restore the tracing state
    if ((set_tracing_on == 1)); then
        set -x
    fi
    return 0
}

## Displays the usage message for common flags.
## Override this function in the calling script to provide custom usage information.
## Usage: usage()
function usage()
{
    display_usage_msg "$common_switches" "OVERRIDE THE FUNCTION usage() IN THE CALLING SCRIPT TO PROVIDE CUSTOM USAGE INFORMATION."
}

declare -x common_switches="
    --help | -h | -?
        Displays this usage text and exits.

    --debugger
        Set when the script is running under a debugger, e.g. 'gdb'. If
        specified, the script will not set traps for DEBUG and EXIT, and will
        set the '--quiet' switch.
        Initial value from \$DEBUGGER or 'false'

    --dry-run | -y
        Runs the script without executing any commands but shows what would have
        been executed.
        Initial value from \$DRY_RUN or 'false'

    --quiet | -q
        Suppresses all prompts for input from the user, and assumes the default
        answers.
        Initial value from \$QUIET or 'false'

    --trace | -x
        Sets the Bash trace option 'set -x' and enables the output from the
        functions 'trace' and 'dump_vars'.
        Initial value from \$TRACE_ENABLED or 'false'

    --verbose | -v
        Enables verbose output: all output from the invoked commands (e.g. jq,
        dotnet, etc.) to be sent to 'stdout' instead of '/dev/null'. It also
        enables the output from the script function trace() and all other
        commands and functions that are otherwise silent.
        Initial value from \$VERBOSE or 'false'

    --graphical | -gr
        Sets the output dump table format to graphical.
        Initial value from \$TABLE_FORMAT or 'graphical'

    --markdown | -md
        Sets the output dump table format to markdown.
        Initial value from \$TABLE_FORMAT or 'graphical'
"
