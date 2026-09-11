# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#---------------------------------------------------------------------------------------------
# This script defines standard error codes used by vm2 scripts.
# Return codes 0 and 1 are used for success and general failure, respectively.
# Other return codes are used for specific argument errors but the error codes can also be reused by some modules for other purposes.
#---------------------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_ERROR_CODES_SH_LOADED:-0} == 1 )) && return 0
declare -xri __VM2_LIB_ERROR_CODES_SH_LOADED=1

declare -x bug_prefix

# RETURN CODES THAT MUST NOT BE REUSED FOR OTHER PURPOSES:
declare -xri success=0                  # The command completed successfully.
declare -xri failure=1                  # A general, unspecified error occurred.

# alternatively as boolean return codes:
declare -xri positive=0                 # Boolean return codes (truthy), you cannot use `return true` in bash but you can `return $positive`;
declare -xri negative=1                 # Boolean return codes (falsy), you cannot use `return false` in bash but you can `return $negative`;

declare -xri eof=1                      # Alias for failure: end-of-file is encountered  (e.g., when using the read command)

# RETURN CODES THAT SHOULD NOT BE REUSED FOR OTHER PURPOSES:
declare -xri err_invalid_arguments=2    # The number of the arguments is invalid or the validation of one or more parameters failed
declare -xri err_argument_type=3        # An argument is of the wrong type (integer, boolean, indexed or associative array, etc.)
declare -xri err_argument_value=4       # An argument has an invalid value (out of range, not in allowed set, e.g., expected non-negative integer but got negative value)
declare -xri err_invalid_nameref=5      # An argument is not a valid name of a variable
declare -xri err_missing_argument=6     # A required argument is missing
declare -xri err_too_many_arguments=7   # More arguments were provided than the function accepts
declare -xri err_unknown_argument=8     # An unknown argument was provided
declare -xri err_not_found=9            # Could not find an item matching the criteria
declare -xri err_found_too_many=10      # Found too many items matching the criteria
declare -xri err_unsafe_argument=11     # An argument value is unsafe to use (e.g., a file path that could lead to directory traversal, a string that could lead to command injection, etc.)
declare -xri err_invalid_json=12        # The argument is not a valid JSON.
declare -xri err_invalid_json_array=13  # The argument is not a valid JSON array.
declare -xri err_invalid_item=14        # An item in a collection (e.g. JSON array) is not valid.

declare -xri err_not_file=16            # Parameter value is not a file
declare -xri err_not_directory=17       # Parameter value is not a directory
declare -xri err_invalid_path=18        # Parameter value is not a valid path (e.g., contains invalid characters, is too long, etc.)
declare -xri err_non_existent_path=19   # Parameter value is a path that does not exist

declare -xri err_not_overridden=64      # A function that should be overridden in the calling script (e.g. usage_text()) was not overridden
declare -xri err_tool_not_found=65      # An external tool (e.g., jq, dotnet, etc.) that the script depends on was not found in the system
declare -xri err_tool_error=66          # An error occurred while executing an external tool (e.g., git, dotnet, etc.).
declare -xri err_logic_error=67         # An error occurred in the logic of the script (most likely a bug, invalid state, unexpected condition, etc.)

declare -xri err_not_git_directory=80   # The specified directory is not a directory from a Git repository working tree
declare -xri err_not_git_root=81        # The specified directory is not a root directory of a Git repository working tree
declare -xri err_behind_latest_stable_tag=82 # The current commit of the current branch of the repository is behind the latest stable tag
declare -xri err_invalid_repo=83        # The specified repository is not valid
declare -xri err_invalid_branch=84      # The specified directory is not on the expected branch
declare -xri err_repo_with_no_ci=85     # The specified repository root does not have a CI configuration in repo/.github/workflows
declare -xri err_dir_with_ci=86         # The specified directory is not a root directory but has a CI configuration
declare -xri err_dir_with_no_ci=87      # The specified directory does not have a CI configuration in dir/.github/workflows (and is not in a Git repository)
declare -xri err_not_repos_parent=88    # The specified vm2_repos directory is not the parent directory of the vm2 repositories. Please, ensure that the vm2 repositories are cloned into this directory or correct the parameter/environment variable.
declare -xri err_not_current_commit=89  # The specified repository is not on the current commit of the expected branch

