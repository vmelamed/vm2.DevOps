# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# vm2 core error codes
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_not_directory

# vm2 core constants
declare -xr reset
declare -xr red
declare -xr green
declare -xr yellow
declare -xr blue

# this script variables
declare -x diff_only
declare -x summary_file

# Summary variables:
# Found in state:
declare -xi summary_identical_count=0
declare -xi summary_diff_count=0
declare -xi summary_ignore_count=0

declare -xi summary_shared_identical_count=0
declare -xi summary_shared_diff_count=0
declare -xi summary_shared_ignore_count=0

# Actions taken:
declare -xi summary_skipped_count=0
declare -xi summary_not_merged_count=0
declare -xi summary_merged_count=0
declare -xi summary_copied_count=0

declare -xi summary_shared_skipped_count=0
declare -xi summary_shared_copied_count=0

function add_summary_header()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the path to the target directory." -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "${FUNCNAME[0]}() requires the argument to be the path to the target directory (provided $#)." -ec "$err_not_directory"
                                                                                exit_if_has_bugs

    local target_path="$1"
    local target=${target_path#"$vm2_repos/"}
    local target=${target_path%%/*}

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    $diff_only && {
        echo -e "### Target Repository: $target ($target_path)\n"
        echo -e "| Source Path | Target Path | Filename | Default: | Difference | To do: |"
        echo -e "|:------------|:------------|:---------|:---------|:-----------|:-------|"
    } >> "$summary_file" || {
        echo -e "### Target Repository: $target ($target_path)\n"
        echo -e "| Source Path | Target Path | Filename | Default: | Difference | Done:  |"
        echo -e "|:------------|:------------|:---------|:---------|:-----------|:-------|"
    } >> "$summary_file"

    info "Target repository '$target' ($target_path)..."

    target_dump_vars=(
        --quiet
        --header "Configuration for Target '$target':"
        diff_tool
        diff_command
        merge_tool
        merge_command
        --header "Data Model:"
        source_files
        target_files
        file_actions
    )

    dump_vars "${target_dump_vars[@]}"
}

function add_summary_line()
{
    (( $# == 5 ))                                                               || bug "${FUNCNAME[0]}() requires five arguments (provided $#):" \
                                                                                       "  - the source file" \
                                                                                       "  - the target file" \
                                                                                       "  - the actions associated with the file" \
                                                                                       "  - the differences" \
                                                                                       "  - the action taken" \
                                                                                       -ec "$err_invalid_arguments"

    local source_file="$1"
    local target_file="$2"
    local actions="$3"
    local difference="$4"
    local action="$5"

    filename="$(basename "$source_file")"

    rel_source_path="$(dirname "$source_file")"
    rel_source_file="${rel_source_path#"$vm2_repos/"}"

    rel_target_path="$(dirname "$target_file")"
    rel_target_file="${rel_target_path#"$vm2_repos/"}"

    echo "| $rel_source_file | $rel_target_file | $filename | $actions | $difference | $action |" >> "$summary_file"
}

#-------------------------------------------------------------------------------------------
# @description Traces the status of files (identical, different, etc.) with color-coded output.
#
# @arg $1 string status of the file (identical, different, etc.)
#
# @arg $2 string path to the file
#
# @arg $3 string additional information (optional)
#
# @exitcode 0: the status was successfully traced.
#-----------------------------------------------------------------------------------------------
function trace_files()
{
    local _format
    case "${1,,}" in
        identical )
            _format="%-84s ${clr_green}==== Identical ====${clr_reset} %-s\n"
            ;;
        different )
            _format="%-84s ${clr_red}≠≠≠≠ Different ≠≠≠≠${clr_reset} %-s\n"
            ;;
        not_changed )
            _format="%-84s ${clr_yellow}→←→← No change →←→←${clr_reset} %-s\n"
            ;;
        merged )
            _format="%-84s ${clr_blue}→←→← Merged    →←→←${clr_reset} %-s\n"
            ;;
        copied )
            _format="%-84s ${clr_green}→→→→ Copied    →→→→${clr_reset} %-s\n"
            ;;
        skipped )
            _format="%-84s ${clr_yellow}---- Skipping  ----${clr_reset} %-s\n"
            ;;
        * )
            _format="%-84s ??????????????????? %-s\n"
    esac
    # shellcheck disable=SC2059 # Suppress warnings about printf format strings being non-literal
    trace "$(printf "$_format" "${2#"$vm2_repos/$vm2_sot_repo_name/templates/"}" "${3#"$vm2_repos/"}")"
}

function summarize()
{
    declare -a args=(
        --force
        --quiet
        --markdown
        --header "Summary:"
        --header "  Found:"
        --name "Identical"        summary_identical_count
        --name "Different"        summary_diff_count
        --name "Ignored"          summary_ignore_count
        --blank
        --name "Shared Identical" summary_shared_identical_count
        --name "Shared Different" summary_shared_diff_count
        --header "  Actions:"
        --name "Skipped"          summary_skipped_count
        --name "Not Merged"       summary_not_merged_count
        --name "Merged"           summary_merged_count
        --name "Copied"           summary_copied_count
        --blank
        --name "Shared Skipped"   summary_shared_skipped_count
        --name "Shared Copied"    summary_shared_copied_count
        --name "Shared Ignored"   summary_shared_ignore_count
    )
    dump_vars "${args[@]}" >> "$summary_file"

    # shellcheck disable=SC2015 # A && B || C is not if-then-else. C may run when A is true but B is false.
    is_tool_present glow &&
        glow "$summary_file" -w 180 ||
        cat "$summary_file"
}
