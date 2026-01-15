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
    local dangerous_chars='[;|&$`\\<>(){}\n\r]'

    if [[ "$allow_spaces" != "true" ]]; then
        dangerous_chars='[;|&$`\\<>(){}\n\r ]'
    fi

    if [[ "$input" =~ $dangerous_chars ]]; then
        return 1
    fi

    return 0
}

## Sanitizes version strings (semver format)
## Returns 0 if valid semver, 1 otherwise
## Usage: if is_safe_version "$version"; then ... fi
function is_safe_version() {
    local version="$1"

    # Must match semver pattern (already defined in _common_semver.sh)
    if [[ -n "$semverRegex" ]] && [[ "$version" =~ $semverRegex ]]; then
        return 0
    fi

    # Fallback basic validation
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
        return 0
    fi

    return 1
}

## Sanitizes file paths - ensures they don't contain directory traversal or dangerous patterns
## Returns 0 if safe path, 1 otherwise
## Usage: if is_safe_path "$file_path"; then ... fi
function is_safe_path() {
    local path="$1"

    # Reject paths with directory traversal
    if [[ "$path" =~ \.\. ]]; then
        return 1
    fi

    # Reject absolute paths starting with /
    if [[ "$path" =~ ^/ ]]; then
        return 1
    fi

    # Reject paths with dangerous characters
    if [[ "$path" =~ [\$\`\;] ]]; then
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
        return 1
    fi

    # Allow spaces but reject dangerous shell meta-characters
    if ! is_safe_input "$reason" true; then
        return 1
    fi

    # Reject if it looks like a command (starts with -, /, .)
    if [[ "$reason" =~ ^[-/.] ]]; then
        return 1
    fi

    return 0
}

## Validates NuGet server URL or known server name
## Returns 0 if valid, 1 otherwise
function is_safe_nuget_server() {
    local server="$1"

    # Known safe values
    if [[ "$server" == "nuget" ]] || [[ "$server" == "github" ]]; then
        return 0
    fi

    # Must be a valid https URL
    if [[ "$server" =~ ^https://[a-zA-Z0-9._/-]+$ ]]; then
        return 0
    fi

    return 1
}
