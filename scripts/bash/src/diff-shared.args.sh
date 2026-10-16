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
declare -xri err_logic_error

declare -xr ci

declare -xar valid_actions
declare -xr all_actions_str

declare -x  vm2_repos
declare -x  sot
declare -x  current_branch
    declare -xa target_repos        # the target repositories specified as arguments. If not specified, the current directory is used as the only target repo.
declare -xA selectors_actions       # array [file] => [action string] for files specified on the CLI with --file* options
declare -x  diff_only
declare -x  summary_file
declare -xa vm2_repositories
declare -xa arguments=(             # array of all arguments for logging and debugging purposes
    vm2_repos
    sot
    target_repos
    selectors_actions
    diff_only
    all_repos
    current_branch
    summary_file
)

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case ${_option,,} in
            --vm2-repos|-r )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                vm2_repos="$1"; shift
                ;;

            # -s|--source-of-truth )
            #     (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
            #     sot="$1"; shift
            #     ;;
            #
            # When there is a second SoT add this to the usage text as well:
            #
            #  -s, --source-of-truth <sot>   The source-of-truth scenario to use. Must be one of the pre-defined scenarios in
            #                                '\$VM2_REPOS/vm2.Templates/templates/'.

            --all-repositories|--all-repos|-all )
                for _repo in "${vm2_repositories[@]}"; do
                    is_in "$_repo" "${target_repos[@]}" || target_repos+=("$_repo")
                done
                ;;

            --file*|-f* )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                get_selector_action "$_option" "$1"; shift
                ;;

            --diff|-d )
                diff_only="true"
                ;;

            --summary-file|-sf )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                summary_file="$1"; shift
                ;;

            --current-branch|-cb )
                current_branch=true
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            * ) is_empty_array target_repos || ! is_in "$_option" "${target_repos[@]}" &&
                    target_repos+=("$_option")
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
declare -xr action_copy_shared
declare -xr action_ask_to_copy_shared

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
        "i"  | "$action_ignore"             ) _action="$action_ignore" ;;
        "mc" | "$action_merge_or_copy"      ) _action="$action_merge_or_copy" ;;
        "am" | "$action_ask_to_merge"       ) _action="$action_ask_to_merge" ;;
        "m"  | "$action_merge"              ) _action="$action_merge" ;;
        "ac" | "$action_ask_to_copy"        ) _action="$action_ask_to_copy" ;;
        "c"  | "$action_copy"               ) _action="$action_copy" ;;
        "cs" | "$action_copy_shared"        ) _action="$action_copy_shared" ;;
        "acs"| "$action_ask_to_copy_shared" ) _action="$action_ask_to_copy_shared" ;;
        ""                                  ) ;;
        *                                   ) error -ec "$err_argument_value" "Invalid action: $_action. Valid actions are: $all_actions_str" ;;
    esac

    [[ $_file_selector != -* ]] ||
        error -ec "$err_argument_value" "The argument '$_file_selector' does not appear to be a valid file selector."

    exit_if_has_errors

    trace "File selector '$_file_selector' with action '$_action'"

    # get the patterns that the action applies to, and remember the action for those files in the selectors_actions array
    selectors_actions[$_file_selector]="$_action"
}
