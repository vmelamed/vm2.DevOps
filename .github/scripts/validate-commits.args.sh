# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr lib_dir

# core lib exit codes
declare -xri success
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_logic_error
declare -xri err_not_directory
declare -xri err_not_git_directory

# core lib constants
declare -xr ci
declare -xra vm2_repositories

# core lib variables
declare -x _ignore

# this scripts arguments
declare -x repo_path
repo_path=$(pwd)
declare -x base_ref=${BASE_REF:-}

function get_arguments()
{
    local _option

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            -r|--repo-dir )
                (( $# >= 1 ))                                                   || usage -ec "$err_missing_argument" "Missing value for '$_option'"
                repo_path="$1"
                shift
                ;;

            -b|--base-ref )
                (( $# >= 1 ))                                                   || usage -ec "$err_missing_argument" "Missing value for '$_option'"
                base_ref="$1"
                shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug -ec "$err_logic_error" "'$_option' should have been consumed by get_common_arg."
                ;;

            * ) usage -ec "$err_unknown_argument" "Unknown option: $_option"
                ;;
        esac
    done

    usage_if_requested
    validate_arguments
    exit_if_has_errors
    dump_args
}

function validate_arguments()
{
    local -i _rc=$success

    [[ -d $repo_path ]]                                                         || { _rc="$err_not_directory";     error -ec "$_rc" "Invalid directory: '$repo_path'"; }
    (( _rc != success )) || is_inside_work_tree "$repo_path"                    || { _rc="$err_not_git_directory"; error -ec "$_rc" "The directory '$repo_path' is not inside Git repository working tree"; }
    (( _rc == success )) || return "$success"

    # Determine the commit range. CI always passes an explicit base ref (the PR's base branch)
    if [[ -z "$base_ref" ]]; then
        # for ad-hoc/manual runs with none given, default to "since this branch diverged from the repo's
        # default branch" -- the merge-base with origin/HEAD's target (e.g. origin/main) -- rather than
        # requiring the caller to already know a safe ref, or falling back to the root commit and
        # re-litigating the entire pre-convention history.
        local _default_ref=''

        # origin/HEAD, not @{upstream}, is the right signal
        _default_ref=$(git -C "$repo_path" symbolic-ref --short refs/remotes/origin/HEAD 2>"$_ignore") ||
            # here: @{upstream} means "the branch this one
            # pushes/pulls with," which for a normally-pushed feature branch (`git push -u origin <branch>`)
            # is a same-named remote branch, not the trunk it forked from -- its merge-base with HEAD is
            # HEAD itself, which would silently validate almost nothing. @{upstream} is only used as a
            # last-resort fallback, for a repo with no discoverable default branch at all.
            _default_ref=$(git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>"$_ignore") || true

        [[ -n $_default_ref ]]                                                  || { _rc=$err_argument_value; error -ec "$_rc" "No base ref provided, there is no origin/HEAD default branch, and this branch has no" \
                                                                                                                               "upstream tracking branch either. Pass a base ref explicitly, or set \$BASE_REF."; }
        (( _rc == success )) || return "$success"

        base_ref=$(git -C "$repo_path" merge-base HEAD "$_default_ref")         || error -ec "$err_argument_value" "Failed to compute the merge-base with '$_default_ref'."

        trace "No base ref given -- defaulting to the merge-base with '$_default_ref' (${base_ref:0:8})," \
              "i.e. commits since this branch diverged. Pass a base ref explicitly to check a different range."
    fi

    readonly repo_path
    readonly base_ref

    #  TODO: add validation here
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

        repo_path
        base_ref

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