declare -xri time_out=128               # The command timed out (e.g., when using the read command)

declare -xri err_has_errors=253         # There are errors recorded in the global error counter.
declare -xri err_has_bugs=254           # There are bugs recorded in the global bug counter. Please, fix the problems above and try again. Exiting the script immediately...

declare -xri err_unknown=255            # An unknown error occurred

declare -rA __error_messages=(
    [$success]="The command completed successfully or positive outcome - 'true'."
    [$failure]="A general, unspecified error occurred or negative outcome - 'false', or reached end of file."

    [$err_invalid_arguments]="The number of the arguments is invalid or more than one type of parameter error code is present."
    [$err_argument_type]="The argument is of the wrong type (types: string, integer, boolean, array, associative array, etc.)."
    [$err_argument_value]="The argument has an invalid value."
    [$err_invalid_nameref]="The argument is not a valid name of a variable."
    [$err_missing_argument]="A required argument is missing."
    [$err_too_many_arguments]="More than one argument was provided when only one is allowed."
    [$err_unknown_argument]="An unknown argument was provided."
    [$err_not_found]="Could not find an item matching the criteria."
    [$err_found_too_many]="Found too many items matching the criteria."
    [$err_unsafe_argument]="An argument value is unsafe to use (e.g., a file path that could lead to directory traversal, a string that could lead to command injection, etc.)"
    [$err_invalid_json]="The argument is not a valid JSON."
    [$err_invalid_json_array]="The argument is not a valid JSON array."
    [$err_invalid_item]="An item in a collection (e.g. JSON array) is not valid."

    [$err_not_file]="Parameter value is not a file."
    [$err_not_directory]="Parameter value is not a directory."
    [$err_invalid_path]="Parameter value is not a valid path (e.g., contains invalid characters, is too long, etc.)"
    [$err_non_existent_path]="Parameter value is a path that does not exist."

    [$err_not_overridden]="A function that should be overridden in the calling script (e.g. usage_text()) was not overridden."
    [$err_tool_not_found]="An external tool that the script depends on was not found in the system."
    [$err_tool_error]="An error occurred while executing an external tool (e.g., git, dotnet, etc.)."
    [$err_logic_error]="An error occurred in the logic of the script (e.g., bug, invalid state, unexpected condition, etc.)"

    [$err_not_git_directory]="The specified directory is not in a Git working tree."
    [$err_not_git_root]="The specified directory is not the root directory of a Git working tree."
    [$err_behind_latest_stable_tag]="The repository is behind the latest stable tag."
    [$err_invalid_repo]="The specified repository is not valid."
    [$err_invalid_branch]="The specified directory is not on the expected branch."
    [$err_repo_with_no_ci]="The specified repository root does not have a CI configuration in repo/.github/workflows."
    [$err_dir_with_ci]="The specified directory is not a root directory but has a CI configuration."
    [$err_dir_with_no_ci]="The specified directory does not have a CI configuration in dir/.github/workflows (and is not in a Git repository)."
    [$err_not_repos_parent]="The specified \$vm2_repos directory is not the parent directory for the vm2 repositories. Please ensure that the vm2 repositories are cloned into this directory or correct the parameter/environment variable."
    [$err_not_current_commit]="The specified repository is not on the current commit of the expected branch."

    [$time_out]="The command timed out."

    ["$err_has_errors"]="There are errors recorded in the global error counter."
    ["$err_has_bugs"]="There are bugs recorded in the global bug counter. Please, fix the problems above and try again. Exiting the script immediately..."
    [$err_unknown]="An unknown error occurred."
)

