# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-----------------------------------------------------------------------------------------------
# This script defines predicate functions for testing the existence and type of variables.
# It includes functions for checking if a variable, array, or associative array is defined.
# Includes a function (is_in) for testing if a the value of a variable is included in a set of
# values, e.g. array.
#-----------------------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_PREDICATES_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_PREDICATES_SH_LOADED=1

# vm2 core lib exit codes
declare -xi success
declare -x failure
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_invalid_nameref

# vm2 core lib constants
declare -x nugetServersRegex

declare -xr zero_rex='[+-]?0'
declare -xr natural_rex='[1-9][0-9]*'
declare -xr positive_rex="[+]?$natural_rex"
declare -xr negative_rex="-$natural_rex"
declare -xr integer_rex="[+-]?(0|$natural_rex)"
declare -xr decimal_rex="$integer_rex(\.[0-9]*)?|(($integer_rex)?\.[0-9]+)"
declare -xr bool_rex='(true|false)'
declare -xr base64_char_rex='[A-Za-z0-9+/]'
declare -xr build_config_rex="^([A-Za-z_][A-Za-z0-9_]*)?$"
declare -xr tfm_rex="(net[1-9][0-9]*\.[0-9]+(-([a-z]+)([1-9][0-9.]*)?)?|[[:space:]]*)"
declare -xr rid_rex="(([a-z][a-z-]*[a-z])((\.[1-9][0-9]*)*)(-[a-z][0-9a-z]*)?(-[.0-9a-z]+)?|[[:space:]]*)"
declare -xr varNameRex="[A-Za-z_][A-Za-z0-9_]*"
declare -xr prereleaseLabelRex='[-0-9A-Za-z.]+'
declare -xr minverTagPrefixRex='[0-9A-Za-z_]([-0-9A-Za-z._/]*[-A-Za-z_])?'
declare -xr minverPrereleaseIdRex=$prereleaseLabelRex

declare -xr natural_regex="^$natural_rex\$"
declare -xr zero_regex="^$zero_rex\$"
declare -xr positive_regex="^$positive_rex\$"
declare -xr negative_regex="^$negative_rex\$"
declare -xr non_negative_regex="^($positive_rex|$zero_rex)\$"
declare -xr non_positive_regex="^($negative_rex|$zero_rex)\$"
declare -xr integer_regex="^$integer_rex\$"
declare -xr decimal_regex="^($decimal_rex)\$"
declare -xr bool_regex="^$bool_rex\$"
declare -xr build_config_regex="^$build_config_rex\$"
declare -xr tfm_regex="^$tfm_rex\$"
declare -xr rid_regex="^$rid_rex\$"
declare -xr varNameRegex="^$varNameRex\$"
declare -xr minverTagPrefixRegex="^$minverTagPrefixRex$"
declare -xr minverPrereleaseIdRegex="^$minverPrereleaseIdRex$"

declare -xr base64_regex="^($base64_char_rex{4})*($base64_char_rex{3}=|$base64_char_rex{2}==)?\$"

declare -xra known_configurations=(
    Debug
    Release
)

declare -xr known_tfms=(
    ""
    net9.0
    net10.0
)

declare -xr known_runtimes=(
    ""
    linux-x64
    win-x64
    osx-x64
)

# vm2 core lib variables
declare -x _ignore

#-----------------------------------------------------------------------------------------------
# @description Checks if the shell is case-sensitive.
#
# @exitcode positive=0: The shell is case-sensitive.
# @exitcode negative=1: The shell is case-insensitive.
#-----------------------------------------------------------------------------------------------
function is_case_sensitive()
{
    shopt -q nocasematch && return "$negative" || return "$positive"
}

#-----------------------------------------------------------------------------------------------
# @description Sets the shell to case-insensitive mode.
#
# @exitcode success=0: Always.
#-----------------------------------------------------------------------------------------------
function set_case_insensitive()
{
    shopt -s nocasematch || true
}

