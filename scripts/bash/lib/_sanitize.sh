# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
fi

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
if ! declare -pF "error" > "$_ignore"; then
    source "$lib_dir/_diagnostics.sh"
fi
# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
if [[ ! -v "minverTagPrefixRegex" || ! -v "minverPrereleaseIdRegex" ]]; then
    source "$lib_dir/_semver.sh"
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

## Sanitizes user input by removing or escaping potentially dangerous characters.
## Returns 0 if input is safe, 1 if it contains unsafe characters.
## Usage: if sanitize_input "$user_input" [<allow_spaces>]; then ... fi
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

## Sanitizes file paths - ensures they don't contain directory traversal or dangerous patterns
## Returns 0 if safe path, 1 otherwise
## Usage: if ! is_safe_path "$file_path"; then error ... fi
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

## Sanitizes file paths - ensures they don't contain directory traversal or dangerous patterns
## Returns 0 if safe path, 1 otherwise
## Usage: if ! is_safe_existing_path "$file_path"; then error ... fi
function is_safe_existing_path()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the file path to test."
        return 2
    fi
    if ! is_safe_path "$1"; then
        return 1
    fi

    if [[ ! -e "$1" ]]; then
        error "The path '$1' does not exist."
        return 1
    fi

    return 0
}

## Sanitizes file paths - ensures they don't contain directory traversal or dangerous patterns
## Returns 0 if safe path, 1 otherwise
## Usage: if ! is_safe_existing_directory "$file_path"; then error ... fi
function is_safe_existing_directory()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the directory path to test."
        return 2
    fi
    if ! is_safe_existing_path "$1"; then
        return 1
    fi

    if [[ ! -d "$1" ]]; then
        error "The path '$1' is not a directory."
        return 1
    fi

    return 0
}

## Sanitizes file paths - ensures they don't contain directory traversal or dangerous patterns
## Returns 0 if safe path, 1 otherwise
## Usage: if ! is_safe_existing_file "$file_path"; then error ... fi
function is_safe_existing_file()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the file path to test."
        return 2
    fi
    if ! is_safe_existing_path "$1"; then
        return 1
    fi

    if [[ ! -s "$1" ]]; then
        error "The path '$1' is not a file or is empty."
        return 1
    fi

    return 0
}

declare -xr jq_empty='. == null or . == "" or . == []'
declare -xr jq_array_strings='type == "array" and all(type == "string")'
declare -xr jq_array_strings_has_empty="any(. == \"\")"
declare -xr jq_array_strings_nonempty='type == "array" and length > 0 and all(type == "string") and all(length > 0)'

function is_safe_json_array()
{
    if [[ $# -ne 3 ]]; then
        error "${FUNCNAME[0]}() requires exactly three parameters: \
\$1: the name of the variable containing the JSON array, \
\$2: the default value to use if the variable is unbound or empty, and \
\$3: the name of the function to validate each item in the array."
        return 2
    fi

    local -n array="$1"
    local default_array="$2"
    local is_safe_item=$3

    if [[ -z "$array" ]]; then
        warning_var "$1" "The value of '$1' is unbound or empty string." "$default_array"
        return 0
    fi

    local jq_output

    # Validate that the first parameter is a JSON string containing a non-empty array of non-empty strings
    jq_output="$(jq -e "$jq_array_strings_nonempty" 2>&1 <<< "$array")"
    if [[ $? -gt 1 ]]; then
        error "Error  querying JSON (jq): $jq_output"
        return 2
    fi
    if [[ $jq_output != true ]]; then
        error "The value of '$1'='$array' must be a string containing a JSON non-empty array of non-empty strings."
        return 1
    fi

    # Validate each item of the array for safety
    return_value=0

    while IFS= read -r item; do
        if [[ -n "$item" ]] && ! $is_safe_item "$item"; then
            return_value=1 # check all paths before returning
        fi
    done < <(jq -r '.[]' 2>"$_ignore" <<< "$array" || true)

    return "$return_value"
}

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

## Validates and sanitizes a "reason" text input
## Returns 0 if safe, 1 otherwise
## Usage: if is_safe_reason "$reason"; then ... fi
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

## Validates NuGet server URL or known server name
## Returns 0 if valid, 1 otherwise
function is_safe_nuget_server()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly one parameter: the NuGet server to test."
        return 2
    fi
    [[ ! "$1" =~ $nugetServersRegex ]]
}

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

function is_safe_minverPrereleaseId()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires one parameter: the MinVer tag prefix to test."
        return 2
    fi

    [[ ! "$1" =~ $minverPrereleaseIdRegex ]]
}
