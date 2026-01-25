# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# default values for common flags
declare -r default_debugger=false
declare -r default_quiet=false
declare -r default_verbose=false
declare -r default_dry_run=false
declare -r default__ignore=/dev/null
declare -xr default_table_format="graphical"
declare -axr table_formats=("graphical" "markdown")
declare -r default_ci=false

declare -x debugger=${DEBUGGER:-$default_debugger}  # must be set if the script is running under a debugger, e.g. 'bashdb'
declare -x quiet=${QUIET:-$default_quiet}           # suppresses user prompts, assuming default answers
declare -x verbose=${VERBOSE:-$default_verbose}     # enables detailed output
declare -x dry_run=${DRY_RUN:-$default_dry_run}     # simulates commands without executing them
declare -x _ignore=$default__ignore                 # the file to redirect unwanted output to
declare table_format=${DUMP_FORMAT:-$default_table_format} # determines the format in which dump tables are displayed by the
                                                           # function `dump_vars`: graphical ASCII characters or markdown
                                                           # see also the available values in the array `table_formats` above

declare -rx ci=${CI:-$default_ci}                   # CI is usually defined by most CI/CD systems. Set from the env. variable CI.
                                                    # Never allow CI to be overridden from the command line.

## Sets the script to CI mode
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it
function set_ci()
{
    # guard CI from set_debugger
    debugger=false
    # guard CI from quiet off
    quiet=true
    _ignore=/dev/null
    set_table_format markdown
    set +x
    return 0
}

# Override the default or environment values of common flags based on other flags upon sourcing.
# Make sure that the other set_* functions are honoring the ci flag.
if [[ $ci == true ]]; then
    set_ci
fi

## Sets the script to debugger mode
# shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
function set_debugger()
{
    # guard CI from set_debugger
    [[ $ci == true ]] && debugger=false || debugger=true
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

## Sets the script to dry-run mode (does not execute commands, only simulates)
function set_dry_run()
{
    dry_run=true
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

declare got_debugger=false

function get_debugger()
{
    if [[ $got_debugger == true ]]; then
        return 0
    fi
    for v in "$@"; do
        if [[ "${v,,}" == "--debugger" ]]; then
            set_debugger
        fi
    done

    if [[ $debugger != "true" ]]; then
        # set the traps to see the last faulted command. However, they get in the way of debugging.
        trap on_debug DEBUG
        trap on_exit EXIT
    fi
    got_debugger=true
    return 0
}

## Processes common command-line arguments like --debugger, --quiet, --verbose, --trace, --dry-run
## Usage: get_common_arg <argument>
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it
function get_common_arg()
{
    if [[ $# -eq 0 ]]; then
        return 2
    fi
    get_debugger "$@"
    # the calling scripts should not use short options:
    # --help|-h|-\?--debugger|-q|--quiet-v|--verbose-x|--trace-y|--dry-run
    case "${1,,}" in
        --debugger      ) set_debugger ;;
        --help          ) usage true; exit 0 ;;
        -h|-\?          ) usage false; exit 0 ;;
        -v|--verbose    ) set_verbose ;;
        -q|--quiet      ) set_quiet ;;
        -x|--trace      ) set_trace_enabled ;;
        -y|--dry-run    ) set_dry_run ;;
        -gr|--graphical ) set_table_format "graphical" ;;
        -md|--markdown  ) set_table_format "markdown" ;;
        * ) return 1 ;;  # not a common argument
    esac
    return 0 # it was a common argument and was processed
}

## Displays a usage message and optionally an additional error message(s). If there are additional message, the function exits
## with code 2. Avoid calling this function directly; instead, override the usage() function in the calling script to provide
## custom usage information
## Usage: display_usage_msg <usage_text> [<additional_message>]
function display_usage_msg()
{
    if [[ $# -eq 0 || -z "$1" ]]; then
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
    shift
    if [[ $# -gt 0 && -n "$1" ]]; then
        error "$*" || true
        echo ""
        exit 2
    fi
    sync

    # restore the tracing state
    if ((set_tracing_on == 1)); then
        set -x
    fi
    return 0
}

## Displays the usage message for common flags
## ATTENTION: Override this function in the calling script to provide custom usage information
## Usage: usage()
function usage()
{
    display_usage_msg "$common_switches" "OVERRIDE THE FUNCTION usage() IN THE CALLING SCRIPT TO PROVIDE CUSTOM USAGE INFORMATION."
}

declare -rx common_switches="  -v, --verbose                 Enables verbose output:
                                1) displays the commands that will change some state, e.g. 'mkdir', 'git', 'dotnet', etc
                                2) all output to '/dev/null' is redirected to '/dev/stdout'
                                3) enables all tracing and dump outputs
                                Initial value from \$VERBOSE or 'false'
  -x, --trace                   Sets the switch '--verbose' and also redirects all suppressed output from '/dev/null' to
                                '/dev/stdout', sets the Bash trace option 'set -x'
  -y, --dry-run                 Does not execute commands that can change environments, e.g. 'mkdir', 'git', 'dotnet', etc
                                Displays what would have been executed
                                Initial value from \$DRY_RUN or 'false'
  -q, --quiet                   Suppresses all user prompts, assuming the default answers
                                Initial value from \$QUIET or 'false'
  -gr, --graphical              Sets the output dump table format to graphical
                                Initial value from \$DUMP_FORMAT or 'graphical'
  -md, --markdown               Sets the output dump table format to markdown
                                Initial value from \$DUMP_FORMAT or 'graphical'
  --debugger                    Must be set if the script is running under a debugger, e.g. 'gdb'. WhenMust be set if the script
                                is running under a debugger, e.g. 'gdb'. When specified, the script will not trap DEBUG and
                                EXIT, and will set the '--quiet' switch
                                Initial value from \$DEBUGGER or 'false'
  --help                        Displays longer version of the usage text - including all common flags
  -h | -?                       Displays shorter version of the usage text - without common flags

"

declare -rx common_vars="    VERBOSE                     Enables verbose output (see --verbose)
    DRY_RUN                     Does not execute commands that can change environments. (see --dry-run)
    QUIET                       Suppresses all user prompts, assuming the default answers
    DUMP_FORMAT                 Sets the output dump table format. Must be 'graphical' or 'markdown'
    DEBUGGER                    Could be set when the script is running under a debugger, e.g. 'gdb'

"
