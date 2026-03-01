# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
fi

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
if ! declare -pF "error" > "$_ignore"; then
    source "${lib_dir}/_diagnostics.sh"
fi
# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
if [[ ! -v "minverTagPrefixRegex" || ! -v "minverPrereleaseIdRegex" ]]; then
    source "${lib_dir}/_semver.sh"
fi

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

declare -xr nugetServersRegex="^(nuget|github|https?://[-a-zA-Z0-9._/]+)$";

#--------------------------------------------------------------------------------
# Summary: Trims leading and trailing whitespace from a string.
# Parameters:
#   1 - The string to trim
# Returns:
#   The trimmed string
# Usage: trimmed=$(trim "  some string  ")
#-------------------------------------------------------------------------------
function ltrim() {
    local var="$*"
    # remove leading whitespace characters
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
function rtrim() {
    local var="$*"
    # remove trailing whitespace characters
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
function trim() {
    printf '%s' "$(rtrim "$(ltrim "$*")")"
}

#-------------------------------------------------------------------------------
# Summary: Tests if user input is safe by checking for potentially dangerous characters.
# Parameters:
#   1 - input - the input string to test
#   2 - allow_spaces - if "true", allows spaces in input (optional, default: "false")
# Returns:
#   Exit code: 0 if input is safe, 1 if contains unsafe characters, 2 on invalid arguments
# Usage: if is_safe_input <input> [allow_spaces]; then ... fi
# Example: if is_safe_input "$user_input" true; then echo "Safe input"; fi
# Notes: Rejects characters that could enable command injection: ; | & $ ` \ < > ( ) { } newlines carriage-returns
#-------------------------------------------------------------------------------
function is_safe_input()
{
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        error "${FUNCNAME[0]}() requires one or two parameters: the input string to sanitize and an optional flag to allow spaces."
        return 2
    fi

    local input="$1"
    local allow_spaces="${2:-false}"

    # Empty input is considered safe
    if [[ -z "$input" ]]; then
        return 0
    fi

    # Dangerous characters that could enable command injection
    local dangerous_chars
    [[ "$allow_spaces" != "true" ]] && dangerous_chars=$'[;|&$`\\\\<>(){}\n\r ]' || dangerous_chars=$'[;|&$`\\\\<>(){}\n\r]'

    if [[ "$input" =~ $dangerous_chars ]]; then
        error "${FUNCNAME[0]}(): The input '$input' contains one or more of the unsafe characters '$dangerous_chars'."
        return 1
    fi

    return 0
}

#-------------------------------------------------------------------------------
# Summary: Validates file paths to prevent directory traversal and dangerous patterns.
# Parameters:
#   1 - path - the file path to test (should be relative)
# Returns:
#   Exit code: 0 if safe path, 1 if contains dangerous patterns, 2 on invalid arguments
# Usage: if is_safe_path <path>; then ... fi
# Example: if is_safe_path "config/settings.json"; then echo "Safe path"; fi
# Notes: Rejects paths with: .. (traversal), leading / (absolute), and $ ` ; characters.
#-------------------------------------------------------------------------------
function is_safe_path()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the file path to test."
        return 2
    fi

    local path="$1"

    # Reject paths with directory traversal
    if [[ "$path" =~ \.\. ]]; then
        error "The path '$path' contains directory traversal sequences."
        return 1
    fi

    # Reject absolute paths starting with /
    if [[ "$path" =~ ^/ ]]; then
        error "The path '$path' is an absolute path, which is not allowed."
        return 1
    fi

    # Reject paths with dangerous characters
    if [[ "$path" =~ [\$\`\;] ]]; then
        error "The path '$path' contains one or more unsafe characters: \$, \`, ;"
        return 1
    fi

    return 0
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the file path to test."
        return 2
    fi

    ! is_safe_path "$1" && return 1


    if [[ ! -e "$1" ]]; then
        error "The path '$1' does not exist."
        return 1
    fi

    return 0
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the directory path to test."
        return 2
    fi

    ! is_safe_existing_path "$1" && return 1

    if [[ ! -d "$1" ]]; then
        error "The path '$1' is not a directory."
        return 1
    fi

    return 0
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the file path to test."
        return 2
    fi

    ! is_safe_existing_path "$1" && return 1

    if [[ ! -s "$1" ]]; then
        error "The path '$1' is not a file or is empty."
        return 1
    fi

    return 0
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
#   1 - JSON array or a single string (will be converted to single-item JSON array)
#   2 - default_array - default value if $1 is empty string or empty array
#   3 - is_safe_item - name of function to validate each array item
# Returns:
#   Exit code: 0 if valid and all items safe, 1 if invalid or items unsafe, 2 on
#     invalid arguments or jq errors
#   stdout: the normalized JSON array: all unnecessary spaces from the array and
#     the elements trimmed
# Dependencies: jq, warning_var
# Usage: if array=$(is_safe_json_array <array> <default> <validator_function>); then ... fi
# Example: runners=$(is_safe_json_array runners '["ubuntu-latest"]' is_safe_runner_os)
#-------------------------------------------------------------------------------
function is_safe_json_array()
{
    if [[ $# -ne 3 ]]; then
        error "${FUNCNAME[0]}() requires exactly three parameters:"$'\n' \
              "  \$1: the JSON"$'\n' \
              "  \$2: the default value to use if the variable is unbound or empty, and"$'\n' \
              "  \$3: the name of the function to validate each item in the array."
        return 2
    fi

    local default="$2"
    local is_safe_item_fn=$3

    local input output
    input="$(trim "$1")"

    if [[ -z "$input" ]]; then
        input=$default
    fi

    # validate and normalize JSON
    output="$(
        jq '
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
    )" ||
    { error "'$input' is not valid JSON: '$1'"; return 2; }

    # validate each item in the array
    while read -r item; do
        $is_safe_item_fn "$item" || return 1
    done < <(jq -r '.[]' <<< "$output")

    echo "$output"
    return 0
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the runner OS to test."
        return 2
    fi

    local runner_os="$1"
    if [[ -z "$runner_os" ]]; then
        error "The runner OS name is empty."
        return 2
    fi
    if is_in "$runner_os" "${allowed_runners_os[@]}"; then
        return 0
    fi

    error "The runner OS '$runner_os' is not in the list of allowed GitHub Actions runner OS names: ${allowed_runners_os[*]}."
    return 1
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the reason text to test."
        return 2
    fi

    local reason="$1"
    local max_length=200

    # Check length
    if [[ ${#reason} -gt $max_length ]]; then
        error "The reason is too long. Maximum length is $max_length characters."
        return 1
    fi

    # Allow spaces but reject dangerous shell meta-characters
    if ! is_safe_input "$reason" true; then
        return 1
    fi

    # Reject if it looks like a command (starts with -, /, .)
    if [[ "$reason" =~ ^[-/.] ]]; then
        error "The reason '$reason' appears to be a command or unsafe input (contains one or more unsafe characters)."
        return 1
    fi
    return 0
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the NuGet server to test."
        return 2
    fi
    [[ "$1" =~ $nugetServersRegex ]]
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
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        error "${FUNCNAME[0]}() requires at least one or two parameters: the NAME OF THE VARIABLE containing the NuGet server to validate and an optional default value for the NuGet server."
        return 2
    fi

    local -n server=$1
    local default_server=${2:-"nuget"}

    if [[ ! $default_server =~ $nugetServersRegex ]]; then
        error "Invalid default NuGet server: $default_server"
        return 2
    fi

    if [[ -z "$server" ]]; then
        warning_var "server" "No NuGet server configured." "$default_server"
        return 0
    fi

    if [[ ! "$server" =~ $nugetServersRegex ]]; then
        error "Invalid NuGet server: $server"
        return 1
    fi

    return 0
}

#-------------------------------------------------------------------------------
# Summary: Validates that a configuration name is a valid identifier.
# Parameters:
#   1 - configuration - configuration name to validate
# Returns:
#   Exit code: 0 if valid identifier or empty, 1 if invalid, 2 on invalid arguments
# Usage: if is_safe_configuration <config_name>; then ... fi
# Example: if is_safe_configuration "$build_config"; then echo "Valid config"; fi
# Notes: Must match pattern [A-Za-z_][A-Za-z0-9_]* (valid C-style identifier).
#-------------------------------------------------------------------------------
function is_safe_configuration()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires one parameter: the NAME of the configuration variable to test."
        return 2
    fi
    [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && return 0
    error "The configuration '$1' is not valid."
    return 1
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires one parameter: the NAME of the preprocessor symbol parameter to test."
        return 2
    fi
    [[ -z $1 ]] && return 0

    local -n symbols=$1
    local -a symbol_array=()

    IFS=' ,:;' read -ra symbol_array <<< "$symbols"
    local bad=false
    local s=''
    for symbol in "${symbol_array[@]}"; do
        [[ -z $symbol ]] && continue
        if ! [[ "$symbol" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            error "The pre-processor symbol '$symbol' is not valid."
            bad=true
        else
            [[ -z $s ]] && s="$symbol" || s="$s;$symbol"
        fi
    done
    [[ "$bad" == "true" ]] && return 1

    symbols=$s
    return 0
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
function is_safe_min_coverage_pct()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires one parameter: the min coverage percentage to test."
        return 2
    fi

    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        error "The min coverage percentage '$1' is not a valid integer."
        return 1
    fi

    if (( $1 < 0 || $1 > 100 )); then
        error "The min coverage percentage '$1' must be between 0 and 100."
        return 1
    fi

    return 0
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires one parameter: the max regression percentage to test."
        return 2
    fi

    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        error "The max regression percentage '$1' is not a valid integer."
        return 1
    fi

    if (( $1 < 0 || $1 > 100 )); then
        error "The max regression percentage '$1' must be between 0 and 100."
        return 1
    fi

    return 0
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires one parameter: the MinVer prerelease ID to test."
        return 2
    fi

    [[ "$1" =~ $minverPrereleaseIdRegex ]]
}

# The dotnet-version input supports following syntax:
#
# A.B.C (e.g 9.0.308, 10.0.100-preview.1.25120.13) - installs the exact version of .NET SDK semver 2.0 format
# A or A.x (e.g. 8, 8.x) - the latest minor version of the specific .NET SDK, including prerelease versions (preview, rc)
# A.B or A.B.x (e.g. 8.0, 8.0.x) - the latest patch version of the specific .NET SDK, including prerelease versions (preview, rc)
# A.B.Cxx (e.g. 8.0.4xx) - the latest version of the specific SDK release, including prerelease versions (preview, rc).
declare -xr dotnet_regex="^([0-9]+\\.[0-9]+(\\.x)?)|([0-9]+(\\.x)?)|([0-9]+\\.[0-9]+\\.[0-9]xx)|($semverRegex)$"

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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires one parameter: the .NET version to test."
        return 2
    fi

    [[ "$1" =~ $dotnet_regex ]]
}
