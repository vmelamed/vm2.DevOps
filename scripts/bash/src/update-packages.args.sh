# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# constants from lib:
declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_repo_with_no_ci
declare -xri err_not_git_directory

declare -xr ci
declare -xra vm2_repositories
declare -xra sources_of_truth
declare -xr default_sot

# this script's arguments
declare -x vm2_repos
declare -x sot_path
declare -x sot=$default_sot
declare -A target_repos
declare -x summary_file=''
declare -a arguments=(
    vm2_repos
    sot_path
    sot
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

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;

            * ) is_empty_array target_repos || ! is_in "$_option" "${!target_repos[@]}" &&
                    target_repos+=([$_option]='')
                ;;
        esac
    done

    validate_args
    dump_args
    usage_if_requested
}

function validate_args()
{
    local -i _rc=$success
    local _repo _repo_path

    resolve_vm2_repos vm2_repos '' '' &&
    get_vm2_sot_path "$vm2_repos" "$sot" sot_path &&
    info "The Source of Truth '$sot' folder is in '$sot_path'"

    is_in "$sot" "${sources_of_truth[@]}" || error -ec "$err_argument_value" "Invalid source of truth '$sot'. Valid values are: ${sources_of_truth[*]}.";

    if ! is_empty_array target_repos; then
        for _repo in "${!target_repos[@]}"; do
            if is_in "$_repo" "${vm2_repositories[@]}" &&
               resolve_repo_root "$vm2_repos" "$_repo" _repo_path _; then
                target_repos[$_repo]=$_repo_path
            else
                error -ec "$err_argument_value" "Could not resolve repository '$_repo'."
            fi
        done
    else
        error -ec "$err_argument_value" "No target repositories specified."
    fi

    exit_if_has_errors true

    readonly vm2_repos
    readonly sot
    readonly sot_path
    readonly summary_file
    readonly target_repos
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
