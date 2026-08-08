# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines functions for dumping variable names and values in a formatted table.
# It supports different table formats (graphical, markdown) and handles scalars, arrays, associative arrays, functions, and undefined variables.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_DUMP_VARS_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_DUMP_VARS_SH_LOADED=1

declare -rx varNameRegex

declare -rxi success
declare -rxi err_argument_type
declare -rxi err_invalid_nameref
declare -rxi err_invalid_arguments

gth="╔════════════════════════════════════════════════════════════════════════════"

gbh="╟────────────────────────────────────────────────────────────────────────────"

gmt="╟──────────────────────────────────────┴─────────────────────────────────────"

gmb="╟──────────────────────────────────────┬─────────────────────────────────────"

gln="╟──────────────────────────────────────┼─────────────────────────────────────"

gbl="║                                      │                                     "

gbt="╚══════════════════════════════════════╧═════════════════════════════════════"

ghf="║ %s\n"
gvf="║ %-36s │ %-35s\n"

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
declare -A graphical=(
    ["top_header"]=$gth
    ["bottom_header"]=$gbh
    ["top_mid_header"]=$gmt
    ["bottom_mid_header"]=$gmb
    ["header_format"]=$ghf
    ["line"]=$gln
    ["value_format"]=$gvf
    ["blank"]=$gbl
    ["bottom"]=$gbt
)

mbh="|:-------------------------------------|:------------------------------------|"
mln="|--------------------------------------|-------------------------------------|"
mbl="|                                      |                                     |"
mhf="| %-36s |                                     |\n"
mvf="| %-36s | %-35s |\n"

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
declare -A markdown=(
    ["top_header"]=""
    ["bottom_header"]=$mbh
    ["top_mid_header"]=$mln
    ["bottom_mid_header"]=$mln
    ["header_format"]=$mhf
    ["line"]=$mln
    ["value_format"]=$mvf
    ["blank"]=$mbl
    ["bottom"]=""
)

#-------------------------------------------------------------------------------
# @description Writes a header title line in the variable dump table, using the
# current table format (graphical or markdown).
#
# Notes:
#   - Internal helper used by `dump_vars`. Do not call directly — its signature
#     and behavior may change without notice.
#
# @arg $1 string Header text to display.
#
# @exitcode 0 Always.
#
# @stdout Formatted header line.
#
# @example
#   _write_title "Build Summary:"
#-------------------------------------------------------------------------------
function _write_title()
{
    local -n _table
    _table=$(get_table_format)

    # shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo".
    printf "${_table["header_format"]}" "$1"
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Writes a "name: value" line in the variable dump table for the named variable.
# Scalars, arrays, associative arrays, functions, and undefined/unbound variables are each
# formatted differently.
#
# Notes:
#   - Internal helper used by `dump_vars`. Do not call directly — its signature and behavior may
#     change without notice.
#
# @arg $1 nameref Name of the variable to display.
# @arg $2 bool If true, masks the value with the `$secret_str` placeholder instead of printing it
#   (optional, default: false).
#
# @exitcode 0 Always, except when argument validation fails.
# @exitcode 5 The name in $1 does not match the variable-name pattern.
#
# @stdout Formatted variable line showing the name and its value (or a placeholder for unbound
#   or invalid names).
#
# @example
#   _write_line "build_result"
#   _write_line "api_key" true
#-------------------------------------------------------------------------------
# shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo".
function _write_line()
{
    local -i _rc="$success"

    (( $# == 1 || $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires one or two arguments (provided $#): a variable name and an optional secret-masking flag."
    }
    [[ -v 1 && $1 =~ $varNameRegex ]] || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be a valid variable name (provided '${1-<missing>}')."
    }
    [[ ! -v 2 || $2 =~ ^(true|false)$ ]] || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 2, the secret-masking flag, to be 'true' or 'false' (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _table
    _table=$(get_table_format)
    local _format
    _format=${_table["value_format"]}
    local -n _v=$1
    local _value

    if is_defined_associative_array "$1"; then
        printf "$_format" "$1" "${#_v[@]} values:"
        local _key
        for _key in "${!_v[@]}"; do
            printf "$_format" "  [$_key]:" "  '${_v[$_key]}'"
        done
    elif is_defined_array "$1"; then
        printf "$_format" "$1" "${#_v[@]} items:"
        local -i _i
        for (( _i=0; _i < ${#_v[@]}; _i++ )); do
            printf "$_format" "  [$_i]:" "  '${_v[_i]}'"
        done
    elif is_defined_function "$1"; then
        printf "$_format" "$1" "$1()"
    elif is_defined_variable "$1"; then
        # shellcheck disable=SC2154
        case $1 in
            verbose      )  _value=$__saved_verbose ;;
            quiet        )  _value=$__saved_quiet ;;
            table_format )  _value=$__saved_table_format ;;
            _ignore      )  _value=$__saved_ignore ;;
            *            )  local secret=${2:-false}
                            [[ $secret == true ]] && _value="$secret_str" || _value="$_v" ;;
        esac
        printf "$_format" "$1" "$_value"
    else
        printf "$_format" "$1" "❌ '$1' is unbound, undefined, or invalid"
    fi

    return "$success"
}

