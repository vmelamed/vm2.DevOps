# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr script_dir

# core lib exit codes
declare -xri success
declare -xri err_missing_argument
declare -xri err_argument_value
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_too_many_arguments
declare -xri err_tool_not_found
declare -xri err_tool_unauthenticated

# core lib constants
declare -xr ci
declare -xr key_owner

# core lib defaults

# core lib variables
declare -x _ignore

# this script's constants
declare -xri default_repeat=10
declare -xr default_workflow="RebuildBenchHistory.yaml"

# this scripts arguments
declare -x owner=""
declare -x repeat=${REPEAT:-$default_repeat}
declare -x workflow=$default_workflow

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --owner|-o )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                owner="$1"; shift
                ;;

            --repeat|-n )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                repeat="$1"; shift
                ;;

            --workflow|-w )
                (( $# >= 1 ))                                                   || usage "Missing value for ${_option,,}" -ec "$err_missing_argument"
                workflow="$1"; shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            *)  usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;
        esac
    done

    usage_if_requested
    validate_environment
    validate_arguments
    exit_if_has_errors
    dump_args
}

function validate_environment()
{
    # Authentication:
    #   - in a workflow the caller exports the BENCH_DISPATCH_PAT secret as GH_TOKEN;
    #   - locally, export BENCH_DISPATCH_PAT yourself (it is an env var, NOT a repo secret) or rely on the ambient 'gh auth' credentials.
    [[ -z "${BENCH_DISPATCH_PAT:-}" ]] || export GH_TOKEN="${GH_TOKEN:-$BENCH_DISPATCH_PAT}"
    [[ -n "${GH_TOKEN:-}" ]]                                                    || warning "Neither \$GH_TOKEN nor \$BENCH_DISPATCH_PAT is set; relying on the ambient 'gh auth' credentials."

    is_tool_present gh                                                          || { error "The GitHub CLI 'gh' was not found on PATH." -ec "$err_tool_not_found"; return "$success"; }
    gh auth status &> "$_ignore"                                                || error "'gh' is not authenticated. Run 'gh auth login' first." -ec "$err_tool_unauthenticated"
}

function validate_arguments()
{
    # Resolve the GitHub owner: --owner, else $GITHUB_REPOSITORY_OWNER (set by Actions), else derive from this repo's remote.
    [[ -n "$owner" ]] || owner="${GITHUB_REPOSITORY_OWNER:-}"
    if [[ -z "$owner" ]]; then
        local _self_root

        root_working_tree "$script_dir" _self_root || true
        if [[ -n "${_self_root:-}" ]]; then
            local -A _self_state=()
            get_repo_state "$_self_root" _self_state false || true
            owner="${_self_state[$key_owner]:-}"
        fi
    fi

    is_positive "$repeat"                                                       || error "repeat must be a positive integer (got '$repeat')." -ec "$err_argument_value"
    [[ -n "$owner" ]]                                                           || error "Could not determine the GitHub owner. Pass --owner or set \$GITHUB_REPOSITORY_OWNER." -ec "$err_argument_value"

    readonly owner
    readonly repeat
    readonly workflow

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

        owner
        repeat
        workflow

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
