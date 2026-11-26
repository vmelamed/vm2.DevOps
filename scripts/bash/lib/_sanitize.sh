# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_SANITIZE_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_SANITIZE_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_invalid_nameref
declare -x err_argument_type
declare -x err_argument_value
declare -x err_not_found
declare -x err_not_file
declare -x err_not_directory
declare -x err_unsafe_argument
declare -x err_invalid_path
declare -x err_non_existent_path
declare -x err_missing_argument
declare -x err_invalid_json
declare -x err_invalid_json_array
declare -x err_logic_error

# vm2 core lib constants
declare -rx dangerous_chars_regex=$'[;|&$`<>(){}\n\r]'
declare -rx dangerous_chars_and_whitespaces_regex='[;|&$`<>(){}[:space:]]'

# vm2 core lib variables
declare -x noise_sink

#-----------------------------------------------------------------------------------------------
# @description Trims leading whitespace from a string.
#
# @arg $1 string The string to trim.
#
# @exitcode success=0: The trimmed string was printed (always, once past the argument
#   validation gate).
#
# @stdout The string with leading whitespace removed.
#
# @example
#   trimmed=$(ltrim "  some string  ")
#-----------------------------------------------------------------------------------------------
function ltrim()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the value to trim the leading spaces of." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    printf '%s' "${1#"${1%%[![:space:]]*}"}"
}

#-----------------------------------------------------------------------------------------------
# @description Trims leading whitespaces from the value of a string variable.
#
# @arg $1 nameref to a string variable to trim.
#
# @exitcode success=0: The variable was trimmed in place (always, once past the argument
#   validation gate).
#
# @example
#   declare var="  some string  "
#   ltrim_var var
#-----------------------------------------------------------------------------------------------
function ltrim_var()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of the variable to trim the leading spaces of." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to be the name of a variable (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -n __var="$1"

    __var="${__var#"${__var%%[![:space:]]*}"}"
}

#-----------------------------------------------------------------------------------------------
# @description Trims trailing whitespace from a string.
#
# @arg $1 string The string to trim.
#
# @exitcode success=0: The trimmed string was printed (always, once past the argument
#   validation gate).
#
# @stdout The string with trailing whitespace removed.
#
# @example
#   trimmed=$(rtrim "  some string  ")
#-----------------------------------------------------------------------------------------------
function rtrim()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the value to trim the trailing spaces of." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    printf '%s' "${1%"${1##*[![:space:]]}"}"
}

#-----------------------------------------------------------------------------------------------
# @description Trims trailing whitespaces from the value of a string variable.
#
# @arg $1 nameref to a string variable to trim.
#
# @exitcode success=0: The variable was trimmed in place (always, once past the argument
#   validation gate).
#
# @example
#   var="  some string  "
#   rtrim_var var
#-----------------------------------------------------------------------------------------------
function rtrim_var()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of the variable to trim the trailing spaces of." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to be the name of a variable (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -n __var="$1"

    __var="${__var%"${__var##*[![:space:]]}"}"
}

#-----------------------------------------------------------------------------------------------
# @description Trims leading and trailing whitespace from a string.
#
# @arg $1 string The string to trim.
#
# @exitcode success=0: The trimmed string was printed (always, once past the argument
#   validation gate).
#
# @stdout The string with leading and trailing whitespace removed.
#
# @example
#   trimmed=$(trim "  some string  ")
#-----------------------------------------------------------------------------------------------
function trim()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the value to trim the leading and trailing spaces of." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _value=$1

    _value="${_value#"${_value%%[![:space:]]*}"}"
    _value="${_value%"${_value##*[![:space:]]}"}"

    printf '%s' "$_value"
}

