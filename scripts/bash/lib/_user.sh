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
# Summary: Displays a prompt and waits for user to press any key before continuing.
# Parameters: none
# Returns:
#   Exit code: 0 always
# Env. Vars:
#   quiet - when true, skips prompt and returns immediately
# Usage: press_any_key
# Example: press_any_key  # typically called after displaying information
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
# Summary: Asks the user to respond yes or no to a prompt.
# Parameters:
#   1 - prompt - the confirmation question to ask
#   2 - default - default response if user presses Enter: "y" or "n" (optional, default: "y")
# Returns:
#   stdout: 'y' or 'n' based on user response
#   Exit code: 0 if response is 'y', 1 if response is 'n', 2 on invalid arguments
# Env. Vars:
#   quiet - when true, assumes default response without prompting
# Usage: if confirm <prompt> [default]; then ... fi
# Example:
#   if confirm "Delete all files?" "n"; then
#     rm -rf *
#   fi
#-------------------------------------------------------------------------------
function confirm()
{
    local -i rc="$success"

    (( $# == 1 || $# == 2 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires at least one parameter (provided $#): the prompt and a second, optional argument -default response."
    }
    [[ $# -lt 1 || -n "$1" ]] || {
        rc="$err_argument_value"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires that the \$1 parameter is not empty."
    }
    [[ $# -lt 2 || "${2,,}" =~ ^[yn]$ ]] || {
        rc="$err_argument_value"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires that the \$2 parameter is either 'y' or 'n' (case insensitive)."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local default="y"
    local errs

    (( $# == 1 )) || default=${2,,}

    local response=$default
    is_quiet || {
        local prompt="$1"
        local suffix
        [[ "$default" == y ]] && suffix="[Y/n]" || suffix="[y/N]"

        while true; do
            read -r -p "$prompt $suffix: " response
            [[ -z "$response" || "$response" =~ ^[ynYN]$ ]] && break
            warning "Please enter one of Y or N (case insensitive)."
        done
    }

    response=${response:-$default}
    [[ ${response,,} == "y" ]]
}

#-------------------------------------------------------------------------------
# Summary: Displays a prompt and asks the user to enter a value
# Parameters:
#   $1  'prompt' - the text of the prompt. It will be appended with
#       ' [<default>]: ' if the second parameter is non-empty; otherwise, just
#       ': '. If the third parameter is true, the default value will be masked
#       in the prompt as '••••••'.
#   $2  'default', string - the default value to output to stdout if the user
#       presses the [Enter] key without typing anything (optional if last,
#       default: '').
#   $3  'is_secret', boolean: suppresses echoing the input to the terminal. Use
#       for passwords, keys, etc. (optional if last, default false).
#   $4  'validation_function', string: the name of a validation function for
#       both: the default value (if provided) and for the user's input. It
#       should return 0 if the value is valid, or non-zero - if it is invalid.
#       The user will be re-prompted until a valid value is entered. (optional,
#       default: true, in effect - no validation, all values are accepted)
# Returns:
#   stdout: the entered value, or the default value, if the user entered nothing
#   Exit code: 0 if the input parameters are valid, 2 on invalid arguments
# Usage: value=$(enter_value <prompt> [default] [is_secret] [validate_fn])
# Example:
#   password=$(enter_value "Enter description (up to 350 characters)" "test" false validate_no_longer_than_350)
#   password=$(enter_value "Enter your password" "" true) && echo ""
# Note:
#     - If the environment variable 'quiet' is set to true, the function will
#       skip prompting and will immediately output the default value (or an
#       empty string if the default is not provided) to '/dev/stdout'.
#     - If the third parameter is true, the input will be marked in the prompt
#       as "••••••" (useful for secrets) and the terminal echo of the user input
#       will be suppressed. However, the actual input (or the default) will
#       still be output to stdout. After reading the input, a newline will NOT
#       be printed to the terminal and the caller should print one as in the
#       example above.
#-------------------------------------------------------------------------------
function enter_value()
{
    local -i rc="$success"

    (( $# >= 1 && $# <= 4 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() accepts from 1 to 4 arguments (provided $#):" \
                              "    1) a prompt" \
                              "    2) default value (optional if the rest are not specified, default: '')" \
                              "    3) boolean to suppress the echo of the input to the terminal (optional if the rest are not specified, default: false)" \
                              "    4) the name of a validation function (optional, default: true)."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local prompt=$1
    local default=${2:-''}
    local is_secret=${3:-false}
    local validate_fn=${4:-true}

    is_quiet &&
        echo "$default" &&
        return "$success"

    is_boolean "$is_secret" || {
        rc="$err_argument_type"
        error -ec "$rc" "The \$3 argument of ${FUNCNAME[0]}() (is_secret) must be a boolean value ('true' or 'false' -- provided '$1'), indicating whether the input is a secret that should not be echoed to the terminal."
    }
    [[ -z $default ]] || $validate_fn "$default" || {
        rc="$err_argument_value"
        error -ec "$rc" "The default value '$default' does not pass the validation function '$validate_fn'."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    if [[ -n $default ]]; then
        $is_secret && prompt="$prompt [$secret_str]: " || prompt="$prompt [$default]: "
    else
        prompt="$prompt: "
    fi

    local input
    local valid=false
    local errs
    errs=$(get_errors)

    local first_iter=true
    while ! $valid; do
        if $is_secret; then
            read -r -s -p "$prompt" input
        else
            read -r    -p "$prompt" input
        fi

        [[ -n "$input" ]] || input="$default"
        $validate_fn "$input" && valid=true || valid=false

        ! $valid && $is_secret && $first_iter && {
            # prefix the prompt with a newline to separate the new prompts with new lines in secret mode
            prompt=$'\n'"$prompt"
            first_iter=false
        }
    done

    # all good here! reset the global error counter back to the value it had before the loop with the validation function
    set_errors "$errs"
    echo "$input"
}

#-------------------------------------------------------------------------------
# Summary: Displays a prompt and list of options, asks user to choose one.
# Parameters:
#   1 - prompt - the prompt to display before options
#   2+ - options - two or more option texts (first option is default)
# Returns:
#   stdout: number of chosen option (1-based index)
#   Exit code: 0 on success, 2 on invalid arguments (less than 3 parameters)
# Env. Vars:
#   quiet - when true, assumes first option (default) without prompting
# Usage: selection=$(choose <prompt> <option1> <option2> [option3...])
# Example:
#   choice=$(choose "Select environment:" "Development" "Staging" "Production")
#   case $choice in
#     1) env="dev" ;;
#     2) env="staging" ;;
#     3) env="prod" ;;
#   esac
#-------------------------------------------------------------------------------
function choose()
{
    (( $# >= 3 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 3 or more arguments ($# provided): a prompt and at least two choices."
        return "$err_invalid_arguments";
    }

    is_quiet && {
        # just return the default choice (1)
        printf '1'
        return "$success"
    }

    # print the menu
    local prompt=$1; shift
    local options=("$@")

    echo "$prompt" >&2

    local -i opt_index
    local opt
    for (( opt_index=1; opt_index <= ${#options[@]}; opt_index++ )); do
        opt="${options[opt_index-1]}"
        (( opt_index == 1 )) &&
            echo "  $opt_index) $opt (default)" >&2 ||
            echo "  $opt_index) $opt" >&2
    done

    # read the choice
    local selection=1
    while true; do
        read -r -p "Enter choice [1-${#options[@]}]: " selection
        selection=${selection:-1}
        if ! is_natural "$selection"; then # it is not from this world;)
            warning "Invalid choice: $selection."
            continue
        fi
        (( selection == 0 )) && selection=1 && break
        (( selection >= 1 && selection <= ${#options[@]} )) && break
        warning "Invalid choice: $selection"
    done
    printf '%d' "$selection"

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Prints a sequence of quoted values with customizable quote, separator, and parentheses.
# Parameters:
#   Named parameters (must come before values):
#     --quote=<char>|-q=<char> - quote character (default: '). Use '' for no quotes
#     --separator=<char>|-s=<char> - separator (default: ,). Special: 'nl', 'tab', ''
#     --paren=<type>|-p=<type> - parentheses type: (), [], {}, nl, or none (default: none)
#     --json-array|--json|-j - shorthand for --quote='"' --separator=', ' --paren='[]'
#   Positional parameters:
#     1+ - values - values to include in sequence
# Returns:
#   stdout: formatted sequence
#   Exit code: 0 always
# Usage: print_sequence [--quote=<char>] [--separator=<char>] [--paren=<type>] <value1> [value2...]
# Example:
#   print_sequence --quote='"' --separator='; ' --paren='()' apple banana cherry
#   Output: ("apple"; "banana"; "cherry")
# Notes: Named parameters should not be placed last in the argument list.
#-------------------------------------------------------------------------------
function print_sequence()
{
    local open_paren=""
    local close_paren=""
    local quote="'"
    local separator=","
    for arg in "$@"; do
        case $arg in
            --json-array|--json|--jq-array|-j )
                quote='"'
                separator=", "
                open_paren="["
                close_paren="]"
                ;;
            --quote=*|-q=* )
                quote="${arg#*=}"
                ;;
            --separator=*|-s=* )
                separator="${arg#*=}"
                # Handle special values
                case "$separator" in
                    nl  ) separator=$'\n' ;;
                    tab ) separator=$'\t' ;;
                    *   ) ;;
                esac
                ;;
            --parenthesis=*|--paren=*|-p=* )
                local paren_val="${arg#*=}"
                case "$paren_val" in
                    \(|\)|\(\) ) # (|)|()
                        open_paren="("
                        close_paren=")"
                        ;;
                    \[|\]|\[\] ) # [|]|[]
                        open_paren="["
                        close_paren="]"
                        ;;
                    \{|\}|\{\} ) # {|}|{}
                        open_paren="{"
                        close_paren="}"
                        ;;
                    nl|$'\n'|'\n' )
                        # Handle special values
                        open_paren=$'\n'
                        close_paren=$'\n'
                        ;;
                    * )
                        warning "Unknown paren type: ${arg#*=}. Ignoring."
                        open_paren=""
                        close_paren=""
                        ;;
                esac
                ;;
            * ) ;;
        esac
    done

    [[ -n "$open_paren" ]] && printf "%s" "$open_paren" || true
    for arg in "$@"; do
        [[ "$arg" == -* || "$arg" == --* ]] && continue || true
        if [[ $arg != "${!#}" ]]; then
            printf "%s%s%s%s" "$quote" "$arg" "$quote" "$separator"
        else
            printf "%s%s%s" "$quote" "$arg" "$quote"
        fi
    done
    [[ -n "$close_paren" ]] && printf "%s" "$close_paren" || true
}
