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

## Sanitizes user input by removing or escaping potentially dangerous characters.
## Returns 0 if input is safe, 1 if it contains unsafe characters.
## Usage: if sanitize_input "$user_input" [<allow_spaces>]; then ... fi
function is_safe_input()
{
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        error "The function is_safe_input() requires one or two parameters: the input string to sanitize and an optional flag to allow spaces."
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
        error "The input '$input' contains one or more of the unsafe characters '$dangerous_chars'."
        return 1
    fi

    return 0
}

## Sanitizes file paths - ensures they don't contain directory traversal or dangerous patterns
## Returns 0 if safe path, 1 otherwise
## Usage: if ! is_safe_path "$file_path"; then error ... fi
function is_safe_path()
{
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
    if ! is_safe_existing_path "$1"; then
        return 1
    fi

    if [[ ! -s "$1" ]]; then
        error "The path '$1' is not a file or is empty."
        return 1
    fi

    return 0
}

declare -xr skip_projects_sentinel="__skip__"
declare -xr jq_empty='. == null or . == "" or . == []'
declare -xr jq_array_strings='type == "array" and all(type == "string")'
declare -xr jq_array_strings_has_empty="any(. == \"\" or . == \"$skip_projects_sentinel\")"
declare -xr jq_array_strings_nonempty="$jq_array_strings and length > 0 and all(length > 0)"

## Validates if the first argument is a name of a variable containing a valid JSON array of project paths, if it is null, empty
## or empty array, it use the second parameter if provided, defaults to `[""]`.
## Returns 0 if valid, 1 otherwise
## Usage:
##   if ! are_safe_projects <variable_name> [<default_value>]; then error ... fi
##   if ! are_safe_projects ${projects[@]}; then error ... fi
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function are_safe_projects()
{
    local -n projects=$1
    local default_projects=${2:-'[""]'}

    if [[ -z "$projects" ]]; then
        warning_var "projects" \
            "The value of the input '$1' is empty: will use the solution/project/file in the repo's root folder." \
            "$default_projects"
        return 0
    fi

    local jq_output

    # Validate JSON format
    # warn if it is null, empty string, or empty array
    jq_output="$(jq -e "$jq_empty" 2>&1 <<< "$projects")"
    if [[ $? -gt 1 ]]; then
        error "Error  querying JSON (jq): $jq_output"
        return 2
    fi
    if [[ $jq_output == true ]]; then
        warning_var "projects" \
            "The value of the input '$1' is empty: will use the solution/project/file in the repo's root folder." \
            "$default_projects"
        return 0
    fi

    # Validate it's an array of strings
    jq_output="$(jq -e "$jq_array_strings" 2>&1 <<< "$projects")"
    if [[ $? -gt 1 ]]; then
        error "Error  querying JSON (jq): $jq_output"
        return 2
    fi
    if [[ $jq_output != true ]]; then
        error "The value of the input '\$1'='$projects' must be a string containing a JSON array of strings:\
               paths to solution(s), project(s), '$skip_projects_sentinel', or empty."
        return 1
    fi

    # Warn if array contains empty strings
    jq_output="$(jq -e "$jq_array_strings_has_empty" 2>&1 <<< "$projects")"
    if [[ $? -gt 1 ]]; then
        error "Error  querying JSON (jq): $jq_output"
        return 2
    fi
    if [[ $jq_output == true ]]; then
        warning_var "projects" \
            "At least one of the strings in the value of the input '$1' is empty: will use the solution/project/file in the repo's root folder." \
            "$default_projects"
        return 0
    fi

    # Validate each project path for safety
    return_value=0
    while IFS= read -r project_path; do
        if [[ -n "$project_path" ]] && ! is_safe_existing_file "$project_path"; then
            error "Unsafe project path detected: '$project_path'"
            return_value=1 # check all paths before returning
        fi
    done < <(jq -r '.[]' 2>"$_ignore" <<<"$projects" || true)
    return "$return_value"
}

## Validates and sanitizes a "reason" text input
## Returns 0 if safe, 1 otherwise
## Usage: if is_safe_reason "$reason"; then ... fi
function is_safe_reason()
{
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

declare -xr nugetServersRegex="^(nuget|github|https?://[-a-zA-Z0-9._/]+)$";

## Validates NuGet server URL or known server name
## Returns 0 if valid, 1 otherwise
function is_safe_nuget_server()
{
    if [[ $# -ne 1 ]]; then
        error "The function is_safe_nuget_server() requires exactly one parameter: the NuGet server to test."
        return 2
    fi
    [[ ! "$1" =~ $nugetServersRegex ]]
}

function validate_nuget_server()
{
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        error "The function validate_nuget_server() requires at least one or two parameters: the NAME OF THE VARIABLE containing the NuGet server to validate and an optional default value for the NuGet server."
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

function is_safe_minverTagPrefix()
{
    if [[ $# -ne 1 ]]; then
        error "The function is_safe_minverTagPrefix() requires one parameter: the MinVer tag prefix to test."
        return 2
    fi

    [[ ! "$1" =~ $minverTagPrefixRegex ]]
}

function is_safe_minverPrereleaseId()
{
    if [[ $# -ne 1 ]]; then
        error "The function is_safe_minverTagPrefix() requires one parameter: the MinVer tag prefix to test."
        return 2
    fi

    [[ ! "$1" =~ $minverPrereleaseIdRegex ]]
}