#-------------------------------------------------------------------------------
# @description If `$verbose` is on, dumps a table of variable names and values, then, if `$quiet`
# is off, prompts the user to "press any key to continue" (see the `--quiet` and `--force` flags
# below, which can override both checks).
#
# @arg $@ mixed Variable names to dump (passed as strings without a leading `$`), interspersed
#   with any of the following flags:
#     -h, --header <text>  Display the header text and the table's dividing horizontal lines.
#                           Pass the top header text first — subsequent -h/--header occurrences
#                           are treated as mid headers.
#     -m, --markdown        Render the table in markdown format instead of the current format.
#     -g, --graphical       Render the table in graphical format instead of the current format.
#     -b, --blank           Display a blank line in the table.
#     -l, --line            Display a dividing horizontal line in the table.
#     -s, --secret <name>   Dump the named variable with its value masked.
#     -q, --quiet           Skip the "press any key to continue" prompt, even if `$quiet` is false.
#     -f, --force           Dump the variables even if `$verbose` is not true.
#
# @exitcode 0 Always.
#
# @stdout Formatted table of variable names and values.
#
# @example
#   dump_vars --header "Build Summary:" build_result warnings_count errors_count
# @example
#   dump_vars --markdown --header "Configuration:" config_path log_level --line setting1 setting2
#-------------------------------------------------------------------------------
function dump_vars()
{
    (( $# == 0 )) && return "$success"

    # save some current state - to be restored before returning from the function
    save_state

    # shellcheck disable=SC2154 # ci is referenced but not assigned.
    $ci && set_table_format "markdown"
    set +x
    local _v
    for _v in "$@"; do
        case ${_v,,} in
            -q|--quiet) set_quiet ;;
            -f|--force) set_verbose ;;
            -m|--markdown) set_table_format "markdown" ;;
            -g|--graphical) set_table_format "graphical" ;;
            * ) ;;
        esac
    done

    ! is_verbose && restore_state && return "$success"

    # for the proper behavior of this function change some global flags (to be restored before returning from the function)
    local -n _table
    _table=$(get_table_format)

    local _top=true  # is this the top header?
    local _hdr=false # is the next entry a header?
    local _v
    while (( $# > 0 )); do
        _v=$1
        shift
        case ${_v,,} in
            -h|--header )
                _v=$1
                shift
                $_top && echo "${_table["top_header"]}" || {
                    ! $_hdr && echo "${_table["top_mid_header"]}"
                }
                _top=false
                _hdr=false
                _write_title "$_v"
                [[ $1 != -h && $1 != --header ]] && _hdr=false || _hdr=true # is the next entry also a header?
                $_hdr && echo "${_table["bottom_header"]}" || echo "${_table["bottom_mid_header"]}"
                ;;
            -b|--blank )
                echo "${_table["blank"]}"
                ;;
            -l|--line )
                echo "${_table["line"]}"
                ;;
            -s|--secret )
                _v=$1
                shift
                [[ ! $_v =~ ^-.* ]] && _write_line "$_v" true
                ;;
            * )
                [[ ! $_v =~ ^-.* ]] && _write_line "$_v"
                # all options starting with '-' are already processed
                ;;
        esac
    done
    echo "${_table["bottom"]}";
    sync

    press_any_key
    restore_state
    return "$success"
}
