# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

#---------------------------------------------------------------------------------------------
# @description Stashes any local changes in a repository (including untracked files) and creates the upgrade branch from
#   the current HEAD. The stash is left in place; the caller is told how to restore it.
#
# @arg $1 string Path to the repository's working tree.
# @arg $2 string Name of the branch to create.
#
# @exitcode success=0: the branch was created.
# @exitcode err_tool_error: git failed.
#---------------------------------------------------------------------------------------------
function prepare_upgrade_branch()
{
    (( $# == 2 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two arguments: the repository path and the branch name (provided $#)."
    [[ -n $1 && -n $2 ]]          || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires both arguments to be non-empty."
    exit_if_has_bugs

    local _repo=$1 _branch=$2 _previous

    # already on the upgrade branch (e.g. a re-run after an interruption): nothing to prepare
    [[ $(git -C "$_repo" branch --show-current) == "$_branch" ]] && return "$success"

    if [[ -n $(git -C "$_repo" status --porcelain) ]]; then
        _previous=$(git -C "$_repo" branch --show-current)
        git -C "$_repo" stash push --include-untracked --message "update-packages.sh: before $_branch" > /dev/null || return "$err_tool_error"
        warning "Stashed local changes in '$_repo'. To restore them later: git -C '$_repo' switch '$_previous' && git -C '$_repo' stash pop"
    fi

    git -C "$_repo" switch -c "$_branch" > /dev/null || return "$err_tool_error"
}

#---------------------------------------------------------------------------------------------
# @description Commits the given files on the current branch of a repository, if they have changes.
#
# @arg $1 string Path to the repository's working tree.
# @arg $2 string Commit message.
# @arg $@ string Files to commit, relative to the repository root.
#
# @exitcode success=0: committed, or nothing to commit.
# @exitcode err_tool_error: git failed.
#---------------------------------------------------------------------------------------------
function commit_package_versions()
{
    (( $# >= 3 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires the repository path, the message, and at least one file (provided $#)."
    exit_if_has_bugs

    local _repo=$1 _message=$2
    shift 2

    git -C "$_repo" add -- "$@" || return "$err_tool_error"
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
    local _id _current _selected _candidate _result _all_prerelease

    read_package_versions "$_file" "$_section" _versions
    (( ${#_versions[@]} > 0 )) && readarray -t _ids < <(printf '%s\n' "${!_versions[@]}" | sort -f)

    for _id in "${_ids[@]}"; do
        _current=${_versions[$_id]}

        if ! query_package_versions "$_id" _found; then
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
# @description Prints the summary rows as a table.
#
# @arg $@ string Rows in the form 'label|package|current|new|result'.
#
# @stdout The table.
#---------------------------------------------------------------------------------------------
function print_upgrade_summary()
{
    local _row _label _package _current _new _result
    printf '%-28s %-40s %-14s %-14s %s\n' "REPOSITORY" "PACKAGE" "CURRENT" "NEW" "RESULT"
    for _row in "$@"; do
        IFS='|' read -r _label _package _current _new _result <<< "$_row"
        printf '%-28s %-40s %-14s %-14s %s\n' "$_label" "$_package" "$_current" "$_new" "$_result"
    done
}

#---------------------------------------------------------------------------------------------
# @description Runs 'dotnet restore --force-evaluate' in a repository and commits the regenerated 'packages.lock.json'
#   files as a separate commit. Skipped, with a warning, when the repository already has uncommitted changes to lock
#   files, so unrelated changes are never committed by mistake.
#
# @arg $1 string Path to the repository's working tree.
#
# @exitcode success=0: refreshed and committed, skipped, or nothing changed.
# @exitcode err_tool_error: the restore or the commit failed.
#---------------------------------------------------------------------------------------------
function refresh_lock_files()
{
    (( $# == 1 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument: the repository path (provided $#)."
    exit_if_has_bugs

    local _repo=$1

    if [[ -n $(git -C "$_repo" status --porcelain -- '*packages.lock.json') ]]; then
        warning "'$_repo' has uncommitted changes in packages.lock.json; skipped the lock-file refresh for it."
        return "$success"
    fi

    (cd "$_repo" && dotnet restore --force-evaluate > /dev/null) || return "$err_tool_error"

    if [[ -z $(git -C "$_repo" ls-files -- '*packages.lock.json') && -z $(git -C "$_repo" ls-files --others --exclude-standard -- '*packages.lock.json') ]]; then
        return "$success"
    fi

    commit_package_versions "$_repo" "chore(deps): refresh packages.lock.json after Directory.Packages.props update" '*packages.lock.json'
}
