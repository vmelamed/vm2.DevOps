# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # variable is referenced but not assigned.

#-------------------------------------------------------------------------------
# This script defines functions for interacting with the user in a Bash script.
# It includes functions for prompting the user, confirming actions, and reading input.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_USER_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_USER_SH_LOADED=1

declare -rxi secret_str

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value

#-------------------------------------------------------------------------------
# @description Displays a prompt and waits for the user to press any key before
# continuing. If the environment variable 'quiet' is true, skips the prompt and
# returns immediately.
#
# @exitcode 0 Always.
#
# @example
#   press_any_key  # typically called after displaying information
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function press_any_key()
{
    is_quiet || {
        read -n 1 -r -s -p 'Press any key to continue...'
        echo
    }
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Asks the user to respond yes or no to a prompt. If the environment
# variable 'quiet' is true, assumes the default response without prompting.
#
# @arg $1 string The confirmation question to ask.
# @arg $2 string Default response if the user presses Enter: 'y' or 'n' (optional, default: 'y').
#
# @exitcode 0 The response is 'y'.
# @exitcode 1 The response is 'n'.
# @exitcode 2 Invalid arguments.
#
# @example
#   if confirm "Delete all files?" "n"; then
#     rm -rf *
#   fi
#-------------------------------------------------------------------------------
function confirm()
{
    local -i _rc="$success"

    (( $# == 1 || $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires one or two arguments (provided $#): a prompt and an optional default response."
    }
    [[ -n "$1" ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the confirmation prompt, to be non-empty (provided '${1-<missing>}')."
    }
    [[ ! -v 2 || "${2,,}" =~ ^[yn]$ ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 2, the default response, to be 'y' or 'n' (case-insensitive; provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _default="y"
    local _errs

    (( $# == 1 )) || _default=${2,,}

    local _response=$_default
    is_quiet || {
        local _prompt="$1"
        local _suffix
        [[ "$_default" == y ]] && _suffix="[Y/n]" || _suffix="[y/N]"

        while true; do
            read -r -p "$_prompt $_suffix: " _response
            [[ -z "$_response" || "$_response" =~ ^[ynYN]$ ]] && break
            warning "Please enter one of Y or N (case insensitive)."
        done
    }

    _response=${_response:-$_default}
    [[ ${_response,,} == "y" ]]
}

#-------------------------------------------------------------------------------
# @description Displays a prompt and asks the user to enter a value.
#
# Notes:
#   - If the environment variable 'quiet' is true, skips prompting and
#     immediately outputs the default value (or an empty string if no default
#     was provided).
#   - If $3 (is_secret) is true, the default value is masked in the prompt as
#     '••••••', and the terminal echo of the user's input is suppressed. The
#     actual input (or default) is still written to stdout. After reading the
#     input, a newline is NOT printed to the terminal; the caller should print
#     one, as shown in the second example below.
#
# @arg $1 string The text of the prompt. Appended with ' [<default>]: ' if $2 is
# non-empty, otherwise just ': '.
# @arg $2 string Default value output to stdout if the user presses [Enter]
# without typing anything (optional if last, default: '').
# @arg $3 bool Suppresses echoing the input to the terminal. Use for passwords,
# keys, etc. (optional if last, default: false).
# @arg $4 string Name of a validation function, called with both the default
# value (if provided) and the user's input. It must return 0 if the value is
# valid, non-zero if invalid; the user is re-prompted until a valid value is
# entered (optional, default: true, meaning no validation -- all values accepted).
#
# @exitcode 0 The input parameters are valid.
# @exitcode 2 Invalid arguments.
#
# @stdout The entered value, or the default value if the user entered nothing.
#
# @example
#   password=$(enter_value "Enter description (up to 350 characters)" "test" false validate_no_longer_than_350)
# @example
#   password=$(enter_value "Enter your password" "" true) && echo ""
#-------------------------------------------------------------------------------
function enter_value()
{
    local -i _rc="$success"

    (( $# >= 1 && $# <= 4 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() accepts from 1 to 4 arguments (provided $#):" \
                              "    1) a prompt" \
                              "    2) default value (optional if the rest are not specified, default: '')" \
                              "    3) boolean to suppress the echo of the input to the terminal (optional if the rest are not specified, default: false)" \
                              "    4) the name of a validation function (optional, default: true)."
    }
    [[ -n $1 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the prompt, to be non-empty (provided '${1-<missing>}')."
    }
    [[ ! -v 3 || $3 =~ ^(true|false)$ ]] || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 3, the secret-input flag, to be 'true' or 'false' (provided '${3-<missing>}')."
    }
    [[ ! -v 4 ]] || is_defined_function "$4" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 4 to name a defined validation function (provided '${4-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _prompt=$1
    local _default=${2:-''}
    local _is_secret=${3:-false}
    local _validate_fn=${4:-true}

    is_quiet &&
        echo "$_default" &&
        return "$success"

    [[ -z $_default ]] || $_validate_fn "$_default" || {
        _rc="$err_argument_value"
        error -ec "$_rc" "The default value '$_default' does not pass the validation function '$_validate_fn'."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    if [[ -n $_default ]]; then
        $_is_secret && _prompt="$_prompt [$secret_str]: " || _prompt="$_prompt [$_default]: "
    else
        _prompt="$_prompt: "
    fi

    local _input
    local _valid=false
    local _errs
    _errs=$(get_errors)

    local _first_iter=true
    while ! $_valid; do
        if $_is_secret; then
            read -r -s -p "$_prompt" _input
        else
            read -r    -p "$_prompt" _input
        fi

        [[ -n "$_input" ]] || _input="$_default"
        $_validate_fn "$_input" && _valid=true || _valid=false

        ! $_valid && $_is_secret && $_first_iter && {
            # prefix the prompt with a newline to separate the new prompts with new lines in secret mode
            _prompt=$'\n'"$_prompt"
            _first_iter=false
        }
    done

    # all good here! reset the global error counter back to the value it had before the loop with the validation function
    set_errors "$_errs"
    echo "$_input"
}

#-------------------------------------------------------------------------------
# @description Displays a prompt and a list of options, and asks the user to
# choose one. If the environment variable 'quiet' is true, assumes the first
# option (the default) without prompting.
#
# @arg $1 string The prompt to display before the options.
# @arg $@ string Two or more option texts (the first option is the default).
#
# @exitcode 0 Success.
# @exitcode 2 Invalid arguments (fewer than 3 parameters).
#
# @stdout The number of the chosen option (1-based index).
#
# @example
#   choice=$(choose "Select environment:" "Development" "Staging" "Production")
#   case $choice in
#     1) env="dev" ;;
#     2) env="staging" ;;
#     3) env="prod" ;;
#   esac
#-------------------------------------------------------------------------------
function choose()
{
    local -i _rc="$success"

    (( $# >= 3 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires three or more arguments (provided $#): a prompt and at least two choices."
    }
    [[ -n $1 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the choice prompt, to be non-empty (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    is_quiet && {
        # just return the default choice (1)
        printf '1\n'
        return "$success"
    }

    # print the menu
    local _prompt=$1; shift
    local _options=("$@")

    echo "$_prompt" >&2

    local -i _opt_index
    local _opt
    for (( _opt_index=1; _opt_index <= ${#_options[@]}; _opt_index++ )); do
        _opt="${_options[_opt_index-1]}"
        (( _opt_index == 1 )) &&
            echo "  $_opt_index) $_opt (default)" >&2 ||
            echo "  $_opt_index) $_opt" >&2
    done

    # read the choice
    local _selection=1
    while true; do
        read -r -p "Enter choice [1-${#_options[@]}]: " _selection
        _selection=${_selection:-1}
        if ! is_natural "$_selection"; then # it is not from this world;)
            warning "Invalid choice: $_selection."
            continue
        fi
        (( _selection == 0 )) && _selection=1 && break
        (( _selection >= 1 && _selection <= ${#_options[@]} )) && break
        warning "Invalid choice: $_selection"
    done
    printf '%d\n' "$_selection"

    return "$success"
}

#-------------------------------------------------------------------------------
# @description Prints a sequence of quoted values with a customizable quote,
# separator, and enclosing parentheses. Named parameters must come before the
# values.
#
# @arg $@ mixed Named parameters (see below), followed by one or more positional
# values to include in the sequence.
#
# Named parameters:
#   --quote=<char>|-q=<char>         Quote character (default: '). Use '' for no quotes.
#   --separator=<char>|-s=<char>     Separator (default: ,). Special values: 'nl', 'tab', ''.
#   --paren=<type>|-p=<type>         Parentheses type: (), [], {}, nl, or none (default: none).
#   --json-array|--json|-j           Shorthand for --quote='"' --separator=', ' --paren='[]'.
#
# @exitcode 0 Always.
#
# @stdout The formatted sequence.
#
# @example
#   print_sequence --quote='"' --separator='; ' --paren='()' apple banana cherry
#   # Output: ("apple"; "banana"; "cherry")
#-------------------------------------------------------------------------------
function print_sequence()
{
    local _open_paren=""
    local _close_paren=""
    local _quote="'"
    local _separator=","
    for arg in "$@"; do
        case $arg in
            --json-array|--json|--jq-array|-j )
                _quote='"'
                _separator=", "
                _open_paren="["
                _close_paren="]"
                ;;
            --quote=*|-q=* )
                _quote="${arg#*=}"
                ;;
            --separator=*|-s=* )
                _separator="${arg#*=}"
                # Handle special values
                case "$_separator" in
                    nl  ) _separator=$'\n' ;;
                    tab ) _separator=$'\t' ;;
                    *   ) ;;
                esac
                ;;
            --parenthesis=*|--paren=*|-p=* )
                local _paren_val="${arg#*=}"
                case "$_paren_val" in
                    \(|\)|\(\) ) # (|)|()
                        _open_paren="("
                        _close_paren=")"
                        ;;
                    \[|\]|\[\] ) # [|]|[]
                        _open_paren="["
                        _close_paren="]"
                        ;;
                    \{|\}|\{\} ) # {|}|{}
                        _open_paren="{"
                        _close_paren="}"
                        ;;
                    nl|$'\n'|'\n' )
                        # Handle special values
                        _open_paren=$'\n'
                        _close_paren=$'\n'
                        ;;
                    * )
                        warning "Unknown paren type: ${arg#*=}. Ignoring."
                        _open_paren=""
                        _close_paren=""
                        ;;
                esac
                ;;
            * ) ;;
        esac
    done

    local _first=true
    [[ -n "$_open_paren" ]] && printf "%s" "$_open_paren" || true
    for arg in "$@"; do
        [[ "$arg" == -* || "$arg" == --* ]] && continue || true
        if $_first; then
            printf "%s%s%s" "$_quote" "$arg" "$_quote"
            _first=false
        else
            printf "%s%s%s%s"  "$_separator" "$_quote" "$arg" "$_quote"
        fi
    done
    [[ -n "$_close_paren" ]] && printf "%s" "$_close_paren" || true
}
