# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines the common arguments for the vm2 bash scripts: quiet, verbose,
# table_format, dry_run, debugger, and ci. It also defines functions for parsing from command
# line arguments, managing, validating, saving, and restoring the state of these arguments.
# It defines helpers that should be used by the top-level script's usage function.
#===============================================================================================

# Circular include guard
(( ${__VM2_LIB_CORE_ARGS_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_CORE_ARGS_SH_LOADED=1

declare -x script_name

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_argument_type
declare -x err_argument_value
declare -x err_missing_argument
declare -x err_not_overridden
declare -x err_logic_error
declare -x err_invalid_nameref

#===============================================================================================
# processing common command-line arguments
#===============================================================================================

declare usage_requested=""
#-----------------------------------------------------------------------------------------------
# @description Processes one common command-line argument, such as `--quiet`, `--verbose`,
#   `--trace`, or `--dry-run`. Long- and short-form switches are recognized. The calling
#   scripts should ensure that there are no other short- or long-form options colliding with
#   the common arguments options defined here. For example, the calling scripts may have a
#   first matching expression case like:
#   `-h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown ) ;;`
#   to satisfy this requirement, as they may no longer use any of these as their own option.
#
# Notes:
#   - Calls internally the common setting functions `set_verbose`, `set_quiet`,
#     `set_trace_enabled`, `set_dry_run`, `set_table_format` for the common CLI arguments like
#     `--verbose`, `--quiet`, etc.
#
# @arg $1 string The command-line argument to process.
#
# @exitcode positive=0: The argument was a common argument and was processed.
# @exitcode negative=1: The argument was not a common argument.
#
# @example
#   for arg in "$@"; do
#     get_common_arg "$arg" && continue
#     # handle custom arguments
#   done
#-----------------------------------------------------------------------------------------------
function get_common_arg()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the command-line argument to process."
                                                                                exit_if_has_bugs

    # the calling scripts should not use any of the common arguments options:
    # -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown
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

#-----------------------------------------------------------------------------------------------
# @description Exits the script (via `usage`) if a usage request (`--help`, `-h`, or `-?`) was
#   previously recorded by `get_common_arg` in the global `$usage_requested` variable.
#
# @noargs
#
# @exitcode success=0: No usage was requested; execution continues normally.
#
# @example
#   usage_if_requested
#-----------------------------------------------------------------------------------------------
function usage_if_requested()
{
    case "$usage_requested" in
        short ) usage false ;;
        long  ) usage true ;;
        *     ) return "$success" ;;
    esac
}

