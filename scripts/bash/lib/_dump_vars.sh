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
    local -n table
    table=$(get_table_format)

    # shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo".
    printf "${table["header_format"]}" "$1"
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
     [[ $1 =~ $varNameRegex ]] || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a non-empty variable name as argument."
        return "$err_invalid_nameref"
    }

    local -n table
    table=$(get_table_format)
    local format
    format=${table["value_format"]}
    local -n v=$1
    local value

    if is_defined_associative_array "$1"; then
        printf "$format" "$1" "${#v[@]} values:"
        for key in "${!v[@]}"; do
            printf "$format" "  [$key]:" "  '${v[$key]}'"
        done
    elif is_defined_array "$1"; then
        printf "$format" "$1" "${#v[@]} items:"
        for i in "${!v[@]}"; do
            printf "$format" "  [$i]:" "  '${v[i]}'"
        done
    elif is_defined_function "$1"; then
        printf "$format" "$1" "$1()"
    elif is_defined_variable "$1"; then
        # shellcheck disable=SC2154
        case $1 in
            verbose      )  value=$__saved_verbose ;;
            quiet        )  value=$__saved_quiet ;;
            table_format )  value=$__saved_table_format ;;
            _ignore      )  value=$__saved_ignore ;;
            *            )  local secret=${2:-false}
                            [[ $secret == true ]] && value="$secret_str" || value="$v" ;;
        esac
        printf "$format" "$1" "$value"
    else
        printf "$format" "$1" "❌ '$1' is unbound, undefined, or invalid"
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
    local v
    for v in "$@"; do
        case ${v,,} in
            -q|--quiet) set_quiet ;;
            -f|--force) set_verbose ;;
            -m|--markdown) set_table_format "markdown" ;;
            -g|--graphical) set_table_format "graphical" ;;
            * ) ;;
        esac
    done

    ! is_verbose && restore_state && return "$success"

    # for the proper behavior of this function change some global flags (to be restored before returning from the function)
    local -n table
    table=$(get_table_format)

    local top=true  # is this the top header?
    local hdr=false # is the next entry a header?
    while (( $# > 0 )); do
        v=$1
        shift
        case ${v,,} in
            -h|--header )
                v=$1
                shift
                $top && echo "${table["top_header"]}" || {
                    ! $hdr && echo "${table["top_mid_header"]}"
                }
                top=false
                hdr=false
                _write_title "$v"
                [[ $1 != -h && $1 != --header ]] && hdr=false || hdr=true # is the next entry also a header?
                $hdr && echo "${table["bottom_header"]}" || echo "${table["bottom_mid_header"]}"
                ;;
            -b|--blank )
                echo "${table["blank"]}"
                ;;
            -l|--line )
                echo "${table["line"]}"
                ;;
            -s|--secret )
                v=$1
                shift
                [[ ! $v =~ ^-.* ]] && _write_line "$v" true
                ;;
            * )
                [[ ! $v =~ ^-.* ]] && _write_line "$v"
                # all options starting with '-' are already processed
                ;;
        esac
    done
    echo "${table["bottom"]}";
    sync

    press_any_key
    restore_state
    return "$success"
}
