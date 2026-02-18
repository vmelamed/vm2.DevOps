#!/usr/bin/env bash

declare -xr script_name
declare -xr lib_dir

declare -x package_name
declare -x org
declare -x repo
declare -x visibility
declare -x branch
declare -x configure_only
declare -x skip_secrets
declare -x skip_variables
declare -x audit

# shellcheck disable=SC2154 # verbose is referenced but not assigned.
function get_arguments()
{
    local option

    while [[ $# -gt 0 ]]; do
        option="$1"; shift
        if get_common_arg "$option"; then
            continue
        fi

        case "${option,,}" in
            -h|-\?|-v|-q|-x|-y|--help|--quiet|--verbose|--trace|--dry-run )
                ;;

            --name|-n )
                if [[ $# -lt 1 ]]; then
                    error "Missing package name after '$option'."
                    exit 2
                fi
                package_name="$1"; shift
                ;;

            --repo|-r )
                if [[ $# -lt 1 ]]; then
                    error "Missing repo name after '$option'."
                    exit 2
                fi
                repo="$1"; shift
                ;;

            --org|-o )
                if [[ $# -lt 1 ]]; then
                    error "Missing org name after '$option'."
                    exit 2
                fi
                org="$1"; shift
                ;;

            --visibility )
                if [[ $# -lt 1 ]]; then
                    error "Missing visibility after '$option'."
                    exit 2
                fi
                visibility="$1"; shift
                if [[ "$visibility" != "public" && "$visibility" != "private" ]]; then
                    usage false "Visibility must be 'public' or 'private', got '${visibility}'."
                fi
                ;;

            --branch|-b )
                if [[ $# -lt 1 ]]; then
                    error "Missing branch name after '$option'."
                    exit 2
                fi
                branch="$1"; shift
                ;;

            --configure-only )
                configure_only=true
                ;;

            --skip-secrets )
                skip_secrets=true
                ;;

            --skip-variables )
                skip_variables=true
                ;;

            --audit )
                audit=true
                ;;

            * )
                usage false "Unknown argument '$option'."
                ;;
        esac
    done
}
