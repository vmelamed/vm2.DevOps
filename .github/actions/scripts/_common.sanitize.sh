#!/bin/bash

## Sanitizes user input by removing or escaping potentially dangerous characters.
## Returns 0 if input is safe, 1 if it contains unsafe characters.
## Usage: if sanitize_input "$user_input" [<allow_spaces>]; then ... fi
function is_safe_input()
{
    local input="$1"
    local allow_spaces="${2:-false}"

    # Reject null/empty
    if [[ -z "$input" ]]; then
        return 0
    fi

    # Dangerous characters that could enable command injection
    dangerous_chars=$'[;|&$`\\\\<>(){}\n\r]'

    if [[ "$allow_spaces" != "true" ]]; then
        dangerous_chars=$'[;|&$`\\\\<>(){}\n\r ]'
    fi

    if [[ "$input" =~ $dangerous_chars ]]; then
        error "The input '$input' contains one or more of the unsafe characters '$dangerous_chars'."
        return 1
    fi

    return 0
}

## Sanitizes file paths - ensures they don't contain directory traversal or dangerous patterns
## Returns 0 if safe path, 1 otherwise
## Usage: if is_safe_path "$file_path"; then ... fi
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
## Usage: if is_safe_path "$file_path"; then ... fi
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
## Usage: if is_safe_path "$file_path"; then ... fi
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
## Usage: if is_safe_path "$file_path"; then ... fi
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

## Validates if the first argument is a name of a variable containing a valid JSON array of project paths, if it is null, empty
## or empty array, it use the second parameter if provided, defaults to usually `[""]`.
## Returns 0 if valid, 1 otherwise
## Usage: are_safe_projects <variable_name> [<default_value>]
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function are_safe_projects()
{
    local -n projects=$1
    local default_projects=${2:-'[""]'}

    # Validate JSON format
    if [[ -n "$projects" ]] && ! jq -e '.' > "$_ignore" 2>&1 <<<"$projects"; then
        error "The value of the input '$1'='$projects' is not a valid JSON."
        return 1
    fi

    # Check if empty/null
    if [[ -z "$projects" ]] || jq -e '. == null or . == "" or . == []' > "$_ignore" 2>&1 <<<"$projects"; then
        warning_var "projects" \
            "The value of the input '$1' is empty: will build and pack the entire solution." \
            "$default_projects"
        return 0
    fi

    # Validate it's an array of strings
    if ! jq -e 'type == "array" and all(type == "string")' > "$_ignore" 2>&1 <<<"$projects"; then
        error "The value of the input '$1'='$projects' must be a string representing a JSON array of (possibly empty) strings - paths to the project(s) to be packed."
        return 1
    fi

    # Warn if array contains empty strings
    if jq -e 'any(. == "")' > "$_ignore" 2>&1 <<<"$projects"; then
        warning_var "projects" \
            "At least one of the strings in the value of the input '$1' is empty: will build and pack the entire solution." \
            "$default_projects"
        return 0
    fi

    # Validate each project path for safety
    return_value=0
    while IFS= read -r project_path; do
        if [[ -n "$project_path" ]] && ! is_safe_existing_file "$project_path"; then
            error "Unsafe project path detected: '$project_path'"
            return_value=1
        fi
    done < <(jq -r '.[]' 2>"$_ignore" <<<"$projects" || true)
    return "$return_value"
}


## Validates and sanitizes a "reason" text input
## Returns 0 if safe, 1 otherwise
## Usage: if is_safe_reason "$reason"; then ... fi
function is_safe_reason() {
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

declare -xr nugetServersRegex="^(nuget|github|https?://[a-zA-Z0-9._/-]+)$";

## Validates NuGet server URL or known server name
## Returns 0 if valid, 1 otherwise
function is_safe_nuget_server() {
    if [[ ! "$1" =~ $nugetServersRegex ]]; then
        return 1
    fi

    return 0
}

function validate_nuget_server() {
    local -n server=$1
    local default_server=${2:-"nuget"}

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
