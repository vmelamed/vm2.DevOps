# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

declare -rxi err_missing_argument
declare -rxi err_too_many_arguments
declare -rxi err_unknown_argument

declare -x vm2_repos
declare -x repo_name
declare -x repo_path
declare -x repo_owner
declare -x repo
declare -x visibility
declare -x branch
declare -x interactive_vars
declare -x interactive_secrets
declare -x configure_local
declare -x audit
declare -x main_protection_rs_name
declare -x description
declare -x use_ssh
declare -x use_https

#-------------------------------------------------------------------------------
# @description Parses the command-line arguments of `setup-repo.sh`, populating the script-level variables declared
# at the top of this file (`vm2_repos`, `repo_path`, `owner`, `visibility`, `branch`, `interactive_vars`,
# `interactive_secrets`, `configure_local`, `audit`, `main_protection_rs_name`, `description`, `use_ssh`,
# `use_https`). Common switches (`-h`, `-v`, `-q`, `-x`, `-y`, etc.) are delegated to `get_common_arg` first. The
# first (and only) positional argument is taken as `repo_path`; a second positional argument triggers a usage error.
# On completion, calls `usage_if_requested` (exits the process if `--help` was seen) and `dump_args` (prints the
# parsed values in verbose mode).
#
# Notes:
#   - This is a top-level CLI argument parser (see the "Parameter and Precondition Validation Pattern" in
#     CLAUDE.md): it exits the process via `usage()` on bad input rather than returning an error code.
#
# @arg $@ string Command-line arguments passed to `setup-repo.sh`.
#
# @exitcode 0 All arguments parsed successfully (function returns normally; `usage()` exits the process directly on
#   error or on `--help`).
#-------------------------------------------------------------------------------
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
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing path after '$option'."
                vm2_repos="$1"; shift
                ;;

            --owner|-o )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing owner after '$option'."
                repo_owner="$1"; shift
                ;;

            --branch|-b )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing branch name after '$option'."
                branch="$1"; shift
                ;;

            --visibility )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing visibility after '$option'."
                visibility="$1"; shift
                ;;

            --ruleset-name|-rs )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing the name of the ruleset for protecting the default branch after '$option'."
                main_protection_rs_name="$1"; shift
                ;;

            --description )
                [[ $# -ge 1 ]] || usage -ec "$err_missing_argument" "Missing description after '$option'."
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

            --interactive-vars|-iv )
                interactive_vars=true
                ;;

            --interactive-secrets|-is )
                interactive_secrets=true
                ;;

            --skip-local-config|-slc )
                configure_local=false
                ;;

            --audit|-a )
                audit=true
                ;;

            * ) if [[ -z "$repo_path" ]]; then
                    repo_path="$option"
                else
                    usage -ec "$err_too_many_arguments" "Too many positional arguments (project directory or repository name): $option"
                fi
                ;;
        esac
    done
    usage_if_requested
    dump_args
}

#-------------------------------------------------------------------------------
# @description Dumps the parsed input variables to stdout in tabular form via `dump_vars`, but only when verbose
# mode is active. No-op otherwise.
#
# @exitcode 0 Values dumped (verbose mode), or verbose mode is off and the function returned early.
# @stdout A tabular listing of the parsed input variables (`vm2_repos`, `repo_path`, `repo_owner`, `repo_name`,
#   `visibility`, `branch`, `main_protection_rs_name`, `description`, `use_ssh`, `use_https`, `interactive_vars`,
#   `interactive_secrets`, `audit`, `dry_run`, `verbose`, `quiet`) -- only when verbose mode is active.
#-------------------------------------------------------------------------------
function dump_args()
{
    is_verbose || return 0
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
        interactive_vars \
        interactive_secrets \
        audit \
        --blank \
        dry_run \
        verbose \
        quiet
}
