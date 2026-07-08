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
declare -rxi err_missing_argument
declare -rxi err_not_overridden
declare -rxi err_logic_error

# default values for the common flags below
declare -rx default_quiet=false
declare -rx default_verbose=false
declare -rx default_dry_run=false
declare -rx default_debugger=false
declare -rx default_ci=false
declare -rx default_table_format="graphical"

declare -axr table_formats=("graphical" "markdown")

# common flags exported for use by the top-level scripts with CLI switches, options and by other means. Prefer the set_* functions below to set them.
declare -rx default__ignore
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
    table_format
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
# @description Saves the current state of the global flags (quiet, verbose, dry-run, `$_ignore`, table format, and the
# bash tracing option) so it can be restored later by `restore_state`.
#
# Notes:
#   - Internal use only, by `dump_vars`. Do not call this directly -- it may change in the future.
#   - Works cooperatively with `restore_state` to ensure `dump_vars` has no observable side effects on these globals.
#   - Guards against being called twice without an intervening `restore_state` (tracked via `$__state_saved_pid`).
#
# @exitcode 0 State saved successfully.
# @exitcode 1 ($failure) Called while a state was already saved (no matching `restore_state` since the last `save_state`).
#
# @example
#   save_state  # typically called at the beginning of dump_vars
#-------------------------------------------------------------------------------
function save_state()
{
    if (( __state_saved_pid != 0 )); then
        error -ec "$err_logic_error" "${FUNCNAME[0]}() called while state is already saved." >&2
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
# @description Restores the global flags previously saved by `save_state`.
#
# Notes:
#   - Internal use only, by `dump_vars`. Do not call this directly -- it may change in the future.
#   - Works cooperatively with `save_state` to ensure `dump_vars` has no observable side effects on these globals.
#   - Validates that a matching `save_state` call happened, in the same process and the same subshell level, before
#     restoring; logs an error and returns failure otherwise.
#
# @exitcode 0 State restored successfully.
# @exitcode 1 ($failure) No matching `save_state` call, a process/subshell mismatch, or `set_table_format` failed while restoring.
#
# @example
#   restore_state  # typically called at the end of dump_vars
#-------------------------------------------------------------------------------
function restore_state()
{
    local bad_call=false

    (( __state_saved_pid != 0 )) || {
        error -ec "$err_logic_error" "${FUNCNAME[0]}() called before save_state." >&2
        bad_call=true
    }
    (( __state_saved_pid == BASHPID )) || {
        error -ec "$err_logic_error" "${FUNCNAME[0]}() must run in same shell: saved pid=$__state_saved_pid current pid=$BASHPID." >&2
        bad_call=true
    }
    (( __state_saved_subshell == ${BASH_SUBSHELL:-0} )) || {
        error -ec "$err_logic_error" "${FUNCNAME[0]}() called from different subshell level." >&2
        bad_call=true
    }
    __state_saved_pid=0
    __state_saved_subshell=-1
    ! $bad_call || return "$failure"

    set_table_format "$__saved_table_format" || {
        error -ec "$err_logic_error" "${FUNCNAME[0]}() failed to restore table format." >&2
        return "$failure"
    }
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
# @description Sets the script to quiet mode, suppressing user prompts.
#
# Notes:
#   - Sets the global variable `$quiet` to `true`.
#
# @exitcode 0 Always.
#
# @example
#   set_quiet  # typically called when --quiet flag is passed
#-------------------------------------------------------------------------------
function set_quiet()
{
    quiet=true
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Sets the script to non-quiet mode, enabling user prompts.
#
# Notes:
#   - Sets the global variable `$quiet` to `false`.
#
# @exitcode 0 Always.
#
# @example
#   unset_quiet  # typically called explicitly to disable quiet mode, allowing user prompts
#-------------------------------------------------------------------------------
function unset_quiet()
{
    quiet=false
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Tests whether the script is in quiet mode.
#
# @exitcode 0 Quiet mode is on.
# @exitcode 1 Quiet mode is off.
#
# @example
#   if is_quiet; then echo "Quiet mode is on"; else echo "Quiet mode is off"; fi
#-------------------------------------------------------------------------------
function is_quiet()
{
    "$quiet"
}

#-------------------------------------------------------------------------------
# @description Sets the script to verbose mode, enabling detailed output.
#
# Notes:
#   - Sets the global variable `$verbose` to `true`.
#
# @exitcode 0 Always.
#
# @example
#   set_verbose  # typically called when --verbose flag is passed
#-------------------------------------------------------------------------------
function set_verbose()
{
    verbose=true
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Clears the script's verbose mode, disabling detailed output.
#
# Notes:
#   - Sets the global variable `$verbose` to `false`.
#
# @exitcode 0 Always.
#
# @example
#   unset_verbose  # typically called explicitly to disable verbose mode, allowing less detailed output
#-------------------------------------------------------------------------------
function unset_verbose()
{
    verbose=false
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Tests whether the script is in verbose mode.
#
# @exitcode 0 Verbose mode is on.
# @exitcode 1 Verbose mode is off.
#
# @example
#   if is_verbose; then echo "Verbose mode is on"; else echo "Verbose mode is off"; fi
#-------------------------------------------------------------------------------
function is_verbose()
{
    "$verbose"
}

#-------------------------------------------------------------------------------
# @description Sets the script to dry-run mode, simulating commands without execution.
#
# Notes:
#   - Sets the global variable `$dry_run` to `true`.
#
# @exitcode 0 Always.
#
# @example
#   set_dry_run  # typically called when --dry-run flag is passed
#-------------------------------------------------------------------------------
function set_dry_run()
{
    dry_run=true
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Clears the script's dry-run mode, disabling simulation of commands.
#
# Notes:
#   - Sets the global variable `$dry_run` to `false`.
#
# @exitcode 0 Always.
#
# @example
#   unset_dry_run  # typically called explicitly to disable dry-run mode, allowing actual command execution
#-------------------------------------------------------------------------------
function unset_dry_run()
{
    dry_run=false
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Tests whether the script is in dry-run mode.
#
# @exitcode 0 Dry-run mode is on.
# @exitcode 1 Dry-run mode is off.
#
# @example
#   if is_dry_run; then echo "Dry-run mode is on"; else echo "Dry-run mode is off"; fi
#-------------------------------------------------------------------------------
function is_dry_run()
{
    "$dry_run"
}

#-------------------------------------------------------------------------------
# @description Enables trace mode for debugging: turns on verbose mode, redirects normally-suppressed output to
# stderr, and enables bash's built-in trace option.
#
# Notes:
#   - Sets the global variable `$verbose` to `true`.
#   - Sets the global variable `$_ignore` to `/dev/stderr`.
#   - Enables bash trace mode (`set -x`).
#
# @exitcode 0 Always.
#
# @example
#   set_trace_enabled  # typically called when --trace flag is passed
#-------------------------------------------------------------------------------
function set_trace_enabled()
{
    verbose=true
    _ignore=/dev/stderr
    set -x
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Disables trace mode for debugging: turns off verbose mode, redirects normally-suppressed output back
# to /dev/null, and disables bash's built-in trace option.
#
# Notes:
#   - Sets the global variable `$verbose` to `false`.
#   - Sets the global variable `$_ignore` to `/dev/null`.
#   - Disables bash trace mode (`set +x`).
#
# @exitcode 0 Always.
#
# @example
#   unset_trace_enabled  # typically called explicitly to disable trace mode, allowing less detailed output
#-------------------------------------------------------------------------------
function unset_trace_enabled()
{
    verbose=false
    _ignore=/dev/null
    set +x
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Sets the table format used for variable dumps (e.g. in `dump_vars`) to either "graphical" or
# "markdown".
#
# Notes:
#   - The format is matched case-insensitively; on success, sets the global variable `$table_format` to the
#     lower-cased value.
#
# @arg $1 string The desired table format. Must be one of the values in `$table_formats` ("graphical" or "markdown").
#
# @exitcode 0 The format was valid and `$table_format` was updated.
# @exitcode 2 ($err_invalid_arguments) Wrong argument count, or ($err_argument_value) the format is not one of
#   `$table_formats`.
#
# @example
#   set_table_format "markdown"
#-------------------------------------------------------------------------------
function set_table_format()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one parameter ($# provided) - the table format, one of ${table_formats[*]}"
        return "$err_invalid_arguments"
    }

    local f="${1,,}"

    for tf in "${table_formats[@]}"; do
        if [[ "$f" == "$tf" ]]; then
            table_format="$f"
            return "$success"
        fi
    done

    error -ec "$err_invalid_arguments" "Invalid table format: '$1'. Must be one of ${table_formats[*]}."
    return "$err_argument_value"
}

#-------------------------------------------------------------------------------
# @description Returns the current table format setting.
#
# @stdout string The current table format ("graphical" or "markdown").
#
# @exitcode 0 Always.
#
# @example
#   current_format=$(get_table_format)
#-------------------------------------------------------------------------------
function get_table_format()
{
    printf "%s" "$table_format"
    return "$success"
}

declare -x usage_requested=""

#-------------------------------------------------------------------------------
# @description Processes one common command-line argument, such as `--quiet`, `--verbose`, `--trace`, or `--dry-run`.
# Only long-form switches are recognized; calling scripts should not offer single-letter short options of their own
# that collide with these.
#
# Notes:
#   - May call `set_quiet`, `set_verbose`, `set_trace_enabled`, `set_dry_run`, or `set_table_format`, or set the
#     global `$usage_requested` (consumed later by `usage_if_requested`), depending on the argument.
#
# @arg $1 string The command-line argument to process.
#
# @exitcode 0 ($positive) The argument was a recognized common argument and was processed.
# @exitcode 1 ($negative) The argument was not a common argument.
# @exitcode 2 ($err_invalid_arguments) Wrong argument count.
#
# @example
#   for arg in "$@"; do
#     get_common_arg "$arg" && continue
#     # handle custom arguments
#   done
#-------------------------------------------------------------------------------
# shellcheck disable=SC2034 # variable appears unused. Verify it or export it
function get_common_arg()
{
    local -i validation_rc="$success"

    (( $# == 1 )) || {
        validation_rc="$err_invalid_arguments"
        error -sd 3 -ec "$validation_rc" "${FUNCNAME[0]}() requires one parameter ($# provided): the command-line argument to process"
    }

    (( validation_rc == success )) || return "$err_invalid_arguments"

    # the calling scripts should not use short options:
    # --help|-h|-\?|-v|--verbose|-q|--quiet|-x|--trace|-y|--dry-run|-gr|--graphical|-md|--markdown
    case "${1,,}" in
        --help          ) usage_requested="long";;
        -h|-\?          ) usage_requested="short";;
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
# @description Exits the script (via `usage`) if a usage request (`--help`, `-h`, or `-?`) was previously recorded
# by `get_common_arg` in the global `$usage_requested` variable.
#
# @exitcode 0 No usage was requested; execution continues normally.
# @noargs
#
# @example
#   usage_if_requested
#-------------------------------------------------------------------------------
function usage_if_requested()
{
    case "$usage_requested" in
        short ) usage false;;
        long  ) usage true;;
        *     ) return 0;;
    esac
}

#-------------------------------------------------------------------------------
# @description Displays an optional error message, then the (long or short) usage text, and exits the script.
#
# 1. Displays an optional error message at the top, via `error`.
# 1. Displays the long or short usage text, via `usage_text`.
# 1. Exits the script with the resolved exit code (see @exitcode below).
#
# Notes:
#   - Temporarily disables bash trace mode (`set -x`) while it runs, restoring the prior tracing state before
#     exiting, so the usage text itself is never polluted by trace output.
#
# @arg $1 bool Whether to display the long (`true`) or short (`false`) version of the usage text. The long version
#   includes the standard flags like verbose, quiet, etc. Optional, default: `false`.
# @arg $2 int The exit code to use when exiting. Optional, non-negative integer less than 256. Default: 0, or 1 if
#   error messages are present (see @exitcode below).
# @arg $@ string Additional error message parts to display at the top of the output. Optional; if omitted, no
#   message is shown. Supports the same named parameters as `message`/`error`:
#     - `--error-code`/`-ec` followed by a positive error code -- translated to a message and included in the output.
#       May occur multiple times; each occurrence is translated independently.
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show (default: 0). If given more
#       than once, only the last occurrence is used.
#
# @exitcode 0 ($success) No error messages were given, and $2 was omitted or 0.
# @exitcode 1 ($failure) Error messages were given and $2 was omitted or 0 (the exit code is forced to $failure).
# @exitcode N The exit code from $2, if it is a positive value (whether or not error messages are present).
#
# @example
#   usage true
# @example
#   usage "$err_invalid_arguments" -sd 3 -ec "$err_argument_value" "Invalid argument value for the option <option_name>"
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

    (( $# > 0 )) && {
        error "$@";
        exit_code="$failure"
    }

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
# @description Displays the usage text for the script. This default implementation is a placeholder -- override it in
# each top-level script to show script-specific usage information.
#
# @arg $1 bool Whether to display the long (`true`) or short (`false`) version of the usage text. The long version
#   includes the standard flags like verbose, quiet, etc. Optional, default: `false`.
#
# @stdout string The usage text (a placeholder message telling the script author to override this function, plus the
#   common switches/environment variables section when $1 is `true`).
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
OVERRIDE THE FUNCTION usage_text() IN THE CALLING SCRIPT $script_name TO PROVIDE CUSTOM USAGE INFORMATION.
$switches
$vars
EOF
}
