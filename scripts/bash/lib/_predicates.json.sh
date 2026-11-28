# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_PREDICATES_JSON_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_PREDICATES_JSON_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_argument_type
declare -x err_invalid_nameref
declare -x err_unsafe_argument
declare -x err_invalid_json
declare -x err_invalid_json_array
declare -x err_invalid_path
declare -x err_not_file

# vm2 core lib variables
declare -x noise_sink

#-----------------------------------------------------------------------------------------------
# @description Checks if a given string is valid JSON.
#
# @arg $1 string The JSON string to validate.
#
# @exitcode positive=0: The string is valid JSON.
# @exitcode negative=1: The string is not valid JSON.
#-----------------------------------------------------------------------------------------------
function is_json()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the JSON string to validate."
                                                                                exit_if_has_bugs

    jq empty <<< "$1" &> "$noise_sink" && return "$positive" || return "$negative"
}

#-----------------------------------------------------------------------------------------------
# @description Checks if the file at a given path contains valid JSON.
#
# @arg $1 string Path to the file to validate.
#
# @exitcode positive=0: The file contains valid JSON.
# @exitcode negative=1: The file does not contain valid JSON.
#-----------------------------------------------------------------------------------------------
function is_json_file()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the JSON file to validate."
    [[ ! -v 1 ]] || is_path "$1"                                                || bug "$err_invalid_path" "${FUNCNAME[0]}() requires argument 1 to be a valid path (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs

    jq empty "$1" &> "$noise_sink" && return "$positive" || return "$negative"
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
#   is_valid_json_with_schema "$_config_file" "$lib_dir/diff-shared.config.schema.json"
#-----------------------------------------------------------------------------------------------
function is_valid_json_with_schema()
{
    (( $# == 2 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                "  - the JSON file to validate" \
                                                                                                                "  - the JSON Schema file to validate against"
                                                                                exit_if_has_bugs

    local -i _rc="$success"
    local _json_file="$1"
    local _schema_file="$2"

    local -i _rc1="$_rc"

    [[ -s $_json_file ]]                                                        || with_error _rc "$err_not_file" "Invalid JSON file '$_json_file': it does not exist or is empty."
    (( _rc != success )) || is_json_file "$_json_file"                          || with_error _rc "$err_invalid_json" "Invalid JSON file '$_json_file': it is not well-formed."
    (( _rc == success )) || _rc1=$_rc

    _rc=$success
    [[ -s $_schema_file ]]                                                      || with_error _rc "$err_not_file" "Invalid JSON Schema file '$_schema_file': it does not exist or is empty."
    (( _rc != success )) || is_json_file "$_schema_file"                        || with_error _rc "$err_invalid_json" "Invalid JSON Schema file '$_schema_file': it is not well-formed."
    (( _rc == success )) || _rc1=$_rc

    local _output

    if verify_check_jsonschema; then
        # validate against the schema only if both files passed their own checks: _rc holds only the schema file's result
        (( _rc1 != success || _rc != success )) || _output=$(check-jsonschema --schemafile "$_schema_file" "$_json_file" 2>&1) \
                                                                                || with_error _rc "$err_invalid_json" "'$_json_file' failed validation against the schema in '$_schema_file':" "$_output"
        (( _rc == success )) || _rc1=$_rc
    fi

    return "$_rc1"
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
    (( $# > 0 && $# <= 3 ))                                                     || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 to 3 arguments (provided $#):" \
                                                                                                                "  - the name of a variable containing the JSON array" \
                                                                                                                "  - the default value to use if the variable is unbound or empty, optional" \
                                                                                                                "  - the name of the function to validate each item in the array, optional"
    [[ ! -v 1 ]] || { is_variable "$1" && is_mutable "$1"; }                    || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name a writable variable that holds the JSON input (provided '${1-<missing>}')."
    [[ ! -v 3 ]] || is_function "$3"                                            || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3 to name a function that validates each item (provided '${3-<missing>}')."
                                                                                exit_if_has_bugs

    local -n __input=$1

    [[ -n $__input ]] || __input=${2:-}

    local -i _rc="$success"

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ -n "$__input" ]] && is_safe_input "$__input" true                        || with_error _rc "$err_unsafe_argument" "Invalid JSON input '$__input': use a JSON array of strings (possibly empty), a JSON string (possibly empty), or null."
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
            $_is_safe_item_fn "$_item"                                          || with_error _rc "$err_unsafe_argument" "Invalid item '$_item' in the JSON array."
        done < <(jq -r '.[]' <<< "$_output")
    fi
    (( _rc != positive )) || __input=$_output
    return "$_rc"
}
