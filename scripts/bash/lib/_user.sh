# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#=============================================================================================
# This script defines functions for interacting with the user in a Bash script.
# It includes functions for prompting the user, confirming actions, and reading input.
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_USER_SH_LOADED:-0} == 1 )) && return 0
declare -xri __VM2_LIB_USER_SH_LOADED=1

declare -xri secret_str

declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_invalid_nameref

#---------------------------------------------------------------------------------------------
# @description Displays a prompt and waits for the user to press any key before
# continuing. If the environment variable 'quiet' is true, skips the prompt and
# returns immediately.
#
# @exitcode success/positive=0
#
# @example
#   press_any_key  # typically called after displaying information
#---------------------------------------------------------------------------------------------
function press_any_key()
{
    is_quiet || {
        read -n 1 -r -s -p 'Press any key to continue...'
        echo
    }
    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Asks the user to respond yes or no to a prompt. If the environment
# variable 'quiet' is true, assumes the default response without prompting.
#
# @arg $1 string The confirmation question to ask.
# @arg $2 string Default response if the user presses Enter: 'y' or 'n' (optional, default:
#   'y').
#
# @exitcode success/positive=0: The response is 'y'.
# @exitcode failure/negative=1: The response is 'n'.
# @exitcode err_invalid_arguments=2: Invalid arguments.
#
# @example
#   if confirm "Delete all files?" "n"; then
#     rm -rf *
#   fi
#---------------------------------------------------------------------------------------------
function confirm()
{
    (( $# == 1 || $# == 2 ))           || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one or two arguments (provided $#):" \
                                                                            "  - prompt" \
                                                                            "  - default response, optional"
    [[ ! -v 1 || -n "$1" ]]            || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the confirmation prompt, to be non-empty (provided '${1:-<none>}')."
    [[ ! -v 2 || "${2,,}" =~ ^[yn]$ ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires optional argument 2, the default response, to be 'y' or 'n' (case-insensitive; provided '${2:-<none>}')."

    exit_if_has_bugs

    local _default="y"

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

#---------------------------------------------------------------------------------------------
# @description Displays a prompt and asks the user to enter a value.
#
# Notes:
#   - If the environment variable 'quiet' is true, skips prompting and immediately outputs the
#     default value (or an empty string if no default was provided).
#   - If $3 (is_secret) is true, the default value is masked in the prompt as '••••••', and
#     the terminal echo of the user's input is suppressed. The actual input (or default) is
#     still written to stdout. After reading the input, a newline is NOT printed to the
#     terminal; the caller should print one, as shown in the second example below.
#
# @arg $1 string `_prompt` The text of the prompt. Appended with ' [<default>]: ' if $2 is
#   non-empty, otherwise just ': '.
# @arg $2 nameref `_input` the name of a variable to store the entered value.
# @arg $3 string `_default` the default value output to stdout if the user presses [Enter]
#   without typing anything (optional if last, default: '').
# @arg $4 bool `_is_secret` suppresses echoing the input to the terminal. Use for passwords,
#   keys, etc. (optional if last, default: `false`).
# @arg $5 string `_validate_fn` name of a validation function, called with both the default
#   value (if provided) and the user's input. It must return 0 if the value is valid, non-zero
#   if invalid; the user is re-prompted until a valid value is entered (optional, default:
#   `true`, meaning no validation -- all values accepted).
#
# @exitcode success/positive=0: The input parameters are valid.
# @exitcode err_invalid_arguments=2: Invalid arguments.
#
# @example
#   enter_value "Enter description (up to 350 characters)" description "test" false
#   validate_no_longer_than_350
# @example
#   enter_value "Enter your password" password "" true validate_password
#---------------------------------------------------------------------------------------------
function enter_value()
{
    (( $# >= 2 && $# <= 5 ))                        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires from 2 to 5 arguments (provided $#):" \
                                                                                        "  - a prompt" \
                                                                                        "  - the name of the variable to store the entered value" \
                                                                                        "  - default value (optional if the rest are not specified, default: '')" \
                                                                                        "  - boolean to suppress the echo of the input to the terminal (optional if the rest are not specified, default: false)" \
                                                                                        "  - the name of a validation function (optional, default: true)"
    [[ ! -v 1 || -n $1 ]]                           || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the prompt, to be non-empty (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_defined_variable "$2"        || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the name of the variable to store the entered value, to be defined (provided '${2:-<none>}')."
    [[ ! -v 4 ]] || is_boolean "$4"                 || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires optional argument 4, the secret-input flag, to be 'true' or 'false' (provided '${4:-<none>}')."
    [[ ! -v 5 ]] || is_defined_function "$5"        || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires optional argument 5 to name a defined validation function (provided '${5:-<none>}')."

    local _default=${3:-''}
    local _validate_fn=${5:-true}

    [[ -z $_default ]] || $_validate_fn "$_default" || bug -ec "$err_argument_value" "The default value '$_default' does not pass the validation function '$_validate_fn'."

    exit_if_has_bugs

    is_quiet &&
        echo "$_default" &&
        return "$success"

    local _prompt=$1
    local -n _input="$2"
    local _is_secret=${4:-false}

    if [[ -n $_default ]]; then
        $_is_secret && _prompt="$_prompt [$secret_str]: " || _prompt="$_prompt [$_default]: "
    else
        _prompt="$_prompt: "
    fi

    local _valid=false
    local _errs
    _errs=$(get_errors)

    local _first_iter=true
    while ! $_valid; do
        if $_is_secret; then
            read -r -s -p "$_prompt" "${!_input}"
        else
            read -r    -p "$_prompt" "${!_input}"
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
}

#---------------------------------------------------------------------------------------------
# @description Displays a prompt and a list of options, and asks the user to choose one. If
#   the environment variable 'quiet' is true, or if the user just presses [Enter] without making
#   a choice, assumes the first option (the default).
#
# @arg $1 string The prompt to display before the options.
# @arg $2 nameref to a variable name to store the user's choice.
# @arg $3..$@ strings two or more option texts. The first option is the default returned if 'quiet'
#   is true or if the user just presses [Enter] without making a choice).
#
# @exitcode success/positive=0:
# @exitcode err_invalid_arguments=2: Invalid arguments (fewer than 3 parameters).
#
# @example
#   choose "Select environment:" choice "Development" "Staging" "Production"
#   case $choice in
#     1) env="dev" ;;
#     2) env="staging" ;;
#     3) env="prod" ;;
#     *) ...
#   esac
#---------------------------------------------------------------------------------------------
function choose()
{

    (( $# >= 4 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires four or more arguments (provided $#):" \
                                                                                    "  - prompt" \
                                                                                    "  - the name of a variable to store the user's choice" \
                                                                                    "  - at least two choices (the first one is the default)"
    [[ ! -v 1 || -n $1 ]]                    || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the prompt, to be non-empty (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_defined_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2, the name of the variable to store the user's choice, to be defined (provided '${2:-<none>}')."

    local -i _i
    for (( _i=3; _i<=$#; _i++ )); do
        [[ ! -v $_i || -n ${!_i} ]]          || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument $_i, the choice text, to be non-empty (provided '${!_i:-<none>}')."
    done

    exit_if_has_bugs

    local -i _rc="$success"
    local _prompt=$1
    local -n _selection="$2"
    shift 2
    _selection=1

    is_quiet && {
        # just return the default choice (1) via the nameref
        return "$success"
    }

    # print the menu
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
    while true; do
        read -r -p "Enter choice [1-${#_options[@]}]: " _selection
        _selection=${_selection:-1}
        if ! is_natural "$_selection"; then # it is not from this world;)
            warning "Invalid choice: $_selection."
            continue
        fi
        (( _selection == 0 )) && _selection=1 && break
        (( _selection >= 1    && _selection <= ${#_options[@]} )) && break
        warning "Invalid choice: $_selection"
    done
    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Prints a sequence of quoted values with a customizable quote, separator, and
#   enclosing parentheses. Named parameters must come before the values.
#
# @arg $@ mixed Named parameters (see below), followed by one or more positional
# values to include in the sequence.
#
# Named parameters:
#   --quote=<char>|-q=<char>        Quote character (default: '). Use '' for no quotes.
#   --separator=<char>|-s=<char>    Separator (default: ,). Special values: 'nl', 'tab', ''.
#   --paren=<type>|-p=<type>        Parentheses type: (), [], {}, nl, or none (default: none).
#   --json-array|--json|--jq-array|-j
#                                   Shorthand for --quote='"' --separator=', ' --paren='[]'.
#
# @exitcode success/positive=0
#
# @stdout The formatted sequence.
#
# @example
#   print_sequence --quote='"' --separator='; ' --paren='()' apple banana cherry
#   # Output: ("apple"; "banana"; "cherry")
#---------------------------------------------------------------------------------------------
function print_sequence()
{
    local _open_paren=""
    local _close_paren=""
    local _quote="'"
    local _separator=","
    local _arg
    for _arg in "$@"; do
        case $_arg in
            --json-array|--json|--jq-array|-j )
                _quote='"'
                _separator=", "
                _open_paren="["
                _close_paren="]"
                ;;
            --quote=*|-q=* )
                _quote="${_arg#*=}"
                ;;
            --separator=*|-s=* )
                _separator="${_arg#*=}"
                # Handle special values
                case "$_separator" in
                    nl  ) _separator=$'\n' ;;
                    tab ) _separator=$'\t' ;;
                    *   ) ;;
                esac
                ;;
            --parenthesis=*|--paren=*|-p=* )
                local _paren_val="${_arg#*=}"
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
                        warning "Unknown paren type: ${_arg#*=}. Ignoring."
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
    for _arg in "$@"; do
        # skip only the recognized named parameters (matching the case patterns above), not any
        # value that merely happens to start with '-' (e.g. a negative number).
        case $_arg in
            --json-array|--json|--jq-array|-j|--quote=*|-q=*|--separator=*|-s=*|--parenthesis=*|--paren=*|-p=* )
                continue
                ;;
            * ) ;;
        esac
        if $_first; then
            printf "%s%s%s" "$_quote" "$_arg" "$_quote"
            _first=false
        else
            printf "%s%s%s%s"  "$_separator" "$_quote" "$_arg" "$_quote"
        fi
    done
    [[ -n "$_close_paren" ]] && printf "%s" "$_close_paren" || true
}
