# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines functions for sanitizing and validating user input, esp. in GitHub Actions workflows.
# It includes functions for trimming whitespace and checking for safe input.
#===============================================================================================

# Circular include guard
(( ${__VM2_LIB_SANITIZE_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_SANITIZE_SH_LOADED=1

# vm2 core lib exit codes
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_invalid_nameref
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_not_found
declare -xri err_not_file
declare -xri err_not_directory
declare -xri err_unsafe_argument
declare -xri err_invalid_path
declare -xri err_non_existent_path
declare -xri err_missing_argument
declare -xri err_invalid_json
declare -xri err_invalid_json_array
declare -xri err_logic_error

# vm2 core lib constants
declare -xr nugetServersRegex
declare -xr default_nuget_server
declare -xr build_config_regex
declare -xr tfm_regex
declare -xr rid_regex
declare -xra allowed_runners_os
declare -xra known_configurations
declare -xr known_tfms
declare -xr known_runtimes

declare -rx dangerous_chars_regex=$'[;|&$`<>(){}\n\r]'
declare -rx dangerous_chars_and_whitespaces_regex='[;|&$`<>(){}[:space:]]'

# vm2 core lib variables
declare -x _ignore
declare -x repo_owner

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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces." -ec "$err_invalid_arguments"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires a non-empty variable name." -ec "$err_invalid_nameref"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces." -ec "$err_invalid_arguments"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires a non-empty variable name." -ec "$err_invalid_nameref"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces." -ec "$err_invalid_arguments"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires a non-empty variable name." -ec "$err_invalid_nameref"
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
#   - An empty input is considered safe.
#
# @arg $1 string The input string to test.
# @arg $2 bool If true, allows spaces in the input (optional, default: false).
#
# @exitcode positive=0: If the input is safe.
# @exitcode err_unsafe_argument=11: An argument value is unsafe to use.
#
# @example
#   if is_safe_input "$user_input" true; then echo "Safe input"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_input()
{
    (( $# == 1 || $# == 2 ))                                                    || bug "${FUNCNAME[0]}() requires one or two arguments (provided $#):" \
                                                                                       "  - the input string to sanitize" \
                                                                                       "  - an optional flag to allow spaces" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 2 ]] || is_boolean "$2"                                             || bug "${FUNCNAME[0]}() requires argument 2 to be a valid boolean (provided '${2-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs

    local -i _rc="$positive"
    local _input="$1"

    # Empty input is considered safe
    [[ -z "$_input" ]] && return "$positive"

    local _allow_spaces="${2:-false}"

    # Dangerous characters that could enable command injection
    local _dangerous_chars

    $_allow_spaces &&
        _dangerous_chars=$dangerous_chars_regex ||
        _dangerous_chars=$dangerous_chars_and_whitespaces_regex

    [[ ! "$_input" =~ $_dangerous_chars ]]                                      || with_error _rc "$err_unsafe_argument" "${FUNCNAME[0]}(): The input '$_input' contains one or more of the unsafe characters: '$_dangerous_chars'."

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
#   if is_safe_boolean "$reset_flag"; then echo "Valid boolean"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_boolean()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the boolean value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$positive"
    is_boolean "$1"                                                             || with_error _rc "$err_unsafe_argument" "${FUNCNAME[0]}(): The input '$1' is not a valid boolean. Expected 'true' or 'false'."
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
#   if is_safe_integer "$count"; then echo "Valid integer"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_integer()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the integer value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$positive"
    is_integer "$1"                                                             || with_error _rc "$err_unsafe_argument" "${FUNCNAME[0]}(): The input '$1' is not a valid integer."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates file paths to prevent directory traversal and dangerous patterns.
#
# Notes:
#   - Empty strings are considered safe.
#   - Relative paths are expected; absolute paths are considered unsafe.
#   - Rejects paths containing `..` (traversal), a leading `/` (absolute path), or unsafe
#     characters `$`, ````, `;`.
#   - Prints an error message about all detected unsafe patterns.
#
# @arg $1 string The file path to test (should be relative).
#
# @exitcode positive=0: If the path is safe.
# @exitcode err_unsafe_argument=11: If the input is not safe.
#
# @example
#   if is_safe_path "config/settings.json"; then echo "Safe path"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    # empty string is a "safe" path ("missing" maybe valid or invalid and requires more validation)
    [[ -n "$_path" ]]                                                           || return "$_rc"

    # Reject paths with one or more of:
    #   directory traversal
    #   absolute paths starting with '/'
    #   paths with dangerous characters
    [[ ! "$_path" =~ \.\. ]]                                                    || with_error _rc "$err_unsafe_argument" "The path '$_path' contains directory traversal sequences, which is not allowed."
    [[ ! "$_path" =~ ^/ ]]                                                      || with_error _rc "$err_unsafe_argument" "The path '$_path' is an absolute path, which is not allowed."
    [[ ! "$_path" =~ [\$\`\;] ]]                                                || with_error _rc "$err_unsafe_argument" "The path '$_path' contains one or more unsafe characters: \$, \`, ;"
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates file paths to prevent directory traversal and dangerous patterns and
#   ensures that the path string is a valid path even if it does not exist.
#
# Notes:
#   - Rejects paths containing `..` (traversal), a leading `/` (absolute path), or the
#     characters `$`, ````, `;`.
#   - Ensures the path is a valid path string, even if the file or directory does not exist.
#
# @arg $1 string The file path to test (should be relative).
#
# @exitcode positive=0: If the path is valid and safe.
# @exitcode negative=1: If the path is not valid.
# @exitcode err_unsafe_argument=11: If the input is not safe.
#
# @example
#   if is_safe_valid_path "config/settings.json"; then echo "Safe path"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_valid_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _path="$1"
    local -i _rc=$positive

    is_valid_path "$_path"                                                      || with_error _rc "$err_invalid_path" "The path '$_path' is not valid."
    (( _rc != success )) || is_safe_path "$_path"                               || _rc=$?
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a path is safe and exists. Depends on `is_safe_path`.
#
# @arg $1 string The file or directory path to test.
#
# @exitcode positive=0: If the path is valid, safe, and exists.
# @exitcode negative=1: If the path is invalid.
# @exitcode err_unsafe_argument=11: If the input is not safe.
# @exitcode err_non_existent_path=19: If the path does not exist.
#
# @example
#   if is_safe_existing_path "$config_file"; then source "$config_file"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    is_safe_valid_path "$_path"                                                 || return $?
    [[ -e "$_path" ]]                                                           || with_error _rc "$err_non_existent_path" "The path '$_path' does not exist."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a path is safe, exists, and is a directory. Depends on
#   `is_safe_existing_path`.
#
# @arg $1 string The directory path to test.
#
# @exitcode positive=0: If the path is safe, exists, and is a directory.
# @exitcode negative=1: Otherwise.
#
# @example
#   if is_safe_existing_directory "$build_dir"; then cd "$build_dir"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_directory()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the directory path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    is_safe_existing_path "$1"                                                  || return $?
    [[ -d "$1" ]]                                                               || with_error _rc "$err_not_directory" "The path '$_path' is not a directory."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a path is safe, exists, and is a non-empty file. Depends on
#   `is_safe_existing_path`.
#
# @arg $1 string The file path to test.
#
# @exitcode positive=0: If the path is safe, exists, and is a non-empty file.
# @exitcode negative=1: Otherwise.
#
# @example
#   if is_safe_existing_file "$script"; then bash "$script"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_file()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    is_safe_existing_path "$1"                                                  || return $?
    [[ -f "$_path" && -s "$_path" ]]                                            || with_error _rc "$err_not_file" "The path '$_path' is not a file or is empty."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates and normalizes a JSON array of strings, or a single JSON string, into
#   a JSON array of trimmed strings. Also checks each item's validity using the provided
#   validator function.
#
# @arg $1 nameref to a variable containing a JSON array or a single string (a plain string is
#   converted to a single-item JSON array). The normalized JSON array is stored back in that
#   variable.
# @arg $2 string The default value to use if the variable named by $1 contains an empty string.
#    Optional, if $3 is not provided.
# @arg $3 string The name of the function to validate each item in the array. The function
#   should accept a single string argument and return a success/positive exit code if the item
#   is valid, or a non-zero exit code if it is unsafe. When rejecting a value, the function
#   may display an error message as well. Optional.
#
# @exitcode success=0: If the input is valid JSON and all items are safe.
# @exitcode err_unsafe_argument=11: If the input (or one of its items) is unsafe.
# @exitcode err_invalid_json_array=13: If the input is not a JSON array of strings, an empty
#   array, a JSON string, or null.
#
# @example
#   validate_json_array runners '["ubuntu-latest"]' is_safe_runner_os
#-----------------------------------------------------------------------------------------------
function validate_json_array()
{
    (( $# > 0 && $# <= 3 ))                                                     || bug "${FUNCNAME[0]}() requires one to three arguments (provided $#):" \
                                                                                       "  - the name of a variable containing the JSON array" \
                                                                                       "  - the default value to use if the variable is unbound or empty, optional" \
                                                                                       "  - the name of the function to validate each item in the array, optional" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to name a declared variable containing the JSON input (provided '${1-<missing>}')." -ec "$err_missing_argument"
    [[ ! -v 3 ]] || is_function "$3"                                            || bug "${FUNCNAME[0]}() requires argument 3 to name a defined item-validation function (provided '${3-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs

    local -n __input=$1

    [[ -n $__input ]] || __input=${2:-}

    local -i _rc="$positive"

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ -n "$__input" ]] && is_safe_input "$__input" true                        || with_error _rc "$err_unsafe_argument" "${FUNCNAME[0]}() requires a safe, non-empty string representing a JSON array of strings, or an empty array; or a JSON string (possibly empty); or null (provided '${__input-<missing>}')."
    (( _rc == success))                                                         || return "$_rc"

    local _output
    local -i _length

    # validate and normalize JSON
    {
        read -r _output
        read -r _length
    } < <(
        jq -c '
            if type == "boolean" or type == "number" or type == "object" then
                error("The input must be a JSON array of strings, or an empty array; or a JSON string (possibly empty); or null.")
            elif type == "null" then
                [], 0
            elif type == "string" then
                [ trim ], 1
            elif type=="array" and all(type=="string") then
                map(trim | select(. != "")) | reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end) | ., length
            else
                error("The input must be a JSON array of strings, or an empty array; or a JSON string (possibly empty); or null.")
            end
        ' <<< "$__input"
    )                                                                           || with_error _rc "$err_invalid_json_array" "The input must be a JSON array of strings, or an empty array; or a JSON string (possibly empty); or null (provided '${__input-<missing>}')."
    (( _rc == success))                                                         || return "$_rc"

    local _is_safe_item_fn=${3:-}

    if (( _length > 0 )) && [[ -n $_is_safe_item_fn && $_is_safe_item_fn != true ]]; then
        # validate each item in the array
        while read -r _item; do
            $_is_safe_item_fn "$_item"                                          || with_error _rc "$err_unsafe_argument" "'$_item' is not a valid item for this JSON array"
        done < <(jq -r '.[]' <<< "$_output")
    fi
    (( _rc != positive )) || __input=$_output
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a runner OS name is in the allowed list of GitHub Actions
#   runners.
#
# Notes:
#   - The allowed values are defined in the `$allowed_runners_os` array.
#
# @arg $1 string The runner OS name to validate.
#
# @exitcode positive=0: If the runner OS is valid.
# @exitcode negative=1: If the runner OS is empty or not in the allowed list.
#
# @example
#   if is_safe_runner_os "ubuntu-latest"; then echo "Valid runner"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_runner_os()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the runner OS to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _runner_os="$1"
    local -i _rc=$positive

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    is_safe_input "$_runner_os" &&
    is_in "$_runner_os" "${allowed_runners_os[@]}"                              || with_error _rc "$err_argument_value" "The runner OS '$_runner_os' is not allowed. Valid options: ${allowed_runners_os[*]}."
    (( _rc == positive ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates a "reason" text input for safety and length constraints. Depends on
#   `is_safe_input`.
#
# Notes:
#   - Maximum length is 200 characters.
#   - Allows spaces but rejects shell meta-characters and command-like patterns (input
#     starting with `-`, `/`, or `.`).
#
# @arg $1 string The reason text to validate.
#
# @exitcode positive=0: If the reason is safe.
# @exitcode negative=1: If the reason is too long, contains unsafe characters, or looks like a command.
#
# @example
#   if is_safe_reason "$user_reason"; then log_reason "$user_reason"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_reason()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the reason text to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _reason="$1"
    local _max_length=200
    local -i _rc=$positive

    # Allow spaces but reject dangerous shell meta-characters
    is_safe_input "$_reason" true                                               || _rc="$negative"

    # Check length
    (( ${#_reason} <= _max_length ))                                            || with_error _rc "$err_argument_value" "The reason is too long. Maximum length is $_max_length characters."

    # Reject if it looks like a command (starts with -, /, .)
    [[ ! "$_reason" =~ ^[-/.] ]]                                                || with_error _rc "$err_unsafe_argument" "The reason '$_reason' appears to be a command or contains unsafe characters."
    (( _rc == positive ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates a NuGet server moniker (`nuget`, `github`, or a custom https:// URL)
#   and resolves it into a display name and a server URL.
#
# @arg $1 nameref to a variable that stores the NuGet server moniker to validate.
# @arg $2 nameref to a variable to receive the NuGet server's display name.
# @arg $3 nameref to a variable to receive the NuGet server's URL.
# @arg $4 string The default server value (optional, default: `nuget`).
#
# @exitcode success=0: On success.
# @exitcode err_argument_value=4: If the NuGet server moniker is not `nuget`, `github`, or a
#   valid https:// URL.
#
# @example
#   local nuget_server="github" server_name server_url
#   validate_nuget_server nuget_server server_name server_url
#   echo "$server_name -> $server_url"
#-----------------------------------------------------------------------------------------------
function validate_nuget_server()
{
    (( $# == 3 || $# == 4 ))                                                    || bug "${FUNCNAME[0]}() requires three or four arguments (provided $#):" \
                                                                                       "  - the name of the variable containing the NuGet server" \
                                                                                       "  - the name to store the NuGet server's display name" \
                                                                                       "  - the name to store the NuGet server's URL" \
                                                                                       "  - an optional default server" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires the first argument to be a valid variable name containing the NuGet server moniker (provided '$1')." -ec "$err_invalid_nameref"
    [[ ! -v 2 ]] || is_variable "$2"                                            || bug "${FUNCNAME[0]}() requires the second argument to be a valid variable name (provided '$2')." -ec "$err_invalid_nameref"
    [[ ! -v 3 ]] || is_variable "$3"                                            || bug "${FUNCNAME[0]}() requires the third argument to be a valid variable name (provided '$3')." -ec "$err_invalid_nameref"
    [[ ! -v 4 || $4 =~ $nugetServersRegex ]]                                    || bug "${FUNCNAME[0]}() requires the fourth argument to be a valid default NuGet server moniker (provided '$4')." -ec "$err_argument_value"
    [[ -n $repo_owner ]]                                                        || bug "${FUNCNAME[0]}() requires the global variable \$repo_owner to be already set." -ec "$err_logic_error"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    local _default_server="${4:-$default_nuget_server}"
    local -n __server=${1:-_default_server}

    [[ "$__server" =~ $nugetServersRegex ]]                                     || with_error _rc "$err_argument_value" "Invalid NuGet server: $__server."
    (( _rc == success ))                                                        || return "$_rc"

    local -n __server_name=$2
    local -n __server_url=$3
    case "$__server" in
        nuget )
            __server_name="NuGet.org"
            __server_url="https://api.nuget.org/v3/index.json"
            ;;

        github )
            __server_name="GitHub Packages"
            __server_url="https://nuget.pkg.github.com/$repo_owner/index.json"
            ;;

        https://*|http://* )
            __server_name="$__server"
            __server_url="$__server"
            ;;

        * ) error _rc "$err_argument_value" "Unknown NuGet server: $__server"
            ;;
    esac
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a string is a valid build configuration name. Depends on
#   `is_valid_configuration`.
#
# Notes:
#   - Must match the pattern `[A-Za-z_][A-Za-z0-9_]*` (a valid C-style identifier).
#
# @arg $1 string The configuration name to validate.
#
# @exitcode positive=0: If the configuration name is valid.
# @exitcode err_argument_value=1: If the configuration name is invalid.
#
# @example
#   if is_safe_configuration "$build_config"; then echo "Valid config"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_configuration()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the configuration value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    is_safe_input "$1" &&
    is_valid_configuration "$1"                                                 || with_error _rc "$err_argument_value" "The configuration '$1' is not valid."
    (( _rc != positive )) || [[ -z $1 ]] ||
                             is_in_i "$1" "${known_configurations[@]}"          || warning "The configuration '$1' is not among the known configurations: ${known_configurations[*]}." -ec "$err_argument_value"

    (( _rc == success ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a Target Framework Moniker (TFM) is a valid identifier. Depends
#   on `is_valid_framework`.
#
# @arg $1 string The TFM to validate.
#
# @exitcode positive=0: If the TFM is valid.
# @exitcode err_argument_value=4: If the TFM is invalid.
#
# @example
#   if is_safe_framework "$framework"; then echo "Valid TFM"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_framework()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the Target Framework Moniker (TFM) value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_valid_framework "$1"                                                     || with_error _rc "$err_argument_value" "The  Target Framework Moniker (TFM) '$1' is not valid."
    (( _rc != positive )) || is_in "$1" "${known_tfms[@]}"                      || warning "The Target Framework Moniker (TFM) '$1' is not among the known frameworks: ${known_tfms[*]}." -ec "$err_argument_value"

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a Runtime Identifier (RID) is a valid identifier. Depends on
#   `is_valid_runtime`. If the RID is valid but not one of `$known_runtimes`, issues a warning
#   (not an error) rather than failing, so an unrecognized-but-well-formed RID is still
#   accepted.
#
# @arg $1 string The Runtime Identifier (RID) to validate.
#
# @exitcode positive=0: If the RID is valid.
# @exitcode err_argument_value=4: If the RID is invalid.
#
# @example
#   if is_safe_runtime "$runtime"; then echo "Valid RID"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_runtime()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the Runtime Identifier (RID) value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_valid_runtime "$1"                                                       || with_error _rc "$err_argument_value" "The  Runtime Identifier (RID) '$1' is not valid."
    (( _rc != positive )) || is_in "$1" "${known_runtimes[@]}"                  || warning "The Runtime Identifier (RID) '$1' is not among the known runtimes: ${known_runtimes[*]}." -ec "$err_argument_value"
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Lowercases the referenced Runtime Identifier (RID) in place and validates that
#   it is safe to use, via `is_safe_runtime()`.
#
# @arg $1 nameref to a variable containing the Runtime Identifier (RID) to validate.
#
# @exitcode success=0: The Runtime Identifier (RID) was lowercased and found safe.
# @exitcode N propagated from `is_safe_runtime()` (e.g. `err_argument_value`) if the lowercased
#   RID is not safe.
#-----------------------------------------------------------------------------------------------
function validate_runtime()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the Runtime Identifier (RID) variable to validate." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to be the name of a defined variable that will store the normalized Runtime Identifier (RID) (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -n __rid="$1"

    # since `_rid` is a nameref (`local -n`), `${!_rid}` uses bash's nameref-specific
    # indirection rule and expands to the *name* of the variable `_rid` references (i.e.
    # the original `$1`), not a second round of value-based indirection. That is exactly the
    # variable-name argument `trim_var()` expects, so this correctly trims the caller's
    # variable in place.
    __rid="${__rid,,}"
    trim_var "${!__rid}"
    is_safe_runtime "$__rid" || return $?
}

#-----------------------------------------------------------------------------------------------
# @description Validates preprocessor symbols and formats them for passing to `dotnet build`.
#
# Notes:
#   - Reformats the referenced `symbols` variable in place into a semicolon-separated list.
#   - Each symbol must match `[A-Za-z_][A-Za-z0-9_]*`.
#   - Symbols may be separated in the input by spaces, commas, colons, or semicolons.
#
# @arg $1 nameref to a variable containing the space/comma/colon/semicolon-separated symbols;
#   updated in place.
#
# @exitcode success=0: All symbols are valid; the referenced variable was reformatted in place.
# @exitcode err_argument_value=4: One or more symbols are invalid (every invalid symbol is
#   reported via `error`, not just the first).
#
# @example
#   preproc="DEBUG TRACE"
#   validate_preprocessor_symbols preproc
#   # preproc becomes: "DEBUG;TRACE"
#-----------------------------------------------------------------------------------------------
function validate_preprocessor_symbols()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the variable containing the preprocessor symbols to test." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable_name "$1"                                       || bug "${FUNCNAME[0]}() requires argument 1 to be a valid variable name for the preprocessor-symbol list (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -i _rc="$success"
    local -n __symbols=$1

    [[ -n $__symbols ]]                                                         || return "$positive"
    [[ $__symbols =~ ^[\ \,:\;0-9A-Z_a-z]+$ ]]                                  || { with_error _rc "$err_argument_value" "The preprocessor symbols '$__symbols' contain invalid characters."
                                                                                     return "$_rc"
                                                                                }

    local -a _symbol_array=()

    IFS=' ,:;' read -r -a _symbol_array <<< "$__symbols"

    local _normalized_symbols=''
    local _symbol

    for _symbol in "${_symbol_array[@]}"; do
        [[ -n $_symbol ]]                                                       || continue # tolerate consecutive separators in the input
        if is_variable_name "$_symbol"; then
            # symbol is valid, put it into the normalized list
            [[ -z $_normalized_symbols ]] &&
                _normalized_symbols="$_symbol" ||
                _normalized_symbols="$_normalized_symbols;$_symbol"
        else
            with_error _rc "$err_argument_value" "The pre-processor symbol '$_symbol' from '$__symbols' is not valid."
        fi
    done

    (( _rc == success )) || return "$_rc"

    __symbols=$_normalized_symbols
    return "$positive"
}

#-----------------------------------------------------------------------------------------------
# @description Checks whether a candidate secret value is safe to send to the GitHub API --
# i.e. it contains no control characters.
#
# @arg $1 string Candidate secret value to validate.
#
# @exitcode positive=0: The value is non-empty and contains no control characters.
# @exitcode err_argument_value=4: The value is empty, or contains at least one control
#   character.
#-----------------------------------------------------------------------------------------------
function is_safe_secret()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the variable containing the secret to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_valid_secret "$1"                                                        || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the secret value, to be non-empty and to contain no control characters."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates minimum coverage percentage input. Depends on `is_valid_percentage`.
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The minimum coverage percentage to validate.
#
# @exitcode positive=0: If the percentage is valid.
# @exitcode negative=1: If the percentage is invalid.
#
# @example
#   if is_safe_min_coverage_pct "80"; then echo "Valid coverage percentage"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_min_coverage_pct()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the percentage to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_valid_percentage "$1"                                                    || with_error _rc "$err_argument_type" "The min coverage percentage '$1' must be an integer number between 0 and 100."
    (( _rc == positive ))
}
#-----------------------------------------------------------------------------------------------
# @description Validates maximum regression percentage input. Depends on
#    `is_valid_percentage`.
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The maximum regression percentage to validate.
#
# @exitcode positive=0: If the percentage is valid.
# @exitcode negative=1: If the percentage is invalid.
#
# @example
#   if is_safe_max_regression_pct "10"; then echo "Valid regression percentage"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_max_regression_pct()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the percentage to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_valid_percentage "$1"                                                    || with_error _rc "$err_argument_value" "The max regression percentage '$1' must be an integer number between 0 and 100."
    (( _rc == positive ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a MinVer Git tag prefix is safe and well-formed. Delegates to
#   `is_valid_minverTagPrefix`.
#
# Notes:
#   - Must match `$minverTagPrefixRegex` (see `is_valid_minverTagPrefix`).
#
# @arg $1 string The MinVer tag prefix to validate.
#
# @exitcode positive=0: If the tag prefix is valid.
# @exitcode negative=1: If the tag prefix is invalid.
#
# @example
#   if is_safe_minverTagPrefix "v"; then echo "Valid tag prefix"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_minverTagPrefix()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the MinVer tag prefix to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_valid_minverTagPrefix "$@"                                               || with_error _rc "$err_argument_value" "The MinVer tag prefix '$1' is not valid."
    (( _rc == positive ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates the MinVer prerelease identifier format. Delegates to
#   `is_valid_minverPrereleaseId`.
#
# Notes:
#   - Must match `$minverPrereleaseIdRegex` (the same as the SemVer prerelease label format).
#
# @arg $1 string The MinVer prerelease ID to validate.
#
# @exitcode positive=0: If the prerelease ID is valid.
# @exitcode negative=1: If the prerelease ID is invalid.
#
# @example
#   if is_safe_minverPrereleaseId "alpha.1"; then echo "Valid prerelease ID"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_minverPrereleaseId()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the MinVer prerelease ID to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_valid_minverPrereleaseId "$@"                                            || with_error _rc "$err_argument_value" "The prerelease ID '$1' is not valid."

    (( _rc == positive ))
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the string that needs its special ERE characters to be escaped." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}

#-----------------------------------------------------------------------------------------------
# @description Validates a JSON file against a JSON Schema file, using the `check-jsonschema`
#   CLI (https://pypi.org/project/check-jsonschema/, `pip install check-jsonschema`) if it is
#   present on PATH. `check-jsonschema` is a dev-machine convenience, not a hard dependency of
#   this script: if it is not installed, this function warns and reports success rather than
#   failing, so a missing optional tool never blocks diff-shared.sh from running.
#
# @arg $1 string Path to the JSON file to validate (must exist and be non-empty).
# @arg $2 string Path to the JSON Schema file to validate against (must exist and be non-empty).
#
# @exitcode success=0: The file is valid against the schema, or `check-jsonschema` is not
#   installed (validation skipped, a warning is issued).
# @exitcode err_not_file=16: Argument 1 or 2 is not an existing, non-empty file.
# @exitcode err_invalid_json=12: Argument 1 or 2 is not well-formed JSON, or the JSON file
#   failed schema validation (the validator's own error output is reported via `error`).
#
# @example
#   validate_json_schema "$_config_file" "$lib_dir/diff-shared.config.schema.json"
#-----------------------------------------------------------------------------------------------
function validate_json_schema()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                                       "  - the JSON file to validate" \
                                                                                       "  - the JSON Schema file to validate against" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_valid_path "$1"                                          || bug "${FUNCNAME[0]}() requires argument 1 to be a valid path (provided '${1-<missing>}')." -ec "$err_not_file"
    [[ ! -v 2 ]] || is_valid_path "$2"                                          || bug "${FUNCNAME[0]}() requires argument 2 to be a valid path (provided '${2-<missing>}')." -ec "$err_not_file"
                                                                                exit_if_has_bugs

    local _json_file="$1"
    local _schema_file="$2"

    local -i _rc="$success"

    [[ -s $_json_file ]]                                                        || with_error _rc "$err_not_file" "${FUNCNAME[0]}() requires argument 1 to be an existing, non-empty JSON file (provided '${_json_file-<missing>}')."
    [[ -s $_schema_file ]]                                                      || with_error _rc "$err_not_file" "${FUNCNAME[0]}() requires argument 2 to be an existing, non-empty JSON Schema file (provided '${_schema_file-<missing>}')."

    (( _rc != success )) || is_valid_json_file "$_json_file"                    || with_error _rc "$err_invalid_json" "The JSON file '$_json_file' is not well-formed."
    (( _rc != success )) || is_valid_json_file "$_schema_file"                  || with_error _rc "$err_invalid_json" "The JSON schema file '$_schema_file' is not well-formed."

    local _output

    if is_check_jsonschema_present; then
        (( _rc != success )) || _output=$(check-jsonschema --schemafile "$_schema_file" "$_json_file" 2>&1) \
                                                                                || with_error _rc "$err_invalid_json" "'$_json_file' failed validation against the schema in '$_schema_file':" "$_output"
    fi
    return "$_rc"
}
