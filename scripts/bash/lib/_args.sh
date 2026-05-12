# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2089,SC2090

#-------------------------------------------------------------------------------
# This script defines the common arguments for the vm2 bash scripts: quiet, verbose, table_format, dry_run, debugger, and ci.
# It also defines functions for parsing from command line arguments, managing, validating, saving, and restoring the state of
# these arguments.
# It defines helpers that should be used by the top-level scripts's usage function.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_ARGS_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_ARGS_SH_LOADED=1

declare -rx script_name

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_overridden

# default values for the common flags below
declare -xr default_quiet=false
declare -xr default_verbose=false
declare -xr default_dry_run=false
declare -xr default_debugger=false
declare -xr default_ci=false
declare -xr default_table_format="graphical"

declare -axr table_formats=("graphical" "markdown")

# common flags exported for use by the top-level scripts with CLI switches, options and by other means. Prefer the set_* functions below to set them.
declare -xr default__ignore
declare -x _ignore                                  # the file to redirect unwanted output to, changing the value may be useful for debugging, e.g. to redirect to /dev/stdout

declare -x quiet=${QUIET:-$default_quiet}           # suppresses user prompts, assuming default answers
declare -x verbose=${VERBOSE:-$default_verbose}     # enables detailed output
declare -x table_format=${TABLE_FORMAT:-$default_table_format}  # the format to use for the function `dump_vars`: graphical ASCII characters or markdown.
declare -x dry_run=${DRY_RUN:-$default_dry_run}     # simulates commands without executing them
                                                    # the function `dump_vars`: graphical ASCII characters or markdown.
                                                    # See also the available values in the array `table_formats` above
ci=${CI:-${GITHUB_ACTIONS:-${TF_BUILD:-$default_ci}}}
declare -rx ci                                      # Indicates whether the script is running in CI/CD environment.
                                                    # SHOPULD NOT BE OVERRIDDEN BY TOP-LEVEL SWITCHES AND OPTIONS!
                                                    # their values should be based only on environment variables defined by the
                                                    # CI/CD system, e.g. GitHub Actions, Azure DevOps, etc. Usually env.var. $CI

declare -xa common_args=(
    debugger
    ci
    PWD
    quiet
    verbose
    dry_run
)

[[ -n "${_Dbg_DEBUGGER_LEVEL:-}" || -n "${BASHDB_HOME:-}" ]] && debugger=true || debugger=false
declare -xr debugger                                # Indicates whether the script is running under a debugger, e.g. BashDb.
                                                    # SHOULD NOT BE OVERRIDDEN BY TOP-LEVEL SWITCHES AND OPTIONS!

declare __saved_quiet
declare __saved_verbose
declare __saved_table_format
declare __saved_dry_run
declare __saved_ignore
declare __set_tracing_on

declare -gi __state_saved_pid=0
declare -gi __state_saved_subshell=-1

#-------------------------------------------------------------------------------
# Summary: Saves current state of global flags to be restored later by restore_state.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Usage: save_state
# Example: save_state  # typically called at beginning of dump_vars
# Notes: Internally used by dump_vars. Do not use, as it may change in the future. Works cooperatively with restore_state to ensure no side effects in dump_vars.
#-------------------------------------------------------------------------------
function save_state()
{
    if (( __state_saved_pid != 0 )); then
        error "${FUNCNAME[0]}() called while state is already saved." >&2
        return "$failure"
    fi

    __state_saved_pid=$BASHPID
    __state_saved_subshell=${BASH_SUBSHELL:-0}

    is_quiet   && __saved_quiet=true   || __saved_quiet=false
    is_verbose && __saved_verbose=true || __saved_verbose=false
    is_dry_run && __saved_dry_run=true || __saved_dry_run=false
    __saved_ignore=$_ignore
    __saved_table_format=$(get_table_format)
    [[ $- =~ .*x.* ]] && __set_tracing_on=true || __set_tracing_on=false

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Restores state of global flags previously saved by save_state.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Usage: restore_state
# Example: restore_state  # typically called at end of dump_vars
# Notes: Internally used by dump_vars. Do not use, as it may change in the future. Works cooperatively with save_state to ensure no side effects in dump_vars.
#-------------------------------------------------------------------------------
function restore_state()
{
    local bad_call=false

    (( __state_saved_pid != 0 )) || {
        error "${FUNCNAME[0]}() called before save_state." >&2
        bad_call=true
    }
    (( __state_saved_pid == BASHPID )) || {
        error "${FUNCNAME[0]}() must run in same shell: saved pid=$__state_saved_pid current pid=$BASHPID." >&2
        bad_call=true
    }
    (( __state_saved_subshell == ${BASH_SUBSHELL:-0} )) || {
        error "${FUNCNAME[0]}() called from different subshell level." >&2
        bad_call=true
    }
    __state_saved_pid=0
    __state_saved_subshell=-1
    ! $bad_call || return "$failure"

    set_table_format "$__saved_table_format" || { error "${FUNCNAME[0]}() failed to restore table format." >&2; return "$failure"; }
    $__saved_quiet   && set_quiet   || unset_quiet
    $__saved_verbose && set_verbose || unset_verbose
    $__saved_dry_run && set_dry_run || unset_dry_run
    _ignore=$__saved_ignore
    if $__set_tracing_on; then
        set -x
    fi
    return "$success"
}

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
    return "$success"
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
    return "$success"
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
    "$quiet"
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
    return "$success"
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
    return "$success"
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
    "$verbose"
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
    return "$success"
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
    return "$success"
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
    "$dry_run"
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
    return "$success"
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
    return "$success"
}

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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires one parameter ($# provided) - the table format, one of ${table_formats[*]}"
        return "$err_invalid_arguments"
    }

    local f="${1,,}"

    for tf in "${table_formats[@]}"; do
        if [[ "$f" == "$tf" ]]; then
            table_format="$f"
            return "$success"
        fi
    done

    error "Invalid table format: '$1'. Must be one of ${table_formats[*]}."
    return "$err_argument_value"
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
    return "$success"
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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires one parameter ($# provided): the command-line argument to process"
        return "$err_invalid_arguments"
    }

    # the calling scripts should not use short options:
    # --help|-h|-\?|-v|--verbose|-q|--quiet|-x|--trace|-y|--dry-run
    run_short_usage=false
    run_long_usage=false

    case "${1,,}" in
        --help          ) usage true "$success" ;;
        -h|-\?          ) usage "$success" ;;
        -v|--verbose    ) set_verbose ;;
        -q|--quiet      ) set_quiet ;;
        -x|--trace      ) set_trace_enabled ;;
        -y|--dry-run    ) set_dry_run ;;
        -gr|--graphical ) set_table_format "graphical" ;;
        -md|--markdown  ) set_table_format "markdown" ;;
        *               ) return "$negative" ;;  # not a common argument
    esac

    return "$positive" # it was a common argument and was processed
}

