# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2089,SC2090

#=============================================================================================
# This script defines the common environment variables (core state) for the vm2 bash scripts:
# ci, debugger, quiet, verbose, table_format, dry_run, etc., that define some of the behaviors
# of the vm2 scripts. It also defines functions for managing these environment variables.
# Avoid directly modifying these environment variables outside of the provided functions.
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_CORE_STATE_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_CORE_STATE_SH_LOADED=1

declare -x  script_name

declare -xi success                     # The command completed successfully.
declare -xi failure                     # A general, unspecified error occurred.

declare -xi positive                    # Boolean return codes (truthy), you cannot use `return true` in bash but you can `return $positive`;
declare -xi negative                    # Boolean return codes (falsy), you cannot use `return false` in bash but you can `return $negative`;

declare -xi err_invalid_arguments       # The number of the arguments is invalid or more than one type of parameter error code is present
declare -xi err_argument_type
declare -xi err_argument_value          # An argument has an invalid value (out of range, not in allowed set, e.g., expected non-negative integer but got negative value)
declare -xi err_invalid_nameref         # An argument has an invalid nameref (e.g., expected a valid variable name reference but got an invalid one)
declare -xi err_logic_error             # An error occurred in the logic of the script (e.g., bug, invalid state, unexpected condition, etc.)

#---------------------------------------------------------------------------------------------
# @description The initial current working directory when the script started.
#   This value is captured at the very beginning of the script execution and remains constant
#   throughout the script's lifetime. It can be used to return to the original directory if
#   needed.
#---------------------------------------------------------------------------------------------
initial_cwd=$(pwd)
declare -xr initial_cwd


#---------------------------------------------------------------------------------------------
# @description: Indicates whether the script is running under a debugger, e.g. BashDb.
#    SHOULD NOT BE OVERRIDDEN BY TOP-LEVEL SWITCHES AND OPTIONS!
# @default false
# @type boolean
#---------------------------------------------------------------------------------------------
declare -x debugger
[[ -n "${_Dbg_DEBUGGER_LEVEL:-}" || -n "${BASHDB_HOME:-}" ]] && debugger=true || debugger=false
declare -xr debugger

#---------------------------------------------------------------------------------------------
# @description Indicates whether the script is running in CI/CD environment.
#    The `$ci` value should be based only on environment variables defined by the CI/CD
#    system, e.g. GitHub Actions, Azure DevOps, etc. Usually env.var. $CI
#---------------------------------------------------------------------------------------------
declare -xr ci=${CI:-${GITHUB_ACTIONS:-${TF_BUILD:-false}}}

#---------------------------------------------------------------------------------------------
# @description Checks if the `glow` command-line tool is installed on the system.
# @default false
# @type boolean
#---------------------------------------------------------------------------------------------
declare -x glow_present=false
if command -v -p "glow" &> "/dev/null" || which "glow" &>"/dev/null"; then
    glow_present=true
fi
declare -xr glow_present

#---------------------------------------------------------------------------------------------
# default values for the core state variables
#---------------------------------------------------------------------------------------------
declare -xr default_quiet=$ci
declare -xr default_verbose=false
declare -xr default_dry_run=false
declare -xr default__ignore="/dev/null"
declare -xra table_formats=("graphical" "markdown")
declare -xr default_table_format="graphical"
# if $ci; then
#     default_table_format="markdown"
# else
#     default_table_format="graphical"
# fi
# declare -xr default_table_format

#=============================================================================================
# Verbose mode
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description A global flag indicating whether the script should operate in verbose mode.
#   When set to `true`, the script provides extra output for debugging and informational
#   purposes.
# Notes:
#   - Consider this variable as a private implementation detail; it should not be modified
#     directly outside of the provided functions.
#   - It is tested by the `is_verbose()` function.
#   - It is controlled by the functions `set_verbose()` and `unset_verbose()`. And is usually
#     influenced by the `--verbose` command-line flag
# @default false
# @type boolean
#---------------------------------------------------------------------------------------------
declare __verbose=$default_verbose

#---------------------------------------------------------------------------------------------
# @description Tests whether the script is in verbose mode.
#
# @exitcode success/positive=0: Verbose mode is on.
# @exitcode failure/negative=1: Verbose mode is off.
#
# @example
#   if is_verbose; then echo "Verbose mode is on"; else echo "Verbose mode is off"; fi
#---------------------------------------------------------------------------------------------
function is_verbose()
{
    "$__verbose"
}

