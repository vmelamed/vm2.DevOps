# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

# constants from lib:
declare -xri success
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_tool_error
declare -xri err_not_found

declare -xr fail_em
declare -xr question_em
declare -xr right_arrow_em
declare -xr check_em
declare -xr up_arrow_em

declare -x _ignore

# timing variables for performance measurement. us stands for microseconds.
declare -xi search_us
declare -xi restore_us
declare -xi search_count

#---------------------------------------------------------------------------------------------
# @description Decides how a repository may be changed. 'publish': on 'main', clean, and identical to 'origin/main' after
#   a fetch, so a branch can be created, committed, and pushed. 'inplace': the files are edited in the current branch and
#   nothing is committed. 'skip': uncommitted changes exist, so the repository is left untouched.
#
# @arg $1 string Path to the repository's working tree.
# @arg $2 nameref Receives 'publish', 'inplace', or 'skip'.
# @arg $3 nameref Receives a human-readable explanation for the summary.
#
# @exitcode success=0: always.
#---------------------------------------------------------------------------------------------
function classify_repo()
{
    (( $# == 3 ))                         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three arguments (provided $#): " \
                                                                              "  - the repository path" \
                                                                              "  - the mode" \
                                                                              "  - the reason"
    [[ ! -v 1 || -d "$1" ]]               || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a valid repository path as the first argument."
    [[ ! -v 2 ]] || is_variable_name "$2" || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a valid variable name as the second argument."
    [[ ! -v 3 ]] || is_variable_name "$3" || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a valid variable name as the third argument."
    exit_if_has_bugs

    local _repo=$1
    local -n _mode_ref=$2
    local -n _reason_ref=$3
    local _branch

    if [[ -n $(git -C "$_repo" status --porcelain) ]]; then
        _mode_ref=skip
        _reason_ref="uncommitted changes; left untouched"
        return "$success"
    fi

    _branch=$(git -C "$_repo" branch --show-current)
    if [[ $_branch != main ]]; then
        _mode_ref=inplace
        _reason_ref="on branch '$_branch', not 'main'; edited in place, nothing committed"
        return "$success"
    fi

    if ! git -C "$_repo" remote get-url origin > /dev/null 2>&1; then
        _mode_ref=inplace
        _reason_ref="no 'origin' remote; edited in place, nothing committed"
        return "$success"
    fi

    if ! git -C "$_repo" fetch --quiet origin main > /dev/null 2>&1; then
        _mode_ref=inplace
        _reason_ref="could not fetch 'origin/main'; edited in place, nothing committed"
        return "$success"
    fi

    if [[ $(git -C "$_repo" rev-list --count origin/main...main) != 0 ]]; then
        _mode_ref=inplace
        _reason_ref="not identical to 'origin/main'; edited in place, nothing committed"
        return "$success"
    fi

    _mode_ref=publish
    _reason_ref="on 'main', clean, identical to 'origin/main'"
}

#---------------------------------------------------------------------------------------------
# @description Switches a repository that is in 'publish' mode to the upgrade branch, reusing it if a same-day rerun
#   already created it (locally or on 'origin'), and creating it from the current HEAD only when neither exists.
#   Reusing an existing branch rather than recreating it from 'main' avoids a later non-fast-forward push.
#
# @arg $1 string Path to the repository's working tree.
# @arg $2 string Name of the upgrade branch.
#
# @exitcode success=0: the branch is checked out (new, or an existing local/remote one).
# @exitcode err_tool_error: git failed.
#---------------------------------------------------------------------------------------------
function start_publish_branch()
{
    (( $# == 2 ))                             || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two arguments (provided $#):" \
                                                                                  "  - the repository path" \
                                                                                  "  - the branch name"
    [[ ! -v 1 || -d "$1" ]]                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a valid repository path as the first argument."
    [[ ! -v 2 ]] || is_valid_branch_name "$2" || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a valid branch name as the second argument."
    exit_if_has_bugs

    if git -C "$1" show-ref --verify --quiet "refs/heads/$2"; then
        execute --quiet git -C "$1" switch "$2" ||
            return "$err_tool_error"
        trace "Switched to the existing local branch '$2' in '$1'."
        return "$success"
    fi

    if git -C "$1" show-ref --verify --quiet "refs/remotes/origin/$2"; then
        execute --quiet git -C "$1" switch -c "$2" --track "origin/$2" ||
            return "$err_tool_error"
        trace "Checked out the existing remote branch '$2' in '$1'."
        return "$success"
    fi

    execute --quiet git -C "$1" switch -c "$2" || return "$err_tool_error"

    trace "Created and switched to branch '$2' in '$1'."
}

#---------------------------------------------------------------------------------------------
# @description Commits the given paths on the current branch of a repository. A path pattern is staged only when it matches
#   something that changed (modified, deleted, or new), so a pattern such as '*packages.lock.json' is harmless when no
#   lock file changed.
#
# @arg $1 string Path to the repository's working tree.
# @arg $2 string Commit message.
# @arg $3..$@ string Paths or patterns to commit, relative to the repository root.
#
# @exitcode success=0: a new commit was made.
# @exitcode negative=1: nothing had changed; no commit was made. The caller MUST NOT push or open a PR in this case.
# @exitcode err_tool_error: git failed.
#---------------------------------------------------------------------------------------------
function commit_package_versions()
{
    (( $# >= 3 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires the repository path, the message, and at least one path (provided $#)."
    exit_if_has_bugs

    local _repo=$1
    local _message=$2
    local _pathspec

    shift 2
    for _pathspec in "$@"; do
        if [[ -n $(git -C "$_repo" ls-files --modified --deleted --others --exclude-standard -- "$_pathspec") ]]; then
            execute git -C "$_repo" add -A -- "$_pathspec" || return "$err_tool_error"
        fi
    done
    git -C "$_repo" diff --cached --quiet && return "$negative"
    execute git -C "$_repo" commit --quiet -m "$_message" || return "$err_tool_error"
}

#---------------------------------------------------------------------------------------------
# @description Checks the versions of one section of a 'Directory.Packages.props' file against NuGet and upgrades what
#   can be upgraded. Each result is recorded as a row: 'label|package|current|new|result'.
#   In dry-run mode the file is not changed; the rows say what would be updated.
#
# @arg $1 string Path to 'Directory.Packages.props'.
# @arg $2 string Section to process: 'shared' or 'repo'.
# @arg $3 string Label for the summary (e.g., the repository name).
# @arg $4 nameref Array that receives the summary rows.
#
# @exitcode success=0: the section was processed.
#---------------------------------------------------------------------------------------------
function update_section_versions()
{
    (( $# == 4 ))                              || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires four arguments (provided $#):" \
                                                                                   "  - the path of the file to be updated" \
                                                                                   "  - the flag designating which section of the file must be updated must be either 'shared' or 'repo'" \
                                                                                   "  - the summary label" \
                                                                                   "  - the name of the summary rows array."
    [[ ! -v 1 || -f $1 ]]                      || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the path of the file to be updated, to be a path to an existing file (provided ${1:-<none>})."
    [[ ! -v 2 || $2 == shared || $2 == repo ]] || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2, the flag designating which section of the file must be updated must be either 'shared' or 'repo' (provided ${2:-<none>})."
    [[ ! -v 3 || -n $3 ]]                      || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 3, the label, to be non-empty."
    [[ ! -v 4 ]] || is_indexed_array "$4"      || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 4 to be the name of an indexed array variable (provided ${4:-<none>})."
    exit_if_has_bugs

    local _file=$1
    local _section=$2
    local _label=$3
    local -n _rows_ref=$4   # The summary rows array that will receive the results of processing this section

    local -A _versions=()   # Associative array of package ID => current version
    local -a _ids=()        # array of package IDs
    local -a _found=()      # array of versions found for the package
    local _current _selected _candidate _result _all_prerelease _query_rc _t0

    read_package_versions "$_file" "$_section" _versions
    (( ${#_versions[@]} > 0 )) && readarray -t _ids < <(printf '%s\n' "${!_versions[@]}" | sort -f)

    local _id
    local _current          # the current version of the package _id

    for _id in "${_ids[@]}"; do
        _current=${_versions[$_id]}

        trace "$_label: checking '$_id' (current: $_current)..."
        _t0=$(now_us)
        query_package_versions "$_id" _found && _query_rc=0 || _query_rc=$?
        _t1=$(now_us)
        search_us=$(( search_us + _t1 - _t0 ))    # accumulate the search durations: (( _t1 - _t0 )) is the duration of this search
        search_count=$(( search_count + 1 ))

        if (( _query_rc != success )); then
            _rows_ref+=("$_label|$_id|$_current|-|$fail_em search failed")
            continue
        fi
        if (( ${#_found[@]} == 0 )); then
            _rows_ref+=("$_label|$_id|$_current|-|$question_em not found in any source")
            continue
        fi

        _selected=$_current
        select_upgrade_version "$_current" _selected "${_found[@]}"

        if [[ $_selected == "$_current" ]]; then
            _all_prerelease=true
            for _candidate in "${_found[@]}"; do
                is_semverRelease "$_candidate" && _all_prerelease=false
            done
            if $_all_prerelease; then
                _result="$right_arrow_em prerelease only"
            else
                _result="$check_em already latest"
            fi
            _rows_ref+=("$_label|$_id|$_current|$_selected|$_result")
            continue
        fi

        if set_package_version "$_file" "$_section" "$_id" "$_selected"; then
            _result="$up_arrow_em updated"
        else
            _result="$fail_em failed to write"
        fi
        _rows_ref+=("$_label|$_id|$_current|$_selected|$_result")
    done
}


#---------------------------------------------------------------------------------------------
# @description Deletes every 'packages.lock.json' in a repository and runs
#   'dotnet restore --force-evaluate' to regenerate them. The lock files are generated, never
#   hand-edited, so their previous state does not matter. Nothing is committed. What is
#   restored: every '*.csproj' outside a '/templates/' directory. File-based apps (e.g.
#   'examples/*.cs') are deliberately not restored: their lock files are not committed, and
#   their packages are declared in their own source, which this script does not change.
#
# @arg $1 string Path to the repository's working tree.
#
# @exitcode success=0: the lock files were regenerated.
# @exitcode err_not_found=9: no project was found.
# @exitcode err_tool_error=66: the deletion failed, or the restore failed.
#---------------------------------------------------------------------------------------------
function refresh_lock_files()
{
    (( $# == 1 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#): the repository path."
    [[ ! -v 1 || -d "$1" ]]       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires a valid repository path as the first argument."
    exit_if_has_bugs

    local _repo=$1
    local -i _rc=$success
    local -a _projects=()

    find_files_by_precedence "$_repo" _projects '*.csproj' || _rc=$?
    (( _rc == success )) || return "$_rc"

    local _project _t0 _t1

    _t0=$(now_us)
    for _project in "${_projects[@]}"; do
        # '--force-evaluate' overrides dotnet_restore's own '--locked-mode': it re-resolves every dependency and
        # rewrites an existing lock file instead of failing with NU1004 (verified with dotnet 10)
        dotnet_restore "$_project" --force-evaluate || {
            _rc=$?
            error -ec "$_rc" "Failed to restore '$_project'."
        }
    done
    _t1=$(now_us)
    restore_us=$(( restore_us + _t1 - _t0 ))

    return "$_rc"
}


#---------------------------------------------------------------------------------------------
# @description Opens a pull request for the upgrade branch, or finds the one already open for
#   it. The branch must already be pushed.
#
# @arg $1 string Path to the repository's working tree.
# @arg $2 string The upgrade branch (already pushed to 'origin').
# @arg $3 nameref Receives the PR's URL on success; left empty on failure.
#
# @exitcode success=0: a PR is open for the branch (found or created).
# @exitcode err_tool_error: 'gh' failed to find or create one.
#---------------------------------------------------------------------------------------------
function open_pull_request()
{
    (( $# == 3 ))                          || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three arguments (provided $#):" \
                                                                               "  - the repository path" \
                                                                               "  - the branch" \
                                                                               "  - the URL output."
    [[ ! -v 1 || -d $1 ]]                  || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1 to be a valid repository path (provided ${1:-<none>})."
    [[ ! -v 2 || -n $2 ]]                  || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2, the branch name, to be non-empty."
    [[ ! -v 3 ]] || is_variable_name "$3"  || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 3 to be the name of a variable (provided ${3:-<none>})."
    exit_if_has_bugs

    local _repo=$1 _branch=$2
    local -n _url_ref=$3
    _url_ref=''

    _url_ref=$(cd "$_repo" && gh pr list --head "$_branch" --state open --json url --jq '.[0].url // empty' 2>/dev/null) || true
    [[ -n $_url_ref ]] && return "$success"

    _url_ref=$(cd "$_repo" &&
               execute gh pr create --head "$_branch" \
                                    --title "chore(deps): update NuGet package versions in Directory.Packages.props" \
                                    --body "Automated dependency upgrade (stable versions only, never a downgrade) by 'update-packages.sh'." 2>/dev/null) || true
    [[ -n $_url_ref ]] && return "$success"
    return "$err_tool_error"
}
