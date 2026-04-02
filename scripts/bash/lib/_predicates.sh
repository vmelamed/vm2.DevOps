# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines predicate functions for testing the existence and type of variables.
# It includes functions for checking if a variable, array, or associative array is defined.
# Includes a function (is_in) for testing if a the value of a variable is included in a set of values, e.g. array.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_PREDICATES_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_PREDICATES_SH_LOADED=1

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_invalid_nameref

declare -rx varNameRegex

declare -x _ignore

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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the variable to test."
        return "$err_invalid_arguments"
    }

    [[ -v "$1" ]] && declare -p "$1" &> "$_ignore"
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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the variable to test."
        return "$err_invalid_arguments"
    }
    [[ $1 =~ $varNameRegex ]] || {
        error 3 "${FUNCNAME[0]}() requires a non-empty variable name as argument."
        return "$err_invalid_nameref"
    }

    restoreShopt=$(shopt -p nocasematch) || true
    shopt -u nocasematch # set case sensitive matching

    local decl rc="$negative"

    decl=$(declare -p "$1" 2>"$_ignore") &&
        [[ $decl =~ ^declare\ -a ]] &&
            rc="$positive"

    eval "$restoreShopt" &> "$_ignore" || true # restore original shopt state
    return "$rc"
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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the associative array variable to test."
        return "$err_invalid_arguments"
    }
     [[ $1 =~ $varNameRegex ]] || {
        error 3 "${FUNCNAME[0]}() requires a non-empty variable name as argument."
        return "$err_invalid_nameref"
    }

    restoreShopt=$(shopt -p nocasematch) || true
    shopt -u nocasematch # set case sensitive matching

    local decl
    local rc="$negative"

    decl=$(declare -p "$1" 2>"$_ignore") &&
        [[ $decl =~ ^declare\ -A ]] &&
            rc="$positive"

    eval "$restoreShopt" &> "$_ignore" || true # restore original shopt state
    return "$rc"
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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the function to test."
        return "$err_invalid_arguments"
    }

    declare -pF "$1" > "$_ignore" 2>&1
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid boolean - 'true' or 'false'
# Parameters:
#   1 - boolean - string to test
# Returns:
#   Exit code: 0 if boolean, non-zero otherwise
# Usage: if is_boolean <var>; then ... fi
# Example: if is_natural "$apples"; then echo "apples is valid"; fi
#-------------------------------------------------------------------------------
function is_boolean()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ ^(true|false)$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid natural number (0, 1, 2, 3, ...) without a sign.
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if natural, non-zero otherwise
# Usage: if is_natural <number>; then ... fi
# Example: if is_natural "$apples"; then echo "apples is valid"; fi
#-------------------------------------------------------------------------------
function is_natural()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ ^[0-9]+$ ]]
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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ ^[+]?[0-9]+$  && ! "$1" =~ ^[+]?0+$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter represents a valid non-negative integer (0, 1, 2, 3, ...) - the same as is_natural().
# Parameters:
#   1 - number - string to test
# Returns:
#   Exit code: 0 if non-negative integer, non-zero otherwise
# Usage: if is_non_negative <number>; then ... fi
# Example: if is_non_negative "$index"; then echo "Index is valid"; fi
#-------------------------------------------------------------------------------
function is_non_negative()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

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
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

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
    (( $# >= 1 )) || {
        error 3 "${FUNCNAME[0]}() requires at least 1 argument: the value to test and zero or more options to compare against."
        return "$err_invalid_arguments"
    }

    # testing against an empty set of options is always false
    (( $# == 1 )) && return "$negative"

    local sought="$1"; shift
    local v

    for v in "$@"; do
        [[ "$sought" == "$v" ]] && return "$positive"
    done

    return "$negative"
}

function is_base64()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ ^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$ ]]
}
