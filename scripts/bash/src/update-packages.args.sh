# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# constants from core:
declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_invalid_path
declare -xri err_invalid_file

declare -xr ci
declare -xr default_vm2_repos_path
declare -xr default_sot
declare -xr dpp_file_name
declare -xra vm2_repositories
declare -xra sources_of_truth

# this script's arguments
declare -x vm2_repos="${VM2_REPOS:-$default_vm2_repos_path}"    # the path to the folder containing all vm2 repositories, usually '$VM2_REPOS'
declare -x sot=$default_sot                                     # the source of truth name, usually 'AddNewPackages'
declare -x sot_path                                             # the path to the source of truth folder, usually '$VM2_REPOS/vm2.Templates/templates/<sot>/content'
declare -A target_repos=()                                      # dictionary: repo name => repo path
declare -x summary_file=''                                      # the path to the summary file for the update operation(s)

declare -a arguments=(
    vm2_repos
    sot
    sot_path
    target_repos
    summary_file
)

function get_arguments()
{
    local _option _repo

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            -r|--vm2-repos )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                vm2_repos="$1"; shift
                ;;

            # For now we have only one source of truth - 'AddNewPackages', so this option is effectively unused.
            # -s|--source-of-truth )
            #     (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
            #     sot="$1"; shift
            #     ;;
            #
            # When there is a second SoT add this to the usage text as well:
            #
            #  -s, --source-of-truth <sot>   The source-of-truth scenario to use. Must be one of the pre-defined scenarios in
            #                                '\$VM2_REPOS/vm2.Templates/templates/'.

            -all|--all-repos|--all-repositories )
                for _repo in "${vm2_repositories[@]}"; do
                    is_in "$_repo" "${!target_repos[@]}" || target_repos+=([$_repo]='')
                done
                ;;

            -sf|--summary-file )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for $_option"
                summary_file="$1"; shift
                ;;

            # reserved: get_common_arg consumes these options before this case. Effectively this arm never runs BUT it lets
            # ShellCheck to flag (SC2221/SC2222) any script-specific arm that tries to reuse one of them, and it bugs out
            # if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            * ) is_in "$_option" "${!target_repos[@]}" || target_repos+=([$_option]='')
                ;;
        esac
    done

    validate_args
    dump_args
    usage_if_requested
}

function validate_args()
{
    resolve_vm2_repos vm2_repos || true

    has_errors || is_in "$sot" "${sources_of_truth[@]}" ||
        error -ec "$err_argument_value" "Invalid source of truth '$sot'. Valid values are: ${sources_of_truth[*]}."

    has_errors || get_vm2_sot_path "$vm2_repos" sot_path "$sot" || true

    ! is_empty_array target_repos || error -ec "$err_argument_value" "No target repositories specified."

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    if ! has_errors; then

        local _repo _repo_path

        for _repo in "${!target_repos[@]}"; do
            if is_in "$_repo" "${vm2_repositories[@]}" &&
               resolve_repo_root "$vm2_repos" "$_repo" _repo_path _; then
                [[ -f "$_repo_path/$dpp_file_name" ]] || {
                    warnings+=("Skipped repository '$_repo': it does not have a '$dpp_file_name' file.")
                    continue
                }
                target_repos[$_repo]=$_repo_path
            else
                error -ec "$err_argument_value" "Could not resolve repository '$_repo'."
                continue
            fi
        done
    fi

    has_errors || [[ -n $summary_file ]] || {
        summary_file=$(mktemp -p /tmp "update-packages-summary-$(date +%Y%m%d-%H%M%S)-XXXXXX.md")
        add_trap "rm -f ${summary_file@Q}" EXIT
    }

    has_errors || is_valid_path "$summary_file" ||
        error -ec "$err_invalid_path" "Invalid summary file path: '$summary_file'."

    has_errors || {
        echo "# Update Packages Summary"
        echo
    } > "$summary_file" ||
        error -ec "$err_invalid_file" "Failed to write to summary file: '$summary_file'."

    exit_if_has_errors true

    # at this point all arguments have been initialized, validated and necessary paths have been resolved
    readonly vm2_repos
    readonly sot
    readonly sot_path
    readonly target_repos
    readonly summary_file
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
