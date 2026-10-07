# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

# constants from lib:
declare -xri success
declare -xri err_invalid_arguments
declare -xri err_tool_error
declare -x _ignore

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
    (( $# == 3 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three arguments: the repository path, the mode, and the reason (provided $#)."
    exit_if_has_bugs

    local _repo=$1
    local -n _mode_ref=$2 _reason_ref=$3
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
# @description Creates the upgrade branch from the current HEAD of a repository that is in 'publish' mode.
#
# @arg $1 string Path to the repository's working tree.
# @arg $2 string Name of the upgrade branch.
#
# @exitcode success=0: the branch is checked out.
# @exitcode err_tool_error: git failed (e.g., the branch already exists).
#---------------------------------------------------------------------------------------------
function start_publish_branch()
{
    (( $# == 2 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two arguments: the repository path and the branch name (provided $#)."
    exit_if_has_bugs

    git -C "$1" switch -c "$2" > "$_ignore" 2>&1 || return "$err_tool_error"
    trace "Created and switched to branch '$2' in '$1'."
}

#---------------------------------------------------------------------------------------------
# @description Commits the given paths on the current branch of a repository. A path pattern is staged only when it matches
#   something that changed (modified, deleted, or new), so a pattern such as '*packages.lock.json' is harmless when no
#   lock file changed.
#
# @arg $1 string Path to the repository's working tree.
# @arg $2 string Commit message.
# @arg $@ string Paths or patterns to commit, relative to the repository root.
#
# @exitcode success=0: committed, or nothing to commit.
# @exitcode err_tool_error: git failed.
#---------------------------------------------------------------------------------------------
function commit_package_versions()
{
    (( $# >= 3 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires the repository path, the message, and at least one path (provided $#)."
    exit_if_has_bugs

    local _repo=$1 _message=$2 _pathspec
    shift 2

    for _pathspec in "$@"; do
        if [[ -n $(git -C "$_repo" ls-files --modified --deleted --others --exclude-standard -- "$_pathspec") ]]; then
            git -C "$_repo" add -A -- "$_pathspec" || return "$err_tool_error"
        fi
    done
    git -C "$_repo" diff --cached --quiet && return "$success"
    git -C "$_repo" commit --quiet -m "$_message" || return "$err_tool_error"
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
    (( $# == 4 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires four arguments: the file, the section, the label, and the rows array (provided $#)."
    exit_if_has_bugs

    local _file=$1 _section=$2 _label=$3
    local -n _rows_ref=$4
    local -A _versions=()
    local -a _ids=() _found=()
    local _id _current _selected _candidate _result _all_prerelease _query_rc _t0

    read_package_versions "$_file" "$_section" _versions
    (( ${#_versions[@]} > 0 )) && readarray -t _ids < <(printf '%s\n' "${!_versions[@]}" | sort -f)

    for _id in "${_ids[@]}"; do
        _current=${_versions[$_id]}

        trace "$_label: checking '$_id' (current: $_current)..."
        _t0=$(now_us)
        query_package_versions "$_id" _found && _query_rc=0 || _query_rc=$?
        search_us=$(( search_us + $(now_us) - _t0 ))
        search_count=$(( search_count + 1 ))

        if (( _query_rc != success )); then
            _rows_ref+=("$_label|$_id|$_current|-|search failed")
            continue
        fi
        if (( ${#_found[@]} == 0 )); then
            _rows_ref+=("$_label|$_id|$_current|-|not found in any source")
            continue
        fi

        _selected=$_current
        select_upgrade_version "$_current" _selected "${_found[@]}"

        if [[ $_selected == "$_current" ]]; then
            _all_prerelease=true
            for _candidate in "${_found[@]}"; do
                is_semverRelease "$_candidate" && _all_prerelease=false
            done
            if [[ $_all_prerelease == true ]]; then
                _result="prerelease only"
            else
                _result="already latest"
            fi
            _rows_ref+=("$_label|$_id|$_current|$_selected|$_result")
            continue
        fi

        if is_dry_run; then
            _result="would update"
        elif set_package_version "$_file" "$_section" "$_id" "$_selected"; then
            _result="updated"
        else
            _result="failed to write"
        fi
        _rows_ref+=("$_label|$_id|$_current|$_selected|$_result")
    done
}


#---------------------------------------------------------------------------------------------
# @description Deletes every 'packages.lock.json' in a repository and runs 'dotnet restore --force-evaluate' to regenerate
#   them. The lock files are generated, never hand-edited, so their previous state does not matter. Nothing is committed.
#
# @arg $1 string Path to the repository's working tree.
#
# @exitcode success=0: the lock files were regenerated.
# @exitcode err_tool_error: the restore failed.
#---------------------------------------------------------------------------------------------
function refresh_lock_files()
{
    (( $# == 1 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument: the repository path (provided $#)."
    exit_if_has_bugs

    local _repo=$1 _restore_rc _t0
    find "$_repo" -name packages.lock.json -not -path '*/.git/*' -delete

    _t0=$(now_us)
    (cd "$_repo" && dotnet restore --force-evaluate > /dev/null) && _restore_rc=0 || _restore_rc=$?
    restore_us=$(( restore_us + $(now_us) - _t0 ))
    (( _restore_rc == 0 )) || return "$err_tool_error"
}


#---------------------------------------------------------------------------------------------
# @description Opens a pull request for the upgrade branch, or finds the one already open for it. The branch must
#   already be pushed.
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
    (( $# == 3 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three arguments: the repository path, the branch, and the URL output (provided $#)."
    exit_if_has_bugs

    local _repo=$1 _branch=$2
    local -n _url_ref=$3
    _url_ref=''

    _url_ref=$(cd "$_repo" && gh pr list --head "$_branch" --state open --json url --jq '.[0].url // empty' 2>/dev/null) || true
    [[ -n $_url_ref ]] && return "$success"

    _url_ref=$(cd "$_repo" && gh pr create --head "$_branch" \
        --title "chore(deps): update NuGet package versions in Directory.Packages.props" \
        --body "Automated dependency upgrade (stable versions only, never a downgrade) by \`update-packages.sh\`." \
        2>/dev/null) || true
    [[ -n $_url_ref ]] && return "$success"
    return "$err_tool_error"
}
