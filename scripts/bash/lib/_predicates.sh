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
declare -x __is_windows=""

#-------------------------------------------------------------------------------
# @description Tests if a variable is defined.
#
# @arg $1 string variable_name - name of the variable to test
#
# @exitcode 0 the variable is defined
# @exitcode 1 the variable is not defined
# @exitcode 2 invalid arguments ($err_invalid_arguments)
#
# @example
#   if is_defined_variable MY_VAR; then echo "MY_VAR is defined"; fi
#-------------------------------------------------------------------------------
function is_defined_variable()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the variable to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ -v "$1" ]] && declare -p "$1" &> "$_ignore"
}

#-------------------------------------------------------------------------------
# @description Tests if an indexed array variable is defined.
#
# @arg $1 string variable_name - name of the array variable to test
#
# @exitcode 0 ($positive) the array variable is defined
# @exitcode 1 ($negative) the array variable is not defined
# @exitcode 2 invalid arguments ($err_invalid_arguments)
#
# @example
#   if is_defined_array MY_ARRAY; then echo "MY_ARRAY is defined"; fi
#-------------------------------------------------------------------------------
function is_defined_array()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the variable to test."
    }
    [[ $# -ne 1 || $1 =~ $varNameRegex ]] || {
        rc="$err_invalid_nameref"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires a non-empty variable name as argument."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    restoreShopt=$(shopt -p nocasematch) || true
    shopt -u nocasematch # set case sensitive matching

    decl=$(declare -p "$1" 2>"$_ignore")
    [[ $decl =~ ^declare\ -a ]] && rc="$positive" || rc="$negative"

    eval "$restoreShopt" &> "$_ignore" || true # restore original shopt state

    return "$rc"
}

#-------------------------------------------------------------------------------
# @description Tests if an associative array variable is defined.
#
# @arg $1 string variable_name - name of the associative array variable to test
#
# @exitcode 0 ($positive) the associative array variable is defined
# @exitcode 1 ($negative) the associative array variable is not defined
# @exitcode 2 invalid arguments ($err_invalid_arguments)
#
# @example
#   if is_defined_associative_array MY_ASSOC_ARRAY; then echo "MY_ASSOC_ARRAY is defined"; fi
#-------------------------------------------------------------------------------
function is_defined_associative_array()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the associative array variable to test."
    }
    [[ $# -ne 1 || $1 =~ $varNameRegex ]] || {
        rc="$err_invalid_nameref"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires a non-empty variable name as argument."
    }

    (( rc == success )) || return "$err_invalid_arguments"

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
# @description Tests if a function is defined.
#
# @arg $1 string function_name - name of the function to test
#
# @exitcode 0 the function is defined
# @exitcode 1 the function is not defined
# @exitcode 2 invalid arguments ($err_invalid_arguments)
#
# @example
#   if is_defined_function MY_FUNC; then echo "MY_FUNC is defined"; fi
#-------------------------------------------------------------------------------
function is_defined_function()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the function to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    declare -pF "$1" > "$_ignore" 2>&1
}

