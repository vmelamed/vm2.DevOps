# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines functions for working with Git repositories.
#===============================================================================================

# Circular include guard
(( ${__VM2_LIB_GIT_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_GIT_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_invalid_nameref
declare -x err_argument_type
declare -x err_argument_value
declare -x err_logic_error
declare -x err_not_directory
declare -x err_not_git_directory
declare -x err_root_not_repo_name
declare -x err_tool_error

# vm2 core lib constants
declare -x semverTagReleaseRegex

#   Git popular namespaces
declare -xr git_tags_ns='refs/tags/'                                    # The namespace of the tag refs: 'refs/tags/v1.2.3' is the full ref of the tag 'v1.2.3'
declare -xr git_heads_ns='refs/heads/'
declare -xr git_remotes_ns='refs/remotes/'                              # usage: "$git_remotes_ns$remote/$branch"

# vm2 core lib variables
declare -x noise_sink

#-----------------------------------------------------------------------------------------------
# @description Tests if the specified branch name is valid according to Git's rules.
#
# @arg $1 string _branch the branch name to validate.
#
# @exitcode positive=0: if the branch name is valid.
# @exitcode negative=1: if the branch name is invalid.
#
# @example
#   if is_valid_branch_name "main"; then echo "Valid branch name"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_branch_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): a branch name." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _branch=${1#"$git_heads_ns"}

    [[ -n $_branch ]]                                                           || return "$negative"
    git check-ref-format --branch "$_branch" &> "$noise_sink"                   || return "$negative"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the specified tag name is valid according to Git's rules. It also
#   rejects a leading -, because git tag refuses it even though git check-ref-format accepts it.
#
# @arg $1 string _tag the tag name to validate, may or may not be prefixed by 'refs/tags/'
#
# @exitcode positive=0: if the tag name is valid.
# @exitcode negative=1: if the tag name is invalid.
#
# @example
#   if is_valid_tag_name "v1.2.3"; then echo "Valid tag name"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_tag_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): a tag name." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _tag=${1#"$git_tags_ns"}

    [[ -n $_tag && $_tag != -* ]]                                               || return "$negative"
    git check-ref-format "$git_tags_ns$_tag" &> "$noise_sink"                   || return "$negative"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the input string can be a valid commit SHA, or an abbreviation of one:
#   4 to 64 hexadecimal digits. Checks the format only: only git can tell if the commit exists
#   and if an abbreviation is unique (e.g. `git cat-file -e "$sha^{commit}"`). 4 is the shortest
#   abbreviation git accepts; 64 is the length of a SHA-256 hash, in repositories that use it.
#
# @arg $1 string The string to test.
#
# @exitcode positive=0: the string has the format of a commit SHA.
# @exitcode negative=1: otherwise, including an empty string.
#
# @example
#   is_valid_commit_sha "94f1abe56" && echo "Valid commit SHA!"
#-----------------------------------------------------------------------------------------------
function is_valid_commit_sha()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): a SHA string." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    [[ $1 =~ ^[0-9a-fA-F]{4,64}$ ]]                                             || return "$negative"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that the specified repository branch name is valid according to Git
#   branch naming rules, i.e. it is a valid Git ref name.
#
# Notes:
#   - See [git-check-ref-format](https://git-scm.com/docs/git-check-ref-format) for details on
#     valid Git ref names.
#
# @arg $1 string The repository branch name to validate.
#
# @exitcode success=0: If the branch name is valid.
# @exitcode err_argument_value=4: If the branch name is not a valid Git ref name.
#
# @example
#   if validate_branch_name "main"; then echo "Valid branch name"; fi
# @example
#   enter_value "Default branch name" branch_name "$default_default_branch" false validate_branch_name)
#-----------------------------------------------------------------------------------------------
function validate_branch_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): a branch name." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    is_valid_branch_name "$1" || {
        _rc="$err_argument_value"
        error "${FUNCNAME[0]}() requires argument 1 to be a valid Git branch name (provided '${1-<missing>}'). See https://git-scm.com/docs/git-check-ref-format for details." -ec "$_rc"
    }

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the current or the specified directory is inside a Git working tree.
#
# @arg $1 string Path to the directory to test (optional, default: `$initial_cwd`).
#
# @exitcode positive=0: If the directory is inside a Git working tree.
# @exitcode negative=1: If it is not.
#
# @example
#   if is_inside_work_tree "$PWD"; then echo "Inside Git repo"; fi
#-----------------------------------------------------------------------------------------------
function is_inside_work_tree()
{
    (( $# == 0 || $# == 1 ))                                                    || bug "${FUNCNAME[0]}() requires 0 or 1 arguments (provided $#): path to a directory." -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "${FUNCNAME[0]}() requires optional argument 1 to be an existing directory (provided '${1-<missing>}')." -ec "$err_not_directory"
                                                                                exit_if_has_bugs

    local _path="${1:-$initial_cwd}"

    # normalize to $positive/$negative -- `git rev-parse` exits 128 (its generic "fatal" code),
    # not 1, when the directory is not inside a work tree.
    git -C "$_path" rev-parse --is-inside-work-tree &> "$noise_sink" && return "$positive" \
                                                                                || return "$negative"
}

#-----------------------------------------------------------------------------------------------
# @description Retrieves the root of the Git repository working tree for the specified
#   directory, or the current directory.
#
# @arg $1 string Path to a directory inside a Git repository working tree.
# @arg $2 nameref `_repo_root` to a variable to store the absolute path of the root of
#   the Git repository containing the found directory.
#
# @exitcode success=0: The Git working tree root was resolved.
# @exitcode err_not_git_directory=80: Argument 1 (or the current directory) is not inside of a
#   Git working tree.
#
# @example
#   root_working_tree "$PWD" _root
#-----------------------------------------------------------------------------------------------
function root_working_tree()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                       "  - a directory inside a Git working tree" \
                                                                                       "  - the name of the variable to store the absolute path of the root of the Git working tree containing the found directory" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 1 to be an existing directory (provided '${1-<missing>}')." -ec "$err_not_directory"
    [[ ! -v 2 ]] || is_variable "$2"                                            || bug "${FUNCNAME[0]}() requires argument 2 to be the name of a variable to receive the absolute path of the root of the Git working tree (provided '${2-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs # gate here: $2 must be validated before creating a nameref from it below

    local _path=$1
    local -n __repo_root_ref=$2
    local -i _rc=$success

    is_inside_work_tree "$_path"                                                || with_error _rc "$err_not_git_directory" "The directory '$_path' is not in a Git working tree."

    (( _rc != success )) || __repo_root_ref=$(git -C "$_path" rev-parse --show-toplevel 2> "$noise_sink")
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Tests whether local Git metadata is stale enough to justify fetching before
#   evaluating latest-stable-tag predicates.
#
# Notes:
#   - Conservative by design: uncertain states return `$positive` (fetch recommended).
#   - Compares the local vs. remote branch tip SHA, and the latest local vs. remote stable
#     release tag name.
#
# @arg $1 string _dir Path to a Git repository (optional, if the remaining parameters are not
#   provided; default: `$initial_cwd`).
# @arg $2 string _branch The branch to compare against (optional, default: `main`).
#
# @exitcode positive=0: If a fetch is recommended.
# @exitcode negative=1: If local metadata appears fresh.
#
# @example
#   if should_fetch_for_latest_stable_tag "$repo_dir"; then git fetch ...; fi
# @example
#   should_fetch_for_latest_stable_tag "$repo_dir" && git -C "$repo_dir" fetch
#   origin --tags --quiet
#-----------------------------------------------------------------------------------------------
function should_fetch_for_latest_stable_tag()
{
    local -i _rc="$success"

    (( $# <= 2 ))                                                               || bug "${FUNCNAME[0]}() requires at most 2 arguments (provided $#):" \
                                                                                       "  - path to an existing directory (Git repository) (optional if the remaining parameters are not provided, default: current working directory)" \
                                                                                       "  - the branch name to compare against (optional, default: main)" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "${FUNCNAME[0]}() requires optional argument 1 to be an existing Git repository directory (provided '${1-<missing>}')." -ec "$err_not_directory"
    [[ ! -v 2 ]] || is_valid_branch_name "$2"                                   || bug "${FUNCNAME[0]}() requires optional argument 2 to be a valid Git branch name (provided '${2-<missing>}')." -ec "$err_argument_value"
                                                                                exit_if_has_bugs

    local _dir=${1:-$initial_cwd}
    local _branch=${2:-main}

    is_inside_work_tree "$_dir"                                                 || bug "${FUNCNAME[0]}() requires optional argument 1, or the current directory, to be in a Git working tree (provided '${1-<missing>}')." -ec "$err_not_git_directory"
                                                                                exit_if_has_bugs

    # Shallow repositories can miss history or tags needed by release predicates - yes we need a fetch
    [[ $(git -C "$_dir" rev-parse --is-shallow-repository 2>"$noise_sink") != true ]] \
                                                                                || return "$positive"
    local _local_sha _remote_sha

    # no locally-cached SHA - no fetch needed
    _local_sha=$(git -C "$_dir" rev-parse --verify "${git_remotes_ns}origin/$_branch" 2>"$noise_sink") \
                                                                                || return "$negative"
    # no remote SHA for the branch - no fetch needed
    _remote_sha=$(git -C "$_dir" ls-remote --heads origin "$_branch" 2>"$noise_sink" | awk 'NR==1 {print $1}')
    [[ -n "$_remote_sha" ]]                                                     || return "$negative"
    # SHAs are equal - no fetch needed
    [[ "$_local_sha" != "$_remote_sha" ]]                                       || return "$negative"

    local _local_stable_tag _remote_stable_tag

    # Get latest stable tag
    _local_stable_tag=$(
        git -C "$_dir" tag |
        grep -E "$semverTagReleaseRegex" |
        sort -V |
        tail -n1
    )
    # no local stable tags - fetch needed
    [[ -n "$_local_stable_tag" ]]                                               || return "$positive"
    # Get latest stable tag from remote
    _remote_stable_tag=$(
        git -C "$_dir" ls-remote --tags --refs origin 2>"$noise_sink" |
        awk '{print $2}' |
        sed "s#${git_tags_ns}##" |
        grep -E "$semverTagReleaseRegex" |
        sort -V |
        tail -n1
    )
    # no local stable tags - fetch needed
    [[ -n "$_remote_stable_tag" ]]                                              || return "$positive"
    # stable tags are not the same - fetch needed
    [[ "$_local_stable_tag" == "$_remote_stable_tag" ]]                         && return "$negative"

    # fetch needed
    return "$positive"
}

#-----------------------------------------------------------------------------------------------
# @description Ensures that the Git repository in the specified directory has fresh metadata,
#   by fetching from the remote if `should_fetch_for_latest_stable_tag` recommends it.
#
# @arg $1 string Path to a Git repository (optional, if the remaining parameters are not
#   provided; default: `$initial_cwd`).
# @arg $2 string The branch to compare against (optional, default: `main`).
#
# @exitcode success=0: If no fetch was needed, or the fetch succeeded.
# @exitcode N If `git fetch` failed (`err_logic_error`), or if
#   `should_fetch_for_latest_stable_tag` itself returned an error (e.g. invalid arguments, not
#   a Git directory).
#
# @example
#   ensure_fresh_git_state "$repo_dir"
#-----------------------------------------------------------------------------------------------
function ensure_fresh_git_state()
{
    local -i _rc=$positive

    should_fetch_for_latest_stable_tag "$@" || _rc=$?

    if (( _rc == "$positive" )); then
        trace "Git metadata of repository '$1' branch '${2:-main}' appears stale or repository is shallow. Fetching from origin..."
        git -C "$1" fetch origin "${2:-main}" --quiet 2> "$noise_sink"          || with_error _rc "$err_logic_error" "Failed to fetch from origin."
    else
        _rc=$success
        trace "Git metadata of repository '$1' branch '${2:-main}' appears fresh. No fetch needed."
    fi

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Gets the commit hash of the latest stable tag in the specified Git repository.
#
# @arg $1 string _dir path to a Git repository.
# @arg $2 bool _should_fetch flag whether to ensure fresh Git status.
#
# @exitcode success=0: On success.
# @exitcode err_not_git_directory=80: Argument 1 is not inside a Git working tree.
# @exitcode N propagated from `ensure_fresh_git_state()` if `$2` is true and fetching fails.
# @exitcode failure=1: If no stable tags are found.
#
# @stdout The commit hash of the latest stable tag.
#
# @example
#   latest_hash=$(get_latest_stable_tag_hash "$repo_dir")
#-----------------------------------------------------------------------------------------------
function get_latest_stable_tag_hash()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                       "  - a directory" \
                                                                                       "  - flag whether to fetch the latest changes in main from remote" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 1 to be an existing Git repository directory (provided '${1-<missing>}')." -ec "$err_not_directory"
    [[ ! -v 2 ]] || is_boolean "$2"                                             || bug "${FUNCNAME[0]}() requires argument 2, the fetch flag, to be 'true' or 'false' (provided '${2-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs

    local _dir=$1
    local _should_fetch=$2

    local -i _rc=$success

    is_inside_work_tree "$_dir"                                                 || with_error _rc "$err_not_git_directory" "The directory '$_dir' is not in a Git working tree."
    (( _rc != success )) || ! $_should_fetch || ensure_fresh_git_state "$_dir"  || with_error _rc $? "Failed to ensure fresh Git state for '$_dir': $_rc"
    (( _rc == success )) ||                                                     return "$_rc"

    local _latest_stable_tag _latest_stable_hash

    # Get latest stable tag (excludes pre-release tags with -)
    _latest_stable_tag=$(
        git -C "$_dir" tag |
        grep -E "$semverTagReleaseRegex" |
        sort -V |
        tail -n1
    )                                                                           || true
    [[ -n $_latest_stable_tag ]]                                                || return "$failure" # no stable tags? - return 1

    # get the hash of the commit of the latest stable tag
    git -C "$_dir" rev-parse "$_latest_stable_tag^{commit}" 2>"$noise_sink"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the current commit in the specified directory is after the latest
#   stable tag. Depends on `get_latest_stable_tag_hash`.
#
# @arg $1 string _dir path to a Git repository.
# @arg $2 bool _should_fetch flag whether to ensure fresh Git status.
#
# @exitcode positive=0: If the current commit is after the latest stable tag.
# @exitcode negative=1: If it is not.
# @exitcode N Whatever `get_latest_stable_tag_hash` returns on error (e.g. no stable tags,
#   not a Git directory) -- its own argument-count/type bugs are also caught by this
#   function's identical, direct validation gate above.
#
# @example
#   if is_after_latest_stable_tag "$repo_dir"; then echo "Beyond latest stable"; fi
#-----------------------------------------------------------------------------------------------
function is_after_latest_stable_tag()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                       "  - a directory" \
                                                                                       "  - flag whether to fetch the latest changes in main from remote" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 1 to be an existing Git repository directory (provided '${1-<missing>}')." -ec "$err_not_directory"
    [[ ! -v 2 ]] || is_boolean "$2"                                             || bug "${FUNCNAME[0]}() requires argument 2, the fetch flag, to be 'true' or 'false' (provided '${2-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs

    local _latest_stable_hash _commits_after_latest_stable

    # get commit of the latest stable tag
    _latest_stable_hash=$(get_latest_stable_tag_hash "$@")                      || return $?

    # How many commits since the latest stable tag
    _commits_after_latest_stable=$(git -C "${1:-$initial_cwd}" rev-list "$_latest_stable_hash..HEAD" --count 2>"$noise_sink")
    (( _commits_after_latest_stable > 0 ))
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the current commit in the specified directory is on or after the
#   latest stable tag. Depends on `get_latest_stable_tag_hash`.
#
# @arg $1 string _dir path to a Git repository.
# @arg $2 bool _should_fetch flag whether to ensure fresh Git status.
#
# @exitcode positive=0: If the current commit is on or after the latest stable tag.
# @exitcode negative=1: If it is before.
# @exitcode N Whatever `get_latest_stable_tag_hash` returns on error (e.g. no stable tags, not
#   a Git directory).
#
# @example
#   if is_on_or_after_latest_stable_tag "$repo_dir"; then echo "Ready for release"; fi
#-----------------------------------------------------------------------------------------------
function is_on_or_after_latest_stable_tag()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                       "  - a directory" \
                                                                                       "  - flag whether to fetch the latest changes in main from remote" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 1 to be an existing Git repository directory (provided '${1-<missing>}')." -ec "$err_not_directory"
    [[ ! -v 2 ]] || is_boolean "$2"                                             || bug "${FUNCNAME[0]}() requires argument 2, the fetch flag, to be 'true' or 'false' (provided '${2-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs

    local _latest_stable_tag_hash

    # get commit of the latest stable tag
    _latest_stable_tag_hash=$(get_latest_stable_tag_hash "$@")                  || return $?

    # Check if current commit is on or after the latest tag
    # Returns 0 if tag commit is an ancestor of HEAD (i.e., HEAD is at or after the tag)
    git -C "${1:-$initial_cwd}" merge-base --is-ancestor "$_latest_stable_tag_hash" HEAD &> "$noise_sink"
}