declare -rA __error_names=(
    [$success]="\$success/\$positive"
    [$failure]="\$failure/\$negative"

    [$err_invalid_arguments]="\$err_invalid_arguments"
    [$err_argument_type]="\$err_argument_type"
    [$err_argument_value]="\$err_argument_value"
    [$err_invalid_nameref]="\$err_invalid_nameref"
    [$err_missing_argument]="\$err_missing_argument"
    [$err_too_many_arguments]="\$err_too_many_arguments"
    [$err_unknown_argument]="\$err_unknown_argument"
    [$err_not_found]="\$err_not_found"
    [$err_found_too_many]="\$err_found_too_many"
    [$err_unsafe_argument]="\$err_unsafe_argument"
    [$err_invalid_json]="\$err_invalid_json"
    [$err_invalid_json_array]="\$err_invalid_json_array"
    [$err_invalid_item]="\$err_invalid_item"

    [$err_not_file]="\$err_not_file"
    [$err_not_directory]="\$err_not_directory"
    [$err_invalid_path]="\$err_invalid_path"
    [$err_non_existent_path]="\$err_non_existent_path"

    [$err_not_overridden]="\$err_not_overridden"
    [$err_tool_not_found]="\$err_tool_not_found"
    [$err_tool_error]="\$err_tool_error"
    [$err_logic_error]="\$err_logic_error"

    [$err_not_git_directory]="\$err_not_git_directory"
    [$err_not_git_root]="\$err_not_git_root"
    [$err_behind_latest_stable_tag]="\$err_behind_latest_stable_tag"
    [$err_invalid_repo]="\$err_invalid_repo"
    [$err_invalid_branch]="\$err_invalid_branch"
    [$err_repo_with_no_ci]="\$err_repo_with_no_ci"
    [$err_dir_with_ci]="\$err_dir_with_ci"
    [$err_dir_with_no_ci]="\$err_dir_with_no_ci"
    [$err_not_repos_parent]="\$err_not_repos_parent"
    [$err_not_current_commit]="\$err_not_current_commit"

    [$time_out]="\$time_out"

    [$err_has_errors]="\$err_has_errors"
    [$err_has_bugs]="\$err_has_bugs"
    [$err_unknown]="\$err_unknown"
)

#---------------------------------------------------------------------------------------------
# @description Looks up an error code in the `_error_messages` associative array and prints
# "<code>: <message>" to stdout.
#
# @arg $1 int Error code (0-255) to look up.
#
# @stdout an error message string with format: "<code>: <message>" for the given error code.
#
# @example
#   error_message "$err_not_found"
#---------------------------------------------------------------------------------------------
function error_message()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires exactly 1 argument: an error code (provided: $#).\n" "$bug_prefix"
        show_stack 2 4 true
    }
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ ! -v 1 ]] || is_non_negative "$1" || {
        _rc="$err_argument_type"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires argument 1 to be an error code (0..255) (provided '${1:-<none>}')." "$bug_prefix"
        show_stack 2 4 true
    }

    (( _rc == success )) || exit "$_rc"

    [[ -v __error_messages[$1] ]] &&
        echo "$1: ${__error_messages[$1]}" ||
        echo "$1: ${__error_messages[$err_unknown]}"
}

#---------------------------------------------------------------------------------------------
# @description Prints the corresponding error name. Looks up the error code in the
# `_error_names` associative array.
#
# @arg $1 int Error code (0-255) to look up.
#
# @stdout "<name>" for the given error code.
#
# @example
#   error_name "$err_not_found"
#---------------------------------------------------------------------------------------------
function error_name()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires exactly 1 argument: an error code (provided: $#).\n" "$bug_prefix"
        show_stack 2 4 true
    }
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ ! -v 1 ]] || is_non_negative "$1" || {
        _rc="$err_argument_type"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires argument 1 to be an error code (0..255) (provided '${1:-<none>}')." "$bug_prefix"
        show_stack 2 4 true
    }

    (( _rc == success )) || exit "$_rc"

    [[ -v __error_names[$1] ]] &&
        echo "${__error_names[$1]}" ||
        echo err_unknown
}
