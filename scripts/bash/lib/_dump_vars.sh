# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#---------------------------------------------------------------------------------------------
# This script defines functions for dumping variable names and values in a formatted table.
# It supports different table formats (graphical, markdown) and handles scalars, arrays, associative arrays, functions, and undefined variables.
#---------------------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_DUMP_VARS_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DUMP_VARS_SH_LOADED=1

declare -xri success
declare -xri err_argument_type
declare -xri err_invalid_nameref
declare -xri err_invalid_arguments
declare -xri err_missing_argument

declare -xr secret_str

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
declare -A graphical=(
    ["id"]="graphical"
    ["top_top_header"]="╔═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════\n"
    ["fmt_top_header"]="║ %-40s\n"
    ["bot_top_header"]="╟──────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────\n"

    ["top_sub_header"]="╟─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────\n"

    ["top_mid_header"]="╟──────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────────────\n"
    ["fmt_mid_header"]="║ %-40s\n"
    ["bot_mid_header"]="╟──────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────\n"

    ["fmt_left_value"]="║ %-40s │ %-80s\n"
    ["fmt_ind__value"]="║   %-38s │   %-78s\n"

    ["blank_dsh_line"]="╟──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────\n"
    ["blank_spc_line"]="║                                          │                                                                                  \n"
    ["bot_bot_header"]="╚══════════════════════════════════════════╧══════════════════════════════════════════════════════════════════════════════════\n"
)

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
declare -A markdown=(
    ["id"]="markdown"
    ["top_top_header"]=""
    ["fmt_top_header"]="| %-40s |                                                                                  |\n"
    ["bot_top_header"]="|:-----------------------------------------|:---------------------------------------------------------------------------------|\n"

    ["top_sub_header"]="|:-----------------------------------------|:---------------------------------------------------------------------------------|\n"

    ["top_mid_header"]="|──────────────────────────────────────────|──────────────────────────────────────────────────────────────────────────────────|\n"
    ["fmt_mid_header"]="| %-40s |                                                                                  |\n"
    ["bot_mid_header"]="|──────────────────────────────────────────|──────────────────────────────────────────────────────────────────────────────────|\n"

    ["fmt_left_value"]="| %-40s | %-80s |\n"
    ["fmt_ind__value"]="|   %-38s |   %-78s |\n"

    ["blank_dsh_line"]="|──────────────────────────────────────────|──────────────────────────────────────────────────────────────────────────────────|\n"
    ["blank_spc_line"]="|                                          |                                                                                  |\n"
    ["bot_bot_header"]=""
)

# The name of the current table being used for output formatting: either "graphical" or "markdown"
declare -n _current_table

# ref. the common dotnet variables
declare -x preprocessor_symbols
declare -x configuration
declare -x framework
declare -x runtime
declare -x artifacts
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password

# for use in dump_vars() as "${common_dotnet_args_to_output[@]}"
declare -xra dump_common_dotnet_args=(
    preprocessor_symbols
    configuration
    framework
    runtime
    artifacts
    minver_tag_prefix
    minver_prerelease_id
    gh_nuget_username
    --secret gh_nuget_password
)

#---------------------------------------------------------------------------------------------
# @description Writes a header title line in the variable dump table, using the
# current table format (graphical or markdown).
#
# Notes:
#   - Internal helper used by `dump_vars`. Do not call directly — its signature
#     and behavior may change without notice.
#
# @arg $1 string Header text to display.
#
# @exitcode success/positive=0
#
# @stdout Formatted header line.
#
# @example
#   _write_title "Build Summary:"
#---------------------------------------------------------------------------------------------
function _write_title()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 argument (provided $#) - the table header text."

    exit_if_has_bugs

    # shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo".
    printf "${_current_table["fmt_top_header"]}" "$1"
}

