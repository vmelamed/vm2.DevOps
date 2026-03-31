# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_DUMP_VARS_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_DUMP_VARS_SH_LOADED=1

declare -rx varNameRegex

declare -rxi success
declare -rxi err_invalid_nameref

gth="┌────────────────────────────────────────────────────────────────────────────"

gbh="├──────────────────────────────────────┬─────────────────────────────────────"

gmt="├──────────────────────────────────────┴─────────────────────────────────────"

gmb="├──────────────────────────────────────┬─────────────────────────────────────"

gln="├──────────────────────────────────────┼─────────────────────────────────────"

gbl="│                                      │                                     "

gbt="└──────────────────────────────────────┴─────────────────────────────────────"

ghf="│ %s\n"
gvf="│ \$%-35s │ %-35s\n"

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
mvf="| \$%-35s | %-35s |\n"

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
# Summary: Internal function to write a header title in the variable dump table.
# Parameters:
#   1 - title - header text to display
# Returns:
#   stdout: formatted header line
#   Exit code: 0 always
# Usage: _write_title <title>  # internal use only
# Notes: Internally used by dump_vars. Do not use, as it may change in the future.
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
# Summary: Internal function to write a variable name and value line in the dump table.
# Parameters:
#   1 - variable_name - name of the variable to display (passed as nameref)
#   2 - secret - if true, the value will be masked: ••••••
# Returns:
#   stdout: formatted variable line showing name and value
#   Exit code: 0 always
# Usage: _write_line <variable_name>  # internal use only
# Notes: Internally used by dump_vars. Do not use, as it may change in the future. Handles scalars, arrays, associative arrays, functions, and undefined variables differently.
#-------------------------------------------------------------------------------
function _write_line()
{
     [[ $1 =~ $varNameRegex ]] || {
        error 3 "${FUNCNAME[0]}() requires a non-empty variable name as argument."
        return "$err_invalid_nameref"
    }

    local -n v=$1
    local value

    if is_defined_associative_array "$1"; then
        first=true
        for key in "${!v[@]}"; do
            if [[ $first == true ]]; then
                value="${#v[@]}: ($key→${v[$key]}"
                first=false
            else
                value+=", $key→${v[$key]}"
            fi
        done
        value+=")"
    elif is_defined_array "$1"; then
        value="${#v[@]}: (${v[*]})"
    elif is_defined_function "$1"; then
        value="$1()"
    elif is_defined_variable "$1"; then
        # shellcheck disable=SC2154
        case $1 in
            verbose      )  value=$__save_verbose ;;
            quiet        )  value=$__save_quiet ;;
            table_format )  value=$__save_table_format ;;
            _ignore      )  value=$__save_ignore ;;
            *            )  local secret=${2:-false}
                            [[ $secret == true ]] && value="$secret_str" || value="$v" ;;
        esac
    else
        value="❌ '$1' is unbound, undefined, or invalid"
    fi

    local -n table
    table=$(get_table_format)

    # shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo".
    printf "${table["value_format"]}" "$1" "$value"
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: If $verbose is on, dumps a table of variables and in the end, if $quiet is off, asks the user to "press any key to continue." (see also the flags --quiet and --force below)
# Parameters:
#   1+ - variable_names - names of variables to dump (passed as strings without leading $ - nameref-s). Optionally the caller can put in the list flags like:
#        -h or --header <text>: will display the header text and the dividing horizontal lines in the table, so PASS THE TOP HEADER TEXT FIRST. Subsequent headers will be treated as mid headers
#        -m or --markdown: will display the table in markdown format instead of the current format
#        -g or --graphical: will display the table in graphical format instead of the current format
#        -b or --blank: will display a blank line in the table
#        -l or --line: will display a dividing horizontal line in the table
#        -q or --quiet: will not ask the user to "press any key to continue" after dumping the variables, even if $quiet is false
#        -f or --force: will dump the variables even if $verbose is not true
# Exit Codes:
#   0 - success
# Returns:
#   stdout: formatted table of variable names and values
# Side Effects: Will display output to stdout and prompt user for key press, if $quiet is false.
# Usage: dump_vars [options] <variable_name1> [<variable_name2> ...]
# Example:
#   dump_vars --header "Build Summary:" build_result warnings_count errors_count
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

    local top=true
    while (( $# > 0 )); do
        v=$1
        shift
        case ${v,,} in
            -h|--header )
                v=$1
                shift
                if [[ $top == true ]]; then
                    echo "${table["top_header"]}"
                    _write_title "$v"
                    echo "${table["bottom_header"]}"
                    top=false
                else
                    echo "${table["top_mid_header"]}"
                    _write_title "$v"
                    echo "${table["bottom_mid_header"]}"
                fi
                ;;
            -b|--blank )
                echo "${table["blank"]}"
                top=false
                ;;
            -l|--line )
                echo "${table["line"]}"
                top=false
                ;;
            -s|--secret )
                v=$1
                shift
                if [[ ! $v =~ ^-.* ]]; then
                    _write_line "$v" true;
                    top=false
                fi
                ;;
            * )
                if [[ ! $v =~ ^-.* ]]; then
                    _write_line "$v";
                    top=false
                fi
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
