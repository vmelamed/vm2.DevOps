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
declare -xri err_repo_with_no_ci
declare -xri err_repo_not_in_vm2_repos
declare -xri err_io_failure

declare -xr ci
declare -xr default_vm2_repos_path
declare -xr vm2_sot_repo_name
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
    parse_arguments "$@"
    usage_if_requested
    verify_environment
    resolve_arguments
    exit_if_has_errors
    dump_args
}

function parse_arguments()
{
    local _option _repo

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            -r|--vm2-repos )
                (( $# >= 1 )) || usage "Missing value for $_option" -ec "$err_missing_argument"
                vm2_repos="$1"; shift
                ;;

            # For now we have only one source of truth - 'AddNewPackages', so this option is effectively unused.
            # -s|--source-of-truth )
            #     (( $# >= 1 )) || usage "Missing value for $_option" -ec "$err_missing_argument"
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
                (( $# >= 1 )) || usage "Missing value for $_option" -ec "$err_missing_argument"
                summary_file="$1"; shift
                ;;

            # reserved: get_common_arg consumes these options before this case. Effectively this arm never runs BUT it lets
            # ShellCheck to flag (SC2221/SC2222) any script-specific arm that tries to reuse one of them, and it bugs out
            # if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            -*) usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;

            * ) is_in "$_option" "${!target_repos[@]}" || target_repos+=([$_option]='')
                ;;
        esac
    done

    return "$success"
}

function verify_environment()
{

    return "$success"
}

function resolve_arguments()
{
    local -i _rc=$success;

    [[ -n $summary_file ]] || {
        summary_file=$(mktemp -p /tmp "update-packages-summary-$(date +%Y%m%d-%H%M%S)-XXXXXX.md") \
                                                                                || with_error "$err_io_failure" _rc "Failed to create a temporary file"
        (( _rc != success )) || add_trap "rm -f ${summary_file@Q}" EXIT
    }
    is_valid_path "$summary_file"                                               || with_error "$err_invalid_path" _rc "Invalid summary file path: '$summary_file'."
    resolve_vm2_repos vm2_repos                                                 || vm2_repos=''
    is_in "$sot" "${sources_of_truth[@]}"                                       || with_error "$err_argument_value" _rc "Invalid source of truth '$sot'. Valid values are: ${sources_of_truth[*]}."

    has_errors || [[ -z $vm2_repos ]] || get_vm2_sot_path "$vm2_repos" sot_path "$sot" \
                                                                                || return "$success"

    local _repo_path
    local _repo

    if is_empty_array target_repos; then

        local _invalid=false

        # resolve the repo of the current directory:
        resolve_repo_root "$vm2_repos" '' _repo_path _                          || { error "The current directory is not a vm2 repository. No other repositories specified." -ec $?; _invalid=true; }
        $_invalid || {
            _repo=$(basename "$_repo_path")
            is_in "$_repo" "${vm2_repositories[@]}"
        }                                                                       || { error "The repository of the current directory '$_repo' is not in the vm2 repositories list. No other repositories specified." -ec "$err_repo_not_in_vm2_repos"; _invalid=true; }
        $_invalid ||
            [[ -s $_repo_path/$dpp_file_name ]]                                 || { error "Missing '$dpp_file_name' in '$_repo'. No other repositories specified." -ec "$err_invalid_file"; _invalid=true; }
        $_invalid ||
            validate_package_lines "$_repo_path/$dpp_file_name"                 || { error "Invalid package lines in $_repo_path/$dpp_file_name." -ec $?; _invalid=true; }
        $_invalid ||
            target_repos[$_repo]=$_repo_path
    else
        for _repo in "${!target_repos[@]}"; do
            is_in "$_repo" "${vm2_repositories[@]}"                             || { error "The specified repository '$_repo' is not in the vm2 repositories list." -ec "$err_repo_not_in_vm2_repos"; continue; }

            resolve_repo_root "$vm2_repos" "$_repo" _repo_path _                || { error "Could not resolve '$_repo'" -ec $?; continue; }

            [[ -s "$_repo_path/$dpp_file_name" ]]                               || { warning "Missing '$dpp_file_name' in '$_repo'. Skipping the repo.";
                unset "target_repos[$_repo]"
                continue
            }

            validate_package_lines "$_repo_path/$dpp_file_name"                 || { error "Invalid package lines in $_repo_path/$dpp_file_name." -ec $?; continue; }

            target_repos[$_repo]=$_repo_path
        done
    fi

    ! is_in "$vm2_sot_repo_name" "${!target_repos[@]}" ||
        validate_package_lines "$sot_path/$dpp_file_name"                       || error "Invalid package lines in $sot_path/$dpp_file_name." -ec $?

    has_errors || {
        echo "# Update Packages Summary"
        echo
    } > "$summary_file"                                                         || error "Failed to write to summary file: '$summary_file'." -ec "$err_invalid_file"

    # at this point all arguments have been initialized, validated and necessary paths have been resolved
    readonly vm2_repos
    readonly sot
    readonly sot_path
    readonly target_repos
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
        --header "Arguments for $script_name:"

        "${arguments[@]}"

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
