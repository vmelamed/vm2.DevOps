# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#=============================================================================================
# Functions for performing diff and merge operations, including shared blocks, in the VM2 DevOps scripts.
#=============================================================================================

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_not_directory
declare -xri err_invalid_arguments
declare -xri err_logic_error
declare -xri err_tool_error
declare -xri err_dir_with_ci
declare -xri err_argument_type
declare -xri err_not_file

declare -x _ignore

declare -xr vm2_sot_repo_name

declare -x vm2_repos
declare -x diff_only

declare -x diff_tool
declare -x diff_command
declare -x merge_tool
declare -x merge_command

# follow the git diff and merge commands parameters naming convention
declare LOCAL=""
declare REMOTE=""

declare -xr action_ignore="ignore"
declare -xr action_merge_or_copy="merge or copy"
declare -xr action_ask_to_merge="ask to merge"
declare -xr action_merge="merge"
declare -xr action_ask_to_copy="ask to copy"
declare -xr action_copy="copy"
declare -xr action_copy_shared="copy shared"
declare -xr action_ask_to_copy_shared="ask to copy shared"

declare -xra valid_actions=(
    "$action_ignore"
    "$action_merge_or_copy"
    "$action_ask_to_merge"
    "$action_merge"
    "$action_ask_to_copy"
    "$action_copy"
    "$action_copy_shared"
    "$action_ask_to_copy_shared"
)

all_actions_str=$(print_sequence -s=', ' -q='"' "${valid_actions[@]}")
declare -xr all_actions_str

#---------------------------------------------------------------------------------------------
# @description Markers that delimit a "shared" block within an otherwise private/local file -- content between
# them is expected to stay synced with the SoT, while everything outside is left entirely to the target
# repository. Matched as a plain substring anywhere on a line; any trailing text after the marker on that line
# (e.g. a human-readable "Beginning of shared content" label) is purely descriptive and ignored by the scanner.
# The two marker LINES themselves are delimiters and are never considered part of the shared content.
#---------------------------------------------------------------------------------------------
declare -xr shared_begin_marker='<<<==='
declare -xr shared_end_marker='===>>>'

# Additional 'are_different()' outcomes, alongside the existing '$positive'/'$negative':
declare -xri shared_equal=2
declare -xri shared_not_equal=3