#---------------------------------------------------------------------------------------------
# @description Sets the script to verbose mode, enabling detailed output.
#
# Notes:
#   - Sets the global variable `$verbose` to `true`.
#
# @exitcode success/positive=0
#
# @example
#   set_verbose  # typically called when --verbose flag is passed
#---------------------------------------------------------------------------------------------
function set_verbose()
{
    __verbose=true
}

#---------------------------------------------------------------------------------------------
# @description Clears the script's verbose mode, disabling detailed output.
#
# Notes:
#   - Sets the global variable `$verbose` to `false`.
#
# @exitcode success/positive=0
#
# @example
#   unset_verbose  # typically called explicitly to disable verbose mode, allowing less detailed output
#---------------------------------------------------------------------------------------------
function unset_verbose()
{
    __verbose=false
}

#=============================================================================================
# Quiet mode
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description A global flag indicating whether the script should operate in quiet mode.
#   When set to `true`, the script suppresses user prompts, does not wait for user's input and
#   assumes default input value(s) as defined by the input prompts.
#   - Consider this variable as a private implementation detail; it should not be modified
#     directly outside of the provided functions.
#   - It is tested by the `is_quiet()` function.
#   - It is controlled by the functions `set_quiet()` and `unset_quiet()`. And is usually
#     influenced by the `--quiet` command-line flag
# @default false
# @type boolean
#---------------------------------------------------------------------------------------------
declare __quiet=$default_quiet

#---------------------------------------------------------------------------------------------
# @description Tests whether the script is in quiet mode.
#
# @exitcode success/positive=0: Quiet mode is on.
# @exitcode failure/negative=1: Quiet mode is off.
#
# @example
#   if is_quiet; then echo "Quiet mode is on"; else echo "Quiet mode is off"; fi
#---------------------------------------------------------------------------------------------
function is_quiet()
{
    "$__quiet"
}

#---------------------------------------------------------------------------------------------
# @description Sets the script to quiet mode, suppressing user prompts.
#
# Notes:
#   - Sets the global variable `$quiet` to `true`.
#
# @exitcode success/positive=0
#
# @example
#   set_quiet  # typically called when --quiet flag is passed
#---------------------------------------------------------------------------------------------
function set_quiet()
{
    __quiet=true
}

#---------------------------------------------------------------------------------------------
# @description Sets the script to non-quiet mode, enabling user prompts.
#
# Notes:
#   - Sets the global variable `$quiet` to `false`.
#
# @exitcode success/positive=0
#
# @example
#   unset_quiet  # typically called explicitly to disable quiet mode, allowing user prompts
#---------------------------------------------------------------------------------------------
function unset_quiet()
{
    __quiet=false
}

#=============================================================================================
# Dry-run mode
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description A global flag indicating whether the script should perform a "dry" run.
#   When set to `true`, the script simulates actions without making any actual changes.
#   - Consider this variable as a private implementation detail; it should not be modified
#     directly outside of the provided functions.
#   - It is tested by the `is_dry_run()` function.
#   - It is controlled by the functions `set_dry_run()` and `unset_dry_run()`. And is usually
#     influenced by the `--dry-run` command-line flag
# @default false
# @type boolean
#---------------------------------------------------------------------------------------------
declare __dry_run=$default_dry_run

#---------------------------------------------------------------------------------------------
# @description Tests whether the script is in dry-run mode.
#
# @exitcode success/positive=0: Dry-run mode is on.
# @exitcode failure/negative=1: Dry-run mode is off.
#
# @example
#   if is_dry_run; then echo "Dry-run mode is on"; else echo "Dry-run mode is off"; fi
#---------------------------------------------------------------------------------------------
function is_dry_run()
{
    "$__dry_run"
}

#---------------------------------------------------------------------------------------------
# @description Sets the script to dry-run mode, simulating commands without execution.
#
# Notes:
#   - Sets the global variable `$dry_run` to `true`.
#
# @exitcode success/positive=0
#
# @example
#   set_dry_run  # typically called when --dry-run flag is passed
#---------------------------------------------------------------------------------------------
function set_dry_run()
{
    __dry_run=true
}

