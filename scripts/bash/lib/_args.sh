# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed


# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2089
# shellcheck disable=SC2090

# default values for the common flags below
declare -xr default__ignore=/dev/null
declare -xr default_quiet=false
declare -xr default_verbose=false
declare -xr default_dry_run=false
declare -xr default_debugger=false
declare -xr default_ci=false
declare -xr default_table_format="graphical"

declare -axr table_formats=("graphical" "markdown")

# common flags exported for use by the top-level scripts with CLI switches, options and by other means. Prefer the set_* functions below to set them.
declare -x _ignore=$default__ignore                 # the file to redirect unwanted output to, changing the value may be useful for debugging, e.g. to redirect to /dev/stdout
declare -x quiet=${QUIET:-$default_quiet}           # suppresses user prompts, assuming default answers
declare -x verbose=${VERBOSE:-$default_verbose}     # enables detailed output
declare -x dry_run=${DRY_RUN:-$default_dry_run}     # simulates commands without executing them
                                                    # the function `dump_vars`: graphical ASCII characters or markdown.
                                                    # See also the available values in the array `table_formats` above
ci=${CI:-${GITHUB_ACTIONS:-${TF_BUILD:-$default_ci}}}
declare -rx ci                                      # Indicates whether the script is running in CI/CD environment.
                                                    # SHOPULD NOT BE OVERRIDDEN BY TOP-LEVEL SWITCHES AND OPTIONS!
                                                    # their values should be based only on environment variables defined by the
                                                    # CI/CD system, e.g. GitHub Actions, Azure DevOps, etc. Usually env.var. $CI

[[ -n "${_Dbg_DEBUGGER_LEVEL:-}" || -n "${BASHDB_HOME:-}" ]] && debugger=true || debugger=false
declare -xr debugger                                # Indicates whether the script is running under a debugger, e.g. bashdb.
                                                    # SHOULD NOT BE OVERRIDDEN BY TOP-LEVEL SWITCHES AND OPTIONS!

if [[ "${ci}" == true ]]; then # CI is usually defined by most CI/CD systems. Set from the env. variable CI.
    table_format=${DUMP_FORMAT:-markdown}           # in CI/CD environments, default to markdown format unless overridden by DUMP_FORMAT
    quiet=true                                      # in CI/CD environments, default to quiet mode
else
    table_format=${DUMP_FORMAT:-graphical}          # on terminal, default to graphical format unless overridden by DUMP_FORMAT
fi

