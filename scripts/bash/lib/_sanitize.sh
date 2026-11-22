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
declare -x success
declare -x failure
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_invalid_nameref
declare -x err_argument_type
declare -x err_argument_value
declare -x err_not_found
declare -x err_not_file
declare -x err_not_directory
declare -x err_unsafe_argument
declare -x err_invalid_path
declare -x err_non_existent_path
declare -x err_missing_argument
declare -x err_invalid_json
declare -x err_invalid_json_array
declare -x err_logic_error

# vm2 core lib constants
declare -x nugetServersRegex
declare -x default_nuget_server
declare -x gh_runners_os_in_use
declare -x gh_runners_os_in_use_str
declare -x repo_visibilities
declare -x repo_visibilities_str
declare -x configurations_in_use
declare -x configurations_in_use_str
declare -x frameworks_in_use
declare -x frameworks_in_use_str
declare -x runtimes_in_use
declare -x runtimes_in_use_str

declare -rx dangerous_chars_regex=$'[;|&$`<>(){}\n\r]'
declare -rx dangerous_chars_and_whitespaces_regex='[;|&$`<>(){}[:space:]]'

# vm2 core lib variables
declare -x noise_sink
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the value to trim the leading spaces of." -ec "$err_invalid_arguments"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of the variable to trim the leading spaces of." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to be the name of a variable (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the value to trim the trailing spaces of." -ec "$err_invalid_arguments"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of the variable to trim the trailing spaces of." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to be the name of a variable (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the value to trim the leading and trailing spaces of." -ec "$err_invalid_arguments"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of the variable to trim the leading and trailing spaces of." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to be the name of a variable (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
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
    (( $# == 1 || $# == 2 ))                                                    || bug "${FUNCNAME[0]}() requires 1 or 2 arguments (provided $#):" \
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

    [[ ! "$_input" =~ $_dangerous_chars ]]                                      || with_error _rc "$err_unsafe_argument" "Invalid input '$_input': it contains one or more of the unsafe characters '$_dangerous_chars'."

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
#   if is_valid_boolean "$reset_flag"; then echo "Valid boolean"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_boolean()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the boolean value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$positive"
    is_boolean "$1"                                                             || with_error _rc "$err_unsafe_argument" "Invalid boolean '$1': it must be 'true' or 'false'."
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
#   if is_valid_integer "$count"; then echo "Valid integer"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_integer()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the integer value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$positive"
    is_integer "$1"                                                             || with_error _rc "$err_unsafe_argument" "Invalid integer '$1'."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a string is a valid path (non-empty and passing `pathchk`). Depends
#   on `is_path`. The path does not have to exist.
#
# @arg $1 string The path to test.
#
# @exitcode positive=0: If the path is valid.
# @exitcode err_argument_value=4: If the string is not a valid path.
#
# @example
#   if is_valid_path "config/settings.json"; then echo "Valid path"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    # is it a valid path string
    is_path "$1"                                                                || with_error _rc "$err_argument_value" "Invalid path '$1': it must be non-empty and pass 'pathchk'."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a string is a valid and safe path: guards against directory
#   traversal and dangerous patterns. Depends on `is_valid_path`.
#
# Notes:
#   - An empty string is not a valid path, hence not safe.
#   - Relative paths are expected; absolute paths are considered unsafe.
#   - Rejects paths containing `..` (traversal), a leading `/` (absolute path), or unsafe
#     characters `$`, ````, `;`.
#   - Prints an error message about all detected unsafe patterns.
#
# @arg $1 string The file path to test (should be relative).
#
# @exitcode positive=0: If the path is safe.
# @exitcode err_argument_value=4: If the string is not a valid path.
# @exitcode err_unsafe_argument=11: If the input is not safe.
#
# @example
#   if is_safe_path "config/settings.json"; then echo "Safe path"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    # is it a valid path string
    is_valid_path "$_path"                                                      || _rc=$?

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
# @description Validates that a path is safe and exists. Depends on `is_safe_path`.
#
# @arg $1 string The file or directory path to test.
#
# @exitcode positive=0: If the path is valid, safe, and exists.
# @exitcode err_argument_value=4: If the string is not a valid path.
# @exitcode err_unsafe_argument=11: If the input is not safe.
# @exitcode err_non_existent_path=20: If the path does not exist.
#
# @example
#   if is_safe_existing_path "$config_file"; then source "$config_file"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    is_safe_path "$_path"                                                       || return $?
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
# @exitcode err_argument_value=4: If the string is not a valid path.
# @exitcode err_unsafe_argument=11: If the input is not safe.
# @exitcode err_non_existent_path=20: If the path does not exist.
# @exitcode err_not_directory=17: If the path is not a directory.
#
# @example
#   if is_safe_existing_directory "$build_dir"; then cd "$build_dir"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_directory()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the directory path to test." -ec "$err_invalid_arguments"
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
# @exitcode err_argument_value=4: If the string is not a valid path.
# @exitcode err_unsafe_argument=11: If the input is not safe.
# @exitcode err_non_existent_path=20: If the path does not exist.
# @exitcode err_not_file=16: If the path is not a file, or the file is empty.
#
# @example
#   if is_safe_existing_file "$script"; then bash "$script"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_existing_file()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the file path to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive
    local _path="$1"

    is_safe_existing_path "$1"                                                  || return $?
    [[ -f "$_path" && -s "$_path" ]]                                            || with_error _rc "$err_not_file" "The path '$_path' is not a file or is empty."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a runner OS name is in the allowed list of GitHub Actions
#   runners.
#
# Notes:
#   - The allowed values are defined in the `$gh_runners_os_in_use` array.
#
# @arg $1 string The runner OS name to validate.
#
# @exitcode positive=0: If the runner OS is valid.
# @exitcode err_argument_value=4: If the runner OS is not in the allowed list.
#
# @example
#   if is_valid_gh_runner_os "ubuntu-latest"; then echo "Valid runner"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_gh_runner_os()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the runner OS to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_in "$1" "${gh_runners_os_in_use[@]}"                                     || with_error _rc "$err_argument_value" "Invalid runner OS '$1': use one of $gh_runners_os_in_use_str."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a GitHub repository visibility: one of `$repo_visibilities`. The match is
#   case-sensitive: callers that take the value from a person lowercase it first.
#
# @arg $1 string The visibility to validate.
#
# @exitcode positive=0: If the visibility is valid.
# @exitcode err_argument_value=4: If the visibility is not one of `$repo_visibilities`.
#
# @example
#   if is_valid_visibility "private"; then echo "Valid visibility"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_visibility()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): a visibility." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs
    local -i _rc=$success

    is_in "$1" "${repo_visibilities[@]}"                                        || with_error _rc "$err_argument_value" "Invalid repository visibility '$1': use one of $repo_visibilities_str."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a "reason" text input for length constraints.
#
# Notes:
#   - Maximum length is 200 characters.
#
# @arg $1 string The reason text to validate.
#
# @exitcode positive=0: If the reason is valid.
# @exitcode negative=1: If the reason is too long.
#
# @example
#   if is_valid_reason "$user_reason"; then log_reason "$user_reason"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_reason()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the reason text to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _max_length=200
    local -i _rc=$positive

    # Check length
    (( ${#1} <= _max_length ))                                                  || with_error _rc "$err_argument_value" "The reason is too long. Maximum length is $_max_length characters."
    (( _rc == positive ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates a "reason" text input for safety and length constraints. Depends on
#   `is_valid_reason` and `is_safe_input`.
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the reason text to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _reason="$1"
    local -i _rc=$positive

    is_valid_reason "$_reason"                                                  || return $?

    # Allow spaces but reject dangerous shell meta-characters
    is_safe_input "$_reason" true                                               || return $?

    # Reject if it looks like a command (starts with -, /, .)
    [[ ! "$_reason" =~ ^[-/.] ]]                                                || with_error _rc "$err_unsafe_argument" "The reason '$_reason' appears to be a command or contains unsafe characters."
    (( _rc == positive ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates a build configuration name.
#
# Notes:
#   - Must be one of `$configurations_in_use` (case-sensitive).
#
# @arg $1 string The configuration name to validate.
#
# @exitcode positive=0: If the configuration name is valid.
# @exitcode negative=1: If the configuration name is invalid.
#
# @example
#   if is_valid_build_configuration "$build_config"; then echo "Valid config"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_build_configuration()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the configuration value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_in "$1" "${configurations_in_use[@]}"                                    || with_error _rc "$err_argument_value" "Invalid build configuration '$1': use one of $configurations_in_use_str."

    (( _rc == success ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates a Target Framework Moniker (TFM).
#
# Notes:
#   - Must be one of `$frameworks_in_use` (case-sensitive); empty means "from the project".
#
# @arg $1 string The TFM to validate.
#
# @exitcode positive=0: If the TFM is valid.
# @exitcode err_argument_value=4: If the TFM is invalid.
#
# @example
#   if is_valid_framework "$framework"; then echo "Valid TFM"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_framework()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the Target Framework Moniker (TFM) value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_in "$1" "${frameworks_in_use[@]}"                                        || with_error _rc "$err_argument_value" "Invalid Target Framework Moniker (TFM) '$1': use one of $frameworks_in_use_str."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a Runtime Identifier (RID).
#
# Notes:
#   - Must be one of `$runtimes_in_use` (case-sensitive); empty means "portable, no RID".
#
# @arg $1 string The Runtime Identifier (RID) to validate.
#
# @exitcode positive=0: If the RID is valid.
# @exitcode err_argument_value=4: If the RID is invalid.
#
# @example
#   if is_valid_runtime "$runtime"; then echo "Valid RID"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_runtime()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the Runtime Identifier (RID) value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_in "$1" "${runtimes_in_use[@]}"                                          || with_error _rc "$err_argument_value" "Invalid Runtime Identifier (RID) '$1': use one of $runtimes_in_use_str."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a GitHub secret name: contains only alphanumeric characters and
#   underscores, starts with a letter or underscore, and does not start case-insensitively with
#   'GITHUB_'.
#
# @arg $1 string Candidate secret name to validate.
#
# @exitcode positive=0: The secret name is valid.
# @exitcode err_argument_value=4: The value is not a valid name of a GitHub Actions secret.
#-----------------------------------------------------------------------------------------------
function is_valid_secret_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the GitHub secret name to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success
    is_variable_name "$1" && [[ ${1^^} != GITHUB_* ]]                           || with_error _rc "$err_argument_value" "Invalid secret name '$1': use only letters, digits, and underscores; do not start with a digit or with 'GITHUB_'."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a secret value before it is sent to the GitHub API: it must be non-empty
#   and contain no control characters. Depends on `is_secret`. The error never shows the value.
#
# @arg $1 string Candidate secret value to validate.
#
# @exitcode positive=0: The value is non-empty and contains no control characters.
# @exitcode err_argument_value=4: The value is empty, or contains at least one control character.
#-----------------------------------------------------------------------------------------------
function is_valid_secret()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the secret value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_secret "$1"                                                              || with_error _rc "$err_argument_value" "Invalid secret value: it must be non-empty and contain no control characters."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates minimum coverage percentage input. Depends on `is_percentage`.
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The minimum coverage percentage to validate.
#
# @exitcode positive=0: If the percentage is valid.
# @exitcode err_argument_type: 3 the string is not a valid maximum regression percentage
#
# @example
#   if is_valid_min_coverage_pct "80"; then echo "Valid coverage percentage"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_min_coverage_pct()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the percentage to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_percentage "$1"                                                          || with_error _rc "$err_argument_type" "The min coverage percentage '$1' must be an integer number between 0 and 100."
    return "$_rc"
}
#-----------------------------------------------------------------------------------------------
# @description Validates maximum regression percentage input. Depends on `is_percentage`.
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The maximum regression percentage to validate.
#
# @exitcode positive=0: If the percentage is valid.
# @exitcode err_argument_type: 3 the string is not a valid maximum regression percentage
#
# @example
#   if is_valid_max_regression_pct "10"; then echo "Valid regression percentage"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_max_regression_pct()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the percentage to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_percentage "$1"                                                          || with_error _rc "$err_argument_type" "The max regression percentage '$1' must be an integer number between 0 and 100."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a MinVer Git tag prefix is safe and well-formed.
#
# Notes:
#   - Must match `$minverTagPrefixRegex`
#
# @arg $1 string The MinVer tag prefix to validate.
#
# @exitcode positive=0: If the tag prefix is valid.
# @exitcode err_argument_value: 4 the string is not a valid MinVer tag prefix
#
# @example
#   if is_valid_minverTagPrefix "v"; then echo "Valid tag prefix"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_minverTagPrefix()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the MinVer tag prefix to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_minverTagPrefix "$1"                                                     || with_error _rc "$err_argument_value" "Invalid MinVer tag prefix '$1': use letters, digits, '_', '-', '.', or '/', and end with a letter, '-', or '_'."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a string is in MinVer prerelease identifier format (semver
#   prerelease).
#
# Notes:
#   - Must match `$minverPrereleaseIdRegex`
#
# @arg $1 string The prerelease identifier tag prefix to validate.
#
# @exitcode positive=0: If the prerelease Id is valid.
# @exitcode err_argument_value: 4 the string is not a valid MinVer prerelease identifier
#
# @example
#   if is_valid_minverPrereleaseId "v"; then echo "Valid tag prefix"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_minverPrereleaseId()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the prerelease identifier to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$positive

    is_minverPrereleaseId "$1"                                                  || with_error _rc "$err_argument_value" "Invalid MinVer prerelease identifier '$1': use dot-separated SemVer identifiers (letters, digits, '-')."
    return "$_rc"
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
    (( $# == 3 || $# == 4 ))                                                    || bug "${FUNCNAME[0]}() requires 3 or 4 arguments (provided $#):" \
                                                                                       "  - the name of the variable containing the NuGet server" \
                                                                                       "  - the name to store the NuGet server's display name" \
                                                                                       "  - the name to store the NuGet server's URL" \
                                                                                       "  - an optional default server" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to be a valid variable name containing the NuGet server moniker (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
    [[ ! -v 2 ]] || is_variable "$2"                                            || bug "${FUNCNAME[0]}() requires argument 2 to be a valid variable name (provided '${2-<missing>}')." -ec "$err_invalid_nameref"
    [[ ! -v 3 ]] || is_variable "$3"                                            || bug "${FUNCNAME[0]}() requires argument 3 to be a valid variable name (provided '${3-<missing>}')." -ec "$err_invalid_nameref"
    [[ ! -v 4 || $4 =~ $nugetServersRegex ]]                                    || bug "${FUNCNAME[0]}() requires argument 4 to be a valid default NuGet server moniker (provided '${4-<missing>}')." -ec "$err_argument_value"
    [[ -n $repo_owner ]]                                                        || bug "${FUNCNAME[0]}() requires the global variable \$repo_owner to be set." -ec "$err_logic_error"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the NAME of the variable containing the preprocessor symbols to test." -ec "$err_invalid_arguments"
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
#   validate_json_array runners '["ubuntu-latest"]' is_valid_gh_runner_os
#-----------------------------------------------------------------------------------------------
function validate_json_array()
{
    (( $# > 0 && $# <= 3 ))                                                     || bug "${FUNCNAME[0]}() requires 1 to 3 arguments (provided $#):" \
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
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                       "  - the JSON file to validate" \
                                                                                       "  - the JSON Schema file to validate against" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_path "$1"                                                || bug "${FUNCNAME[0]}() requires argument 1 to be a valid path (provided '${1-<missing>}')." -ec "$err_not_file"
    [[ ! -v 2 ]] || is_path "$2"                                                || bug "${FUNCNAME[0]}() requires argument 2 to be a valid path (provided '${2-<missing>}')." -ec "$err_not_file"
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
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): the string that needs its special ERE characters to be escaped." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}
