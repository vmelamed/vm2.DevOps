#!/bin/bash

## Shell function to test if a variable is defined.
## Usage: is_defined <variable_name>
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function is_defined() {
    if [[ $# -ne 1 ]]; then
        echo "The function is_defined() requires exactly one argument: the name of the variable to test." >&2
        return 2
    fi
    declare -p "$1" >"$_ignore" 2>&1
}

## Tests if the parameter represents a valid positive, integer number (aka natural number): {1, 2, 3, ...}
## Usage: is_positive <number>
function is_positive() {
    [[ "$1" =~ ^[+]?[0-9]+$  && ! "$1" =~ ^[+]?0+$ ]]
}

## Tests if the parameter represents a valid non-negative integer number: {0, +0, 1, 2, 3, ...}
## Usage: is_non_negative <number>
function is_non_negative() {
    [[ "$1" =~ ^[+]?[0-9]+$ ]]
}

## Tests if the parameter represents a valid non-positive integer number: {0, -0, -1, -2, -3, ...}
## Usage: is_non_positive <number>
function is_non_positive() {
    [[ "$1" =~ ^-[0-9]+$ || "$1" =~ ^[-]?0+$ ]]
}

## Tests if the parameter represents a valid negative integer number: {-1, -2, -3, ...}
## Usage: is_negative <number>
function is_negative() {
    [[ $1 =~ ^-[0-9]+$ && ! "$1" =~ ^[-]?0+$ ]]
}

## Tests if the parameter represents a valid integer number: {..., -2, -1, 0, 1, 2, ...}
## Usage: is_integer <number>
function is_integer() {
    [[ "$1" =~ ^[-+]?[0-9]+$ ]]
}

## Tests if the parameter represents a valid decimal number
## Usage: is_decimal <number>
function is_decimal() {
    [[ "$1" =~ ^[-+]?[0-9]*(\.[0-9]*)?$ ]]
}

## Tests if the first parameter is equal to one of the following parameters.
## Usage: is_in <value> <option1> [<option2> ...]
function is_in() {
    if [[ $# -lt 2 ]]; then
        error "The function is_in() requires at least 2 arguments: the value to test and at least one valid option."
        return 2
    fi

    local sought="$1"; shift
    local v
    for v in "$@"; do
        [[ "$sought" == "$v" ]] && return 0
    done
    return 1
}

## Tests the error counter to determine if there are any accumulated errors so far
## Usage: has_errors [<flag>]. The flag is optional and doesn't matter what it is - if it is passed, the method calls `exit 2`.
## Return: If it didn't exit, returns 1 if there are errors, 0 otherwise.
function has_errors()
{
    if ((errors > 0)); then
        echo "❌  ERROR: $errors error(s) encountered. Please fix the issues and try again." >&2
        if [[ -n $1 ]]; then
            usage
            exit 2
        fi
        return 1
    fi
    return 0
}

## Exits the script if there are any accumulated errors so far.
function exit_if_has_errors()
{
    has_errors 2
}
