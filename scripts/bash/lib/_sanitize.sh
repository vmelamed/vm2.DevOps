# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines functions for sanitizing and validating user input, esp. in GitHub Actions workflows.
# It includes functions for trimming whitespace and checking for safe input.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_SANITIZE_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_SANITIZE_SH_LOADED=1

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative
declare -rxi err_invalid_arguments
declare -rxi err_invalid_nameref
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_found
declare -rxi err_not_file
declare -rxi err_not_directory
declare -rxi err_unsafe_argument
declare -rxi err_invalid_path

declare -rx varNameRegex

declare -xra allowed_runners_os=(
    "ubuntu-latest"
    "ubuntu-22.04"
    "ubuntu-20.04"
    "windows-latest"
    "windows-2022"
    "windows-2019"
    "macos-latest"
    "macos-12"
    "macos-11")

declare -xr nugetServersRegex
declare -xr varNameRegex

#--------------------------------------------------------------------------------
# @description Trims leading whitespace from a string.
#
# @arg $1 string The string to trim.
#
# @exitcode 0 Always (on valid arguments).
# @exitcode 2 If the number of arguments is not exactly one.
#
# @stdout The string with leading whitespace removed.
#
# @example
#   trimmed=$(ltrim "  some string  ")
#-------------------------------------------------------------------------------
function ltrim()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim spaces from the left."
        return "$err_invalid_arguments"
    }

    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    printf '%s' "$var"
}

#--------------------------------------------------------------------------------
# @description Trims trailing whitespace from a string.
#
# @arg $1 string The string to trim.
#
# @exitcode 0 Always (on valid arguments).
# @exitcode 2 If the number of arguments is not exactly one.
#
# @stdout The string with trailing whitespace removed.
#
# @example
#   trimmed=$(rtrim "  some string  ")
#-------------------------------------------------------------------------------
function rtrim()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim spaces from the right."
        return "$err_invalid_arguments"
    }

    local var="$1"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

#--------------------------------------------------------------------------------
# @description Trims leading and trailing whitespace from a string.
#
# @arg $1 string The string to trim.
#
# @exitcode 0 Always (on valid arguments).
# @exitcode 2 If the number of arguments is not exactly one.
#
# @stdout The string with leading and trailing whitespace removed.
#
# @example
#   trimmed=$(trim "  some string  ")
#-------------------------------------------------------------------------------
function trim()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim spaces from the left and from the right."
        return "$err_invalid_arguments"
    }

    printf '%s' "$(rtrim "$(ltrim "$1")")"
}

#-------------------------------------------------------------------------------
# @description Tests if user input is safe by checking for potentially dangerous characters.
#
# Notes:
#   - Rejects characters that could enable command injection: `; | & $ \` \ < > ( ) { }`, newlines, and
#     carriage returns.
#   - An empty input is considered safe.
#
# @arg $1 string The input string to test.
# @arg $2 bool If true, allows spaces in the input (optional, default: false).
#
# @exitcode 0 If the input is safe.
# @exitcode 1 If the input contains one or more unsafe characters.
# @exitcode 2 If the number of arguments is not one or two.
#
# @example
#   if is_safe_input "$user_input" true; then echo "Safe input"; fi
#-------------------------------------------------------------------------------
function is_safe_input()
{
    (( $# == 1 || $# == 2 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one or two arguments (provided $#): the input string to sanitize and an optional flag to allow spaces."
        return "$err_invalid_arguments"
    }

    local input="$1"
    local allow_spaces="${2:-false}"

    # Empty input is considered safe
    if [[ -z "$input" ]]; then
        return "$positive"
    fi

    # Dangerous characters that could enable command injection
    local dangerous_chars

    $allow_spaces && dangerous_chars=$'[;|&$`\\\\<>(){}\n\r]' || dangerous_chars=$'[;|&$`\\\\<>(){}\n\r ]'

    if [[ "$input" =~ $dangerous_chars ]]; then
        error -sd 3 -ec "$err_unsafe_argument" "${FUNCNAME[0]}(): The input '$input' contains one or more of the unsafe characters '$dangerous_chars'."
        return "$negative"
    fi

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates that the input is a boolean value (`true` or `false`).
#
# @arg $1 string The input string to test.
#
# @exitcode 0 If the input is a valid boolean.
# @exitcode 1 If the input is not a valid boolean.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if validate_boolean "$reset_flag"; then echo "Valid boolean"; fi
#-------------------------------------------------------------------------------
function validate_boolean()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the boolean value to validate."
        return "$err_invalid_arguments"
    }

    is_boolean "$1"
}

