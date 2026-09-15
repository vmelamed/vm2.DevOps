# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_argument_value

declare -x ci

declare -xar valid_actions
declare -xr all_actions_str

declare -x  vm2_repos
declare -x  sot
declare -x  not_main
declare -xa target_repos            # the target repositories specified as arguments. If not specified, the current directory is used as the only target repo.
declare -xA selectors_actions       # array [file] => [action string] for files specified on the CLI with --file* options
declare -x  diff_only
declare -x  summary_file
declare -xa arguments               # array of all arguments for logging and debugging purposes
declare -xa vm2_repositories

function get_arguments()
{
    local __option
    local value

    while (( $# > 0 )); do
        __option="$1"; shift
        if get_common_arg "$__option"; then
            continue
        fi

        value="$__option"
        __option=${__option,,}
        case "$__option" in
            # do not use the common options - they were already processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --vm2-repos|-r )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $__option"
                vm2_repos="$1"; shift
                ;;

            --source-of-truth|-s )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $__option"
                sot="$1"; shift
                ;;

            --all-repos|-a )
                target_repos=("${vm2_repositories[@]}")
                ;;

            --file*|-f* )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $__option"
                get_selector_action "$__option" "$1"; shift
                ;;

            --diff|-d )
                diff_only="true"
                ;;

            --summary )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $__option"
                summary_file="$1"; shift
                ;;

            --not-main|-nm )
                not_main=true
                ;;

            * ) (( ${#target_repos[@]} == 0 )) || ! is_in "$value" "${target_repos[@]}" &&
                    target_repos+=("$value")
                ;;
        esac
    done

    [[ -n "$summary_file" ]] || {
        summary_file=$(mktemp -p /tmp "diff-shared-log-$(date +%Y%m%d-%H%M%S)-XXXXXX.md")
        trap 'rm -f "$summary_file"' EXIT
    }

    dump_args

    usage_if_requested
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        "${arguments[@]}"

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}

declare -xr action_ignore
declare -xr action_merge_or_copy
declare -xr action_ask_to_merge
declare -xr action_merge
declare -xr action_ask_to_copy
declare -xr action_copy

function get_selector_action()
{
    (( $# == 2 )) || bug "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#):" \
                                "  - option" \
                                "  - file selector"

    exit_if_has_bugs

    local _option="$1"
    local _file_selector=$2
    local _action=""

    # get the action from the option name, e.g. --file-ask-to-merge => "ask-to-merge"
    [[ $_option =~ ^-(-file|f)(-?([a-z-]+))?$ ]] ||
        error -ec "$err_unknown_argument" "Unknown argument: $_option"

    # get the action and replace the dashes with spaces in the action name, e.g. "ask-to-merge" => "ask to merge"
    _action="${BASH_REMATCH[3]//-/ }"

    case "$_action" in
        "i"  | "$action_ignore" ) _action="$action_ignore" ;;
        "mc" | "$action_merge_or_copy" ) _action="$action_merge_or_copy" ;;
        "am" | "$action_ask_to_merge" ) _action="$action_ask_to_merge" ;;
        "m"  | "$action_merge" ) _action="$action_merge" ;;
        "ac" | "$action_ask_to_copy" ) _action="$action_ask_to_copy" ;;
        "c"  | "$action_copy" ) _action="$action_copy" ;;
        * ) ;;
    esac

    # validate the action
    [[ -z $_action ]] || is_in "$_action" "${valid_actions[@]}" ||
        error -ec "$err_argument_value" "Invalid action: $_action. Valid actions are: $all_actions_str"

    trace "File selector '$_file_selector' with action '$_action'"

    [[ $_file_selector != -* ]] ||
        error -ec "$err_argument_value" "The argument '$_file_selector' does not appear to be a valid file selector."

    exit_if_has_errors

    # get the patterns that the action applies to, and remember the action for those files in the selectors_actions array
    selectors_actions[$_file_selector]="$_action"
}
