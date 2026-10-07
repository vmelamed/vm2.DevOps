# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

# constants from lib:
declare -xri success
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_logic_error
declare -xri err_tool_error

#---------------------------------------------------------------------------------------------
# @description Chooses the version a package should be upgraded to. Only stable release versions
#   are considered. The result is the highest candidate that is strictly greater than the current
#   version under SemVer precedence; otherwise the current version is kept (never a downgrade).
#
# @arg $1 string The package's current version, as written in 'Directory.Packages.props'.
# @arg $2 nameref The name of a variable that receives the chosen version.
# @arg $@ string Candidate versions found by the search (zero or more; prereleases are ignored).
#
# @exitcode success=0: a version was chosen (it may be the current one).
#
# @example
#   select_upgrade_version 1.0.0 chosen 1.1.0-preview.3 1.0.2 1.0.1
#---------------------------------------------------------------------------------------------
function select_upgrade_version()
{
    (( $# >= 2 ))                          || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least two arguments (provided $#):" \
                                                                                  "  - the current version" \
                                                                                  "  - the name of the variable that receives the chosen version" \
                                                                                  "  - zero or more candidate versions"
    [[ ! -v 1 || -n $1 ]]                  || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the current version, to be non-empty."
    exit_if_has_bugs

    local _current=$1
    local -n _chosen=$2
    shift 2

    _chosen=$_current

    local _candidate
    for _candidate in "$@"; do
        is_semverRelease "$_candidate" || continue
        semver_greaterThan "$_candidate" "$_chosen" && _chosen=$_candidate
    done

    return "$success"
}

declare -xr props_shared_begin='<!-- <<<=== begin shared content -->'
declare -xr props_shared_end='<!-- ===>>> end shared content -->'

#---------------------------------------------------------------------------------------------
# @description Returns the section of 'Directory.Packages.props' a package line belongs to: the shared block between
#   the 'begin/end shared content' markers, or the repository-specific part outside them.
#
# @arg $1 string The section to match: 'shared' or 'repo'.
# @arg $2 string A line of the file.
# @arg $3 nameref The name of a variable that tracks whether the current line is inside the shared block.
#
# @exitcode success=0: the line belongs to the requested section.
# @exitcode negative=1: the line belongs to the other section, or is a marker line.
#---------------------------------------------------------------------------------------------
function _props_line_in_section()
{
    local _section=$1 _line=$2
    local -n _in_shared_ref=$3

    if [[ $_line == *"$props_shared_begin"* ]]; then _in_shared_ref=true; return "$negative"; fi
    if [[ $_line == *"$props_shared_end"* ]]; then _in_shared_ref=false; return "$negative"; fi

    [[ $_section == shared && $_in_shared_ref == true ]] && return "$success"
    [[ $_section == repo && $_in_shared_ref != true ]] && return "$success"
    return "$negative"
}

#---------------------------------------------------------------------------------------------
# @description Reads the package versions of one section of a 'Directory.Packages.props' file. Commented-out lines are
#   ignored. The keys keep the casing used in the file.
#
# @arg $1 string Path to 'Directory.Packages.props'.
# @arg $2 string The section to read: 'shared' or 'repo'.
# @arg $3 nameref Associative array that receives package ID => version.
#
# @exitcode success=0: the file was read.
#---------------------------------------------------------------------------------------------
function read_package_versions()
{
    local _file=$1 _section=$2
    local -n _versions_ref=$3
    local _line _id _version _inside=false
    local _package_regex='^[[:space:]]*<PackageVersion Include="([^"]+)" Version="([^"]+)"[[:space:]]*/>'

    _versions_ref=()
    while IFS= read -r _line || [[ -n $_line ]]; do
        _props_line_in_section "$_section" "$_line" _inside || continue
        [[ $_line == *"<!--"* || $_line == *"-->"* ]] && continue
        [[ $_line =~ $_package_regex ]] || continue
        _id=${BASH_REMATCH[1]}
        _version=${BASH_REMATCH[2]}
        _versions_ref[$_id]=$_version
    done < "$_file"
}

#---------------------------------------------------------------------------------------------
# @description Rewrites the version of one package in one section of a 'Directory.Packages.props' file, changing only that
#   line's Version attribute. The package ID is matched case-insensitively and the casing in the file is kept.
#
# @arg $1 string Path to 'Directory.Packages.props'.
# @arg $2 string The section to edit: 'shared' or 'repo'.
# @arg $3 string Package ID.
# @arg $4 string New version.
#
# @exitcode success=0: the package line was rewritten.
# @exitcode err_logic_error: the package is not in that section of the file.
#---------------------------------------------------------------------------------------------
function set_package_version()
{
    local _file=$1 _section=$2 _id=$3 _new=$4
    local _line _tmp _inside=false _done=false _line_id _line_version
    local _package_regex='^([[:space:]]*<PackageVersion Include=")([^"]+)(" Version=")([^"]+)("[[:space:]]*/>.*)$'

    _tmp=$(mktemp)
    while IFS= read -r _line || [[ -n $_line ]]; do
        if _props_line_in_section "$_section" "$_line" _inside &&
           [[ $_line != *"<!--"* && $_line != *"-->"* && $_line =~ $_package_regex ]] &&
           [[ ${BASH_REMATCH[2]} == "$_id" || ${BASH_REMATCH[2],,} == "${_id,,}" ]] &&
           [[ $_done == false ]]; then
            _line="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}${_new}${BASH_REMATCH[5]}"
            _done=true
        fi
        printf '%s\n' "$_line" >> "$_tmp"
    done < "$_file"

    if [[ $_done == true ]]; then
        mv "$_tmp" "$_file"
        return "$success"
    fi
    rm -f "$_tmp"
    return "$err_logic_error"
}

#---------------------------------------------------------------------------------------------
# @description Lists every version of a package found in the configured NuGet sources, using 'dotnet package search'.
#   Versions from all sources are returned; the package ID is matched case-insensitively.
#
# @arg $1 string Package ID.
# @arg $2 nameref Array that receives the versions.
#
# @exitcode success=0: the search ran (the array may be empty when the package is not found).
# @exitcode err_tool_error: the search failed.
#---------------------------------------------------------------------------------------------
function query_package_versions()
{
    local _id=$1
    local -n _found_ref=$2
    local _json

    _json=$(dotnet package search "$_id" --exact-match --format json 2>/dev/null) || return "$err_tool_error"

    readarray -t _found_ref < <(jq -r --arg id "$_id" \
        '.searchResult[].packages[] | select((.id | ascii_downcase) == ($id | ascii_downcase)) | .version' <<< "$_json")
    return "$success"
}
