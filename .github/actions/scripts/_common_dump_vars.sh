#!/bin/bash

declare -r default_table_format="graphical"

## table_format determines the format in which dump tables are displayed by the
## `dump_vars` function(with graphical ASCII characters or with markdown)
declare -x table_format=${TABLE_FORMAT:-$default_table_format}


function set_table_format()
{
    shopt -s nocasematch
    if [[ "$1" =~ ^(graphical|markdown)$ ]]; then
        table_format=${1,,}
        [[ $table_format == "graphical" ]] && table=$graphical || table=$markdown
    else
        error "Invalid table format: $1"
    fi
    shopt -u nocasematch
    return 0
}

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

declare save_quiet
declare save_verbose
declare save_table_format
declare save_ignore
declare set_tracing_on

## Dumps a table of variables and in the end asks the user to "press any key to continue."
## If $verbose is false and --force is not specified, the function will not display anything.
## The names of the variables must be specified as strings - no leading $.
## Optionally the caller can specify flags like:
## -h or --header <text> will display the header text and the dividing horizontal lines in the table,
##         so PASS THE TOP HEADER TEXT FIRST. Subsequent headers will be treated as mid headers
## -m or --markdown will display the table in markdown format instead of the current format
## -g or --graphical will display the table in graphical format instead of the current format
## -b or --blank will display a blank line in the table
## -l or --line will display a dividing horizontal line in the table
## -q or --quiet will not ask the user to "press any key to continue" after dumping the variables, even if $quiet is false
## -f or --force will dump the variables even if $verbose is not true
function push_state() {
    save_quiet=$quiet
    save_verbose=$verbose
    save_table_format=$table_format
    save_ignore=$_ignore
    if [[ $- =~ .*x.* ]]; then set_tracing_on=1; else set_tracing_on=0; fi
    return 0
}

function pop_state() {
    quiet=$save_quiet
    verbose=$save_verbose
    table_format=$save_table_format
    _ignore=$save_ignore
    if ((set_tracing_on == 1)); then
        set -x
    fi
    return 0
}

function dump_vars() {
    if (( $# == 0 )); then
        return 0
    fi

    # save some current state - to be restored before returning from the function
    push_state
    _ignore=/dev/null
    set +x
    for v in "$@"; do
        case ${v,,} in
            -q|--quiet) quiet=true ;;
            -f|--force) verbose=true ;;
            -m|--markdown) table_format="markdown" ;;
            -g|--graphical) table_format="graphical" ;;
            * ) ;;
        esac
    done

    if [[ $verbose == false ]]; then
        pop_state
        return 0
    fi

    # for the proper behavior of this function change some global flags (to be restored before returning from the function)
    local table_name
    [[ $table_format == "markdown" ]] && table_name=markdown || table_name=graphical
    local -n table=$table_name

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
                else
                    echo "${table["top_mid_header"]}"
                    _write_title "$v"
                    echo "${table["bottom_mid_header"]}"
                fi
                ;;
            -b|--blank )
                echo "${table["blank"]}"
                ;;
            -l|--line )
                echo "${table["line"]}"
                ;;
            *)
                if [[ ! $v =~ ^-.* ]]; then
                    _write_line "$v";
                fi
                # all options starting with '-' are already processed
                ;;
        esac
        top=false
    done
    echo "${table["bottom"]}"
    sync
    press_any_key
    pop_state
    return 0
}

## internal function to write a line for a variable in the variable dump table
function _write_title() {
    local table_name
    [[ $table_format == "markdown" ]] && table_name=markdown || table_name=graphical
    local -n table=$table_name
    # shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo".
    printf "${table["header_format"]}" "$1"
    return 0
}

function _write_line() {
    local -n v=$1
    local value

    if declare -p "$1" 2>"$_ignore" | grep -q 'declare -[xir-]'; then
        value="$v"
    elif declare -p "$1" 2>"$_ignore" | grep -q 'declare -a'; then
        value="${#v[@]}: (${v[*]})"
    elif declare -p "$1" 2>"$_ignore" | grep -q 'declare -A'; then
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
    elif declare -pF "$1" 2>"$_ignore" | grep -q 'declare -f'; then
        value="$1()"
    elif ! is_defined "$1"; then
        value="****** unbound, undefined, or invalid"
    else
        value="$v"
    fi

    local table_name
    [[ $table_format == "markdown" ]] && table_name=markdown || table_name=graphical
    local -n table=$table_name

    # shellcheck disable=SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo".
    printf "${table["value_format"]}" "$1" "$value"
    return 0
}
