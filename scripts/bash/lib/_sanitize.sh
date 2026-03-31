# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

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
# Summary: Trims leading and trailing whitespace from a string.
# Parameters:
#   1 - The string to trim
# Returns:
#   The trimmed string
# Usage: trimmed=$(trim "  some string  ")
#-------------------------------------------------------------------------------
function ltrim()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim spaces from the left."
        return "$err_invalid_arguments"
    }

    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    printf '%s' "$var"
}

#--------------------------------------------------------------------------------
# Summary: Trims leading and trailing whitespace from a string.
# Parameters:
#   1 - The string to trim
# Returns:
#   The trimmed string
# Usage: trimmed=$(trim "  some string  ")
#-------------------------------------------------------------------------------
function rtrim()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim spaces from the right."
        return "$err_invalid_arguments"
    }

    local var="$1"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

#--------------------------------------------------------------------------------
# Summary: Trims leading and trailing whitespace from a string.
# Parameters:
#   1 - The string to trim
# Returns:
#   The trimmed string
# Usage: trimmed=$(trim "  some string  ")
#-------------------------------------------------------------------------------
function trim()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to trim spaces from the left and from the right."
        return "$err_invalid_arguments"
    }

    printf '%s' "$(rtrim "$(ltrim "$1")")"
}

#-------------------------------------------------------------------------------
# Summary: Tests if user input is safe by checking for potentially dangerous characters.
# Parameters:
#   1 - input - the input string to test
#   2 - allow_spaces - if true, allows spaces in input (optional, default: false)
# Returns:
#   Exit code: 0 if input is safe, 1 if contains unsafe characters, 2 on invalid arguments
# Usage: if is_safe_input <input> [allow_spaces]; then ... fi
# Example: if is_safe_input "$user_input" true; then echo "Safe input"; fi
# Notes: Rejects characters that could enable command injection: ; | & $ ` \ < > ( ) { } newlines carriage-returns
#-------------------------------------------------------------------------------
function is_safe_input()
{
    (( $# == 1 || $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires one or two arguments (provided $#): the input string to sanitize and an optional flag to allow spaces."
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
        error 3 "${FUNCNAME[0]}(): The input '$input' contains one or more of the unsafe characters '$dangerous_chars'."
        return "$negative"
    fi

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates that the input is a boolean value (true or false).
# Parameters:
#   1 - The input string to test
# Returns:
#   Exit code: 0 if input is a valid boolean, 1 if not, 2 on invalid arguments
# Usage: if validate_boolean "$input"; then ... fi
# Example: if validate_boolean "$reset_flag"; then echo "Valid boolean"; fi
#-------------------------------------------------------------------------------
function validate_boolean()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the boolean value to validate."
        return "$err_invalid_arguments"
    }

    is_boolean "$1"
}

#-------------------------------------------------------------------------------
# Summary: Validates that the input is a boolean value (true or false).
# Parameters:
#   1 - The input string to test
# Returns:
#   Exit code: 0 if input is a valid boolean, 1 if not, 2 on invalid arguments
# Usage: if is_safe_boolean "$input"; then ... fi
# Example: if is_safe_boolean "$reset_flag"; then echo "Valid boolean"; fi
#-------------------------------------------------------------------------------
function is_safe_boolean()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the boolean value to test."
        return "$err_invalid_arguments"
    }
    validate_boolean "$1" || {
        error 3 "${FUNCNAME[0]}(): The input '$1' is not a valid boolean. Expected 'true' or 'false'."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates that the input is an integer value.
# Parameters:
#   1 - The input string to test
# Returns:
#   Exit code: 0 if input is a valid integer, 1 if not, 2 on invalid arguments
# Usage: if is_safe_integer "$input"; then ... fi
# Example: if is_safe_integer "$count"; then echo "Valid integer"; fi
#-------------------------------------------------------------------------------
function is_safe_integer()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the integer value to test."
        return "$err_invalid_arguments"
    }
    validate_integer "$1" || {
        error 3 "${FUNCNAME[0]}(): The input '$1' is not a valid integer."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates file paths to prevent directory traversal and dangerous patterns.
# Parameters:
#   1 - path - the file path to test (should be relative)
# Returns:
#   Exit code: 0 if safe path, 1 if contains unsafe characters, 2 on invalid arguments
# Usage: if is_safe_path <path>; then ... fi
# Example: if is_safe_path "config/settings.json"; then echo "Safe path"; fi
# Notes: Rejects paths with: .. (traversal), leading / (absolute), and $ ` ; characters.
#-------------------------------------------------------------------------------
function is_safe_path()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
        return "$err_invalid_arguments"
    }

    local path="$1"

    # Reject paths with directory traversal
    [[ ! "$path" =~ \.\. ]] || {
        error "The path '$path' contains directory traversal sequences."
        return "$negative"
    }

    # Reject absolute paths starting with /
    [[ ! "$path" =~ ^/ ]] || {
        error "The path '$path' is an absolute path, which is not allowed."
        return "$negative"
    }

    # Reject paths with dangerous characters
    [[ ! "$path" =~ [\$\`\;] ]] || {
        error "The path '$path' contains one or more unsafe characters: \$, \`, ;"
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates that a path is safe and exists.
# Parameters:
#   1 - path - the file or directory path to test
# Returns:
#   Exit code: 0 if safe and exists, 1 if unsafe or doesn't exist, 2 on invalid arguments
# Dependencies: is_safe_path
# Usage: if is_safe_existing_path <path>; then ... fi
# Example: if is_safe_existing_path "$config_file"; then source "$config_file"; fi
#-------------------------------------------------------------------------------
function is_safe_existing_path()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
        return "$err_invalid_arguments"
    }

    is_safe_path "$1" || return "$negative"

    [[ -e "$1" ]] || {
        error "The path '$1' does not exist."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates that a path is safe, exists, and is a directory.
# Parameters:
#   1 - path - the directory path to test
# Returns:
#   Exit code: 0 if safe, exists, and is directory, 1 otherwise, 2 on invalid arguments
# Dependencies: is_safe_existing_path
# Usage: if is_safe_existing_directory <path>; then ... fi
# Example: if is_safe_existing_directory "$build_dir"; then cd "$build_dir"; fi
#-------------------------------------------------------------------------------
function is_safe_existing_directory()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the directory path to test."
        return "$err_invalid_arguments"
    }

    is_safe_existing_path "$1" || return "$negative"

    [[ -d "$1" ]] || {
        error "The path '$1' is not a directory."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates that a path is safe, exists, and is a non-empty file.
# Parameters:
#   1 - path - the file path to test
# Returns:
#   Exit code: 0 if safe, exists, and is non-empty file, 1 otherwise, 2 on invalid arguments
# Dependencies: is_safe_existing_path
# Usage: if is_safe_existing_file <path>; then ... fi
# Example: if is_safe_existing_file "$script"; then bash "$script"; fi
#-------------------------------------------------------------------------------
function is_safe_existing_file()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the file path to test."
        return "$err_invalid_arguments"
    }

    is_safe_existing_path "$1" || return "$negative"

    [[ -s "$1" ]] || {
        error "The path '$1' is not a file or is empty."
        return "$negative"
    }

    return "$positive"
}

declare -xr jq_empty='. == null or . == "" or length == 0'
declare -xr jq_array_strings='type == "array" and all(type == "string")'
declare -xr jq_array_strings_has_empty="any(. == \"\")"
declare -xr jq_array_strings_nonempty='type == "array" and length > 0 and all(type == "string") and all(length > 0)'

#-------------------------------------------------------------------------------
# Summary: Validates and normalizes a JSON array of strings or a single JSON
#   string to a JSON array of non-empty, trimmed strings.
#   Also, checks each item's safety using the provided validator function.
# Parameters:
#   1 - JSON array or a single string (the string will be converted to single-item JSON array)
#   2 - default_array - default value if $1 is empty string or empty array
#   3 - is_safe_item - name of function to validate each array item
# Returns:
#   Exit code: 0 if valid and all items safe, 1 if invalid or items unsafe, 2 on
#     invalid arguments or jq errors
#   stdout: the normalized JSON array: all unnecessary spaces from the array and
#     the elements trimmed
# Dependencies: jq, warning_var
# Usage: if array=$(is_safe_json_array "$array" '[]' is_safe_existing_file); then ... fi
# Example: runners=$(is_safe_json_array "$runners" '["ubuntu-latest"]' is_safe_runner_os)
#-------------------------------------------------------------------------------
function is_safe_json_array()
{
    (( $# == 3 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly three arguments (provided $#):"$'\n' \
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
        error "'$input' is not a valid JSON: '$1'"
        return "$err_invalid_arguments"
    }

    # validate each item in the array
    while read -r item; do
        $is_safe_item_fn "$item" || return "$negative"
    done < <(jq -r '.[]' <<< "$output")

    echo "$output"
    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates that a runner OS name is in the allowed list of GitHub Actions runners.
# Parameters:
#   1 - runner_os - runner OS name to validate
# Returns:
#   Exit code: 0 if valid runner OS, 1 if invalid, 2 on invalid arguments
# Usage: if is_safe_runner_os <runner_os>; then ... fi
# Example: if is_safe_runner_os "ubuntu-latest"; then echo "Valid runner"; fi
# Notes: Allowed values defined in $allowed_runners_os array.
#-------------------------------------------------------------------------------
function is_safe_runner_os()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the runner OS to test."
        return "$err_invalid_arguments"
    }

    local runner_os="$1"

    [[ -n "$runner_os" ]] || {
        error "The runner OS name is empty."
        return "$err_invalid_arguments"
    }
    is_in "$runner_os" "${allowed_runners_os[@]}" || {
        error "The runner OS '$runner_os' is not allowed. Valid options: ${allowed_runners_os[*]}."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates a "reason" text input for safety and length constraints.
# Parameters:
#   1 - reason - the reason text to validate
# Returns:
#   Exit code: 0 if safe, 1 if unsafe or too long, 2 on invalid arguments
# Dependencies: is_safe_input
# Usage: if is_safe_reason <reason>; then ... fi
# Example: if is_safe_reason "$user_reason"; then log_reason "$user_reason"; fi
# Notes: Maximum length 200 characters. Allows spaces but rejects shell meta-characters and command-like patterns.
#-------------------------------------------------------------------------------
function is_safe_reason()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the reason text to test."
        return "$err_invalid_arguments"
    }

    local reason="$1"
    local max_length=200

    # Check length
    (( ${#reason} <= max_length )) || {
        error "The reason is too long. Maximum length is $max_length characters."
        return "$negative"
    }

    # Allow spaces but reject dangerous shell meta-characters
    is_safe_input "$reason" true || {
        return "$negative"
    }

    # Reject if it looks like a command (starts with -, /, .)
    [[ "$reason" =~ ^[-/.] ]] && {
        error "The reason '$reason' appears to be a command or contains unsafe characters."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates NuGet server URL or known server name.
# Parameters:
#   1 - server - NuGet server URL or name to validate
# Returns:
#   Exit code: 0 if valid, 1 if invalid, 2 on invalid arguments
# Usage: if is_valid_nuget_server <server>; then ... fi
# Example: if is_valid_nuget_server "nuget"; then echo "Valid server"; fi
# Notes: Accepts "nuget", "github", or valid http(s) URLs matching $nugetServersRegex.
#-------------------------------------------------------------------------------
function is_valid_nuget_server()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the NuGet server to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ $nugetServersRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Validates NuGet server URL or known server name.
# Parameters:
#   1 - server - NuGet server URL or name to validate
# Returns:
#   Exit code: 0 if valid, 1 if invalid, 2 on invalid arguments
# Usage: if is_safe_nuget_server <server>; then ... fi
# Example: if is_safe_nuget_server "nuget"; then echo "Valid server"; fi
# Notes: Accepts "nuget", "github", or valid http(s) URLs matching $nugetServersRegex.
#-------------------------------------------------------------------------------
function is_safe_nuget_server()
{
    is_valid_nuget_server "$@"
}

#-------------------------------------------------------------------------------
# Summary: Validates NuGet server variable and sets to default if empty.
# Parameters:
#   1 - server (nameref!) - name of variable containing NuGet server
#   2 - default_server - default server value (optional, default: "nuget")
# Returns:
#   Exit code: 0 on success, 1 if server invalid, 2 on invalid arguments or bad default
# Side Effects: Sets server variable to default if empty
# Dependencies: warning_var
# Usage: validate_nuget_server <server_var_name> [default_server]
# Example: validate_nuget_server nuget_server "github"
#-------------------------------------------------------------------------------
function validate_nuget_server()
{
    (( $# >= 1 && $# <= 2 )) || {
        error 3 "${FUNCNAME[0]}() requires at least one or two arguments (provided $#): the NAME OF THE VARIABLE containing the NuGet server to validate and an optional default value for the NuGet server."
        return "$err_invalid_arguments"
    }
     [[ $1 =~ $varNameRegex ]] || {
        error 3 "${FUNCNAME[0]}() requires a non-empty variable name as argument."
        return "$err_invalid_nameref"
    }

    local -n server=$1
    local default_server=${2:-"nuget"}

    [[ $default_server =~ $nugetServersRegex ]] || {
        error "Invalid default NuGet server: $default_server."
        return "$err_invalid_arguments"
    }

    [[ -n "$server" ]] || {
        warning_var "server" "No NuGet server configured." "$default_server"
        return "$positive"
    }

    [[ "$server" =~ $nugetServersRegex ]] || {
        error "Invalid NuGet server: $server."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates that a configuration name is a valid identifier.
# Parameters:
#   1 - configuration - configuration name to validate
# Returns:
#   Exit code: 0 if valid configuration name, 1 if invalid, 2 if invalid number of arguments
# Usage: if is_valid_configuration <config_name>; then ... fi
# Example: if is_valid_configuration "$build_config"; then echo "Valid config"; fi
# Notes: Must match pattern [A-Za-z_][A-Za-z0-9_]* (valid C-style identifier).
#-------------------------------------------------------------------------------
function is_valid_configuration()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the configuration variable to test."
        return "$err_invalid_arguments"
    }

    [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

#-------------------------------------------------------------------------------
# Summary: Validates that a configuration name is a valid identifier.
# Parameters:
#   1 - configuration - configuration name to validate
# Returns:
#   Exit code: 0 if valid configuration name, 1 if invalid, 2 if invalid number of arguments
# Usage: if is_safe_configuration <config_name>; then ... fi
# Example: if is_safe_configuration "$build_config"; then echo "Valid config"; fi
# Notes: Must match pattern [A-Za-z_][A-Za-z0-9_]* (valid C-style identifier).
#-------------------------------------------------------------------------------
function is_safe_configuration()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the configuration variable to test."
        return "$err_invalid_arguments"
    }

    is_valid_configuration "$1" || {
        error "The configuration '$1' is not valid."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates preprocessor symbols and formats them for passing to 'dotnet build'.
# Parameters:
#   1 - symbols (nameref!) - name of variable containing space/comma/colon/semicolon-separated symbols
# Returns:
#   Exit code: 0 if all symbols valid, 1 if any invalid, 2 on invalid arguments
# Side Effects: Reformats symbols variable to semicolon-separated list
# Usage: validate_preprocessor_symbols <symbols_var_name>
# Example:
#   preproc="DEBUG TRACE"
#   validate_preprocessor_symbols preproc
#   # preproc becomes: "DEBUG;TRACE"
# Notes: Each symbol must match [A-Za-z_][A-Za-z0-9_]*.
#-------------------------------------------------------------------------------
function validate_preprocessor_symbols()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires one argument (provided $#): the NAME of the variable containing the preprocessor symbols to test."
        return "$err_invalid_arguments"
    }
    [[ $1 =~ $varNameRegex ]] || {
        error 3 "${FUNCNAME[0]}() requires a non-empty variable name as argument."
        return "$err_invalid_nameref"
    }

    local -n symbols=$1
    local -a symbol_array=()

    [[ -z $symbols ]] && return "$positive"

    IFS=' ,:;' read -ra symbol_array <<< "$symbols"

    local bad=false
    local s=''
    for symbol in "${symbol_array[@]}"; do
        [[ -z $symbol ]] && continue
        if [[ "$symbol" =~ $varNameRegex ]]; then
            [[ -z $s ]] && s="$symbol" || s="$s;$symbol"
        else
            error "The pre-processor symbol '$symbol' is not valid."
            bad=true
        fi
    done

    "$bad" && return "$negative"

    symbols=$s
    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates that a given value is a valid percentage (0-100).
# Parameters:
#   1 - percentage - the percentage to validate
# Returns:
#   Exit code: 0 if valid percentage, 1 if invalid, 2 on invalid arguments
# Usage: if is_valid_percentage <percentage>; then ... fi
# Example: if is_valid_percentage "50"; then echo "Valid percentage"; fi
# Notes: Must be an integer between 0 and 100.
#-------------------------------------------------------------------------------
function is_valid_percentage()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires one argument (provided $#): the percentage to test."
        return "$err_invalid_arguments"
    }

    is_natural "$1" && (( $1 >= 0 && $1 <= 100 ))
}

#-------------------------------------------------------------------------------
# Summary: Validates minimum coverage percentage input.
# Parameters:
#   1 - min_coverage_pct - minimum coverage percentage to validate
# Returns:
#   Exit code: 0 if valid percentage, 1 if invalid, 2 on invalid arguments
# Usage: if is_safe_min_coverage_pct <min_coverage_pct>; then ... fi
# Example: if is_safe_min_coverage_pct "80"; then echo "Valid coverage percentage"; fi
# Notes: Must be an integer between 0 and 100.
#-------------------------------------------------------------------------------
function is_safe_min_coverage_pct()
{
    is_valid_percentage "$@" || {
        error "The min coverage percentage '$1' must be an integer number between 0 and 100."
        return "$negative"
    }

    return "$positive"
}

#-------------------------------------------------------------------------------
# Summary: Validates maximum regression percentage input.
# Parameters:
#   1 - max_regression_pct - maximum regression percentage to validate
# Returns:
#   Exit code: 0 if valid percentage, 1 if invalid, 2 on invalid arguments
# Usage: if is_safe_max_regression_pct <max_regression_pct>; then ... fi
# Example: if is_safe_max_regression_pct "10"; then echo "Valid regression percentage"; fi
# Notes: Must be an integer between 0 and 100.
function is_safe_max_regression_pct()
{
    is_valid_percentage "$@" || {
        error "The max regression percentage '$1' must be between 0 and 100."
        return "$negative"
    }

    return "$positive"
}

declare -xr minverPrereleaseIdRegex
declare -xr semverRex

#-------------------------------------------------------------------------------
# Summary: Validates MinVer prerelease identifier format.
# Parameters:
#   1 - prerelease_id - MinVer prerelease ID to validate
# Returns:
#   Exit code: 0 if valid, 1 if invalid, 2 on invalid arguments
# Usage: if is_valid_minverPrereleaseId <id>; then ... fi
# Example: if is_valid_minverPrereleaseId "alpha.1"; then echo "Valid prerelease ID"; fi
# Notes: Must match $minverPrereleaseIdRegex (same as semver prerelease label format).
#-------------------------------------------------------------------------------
function is_valid_minverPrereleaseId()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires one argument (provided $#): the MinVer prerelease ID to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ $minverPrereleaseIdRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Validates MinVer prerelease identifier format.
# Parameters:
#   1 - prerelease_id - MinVer prerelease ID to validate
# Returns:
#   Exit code: 0 if valid, 1 if invalid, 2 on invalid arguments
# Usage: if is_safe_minverPrereleaseId <id>; then ... fi
# Example: if is_safe_minverPrereleaseId "alpha.1"; then echo "Valid prerelease ID"; fi
# Notes: Must match $minverPrereleaseIdRegex (same as semver prerelease label format).
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
# Summary: Validates .NET version input format.
# Parameters:
#   1 - version - .NET version string to validate
# Returns:
#   Exit code: 0 if valid, 1 if invalid, 2 on invalid arguments
# Usage: if is_valid_dotnet_version <version>; then ... fi
# Example: if is_valid_dotnet_version "10.0.100-preview.1.25120.13"; then echo "Valid .NET version"; fi
# Notes: Must match $dotnet_regex. The dotnet-version input supports the following syntax (from [actions/setup-dotnet](https://github.com/actions/setup-dotnet)):
#   - A.B.C (e.g 9.0.308, 10.0.100-preview.1.25120.13) - installs the exact version of .NET SDK semver 2.0 format
#   - A or A.x (e.g. 8, 8.x) - the latest minor version of the specific .NET SDK, including prerelease versions (preview, rc)
#   - A.B or A.B.x (e.g. 8.0, 8.0.x) - the latest patch version of the specific .NET SDK, including prerelease versions (preview, rc)
#   - A.B.Cxx (e.g. 8.0.4xx) - the latest version of the specific SDK release, including prerelease versions (preview, rc).
#-------------------------------------------------------------------------------
function is_valid_dotnet_version()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires one argument (provided $#): the .NET version to test."
        return "$err_invalid_arguments"
    }

    [[ "$1" =~ $dotnet_regex ]]
}

#-------------------------------------------------------------------------------
# Summary: Validates .NET version input format.
# Parameters:
#   1 - version - .NET version string to validate
# Returns:
#   Exit code: 0 if valid, 1 if invalid, 2 on invalid arguments
# Usage: if is_safe_dotnet_version <version>; then ... fi
# Example: if is_safe_dotnet_version "10.0.100-preview.1.25120.13"; then echo "Valid .NET version"; fi
# Notes: Must match $dotnet_regex. The dotnet-version input supports the following syntax (from [actions/setup-dotnet](https://github.com/actions/setup-dotnet)):
#   - A.B.C (e.g 9.0.308, 10.0.100-preview.1.25120.13) - installs the exact version of .NET SDK semver 2.0 format
#   - A or A.x (e.g. 8, 8.x) - the latest minor version of the specific .NET SDK, including prerelease versions (preview, rc)
#   - A.B or A.B.x (e.g. 8.0, 8.0.x) - the latest patch version of the specific .NET SDK, including prerelease versions (preview, rc)
#   - A.B.Cxx (e.g. 8.0.4xx) - the latest version of the specific SDK release, including prerelease versions (preview, rc).
#-------------------------------------------------------------------------------
function is_safe_dotnet_version()
{
    is_valid_dotnet_version "$@"
}