#---------------------------------------------------------------------------------------------
# @description Resolves the target repository directory and ensures it is in a valid state.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string the directory of the vm2 repositories (must be an existing directory)
# @arg $2 string the directory name of the target repository
# @arg $3 string nameref to the variable to store the absolute path of the root of the target repository
# @arg $4 string nameref to the variable to store the absolute path of the target repository directory
#
# @exitcode success=0: the target repository directory is resolved and in a valid state
# @exitcode err_not_directory=17: the target repository directory does not exist or is not a valid git repository with CI configured
# @exitcode err_logic_error: the target repository is a git repository but is not in a clean working-tree state
# @exitcode err_tool_error: 'git branch --show-current' failed against the resolved target repository (it appears corrupted)
#---------------------------------------------------------------------------------------------
function resolve_target()
{
    local -i _rc="$success"

    (( $# == 4 ))        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects four arguments (provided $#):" \
                                                                "  - the directory of the repositories" \
                                                                "  - the directory name of the target repository" \
                                                                "  - the name of the variable to store the absolute path of the root of the target repository" \
                                                                "  - the name of the variable to store the absolute path of the target repository directory"
    [[ -n $1 && -d $1 ]] || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 1, the directory of the vm2 repositories, to be a non-empty existing directory."
    [[ -n $2 ]]          || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the directory name of the target repository, to be a non-empty existing directory."
    is_variable "$3"     || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3, the name of the variable to store the absolute path to the root of the working tree of the target repository."
    is_variable "$4"     || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 4, the name of the variable to store the absolute path to the target repository directory."

    exit_if_has_bugs

    local _repos="$1"
    local _r="$2"
    local -n _target_root="$3"
    local -n _target_path="$4"
    local branch="<not a git repository>"

    resolve_repo_root "$_repos" "$_r" _target_root _target_path || _rc=$?

    # We can only work with git repos or directories that have CI configured:
    (( _rc == success || _rc == err_dir_with_ci )) || {
        error -ec "$_rc" "The specified target directory '${_repos%/}/${_r#/}' is invalid. It should have CI configured in '.github/workflows'."
        return "$_rc"
    }

    (( _rc == err_dir_with_ci )) && {
        warning "The root directory of the target project is '$_target_root', but it is not a git repository yet."
        return "$success"
    }

    # if it is a git repo then make sure it is in a clean state:
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    branch="$(git -C "$_target_root" branch --show-current 2>"$_ignore")" && {
        ensure_fresh_git_state "$_target_root" "$branch" || {
            _rc=$err_logic_error
            error -ec "$_rc" "The specified target repository at '$_target_root' on branch '$branch' is not in a clean state." \
                                                "Commit or stash your changes."
        }
    } || {
        _rc=$err_tool_error
        error -ec "$_rc" "The repository in the specified target directory '$1' appears corrupted."
    }

    trace "The Git working tree root of the target repository is '$_target_root', on a branch '$branch'."
    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Locates a single well-formed '$shared_begin_marker'/'$shared_end_marker' pair in the given file
# and reports their 1-based line numbers via the two nameref output variables.
#
# Notes:
#   - Fails (without a bug-exit -- this is an expected runtime outcome, not a caller contract violation) if the
#     file has zero or more than one begin marker, zero or more than one end marker, or the begin marker is not
#     strictly before the end marker. Only a single shared block per file is supported.
#
# @arg $1 string path to the file to scan
# @arg $2 string name of the variable to receive the begin marker's line number
# @arg $3 string name of the variable to receive the end marker's line number
#
# @exitcode positive=0: exactly one well-formed marker pair was found; the two nameref outputs were set.
# @exitcode negative=1: no well-formed, single marker pair could be found; the nameref outputs were not set.
#---------------------------------------------------------------------------------------------
function __find_shared_markers()
{
    (( $# == 3 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly three arguments (provided $#):" \
                                                                         "  - the file to scan for a shared-content marker pair" \
                                                                         "  - the name of the variable to receive the begin marker's line number" \
                                                                         "  - the name of the variable to receive the end marker's line number"
    [[ -v 1 && -f $1 ]]              || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the file to scan, to be an existing file (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to be the name of a defined variable (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_variable "$3" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3 to be the name of a defined variable (provided '${3:-<none>}')."

    exit_if_has_bugs

    local -n _begin_line_out="$2"
    local -n _end_line_out="$3"

    local -i _begin_count _end_count

    _begin_count=$(grep -Fc -- "$shared_begin_marker" "$1") || true
    _end_count=$(grep -Fc -- "$shared_end_marker" "$1")     || true

    (( _begin_count == 1 && _end_count == 1 )) || return "$negative"

    _begin_line_out=$(grep -Fn -- "$shared_begin_marker" "$1" | cut -d: -f1)
    _end_line_out=$(grep -Fn -- "$shared_end_marker" "$1" | cut -d: -f1)

    (( _begin_line_out < _end_line_out )) || return "$negative"

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Extracts the content strictly between a single '$shared_begin_marker'/'$shared_end_marker' pair
# in the given file, via the nameref output variable. The two marker lines themselves are excluded.
#
# Notes:
#   - Fails (without a bug-exit -- see '__find_shared_markers()') if no well-formed, single marker pair exists.
#
# @arg $1 string path to the file to scan
# @arg $2 string name of the variable to receive the extracted shared block content
#
# @exitcode positive=0: exactly one well-formed marker pair was found; the shared block content
#   (possibly empty) was stored in the output variable
# @exitcode negative=1: no well-formed, single marker pair could be found
#
# @example
#   get_shared_block "$source_file" _shared_content || warning "..."
#---------------------------------------------------------------------------------------------
function get_shared_block()
{
    (( $# == 2 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                         "  - the file to scan for a shared-content marker pair" \
                                                                         "  - the name of the variable to receive the extracted shared content"
    [[ -v 1 && -f $1 ]]              || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the file to scan, to be an existing file (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to be the name of a defined variable (provided '${2:-<none>}')."

    exit_if_has_bugs

    local -n _shared_content_out="$2"

    local -i _begin_line _end_line

    __find_shared_markers "$1" _begin_line _end_line || return "$negative"

    _shared_content_out=$(sed -n "$((_begin_line + 1)),$((_end_line - 1))p" "$1")

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Compares two files with a fast whitespace/blank-line-insensitive 'diff -q -w -B'. If they are identical,
# returns immediately. If they differ, also scans both files for a single '$shared_begin_marker'/'$shared_end_marker'
# pair and, when both are found and well-formed, compares only the content between them -- letting a caller sync just
# the "shared" portion of an otherwise private/local file (see 'copy_shared_block()'). If either file's markers are
# missing or malformed, falls back to the plain whole-file result, so a broken marker never blocks the file --
# warning about it only when 'warn_no_markers' is true (callers whose action doesn't understand shared blocks at
# all, e.g. plain 'copy'/'merge'/'ignore', pass false, since most files have no markers and a warning on every one
# of them would be noise; it still traces at the lower verbosity level either way).
# If 'show_diff' is true and the whole files differ, also launches the configured (or default) visual diff tool via
# '$diff_command' against the global 'LOCAL'/'REMOTE' variables, which this function sets before evaluating it.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string SoT (source of truth) file path; assigned to the global 'LOCAL' for '$diff_command' to use
# @arg $2 string target file path; assigned to the global 'REMOTE' for '$diff_command' to use
# @arg $3 bool _show_in_diff_tool whether to also display the visual diff when the files differ
# @arg $4 bool _has_shared whether the files contain well-formed shared-block markers
#
# @exitcode negative=1: the files are identical
# @exitcode positive=0: the files differ, and either file lacks a well-formed shared-block marker pair
# @exitcode $shared_equal=2: the files differ, but their shared blocks (between the markers) are identical
# @exitcode $shared_not_equal=3: the files differ, and their shared blocks also differ
#
# @example
#   are_different "$source_file" "$target_file" false true
#---------------------------------------------------------------------------------------------
function are_different()
{
    (( $# == 4 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires four arguments (provided $#):" \
                                                                       "  - the SoT file" \
                                                                       "  - the target file" \
                                                                       "  - the display-diff flag." \
                                                                       "  - the warning if no shared-block markers flag."
    [[ ! -v 1 || -s $1 ]]           || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the SoT file, to be an existing, non-empty file (provided '${1:-<none>}')."
    [[ ! -v 2 || -s $2 ]]           || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 2, the target file, to be an existing, non-empty file (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_boolean "$3" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 3, the display-diff flag, to be 'true' or 'false' (provided '${4:-<none>}')."
    [[ ! -v 4 ]] || is_boolean "$4" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 4, the warn if shared-block markers are missing or malformed flag, to be 'true' or 'false' (provided '${4:-<none>}')."

    exit_if_has_bugs

    # follow the git diff command parameters naming convention, so the eval command can use them correctly
    LOCAL=$1
    REMOTE=$2

    local _show_in_diff_tool=$3
    local _has_shared=$4

    # compare fast, return fast, if no significant diffs; otherwise continue with the fancy diff tool of choice
    if diff -q -w -B "$LOCAL" "$REMOTE" > "$_ignore"; then
        trace_files "identical" "$LOCAL" "$REMOTE"
        (( ++summary_identical_count ))
        return "$negative" # NOT different!
    fi

    trace_files "different" "$LOCAL" "$REMOTE"
    $_show_in_diff_tool && eval "$diff_command"

    local _source_shared _target_shared

    if $_has_shared && get_shared_block "$LOCAL" _source_shared && get_shared_block "$REMOTE" _target_shared; then
        local _source_shared_file _target_shared_file
        _source_shared_file=$(mktemp)
        _target_shared_file=$(mktemp)
        printf '%s\n' "$_source_shared" > "$_source_shared_file"
        printf '%s\n' "$_target_shared" > "$_target_shared_file"

        local -i _shared_rc
        if diff -q -w -B "$_source_shared_file" "$_target_shared_file" > "$_ignore"; then
            _shared_rc=$shared_equal
            (( ++summary_shared_identical_count ))
        else
            _shared_rc=$shared_not_equal
            (( ++summary_shared_diff_count ))
        fi

        rm -f "$_source_shared_file" "$_target_shared_file"
        return "$_shared_rc"
    else
        (( ++summary_diff_count ))
    fi

    declare warning_message="Could not find a single, well-formed shared-content marker pair ('$shared_begin_marker' / '$shared_end_marker') in '$LOCAL' and/or '$REMOTE' -- falling back to the whole-file result."

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    $_has_shared && warning "$warning_message"

    return "$positive"
}

#---------------------------------------------------------------------------------------------
# @description Runs the configured (or default) merge tool via '$merge_command' to merge the SoT file into the target
# file in place. Follows the Git merge parameter naming convention ('LOCAL', 'REMOTE', 'MERGED', 'BASE') so that
# '$merge_command' can reference these globals. Detects whether the merge actually changed the target file by comparing
# a SHA-256 hash of the target file before and after running the tool.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string SoT (source of truth) file path; assigned to the globals 'REMOTE' and 'BASE'
# @arg $2 string target file path; assigned to the globals 'LOCAL' and 'MERGED' (the file the merge tool is expected to
#   modify in place)
#
# @exitcode success=0: the target file's content changed as a result of the merge
# @exitcode failure=1: the target file's content is unchanged after the merge tool ran
#
# @example
#   merge "$source_file" "$target_file"
#---------------------------------------------------------------------------------------------
function merge()
{
    (( $# == 2 ))       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                            "  - the SoT file" \
                                                            "  - the target file"
    [[ -v 1 && -f $1 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the SoT file, to be an existing file (provided '${1:-<none>}')."
    [[ -v 2 && -f $2 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 2, the target file, to be an existing file (provided '${2:-<none>}')."

    exit_if_has_bugs

    # follow the git merge command parameters naming convention, so the eval command can use them correctly
    LOCAL=$2
    REMOTE=$1
    MERGED=$2
    # BASE=$1 not used for now...

    before=$(sha256sum "$LOCAL")
    execute eval "$merge_command"
    after=$(sha256sum "$MERGED")

    # shellcheck disable=SC2015 # Suppress warnings about using '&&' and '||' for control flow instead of 'if' statements
    [[ "$before" == "$after" ]] && {
        trace_files "not_changed" "$REMOTE" "$LOCAL"
        (( ++summary_not_merged_count ))
        return "$failure"
    } || {
        trace_files "merged" "$REMOTE" "$LOCAL"
        (( ++summary_merged_count ))
        return "$success"
    }
}

#---------------------------------------------------------------------------------------------
# @description Copies the source file over the destination file, creating the destination directory first if it does
# not already exist. Both the directory creation and the copy go through 'execute', so they are skipped (and only
# printed) in dry-run mode.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string source file path to copy from
# @arg $2 string destination file path to copy to
#
# @exitcode success=0: the copy (or dry-run print) succeeded
#
# @example
#   copy_file "$source_file" "$target_file"
#---------------------------------------------------------------------------------------------
function copy_file()
{
    (( $# == 2 ))       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                            "  - the source file path" \
                                                            "  - destination file path."
    [[ -v 1 && -f $1 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the source file, to be an existing file (provided '${1:-<none>}')."
    [[ -v 2 && -n $2 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the destination file path, to be non-empty (provided '${2:-<none>}')."

    exit_if_has_bugs

    local _src_file="$1"
    local _dest_file="$2"
    local _dest_dir

    _dest_dir=$(dirname "$_dest_file")

    if [[ ! -d "$_dest_dir" ]]; then
        execute mkdir -p "$_dest_dir"
    fi
    execute cp "$_src_file" "$_dest_file"
    trace_files "copied" "$_src_file" "$_dest_file"
    (( ++summary_copied_count ))
}

#---------------------------------------------------------------------------------------------
# @description Splices the SoT file's shared block (the content between '$shared_begin_marker' and
# '$shared_end_marker') into the target file, replacing the target's own shared block in place while leaving
# everything before and after it untouched. Goes through 'execute', so it is skipped (and only printed) in
# dry-run mode.
#
# Notes:
#   - Callers MUST have already confirmed (e.g. via 'are_different()' returning '$shared_not_equal') that both
#     files have exactly one well-formed marker pair; at that point a missing/malformed marker is a caller
#     contract violation, not an expected runtime outcome, so this function bug-exits instead of degrading.
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string SoT (source of truth) file path to copy the shared block from
# @arg $2 string target file path to splice the shared block into, in place
#
# @exitcode success=0: the splice (or dry-run print) succeeded
#
# @example
#   copy_shared_block "$source_file" "$target_file"
#---------------------------------------------------------------------------------------------
function copy_shared_block()
{
    (( $# == 2 ))       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                            "  - the SoT file to copy the shared block from" \
                                                            "  - the target file to splice the shared block into"
    [[ -v 1 && -f $1 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the SoT file, to be an existing file (provided '${1:-<none>}')."
    [[ -v 2 && -f $2 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 2, the target file, to be an existing file (provided '${2:-<none>}')."

    exit_if_has_bugs

    local _src_file="$1"
    local _dest_file="$2"
    local _shared_content
    local -i _dest_begin_line _dest_end_line

    get_shared_block "$_src_file" _shared_content ||
        bug -ec "$err_logic_error" "${FUNCNAME[0]}() requires the SoT file '$_src_file' to already have a single, well-formed shared-content marker pair (the caller is expected to have checked this via are_different())."
    __find_shared_markers "$_dest_file" _dest_begin_line _dest_end_line ||
        bug -ec "$err_logic_error" "${FUNCNAME[0]}() requires the target file '$_dest_file' to already have a single, well-formed shared-content marker pair (the caller is expected to have checked this via are_different())."

    exit_if_has_bugs

    local _tmp_file
    _tmp_file=$(mktemp)

    {
        sed -n "1,${_dest_begin_line}p" "$_dest_file"
        printf '%s\n' "$_shared_content"
        sed -n "${_dest_end_line},\$p" "$_dest_file"
    } > "$_tmp_file"

    execute cp "$_tmp_file" "$_dest_file"
    rm -f "$_tmp_file"

    trace_files "copied" "$_src_file" "$_dest_file"
    (( ++summary_shared_copied_count ))
}