#-----------------------------------------------------------------------------------------------
# @description This function:
#   - displays an optional error message, via `error`.
#   - displays the long or the short usage text, via `usage_text`.
#   - exits the script with the resolved exit code (see @exitcode below).
#
# Notes:
#   - Overrides the function defined in _diagnostics.sh
#   - Temporarily disables bash trace mode (`set -x`) while it runs, so the usage text itself is
#     never polluted by trace output.
#
# @arg $1 bool `_long_usage` whether to display the long (`true`) or the short (`false`) version
#   of the usage text. The long version includes the common flags like verbose, quiet, etc.
#   Optional, default: `false`. Recognized only in the first position.
# @arg $2 int the vm2 `$err_*` code, passed on to error as its leading code. Optional.
#   Recognized only in the second position, if first position is boolean, otherwise in the first
#   position.
# @arg $@ string Error message parts. Optional. May include the following named parameters:
#     - `--error-code`/`-ec` followed by an error code -- the form before the leading code;
#       translated to its error message and included in the output where it appears. If $1 is
#       omitted, the last `--error-code` is assigned to `$__last_error` (`get_last_error()`)
#     - `--stack-depth`/`-sd` followed by an integer -- how many stack frames to show below
#       the message (default: all). If given more than once, the last occurrence takes effect.
#     - `--no-stack`/`-ns` -- do not dump the stack. Combined with `--stack-depth`/`-sd`, the
#       last occurrence takes effect.
#
# @stderr string The formatted error message, prefixed with `$error_prefix`.
# @stdout string the usage text
#
# @exitcode success=0: When only $1 is specified.
# @exitcode failure=1: Error messages were given, $2 was omitted, and no `--error-code`/`-ec`
#   named arguments were specified.
# @exitcode N The exit code from $2 (or $1), if it is a valid exit code or the code of the last
#   `--error-code`/`-ec` named argument.
#
# @example
#   usage true
# @example
#   usage "$err_unknown_argument" "Unknown argument: $_option" # exits with $err_unknown_argument
# @example
#   # explicit $2 (here $1) wins: exit with $err_invalid_arguments
#   usage "$err_invalid_arguments" "Invalid argument value for the option <option_name>" \
#                                  -ec "$err_unsafe_argument" -sd 3
#-----------------------------------------------------------------------------------------------
function usage()
{
    # save the tracing state and disable tracing
    local -A _core_state=()
    save_state _core_state
    set +x

    local _long_usage=false
    (( $# > 0 )) &&
        is_boolean "$1" &&
        _long_usage=$1 &&
        shift

    local -i _ec=$success

    if (( $# > 0 )); then
        # the remaining arguments are error messages to display at the top of the usage text
        error "$@" --stack-skip 3

        # the last error code is the exit code
        get_last_error _ec
    fi

    echo ""
    usage_text "$_long_usage"

    # restore the tracing state
    restore_state _core_state
    exit "$_ec"
}

#-----------------------------------------------------------------------------------------------
# @description the usage text fragment for the common arguments of a script.
#-----------------------------------------------------------------------------------------------
declare -xr common_args_usage="
Common switches:
  -v, --verbose                 Enables verbose output from tracing and variables dumps, e.g. in the 'dump_vars' function
                                Overrides the initial value from the environment value \$VERBOSE or 'false'
  -x, --trace                   1) Sets the switch '--verbose'
                                2) Redirects all suppressed output from '/dev/null' to '/dev/stderr'
                                3) Sets the Bash trace option 'set -x'
  -y, --dry-run                 Suppresses the execution of commands wrapped in 'execute' function and displays what would have
                                normally been executed. These commands usually change some external state, e.g. 'mkdir', 'git',
                                'dotnet', etc.)
                                Overrides the initial value from the environment value \$DRY_RUN or 'false'
  -q, --quiet                   Suppresses all user prompts, assuming the default answers
                                Overrides the initial value from the environment value \$QUIET or 'false'
  -gr, --graphical              Sets the output dump table format to graphical
                                Overrides the initial value from the environment value \$DUMP_FORMAT or 'graphical' in terminal
                                environments
  -md, --markdown               Sets the output dump table format to markdown
                                Overrides the initial value from the environment value \$DUMP_FORMAT or 'markdown' in CI
                                environments
  --help                        Displays longer version of the usage text - including all common flags
  -h, -?                        Displays shorter version of the usage text - without the common flags
                                If you have both --help and -h|-? in your script, the last one wins.

Common environment variables:
  VERBOSE                       Enables tracing and verbose output.
  DRY_RUN                       Does not execute commands that can change environments, i.e. have side effects.
  QUIET                         Suppresses all user prompts, assuming the default answers.
  DUMP_FORMAT                   Sets the output dump table format. Must be either 'graphical' or 'markdown'.
"

#-----------------------------------------------------------------------------------------------
# @description Verifies the arguments of the function usage_text usually defined in each top-
#   level script.
#
# @arg $1 bool _long_text whether Indicates whether to display the long (`true`) or short
#   (`false`) version of the usage text. The long version includes the standard flags like
#   verbose, quiet, etc. Optional, default: `false`.
#-----------------------------------------------------------------------------------------------
function assert_usage_text_args()
{
    (( $# ==1 ))                                                                || bug "$err_invalid_arguments" "${FUNCNAME[1]}() requires 1 argument (provided $#): a boolean, whether to display the long or short usage text."
    [[ ! -v 1 ]] || is_boolean "$1"                                             || bug "$err_argument_type" "${FUNCNAME[1]}() requires argument 1, whether to display the long or short usage text, to be 'true' or 'false' (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs
}

#-----------------------------------------------------------------------------------------------
# @description Displays the usage text for the script. This default implementation is a
#   placeholder -- override it in each top-level script to show script-specific usage
#   information.
#
# @arg $1 bool _long_text whether to display the long (`true`) or short (`false`) version of
#   the usage text. The long version includes the standard flags like verbose, quiet, etc.
#   Optional, default: `false`.
#
# @stdout string The usage text (a placeholder message telling the script author to override
#   this function, plus the common switches/environment variables section when $1 is `true`).
#-----------------------------------------------------------------------------------------------
function usage_text()
{
    assert_usage_text_args "$@"

    local _long_text=$1
    local _common_args

    $_long_text && _common_args=$common_args_usage || _common_args=''

    cat << EOF
OVERRIDE THE FUNCTION usage_text() IN THE CALLING SCRIPT '$script_name' TO PROVIDE CUSTOM USAGE INFORMATION.
$_common_args
EOF
}