#---------------------------------------------------------------------------------------------
# @description Clears the script's dry-run mode, disabling simulation of commands.
#
# Notes:
#   - Sets the global variable `$dry_run` to `false`.
#
# @exitcode success/positive=0
#
# @example
#   unset_dry_run  # typically called explicitly to disable dry-run mode, allowing actual
#   command execution
#---------------------------------------------------------------------------------------------
function unset_dry_run()
{
    __dry_run=false
}

#=============================================================================================
# Ignore output
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description The name of an I/O stream where unwanted output SHOULD be redirected to. E.g.,
#   'stderr' or even 'stdout' from commands to avoid cluttering the terminal or logs. When you
#   need to see that output for debugging purposes, you can invoke `show_ignored_output` to
#   redirect `$_ignore` to `/dev/stderr`. AVOID redirecting `$_ignore` it to `/dev/stdout`
#   blindly! If the output of the command is captured or redirected, the output to '$_ignore'
#   may interfere with the expected output of the command and the logic of the script.
#   Therefore prefer using the functions `show_ignored_output()` without arguments and
#   `hide_ignored_output()` to manipulate `$_ignore`.
# @default "/dev/null"
# @type string
#---------------------------------------------------------------------------------------------
declare -x _ignore=$default__ignore

#---------------------------------------------------------------------------------------------
# @description Redirects the ignored output (held in $_ignore) to the specified file. With no
#    argument, redirects it to `/dev/stderr` so that output that is normally discarded becomes
#    visible for debugging purposes.
#
# Notes:
#   - Redirecting to /dev/stdout is allowed but triggers a warning, since it can corrupt the
#     output of any command whose stdout is captured or redirected.
#
# @arg $1 string file to redirect the ignored output to (optional, default: /dev/stderr)
#
# @exitcode success/positive=0
#
# @example
#   show_ignored_output /dev/stdout
#---------------------------------------------------------------------------------------------
function show_ignored_output()
{
    (( $# <= 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() accepts at most one argument (provided $#):" \
                                                        "  - the file name to redirect the ignored output to"
    exit_if_has_bugs

    (( $# == 0 )) && _ignore=/dev/stderr && return "$success"

    [[ ! $1 =~ ^(/dev/stdout|/dev/fd/1|/proc/self/fd/1)$ ]] ||
        warning "Redirecting ignored output to '/stdout' may lead to unpredictable output results if it is also redirected or captured!"

    _ignore=$1
}

#---------------------------------------------------------------------------------------------
# @description Restores the ignored output (held in $_ignore) to /dev/null.
#
# @exitcode success/positive=0
#---------------------------------------------------------------------------------------------
function hide_ignored_output()
{
    _ignore=$default__ignore
}

#=============================================================================================
# Trace mode
#=============================================================================================
# Note that this mode is actually a combination of enabling verbose mode, redirecting ignored output to stderr, and turning on
# bash's trace option.

#---------------------------------------------------------------------------------------------
# @description Enables trace mode for debugging purposes: turns on verbose mode, redirects
#    normally-suppressed output to `stderr`, and enables bash's built-in trace option.
#
# Notes:
#   - Sets the global variable `$verbose` to `true`.
#   - Sets the global variable `$_ignore` to `/dev/stderr`.
#   - Enables bash trace mode (`set -x`).
#   - the output may become verbose and include all commands executed along with their
#     arguments, therefore it is recommended to use this mode primarily for debugging purposes
#     on a narrow scope or during specific debugging sessions.
#
# @exitcode success/positive=0
#
# @example
#   set_trace_enabled  # typically called when --trace flag is passed
#---------------------------------------------------------------------------------------------
function set_trace_enabled()
{
    __verbose=true
    _ignore=/dev/stderr
    set -x
}

#---------------------------------------------------------------------------------------------
# @description Disables trace mode for debugging: turns off verbose mode, redirects normally-
#   suppressed output back to `/dev/null`, and disables bash's built-in trace option.
#
# Notes:
#   - Sets the global variable `$verbose` to `false`.
#   - Sets the global variable `$_ignore` to `/dev/null`.
#   - Disables bash trace mode (`set +x`).
#
# @exitcode success/positive=0
#
# @example
#   unset_trace_enabled  # typically called explicitly to disable trace mode, allowing less
#   detailed output
#---------------------------------------------------------------------------------------------
function unset_trace_enabled()
{
    __verbose=false
    _ignore=$default__ignore
    set +x
}

#---------------------------------------------------------------------------------------------
# @description Tests whether tracing is enabled in the script.
#
# @exitcode success/positive=0: Trace is enabled.
# @exitcode failure/negative=1: Trace is disabled
#
# @example
#   if is_trace_enabled; then echo "Trace is enabled."; else echo "Trace is disabled"; fi
#---------------------------------------------------------------------------------------------
function is_trace_enabled()
{
    is_verbose && [[ $_ignore != "$default__ignore" && $- =~ .*x.* ]]
}

#=============================================================================================
# Table of dump_vars mode
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description A global variable specifying the format for table output from dump_vars. Can be
#   set to either "graphical" or "markdown".
#   - Consider this variable as a private implementation detail; it should not be modified
#     directly outside of the provided functions
#   - The table format is obtained by the `get_table_format()` function
#   - It is controlled by the functions `set_table_format()`. It is usually influenced by the
#     `--graphical` or `--markdown` command-line flags
# @default in CI - "markdown", otherwise "graphical"
# @type string with 2 valid values: "graphical" or "markdown"
#---------------------------------------------------------------------------------------------
declare __table_format=$default_table_format

#---------------------------------------------------------------------------------------------
# @description Returns the current table format setting.
#
# @arg $1 nameref The name of the variable to store the current table format in.
#
# @exitcode success/positive=0
#
# @example
#   get_table_format current_format
#---------------------------------------------------------------------------------------------
function get_table_format()
{
    (( $# == 1 ))                               || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one parameter ($# provided):" \
                                                                                    "  - the name of the variable to store the current table format in."
    [[ ! -v 1 ]] || is_defined_variable "$1"    || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires a declared variable name as its argument: '${1:-<none>}'."

    exit_if_has_bugs

    local -n _ret_format=$1
    _ret_format="$__table_format"
}

#---------------------------------------------------------------------------------------------
# @description Sets the table format used for variable dumps (e.g. in `dump_vars`) to either
#   "graphical" or "markdown".
#
# Notes:
#   - The format is matched case-insensitively; on success, sets the global variable
#     `$table_format` to the lower-cased value.
#
# @arg $1 string The desired table format. Must be one of the values in `$table_formats`
#   ("graphical" or "markdown").
#
# @exitcode success/positive=0: The format was valid and `$table_format` was updated.
#
# @example
#   set_table_format "markdown"
#---------------------------------------------------------------------------------------------
function set_table_format()
{
    (( $# == 1 ))                                        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one parameter ($# provided):" \
                                                                                                "  - the table format, one of ${table_formats[*]}"
    [[ ! -v 1 ]] || is_in "${1,,}" "${table_formats[@]}" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires its argument to be a valid table format '${1:-<none>}': must be one of ${table_formats[*]}."

    exit_if_has_bugs

    __table_format="${1,,}"
    trace -sd 10 "Table format set to: $__table_format"
}

#=============================================================================================
# Save/Restore core state
#=============================================================================================

# indexes for a state array (used by save_state and restore_state)
declare -xr key_pid="PID"
declare -xr key_subshell_pid="Subshell_PID"
declare -xr key_ci="CI"
declare -xr key_quiet="Quiet"
declare -xr key_verbose="Verbose"
declare -xr key_dry_run="Dry_Run"
declare -xr key_tracing="Tracing"
declare -xr key_ignore="Ignore"
declare -xr key_table_format="Table_Format"
declare -xr key_errors="Errors_Count"
declare -xr key_case_sensitivity="Case_Sensitivity"
declare -xr key_glob_star="Glob_Star"
declare -xr key_null_glob="Null_Glob"
declare -xri state_length=12

#---------------------------------------------------------------------------------------------
# @description Internal helper used only by `save_state`/`restore_state`, to test whether $1
#   names an existing associative array variable. `save_state`/`restore_state` must not call
#   any other library function (other than `bug`/`exit_if_has_bugs`) -- in particular, they
#   must never call `is_defined_associative_array`, which itself calls `save_state`, causing
#   unbounded recursion. Uses only raw bash builtins.
#
# Notes:
#   - This function is intended for internal use only.
#   - It does not rely on any other library functions to avoid recursion issues.
#   - It uses raw bash builtins to determine if the variable is an associative array.
#
# @arg $1 string Name of the variable to test.
#
# @exitcode success/positive=0: $1 names an existing associative array.
# @exitcode failure/negative=1: otherwise.
#---------------------------------------------------------------------------------------------
function __is_state_array()
{
    local _was_nocasematch=false
    shopt -q nocasematch && _was_nocasematch=true
    $_was_nocasematch && shopt -u nocasematch

    local _decl
    _decl=$(declare -p "$1" 2>"$_ignore")
    local -i _matched=1
    [[ $_decl == "declare -A"* ]] && _matched=0

    $_was_nocasematch && shopt -s nocasematch

    return "$_matched"
}

#---------------------------------------------------------------------------------------------
# @description Saves the current state of the global flags: quiet, verbose, dry-run,
#   `$_ignore`, table format, and the bash tracing option to an associative array, so it can
#   be restored later by `restore_state`.
#
# @arg $1 nameref `__state` name of an associative array variable that will store the saved
#   state. The array must be either a fresh, unused array or one that has been restored by
#   `restore_state`.
#
# Notes:
#   - Works cooperatively with `restore_state` to ensure no observable side effects on the
#     global flags
#   - do not change the state array manually between `save_state` and `restore_state` calls
#   - Guards against being called twice with the same state array without an intervening
#     `restore_state`
#   - The function does not initialize the array - the caller is supposed to do that by
#     - declaring it as an associative array with `declare -A state` before passing it to
#       `save_state` or by
#     - reusing it only after it has been restored with `restore_state`
#
# @exitcode success/positive=0: State saved successfully.
#
# @example
#   local -A state
#   save_state state
#   ...
#   # DO NOT USE $state here until it has been restored.
#   restore_state state
#   # after being restored the variable $state CAN BE USED again.
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2004 # $/${} is unnecessary on arithmetic variables.
function save_state()
{
    (( $# == 1 ))                         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects exactly one argument (provided $#):" \
                                                                               "  - the name of an array variable that will store the saved state"
    [[ ! -v 1 ]] || __is_state_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() expects its argument to be the name of an array variable that will store the saved state (provided '${1:-<none>}')."

    exit_if_has_bugs

    local -n __state="$1"

    [[ ! -v __state[$key_pid] ]] || (( __state[$key_pid] == 0 ))                    || bug -ec "$err_logic_error" "${FUNCNAME[0]}() must be called with a unused or previously restored state."
    [[ ! -v __state[$key_subshell_pid] ]] || (( __state[$key_subshell_pid] == -1 )) || bug -ec "$err_logic_error" "${FUNCNAME[0]}() must be called with a unused or previously restored state."

    exit_if_has_bugs

    local _current_table_format

    get_table_format _current_table_format

    __state[$key_pid]=$BASHPID
    __state[$key_subshell_pid]=${BASH_SUBSHELL:-0}
    __state[$key_ci]="$ci"
    __state[$key_ignore]=$_ignore
    __state[$key_table_format]=$_current_table_format
    __state[$key_errors]=$(get_errors)
    is_quiet          && __state[$key_quiet]=true   || __state[$key_quiet]=false
    is_verbose        && __state[$key_verbose]=true || __state[$key_verbose]=false
    is_dry_run        && __state[$key_dry_run]=true || __state[$key_dry_run]=false
    [[ $- =~ .*x.* ]] && __state[$key_tracing]=true || __state[$key_tracing]=false
    __state[$key_case_sensitivity]=$(shopt -p nocasematch)  || true
    __state[$key_glob_star]=$(shopt -p globstar) || true
    __state[$key_null_glob]=$(shopt -p nullglob) || true
}

#---------------------------------------------------------------------------------------------
# @description Restores the state of the global flags from a state previously stored by
#   `save_state`.
#
# Notes:
#   - Works cooperatively with `save_state` to ensure no observable side effects on the global
#     flags
#   - Validates that a matching `save_state` call happened, in the same process and the same
#     subshell level, before restoring
#
# @arg $1 nameref `__state` name of the associative array variable previously populated by
#   `save_state`.
#
# @exitcode success/positive=0: State restored successfully.
#
# @example
#   restore_state state  # typically called at the end of dump_vars
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2004 # $/${} is unnecessary on arithmetic variables.
# shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
function restore_state()
{
    local -i _rc=$success

    (( $# == 1 ))                         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects exactly one argument:" \
                                                                                "  - the name of an array variable that will store the saved state"
    [[ ! -v 1 ]] || __is_state_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() expects its argument to be the name of an associative array variable where 'save_state' has stored the global state (provided '${1:-<none>}')."

    exit_if_has_bugs

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local -n __state=$1

    (( ${#__state[@]} >= state_length )) &&
    [[ -v __state[$key_pid] ]]           && (( __state[$key_pid] == BASHPID )) &&
    [[ -v __state[$key_subshell_pid] ]]  && (( __state[$key_subshell_pid] == ${BASH_SUBSHELL:-0} )) ||
        bug -ec "$err_logic_error" "${FUNCNAME[0]}() must be called with a state previously stored by the function 'save_state' in this shell (and this sub-shell)."

    exit_if_has_bugs

    __state[$key_pid]=0
    __state[$key_subshell_pid]=-1
    _ignore=${__state[$key_ignore]}
    set_table_format "${__state[$key_table_format]}"
    set_errors "${__state[$key_errors]}"
    ${__state[$key_quiet]}   && set_quiet   || unset_quiet
    ${__state[$key_verbose]} && set_verbose || unset_verbose
    ${__state[$key_dry_run]} && set_dry_run || unset_dry_run
    ${__state[$key_tracing]} && set -x      || set +x
    eval "${__state[$key_case_sensitivity]:-true}" || true
    eval "${__state[$key_glob_star]:-true}"        || true
    eval "${__state[$key_null_glob]:-true}"        || true
}

#---------------------------------------------------------------------------------------------
# @description Sets whether case sensitivity should be enabled or disabled.
#
# @arg $1 bool Whether case sensitivity should be enabled (`true`) or disabled (`false`).
#
# @exitcode success/positive=0
#
# @example
#   local -A state
#   save_state state
#   set_case_sensitive true
#   ...
#   restore_state state
#---------------------------------------------------------------------------------------------
function set_case_sensitive()
{
    (( $# == 1 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects exactly one argument:" \
                                                                                  "  - a boolean value indicating whether case sensitivity should be enabled"
    [[ ! -v 1 ]] || is_boolean "$1"          || bug -ec "$err_argument_type" "${FUNCNAME[0]}() expects the first argument to be a boolean value"
    exit_if_has_bugs

    local _case_sensitive=$1

    if $_case_sensitive; then
        shopt -u nocasematch || true
    else
        shopt -s nocasematch || true
    fi
}

#---------------------------------------------------------------------------------------------
# @description Sets whether the globstar option should be enabled or disabled.
#
# @arg $1 bool Whether the globstar option should be enabled (`true`) or disabled (`false`).
#
# @exitcode success/positive=0
#
# @example
#   local -A state
#   save_state state
#   set_glob_star true
#   ...
#   restore_state state
#---------------------------------------------------------------------------------------------
function set_glob_star()
{
    (( $# == 1 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects exactly one argument:" \
                                                                                  "  - a boolean value indicating whether the globstar option should be enabled"
    [[ ! -v 1 ]] || is_boolean "$1"          || bug -ec "$err_argument_type" "${FUNCNAME[0]}() expects the first argument to be a boolean value"
    exit_if_has_bugs

    local _enable=$1

    if $_enable; then
        shopt -s globstar || true
    else
        shopt -u globstar || true
    fi
}

#---------------------------------------------------------------------------------------------
# @description Sets whether the nullglob option should be enabled or disabled.
#
# @arg $1 bool Whether the nullglob option should be enabled (`true`) or disabled (`false`).
#
# @exitcode success/positive=0
#
# @example
#   local -A state
#   save_state state
#   set_null_glob true
#   ...
#   restore_state state
#---------------------------------------------------------------------------------------------
function set_null_glob()
{
    (( $# == 1 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects exactly one argument:" \
                                                                                  "  - a boolean value indicating whether the nullglob option should be enabled"
    [[ ! -v 1 ]] || is_boolean "$1"          || bug -ec "$err_argument_type" "${FUNCNAME[0]}() expects the first argument to be a boolean value"
    exit_if_has_bugs

    local _enable=$1

    if $_enable; then
        shopt -s nullglob || true
    else
        shopt -u nullglob || true
    fi
}
