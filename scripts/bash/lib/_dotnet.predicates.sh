# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_DOTNET_PREDICATES_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DOTNET_PREDICATES_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x positive
declare -x failure
declare -x err_invalid_arguments
declare -x err_argument_type
declare -x err_argument_value
declare -x err_invalid_nameref
declare -x err_logic_error

# vm2 core lib constants
declare -x preprocessorSymbolRegex
declare -x minverTagPrefixRegex
declare -x minverPrereleaseIdRegex
declare -x nugetServersRegex

declare -x configurations_in_use
declare -x configurations_in_use_str
declare -x frameworks_in_use
declare -x frameworks_in_use_str
declare -x runtimes_in_use
declare -x runtimes_in_use_str

declare -x u_letters_set
declare -x l_letters_set
declare -x letters_set
declare -x nz_digits_set
declare -x digits_set
declare -x hex_digits_set

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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the configuration value to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_in "$1" "${configurations_in_use[@]}"                                    || with_error _rc "$err_argument_value" "Invalid build configuration '$1': use one of $configurations_in_use_str."

    return "$_rc"
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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the Target Framework Moniker (TFM) value to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the Runtime Identifier (RID) value to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_in "$1" "${runtimes_in_use[@]}"                                          || with_error _rc "$err_argument_value" "Invalid Runtime Identifier (RID) '$1': use one of $runtimes_in_use_str."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a string is a C# preprocessor symbol.
#
# Notes:
#   - Must match `$preprocessorSymbolRegex`: starts with a letter or underscore ('_') and
#     continues with letters, numbers, and underscores.
#
# @arg $1 string The string to test.
#
# @exitcode positive=0: The string is a preprocessor symbol.
# @exitcode negative=1: The string is not a preprocessor symbol.
#
# @example
#   if is_preprocessor_symbol "SHORT_RUN"; then echo "Valid preprocessor symbol"; fi
#-----------------------------------------------------------------------------------------------
function is_preprocessor_symbol()
{
    __test_with_regex "$@" "$preprocessorSymbolRegex"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a C# preprocessor symbol, via `is_preprocessor_symbol`, and reports an
#   error when it is invalid.
#
# Notes:
#   - Must match `$preprocessorSymbolRegex`: starts with a letter or underscore ('_') and
#     continues with letters, numbers, and underscores.
#
# @arg $1 string The preprocessor symbol to validate.
#
# @exitcode success=0: The string is a preprocessor symbol.
# @exitcode err_argument_value=4: The string is not a preprocessor symbol.
#
# @example
#   is_valid_preprocessor_symbol "$symbol" || _rc=$?
#-----------------------------------------------------------------------------------------------
function is_valid_preprocessor_symbol()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the preprocessor symbol to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_preprocessor_symbol "$1"                                                 || with_error _rc "$err_argument_value" "Invalid preprocessor symbol '$1'."

    return "$_rc"
}

declare -x __preprocessor_symbols_regex="^[\ \,:\;${digits_set}${letters_set}_]+$"

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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the NAME of the variable containing the preprocessor symbols to test."
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to be a valid variable name for the preprocessor-symbol list (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs

    local -i _rc="$success"
    local -n __symbols=$1

    [[ -n $__symbols ]]                                                         || return "$positive"
    [[ $__symbols =~ $__preprocessor_symbols_regex ]]                           ||  {
                                                                                        with_error _rc "$err_argument_value" "The preprocessor symbols '$__symbols' contain invalid characters."
                                                                                        return "$_rc"
                                                                                    }

    local -a _symbol_array=()

    IFS=' ,:;' read -r -a _symbol_array <<< "$__symbols"

    local _normalized_symbols=''
    local _symbol

    for _symbol in "${_symbol_array[@]}"; do
        [[ -n $_symbol ]]                                                       || continue # tolerate consecutive separators in the input
        is_valid_preprocessor_symbol "$_symbol"                                 || _rc=$?
        if (( _rc == success )); then
            # symbol is valid, put it into the normalized list
            [[ -z $_normalized_symbols ]] &&
                _normalized_symbols="$_symbol" ||
                _normalized_symbols="$_normalized_symbols;$_symbol"
        fi
    done

    (( _rc == success )) || return "$_rc"

    __symbols=$_normalized_symbols
    return "$positive"
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
# @exitcode err_argument_type=3: the string is not a valid minimum coverage percentage
#
# @example
#   if is_valid_min_coverage_pct "80"; then echo "Valid coverage percentage"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_min_coverage_pct()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the percentage to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_percentage "$1"                                                          || with_error _rc "$err_argument_value" "Invalid minimum coverage percentage '$1': use an integer from 0 to 100."

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
# @exitcode err_argument_type=3: the string is not a valid maximum regression percentage
#
# @example
#   if is_valid_max_regression_pct "10"; then echo "Valid regression percentage"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_max_regression_pct()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the percentage to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_percentage "$1"                                                          || with_error _rc "$err_argument_value" "Invalid maximum performance regression '$1': use an integer from 0 to 100."

    return "$_rc"
}


#-----------------------------------------------------------------------------------------------
# @description Tests if a string is a MinVer Git tag prefix (e.g. `v` as in `v1.2.3`).
#
# Notes:
#   - Must match `$minverTagPrefixRegex`: starts with a letter, a digit, or `_`; continues with
#     letters, digits, `_`, `-`, `.`, or `/`; and ends with a letter, `_`, or `-` -- never with a
#     digit, which would run into the version (`v1` + `2.3.4`). A one-character prefix is the
#     regex's exception: it may be a digit.
#
# @arg $1 string The MinVer tag prefix to validate.
#
# @exitcode positive=0: The string is a valid MinVer Git tag prefix.
# @exitcode negative=1: The string is not a valid MinVer Git tag prefix.
#
# @example
#   if is_minverTagPrefix "v"; then echo "Valid tag prefix"; fi
#-----------------------------------------------------------------------------------------------
function is_minverTagPrefix()
{
    __test_with_regex "$@" "$minverTagPrefixRegex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a string is a MinVer prerelease identifier format.
#
# Notes:
#   - Must match `$minverPrereleaseIdRegex`: the same format as a SemVer prerelease label, so
#     a numeric identifier may be `0` but not have a leading zero. For an untagged commit, MinVer
#     appends the commit height to these identifiers: `preview.0` gives e.g. `1.2.4-preview.0.3`.
#
# @arg $1 string The MinVer prerelease ID to validate.
#
# @exitcode positive=0: If the prerelease ID is valid.
# @exitcode negative=1: If the prerelease ID is invalid.
#
# @example
#   if is_minverPrereleaseId "alpha.1"; then echo "Valid prerelease ID"; fi
#-----------------------------------------------------------------------------------------------
function is_minverPrereleaseId()
{
    __test_with_regex "$@" "$minverPrereleaseIdRegex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if a string is a valid NuGet server URL or a known server name.
#
# Notes:
#   - Accepts `nuget`, `github`, or an https URL matching `$nugetServersRegex`.
#
# @arg $1 string The NuGet server URL or name to test.
#
# @exitcode positive=0: If the server can be a valid NuGet server.
# @exitcode negative=1: If the server is not a valid NuGet server.
#
# @example
#   if is_nuget_server "nuget"; then echo "Valid server"; fi
#-----------------------------------------------------------------------------------------------
function is_nuget_server()
{
    __test_with_regex "$@" "$nugetServersRegex"
}
