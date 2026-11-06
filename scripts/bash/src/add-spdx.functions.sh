# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name

# core lib exit codes
declare -xri success
declare -xri err_invalid_arguments
declare -xri err_not_file
declare -xri err_logic_error
declare -xri err_io_failure

# this scripts constants
declare -x root

# this scripts variables
declare -x cs_header
declare -x bash_header
declare -x yaml_header

declare -xi processed
declare -xi modified
declare -xi skipped
declare -xi failed

#---------------------------------------------------------------------------------------------
# @description Prepends the SPDX header to a C# file, stripping a leading UTF-8 BOM (if any):
#   the vm2 convention is plain UTF-8 (no BOM), enforced via '.editorconfig' ('charset =
#   utf-8'), so a stray BOM left over from a classic-Visual-Studio-created file is cleaned up
#   as a side effect of adding the header.
#
# @arg $1 string Path to an existing C# file with no SPDX header yet.
# @arg $2 string the path to an existing writable temporary file to write the modified contents of the original $1 file to
#
# @exitcode success=0: the modified content of file $1 was successfully written to $2.
#---------------------------------------------------------------------------------------------
function add_spdx_csharp_file()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() expects two arguments (provided $#):" \
                                                                                       "  - the name of the file to add an SPDX header to" \
                                                                                       "  - the name of a temporary file where to write the modified contents to" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || $1 == *.cs ]]                                                  || bug "${FUNCNAME[0]}() requires argument 1, the file to add an SPDX header to, to be a *.cs file (provided: '$1')." -ec "$err_not_file"
    [[ ! -v 2 || -w $2 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 2, the file to write the modified contents to, to be an existing writable file (provided: '$2')." -ec "$err_not_file"
    exit_if_has_bugs

    local _file="$1"
    local _temp_file="$2"
    {
        printf "%s" "$cs_header"

        # Check if file has a UTF-8 BOM (0xEF 0xBB 0xBF) and skip past it if so
        if head -c 3 "$_file" | od -An -tx1 | grep -q "ef bb bf"; then
            tail -c +4 "$_file"
        else
            cat "$_file"
        fi
    } > "$_temp_file"
}

#---------------------------------------------------------------------------------------------
# @description Prepends the SPDX header to a bash file, inserting it after the shebang line
#   when there is one, or at the very top otherwise.
#
# @arg $1 string Path to an existing bash file with no SPDX header yet.
# @arg $2 string the path to an existing writable temporary file to write the modified contents of the original $1 file to
#
# @exitcode success=0: the modified content of file $1 was successfully written to $2.
#---------------------------------------------------------------------------------------------
function add_spdx_bash_file()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() expects two arguments (provided $#):" \
                                                                                       "  - the name of the file to add an SPDX header to" \
                                                                                       "  - the name of a temporary file where to write the modified contents to" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || $1 == *.@(sh|bats) ]]                                          || bug "${FUNCNAME[0]}() requires argument 1, the file to add an SPDX header to, to be *.sh or *.bats file (provided: '$1')." -ec "$err_not_file"
    [[ ! -v 2 || -w $2 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 2, the file to write the modified contents to, to be an existing writable file (provided: '$2')." -ec "$err_not_file"
    exit_if_has_bugs

    local _file="$1"
    local _temp_file="$2"
    local _first_line

    _first_line=$(head -n 1 "$_file")

    {
        if [[ "$_first_line" =~ ^#! ]]; then
            # Has shebang - insert after it
            echo "$_first_line"
            printf "%s" "$bash_header"
            tail -n +2 "$_file"
        else
            # No shebang - insert at top
            printf "%s" "$bash_header"
            cat "$_file"
        fi
    } > "$_temp_file"
}

#---------------------------------------------------------------------------------------------
# @description Prepends the SPDX header to a YAML file. Always inserted at the top: unlike bash
#   scripts, YAML has no shebang-equivalent line to insert after.
#
# @arg $1 string Path to an existing YAML file with no SPDX header yet.
# @arg $2 string the path to an existing writable temporary file to write the modified contents of the original $1 file to
#
# @exitcode success=0: the modified content of file $1 was successfully written to $2.
#---------------------------------------------------------------------------------------------
function add_spdx_yaml_file()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() expects two arguments (provided $#):" \
                                                                                       "  - the name of the file to add an SPDX header to" \
                                                                                       "  - the name of a temporary file where to write the modified contents to" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || $1 == *.@(yaml|yml) ]]                                         || bug "${FUNCNAME[0]}() requires argument 1, the file to add an SPDX header to, to be *.yaml or *.yml file (provided: '$1')." -ec "$err_not_file"
    [[ ! -v 2 || -w $2 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 2, the file to write the modified contents to, to be an existing writable file (provided: '$2')." -ec "$err_not_file"
    exit_if_has_bugs

    local _file="$1"
    local _temp_file="$2"

    {
        printf "%s" "$yaml_header"
        cat "$_file"
    } > "$_temp_file"
}

#---------------------------------------------------------------------------------------------
# @description Drives one file through the steps shared by all file types: skips it if it already
#   has an SPDX header, reports it as an error if it is read-only, otherwise has the writer for
#   its type write the new contents to a temporary file next to it, which then replaces the
#   original (through 'execute', so a dry run only prints the 'mv'). Updates exactly one of the
#   'modified'/'skipped'/'failed' counters, besides 'processed', for every file.
#
# @arg $1 string Path to the file to process.
#
# @exitcode success=0: the file got the header, or already had one.
# @exitcode err_not_file: the file is not writable (reported with 'error').
# @exitcode err_io_failure: creating, writing, or moving the temporary file failed
#   (reported with 'error').
#---------------------------------------------------------------------------------------------
function process_file()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() expects one argument (provided $#):" \
                                                                                       "  - the name of the file to add an SPDX header to" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || $1 == *.@(cs|sh|bats|yaml|yml) ]]                              || bug "${FUNCNAME[0]}() requires argument 1, the file to add an SPDX header to, to be a file with one of the suffixes: *.cs, *.sh, *.bats, *.yaml, or *.yml (provided: '$1')." -ec "$err_not_file"
    exit_if_has_bugs

    local _file="$1"
    local _rel=".${_file#"$root"}"

    trace "Processing $_file"
    (( ++processed ))

    if grep -q "SPDX-License-Identifier" "$_file"; then
        info "Skipping (has header): $_rel"
        (( ++skipped ))
        return
    fi

    local -i _rc=$success

    [[ -w $1 ]]                                                                 || { _rc=$err_not_file; error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the file to add an SPDX header to, to be an existing writable file (provided: '$1')."; }
    (( _rc == success ))                                                        || { (( ++failed )); return "$_rc"; }

    local _temp_file

    _temp_file=$(mktemp)                                                        || { _rc=$err_io_failure; (( ++failed )); error -ec "$_rc" "Failed to create a temporary file for '$_rel'"; return "$_rc"; }
    case $_file in
        *.cs         )
            add_spdx_csharp_file "$_file" "$_temp_file"                         || _rc=$?
            ;;
        *.sh|*.bats  )
            add_spdx_bash_file "$_file" "$_temp_file"                           || _rc=$?
            ;;
        *.yaml|*.yml )
            add_spdx_yaml_file "$_file" "$_temp_file"                           || _rc=$?
            ;;
        *            )
            exit_with_bug -ec "$err_logic_error" "${FUNCNAME[0]}() requires argument 1, the file to add an SPDX header to, to be an existing writable file with one of the suffixes: .cs, .sh, .bats, .yaml, or .yml (provided: '$_file')."
            ;;
    esac
    (( _rc == success ))                                                        || { _rc=$err_io_failure; error -ec "$_rc" "Failed to write the new contents of '$_rel'"; }
    (( _rc != success )) || chmod --reference="$_file" "$_temp_file"            || { _rc=$err_io_failure; error -ec "$_rc" "Failed to change the mode of a temporary file"; }
    (( _rc != success )) || execute mv "$_temp_file" "$_file"                   || { _rc=$err_io_failure; error -ec "$_rc" "Failed to copy the temporary file over the original file '$_file'"; }
    rm -f "$_temp_file"
    (( _rc == success ))                                                        || { (( ++failed )); return "$_rc"; }

    (( ++modified ))
    if is_dry_run; then
        info "Would've added header to: $_rel"
    else
        info "Added header to: $_rel"
    fi
}
