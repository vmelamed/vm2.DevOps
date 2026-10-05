# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#---------------------------------------------------------------------------------------------
# This script defines predicate functions for testing the existence and type of variables.
# It includes functions for checking if a variable, array, or associative array is defined.
# Includes a function (is_in) for testing if a the value of a variable is included in a set of
# values, e.g. array.
#---------------------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_PREDICATES_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_PREDICATES_SH_LOADED=1

declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_invalid_path

declare -x _ignore

#---------------------------------------------------------------------------------------------
# @description Checks if the shell is case-sensitive.
#
# @exitcode positive=0: The shell is case-sensitive.
# @exitcode negative=1: The shell is case-insensitive.
#---------------------------------------------------------------------------------------------
function is_case_sensitive()
{
    shopt -q nocasematch && return "$negative" || return "$positive"
}

#---------------------------------------------------------------------------------------------
# @description Sets the shell to case-insensitive mode.
#
# @exitcode success=0: Always.
#---------------------------------------------------------------------------------------------
function set_case_insensitive()
{
    shopt -s nocasematch || true
}

#---------------------------------------------------------------------------------------------
# @description Sets the shell to case-sensitive mode.
#
# @exitcode success=0: Always.
#---------------------------------------------------------------------------------------------
function set_case_sensitive()
{
    shopt -u nocasematch || true
}

#---------------------------------------------------------------------------------------------
# @description Sets the shell's match case sensitivity option based on the provided argument.
#   Returns the previous state of the case sensitivity.
#
# @arg $1 boolean _new_case_sensitive - the desired new state for the shell's case sensitivity
#   (true for case-sensitive mode, false - for case-insensitive). Optional, default is true.
#
# @exitcode positive=0: previously the shell matching was case sensitive
# @exitcode negative=1: previously the shell matching was case insensitive
#
# @example
#
#   # Set the shell nocasematch option to off and save the previous state in _old_case_sensitive
#   declare _old_case_sensitive
#   set_case_sensitivity && _old_case_sensitive=true || _old_case_sensitive=false
#
#   # Restore the previous state of the nocasematch option.
#   set_case_sensitivity "$_old_case_sensitive"
#---------------------------------------------------------------------------------------------
function set_case_sensitivity()
{
    (( $# <= 1 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at most one argument (provided $#): the desired new state for the shell's case sensitivity."
    [[ ! -v 1 ]] || is_boolean "$1" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires a boolean argument (provided '$1'): the desired new state for the shell's case sensitivity."
    exit_if_has_bugs

    local _new_case_sensitive=${1:-true}
    local _old_case_sensitive

    is_case_sensitive && _old_case_sensitive=true || _old_case_sensitive=false

    if [[ $_new_case_sensitive != "$_old_case_sensitive" ]]; then
        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        $_new_case_sensitive && set_case_sensitive || set_case_insensitive
    fi

    $_old_case_sensitive && return "$positive" || return "$negative"
}

declare -xr varNameRegex="^[A-Za-z_][A-Za-z0-9_]*$"
#---------------------------------------------------------------------------------------------
# @description Tests if a string is a valid variable name.
#
# @arg $1 string variable_name - the name of the variable to test
#
# @exitcode positive=0: the string is a valid variable name
# @exitcode negative=1: otherwise
#
# @example
#   if is_variable_name "MY_VAR"; then echo "Valid variable name"; fi
#---------------------------------------------------------------------------------------------
function is_variable_name()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the variable to test."
    exit_if_has_bugs

    [[ $1 =~ $varNameRegex ]]
}

#---------------------------------------------------------------------------------------------
# @description Tests if a variable is defined.
#
# @arg $1 string variable_name - name of the variable to test
#
# @exitcode positive=0: the variable is defined
# @exitcode negative=1: otherwise
#
# @example
#   if is_variable MY_VAR; then echo "MY_VAR is defined"; fi
#---------------------------------------------------------------------------------------------
function is_variable()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the variable to test."
    exit_if_has_bugs

    is_variable_name "$1" && declare -p "$1" &> "$_ignore"
}

