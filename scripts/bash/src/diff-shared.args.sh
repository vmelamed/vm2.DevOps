# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# vm2 core lib exit codes
declare -xri success
declare -xri err_invalid_arguments
declare -xri err_missing_argument
declare -xri err_unknown_argument
declare -xri err_argument_value
declare -xri err_logic_error
declare -xri err_io_failure
declare -xri err_tool_not_found

# vm2 core lib constants
declare -xr ci
declare -xra vm2_repositories
declare -xra sources_of_truth
declare -xr default_sot
declare -xr vm2_sot_repo_name
declare -xr default_vm2_repos_path

# vm2 core lib variable
declare -x usage_requested

# this scripts arguments
declare -x vm2_repos="${VM2_REPOS:-$default_vm2_repos_path}"
declare -xA selectors_actions=()        # array [file] => [action string] for files specified on the CLI with --file* options
declare -x summary_file=""              # the file where the summary of the differences and actions will be written. If not specified, a temporary file will be created.
declare -x diff_only=false              # if true, only show the differences without asking the user to take any actions. This is useful for CI validation of the shared content.
declare -x current_branch=false         # both vm2.DevOps and SoT repositories must be on the main branch by default, otherwise on their respective current branches
declare -xa target_repos=()             # the target repositories specified as arguments. If not specified, the current directory is used as the only target repo.
declare -x sot=$default_sot             # at the moment we support only one source of truth @ "$vm2_repos/$vm2_sot_repo_name/templates/$default_sot/content - $VM2_REPOS/templates/AddNewPackage/content
declare -xa arguments=(                 # array of all arguments for logging and debugging purposes
    vm2_repos
    selectors_actions
    summary_file
    diff_only
    current_branch
    target_repos
    --line
    sot
    sot_path
)

# SoT is validated and resolved to sot_path
declare -x sot_path=''
# target_repos are validated and resolved to target roots and target paths:
declare -a target_roots=()
declare -a target_paths=()

# this scripts variables
declare -x vm2_branch='main'
declare -x sot_branch='main'
declare -xar valid_actions
declare -xr all_actions_str

function get_arguments()
{
    parse_arguments "$@"
    usage_if_requested
    verify_environment
    resolve_arguments
    exit_if_has_errors
    dump_args
}

function parse_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case ${_option,,} in
            --vm2-repos|-r )
                (( $# >= 1 ))                                                   || usage "Missing value for $_option" -ec "$err_missing_argument"
                vm2_repos="$1"; shift
                ;;

            --file*|-f* )
                (( $# >= 1 ))                                                   || usage "Missing value for $_option" -ec "$err_missing_argument"
                get_selector_action "$_option" "$1"; shift
                ;;

            --summary-file|-sf )
                (( $# >= 1 ))                                                   || usage "Missing value for $_option" -ec "$err_missing_argument"
                summary_file="$1"; shift
                ;;

            --all-repositories|--all-repos|-all )
                local _repo
                for _repo in "${vm2_repositories[@]}"; do
                    is_in "$_repo" "${target_repos[@]}" || target_repos+=("$_repo")
                done
                ;;

            --diff|-d )
                diff_only="true"
                ;;

            --current-branch|-cb )
                current_branch=true
                ;;

            # -s|--source-of-truth )
            #     (( $# >= 1 )) || usage "Missing value for $_option" -ec "$err_missing_argument"
            #     sot="$1"; shift
            #     ;;
            #
            # When there is a second SoT add this to the usage text as well:
            #
            #  -s, --source-of-truth <sot>   The source-of-truth scenario to use. Must be one of the pre-defined scenarios in
            #                                '\$VM2_REPOS/vm2.Templates/templates/'.

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            -*) usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;

            * ) is_empty_array target_repos || ! is_in "$_option" "${target_repos[@]}" &&
                    target_repos+=("$_option")
                ;;
        esac
    done
    return "$success"
}

function verify_environment
{
    is_tool_present git                                                         || error "'git' is not installed. Please install it first." -ec "$err_tool_not_found"
    return "$success"
}

function resolve_arguments()
{
    local -i _rc=$success

    # adjust vm2_branch and sot_branch
    if $current_branch; then
        vm2_branch=''
        sot_branch=''
    fi

    # resolve and validate vm2_repos. We cannot continue without it.
    resolve_vm2_repos vm2_repos "$vm2_branch" "$sot_branch"                     || usage "Could not resolve the path of the vm2 repositories directory from the specified value of '$vm2_repos'." -ec $?
    trace "All vm2 repositories are expected to be in '$vm2_repos'"

    # resolve and validate sot. We cannot continue without it.
    is_in "$sot" "${sources_of_truth[@]}"                                       || usage "Invalid source of truth '$sot'. Valid values are: ${sources_of_truth[*]}." -ec "$err_argument_value"

    # resolve and validate sot_path
    get_vm2_sot_path "$vm2_repos" sot_path "$sot"                               || with_error _rc $? "Could not find the source of truth directory for the specified template '$sot' in the expected location in '$vm2_repos'."

    # if no repos were specified as arguments, use the current directory as the only target repo:
    ! is_empty_array target_repos || target_repos+=("$(pwd)")

    # resolve and validate target_repos, target_roots, target_paths
    local _target=''
    local _target_root
    local _target_path
    for _target in "${target_repos[@]}"; do
        _rc=$success
        resolve_target "$vm2_repos" "$_target" _target_root _target_path        || with_error _rc $? "Could not resolve the Git working tree root of the target '$_target'. Please, ensure that it exists and is a valid directory."
        (( _rc == success )) || continue

        target_roots+=("$_target_root")
        target_paths+=("$_target_path")
    done

    if $diff_only; then
        local _selector
        for _selector in "${!selectors_actions[@]}"; do
            selectors_actions["$_selector"]="$action_ignore"   # diff only
        done
    fi

    has_errors || [[ -n $summary_file ]] || {
        local _temp_file_template

        _temp_file_template="diff-shared-log-$(date +%Y%m%d-%H%M%S)-XXXXXX.md"
        summary_file=$(mktemp -p /tmp "$_temp_file_template")                   || with_error _rc "$err_io_failure"  "Failed to create a temporary file"
        (( _rc != success )) || add_trap "rm -f ${summary_file@Q}" EXIT
    }

    readonly current_branch
    readonly vm2_branch
    readonly sot_branch
    readonly vm2_repos
    readonly sot
    readonly sot_path
    readonly target_repos
    readonly target_roots
    readonly target_paths
    readonly diff_only
    readonly summary_file

    return "$success"
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "$script_name arguments:"

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
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#):" \
                                                                                       "  - option" \
                                                                                       "  - file selector" \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _option="$1"
    local _file_selector=$2
    local _action=""

    # get the action from the option name, e.g. --file-ask-to-merge => "ask-to-merge"
    [[ $_option =~ ^-(-file|f)(-?([a-z-]+))?$ ]] ||
        error "Unknown argument: $_option" -ec "$err_unknown_argument"

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
        *                                   ) error "Invalid action: $_action. Valid actions are: $all_actions_str"  -ec "$err_argument_value" ;;
    esac

    [[ $_file_selector != -* ]] ||
        error "The argument '$_file_selector' does not appear to be a valid file selector." -ec "$err_argument_value"

    exit_if_has_errors

    trace "File selector '$_file_selector' with action '$_action'"

    # get the patterns that the action applies to, and remember the action for those files in the selectors_actions array
    selectors_actions[$_file_selector]="$_action"
}