#-----------------------------------------------------------------------------------------------
# @description Trims leading and trailing whitespaces from the value of a string variable.
#
# @arg $1 nameref to a string variable to trim.
#
# @exitcode success=0: The variable was trimmed in place (always, once past the argument
#   validation gate).
#
# @example
#   var="  some string  "
#   trim var
#-----------------------------------------------------------------------------------------------
function trim_var()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of the variable to trim the leading and trailing spaces of." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to be the name of a variable (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -n __var="$1"

    __var="${__var#"${__var%%[![:space:]]*}"}"
    __var="${__var%"${__var##*[![:space:]]}"}"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if user input is safe by checking for potentially dangerous characters.
#   If the input is unsafe, prints an error message.
#
# Notes:
#   - Rejects characters that could enable command injection: `; | & $ \` \ < >
#     ( ) { }`, newlines, and carriage returns.
#   - Rejects spaces unless specified otherwise with $2
#   - An empty input is considered safe.
#
# @arg $1 string The input string to test.
# @arg $2 bool If true, allows spaces in the input (optional, default: false).
#
# @exitcode success=0: If the input is safe.
# @exitcode err_unsafe_argument=11: An argument value is unsafe to use.
#
# @example
#   if is_safe_input "$user_input" true; then echo "Safe input"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_input()
{
    (( $# == 1 || $# == 2 ))                                                    || bug "${FUNCNAME[0]}() requires 1 or 2 arguments (provided $#):" \
                                                                                       "  - the input string to sanitize" \
                                                                                       "  - an optional flag to allow spaces" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 2 ]] || is_boolean "$2"                                             || bug "${FUNCNAME[0]}() requires argument 2 to be a valid boolean (provided '${2-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs

    local -i _rc="$success"
    local _input="$1"

    # Empty input is considered safe
    [[ -z "$_input" ]] && return "$success"

    local _allow_spaces="${2:-false}"

    # Dangerous characters that could enable command injection
    local _dangerous_chars

    $_allow_spaces &&
        _dangerous_chars=$dangerous_chars_regex ||
        _dangerous_chars=$dangerous_chars_and_whitespaces_regex

    [[ ! "$_input" =~ $_dangerous_chars ]]                                      || with_error _rc "$err_unsafe_argument" "Invalid input '$_input': it contains one or more of the unsafe characters '$_dangerous_chars'."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that the input is a boolean value (`true` or `false`).
#   If the input is not a valid boolean, prints an error message.
#
# @arg $1 string The input string to test.
#
# @exitcode positive=0: If the input is a valid boolean.
# @exitcode err_unsafe_argument=11: If the input is not safe.
#
# @example
#   if is_valid_boolean "$reset_flag"; then echo "Valid boolean"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_boolean()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the boolean value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"
    is_boolean "$1"                                                             || with_error _rc "$err_unsafe_argument" "Invalid boolean '$1': it must be 'true' or 'false'."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that the input is an integer value.
#   If the input is not a valid integer, prints an error message.
#
# @arg $1 string The input string to test.
#
# @exitcode positive=0: If the input is a valid integer.
# @exitcode err_unsafe_argument=11: If the input is not safe.
#
# @example
#   if is_valid_integer "$count"; then echo "Valid integer"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_integer()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the integer value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"
    is_integer "$1"                                                             || with_error _rc "$err_unsafe_argument" "Invalid integer '$1'."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a string is a valid path (non-empty and passing `pathchk`). Depends
#   on `is_path`. The path does not have to exist.
#
# @arg $1 string The path to test.
#
# @exitcode success=0: If the path is valid.
# @exitcode err_argument_value=4: If the string is not a valid path.
#
# @example
#   if is_valid_path "config/settings.json"; then echo "Valid path"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success

    # is it a valid path string
    is_path "$1"                                                                || with_error _rc "$err_argument_value" "Invalid path '$1': it must be non-empty and pass 'pathchk'."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a string is a valid and safe path: guards against directory
#   traversal and dangerous patterns. Depends on `is_valid_path`.
#
# Notes:
#   - An empty string is not a valid path, hence not safe.
#   - Relative paths are expected; absolute paths are considered unsafe.
#   - Rejects paths containing `..` (traversal), a leading `/` (absolute path), or unsafe
#     characters `$`, ````, `;`.
#   - Prints an error message about all detected unsafe patterns.
#
# @arg $1 string The file path to test (should be relative).
#
# @exitcode success=0: If the path is safe.
# @exitcode err_argument_value=4: If the string is not a valid path.
# @exitcode err_unsafe_argument=11: If the input is not safe.
#
# @example
#   if is_safe_path "config/settings.json"; then echo "Safe path"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success
    local _path="$1"

    # is it a valid path string
    is_valid_path "$_path"                                                      || _rc=$?

    # Reject paths with one or more of:
    #   directory traversal
    #   absolute paths starting with '/'
    #   paths with dangerous characters
    [[ ! "$_path" =~ \.\. ]]                                                    || with_error _rc "$err_unsafe_argument" "The path '$_path' contains directory traversal sequences, which is not allowed."
    [[ ! "$_path" =~ ^/ ]]                                                      || with_error _rc "$err_unsafe_argument" "The path '$_path' is an absolute path, which is not allowed."
    [[ ! "$_path" =~ [\$\`\;] ]]                                                || with_error _rc "$err_unsafe_argument" "Invalid path '$_path': it contains an unsafe character ('\$', '\`', or ';')."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a path is safe and exists. Depends on `is_safe_path`.
#
# @arg $1 string The file or directory path to test.
#
# @exitcode success=0: If the path is valid, safe, and exists.
# @exitcode err_argument_value=4: If the string is not a valid path.
# @exitcode err_unsafe_argument=11: If the input is not safe.
# @exitcode err_non_existent_path=20: If the path does not exist.
#
# @example
#   if is_safe_existing_path "$config_file"; then source "$config_file"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success
    local _path="$1"

    is_safe_path "$_path"                                                       || _rc=$?
    [[ -e "$_path" ]]                                                           || with_error _rc "$err_non_existent_path" "The path '$_path' does not exist."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a path is safe, exists, and is a directory. Depends on
#   `is_safe_existing_path`.
#
# @arg $1 string The directory path to test.
#
# @exitcode success=0: If the path is safe, exists, and is a directory.
# @exitcode err_argument_value=4: If the string is not a valid path.
# @exitcode err_unsafe_argument=11: If the input is not safe.
# @exitcode err_non_existent_path=20: If the path does not exist.
# @exitcode err_not_directory=17: If the path is not a directory.
#
# @example
#   if is_safe_existing_directory "$build_dir"; then cd "$build_dir"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_directory()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the directory path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_safe_existing_path "$1"                                                  || _rc=$?
    (( _rc != success )) || [[ -d "$1" ]]                                       || with_error _rc "$err_not_directory" "The path '$1' is not a directory."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a path is safe, exists, and is a non-empty file. Depends on
#   `is_safe_existing_path`.
#
# @arg $1 string The file path to test.
#
# @exitcode success=0: If the path is safe, exists, and is a non-empty file.
# @exitcode err_argument_value=4: If the string is not a valid path.
# @exitcode err_unsafe_argument=11: If the input is not safe.
# @exitcode err_non_existent_path=20: If the path does not exist.
# @exitcode err_not_file=16: If the path is not a file, or the file is empty.
#
# @example
#   if is_safe_existing_file "$script"; then bash "$script"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_file()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_safe_existing_path "$1"                                                  || _rc=$?
    (( _rc != success )) || [[ -f "$1" && -s "$1" ]]                            || with_error _rc "$err_not_file" "The path '$1' is not a file or is empty."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Escapes special characters in a string for use in an extended regular
#   expression (ERE).
#
# Notes:
#   - Escapes the characters that have special meaning in ERE: `[](){}.^$*+?|\`.
#
# @arg $1 string The string to escape.
#
# @exitcode success=0: The string was escaped and printed (always, once past the argument
#   validation gate).
#
# @stdout The escaped string, with special ERE characters prefixed by a backslash.
#
# @example
#   escaped=$(escape_ere "some string with special chars.*")
#-----------------------------------------------------------------------------------------------
function escape_ere()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the string that needs its special ERE characters to be escaped." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}