#---------------------------------------------------------------------------------------------
# @description Tests if a variable is defined and if it is an indexed array.
#
# @arg $1 string variable_name - name of the array variable to test
#
# @exitcode positive=0: the strings is the name of a defined indexed array variable
# @exitcode negative=1: otherwise
#
# @example
#   declare -a MY_ARRAY=(aaa bbb ccc)
#   if is_indexed_array MY_ARRAY; then echo "MY_ARRAY is defined"; fi
#---------------------------------------------------------------------------------------------
function is_indexed_array()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the indexed array variable to test."
    exit_if_has_bugs

    is_variable_name "$1" ||
        return "$negative"

    declare _old_case_sensitive
    set_case_sensitivity true && _old_case_sensitive=true || _old_case_sensitive=false

    local -i _rc="$positive"
    local _decl

    _decl=$(declare -p "$1" 2>"$_ignore") &&
    [[ $_decl =~ ^declare\ -a ]] ||
        _rc="$negative"

    # Restore the previous state of the nocasematch option.
    set_case_sensitivity "$_old_case_sensitive"

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Tests if a variable is defined and if it is an associative array.
#
# @arg $1 string variable_name - name of the array variable to test
#
# @exitcode positive=0: the strings is the name of a defined associative array variable
# @exitcode negative=1: otherwise
#
# @example
#   declare -A MY_ARRAY=([aaa]=aaa [bbb]=bbb [ccc]=ccc)
#   if is_associative_array MY_ARRAY; then echo "MY_ARRAY is defined"; fi
#---------------------------------------------------------------------------------------------
function is_associative_array()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the indexed array variable to test."
    exit_if_has_bugs

    is_variable_name "$1" ||
        return "$negative"

    declare _old_case_sensitive
    set_case_sensitivity true && _old_case_sensitive=true || _old_case_sensitive=false

    local -i _rc="$positive"
    local _decl

    _decl=$(declare -p "$1" 2>"$_ignore") &&
    [[ $_decl =~ ^declare\ -A ]] ||
        _rc="$negative"

    # Restore the previous state of the nocasematch option.
    set_case_sensitivity "$_old_case_sensitive"

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Tests if a variable is defined and if it is an indexed or an associative array.
#
# @arg $1 string variable_name - name of the array variable to test
#
# @exitcode positive=0: the strings is the name of a defined indexed or an associative array variable
# @exitcode negative=1: otherwise
#
# @example
#   declare -A MY_ASSOC_ARRAY=([aaa]=aaa [bbb]=bbb [ccc]=ccc)
#   declare -a MY_INDEXED_ARRAY=(aaa bbb ccc)
#   if is_array MY_ASSOC_ARRAY; then echo "MY_ASSOC_ARRAY is defined"; fi
#   if is_array MY_INDEXED_ARRAY; then echo "MY_INDEXED_ARRAY is defined"; fi
#---------------------------------------------------------------------------------------------
function is_array()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the array variable to test."
    exit_if_has_bugs

    is_variable_name "$1" ||
        return "$negative"

    declare _old_case_sensitive
    set_case_sensitivity false && _old_case_sensitive=true || _old_case_sensitive=false

    local -i _rc="$positive"
    local _decl

    _decl=$(declare -p "$1" 2>"$_ignore") &&
    [[ $_decl =~ ^declare\ -a ]] || # -a or -A case insensitive!
        _rc="$negative"

    # Restore the previous state of the nocasematch option.
    set_case_sensitivity "$_old_case_sensitive"

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Tests if an array (indexed or associative) is empty.
#
# @arg $1 string array_name - name of the array variable to test
#
# @exitcode positive=0: the array is empty
# @exitcode negative=1: otherwise
#
# @example
#   if is_empty_array MY_ARRAY; then echo "MY_ARRAY is empty"; fi
#---------------------------------------------------------------------------------------------
function is_empty_array()
{

    (( $# == 1 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the array variable to test."
    [[ ! -v 1 ]] || is_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to be the name of an indexed or an associative array variable (provided '${1:-<none>}')."
    exit_if_has_bugs

    local -n _array="$1"

    (( ${#_array[@]} == 0 ))
}

#---------------------------------------------------------------------------------------------
# @description Tests if a function is defined.
#
# @arg $1 string name of the function to test
#
# @exitcode positive=0: the function is defined
# @exitcode negative=1: otherwise
#
# @example
#   if is_function MY_FUNC; then echo "MY_FUNC is defined"; fi
#---------------------------------------------------------------------------------------------
function is_function()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name to test."
    exit_if_has_bugs

    is_variable_name "$1" ||
        return "$negative"

    declare -pF "$1" > "$_ignore" 2>&1
}

#---------------------------------------------------------------------------------------------
# @description Tests if the string matches the provided regular expression.
#   For internal use only!
#
# @arg $1 string value - the string to test
# @arg $2 string regex - the regular expression to match against
#
# @exitcode positive=0: the string $1 matches the regex $2
# @exitcode negative=1: otherwise
#---------------------------------------------------------------------------------------------
function __test_with_regex()
{
    (( $# == 2 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[1]}() requires exactly one argument (provided $(($#-1))): the value to test."
    exit_if_has_bugs

    [[  $1 =~ $2 ]]
}

declare -x zero_rex='[+-]?0+'
declare -x natural_rex='[0-9]*[1-9][0-9]*'
declare -x positive_rex="[+]?$natural_rex"
declare -x negative_rex="-$natural_rex"
declare -x integer_rex='[+-]?[0-9]+'
declare -x decimal_rex="$integer_rex(\.[0-9]*)?|(($integer_rex)?\.[0-9]+)"
declare -x bool_rex='(true|false)'
declare -x base64_char_rex='[A-Za-z0-9+/]'

declare -x natural_regex="^$natural_rex\$"
declare -x zero_regex="^$zero_rex\$"
declare -x positive_regex="^$positive_rex\$"
declare -x negative_regex="^$negative_rex\$"
declare -x non_negative_regex="^($positive_rex|$zero_rex)\$"
declare -x non_positive_regex="^($negative_rex|$zero_rex)\$"
declare -x integer_regex="^$integer_rex\$"
declare -x decimal_regex="^($decimal_rex)\$"
declare -x bool_regex="^$bool_rex\$"
declare -x dotnet_version_rex='([0-9]+\.[0-9]+\.[0-9]+)|([0-9]+\.[0-9]+(\.x)?)|([0-9]+(\.x)?)|([0-9]+\.[0-9]+\.[0-9]+x)|latest'
declare -x dotnet_version_regex="^$dotnet_version_rex\$"

declare -xr base64_regex="^($base64_char_rex{4})*($base64_char_rex{3}=|$base64_char_rex{2}==)?\$"

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid boolean value - 'true' or 'false'.
#
# @arg $1 string boolean - string to test
#
# @exitcode positive=0: the string is either 'true', or 'false'
# @exitcode negative=1: otherwise
#
# @example
#   if is_boolean "$flag"; then echo "flag is valid"; fi
#---------------------------------------------------------------------------------------------
function is_boolean()
{
    __test_with_regex "$@" "$bool_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid natural number (1, 2, 3, ...)
#   without a sign.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a natural number
# @exitcode negative=1: otherwise
#
# @example
#   if is_natural "$apples"; then echo "apples is valid"; fi
#---------------------------------------------------------------------------------------------
function is_natural()
{
    __test_with_regex "$@" "$natural_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid non-negative integer (0, 1, 2, 3,
#   ...), with an optional leading '+'.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a non-negative integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_non_negative "$index"; then echo "Index is valid"; fi
#---------------------------------------------------------------------------------------------
function is_non_negative()
{
    __test_with_regex "$@" "$non_negative_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid exit code (0, 1, 2, 3, ..., 255)
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a valid exit code number
# @exitcode negative=1: otherwise
#
# @example
#   if is_natural "$apples"; then echo "apples is valid"; fi
#---------------------------------------------------------------------------------------------
function is_exit_code()
{
    is_non_negative "$1" && (( "$1" <= 255 ))
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid positive integer (1, 2, 3, ...), with
#   an optional leading '+'.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a positive integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_positive "$count"; then echo "Count is positive"; fi
#---------------------------------------------------------------------------------------------
function is_positive()
{
    __test_with_regex "$@" "$positive_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid non-positive integer (0, -1, -2, -3,
#   ...).
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a non-positive integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_non_positive "$delta"; then echo "Delta is non-positive"; fi
#---------------------------------------------------------------------------------------------
function is_non_positive()
{
    __test_with_regex "$@" "$non_positive_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid negative integer (-1, -2, -3, ...).
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a negative integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_negative "$offset"; then echo "Offset is negative"; fi
#---------------------------------------------------------------------------------------------
function is_negative()
{
    __test_with_regex "$@" "$negative_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid integer (..., -2, -1, 0, 1, 2, ...),
#   with an optional leading sign.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is an integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_integer "$value"; then echo "Value is an integer"; fi
#---------------------------------------------------------------------------------------------
function is_integer()
{
    __test_with_regex "$@" "$integer_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid decimal number (including integers
#   and floating-point), with an optional leading sign.
#
# Notes:
#   - The regex `^[-+]?[0-9]*(\.[0-9]*)?$` also accepts a lone sign, an empty string, or a
#     lone '.', since all the numeric parts are optional. Callers relying on strict numeric
#     validity should be aware of these edge cases.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string matches the decimal-number pattern
# @exitcode negative=1: otherwise
#
# @example
#   if is_decimal "$price"; then echo "Price is valid"; fi
#---------------------------------------------------------------------------------------------
function is_decimal()
{
    __test_with_regex "$@" "$decimal_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the first parameter is a valid Base64 encoded string.
#
# @arg $1 string value - the value to test
#
# @exitcode positive=0: the value is a valid Base64 encoded string
# @exitcode negative=1: the value is not a valid Base64 encoded string
#
# @example
#   if is_base64 "$encoded_string"; then echo "Valid Base64"; fi
#---------------------------------------------------------------------------------------------
function is_base64()
{
    __test_with_regex "$@" "$base64_regex"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the first parameter equals one of the following parameters.
#
# @arg $1 string value - value to search for
# @arg $@ string options - zero or more valid options to compare against
#
# @exitcode positive=0: the value was found among the options
# @exitcode negative=1: otherwise
#
# @example
#   if is_in "$color" "red" "green" "blue"; then echo "Valid color"; fi
#---------------------------------------------------------------------------------------------
function is_in()
{
    (( $# > 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires more than 1 arguments:" \
                                                        "  - the value to test" \
                                                        "  - options to compare against"
    exit_if_has_bugs

    local _sought="$1"; shift
    local _v

    for _v in "$@"; do
        [[ $_sought == "$_v" ]] &&
            return "$positive"
    done
    return "$negative"
}

declare -x __os_name
__os_name="$(uname -s)"
declare -xr __os_name

declare -x __is_windows
[[ "$__os_name" == "Windows_NT" || "$__os_name" == *MINGW* || "$__os_name" == *MSYS* ]] && __is_windows=true || __is_windows=false
declare -xr __is_windows

#---------------------------------------------------------------------------------------------
# @description Detects if the current operating system is Windows (including Windows_NT,
#   MINGW, and MSYS environments).
#
# @noargs
#
# @exitcode positive=0: running on Windows
# @exitcode negative=1: otherwise
#
# @example
#   if is_windows; then echo "Running on Windows"; fi
#---------------------------------------------------------------------------------------------
function is_windows()
{
   $__is_windows
}

#---------------------------------------------------------------------------------------------
# @description Detects if the given string is a valid filename (not empty, not containing
#   slashes, and not "." or "..").
#
# @arg $1 string name - the filename to test
#
# @exitcode positive=0: the filename is valid
# @exitcode negative=1: otherwise
#
# @example
#   if is_valid_filename "$filename"; then echo "Valid filename"; fi
#---------------------------------------------------------------------------------------------
function is_valid_filename()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    exit_if_has_bugs

    [[ -n $1 && $1 != */* && $1 != . && $1 != .. ]]
}

#---------------------------------------------------------------------------------------------
# @description Detects if the given string is a valid path (not empty and passing pathchk).
#
# @arg $1 string name - the path to test
#
# @exitcode positive=0: the path is valid
# @exitcode negative=1: otherwise
#
# @example
#   if is_valid_path "$path"; then echo "Valid path"; fi
#---------------------------------------------------------------------------------------------
function is_valid_path()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test."
    exit_if_has_bugs

    pathchk -- "$1" &> "$_ignore"
}

#---------------------------------------------------------------------------------------------
# @description Checks whether a candidate secret name is valid: contains only alphanumeric
#   characters and underscores, start with a letter or underscore, and does not start with
#   'GITHUB_'.
#
# @arg $1 string Candidate secret name to validate.
#
# @exitcode positive=0: The secret name is valid.
# @exitcode negative=1: The secret name is not valid.
#   character.
#---------------------------------------------------------------------------------------------
function is_valid_secret_name()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the GitHub secret name to test."
    exit_if_has_bugs

    is_variable_name "$1" && [[ $1 != GITHUB_* ]]
}

#---------------------------------------------------------------------------------------------
# @description Checks whether a candidate secret value is safe to send to the GitHub API --
# i.e. it contains no control characters.
#
# @arg $1 string Candidate secret value to validate.
#
# @exitcode positive=0: The value contains no control characters.
# @exitcode negative=1: otherwise
#---------------------------------------------------------------------------------------------
function is_valid_secret()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the secret value to validate."
    exit_if_has_bugs

    [[ -n $1 && ! $1 =~ [[:cntrl:]] ]]
}

#---------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid .NET SDK version specifier, e.g. a
#   full version (`10.0.100`), a major.minor with optional feature-band wildcard (`10.0`,
#   `10.0.1xx`), a bare major (`10`), or the literal `latest`.
#
# @arg $1 string version - string to test
#
# @exitcode positive=0: the string is a valid .NET SDK version specifier
# @exitcode negative=1: otherwise
#
# @example
#   if is_valid_dotnet_version "$dotnet_version"; then echo "Valid"; fi
#---------------------------------------------------------------------------------------------
function is_valid_dotnet_version()
{
    __test_with_regex "$@" "$dotnet_version_regex"
}

#---------------------------------------------------------------------------------------------
# @description Checks if a given tool is available on the `$PATH`.
#
# @arg $1 string Name of the tool to check.
#
# @exitcode positive=0: The tool is present.
# @exitcode negative=1: The tool is not present.
#---------------------------------------------------------------------------------------------
function is_tool_present()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the name of the tool to check"
    exit_if_has_bugs

    command -v -p "$1" &>"$_ignore" || which "$1" &>"$_ignore"
}

#---------------------------------------------------------------------------------------------
# @description Checks if a given string is valid JSON.
#
# @arg $1 string The JSON string to validate.
#
# @exitcode positive=0: The string is valid JSON.
# @exitcode negative=1: The string is not valid JSON.
#---------------------------------------------------------------------------------------------
function is_valid_json()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the JSON string to validate."
    exit_if_has_bugs

    jq empty <<< "$1" &> "$_ignore" && return "$positive" || return "$negative"
}

#---------------------------------------------------------------------------------------------
# @description Checks if the file at a given path contains valid JSON.
#
# @arg $1 string Path to the file to validate.
#
# @exitcode positive=0: The file contains valid JSON.
# @exitcode negative=1: The file does not contain valid JSON.
#---------------------------------------------------------------------------------------------
function is_valid_json_file()
{
    (( $# == 1 ))                      || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the JSON string to validate."
    [[ ! -v 1 ]] || is_valid_path "$1" || bug -ec "$err_invalid_path" "${FUNCNAME[0]}() requires argument 1 to be a valid path (provided '${1:-<none>}')."
    exit_if_has_bugs

    jq empty "$1" &> "$_ignore" && return "$positive" || return "$negative"
}
