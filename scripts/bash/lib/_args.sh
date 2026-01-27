# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# default values for the common flags below
declare -xr default__ignore=/dev/null
declare -xr default_quiet=false
declare -xr default_verbose=false
declare -xr default_dry_run=false

declare -xr default_ci=false

declare -xr default_table_format="graphical"

declare -axr table_formats=("graphical" "markdown")

# common flags exported for use by the top-level scripts with CLI switches, options and by other means. Prefer the set_* functions below to set them.
declare -x _ignore=$default__ignore                 # the file to redirect unwanted output to
declare -x quiet=${QUIET:-$default_quiet}           # suppresses user prompts, assuming default answers
declare -x verbose=${VERBOSE:-$default_verbose}     # enables detailed output
declare -x dry_run=${DRY_RUN:-$default_dry_run}     # simulates commands without executing them
                                                    # the function `dump_vars`: graphical ASCII characters or markdown.
                                                    # See also the available values in the array `table_formats` above

declare -x ci=$default_ci                           # indicates whether the script is running in CI/CD environment.
                                                    # MUST NOT BE OVERRIDDEN BY TOP-LEVEL SWITCHES AND OPTIONS
                                                    # their values should be based only on environment variables defined by the
                                                    # CI/CD system, e.g. GitHub Actions, Azure DevOps, etc.

[[ -n "${_Dbg_DEBUGGER_LEVEL:-}" || -n "${BASHDB_HOME:-}" ]] && debugger=true || debugger=false
declare -xr debugger                                # indicates whether the script is running under a debugger, e.g. bashdb

if [[ "${GITHUB_ACTIONS:-}" == "true" || "${TF_BUILD:-}" == "True" || "${CI:-}" == "true" ]]; then # CI is usually defined by most CI/CD systems. Set from the env. variable CI.
    ci=true
    table_format=${DUMP_FORMAT:-markdown}           # in CI/CD environments, default to markdown format unless overridden by DUMP_FORMAT
else
    ci=false
    table_format=${DUMP_FORMAT:-graphical}          # on terminal, default to graphical format unless overridden by DUMP_FORMAT
fi
declare -rx ci                                      # freeze the value of ci after setting it above

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
    if [[ $# -ne 1 || -z "$1" ]]; then
        error "set_table_format requires one parameter - the table format"
        return 1
    fi
    local f="${1,,}"
    if ! is_in "$f" "${table_formats[@]}"; then
        error "Invalid table format: $1"
        return 1
    fi
    table_format="$f"
    return 0
}

function get_table_format()
{
    printf "%s" "$table_format"
    return 0
}

## Processes common command-line arguments like --quiet, --verbose, --trace, --dry-run
## Usage: get_common_arg <argument>
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it
function get_common_arg()
{
    if [[ $# -eq 0 ]]; then
        return 2
    fi
    # the calling scripts should not use short options:
    # --help|-h|-\?|-v|--verbose|-q|--quiet|-x|--trace|-y|--dry-run
    case "${1,,}" in
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

## Tests the error counter to determine if there are any accumulated errors so far
## Usage: exit_if_has_errors [<flag>]. The flag is optional and doesn't matter what it is - if it is passed, the method calls `exit 2`.
## Return: If it didn't exit, returns 1 if there are errors, 0 otherwise.
function exit_if_has_errors()
{
    # shellcheck disable=SC2154 # errors is referenced but not assigned.
    if ((errors > 0)); then
        usage false "$errors error(s) encountered. Please fix the above issues and try again."
        exit 2
    fi
    return 0
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
  --help                        Displays longer version of the usage text - including all common flags
  -h | -?                       Displays shorter version of the usage text - without common flags

"

declare -rx common_vars="  VERBOSE                       Enables verbose output (see --verbose)
  DRY_RUN                       Does not execute commands that can change environments. (see --dry-run)
  QUIET                         Suppresses all user prompts, assuming the default answers
  DUMP_FORMAT                   Sets the output dump table format. Must be 'graphical' or 'markdown'

"

# Override the default or environment values of common flags based on other flags upon sourcing.
# Make sure that the other set_* functions are honoring the ci flag.
if [[ $ci == true ]]; then
    # guard CI from quiet off
    _ignore=/dev/null
    set_quiet
    set_table_format markdown
    set +x
fi
# By default all scripts trap DEBUG and EXIT to provide better error handling.
# However, when running under a debugger, e.g. 'bashdb', trapping these signals
# interferes with the debugging session.
if [[ $debugger != "true" ]]; then
    # set the traps to see the last faulted command. However, they get in the way of debugging.
    trap on_debug DEBUG
    trap on_exit EXIT
fi
