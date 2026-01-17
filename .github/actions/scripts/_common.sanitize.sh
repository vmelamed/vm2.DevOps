#!/bin/bash

## Sanitizes user input by removing or escaping potentially dangerous characters.
## Returns 0 if input is safe, 1 if it contains unsafe characters.
## Usage: if sanitize_input "$user_input"; then ... fi
function is_safe_input() {
    local input="$1"
    local allow_spaces="${2:-false}"

    # Reject null/empty
    if [[ -z "$input" ]]; then
        return 1
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
function is_safe_path() {
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
        error "The path '$path' contains unsafe characters."
        return 1
    fi

    return 0
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
    if [[ "$1" =~ $nugetServersRegex ]]; then
        return 0
    fi
    error "The NuGet server '$1' is not valid. Must be 'nuget', 'github', or a valid https URL."
    return 1
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
    fi
}
