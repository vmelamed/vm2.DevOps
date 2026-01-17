#!/bin/bash

if ! declare -pF "error" > /dev/null; then
    semver_dir="$(dirname "${BASH_SOURCE[0]}")"
    source "$semver_dir/_common.diagnostics.sh"
fi

## Displays a prompt, followed by "Press any key to continue..." and returns only after the script user
## presses a key. If there is defined variable $quiet with value "true", the function will not display prompt and will
## not wait for response.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function press_any_key() {
    if [[ "$quiet" != true ]]; then
        read -n 1 -rsp 'Press any key to continue...' >&2
        echo
    fi
    return 0
}

## Asks the script user to respond yes or no to some prompt. If there is a defined variable $quiet with
## value "true", the function will not display the prompt and will assume the default response or 'y'.
## Parameter 1 - the prompt to confirm.
## Parameter 2 - the default response if the user presses [Enter]. When specified should be either 'y' or 'n'. Optional.
## Outputs the result to stdout as 'y' or 'n'.
function confirm() {
    if [[ -z "$1" ]]; then
        error "The function confirm() requires at least one parameter: the prompt."
        exit 2
    fi
    if [[ -n "$2" && ! "$2" =~ ^[ynYN]$ ]]; then
        error "If a default response parameter is specified for the function confirm(), it must be either 'y' or 'n'"
        exit 2
    fi

    local default
    local prompt="$1"

    default=$(to_lower "${2:-y}")

    if [[ "$quiet" == true ]]; then
        printf '%s' "$default"
        return 0
    fi

    local suffix

    if [[ "$default" == y ]]; then
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi

    local response
    while true; do
        read -rp "$prompt $suffix: " response >&2
        response=${response:-$default}
        response=${response,,}
        if [[ "$response" =~ ^[yn]$ ]]; then
            printf '%s' "$response"
            return 0;
        fi
        error "Please enter y or n." >&2
        errors=$((errors - 1))
    done
}

## Displays a prompt and a list of options to the script user and asks them to choose one of the options.
## Parameter 1 - the prompt to display before the options
## Parameter 2 - the text of the first option
## Parameter 3 - the text of the second option.
## ... - etc.
## The first option is the default one.
## The result will be printed in stdout as the number of the chosen option.
## The function will exit with code 2 if less than 3 parameters are specified.
function choose() {
    if [[ $# -lt 3 ]]; then
        error "The function choose() requires 3 or more arguments: a prompt and at least two choices." >&2;
        return 2;
    fi

    local prompt=$1; shift
    local options=("$@")

    if [[ "$quiet" == true ]]; then
        printf '1'
        return 0
    fi

    echo "$prompt" >&2
    local -i i=1
    for o in "${options[@]}"; do
        if [[ $i -eq 1 ]]; then
            echo "  $i) $o (default)" >&2
        else
            echo "  $i) $o" >&2
        fi
        ((i++))
    done

    local -i selection=1
    while true; do
        read -rp "Enter choice [1-${#options[@]}]: " selection
        selection=${selection:-1}
        [[ $selection = 0 ]] && selection=1
        if [[ $selection =~ ^[1-9][0-9]*$ && $selection -ge 1 && $selection -le ${#options[@]} ]]; then
            printf '%d' "$selection"
            return 0
        fi
        error "Invalid choice: $selection" >&2
    done
    return 0
}