#-------------------------------------------------------------------------------
# @description Validates that the input is a boolean value (`true` or `false`).
#
# @arg $1 string The input string to test.
#
# @exitcode 0 If the input is a valid boolean.
# @exitcode 1 If the input is not a valid boolean.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_boolean "$reset_flag"; then echo "Valid boolean"; fi
#-------------------------------------------------------------------------------
function is_safe_boolean()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the boolean value to test."
        return "$err_invalid_arguments"
    }
    is_boolean "$1" || {
        error -sd 3 -ec "$err_argument_type" "${FUNCNAME[0]}(): The input '$1' is not a valid boolean. Expected 'true' or 'false'."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates that the input is an integer value.
#
# @arg $1 string The input string to test.
#
# @exitcode 0 If the input is a valid integer.
# @exitcode 1 If the input is not a valid integer.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_integer "$count"; then echo "Valid integer"; fi
#-------------------------------------------------------------------------------
function is_safe_integer()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the integer value to test."
        return "$err_invalid_arguments"
    }
    is_integer "$1" || {
        error -sd 3 -ec "$err_argument_type" "${FUNCNAME[0]}(): The input '$1' is not a valid integer."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates file paths to prevent directory traversal and dangerous patterns.
#
# Notes:
#   - Rejects paths containing `..` (traversal), a leading `/` (absolute path), or the characters
#     `$`, `` ` ``, `;`.
#
# @arg $1 string The file path to test (should be relative).
#
# @exitcode 0 If the path is safe.
# @exitcode 1 If the path contains unsafe characters or patterns.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_path "config/settings.json"; then echo "Safe path"; fi
#-------------------------------------------------------------------------------
function is_safe_path()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
        return "$err_invalid_arguments"
    }

    local path="$1"

    # Reject paths with directory traversal
    [[ ! "$path" =~ \.\. ]] || {
        error -ec "$err_unsafe_argument" "The path '$path' contains directory traversal sequences."
        return "$negative"
    }

    # Reject absolute paths starting with /
    [[ ! "$path" =~ ^/ ]] || {
        error -ec "$err_unsafe_argument" "The path '$path' is an absolute path, which is not allowed."
        return "$negative"
    }

    # Reject paths with dangerous characters
    [[ ! "$path" =~ [\$\`\;] ]] || {
        error -ec "$err_unsafe_argument" "The path '$path' contains one or more unsafe characters: \$, \`, ;"
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates that a path is safe and exists. Depends on `is_safe_path`.
#
# @arg $1 string The file or directory path to test.
#
# @exitcode 0 If the path is safe and exists.
# @exitcode 1 If the path is unsafe or does not exist.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_existing_path "$config_file"; then source "$config_file"; fi
#-------------------------------------------------------------------------------
function is_safe_existing_path()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
        return "$err_invalid_arguments"
    }

    is_safe_path "$1" || return "$negative"

    [[ -e "$1" ]] || {
        error -ec "$err_invalid_path" "The path '$1' does not exist."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates that a path is safe, exists, and is a directory. Depends on
#   `is_safe_existing_path`.
#
# @arg $1 string The directory path to test.
#
# @exitcode 0 If the path is safe, exists, and is a directory.
# @exitcode 1 Otherwise.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_existing_directory "$build_dir"; then cd "$build_dir"; fi
#-------------------------------------------------------------------------------
function is_safe_existing_directory()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the directory path to test."
        return "$err_invalid_arguments"
    }

    is_safe_existing_path "$1" || return "$negative"

    [[ -d "$1" ]] || {
        error -ec "$err_not_directory" "The path '$1' is not a directory."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates that a path is safe, exists, and is a non-empty file. Depends on
#   `is_safe_existing_path`.
#
# @arg $1 string The file path to test.
#
# @exitcode 0 If the path is safe, exists, and is a non-empty file.
# @exitcode 1 Otherwise.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_existing_file "$script"; then bash "$script"; fi
#-------------------------------------------------------------------------------
function is_safe_existing_file()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
        return "$err_invalid_arguments"
    }

    is_safe_existing_path "$1" || return "$negative"

    [[ -s "$1" ]] || {
        error -ec "$err_not_file" "The path '$1' is not a file or is empty."
        return "$negative"
    }

    return "$positive"
}

declare -xr jq_empty='. == null or . == "" or length == 0'
declare -xr jq_array_strings='type == "array" and all(type == "string")'
declare -xr jq_array_strings_has_empty="any(. == \"\")"
declare -xr jq_array_strings_nonempty='type == "array" and length > 0 and all(type == "string") and all(length > 0)'

#-------------------------------------------------------------------------------
# @description Validates and normalizes a JSON array of strings, or a single JSON string, into a
#   JSON array of non-empty, trimmed strings. Also checks each item's safety using the provided
#   validator function.
#
# @arg $1 string A JSON array or a single string (a plain string is converted to a single-item
#   JSON array).
# @arg $2 string The default value to use if $1 is an empty string or an empty array.
# @arg $3 string The name of the function to validate each item in the array.
#
# @exitcode 0 If the input is valid JSON and all items are safe.
# @exitcode 1 If any item is unsafe.
# @exitcode 2 If the number of arguments is not exactly three.
# @exitcode 4 If $1 is not valid JSON, or is JSON of the wrong shape (`err_argument_value`).
#
# @stdout The normalized JSON array, with unnecessary whitespace removed and each element trimmed.
#
# @example
#   runners=$(is_safe_json_array "$runners" '["ubuntu-latest"]' is_safe_runner_os)
#-------------------------------------------------------------------------------
function is_safe_json_array()
{
    (( $# == 3 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly three arguments (provided $#):"$'\n' \
              "  \$1: the JSON"$'\n' \
              "  \$2: the default value to use if the variable is unbound or empty, and"$'\n' \
              "  \$3: the name of the function to validate each item in the array."
        return "$err_invalid_arguments"
    }

    local default="$2"
    local is_safe_item_fn=$3

    local input output
    input="$(trim "$1")"
    [[ -n "$input" ]] || input=$default

    # validate and normalize JSON
    output="$(
        jq -c '
            if type == "boolean" or type == "number" or type == "object" then
                error("The input cannot be boolean, number, object, or null. It must be a JSON array of non-empty strings or a JSON string.")
            elif type == "null" then
                []
            elif type == "string" and (. | tostring | trim | length > 0) then
                [ . | tostring | trim ]
            elif type=="array" and all(type=="string") and all(. | trim | length > 0) then
                map( . | tostring | trim )
            else
                error("The input must be a JSON array of non-empty strings or a JSON string.")
            end ' <<< "$input"
    )" || {
        error -ec "$err_argument_value" "'$input' is not a valid JSON: '$1'"
        return "$err_argument_value"
    }

    # validate each item in the array
    while read -r item; do
        $is_safe_item_fn "$item" || return "$negative"
    done < <(jq -r '.[]' <<< "$output")

    echo "$output"
    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates that a runner OS name is in the allowed list of GitHub Actions runners.
#
# Notes:
#   - The allowed values are defined in the `$allowed_runners_os` array.
#
# @arg $1 string The runner OS name to validate.
#
# @exitcode 0 If the runner OS is valid.
# @exitcode 1 If the runner OS is empty or not in the allowed list.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_runner_os "ubuntu-latest"; then echo "Valid runner"; fi
#-------------------------------------------------------------------------------
function is_safe_runner_os()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the runner OS to test."
        return "$err_invalid_arguments"
    }

    local runner_os="$1"

    [[ -n "$runner_os" ]] || {
        error -ec "$err_argument_value" "The runner OS name is empty."
        return "$err_argument_value"
    }
    is_in "$runner_os" "${allowed_runners_os[@]}" || {
        error -ec "$err_argument_value" "The runner OS '$runner_os' is not allowed. Valid options: ${allowed_runners_os[*]}."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates a "reason" text input for safety and length constraints. Depends on
#   `is_safe_input`.
#
# Notes:
#   - Maximum length is 200 characters.
#   - Allows spaces but rejects shell meta-characters and command-like patterns (input starting
#     with `-`, `/`, or `.`).
#
# @arg $1 string The reason text to validate.
#
# @exitcode 0 If the reason is safe.
# @exitcode 1 If the reason is too long, contains unsafe characters, or looks like a command.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_reason "$user_reason"; then log_reason "$user_reason"; fi
#-------------------------------------------------------------------------------
function is_safe_reason()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the reason text to test."
        return "$err_invalid_arguments"
    }

    local rsn="$1"
    local max_length=200

    # Check length
    (( ${#rsn} <= max_length )) || {
        error -ec "$err_argument_value" "The reason is too long. Maximum length is $max_length characters."
        return "$negative"
    }

    # Allow spaces but reject dangerous shell meta-characters
    is_safe_input "$rsn" true || {
        return "$negative"
    }

    # Reject if it looks like a command (starts with -, /, .)
    [[ "$rsn" =~ ^[-/.] ]] && {
        error -ec "$err_unsafe_argument" "The reason '$rsn' appears to be a command or contains unsafe characters."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates a NuGet server URL or known server name.
#
# Notes:
#   - Accepts `nuget`, `github`, or a valid http(s) URL matching `$nugetServersRegex`.
#
# @arg $1 string The NuGet server URL or name to validate.
#
# @exitcode 0 If the server is valid.
# @exitcode 1 If the server is invalid.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_valid_nuget_server "nuget"; then echo "Valid server"; fi
#-------------------------------------------------------------------------------
function is_valid_nuget_server()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the NuGet server to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ $nugetServersRegex ]]
}

#-------------------------------------------------------------------------------
# @description Validates a NuGet server URL or known server name. Delegates to
#   `is_valid_nuget_server`.
#
# Notes:
#   - Accepts `nuget`, `github`, or a valid http(s) URL matching `$nugetServersRegex`.
#
# @arg $1 string The NuGet server URL or name to validate.
#
# @exitcode 0 If the server is valid.
# @exitcode 1 If the server is invalid.
#
# @example
#   if is_safe_nuget_server "nuget"; then echo "Valid server"; fi
#-------------------------------------------------------------------------------
function is_safe_nuget_server()
{
    is_valid_nuget_server "$@"
}

#-------------------------------------------------------------------------------
# @description Validates a NuGet server variable and sets it to a default value if empty. Depends
#   on `warning_var`.
#
# Notes:
#   - Sets the referenced `server` variable to the default value if it was empty.
#
# @arg $1 nameref Name of the variable containing the NuGet server to validate; updated in place.
# @arg $2 string The default server value (optional, default: `nuget`).
#
# @exitcode 0 On success.
# @exitcode 1 If the server value is invalid.
# @exitcode 2 If the number of arguments is not one or two, if $1 is not a valid variable name, or
#   if the default server value is invalid.
#
# @example
#   validate_nuget_server nuget_server "github"
#-------------------------------------------------------------------------------
function validate_nuget_server()
{
    local -i rc="$success"

    (( $# >= 1 && $# <= 2 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires at least one or two arguments (provided $#): the NAME OF THE VARIABLE containing the NuGet server to validate and an optional default value for the NuGet server."
    }
    [[ $# -lt 1 || $1 =~ $varNameRegex ]] || {
        rc="$err_invalid_nameref"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires a non-empty variable name as argument."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local -n server=$1
    local default_server=${2:-"nuget"}

    [[ $default_server =~ $nugetServersRegex ]] || {
        error -ec "$err_argument_value" "Invalid default NuGet server: $default_server."
        return "$err_invalid_arguments"
    }

    [[ -n "$server" ]] || {
        warning_var "server" "No NuGet server configured." "$default_server"
        return "$positive"
    }

    [[ "$server" =~ $nugetServersRegex ]] || {
        error -ec "$err_argument_value" "Invalid NuGet server: $server."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates that a configuration name is a valid identifier.
#
# Notes:
#   - Must match the pattern `[A-Za-z_][A-Za-z0-9_]*` (a valid C-style identifier).
#
# @arg $1 string The configuration name to validate.
#
# @exitcode 0 If the configuration name is valid.
# @exitcode 1 If the configuration name is invalid.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_valid_configuration "$build_config"; then echo "Valid config"; fi
#-------------------------------------------------------------------------------
function is_valid_configuration()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the configuration variable to test."
        return "$err_invalid_arguments"
    }

    [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

#-------------------------------------------------------------------------------
# @description Validates that a configuration name is a valid identifier. Depends on
#   `is_valid_configuration`.
#
# Notes:
#   - Must match the pattern `[A-Za-z_][A-Za-z0-9_]*` (a valid C-style identifier).
#
# @arg $1 string The configuration name to validate.
#
# @exitcode 0 If the configuration name is valid.
# @exitcode 1 If the configuration name is invalid.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_configuration "$build_config"; then echo "Valid config"; fi
#-------------------------------------------------------------------------------
function is_safe_configuration()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the configuration variable to test."
        return "$err_invalid_arguments"
    }

    is_valid_configuration "$1" || {
        error -ec "$err_argument_value" "The configuration '$1' is not valid."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates preprocessor symbols and formats them for passing to `dotnet build`.
#
# Notes:
#   - Reformats the referenced `symbols` variable in place into a semicolon-separated list.
#   - Each symbol must match `[A-Za-z_][A-Za-z0-9_]*`.
#   - Symbols may be separated in the input by spaces, commas, colons, or semicolons.
#
# @arg $1 nameref Name of the variable containing the space/comma/colon/semicolon-separated
#   symbols; updated in place.
#
# @exitcode 0 If all symbols are valid.
# @exitcode 1 If any symbol is invalid.
# @exitcode 2 If the number of arguments is not exactly one, or if $1 is not a valid variable name.
#
# @example
#   preproc="DEBUG TRACE"
#   validate_preprocessor_symbols preproc
#   # preproc becomes: "DEBUG;TRACE"
#-------------------------------------------------------------------------------
function validate_preprocessor_symbols()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the variable containing the preprocessor symbols to test."
    }
    [[ $# -ne 1 || $1 =~ $varNameRegex ]] || {
        rc="$err_invalid_nameref"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires a non-empty variable name as argument."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local -n symbols=$1
    local -a symbol_array=()

    [[ -z $symbols ]] && return "$positive"

    IFS=' ,:;' read -r -a symbol_array <<< "$symbols"

    local bad=false
    local s=''
    for symbol in "${symbol_array[@]}"; do
        [[ -z $symbol ]] && continue
        if [[ "$symbol" =~ $varNameRegex ]]; then
            [[ -z $s ]] && s="$symbol" || s="$s;$symbol"
        else
            error -ec "$err_argument_value" "The pre-processor symbol '$symbol' is not valid."
            bad=true
        fi
    done

    "$bad" && return "$negative"

    symbols=$s
    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates that a given value is a valid percentage (0-100).
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The percentage to validate.
#
# @exitcode 0 If the percentage is valid.
# @exitcode 1 If the percentage is invalid.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_valid_percentage "50"; then echo "Valid percentage"; fi
#-------------------------------------------------------------------------------
function is_valid_percentage()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the percentage to test."
        return "$err_invalid_arguments"
    }

    is_integer "$1" && (( $1 >= 0 && $1 <= 100 ))
}

#-------------------------------------------------------------------------------
# @description Validates minimum coverage percentage input. Depends on `is_valid_percentage`.
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The minimum coverage percentage to validate.
#
# @exitcode 0 If the percentage is valid.
# @exitcode 1 If the percentage is invalid.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_min_coverage_pct "80"; then echo "Valid coverage percentage"; fi
#-------------------------------------------------------------------------------
function is_safe_min_coverage_pct()
{
    is_valid_percentage "$@" || {
        error -ec "$err_argument_type" "The min coverage percentage '$1' must be an integer number between 0 and 100."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Validates maximum regression percentage input. Depends on `is_valid_percentage`.
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The maximum regression percentage to validate.
#
# @exitcode 0 If the percentage is valid.
# @exitcode 1 If the percentage is invalid.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_safe_max_regression_pct "10"; then echo "Valid regression percentage"; fi
#-------------------------------------------------------------------------------
function is_safe_max_regression_pct()
{
    is_valid_percentage "$@" || {
        error -ec "$err_argument_type" "The max regression percentage '$1' must be between 0 and 100."
        return "$negative"
    }

    return "$positive"
}

declare -xr minverPrereleaseIdRegex
declare -xr semverRex

#-------------------------------------------------------------------------------
# @description Validates the MinVer prerelease identifier format.
#
# Notes:
#   - Must match `$minverPrereleaseIdRegex` (the same as the SemVer prerelease label format).
#
# @arg $1 string The MinVer prerelease ID to validate.
#
# @exitcode 0 If the prerelease ID is valid.
# @exitcode 1 If the prerelease ID is invalid.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_valid_minverPrereleaseId "alpha.1"; then echo "Valid prerelease ID"; fi
#-------------------------------------------------------------------------------
function is_valid_minverPrereleaseId()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the MinVer prerelease ID to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ $minverPrereleaseIdRegex ]]
}

#-------------------------------------------------------------------------------
# @description Validates the MinVer prerelease identifier format. Delegates to
#   `is_valid_minverPrereleaseId`.
#
# Notes:
#   - Must match `$minverPrereleaseIdRegex` (the same as the SemVer prerelease label format).
#
# @arg $1 string The MinVer prerelease ID to validate.
#
# @exitcode 0 If the prerelease ID is valid.
# @exitcode 1 If the prerelease ID is invalid.
#
# @example
#   if is_safe_minverPrereleaseId "alpha.1"; then echo "Valid prerelease ID"; fi
#-------------------------------------------------------------------------------
function is_safe_minverPrereleaseId()
{
    is_valid_minverPrereleaseId "$@"
}

# The dotnet-version input supports following syntax:
#
# A.B.C (e.g 9.0.308, 10.0.100-preview.1.25120.13) - installs the exact version of .NET SDK semver 2.0 format
# A or A.x (e.g. 8, 8.x) - the latest minor version of the specific .NET SDK, including prerelease versions (preview, rc)
# A.B or A.B.x (e.g. 8.0, 8.0.x) - the latest patch version of the specific .NET SDK, including prerelease versions (preview, rc)
# A.B.Cxx (e.g. 8.0.4xx) - the latest version of the specific SDK release, including prerelease versions (preview, rc).
declare -xr dotnet_regex="^([0-9]+\\.[0-9]+(\\.x)?)|([0-9]+(\\.x)?)|([0-9]+\\.[0-9]+\\.[0-9]xx)|($semverRex)$"

#-------------------------------------------------------------------------------
# @description Validates the .NET version input format.
#
# Notes:
#   - Must match `$dotnet_regex`. The `dotnet-version` input supports the following syntax (from
#     [actions/setup-dotnet](https://github.com/actions/setup-dotnet)):
#     - `A.B.C` (e.g. `9.0.308`, `10.0.100-preview.1.25120.13`) - installs the exact version of the
#       .NET SDK, SemVer 2.0 format.
#     - `A` or `A.x` (e.g. `8`, `8.x`) - the latest minor version of the specific .NET SDK,
#       including prerelease versions (preview, rc).
#     - `A.B` or `A.B.x` (e.g. `8.0`, `8.0.x`) - the latest patch version of the specific .NET SDK,
#       including prerelease versions (preview, rc).
#     - `A.B.Cxx` (e.g. `8.0.4xx`) - the latest version of the specific SDK release, including
#       prerelease versions (preview, rc).
#
# @arg $1 string The .NET version string to validate.
#
# @exitcode 0 If the version is valid.
# @exitcode 1 If the version is invalid.
# @exitcode 2 If the number of arguments is not exactly one.
#
# @example
#   if is_valid_dotnet_version "10.0.100-preview.1.25120.13"; then echo "Valid .NET version"; fi
#-------------------------------------------------------------------------------
function is_valid_dotnet_version()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the .NET version to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ $dotnet_regex ]]
}

#-------------------------------------------------------------------------------
# @description Validates the .NET version input format. Delegates to `is_valid_dotnet_version`.
#
# Notes:
#   - Must match `$dotnet_regex`. The `dotnet-version` input supports the following syntax (from
#     [actions/setup-dotnet](https://github.com/actions/setup-dotnet)):
#     - `A.B.C` (e.g. `9.0.308`, `10.0.100-preview.1.25120.13`) - installs the exact version of the
#       .NET SDK, SemVer 2.0 format.
#     - `A` or `A.x` (e.g. `8`, `8.x`) - the latest minor version of the specific .NET SDK,
#       including prerelease versions (preview, rc).
#     - `A.B` or `A.B.x` (e.g. `8.0`, `8.0.x`) - the latest patch version of the specific .NET SDK,
#       including prerelease versions (preview, rc).
#     - `A.B.Cxx` (e.g. `8.0.4xx`) - the latest version of the specific SDK release, including
#       prerelease versions (preview, rc).
#
# @arg $1 string The .NET version string to validate.
#
# @exitcode 0 If the version is valid.
# @exitcode 1 If the version is invalid.
#
# @example
#   if is_safe_dotnet_version "10.0.100-preview.1.25120.13"; then echo "Valid .NET version"; fi
#-------------------------------------------------------------------------------
function is_safe_dotnet_version()
{
    is_valid_dotnet_version "$@"
}

#-------------------------------------------------------------------------------
# @description Escapes special characters in a string for use in an extended regular expression
#   (ERE).
#
# Notes:
#   - Escapes the characters that have special meaning in ERE: `[](){}.^$*+?|\`.
#
# @arg $1 string The string to escape.
#
# @exitcode 0 Always (on valid arguments).
# @exitcode 2 If the number of arguments is not exactly one.
#
# @stdout The escaped string, with special ERE characters prefixed by a backslash.
#
# @example
#   escaped=$(escape_ere "some string with special chars.*")
#-------------------------------------------------------------------------------
function escape_ere()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the string that needs its special ERE characters to be escaped."
        return "$err_invalid_arguments"
    }

    printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}
