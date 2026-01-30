# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed


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
# Summary: Enables trace mode for debugging by setting verbose, redirecting output, and enabling bash tracing.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Side Effects:
#   - Sets global variable $verbose to true
#   - Sets global variable $_ignore to /dev/stdout
#   - Enables bash trace mode (set -x)
# Usage: set_trace_enabled
# Example: set_trace_enabled  # typically called when --trace flag is passed
#-------------------------------------------------------------------------------
function set_trace_enabled()
{
    verbose=true
    _ignore=/dev/stdout
    set -x
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
        error "${FUNCNAME[0]}() requires one parameter - the table format"
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
function display_usage_msg()
{
    if [[ $# -eq 0 || -z "$1" ]]; then
        error "${FUNCNAME[0]}() requires at least one parameter - the usage text" >&2
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

#-------------------------------------------------------------------------------
# Summary: Tests the global error counter and exits if errors were encountered.
# Parameters:
#   1 - flag - optional parameter; if any value is provided, forces call to exit 2
# Returns:
#   Exit code: 2 if errors exist, 0 otherwise
# Env. Vars:
#   errors - global error counter
# Usage: exit_if_has_errors
# Example:
#   exit_if_has_errors  # exits with code 2 if errors exist
#-------------------------------------------------------------------------------
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
