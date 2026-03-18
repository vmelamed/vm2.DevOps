# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -x vm2_repos
declare -x repo_name
declare -x repo_path
declare -x owner
declare -x repo
declare -x visibility
declare -x branch
declare -x force_defaults
declare -x enter_secrets
declare -x audit
declare -x main_protection_rs_name
declare -x description
declare -x use_ssh
declare -x use_https

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

            --vm2-repos )
                [[ $# -ge 1 ]] || usage false "Missing path after '$option'."
                vm2_repos="$1"; shift
                ;;

            --owner|-o )
                [[ $# -ge 1 ]] || usage false "Missing owner after '$option'."
                owner="$1"; shift
                ;;

            --repo-name|-n )
                [[ $# -ge 1 ]] || usage false "Missing repository name after '$option'."
                repo_name="$1"; shift
                ;;

            --branch|-b )
                [[ $# -ge 1 ]] || usage false "Missing branch name after '$option'."
                branch="$1"; shift
                ;;

            --visibility )
                [[ $# -ge 1 ]] || usage false "Missing visibility after '$option'."
                visibility="$1"; shift
                ;;

            --ruleset-name|-rs )
                [[ $# -ge 1 ]] || usage false "Missing the name of the ruleset for protecting the default branch after '$option'."
                main_protection_rs_name="$1"; shift
                ;;

            --description )
                [[ $# -ge 1 ]] || usage false "Missing description after '$option'."
                description="$1"; shift
                ;;

            --ssh|-s )
                use_ssh=true
                use_https=false
                ;;

            --https|-t )
                use_ssh=false
                use_https=true
                ;;

            --force-defaults|-f )
                force_defaults=true
                ;;

            --enter-secrets|-e )
                enter_secrets=true
                ;;


            --audit )
                audit=true
                ;;

            * ) if [[ -z "$repo_path" ]]; then
                    repo_path="$option"
                else
                    usage false "Too many positional arguments (project directory or repository name): ${option}"
                fi
                ;;
        esac
    done
    #dump_args
}

function dump_args()
{
    dump_vars --quiet \
        --header "Inputs" \
        vm2_repos \
        repo_path \
        repo_owner \
        repo_name \
        visibility \
        branch \
        main_protection_rs_name \
        description \
        use_ssh \
        use_https \
        force_defaults \
        enter_secrets \
        audit \
        --blank \
        dry_run \
        verbose \
        quiet
}
