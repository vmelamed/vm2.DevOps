# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# shellcheck disable=SC2154 # variable is referenced but not assigned.
if ! declare -pF "error" > "$_ignore"; then
    semver_dir="$(dirname "${BASH_SOURCE[0]}")"
    source "$semver_dir/_common.diagnostics.sh"
fi

## Displays a prompt, followed by "Press any key to continue..." and returns only after the script user
## presses a key. If there is defined variable $quiet with value "true", the function will not display prompt and will
## not wait for response.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function press_any_key()
{
    if [[ "$quiet" != true ]]; then
        read -n 1 -rsp 'Press any key to continue...' >&2
        echo
    fi
    return 0
}

## Asks the script user to respond yes or no to some prompt. If there is a defined variable $quiet with
## value "true", the function will not display the prompt and will assume the default response or 'y'.
## Parameter 1 - the prompt to confirm.
## Parameter 2 - the default response if the user presses [Enter]. When specified should be either 'y' or 'n'. Optional.
## Outputs the result to stdout as 'y' or 'n'.
function confirm()
{
    if [[ $# -eq 0 || $# -gt 2 || -z "$1" ]]; then
        error "The function confirm() requires at least one parameter: the prompt and a second, optional parameter -default response."
        return 2
    fi
    local prompt="$1"
    local default
    if [[ $# -eq 2 ]]; then
        default=${2,,}
    else
        default="y"
    fi
    if [[ "$quiet" == true ]]; then
        printf '%s' "$default"
        return 0
    fi

    local suffix

    if [[ "$default" == y ]]; then
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi

    local response
    while true; do
        read -rp "$prompt $suffix: " response >&2
        response=${response:-$default}
        response=${response,,}
        if [[ "$response" =~ ^[yn]$ ]]; then
            printf '%s' "$response"
            return 0;
        fi
        error "Please enter y or n." >&2
        errors=$((errors - 1))
    done
    [[ ${response,,} == "y" ]]
}

## Displays a prompt and a list of options to the script user and asks them to choose one of the options.
## Parameter 1 - the prompt to display before the options
## Parameter 2 - the text of the first option
## Parameter 3 - the text of the second option.
## ... - etc.
## The first option is the default one.
## The result will be printed in stdout as the number of the chosen option.
## The function will exit with code 2 if less than 3 parameters are specified.
function choose()
{
    if [[ $# -lt 3 ]]; then
        error "The function choose() requires 3 or more arguments: a prompt and at least two choices." >&2;
        return 2;
    fi

    local prompt=$1; shift
    local options=("$@")

    if [[ "$quiet" == true ]]; then
        printf '1'
        return 0
    fi

    echo "$prompt" >&2
    local -i i=1
    for o in "${options[@]}"; do
        if [[ $i -eq 1 ]]; then
            echo "  $i) $o (default)" >&2
        else
            echo "  $i) $o" >&2
        fi
        i=$((i+1))
    done

    local -i selection=1
    while true; do
        read -rp "Enter choice [1-${#options[@]}]: " selection
        selection=${selection:-1}
        [[ $selection = 0 ]] && selection=1
        if [[ $selection =~ ^[1-9][0-9]*$ && $selection -ge 1 && $selection -le ${#options[@]} ]]; then
            printf '%d' "$selection"
            return 0
        fi
        error "Invalid choice: $selection" >&2
    done
    return 0
}

## Prints the specified sequence of quoted values, separated by a separator and enclosed in parentheses.
## The function can take optionally named parameters to customize the output:
##   --quote|-q='<quote_char>': Specifies the quote character to use. Default is single quote (').
##     You can also specify --quote='' for no quotes (empty string).
##   --separator|-s='<separator_char>': Specifies the separator character to use. Default is comma (,).
##     Special values for separator are: nl (newline) or $'\n', tab (tab character) or $'\t', and '' (no separator).
##   --paren|-p='('|')'|'['|']'|'{'|'}'|'()'|'[]'|'{}': Specifies the type of parentheses to use. Default is no parentheses.
##     Special values for separator is: nl (newline) or $'\n'.
## Usage: print_sequence [--quote='<quote_char>'] [--separator='<separator_char>']
##                        [--paren='('|')'|'['|']'|'{'|'}'|'()'|'[]'|'{}'|nl] <value1> [<value2> ...]
## Note: The named parameters can be specified in any order before the list of values, but they should not be last.
## Examples:
##   print_sequence --quote='"' --separator='; ' --paren='()' apple banana cherry
##     Output: ("apple"; "banana"; "cherry")
##   print_sequence -p='[]' -s=' | ' 1 2 3 4 5
##     Output: [1 | 2 | 3 | 4 | 5]
##   print_sequence -p='[]' 1 2 3 4 5 -s=' | ' (putting a named parameter last spoils the output):
##     Output: [1 | 2 | 3 | 4 | 5 | ]
function print_sequence()
{
    open_paren=""
    close_paren=""
    quote="'"
    separator=","
    local arg
    for arg in "$@"; do
        case $arg in
            --quote=*|-q=* )
                quote="${arg#*=}"
                ;;
            --separator=*|-s=* )
                separator="${arg#*=}"
                # Handle special values
                case "$separator" in
                    nl) separator=$'\n' ;;
                    tab) separator=$'\t' ;;
                    * ) ;;
                esac
                ;;
            --paren=*|--parenthesis=*|-p=* )
                local paren_val="${arg#*=}"
                case "$paren_val" in
                    \(|\)|\(\) )
                        open_paren="("
                        close_paren=")"
                        ;;
                    \[|\]|\[\] )
                        open_paren="["
                        close_paren="]"
                        ;;
                    \{|\}|\{\} )
                        open_paren="{"
                        close_paren="}"
                        ;;
                    nl|$'\n'|'\n' )
                        # Handle special values
                        open_paren=$'\n'
                        close_paren=$'\n'
                        ;;
                    * )
                        warning "Unknown paren type: ${arg#*=}. Ignoring."
                        open_paren=""
                        close_paren=""
                        ;;
                esac
                ;;
            * ) ;;
        esac
    done

    [[ -n "$open_paren" ]] && printf "%s" "$open_paren" || true
    for arg in "$@"; do
        [[ "$arg" == -* || "$arg" == --* ]] && continue || true
        if [[ $arg != "${!#}" ]]; then
            printf "%s%s%s%s" "$quote" "$arg" "$quote" "$separator"
        else
            printf "%s%s%s" "$quote" "$arg" "$quote"
        fi
    done
    [[ -n "$close_paren" ]] && printf "%s" "$close_paren" || true
}
