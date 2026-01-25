#!/usr/bin/env bash

declare -xr script_name
declare -xr script_dir
declare -xr common_dir

declare -x commit_sha
declare -x new_branch
declare -x check_out_new_branch

# shellcheck disable=SC2154 # verbose is referenced but not assigned.
function get_arguments()
{
    if [[ $# -lt 2 ]]; then
        usage false "This script requires two options: '--commit-sha <commit-sha>' and '--branch <new-branch-name>'."
    fi

    local option

    while [[ $# -gt 0 ]]; do
        option="$1"; shift
        if get_common_arg "$option"; then
            continue
        fi

        case "${option,,}" in
            # do not use the common options:
            -h|-v|-q|-x|-y|--help|--debugger|--quiet|--verbose|--trace|--dry-run )
                ;;

            --branch|-b )
                if [[ $# -lt 1 ]]; then
                    error "Missing branch name after '$option'."
                    exit 2
                fi
                new_branch="$1"; shift
                ;;

            --commit-sha|-c )
                if [[ $# -lt 1 ]]; then
                    error "Missing commit SHA after '$option'."
                    exit 2
                fi
                commit_sha="$1"; shift
                ;;

            --check-out-new|-n )
                check_out_new_branch=true
                ;;

            * )
                usage false "Unknown argument '$option'."
                ;;
        esac
    done
}