#---------------------------------------------------------------------------------------------
# @description Writes a "name: value" line in the variable dump table for the named variable.
# Scalars, arrays, associative arrays, functions, and undefined/unbound variables are each
# formatted differently.
#
# Notes:
#   - Internal helper used by `dump_vars`. Do not call directly — its signature and behavior
#     may change without notice.
#
# @arg $1 nameref to the variable to display.
# @arg $2 bool if true, prints the value of the `$secret_str` instead of the actual value
# @arg $3 string name to display instead of the variable name. Optional if not provided, the
#   variable's actual name is used.
#
# @exitcode success/positive=0
#
# @stdout Formatted variable line showing the name and its value (or a placeholder for unbound
#   or invalid names).
#
# @example
#   _write_line "build_result"
#   _write_line "api_key" true
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo".
function _write_line()
{
    local -i _rc="$success"
    local _has_name=false

    (( $# == 2 || $# == 3 ))                                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two or three arguments (provided $#):" \
                                                                                                    "  - nameref to the variable to display" \
                                                                                                    "  - bool, if true, masks the value with the \$secret_str placeholder instead of printing it." \
                                                                                                    "  - string, optional name to display instead of the variable name."
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ ! -v 3 || -z $3 ]]           || _has_name=true
    [[ ! -v 1 ]] || $_has_name      || is_variable_name "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to be a valid variable name (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_boolean "$2"                          || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 2, the secret-masking flag, to be 'true' or 'false' (provided '${2:-<none>}')."

    exit_if_has_bugs

    local _format _format_i
    _format=${_current_table["fmt_left_value"]}
    _format_i=${_current_table["fmt_ind__value"]}

    local _name=${3:-$1}
    local _value
    local _is_secret=$2

    if is_defined_associative_array "$1"; then
        local -n _var=$1
        printf "$_format" "$_name" "${#_var[@]} entries:"
        local _key
        for _key in "${!_var[@]}"; do
            printf "$_format_i" "$_key" "${_var[$_key]}"
        done

    elif is_defined_indexed_array "$1"; then
        local -n _var=$1
        printf "$_format" "$_name" "${#_var[@]} items:"
        local -i _i
        for (( _i=0; _i < ${#_var[@]}; _i++ )); do
            printf "$_format_i" "[$_i]:" "${_var[_i]}"
        done

    elif is_defined_function "$1"; then
        printf "$_format" "$_name" "$1()"

    elif is_defined_variable "$1"; then
        local -n _var=$1
        [[ $_is_secret == true && -n  $_var ]] && _value="$secret_str" || _value="$_var"
        printf "$_format" "$_name" "$_value"

    elif $_has_name; then
        printf "$_format" "$_name" "$1"

    else
        printf "$_format" "$_name" '❌  '"$_name"' is unbound, undefined, or invalid'
    fi
}

#---------------------------------------------------------------------------------------------
# @description If `$verbose` is on, dumps a table of variable names and values, then, if `$quiet`
# is off, prompts the user to "press any key to continue" (see the `--quiet` and `--force` flags
# below, which can override both checks).
#
# @arg $@ mixed Variable names to dump (passed as strings without a leading `$`), interspersed
#   with any of the following flags:
#     -h, --header <text>   Display the header text and the table's dividing horizontal lines
#                           Pass the top header text first — subsequent -h/--header
#                           occurrences are treated as mid headers
#     -n, --name            The next entry specifies a display name for the following value,
#                           instead of the name of the variable
#     -m, --markdown        Render the table in markdown format instead of the current format
#     -g, --graphical       Render the table in graphical format instead of the current format
#     -b, --blank           Display a blank line in the table
#     -l, --line            Display a dividing horizontal line in the table
#     -s, --secret <name>   Dump the named variable with its value masked
#     -ci, --common-dotnet-args  Dump the common dotnet arguments (see `dump_common_dotnet_args` array)
#     -c, --core-state      Dump the core state (see `core_state` associative array)
#     -q, --quiet           Skip the "press any key to continue" prompt, even if `$quiet` is false
#     -f, --force           Dump the variables even if `$verbose` is not true
#
# @exitcode success/positive=0
#
# @stdout Formatted table of variable names and values.
#
# @example
#   dump_vars --header "Build Summary:" build_result warnings_count errors_count
# @example
#   dump_vars --markdown --header "Configuration:" config_path log_level --line setting1 setting2
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf '..%s..' "$foo".
function dump_vars()
{
    (( $# == 0 )) && return "$success"

    local _fmt=''

    get_table_format _fmt
    trace -sd 10 "Current table format: $_fmt"

    # save the current global state - to be restored before returning from the function
    local -A _core_state=()
    save_state _core_state

    set +x
    local _flag
    for _flag in "$@"; do
        case ${_flag,,} in
            -q|--quiet) set_quiet ;;
            -f|--force) set_verbose ;;
            -m|--markdown) set_table_format "markdown" ;;
            -g|--graphical) set_table_format "graphical" ;;
            * ) ;;
        esac
    done

    ! is_verbose &&
        restore_state _core_state &&
        return "$success"

    get_table_format _fmt
    _current_table=$_fmt

    trace -sd 10 "Current table format: ${!_current_table}"

    # for the proper behavior of this function change some global flags (to be restored before returning from the function)
    local _top=true  # is this the top header?
    local _curr_is_header=false # is the current entry a header?
    local _next_is_header=false # is the next entry a header?
    local _secret=false # is the current value a secret?
    local _header_text # the text of the current header
    local _name='' # the name of the current variable if specified with -n|--name

    printf "${_current_table["top_top_header"]}"
    while (( $# > 0 )); do
        _flag=$1
        shift
        case ${_flag,,} in
            # already processed above in the initial flag parsing loop
            -q|-f|-m|-g|--quiet|--force|--markdown|--graphical) ;;

            -n|--name )
                (( $# > 0 )) && {
                    _name=$1
                    shift
                 } || _name="❌  missing name"
                ;;

            -h|--header )
                _curr_is_header=true
                _header_text="❌  The text of the header is missing"
                (( $# > 0 )) && _header_text=$1 && shift
                $_top &&
                    printf "${_current_table["fmt_top_header"]}" "$_header_text" ||
                    printf "${_current_table["fmt_mid_header"]}" "$_header_text"
                ;;

            -c|--core-state )
                _write_line _core_state false
                ;;

            -ci|--common-dotnet-args )
                _secret=false
                local _arg
                for _arg in "${dump_common_dotnet_args[@]}"; do
                    [[ $_arg == @(-s|--secret) ]] && _secret=true && continue
                    _write_line "$_arg" "$_secret"
                    _secret=false
                done
                ;;

            -b|--blank )
                printf "${_current_table["blank_spc_line"]}"
                ;;

            -l|--line )
                printf "${_current_table["blank_dsh_line"]}"
                ;;

            -s|--secret )
                _secret=true
                ;;

            * ) _write_line "$_flag" "$_secret" "$_name"
                _name=''
                _secret=false
                # all options starting with '-' are already processed
                ;;
        esac

        if (( $# > 0 )); then
            [[ $1 == -h || $1 == --header ]] && _next_is_header=true
            if $_curr_is_header; then
                if $_next_is_header; then
                    $_top &&
                        printf "${_current_table["top_sub_header"]}" || # finish the top or middle header and start the sub-header section
                        printf "${_current_table["bot_top_header"]}"
                else
                    $_top &&
                        printf "${_current_table["bot_top_header"]}" || # finish the top header
                        printf "${_current_table["bot_mid_header"]}"    # finish the middle header
                fi
                _top=false
                _curr_is_header=false
            else
                $_next_is_header && ! $_top &&
                    printf "${_current_table["top_mid_header"]}"
            fi
        fi
        _next_is_header=false
    done

    printf "${_current_table["bot_bot_header"]}";
    sync

    press_any_key
    restore_state _core_state
    return "$success"
}
