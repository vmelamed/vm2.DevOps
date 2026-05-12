# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument
declare -rxi err_argument_value

declare -xa common_args

declare -xar valid_actions
declare -xr all_actions_str

declare -x  vm2_repos
declare -x  sot
declare -xa target_repos            # the target repositories specified as arguments. If not specified, the current directory is used as the only target repo.
declare -xA selectors_actions       # array [file] => [action string] for files specified on the CLI with --file* options
declare -x  summary_file
declare -x  diff_only
declare -xa arguments               # array of all arguments for logging and debugging purposes

declare -xA selectors_actions=()    # array [file] => [action string] for files specified with --file* options, the rest of the files - no action

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function get_arguments()
{
    local option

    while [[ $# -gt 0 ]]; do
        option="$1"; shift
        if get_common_arg "$option"; then
            continue
        fi

        value="$option"
        option=${option,,}
        case "$option" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --vm2-repos|-r )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for $option"
                vm2_repos="$1"; shift
                ;;

            --file*|-f* )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for $option"
                get_selector_action "$option" "$1"; shift
                ;;

            --source-of-truth|-s )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for $option"
                sot="$1"; shift
                ;;

            --summary )
                [[ $# -ge 1 ]] || usage "$err_missing_argument" "Missing value for $option"
                summary_file="$1"; shift
                ;;

            --all-repos|-a )
                target_repos=("${vm2_repositories[@]}")
                ;;

            --diff|-d )
                diff_only="true"
                ;;

            * ) ! is_in "$value" "${target_repos[@]}" &&
                    target_repos+=("$value")
                ;;
        esac
    done
}

function get_selector_action()
{
    [[ $# -eq 2 ]] || usage "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): option and file patterns list."

    local option="$1"
    local file_selector=$2
    local action=""

    # get the action from the option name, e.g. --file-ask-to-merge => "ask-to-merge"
    [[ $option =~ ^-(-file|f)(-([a-z-]+))?$ ]] ||
        usage "$err_unknown_argument" "Unknown argument: $option"

    # get the action and replace the dashes with spaces in the action name, e.g. "ask-to-merge" => "ask to merge"
    action="${BASH_REMATCH[3]//-/ }"

    # validate the action
    [[ -z $action ]] || is_in "$action" "${valid_actions[@]}" ||
        usage "$err_argument_value" "Invalid action: $action. Valid actions are: $all_actions_str"

    [[ $file_selector != -* ]] || usage "$err_argument_value" "The argument '$file_selector' does not appear to be a valid file selector."

    # get the patterns that the action applies to, and remember the action for those files in the selectors_actions array
    selectors_actions[$file_selector]="$action"
}

function dump_args()
{
    dump_vars \
        --header "Script Arguments:" \
        "${common_args[@]}" \
        --blank \
        "${arguments[@]}" \
        "$@"
}
