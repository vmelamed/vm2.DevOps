# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#=============================================================================================
# This script defines functions for sanitizing and validating user input, esp. in GitHub Actions workflows.
# It includes functions for trimming whitespace and checking for safe input.
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_SANITIZE_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_SANITIZE_SH_LOADED=1

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

declare -x _ignore

declare -x repo_owner

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function ltrim()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces."
    exit_if_has_bugs

    printf '%s' "${1#"${1%%[![:space:]]*}"}"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function ltrim_var()
{
    (( $# == 1 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces."
    [[ ! -v 1 ]] || is_variable "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires a non-empty variable name."
    exit_if_has_bugs

    local -n _var="$1"

    _var="${_var#"${_var%%[![:space:]]*}"}"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function rtrim()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces."
    exit_if_has_bugs

    printf '%s' "${1%"${1##*[![:space:]]}"}"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function rtrim_var()
{
    (( $# == 1 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces."
    [[ ! -v 1 ]] || is_variable "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires a non-empty variable name."
    exit_if_has_bugs

    local -n _var="$1"

    _var="${_var%"${_var##*[![:space:]]}"}"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function trim()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces."
    exit_if_has_bugs

    local _value=$1

    _value="${_value#"${_value%%[![:space:]]*}"}"
    _value="${_value%"${_value##*[![:space:]]}"}"

    printf '%s' "$_value"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function trim_var()
{
    (( $# == 1 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim the leading spaces."
    [[ ! -v 1 ]] || is_variable "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires a non-empty variable name."
    exit_if_has_bugs

    local -n _var="$1"

    _var="${_var#"${_var%%[![:space:]]*}"}"
    _var="${_var%"${_var##*[![:space:]]}"}"
}

declare -rx dangerous_chars_regex=$'[;|&$`<>(){}\n\r]'
declare -rx dangerous_chars_and_whitespaces_regex='[;|&$`<>(){}[:space:]]'
#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_input()
{
    (( $# == 1 || $# == 2 ))        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one or two arguments (provided $#):" \
                                                                        "  - the input string to sanitize" \
                                                                        "  - an optional flag to allow spaces"
    [[ ! -v 2 ]] || is_boolean "$2" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 2 to be a valid boolean (provided '${2:-<none>}')."
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

    if [[ "$_input" =~ $_dangerous_chars ]]; then
        _rc="$err_unsafe_argument"
        error -ec "$_rc" "${FUNCNAME[0]}(): The input '$_input' contains one or more of the unsafe characters: '$_dangerous_chars'."
    fi

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_boolean()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the boolean value to test."
    exit_if_has_bugs

    local -i _rc="$positive"
    is_boolean "$1" || {
        _rc="$err_unsafe_argument"
        error -ec "$_rc" "${FUNCNAME[0]}(): The input '$1' is not a valid boolean. Expected 'true' or 'false'."
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_integer()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the integer value to test."
    exit_if_has_bugs

    local -i _rc="$positive"
    is_integer "$1" || {
        _rc="$err_unsafe_argument"
        error -ec "$_rc" "${FUNCNAME[0]}(): The input '$1' is not a valid integer."
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_path()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
    exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    [[ -n "$_path" ]] ||
        # empty string is a "safe" path ("missing" maybe valid or invalid and requires more validation)
        return "$_rc"

    # Reject paths with directory traversal
    [[ ! "$_path" =~ \.\. ]] || {
        _rc=$err_unsafe_argument
        error -ec "$_rc" "The path '$_path' contains directory traversal sequences, which is not allowed."
    }
    # Reject absolute paths starting with /
    [[ ! "$_path" =~ ^/ ]] || {
        _rc=$err_unsafe_argument
        error -ec "$_rc" "The path '$_path' is an absolute path, which is not allowed."
    }
    # Reject paths with dangerous characters
    [[ ! "$_path" =~ [\$\`\;] ]] || {
        _rc=$err_unsafe_argument
        error -ec "$_rc" "The path '$_path' contains one or more unsafe characters: \$, \`, ;"
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_valid_path()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
    exit_if_has_bugs

    local _path="$1"
    local -i _rc=$positive

    is_safe_path "$_path" ||
        return "$?"

    is_valid_path "$_path" || {
        _rc=$?
        error -ec "$_rc" "The path '$_path' is not valid."
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_existing_path()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
    exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    is_safe_valid_path "$_path" ||
        return "$?"

    [[ -e "$_path" ]] || {
        _rc="$err_non_existent_path"
        error -ec "$_rc" "The path '$_path' does not exist."
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_existing_directory()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the directory path to test."
    exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    is_safe_existing_path "$1" ||
        return "$?"

    [[ -d "$1" ]] || {
        _rc="$err_not_directory"
        error -ec "$_rc" "The path '$_path' is not a directory."
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_existing_file()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
    exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    is_safe_existing_path "$1" ||
        return "$?"

    [[ -f "$_path" && -s "$_path" ]] || {
        _rc="$err_not_file"
        error -ec "$_rc" "The path '$_path' is not a file or is empty."
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Validates and normalizes a JSON array of strings, or a single JSON string, into
#   a JSON array of non-empty, trimmed strings. Also checks each item's validity using the
#   provided validator function.
#
# @arg $1 nameref to a variable containing a JSON array or a single string (a plain string is
#   converted to a single-item JSON array). The normalized JSON array is stored back in that
#   variable.
# @arg $2 string The default value to use if $1 is an empty string. Optional, if $3 is not
#   provided either.
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
#---------------------------------------------------------------------------------------------
function validate_json_array()
{
    (( $# > 0 && $# <= 3 ))          || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one to three arguments (provided $#):" \
                                                                            "  - the name of a variable containing the JSON array" \
                                                                            "  - the default value to use if the variable is unbound or empty, optional" \
                                                                            "  - the name of the function to validate each item in the array, optional"
    [[ ! -v 1 ]] || is_variable "$1" || bug -ec "$err_missing_argument" "${FUNCNAME[0]}() requires argument 1 to name a declared variable containing the JSON input (provided '${1:-<none>}')."
    [[ ! -v 3 ]] || is_function "$3" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 3 to name a defined item-validation function (provided '${3:-<none>}')."
    exit_if_has_bugs

    local -n _input=${1:-$2}

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ -n "$_input" ]] && is_safe_input "$_input" true || {
        _rc=$err_unsafe_argument
        error -ec "$_rc" "${FUNCNAME[0]}() requires a safe, non-empty string representing a JSON array of strings, or an empty array; or a JSON string (possibly empty); or null (provided '${_input:-<none>}')."
    }
    jq empty <<< "$_input"

    local _output
    local -i _length
    local -i _rc="$positive"

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
                map( trim ) | unique, length
            else
                error("The input must be a JSON array of strings, or an empty array; or a JSON string (possibly empty); or null.")
            end
        ' <<< "$_input"
    ) || {
        _rc=$err_invalid_json_array
        error -ec "$_rc" "The input must be a JSON array of strings, or an empty array; or a JSON string (possibly empty); or null (provided '${_input:-<none>}')."
        return "$_rc"
    }

    local _is_safe_item_fn=${3:-}

    if (( _length > 0 )) && [[ -n $_is_safe_item_fn && $_is_safe_item_fn != true ]]; then
        # validate each item in the array
        while read -r _item; do
            $_is_safe_item_fn "$_item" || {
                _rc="$err_unsafe_argument"
                error -ec "$_rc" "'$_item' is not a valid item for this JSON array"
            }
        done < <(jq -r '.[]' <<< "$_output")
    fi

    (( _rc == positive )) && _input=$_output
    return "$_rc"
}


declare -xra allowed_runners_os=(
    "ubuntu-latest"
    "ubuntu-22.04"
    "ubuntu-20.04"
    "windows-latest"
    "windows-2022"
    "windows-2019"
    "macos-latest"
    "macos-12"
    "macos-11"
)

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_runner_os()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the runner OS to test."
    exit_if_has_bugs

    local _runner_os="$1"
    local -i _rc=$positive

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    is_safe_input "$_runner_os" &&
    is_in "$_runner_os" "${allowed_runners_os[@]}" || {
        error -ec "$err_argument_value" "The runner OS '$_runner_os' is not allowed. Valid options: ${allowed_runners_os[*]}."
        _rc="$negative"
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_reason()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the reason text to test."
    exit_if_has_bugs

    local _rsn="$1"
    local _max_length=200
    local -i _rc=$positive

    # Allow spaces but reject dangerous shell meta-characters
    is_safe_input "$_rsn" true || {
        _rc="$negative"
    }

    # Check length
    (( ${#_rsn} <= _max_length )) || {
        error -ec "$err_argument_value" "The reason is too long. Maximum length is $_max_length characters."
        _rc="$negative"
    }

    # Reject if it looks like a command (starts with -, /, .)
    [[ "$_rsn" =~ ^[-/.] ]] && {
        error -ec "$err_unsafe_argument" "The reason '$_rsn' appears to be a command or contains unsafe characters."
        _rc="$negative"
    }

    return "$_rc"
}

declare -xr nugetServersRegex
#---------------------------------------------------------------------------------------------
# @description Tests if a string is a valid NuGet server URL or known server name.
#
# Notes:
#   - Accepts `nuget`, `github`, or a valid http(s) URL matching `$nugetServersRegex`.
#
# @arg $1 string The NuGet server URL or name to test.
#
# @exitcode positive=0: If the server can be a valid NuGet server.
# @exitcode negative=1: If the server is not a valid NuGet server.
#
# @example
#   if is_valid_nuget_server "nuget"; then echo "Valid server"; fi
#---------------------------------------------------------------------------------------------
function is_valid_nuget_server()
{
    __test_with_regex "$@" "$nugetServersRegex"
}

declare -xr default_nuget_server
#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function validate_nuget_server()
{
    (( $# == 3 || $# == 4 ))         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three or four arguments (provided $#):" \
                                                                            "  - the name of the variable containing the NuGet server" \
                                                                            "  - the name to store the NuGet server's display name" \
                                                                            "  - the name to store the NuGet server's URL" \
                                                                            "  - an optional default server"
    [[ ! -v 1 ]] || is_variable "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires the first argument to be a valid variable name containing the NuGet server moniker (provided '$1')."
    [[ ! -v 2 ]] || is_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires the second argument to be a valid variable name (provided '$2')."
    [[ ! -v 3 ]] || is_variable "$3" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires the third argument to be a valid variable name (provided '$3')."
    exit_if_has_bugs

    local -i _rc="$success"

    [[ ! -v 4 || $4 =~ $nugetServersRegex ]] || {
        _rc="$err_argument_value"
        error -ec "$_rc"  "${FUNCNAME[0]}() requires the fourth argument to be a valid default NuGet server moniker (provided '$4')."
    }
    (( _rc == "$success" )) || return "$_rc"

    local -i _rc="$success"
    local -n _server=${1:-_default_server}
    local _default_server="${4:-$default_nuget_server}"

    [[ "$_server" =~ $nugetServersRegex ]] || {
        _rc="$err_argument_value"
        error -ec "$_rc" "Invalid NuGet server: $_server."
        return "$_rc"
    }

    local -n _server_name=$2
    local -n _server_url=$3
    case "$_server" in
        nuget )
            _server_name="NuGet.org"
            _server_url="https://api.nuget.org/v3/index.json"
            ;;

        github )
            _server_name="GitHub Packages"
            _server_url="https://nuget.pkg.github.com/$repo_owner/index.json"
            ;;

        https://*|http://* )
            _server_name="$_server"
            _server_url="$_server"
            ;;

        * ) _rc="$err_argument_value"
            error -ec "$_rc" "Unknown NuGet server: $_server"
            ;;
    esac

    return "$_rc"
}

declare -xr build_config_regex="^([A-Za-z_][A-Za-z0-9_]*)?$"
#---------------------------------------------------------------------------------------------
# @description Tests if a build configuration name is a valid identifier.
#
# @arg $1 string The configuration name to test.
#
# @exitcode positive=0: If the configuration name is valid.
# @exitcode negative=1: If the configuration name is invalid.
#
# @example
#   if is_valid_configuration "$build_config"; then echo "Valid config"; fi
#---------------------------------------------------------------------------------------------
function is_valid_configuration()
{
    __test_with_regex "$@" "$build_config_regex"
}

declare -xr known_configurations=(Debug Release)
#---------------------------------------------------------------------------------------------
# @description Validates that a string is a valid build configuration name. Depends on
#   `is_valid_configuration`.
#
# Notes:
#   - Must match the pattern `[A-Za-z_][A-Za-z0-9_]*` (a valid C-style identifier).
#
# @arg $1 string The configuration name to validate.
#
# @exitcode positive=0: If the configuration name is valid.
# @exitcode negative=1: If the configuration name is invalid.
#
# @example
#   if is_safe_configuration "$build_config"; then echo "Valid config"; fi
#---------------------------------------------------------------------------------------------
function is_safe_configuration()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the configuration value to test."
    exit_if_has_bugs

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    is_safe_input "$1" &&
    is_valid_configuration "$1" || {
        error -ec "$err_argument_value" "The configuration '$1' is not valid."
        return "$negative"
    }

    [[ -z $1 ]] || is_in "$1" "${known_configurations[@]}" ||
        warning -ec "$err_argument_value" "The configuration '$1' is not among the known configurations: ${known_configurations[*]}."

    return "$positive"
}

declare -xr tfm_regex="^(net[1-9][0-9]*\.[0-9]+(-([a-z]+)([1-9][0-9.]*)?)?|[[:space:]]*)$"
#---------------------------------------------------------------------------------------------
# @description Tests if a string is a valid Target Framework Moniker (TFM).
#
# @arg $1 string The TFM to validate.
#
# @exitcode positive=0: If the TFM is valid.
# @exitcode negative=1: If the TFM is invalid.
#
# @example
#   if is_valid_framework "$framework"; then echo "Valid TFM"; fi
#---------------------------------------------------------------------------------------------
function is_valid_framework()
{
    __test_with_regex "$@" "$tfm_regex"
}

declare -xr known_tfms=("" net9.0 net10.0)
#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_framework()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the Target Framework Moniker (TFM) value to test."
    exit_if_has_bugs

    local -i _rc=$positive

    is_valid_framework "$1" || {
        _rc="$err_argument_value"
        error -ec "$_rc" "The  Target Framework Moniker (TFM) '$1' is not valid."
    }

    is_in "$1" "${known_tfms[@]}" ||
        warning -ec "$err_argument_value" "The Target Framework Moniker (TFM) '$1' is not among the known frameworks: ${known_tfms[*]}."

    return "$_rc"
}

declare -xr rid_regex="^(([a-z][a-z-]*[a-z])((\.[1-9][0-9]*)*)(-[a-z][0-9a-z]*)?(-[.0-9a-z]+)?|[[:space:]]*)$"
#---------------------------------------------------------------------------------------------
# @description Validates that a string is a valid Runtime Identifier (RID).
#
# @arg $1 string The RID to validate.
#
# @exitcode positive=0: If the RID is valid.
# @exitcode negative=1: If the RID is invalid.
#
# @example
#   if is_valid_runtime "$runtime"; then echo "Valid RID"; fi
#---------------------------------------------------------------------------------------------
function is_valid_runtime()
{
    __test_with_regex  "$@" "$rid_regex"
}

declare -xr known_runtimes=("" linux-x64 win-x64 osx-x64)
#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_runtime()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the Runtime Identifier (RID) value to test."
    exit_if_has_bugs

    local -i _rc=$positive

    is_valid_runtime "$1" || {
        _rc="$err_argument_value"
        error -ec "$_rc" "The  Runtime Identifier (RID) '$1' is not valid."
    }

    is_in "$1" "${known_runtimes[@]}" ||
        warning -ec "$err_argument_value" "The Runtime Identifier (RID) '$1' is not among the known runtimes: ${known_runtimes[*]}."

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Lowercases the referenced Runtime Identifier (RID) in place and validates that
#   it is safe to use, via `is_safe_runtime()`.
#
# @arg $1 nameref to a variable containing the Runtime Identifier (RID) to validate.
#
# @exitcode success=0: The Runtime Identifier (RID) was lowercased and found safe.
# @exitcode N propagated from `is_safe_runtime()` (e.g. `err_argument_value`) if the lowercased
#   RID is not safe.
#---------------------------------------------------------------------------------------------
function validate_runtime()
{
    (( $# == 1 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the Runtime Identifier (RID) variable to validate."
    [[ ! -v 1 ]] || is_variable "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to be the name of a defined variable that will store the normalized Runtime Identifier (RID) (provided '${1:-<none>}')."
    exit_if_has_bugs

    local -n _rid="$1"

    # since `_rid` is a nameref (`local -n`), `${!_rid}` uses bash's nameref-specific
    # indirection rule and expands to the *name* of the variable `_rid` references (i.e.
    # the original `$1`), not a second round of value-based indirection. That is exactly the
    # variable-name argument `trim_var()` expects, so this correctly trims the caller's
    # variable in place.
    _rid="${_rid,,}"
    trim_var "${!_rid}"
    is_safe_runtime "$_rid" || return "$?"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function validate_preprocessor_symbols()
{
    (( $# == 1 ))                         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the variable containing the preprocessor symbols to test."
    [[ ! -v 1 ]] || is_variable_name "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to be a valid variable name for the preprocessor-symbol list (provided '${1:-<none>}')."
    exit_if_has_bugs

    local -i _rc="$success"
    local -n _symbols=$1

    [[ -z $_symbols ]] && return "$positive"

    [[ $_symbols =~ ^[\ \,:\;0-9A-Z_a-z]+$ ]] || {
        _rc="$err_argument_value"
        error -ec "$_rc" "The preprocessor symbols '$_symbols' contain invalid characters."
        return "$_rc"
    }

    local -a _symbol_array=()

    IFS=' ,:;' read -r -a _symbol_array <<< "$_symbols"

    local _normalized_symbols=''
    local _symbol

    for _symbol in "${_symbol_array[@]}"; do
        [[ -n $_symbol ]] ||
            continue # tolerate consecutive separators in the input
        if is_variable_name "$_symbol"; then
            # symbol is valid, put it into the normalized list
            [[ -z $_normalized_symbols ]] && _normalized_symbols="$_symbol" || _normalized_symbols="$_normalized_symbols;$_symbol"
        else
            _rc="$err_argument_value"
            error -ec "$_rc" "The pre-processor symbol '$_symbol' from '$_symbols' is not valid."
        fi
    done

    (( _rc == success )) || return "$_rc"

    _symbols=$_normalized_symbols
    return "$positive"
}

#---------------------------------------------------------------------------------------------
# @description Checks whether a candidate secret value is safe to send to the GitHub API --
# i.e. it contains no control characters.
#
# @arg $1 string Candidate secret value to validate.
#
# @exitcode positive=0: The value is non-empty and contains no control characters.
# @exitcode err_argument_value=4: The value is empty, or contains at least one control
#   character.
#---------------------------------------------------------------------------------------------
function is_safe_secret()
{
    is_valid_secret "$1" || {
        error -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the secret value, to be non-empty and to contain no control characters."
        return "$err_argument_value"
    }
}

#---------------------------------------------------------------------------------------------
# @description Validates that a given value is a valid percentage (0-100).
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The percentage to validate.
#
# @exitcode positive=0: If the percentage is valid.
# @exitcode negative=1: If the percentage is invalid.
#
# @example
#   if is_valid_percentage "50"; then echo "Valid percentage"; fi
#---------------------------------------------------------------------------------------------
function is_valid_percentage()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the percentage to test."
    exit_if_has_bugs

    is_integer "$1" && (( $1 >= 0 && $1 <= 100 ))
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_min_coverage_pct()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the percentage to test."
    exit_if_has_bugs

    is_valid_percentage "$1" || {
        error -ec "$err_argument_type" "The min coverage percentage '$1' must be an integer number between 0 and 100."
        return "$negative"
    }

    return "$positive"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_max_regression_pct()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the percentage to test."
    exit_if_has_bugs

    is_valid_percentage "$1" || {
        error -ec "$err_argument_value" "The max regression percentage '$1' must be an integer number between 0 and 100."
        return "$negative"
    }

    return "$positive"
}

declare -xr minverTagPrefixRegex
declare -xr minverPrereleaseIdRegex
#---------------------------------------------------------------------------------------------
# @description Tests if a string is a valid MinVer Git tag prefix (e.g. `v` as in `v1.2.3`).
#
# Notes:
#   - Must match `$minverTagPrefixRegex` (`$minverTagPrefixRex` in `_semver.sh`): starts and
#     ends with an alphanumeric or `_`, with `-`, `.`, `/` allowed in between.
#
# @arg $1 string The MinVer tag prefix to validate.
#
# @exitcode positive=0: If the tag prefix is valid.
# @exitcode negative=1: If the tag prefix is invalid.
#
# @example
#   if is_valid_minverTagPrefix "v"; then echo "Valid tag prefix"; fi
#---------------------------------------------------------------------------------------------
function is_valid_minverTagPrefix()
{
    __test_with_regex "$@" "$minverTagPrefixRegex"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_minverTagPrefix()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the MinVer tag prefix to test."
    exit_if_has_bugs

    is_valid_minverTagPrefix "$@" || {
        error -ec "$err_argument_value" "The MinVer tag prefix '$1' is not valid."
        return "$negative"
    }
}

#---------------------------------------------------------------------------------------------
# @description Validates the MinVer prerelease identifier format.
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
#   if is_valid_minverPrereleaseId "alpha.1"; then echo "Valid prerelease ID"; fi
#---------------------------------------------------------------------------------------------
function is_valid_minverPrereleaseId()
{
    __test_with_regex "$@" "$minverPrereleaseIdRegex"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function is_safe_minverPrereleaseId()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the MinVer prerelease ID to test."
    exit_if_has_bugs

    is_valid_minverPrereleaseId "$@" || {
        error -ec "$err_argument_value" "The prerelease ID '$1' is not valid."
        return "$negative"
    }
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function escape_ere()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the string that needs its special ERE characters to be escaped."
    exit_if_has_bugs

    printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function validate_json_schema()
{
    (( $# == 2 ))                      || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                            "  - the JSON file to validate" \
                                                                            "  - the JSON Schema file to validate against"
    [[ ! -v 1 ]] || is_valid_path "$1" || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1 to be a valid path (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_valid_path "$2" || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 2 to be a valid path (provided '${2:-<none>}')."
    exit_if_has_bugs

    local _json_file="$1"
    local _schema_file="$2"

    local -i _rc="$success"

    [[ -s $_json_file ]]               || {
        _rc="$err_not_file"
        error -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1 to be an existing, non-empty JSON file (provided '${_json_file:-<none>}')."
    }
    [[ -s $_schema_file ]]             || {
        _rc="$err_not_file"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 2 to be an existing, non-empty JSON Schema file (provided '${_schema_file:-<none>}')."
    }
    (( _rc == "$success" )) || return "$_rc"

    is_valid_json_file "$_json_file"   || {
        _rc="$err_invalid_json"
        error -ec "$_rc" "The JSON file '$_json_file' is not well-formed."
    }
    is_valid_json_file "$_schema_file" || {
        _rc="$err_invalid_json"
        error -ec "$_rc" "The JSON schema file '$_schema_file' is not well-formed."
    }
    (( _rc == "$success" )) || return "$_rc"

    is_tool_present check-jsonschema || {
        warning "'check-jsonschema' was not found on PATH -- skipping schema validation of '$_json_file'." \
                "Install it with: pip install check-jsonschema"
        return "$success"
    }

    local _output
    _output=$(check-jsonschema --schemafile "$_schema_file" "$_json_file" 2>&1) || {
        _rc=$err_invalid_json
        error -ec "$_rc" "'$_json_file' failed validation against the schema in '$_schema_file':" "$_output"
    }

    return "$_rc"
}
