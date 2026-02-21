# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -x git_repos
declare -x repo_name
declare -x repo_path
declare -x owner
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

            --path )
                [[ $# -ge 1 ]] || { usage false "Missing path after '$option'."; exit 2; }
                repo_path="$1"; shift
                ;;

            --owner )
                [[ $# -ge 1 ]] || { usage false "Missing owner after '$option'."; exit 2; }
                owner="$1"; shift
                ;;

            --visibility )
                [[ $# -ge 1 ]] || { usage false "Missing visibility after '$option'."; exit 2; }
                visibility="$1"; shift
                ;;

            --branch|-b )
                [[ $# -ge 1 ]] || { usage false "Missing branch name after '$option'."; exit 2; }
                branch="$1"; shift
                ;;

            --git-repos|-r )
                [[ $# -ge 1 ]] || { usage false "Missing path after '$option'."; exit 2; }
                git_repos="$1"; shift
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
