# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# shellcheck disable=SC2154 # variable is referenced but not assigned.
if ! declare -pF "error" > "$_ignore"; then
    diag_dir="$(dirname "${BASH_SOURCE[0]}")"
    source "$diag_dir/_diagnostics.sh"
fi

#-------------------------------------------------------------------------------
# Summary: Tests if a variable is defined.
# Parameters:
#   1 - variable_name (nameref!) - name of the variable to test
# Returns:
#   Exit code: 0 if variable is defined, non-zero otherwise, 2 on invalid arguments
# Env. Vars:
#   _ignore - file to redirect unwanted output to
# Usage: if is_defined_variable <variable_name>; then ... fi
# Example: if is_defined_variable MY_VAR; then echo "MY_VAR is defined"; fi
#-------------------------------------------------------------------------------
function is_defined_variable()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one argument: the name of the variable to test."
        return 2
    fi
    declare -p "$1" > "$_ignore" 2>&1
}

#-------------------------------------------------------------------------------
# Summary: Tests if an array variable is defined.
# Parameters:
#   1 - variable_name (nameref!) - name of the array variable to test
# Returns:
#   Exit code: 0 if array variable is defined, non-zero otherwise, 2 on invalid arguments
# Env. Vars:
#   _ignore - file to redirect unwanted output to
# Usage: if is_defined_array <variable_name>; then ... fi
# Example: if is_defined_array MY_ARRAY; then echo "MY_ARRAY is defined"; fi
#-------------------------------------------------------------------------------
function is_defined_array()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one argument: the name of the array variable to test."
        return 2
    fi

    restoreShopt=$(shopt -p nocasematch)
    shopt -u nocasematch

    local decl ret=1

    if is_defined_variable "$1"; then
        decl=$(declare -p "$1" 2>"$_ignore")
        [[ $decl =~ ^declare\ -a ]] && ret=0
    fi

    eval "$restoreShopt" &> "$_ignore"
    return "$ret"
}

#-------------------------------------------------------------------------------
# Summary: Tests if an associative array variable is defined.
# Parameters:
#   1 - variable_name (nameref!) - name of the associative array variable to test
# Returns:
#   Exit code: 0 if associative array variable is defined, non-zero otherwise, 2 on invalid arguments
# Env. Vars:
#   _ignore - file to redirect unwanted output to
# Usage: if is_defined_associative_array <variable_name>; then ... fi
# Example: if is_defined_associative_array MY_ASSOC_ARRAY; then echo "MY_ASSOC_ARRAY is defined"; fi
#-------------------------------------------------------------------------------
function is_defined_associative_array()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one argument: the name of the associative array variable to test."
        return 2
    fi

    restoreShopt=$(shopt -p nocasematch)
    shopt -u nocasematch

    local decl ret=1

    if is_defined_variable "$1"; then
        decl=$(declare -p "$1" 2>"$_ignore")
        [[ $decl =~ ^declare\ -A ]] && ret=0
    fi

    eval "$restoreShopt" &> "$_ignore"
    return "$ret"
}

#-------------------------------------------------------------------------------
# Summary: Tests if a function is defined.
# Parameters:
#   1 - function_name (nameref!) - name of the function to test
# Returns:
#   Exit code: 0 if function is defined, non-zero otherwise, 2 on invalid arguments
# Env. Vars:
#   _ignore - file to redirect unwanted output to
# Usage: if is_defined_function <function_name>; then ... fi
# Example: if is_defined_function MY_FUNC; then echo "MY_FUNC is defined"; fi
#-------------------------------------------------------------------------------
function is_defined_function()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one argument: the name of the function to test."
        return 2
    fi
    declare -pF "$1" > "$_ignore" 2>&1
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid positive integer number (natural number: 1, 2, 3, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if positive integer, non-zero otherwise
# Usage: if is_positive <number>; then ... fi
# Example: if is_positive "$count"; then echo "Count is positive"; fi
#-------------------------------------------------------------------------------
function is_positive()
{
    [[ "$1" =~ ^[+]?[0-9]+$  && ! "$1" =~ ^[+]?0+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid non-negative integer (0, 1, 2, 3, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if non-negative integer, non-zero otherwise
# Usage: if is_non_negative <number>; then ... fi
# Example: if is_non_negative "$index"; then echo "Index is valid"; fi
#-------------------------------------------------------------------------------
function is_non_negative()
{
    [[ "$1" =~ ^[+]?[0-9]+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid non-positive integer (0, -1, -2, -3, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if non-positive integer, non-zero otherwise
# Usage: if is_non_positive <number>; then ... fi
# Example: if is_non_positive "$delta"; then echo "Delta is non-positive"; fi
#-------------------------------------------------------------------------------
function is_non_positive()
{
    [[ "$1" =~ ^-[0-9]+$ || "$1" =~ ^[-]?0+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid negative integer (-1, -2, -3, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if negative integer, non-zero otherwise
# Usage: if is_negative <number>; then ... fi
# Example: if is_negative "$offset"; then echo "Offset is negative"; fi
#-------------------------------------------------------------------------------
function is_negative()
{
    [[ $1 =~ ^-[0-9]+$ && ! "$1" =~ ^[-]?0+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid integer (..., -2, -1, 0, 1, 2, ...).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if integer, non-zero otherwise
# Usage: if is_integer <number>; then ... fi
# Example: if is_integer "$value"; then echo "Value is an integer"; fi
#-------------------------------------------------------------------------------
function is_integer()
{
    [[ "$1" =~ ^[-+]?[0-9]+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid decimal number (including integers and floating-point).
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if decimal number, non-zero otherwise
# Usage: if is_decimal <number>; then ... fi
# Example: if is_decimal "$price"; then echo "Price is valid"; fi
#-------------------------------------------------------------------------------
function is_decimal()
{
    [[ "$1" =~ ^[-+]?[0-9]*(\.[0-9]*)?$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the first parameter equals one of the following parameters.
# Parameters:
#   1 - value - value to search for
#   2+ - options - one or more valid options to compare against
# Returns:
#   Exit code: 0 if value found in options, 1 if not found, 2 on invalid arguments
# Usage: if is_in <value> <option1> [option2...]; then ... fi
# Example: if is_in "$color" "red" "green" "blue"; then echo "Valid color"; fi
#-------------------------------------------------------------------------------
function is_in()
{
    if [[ $# -lt 1 ]]; then
        error "${FUNCNAME[0]}() requires at least 1 argument: the value to test."
        return 2
    fi
    if [[ $# -eq 1 ]]; then
        # testing against an empty set of options is always false
        return 1
    fi

    local sought="$1"; shift
    local v
    for v in "$@"; do
        [[ "$sought" == "$v" ]] && return 0
    done
    return 1
}
