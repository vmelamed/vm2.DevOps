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
declare -xri err_invalid_item

# One PackageVersion element on ONE line, Include before Version, double quotes. Groups: 1 prefix, 2 id, 3 middle,
# 4 version, 5 suffix -- set_package_version reassembles 1..5 with a new 4, so the line's original spacing survives.
# Anything else (multi-line elements, other attribute order, single quotes) is rejected by validate_package_lines
# before a run writes anything, instead of being silently skipped.
declare -xr package_regex='^([[:space:]]*<PackageVersion[[:space:]]+Include=")([^"]+)("[[:space:]]+Version=")([^"]+)("[[:space:]]*/>.*)$'

#---------------------------------------------------------------------------------------------
# @description Verifies that every PackageVersion element in a 'Directory.Packages.props' file has the one-line shape
#   that read_package_versions and set_package_version understand ($package_regex). Reports EVERY offending line, with
#   file and line number, so the caller can stop before anything is written instead of silently skipping packages.
#   Lines containing '<!--' or '-->' are ignored, the same way the reader ignores them.
#
# Note: the XML parsing is sub-optimal and it is expected that additional rules are followed:
#   - the file is well-formed XML
#   - all comments are single line: '<!-- valid single line comment -->'
#   - the comments are not mixed with XML elements on the same line '<!-- invalid single comment mixed with element --><PackageVersion...>'
#   - the XML elements specifying package versions are single-line elements of the form: <PackageVersion Include="..." Version="..." />
#
# @arg $1 string Path to 'Directory.Packages.props'.
#
# @exitcode success=0: every PackageVersion line has the supported shape.
# @exitcode err_invalid_item=14: at least one does not (each one is reported via error()).
#---------------------------------------------------------------------------------------------
function validate_package_lines()
{
    (( $# == 1 ))         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument: the path to 'Directory.Packages.props' (provided $#)."
    [[ ! -v 1 || -f $1 ]] || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1 to be a path to an existing file (provided ${1-<missing>})."
    exit_if_has_bugs

    local _file=$1 _line
    local -i _rc=$success _line_number=0

    while IFS= read -r _line || [[ -n $_line ]]; do
        (( ++_line_number ))
        [[ $_line == *"<PackageVersion"* ]]           || continue # skip non-PackageVersion lines, e.g., "<ItemGroup..."
        [[ $_line == *"<!--"* || $_line == *"-->"* ]] && continue # skip comments, e.g., <!-- <PackageVersion... /> -->
        [[ $_line =~ $package_regex ]]                && continue # validate PackageVersion lines, e.g., <PackageVersion Include="<id>" Version="<version>" />

        _rc=$err_invalid_item
        error -ec "$_rc" "$_file:$_line_number: unsupported PackageVersion format; expected one line in the form" \
                         "  <PackageVersion Include=\"<id>\" Version=\"<version>\" />" \
                         "  but found: $_line"
    done < "$_file"
    return "$_rc"
}

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
    [[ ! -v 2 ]] || is_variable_name "$2"  || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2, to be the name of a variable."
    exit_if_has_bugs

    local _current=$1
    local -n _chosen=$2

    _chosen=$_current

    local _candidate

    shift 2
    for _candidate in "$@"; do
        is_semverRelease "$_candidate" || continue
        semver_greaterThan "$_candidate" "$_chosen" && _chosen=$_candidate
    done

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Markers that delimit a "shared" block within an otherwise private/local file -- content between them is expected
#   to stay synced with the SoT, while everything outside is left entirely to the target repository. Matched as a plain
#   substring anywhere on a line; any trailing text after the marker on that line (e.g. a human-readable "Beginning of shared
#   content" label) is purely descriptive and ignored by the scanner. The two marker LINES themselves are delimiters and are
#   never considered part of the shared content.
#---------------------------------------------------------------------------------------------
declare -xr shared_begin_marker
declare -xr shared_end_marker

#---------------------------------------------------------------------------------------------
# @description Returns the section of 'Directory.Packages.props' a package line belongs to: the shared block between
#   the 'begin/end shared content' markers, or the repository-specific part outside them.
#
# Note: the XML parsing is sub-optimal and it is expected that additional rules are followed:
#   - the file is well-formed XML
#   - all comments are single line: '<!-- valid single line comment -->'
#   - the comments are not mixed with XML elements on the same line '<!-- invalid single comment mixed with element --><PackageVersion...>'
#   - the XML elements specifying package versions are single-line elements of the form: <PackageVersion Include="..." Version="..." />
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
    (( $# == 3 ))                              || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three arguments (provided $#):" \
                                                                                   "  - the section to match ('shared' or 'repo')" \
                                                                                   "  - the line of the file to test" \
                                                                                   "  - the name of the variable that tracks whether the current line is inside the shared block"
    [[ ! -v 1 || $1 == shared || $1 == repo ]] || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2 to be which section to match - either 'shared' or 'repo' (provided ${1-<missing>})."
    [[ ! -v 3 ]] || is_variable "$3"           || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 3 to be the name of a variable that tracks whether the current line is inside the shared block (provided ${3-<missing>})."
    exit_if_has_bugs

    [[ -z ${2-} ]] && return "$negative" # shortcut for empty XML lines

    local _section=$1
    local _line=$2
    local -n _in_shared_ref=$3

    [[ $_line != *"$shared_begin_marker"* ]] || { _in_shared_ref=true; return "$negative"; }
    [[ $_line != *"$shared_end_marker"* ]]   || { _in_shared_ref=false; return "$negative"; }

    [[ $_section == shared && $_in_shared_ref == true ]] && return "$success"
    [[ $_section == repo && $_in_shared_ref != true ]] && return "$success"

    return "$negative"
}

#---------------------------------------------------------------------------------------------
# @description Reads the package versions of one section of a 'Directory.Packages.props' file. Commented-out lines are
#   ignored. The keys keep the casing used in the file.
#
# Note: the XML parsing is sub-optimal and it is expected that additional rules are followed:
#   - the file is well-formed XML
#   - all comments are single line: '<!-- valid single line comment -->'
#   - the comments are not mixed with XML elements on the same line '<!-- invalid single comment mixed with element --><PackageVersion...>'
#   - the XML elements specifying package versions are single-line elements of the form: <PackageVersion Include="..." Version="..." />
#
# @arg $1 string Path to 'Directory.Packages.props'.
# @arg $2 string The section to read: 'shared' or 'repo'.
# @arg $3 nameref Associative array that receives package ID => version.
#
# @exitcode success=0: the file was read.
#---------------------------------------------------------------------------------------------
function read_package_versions()
{
    (( $# == 3 ))                              || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three arguments (provided $#):" \
                                                                                   "  - the path to 'Directory.Packages.props' file" \
                                                                                   "  - the section ('shared' or 'repo')" \
                                                                                   "  - the name of the variable that receives the versions"
    [[ ! -v 1 || -f $1 ]]                      || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1 to be a path to an existing file (provided ${1-<missing>})."
    [[ ! -v 2 || $2 == shared || $2 == repo ]] || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2 to be either 'shared' or 'repo' (provided ${2-<missing>})."
    [[ ! -v 3 ]] || is_associative_array "$3"  || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 3 to be the name of an associative array variable (provided ${3-<missing>})."
    exit_if_has_bugs

    local _file=$1
    local _section=$2
    local -n _versions_ref=$3

    local _line
    local _id
    local _version
    local _inside=false

    _versions_ref=()
    while IFS= read -r _line || [[ -n $_line ]]; do
        _props_line_in_section "$_section" "$_line" _inside || continue # Skip lines outside the specified section
        [[ $_line == *"<!--"* || $_line == *"-->"* ]] && continue       # Skip lines containing comments
        [[ $_line =~ $package_regex ]] || continue                      # Skip lines that do not match the package regex
        _id=${BASH_REMATCH[2]}                                          # package_regex groups: 1 prefix, 2 id, 3 middle, 4 version, 5 suffix
        _version=${BASH_REMATCH[4]}
        # shellcheck disable=SC2004 # $/${} is unnecessary on arithmetic variables.
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

    _tmp=$(mktemp)
    while IFS= read -r _line || [[ -n $_line ]]; do
        if _props_line_in_section "$_section" "$_line" _inside &&
           [[ $_line != *"<!--"* && $_line != *"-->"* && $_line =~ $package_regex ]] &&
           [[ ${BASH_REMATCH[2]} == "$_id" || ${BASH_REMATCH[2],,} == "${_id,,}" ]] &&
           [[ $_done == false ]]; then
            _line="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}${_new}${BASH_REMATCH[5]}"
            _done=true
        fi
        printf '%s\n' "$_line" >> "$_tmp"
    done < "$_file"

    local _rc=$success

    if [[ $_done == true ]]; then
        execute mv "$_tmp" "$_file" || _rc=$?
        (( _rc == success )) || {
            _rc="$err_tool_error"
            error -ec "$_rc" "Failed to copy temporary file to '$_file'."
        }
    else
        _rc=$err_logic_error
    fi

    rm -f "$_tmp"

    return "$_rc"
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
    (( $# == 2 ))                         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two arguments (provided $#): the package ID and the name of the variable that receives the versions."
    [[ ! -v 1 || -n $1 ]]                 || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the package ID, to be non-empty."
    [[ ! -v 2 ]] || is_variable_name "$2" || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2 to be the name of a variable (provided ${2-<missing>})."
    exit_if_has_bugs

    local _rc=$success
    local _id=$1
    local -n _found_ref=$2
    local _json

    _json=$(dotnet package search "$_id" --exact-match --format json 2>/dev/null) || return "$err_tool_error"

    local _output_file
    _output_file=$(mktemp) || {
        _rc=$err_tool_error
        error -ec "$_rc" "Failed to create a temporary output file."
    }

    (( _rc != success )) ||
    jq -r --arg id "$_id" '.searchResult[].packages[] | select((.id | ascii_downcase) == ($id | ascii_downcase)) | .version' <<< "$_json" > "$_output_file" || {
        _rc=$err_tool_error
        error -ec "$_rc" "Failed to query package versions."
    }

    (( _rc != success )) ||
    readarray -t _found_ref < "$_output_file" || {
        _rc=$?
        error -ec "$_rc" "Failed to read package versions from temporary output file." "$(get_dotnet_error_message "$_rc")"
    }

    rm -f "$_output_file"
    return "$_rc"
}