#-------------------------------------------------------------------------------
# Summary:
#       1) displays optional exit error message
#       2) displays optionally long or short usage message
#       3) exits the script with
#               - optional exit code
#               - 0 ($success) if no error messages are present
#               - 1 ($failure) if error messages are present
# Parameters:
#   1 - long_help - boolean flag indicating whether to display the long (if true) or the short (if false) version of the usage text.
#       The long version includes the standard parameters like verbose, quiet, etc.
#       (optional, boolean, default: false)
#   2 - exit_code - the exit code to use when exiting
#       (optional, non-negative integer, less than 256, default 1 - if error messages are present, otherwise 0)
#   3+ - error_message(s) - additional error messages to display at the top
#       (optional, default - no message)
#
# Returns:
#   Exit code: depends on implementation
#     - provided exit code
#     - 1 ($failure) if error messages are present
#     - 0 ($success) if no error messages are present
# Usage: usage [<long_help>] [<exit_code>] [<error_message>]*
# Example:
#     usage true
#     usage $err_invalid_argument_value "Invalid argument value for the option <option_name>"
#-------------------------------------------------------------------------------
function usage()
{
    local long=false
    (( $# > 0 )) && is_boolean "$1" && long=$1 && shift

    local -i exit_code=$success
    (( $# > 0 )) && is_natural "$1" && exit_code=$1 && shift

    # the remaining arguments are error messages to display at the top of the usage text
    (( $# > 0 && exit_code == success )) && exit_code=$failure

    # save the tracing state and disable tracing
    local set_tracing_on=false
    [[ $- =~ .*x.* ]] && set_tracing_on=true
    set +x

    (( $# > 0 )) && error "$@"
    usage_text "$long"

    # restore the tracing state
    $set_tracing_on && set -x

    exit "$exit_code"
}

declare -rx common_switches=\
"  -v, --verbose                 Enables verbose output from tracing and variables dumps, e.g. in the 'dump_vars' function
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
  -h | -?                       Displays shorter version of the usage text - without the common flags
                                If you have both --help and -h|-? in your script, the last one wins.
"

declare -rx common_vars=\
"  VERBOSE                       Enables verbose output (see --verbose)
  DRY_RUN                       Does not execute commands that can change environments. (see --dry-run)
  QUIET                         Suppresses all user prompts, assuming the default answers (see --quiet)
  DUMP_FORMAT                   Sets the output dump table format. Must be 'graphical' or 'markdown'
                                (see --graphical and --markdown)
"

#-------------------------------------------------------------------------------
# Summary: Displays the usage text for the script. Override in each top-level script to show different usage text.
# Parameters:
#   1 - long_help - boolean flag indicating whether to display the long (if true) or the short (if false) version of the usage text.
#       The long version includes the standard parameters like verbose, quiet, etc.
#       (optional, boolean, default: false)
#-------------------------------------------------------------------------------
function usage_text()
{
    local long_text=$1
    local switches=""
    local vars=""

    if $long_text; then
        switches="Switches:"$'\n'"$common_switches"
        vars="Environment Variables:"$'\n'"$common_vars"
    fi

    cat << EOF
OVERRIDE THE FUNCTION usage_text() IN THE CALLING SCRIPT ${script_name} TO PROVIDE CUSTOM USAGE INFORMATION.
$switches
$vars
EOF
}