#-----------------------------------------------------------------------------------------------
# @description Sets the shell to case-sensitive mode (the default Bash mode).
#
# @exitcode success=0: Always.
#-----------------------------------------------------------------------------------------------
function set_case_sensitive()
{
    shopt -u nocasematch || true
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a string is a valid variable name.
#
# @arg $1 string variable_name - the name of the variable to test
#
# @exitcode positive=0: the string is a valid variable name
# @exitcode negative=1: otherwise
#
# @example
#   if is_variable_name "MY_VAR"; then echo "Valid variable name"; fi
#-----------------------------------------------------------------------------------------------
function is_variable_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the variable to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    [[ $1 =~ $varNameRegex ]]
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a variable is defined.
#
# @arg $1 string variable_name - name of the variable to test
#
# @exitcode positive=0: the variable is defined
# @exitcode negative=1: otherwise
#
# @example
#   if is_variable MY_VAR; then echo "MY_VAR is defined"; fi
#-----------------------------------------------------------------------------------------------
function is_variable()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the variable to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    is_variable_name "$1" && declare -p "$1" &> "$_ignore"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a variable is defined and if it is an indexed array.
#
# @arg $1 string variable_name - name of the array variable to test
#
# @exitcode positive=0: the strings is the name of a defined indexed array variable
# @exitcode negative=1: otherwise
#
# @example
#   declare -a MY_ARRAY=(aaa bbb ccc)
#   if is_indexed_array MY_ARRAY; then echo "MY_ARRAY is defined"; fi
#-----------------------------------------------------------------------------------------------
function is_indexed_array()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the indexed array variable to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    is_variable_name "$1" || return "$negative"

    begin_scope
    set_case_sensitive

    local -i _rc="$positive"
    local _decl

    _decl=$(declare -p "$1" 2>"$_ignore") && [[ $_decl =~ ^declare\ -a ]] || _rc="$negative"

    end_scope

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a variable is defined and if it is an associative array.
#
# @arg $1 string variable_name - name of the array variable to test
#
# @exitcode positive=0: the strings is the name of a defined associative array variable
# @exitcode negative=1: otherwise
#
# @example
#   declare -A MY_ARRAY=([aaa]=aaa [bbb]=bbb [ccc]=ccc)
#   if is_associative_array MY_ARRAY; then echo "MY_ARRAY is defined"; fi
#-----------------------------------------------------------------------------------------------
function is_associative_array()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the indexed array variable to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    is_variable_name "$1" || return "$negative"

    begin_scope
    set_case_sensitive

    local -i _rc="$positive"
    local _decl

    _decl=$(declare -p "$1" 2>"$_ignore") && [[ $_decl =~ ^declare\ -A ]] || _rc="$negative"

    end_scope

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a variable is defined and if it is an indexed or an associative array.
#
# @arg $1 string variable_name - name of the array variable to test
#
# @exitcode positive=0: the strings is the name of a defined indexed or an associative array variable
# @exitcode negative=1: otherwise
#
# @example
#   declare -A MY_ASSOC_ARRAY=([aaa]=aaa [bbb]=bbb [ccc]=ccc)
#   declare -a MY_INDEXED_ARRAY=(aaa bbb ccc)
#   if is_array MY_ASSOC_ARRAY; then echo "MY_ASSOC_ARRAY is defined"; fi
#   if is_array MY_INDEXED_ARRAY; then echo "MY_INDEXED_ARRAY is defined"; fi
#-----------------------------------------------------------------------------------------------
function is_array()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the array variable to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    is_variable_name "$1" || return "$negative"

    begin_scope
    set_case_insensitive

    local -i _rc="$positive"
    local _decl

     # -a or -A case insensitive!
    _decl=$(declare -p "$1" 2>"$_ignore") && [[ $_decl =~ ^declare\ -a ]] || _rc="$negative"

    end_scope

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if an array (indexed or associative) is empty.
#
# @arg $1 string array_name - name of the array variable to test
#
# @exitcode positive=0: the array is empty
# @exitcode negative=1: otherwise
#
# @example
#   if is_empty_array MY_ARRAY; then echo "MY_ARRAY is empty"; fi
#-----------------------------------------------------------------------------------------------
function is_empty_array()
{

    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of the array variable to test." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_array "$1"                                               || bug "${FUNCNAME[0]}() requires argument 1 to be the name of an indexed or an associative array variable (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -n __array="$1"

    [[ -z ${__array[*]+x} ]]
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a function is defined.
#
# @arg $1 string name of the function to test
#
# @exitcode positive=0: the function is defined
# @exitcode negative=1: otherwise
#
# @example
#   if is_function MY_FUNC; then echo "MY_FUNC is defined"; fi
#-----------------------------------------------------------------------------------------------
function is_function()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    is_variable_name "$1" || return "$negative"

    declare -pF "$1" > "$_ignore" 2>&1
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the string matches the provided regular expression.
#   For internal use only!
#
# @arg $1 string value - the string to test
# @arg $2 string regex - the regular expression to match against
#
# @exitcode positive=0: the string $1 matches the regex $2
# @exitcode negative=1: otherwise
#-----------------------------------------------------------------------------------------------
function __test_with_regex()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[1]}() requires exactly one argument (provided $(($#-1))): the value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    [[  $1 =~ $2 ]]
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid boolean value - 'true' or 'false'.
#
# @arg $1 string boolean - string to test
#
# @exitcode positive=0: the string is either 'true', or 'false'
# @exitcode negative=1: otherwise
#
# @example
#   if is_boolean "$flag"; then echo "flag is valid"; fi
#-----------------------------------------------------------------------------------------------
function is_boolean()
{
    __test_with_regex "$@" "$bool_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid natural number (1, 2, 3, ...)
#   without a sign.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a natural number
# @exitcode negative=1: otherwise
#
# @example
#   if is_natural "$apples"; then echo "apples is valid"; fi
#-----------------------------------------------------------------------------------------------
function is_natural()
{
    __test_with_regex "$@" "$natural_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid non-negative integer (0, 1, 2, 3,
#   ...), with an optional leading '+'.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a non-negative integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_non_negative "$index"; then echo "Index is valid"; fi
#-----------------------------------------------------------------------------------------------
function is_non_negative()
{
    __test_with_regex "$@" "$non_negative_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid exit code (0, 1, 2, 3, ..., 255)
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a valid exit code number
# @exitcode negative=1: otherwise
#
# @example
#   if is_natural "$apples"; then echo "apples is valid"; fi
#-----------------------------------------------------------------------------------------------
function is_exit_code()
{
    is_non_negative "$1" && (( $1 <= 255 ))
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid positive integer (1, 2, 3, ...), with
#   an optional leading '+'.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a positive integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_positive "$count"; then echo "Count is positive"; fi
#-----------------------------------------------------------------------------------------------
function is_positive()
{
    __test_with_regex "$@" "$positive_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid non-positive integer (0, -1, -2, -3,
#   ...).
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a non-positive integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_non_positive "$delta"; then echo "Delta is non-positive"; fi
#-----------------------------------------------------------------------------------------------
function is_non_positive()
{
    __test_with_regex "$@" "$non_positive_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid negative integer (-1, -2, -3, ...).
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is a negative integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_negative "$offset"; then echo "Offset is negative"; fi
#-----------------------------------------------------------------------------------------------
function is_negative()
{
    __test_with_regex "$@" "$negative_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid integer (..., -2, -1, 0, 1, 2, ...),
#   with an optional leading sign.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string is an integer
# @exitcode negative=1: otherwise
#
# @example
#   if is_integer "$value"; then echo "Value is an integer"; fi
#-----------------------------------------------------------------------------------------------
function is_integer()
{
    __test_with_regex "$@" "$integer_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the parameter represents a valid decimal number (including integers
#   and floating-point), with an optional leading sign.
#
# Notes:
#   - The regex `^[-+]?[0-9]*(\.[0-9]*)?$` also accepts a lone sign, an empty string, or a
#     lone '.', since all the numeric parts are optional. Callers relying on strict numeric
#     validity should be aware of these edge cases.
#
# @arg $1 string number - string to test
#
# @exitcode positive=0: the string matches the decimal-number pattern
# @exitcode negative=1: otherwise
#
# @example
#   if is_decimal "$price"; then echo "Price is valid"; fi
#-----------------------------------------------------------------------------------------------
function is_decimal()
{
    __test_with_regex "$@" "$decimal_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the first parameter is a valid Base64 encoded string.
#
# @arg $1 string value - the value to test
#
# @exitcode positive=0: the value is a valid Base64 encoded string
# @exitcode negative=1: the value is not a valid Base64 encoded string
#
# @example
#   if is_base64 "$encoded_string"; then echo "Valid Base64"; fi
#-----------------------------------------------------------------------------------------------
function is_base64()
{
    __test_with_regex "$@" "$base64_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the first parameter equals one of the following parameters.
#
# @arg $1 string value - value to search for
# @arg $@ string options - zero or more valid options to compare against
#
# @exitcode positive=0: the value was found among the options
# @exitcode negative=1: otherwise
#
# @example
#   if is_in "$color" "red" "green" "blue"; then echo "Valid color"; fi
#-----------------------------------------------------------------------------------------------
function is_in()
{
    (( $# >= 1 ))                                                               || bug "${FUNCNAME[0]}() requires more than 1 arguments:" \
                                                                                       "  - the value to test" \
                                                                                       "  - options to compare against" \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _sought="$1"; shift
    local _v

    for _v in "$@"; do
        [[ $_sought == "$_v" ]] && return "$positive"
    done
    return "$negative"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the first parameter equals one of the following parameters case
#   insensitively.
#
# @arg $1 string value - value to search for
# @arg $@ string options - zero or more valid options to compare against
#
# @exitcode positive=0: the value was found among the options
# @exitcode negative=1: otherwise
#
# @example
#   if is_in_i "$color" "red" "green" "blue"; then echo "Valid color"; fi
#-----------------------------------------------------------------------------------------------
function is_in_i()
{
    (( $# >= 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 or more arguments:" \
                                                                                       "  - the value to test" \
                                                                                       "  - options to compare against" \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _sought="$1"; shift
    local -i _rc=$negative
    local _v

    begin_scope
    set_case_insensitive
    for _v in "$@"; do
        [[ $_sought == "$_v" ]] && {
            _rc=$positive
            break
        }
    done
    end_scope

    return "$_rc"
}

declare -x __os_name=''
declare -x __is_windows=''

#-----------------------------------------------------------------------------------------------
# @description Detects if the current operating system is Windows (including Windows_NT,
#   MINGW, and MSYS environments).
#
# @noargs
#
# @exitcode positive=0: running on Windows
# @exitcode negative=1: otherwise
#
# @example
#   if is_windows; then echo "Running on Windows"; fi
#-----------------------------------------------------------------------------------------------
function is_windows()
{
    if [[ -z $__is_windows ]]; then
        __os_name="$(uname -s)"
        [[ "$__os_name" == "Windows_NT" || "$__os_name" == *MINGW* || "$__os_name" == *MSYS* ]] &&
            __is_windows=true ||
            __is_windows=false
        readonly __os_name
        readonly __is_windows
    fi

    $__is_windows
}

#-----------------------------------------------------------------------------------------------
# @description Detects if the given string is a valid filename (not empty, not containing
#   slashes, and not "." or "..").
#
# @arg $1 string name - the filename to test
#
# @exitcode positive=0: the filename is valid
# @exitcode negative=1: otherwise
#
# @example
#   if is_valid_filename "$filename"; then echo "Valid filename"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_filename()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    [[ -n $1 && $1 != */* && $1 != . && $1 != .. ]]
}

#-----------------------------------------------------------------------------------------------
# @description Detects if the given string is a valid path (not empty and passing pathchk).
#
# @arg $1 string name - the path to test
#
# @exitcode positive=0: the path is valid
# @exitcode negative=1: otherwise
#
# @example
#   if is_valid_path "$path"; then echo "Valid path"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_path()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the value to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    pathchk -- "$1" &> "$_ignore"
}

#-----------------------------------------------------------------------------------------------
# @description Checks whether a candidate secret name is valid: contains only alphanumeric
#   characters and underscores, starts with a letter or underscore, and does not start
#    case-insensitively with 'GITHUB_'.
#
# @arg $1 string Candidate secret name to validate.
#
# @exitcode positive=0: The secret name is valid.
# @exitcode negative=1: The secret name is not valid.
#-----------------------------------------------------------------------------------------------
function is_valid_secret_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the GitHub secret name to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    is_variable_name "$1" && [[ ${1^^} != GITHUB_* ]]
}

#-----------------------------------------------------------------------------------------------
# @description Checks whether a candidate secret value is safe to send to the GitHub API --
# i.e. it contains no control characters.
#
# @arg $1 string Candidate secret value to validate.
#
# @exitcode positive=0: The value contains no control characters.
# @exitcode negative=1: otherwise
#-----------------------------------------------------------------------------------------------
function is_valid_secret()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the secret value to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    [[ -n $1 && ! $1 =~ [[:cntrl:]] ]]
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a build configuration name is a valid identifier.
#
# @arg $1 string The configuration name to test.
#
# @exitcode positive=0: If the configuration name is valid.
# @exitcode negative=1: If the configuration name is invalid.
#
# @example
#   if is_valid_configuration "$build_config"; then echo "Valid config"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_configuration()
{
    __test_with_regex "$@" "$build_config_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a string is a valid Target Framework Moniker (TFM).
#
# @arg $1 string The TFM to validate.
#
# @exitcode positive=0: If the TFM is valid.
# @exitcode negative=1: If the TFM is invalid.
#
# @example
#   if is_valid_framework "$framework"; then echo "Valid TFM"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_framework()
{
    __test_with_regex "$@" "$tfm_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a string is a valid Runtime Identifier (RID).
#
# @arg $1 string The RID to validate.
#
# @exitcode positive=0: If the RID is valid.
# @exitcode negative=1: If the RID is invalid.
#
# @example
#   if is_valid_runtime "$runtime"; then echo "Valid RID"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_runtime()
{
    __test_with_regex  "$@" "$rid_regex"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a given value is a valid percentage (0-100).
#
# Notes:
#   - Must be an integer between 0 and 100, inclusive.
#
# @arg $1 string The percentage to validate.
#
# @exitcode positive=0: If the percentage is valid.
# @exitcode negative=1: If the percentage is invalid.
#
# @example
#   if is_valid_percentage "50"; then echo "Valid percentage"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_percentage()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the percentage to test." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    is_non_negative "$1" && (( $1 <= 100 ))
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a string is a valid MinVer Git tag prefix (e.g. `v` as in `v1.2.3`).
#
# Notes:
#   - Must match `$minverTagPrefixRegex` (`$minverTagPrefixRex` in `_semver.sh`): starts and
#     ends with an alphanumeric or `_`, with `-`, `.`, `/` allowed in between.
#
# @arg $1 string The MinVer tag prefix to validate.
#
# @exitcode positive=0: If the tag prefix is valid.
# @exitcode negative=1: If the tag prefix is invalid.
#
# @example
#   if is_valid_minverTagPrefix "v"; then echo "Valid tag prefix"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_minverTagPrefix()
{
    __test_with_regex "$@" "$minverTagPrefixRegex"
}

#-----------------------------------------------------------------------------------------------
# @description Validates the MinVer prerelease identifier format.
#
# Notes:
#   - Must match `$minverPrereleaseIdRegex` (the same as the SemVer prerelease label format).
#
# @arg $1 string The MinVer prerelease ID to validate.
#
# @exitcode positive=0: If the prerelease ID is valid.
# @exitcode negative=1: If the prerelease ID is invalid.
#
# @example
#   if is_valid_minverPrereleaseId "alpha.1"; then echo "Valid prerelease ID"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_minverPrereleaseId()
{
    __test_with_regex "$@" "$minverPrereleaseIdRegex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a string is a valid NuGet server URL or known server name.
#
# Notes:
#   - Accepts `nuget`, `github`, or a valid http(s) URL matching `$nugetServersRegex`.
#
# @arg $1 string The NuGet server URL or name to test.
#
# @exitcode positive=0: If the server can be a valid NuGet server.
# @exitcode negative=1: If the server is not a valid NuGet server.
#
# @example
#   if is_valid_nuget_server "nuget"; then echo "Valid server"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_nuget_server()
{
    __test_with_regex "$@" "$nugetServersRegex"
}
