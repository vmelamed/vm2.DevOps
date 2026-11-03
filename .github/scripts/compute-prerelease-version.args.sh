# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# core lib exit codes
declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_tool_error

# core lib constants
declare -xr ci

# core lib defaults
declare -xr default_minver_tag_prefix
declare -xr default_minver_prerelease_id

# core lib variables

# this script's arguments
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}  # the value comes from the CLI, or fromGitHub Actions vars MINVERDEFAULTPRERELEASEIDENTIFIERS, or $default_minver_prerelease_id. It must not be empty for pre-release.
declare -x reason=${REASON:-"pre-release build"}

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --minver-tag-prefix|-mp )
                (( $# >= 1 ))                                                   || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-mi )
                (( $# >= 1 ))                                                   || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                minver_prerelease_id="$1"; shift
                ;;

            --reason|-r )
                (( $# >= 1 ))                                                   || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                reason="$1"; shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            * ) usage -ec "$err_unknown_argument" "Unknown argument: $_option"
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
    git fetch --tags --force

    # detect if the head is already tagged
    head_tag=$(git tag --points-at HEAD)
    [[ -z $head_tag ]]                                                          || error -ec "$err_tool_error" "The HEAD is already tagged with '$head_tag'. A prerelease requires at least one new commit on main."

    return "$success"
}

function validate_arguments()
{
    validate_semverTagComponents "$minver_tag_prefix" "$minver_prerelease_id"   || true
    is_safe_reason "$reason" || true

    readonly minver_tag_prefix
    readonly minver_prerelease_id
    readonly reason

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

        minver_tag_prefix
        minver_prerelease_id
        reason

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