#-------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid boolean - 'true' or 'false'.
#
# @arg $1 string boolean - string to test
#
# @exitcode 0 the string is 'true' or 'false'
# @exitcode 1 otherwise
#
# @example
#   if is_boolean "$flag"; then echo "flag is valid"; fi
#-------------------------------------------------------------------------------
function is_boolean()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ ^(true|false)$ ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid natural number (0, 1, 2, 3, ...) without a sign.
#
# @arg $1 string number - string to test
#
# @exitcode 0 the string is a natural number
# @exitcode 1 otherwise
#
# @example
#   if is_natural "$apples"; then echo "apples is valid"; fi
#-------------------------------------------------------------------------------
function is_natural()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ ^[0-9]+$ ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid positive integer (1, 2, 3, ...), with an optional leading '+'.
#
# @arg $1 string number - string to test
#
# @exitcode 0 the string is a positive integer
# @exitcode 1 otherwise
#
# @example
#   if is_positive "$count"; then echo "Count is positive"; fi
#-------------------------------------------------------------------------------
function is_positive()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ ^[+]?[0-9]+$  && ! "$1" =~ ^[+]?0+$ ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid non-negative integer (0, 1, 2, 3, ...), with an optional
# leading '+'.
#
# @arg $1 string number - string to test
#
# @exitcode 0 the string is a non-negative integer
# @exitcode 1 otherwise
#
# @example
#   if is_non_negative "$index"; then echo "Index is valid"; fi
#-------------------------------------------------------------------------------
function is_non_negative()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ ^[+]?[0-9]+$ ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid non-positive integer (0, -1, -2, -3, ...).
#
# @arg $1 string number - string to test
#
# @exitcode 0 the string is a non-positive integer
# @exitcode 1 otherwise
#
# @example
#   if is_non_positive "$delta"; then echo "Delta is non-positive"; fi
#-------------------------------------------------------------------------------
function is_non_positive()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ ^-[0-9]+$ || "$1" =~ ^[-]?0+$ ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid negative integer (-1, -2, -3, ...).
#
# @arg $1 string number - string to test
#
# @exitcode 0 the string is a negative integer
# @exitcode 1 otherwise
#
# @example
#   if is_negative "$offset"; then echo "Offset is negative"; fi
#-------------------------------------------------------------------------------
function is_negative()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ $1 =~ ^-[0-9]+$ && ! "$1" =~ ^[-]?0+$ ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid integer (..., -2, -1, 0, 1, 2, ...), with an optional leading
# sign.
#
# @arg $1 string number - string to test
#
# @exitcode 0 the string is an integer
# @exitcode 1 otherwise
#
# @example
#   if is_integer "$value"; then echo "Value is an integer"; fi
#-------------------------------------------------------------------------------
function is_integer()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ ^[-+]?[0-9]+$ ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid decimal number (including integers and floating-point), with an
# optional leading sign.
#
# Notes:
#   - The regex `^[-+]?[0-9]*(\.[0-9]*)?$` also accepts a lone sign, an empty string, or a lone '.', since all the
#     numeric parts are optional. Callers relying on strict numeric validity should be aware of these edge cases.
#
# @arg $1 string number - string to test
#
# @exitcode 0 the string matches the decimal-number pattern
# @exitcode 1 otherwise
#
# @example
#   if is_decimal "$price"; then echo "Price is valid"; fi
#-------------------------------------------------------------------------------
function is_decimal()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ ^[-+]?[0-9]*(\.[0-9]*)?$ ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the first parameter equals one of the following parameters.
#
# Notes:
#   - If no options are given (only $1 is provided), the test always fails ($negative) -- an empty option set never
#     contains the sought value.
#
# @arg $1 string value - value to search for
# @arg $@ string options - zero or more valid options to compare against
#
# @exitcode 0 ($positive) the value was found among the options
# @exitcode 1 ($negative) the value was not found (or no options were given)
# @exitcode 2 invalid arguments ($err_invalid_arguments) -- fewer than 1 argument was provided
#
# @example
#   if is_in "$color" "red" "green" "blue"; then echo "Valid color"; fi
#-------------------------------------------------------------------------------
function is_in()
{
    local -i rc="$success"

    (( $# >= 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires at least 1 argument: the value to test and zero or more options to compare against."
    }

    (( rc == success )) || return "$err_invalid_arguments"

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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ ^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$ ]]
}

#-------------------------------------------------------------------------------
# @description Detects if the current operating system is Windows (including Windows_NT, MINGW, and MSYS environments).
# The result is cached in the module-level variable $__is_windows after the first call.
#
# @exitcode 0 running on Windows
# @exitcode 1 otherwise
#
# @example
#   if is_windows; then echo "Running on Windows"; fi
#-------------------------------------------------------------------------------
function is_windows()
{
    if [[ -z "$__is_windows" ]]; then
        local os_name
        os_name="$(uname -s)" || true
        [[ "$os_name" == "Windows_NT" || "$os_name" == *MINGW* || "$os_name" == *MSYS* ]] && __is_windows="true" || __is_windows="false"
    fi

    $__is_windows;
}
