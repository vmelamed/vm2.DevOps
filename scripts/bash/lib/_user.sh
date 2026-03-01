# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed


# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# shellcheck disable=SC2154 # variable is referenced but not assigned.
if ! declare -pF "error" > "$_ignore"; then
    semver_dir="$(dirname "${BASH_SOURCE[0]}")"
    source "$semver_dir/_diagnostics.sh"
fi

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
    if [[ "$quiet" != true ]]; then
        read -n 1 -rsp 'Press any key to continue...' >&2
        echo
    fi
    return 0
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
    if [[ $# -eq 0 || $# -gt 2 || -z "$1" ]]; then
        error "${FUNCNAME[0]}() requires at least one parameter: the prompt and a second, optional parameter -default response."
        return 2
    fi

    local default
    [[ $# -eq 2 ]] && default=${2,,} || default="y"

    local response=$default
    if [[ "$quiet" != true ]]; then
        local prompt="$1"
        local suffix
        [[ "$default" == y ]] && suffix="[Y/n]" || suffix="[y/N]"

        while true; do
            read -rp "$prompt $suffix: " response
            [[ -z "$response" || "$response" =~ ^[ynYN]$ ]] && break
            warning "Please enter one of y/Y/n/N." >&2
        done
    fi
    response=${response:-$default}
    [[ ${response,,} == "y" ]]
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
    if [[ $# -lt 3 ]]; then
        error "${FUNCNAME[0]}() requires 3 or more arguments: a prompt and at least two choices." >&2;
        return 2;
    fi

    local -i selection=1

    if [[ "$quiet" != true ]]; then
        # print the menu
        local prompt=$1; shift
        local options=("$@")

        echo "$prompt" >&2

        local -i i=1
        for o in "${options[@]}"; do
            if [[ $i -eq 1 ]]; then
                echo "  $i) $o (default)" >&2
            else
                echo "  $i) $o" >&2
            fi
            i=$((i+1))
        done

        # read the choice
        while true; do
            read -rp "Enter choice [1-${#options[@]}]: " selection
            selection=${selection:-1}
            [[ $selection -eq 0 ]] && selection=1 # the default
            [[ $selection =~ ^[1-9][0-9]*$ && $selection -ge 1 && $selection -le ${#options[@]} ]] && break
            warning "Invalid choice: $selection" >&2
        done
    fi

    printf '%d' "$selection"
    return 0
}

#-------------------------------------------------------------------------------
# Summary: Prints a sequence of quoted values with customizable quote, separator, and parentheses.
# Parameters:
#   Named parameters (must come before values):
#     --quote=<char>|-q=<char> - quote character (default: '). Use '' for no quotes
#     --separator=<char>|-s=<char> - separator (default: ,). Special: 'nl', 'tab', ''
#     --paren=<type>|-p=<type> - parentheses type: (), [], {}, nl, or none (default: none)
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
            --quote=*|-q=* )
                quote="${arg#*=}"
                ;;
            --separator=*|-s=* )
                separator="${arg#*=}"
                # Handle special values
                case "$separator" in
                    nl) separator=$'\n' ;;
                    tab) separator=$'\t' ;;
                    * ) ;;
                esac
                ;;
            --parenthesis=*|--paren=*|-p=* )
                local paren_val="${arg#*=}"
                case "$paren_val" in
                    \(|\)|\(\) )
                        open_paren="("
                        close_paren=")"
                        ;;
                    \[|\]|\[\] )
                        open_paren="["
                        close_paren="]"
                        ;;
                    \{|\}|\{\} )
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
