# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# core lib exit codes
declare -xri success
declare -xri err_not_found
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

# core lib constants
declare -xr ci
declare -xra dump_common_dotnet_args

# core lib defaults

# core lib variables

# this scripts arguments
build_project=${BUILD_PROJECT:-}

function get_arguments()
{
    local _option
    local _positional_arg_set=false

    while (( $# > 0 )); do
        _option="$1"
        shift
        get_common_arg "$_option" && continue

        get_common_dotnet_arg "$_option" "${1:-}" && {
            (( $# >= 1 )) && shift
            continue
        }

        [[ "$_option" != -* ]]                                                  || usage -ec "$err_unknown_argument" "Unknown argument: $_option"

        ! $_positional_arg_set                                                  || usage -ec "$err_too_many_arguments" "Multiple build projects specified: $_option"
        build_project="$_option"
        _positional_arg_set=true
    done

    usage_if_requested
    validate_arguments
    exit_if_has_errors
    dump_args
}

function validate_arguments()
{
    # sanitize inputs
    if [[ -z $build_project ]]; then
        local -a _projects=()

        local -A __build_project_state=()
        save_state __build_project_state
        set_null_glob true

            # search for *.slnx|*.sln|*.csproj file in the current directory
            _projects=(./*.slnx)
            (( ${#_projects[@]} > 0 )) || _projects=(./*.sln)
            (( ${#_projects[@]} > 0 )) || _projects=(./*.csproj)

        restore_state __build_project_state

        (( ${#_projects[@]} > 0 ))                                              || error "No build project (*.slnx, *.sln, *.csproj) was specified or found in the current directory." -ec "$err_not_found"
        build_project=${_projects[0]:-}
        (( ${#_projects[@]} == 1 ))                                             || warning "Multiple projects found: (${_projects[*]}), using the first one: '$build_project'."
        trace "Auto-detected build project: $build_project"
    fi

    is_safe_valid_path "$build_project"
    sanitize_common_dotnet_args "$build_project"

    readonly build_project

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

        build_project

        "${dump_common_dotnet_args[@]}"

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
