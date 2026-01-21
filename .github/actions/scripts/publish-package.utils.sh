#!/usr/bin/env bash

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function get_arguments()
{
    if [[ "${#}" -eq 0 ]]; then return; fi

    # process --debugger first
    for v in "$@"; do
        if [[ "$v" == "--debugger" ]]; then
            get_common_arg "--debugger"
            break
        fi
    done
    # shellcheck disable=SC2154 # v appears unused. Verify use (or export if used externally).
    if [[ $debugger != "true" ]]; then
        trap on_debug DEBUG
        trap on_exit EXIT
    fi

    local flag
    local value

    while [[ "${#}" -gt 0 ]]; do
        # get the flag and convert it to lower case
        flag="$1"
        shift
        if get_common_arg "$flag"; then
            continue
        fi

        case "${flag,,}" in
            # do not use the common options:
            --help|-h|--debugger|-q|--quiet-v|--verbose-x|--trace-y|--dry-run )
                ;;

            --package-project|-p )
                value="$1"; shift
                package_project="$value"
                ;;

            --nuget-server|-n )
                value="$1"; shift
                nuget_server="$value"
                ;;

            --preprocessor-symbols|-s )
                value="$1"; shift
                preprocessor_symbols="$value"
                ;;

            --minver-tag-prefix|-t )
                value="$1"; shift
                minver_tag_prefix="$value"
                ;;

            --minver-prerelease-id|-i )
                value="$1"; shift
                minver_prerelease_id="$value"
                ;;

            --repo-owner|-o )
                value="$1"; shift
                repo_owner="$value"
                ;;

            --version|-v )
                value="$1"; shift
                version="$value"
                ;;

            --git-tag|-g )
                value="$1"; shift
                git_tag="$value"
                ;;

            --reason|-r )
                value="$1"; shift
                reason="$value"
                ;;

            --artifacts-saved|-a )
                value="$1"; shift
                artifacts_saved="$value"
                ;;

            --artifacts-dir|-d )
                value="$1"; shift
                artifacts_dir="$value"
                ;;

            * ) usage "Unknown option: $flag"
                exit 2
                ;;
        esac
    done
}

dump_all_variables()
{
    dump_vars --force --quiet --markdown \
        --header "Script Arguments:" \
        debugger \
        dry_run \
        verbose \
        quiet \
        --blank \
        package_project \
        nuget_server \
        preprocessor_symbols \
        minver_tag_prefix \
        minver_prerelease_id \
        repo_owner \
        version \
        git_tag \
        reason \
        artifacts_saved \
        artifacts_dir \
        --header "other:" \
        ci

}
