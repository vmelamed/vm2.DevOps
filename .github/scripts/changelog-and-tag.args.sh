# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# core constants
declare -xri success
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_argument_value

declare -xr ci

# script arguments
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x tag=${TAG:-}
declare -x reason=${REASON:-}
declare -x needs_empty_commit=${NEEDS_EMPTY_COMMIT:-false}
declare -x is_release=false
declare -x is_prerelease=false

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --tag|-t )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                tag="$1"; shift
                ;;

            --minver-tag-prefix|-p )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --reason|-r )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                reason="$1"; shift
                ;;

            --needs-empty-commit )
                (( $# >= 1 )) || usage -ec "$err_missing_argument" "Missing value for ${_option,,}"
                needs_empty_commit="$1"; shift
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
    validate_arguments
    dump_args
}

function validate_arguments()
{
    # Sanitize inputs
    validate_semverTagComponents "$minver_tag_prefix" || true

    # Determine tag type: release or prerelease
    if is_semverReleaseTag "$tag"; then
        is_release=true
        reason=${reason:-"stable release"}
    elif is_semverPrereleaseTag "$tag"; then
        is_prerelease=true
        reason=${reason:-"pre-release"}
    else
        error -ec "$err_argument_value" "Tag '$tag' is not a valid semver release or prerelease tag."
    fi

    is_safe_reason "$reason" || true

    exit_if_has_errors

    [[ -n "${GITHUB_REPOSITORY:-}" && -n "${RELEASE_PAT:-}" ]] ||
        exit_with_error -ec "$err_argument_value" "GITHUB_REPOSITORY and/or RELEASE_PAT are not set."

    readonly tag
    readonly reason
    readonly minver_tag_prefix
    readonly needs_empty_commit
    readonly is_release
    readonly is_prerelease

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

        tag
        minver_tag_prefix
        reason
        needs_empty_commit
        is_release
        is_prerelease

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