#-------------------------------------------------------------------------------
# Summary: Sets the script to quiet mode, suppressing user prompts.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects: Sets global variable $quiet to true
# Usage: set_quiet
# Example: set_quiet  # typically called when --quiet flag is passed
#-------------------------------------------------------------------------------
function set_quiet()
{
    quiet=true
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Sets the script to non-quiet mode, enabling user prompts.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects: Sets global variable $quiet to false
# Usage: unset_quiet
# Example: unset_quiet  # typically called explicitly to disable quiet mode, allowing user prompts
#-------------------------------------------------------------------------------
function unset_quiet()
{
    quiet=false
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Returns whether the script is in quiet mode.
# Parameters: none
# Returns:
#   stdout: true if in quiet mode, false otherwise
#   Exit code: 0 if quiet mode is on and 1 if it is off
# Usage: if is_quiet; then ...
# Example: if is_quiet; then echo "Quiet mode is on"; else echo "Quiet mode is off"; fi
#-------------------------------------------------------------------------------
function is_quiet()
{
    $quiet
}

#-------------------------------------------------------------------------------
# Summary: Sets the script to verbose mode, enabling detailed output.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects: Sets global variable $verbose to true
# Usage: set_verbose
# Example: set_verbose  # typically called when --verbose flag is passed
#-------------------------------------------------------------------------------
function set_verbose()
{
    verbose=true
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Clears the script's verbose mode, disabling detailed output.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects: Sets global variable $verbose to false
# Usage: unset_verbose
# Example: unset_verbose  # typically called explicitly to disable verbose mode, allowing less detailed output
#-------------------------------------------------------------------------------
function unset_verbose()
{
    verbose=false
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Returns whether the script is in verbose mode.
# Parameters: none
# Returns:
#   stdout: true if in verbose mode, false otherwise
#   Exit code: 0 if verbose mode is on and 1 if it is off
# Usage: if is_verbose; then ...
# Example: if is_verbose; then echo "Verbose mode is on"; else echo "Verbose mode is off"; fi
#-------------------------------------------------------------------------------
function is_verbose()
{
    $verbose
}

#-------------------------------------------------------------------------------
# Summary: Sets the script to dry-run mode, simulating commands without execution.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects: Sets global variable $dry_run to true
# Usage: set_dry_run
# Example: set_dry_run  # typically called when --dry-run flag is passed
#-------------------------------------------------------------------------------
function set_dry_run()
{
    dry_run=true
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Clears the script's dry-run mode, disabling simulation of commands.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects: Sets global variable $dry_run to false
# Usage: unset_dry_run
# Example: unset_dry_run  # typically called explicitly to disable dry-run mode, allowing actual command execution
#-------------------------------------------------------------------------------
function unset_dry_run()
{
    dry_run=false
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Returns whether the script is in dry-run mode.
# Parameters: none
# Returns:
#   stdout: true if in dry-run mode, false otherwise
#   Exit code: 0 if dry-run mode is on and 1 if it is off
# Usage: if is_dry_run; then ...
# Example: if is_dry_run; then echo "Dry-run mode is on"; else echo "Dry-run mode is off"; fi
#-------------------------------------------------------------------------------
function is_dry_run()
{
    $dry_run
}

#-------------------------------------------------------------------------------
# Summary: Enables trace mode for debugging by setting verbose, redirecting output, and enabling bash tracing.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects:
#   - Sets global variable $verbose to true
#   - Sets global variable $_ignore to /dev/stderr
#   - Enables bash trace mode (set -x)
# Usage: set_trace_enabled
# Example: set_trace_enabled  # typically called when --trace flag is passed
#-------------------------------------------------------------------------------
function set_trace_enabled()
{
    verbose=true
    _ignore=/dev/stderr
    set -x
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Disables trace mode for debugging by clearing verbose, redirecting output, and disabling bash tracing.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects:
#   - Sets global variable $verbose to false
#   - Sets global variable $_ignore to /dev/null
#   - Disables bash trace mode (set +x)
# Usage: unset_trace_enabled
# Example: unset_trace_enabled  # typically called explicitly to disable trace mode, allowing less detailed output
#-------------------------------------------------------------------------------
function unset_trace_enabled()
{
    verbose=false
    _ignore=/dev/null
    set +x
    return 0
}

## Will be overridden in _predicates.sh, akin to forward declaration in C/C++
function is_in() { return 0; }

#-------------------------------------------------------------------------------
# Summary: Sets the table format for variable dumps to either graphical or markdown.
# Parameters:
#   1 - format - desired table format: "graphical" or "markdown"
# Returns:
#   Exit code: 0 on success, 2 on invalid format
# Side Effects: Sets global variable $table_format
# Dependencies: is_in function
# Usage: set_table_format <format>
# Example: set_table_format "markdown"
#-------------------------------------------------------------------------------
function set_table_format()
{
    if [[ $# -ne 1 || -z "$1" ]]; then
        error 3 "${FUNCNAME[0]}() requires one parameter - the table format"
        return 2
    fi
    local f="${1,,}"
    if ! is_in "$f" "${table_formats[@]}"; then
        error "Invalid table format: $1"
        return 2
    fi
    table_format="$f"
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Returns the current table format setting.
# Parameters: none
# Returns:
#   stdout: current table format ("graphical" or "markdown")
#   Exit code: 0 always
# Usage: format=$(get_table_format)
# Example: current_format=$(get_table_format)
#-------------------------------------------------------------------------------
function get_table_format()
{
    printf "%s" "$table_format"
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Processes common command-line arguments like --quiet, --verbose, --trace, --dry-run.
# Parameters:
#   1 - argument - command-line argument to process
# Returns:
#   Exit code: 0 if argument was processed, 1 if not a common argument, 2 if no argument provided
# Side Effects: May call set_* functions or usage/exit based on argument
# Usage: get_common_arg <argument>
# Example:
#   for arg in "$@"; do
#     get_common_arg "$arg" && continue
#     # handle custom arguments
#   done
#-------------------------------------------------------------------------------
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it
function get_common_arg()
{
    if [[ $# -eq 0 ]]; then
        return 2
    fi
    # the calling scripts should not use short options:
    # --help|-h|-\?|-v|--verbose|-q|--quiet|-x|--trace|-y|--dry-run
    run_short_usage=false
    run_long_usage=false
    case "${1,,}" in
        --help          ) run_long_usage=true; run_short_usage=false ;;
        -h|-\?          ) run_long_usage=false; run_short_usage=true ;;
        -v|--verbose    ) set_verbose ;;
        -q|--quiet      ) set_quiet ;;
        -x|--trace      ) set_trace_enabled ;;
        -y|--dry-run    ) set_dry_run ;;
        -gr|--graphical ) set_table_format "graphical" ;;
        -md|--markdown  ) set_table_format "markdown" ;;
        * ) return 1 ;;  # not a common argument
    esac
    $run_long_usage && usage true
    $run_short_usage && usage false
    return 0 # it was a common argument and was processed
}

#-------------------------------------------------------------------------------
# Summary: Displays a usage message and optionally additional error messages, exiting with code 2 if error messages are present.
# Parameters:
#   1 - usage_text - the usage text to display
#   2+ - additional_message - optional error messages to display (optional)
# Returns:
#   stdout: usage text
#   stderr: error messages if provided
#   Exit code: exits with 2 if additional messages provided, otherwise returns to caller
# Usage: display_usage_msg <usage_text> [additional_message...]
# Example: display_usage_msg "$usage_text" "Invalid parameter: $param"
# Notes: Temporarily disables tracing during display. Override usage() in calling scripts for custom help.
#-------------------------------------------------------------------------------
declare -x allow_on_exit

function display_usage_msg()
{
    if [[ $# -eq 0 || -z "$1" ]]; then
        error 3 "${FUNCNAME[0]}() requires at least one parameter - the usage text"
        exit 2
    fi

    local ec=0

    # save the tracing state and disable tracing
    local set_tracing_on
    [[ $- =~ .*x.* ]] && set_tracing_on=true || set_tracing_on=false
    set +x

    usage_txt=$1
    shift
    if [[ $# -gt 0 && -n "$1" ]]; then
        error 5 "$*"
        ec=2
    fi
    echo "
$usage_txt
"

    # restore the tracing state
    $set_tracing_on && set -x
    allow_on_exit=false
    exit "$ec"
}

#-------------------------------------------------------------------------------
# Summary: Displays the usage message; MUST be overridden in calling scripts for custom usage information.
# Parameters: varies by implementation in calling script
# Returns:
#   Exit code: depends on implementation
# Usage: Override this function in your script
# Example:
#   function usage() {
#     display_usage_msg "Usage: $script_name [options]" "$@"
#   }
#-------------------------------------------------------------------------------
function usage()
{
    display_usage_msg "$common_switches" "OVERRIDE THE FUNCTION usage() IN THE CALLING SCRIPT TO PROVIDE CUSTOM USAGE INFORMATION."
}

declare -rx common_switches="  -v, --verbose                 Enables verbose output from tracing and variables dumps, e.g. in the 'dump_vars' function
                                Initial value from \$VERBOSE or 'false'
  -x, --trace                   1) Sets the switch '--verbose'
                                2) Redirects all suppressed output from '/dev/null' to '/dev/stderr'
                                3) Sets the Bash trace option 'set -x'
  -y, --dry-run                 Suppresses the execution of commands wrapped in 'execute' function and displays what would have
                                normally been executed. These commands usually change some external state, e.g. 'mkdir', 'git',
                                'dotnet', etc.)
                                Initial value from \$DRY_RUN or 'false'
  -q, --quiet                   Suppresses all user prompts, assuming the default answers
                                Initial value from \$QUIET or 'false'
  -gr, --graphical              Sets the output dump table format to graphical
                                Initial value from \$DUMP_FORMAT or 'graphical' in terminal environments
  -md, --markdown               Sets the output dump table format to markdown
                                Initial value from \$DUMP_FORMAT or 'markdown' in CI environments
  --help                        Displays longer version of the usage text - including all common flags
  -h | -?                       Displays shorter version of the usage text - without common flags
                                If you have both --help and -h|-? in your script, the last one wins.
"

declare -rx common_vars="  VERBOSE                       Enables verbose output (see --verbose)
  DRY_RUN                       Does not execute commands that can change environments. (see --dry-run)
  QUIET                         Suppresses all user prompts, assuming the default answers (see --quiet)
  DUMP_FORMAT                   Sets the output dump table format. Must be 'graphical' or 'markdown'
                                (see --graphical and --markdown)
"

# Override the default or environment values of common flags based on other flags upon sourcing.
# Make sure that the other set_* functions are honoring the ci flag.
if [[ $ci == true ]]; then
    # guard CI from quiet off
    _ignore=$default__ignore
    set_quiet
    set_table_format markdown
    set +x
fi

# By default all scripts trap DEBUG and EXIT to provide better error handling.
# However, when running under a debugger, e.g. 'bashdb', trapping these signals
# interferes with the debugging session.
if [[ $debugger != true ]]; then
    # set the traps to see the last faulted command. However, they get in the way of debugging.
    trap on_debug DEBUG
    trap on_exit EXIT
fi
