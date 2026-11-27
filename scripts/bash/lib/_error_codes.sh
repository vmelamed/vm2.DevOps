# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-----------------------------------------------------------------------------------------------
# This script defines standard error codes used by vm2 scripts.
# Return codes 0 and 1 are used for success and general failure, respectively.
# Other return codes are used for specific argument errors but the error codes can also be reused by some modules for other purposes.
#-----------------------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_ERROR_CODES_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_ERROR_CODES_SH_LOADED=1

#===============================================================================================
# vm2 core lib exit codes: returned exit codes by the functions and scripts in the vm2 ecosystem.
#===============================================================================================

# RETURN CODES THAT ARE REUSED FOR OTHER PURPOSES:
declare -xri success=0                              # The command succeeded (as a predicate: true).
declare -xri failure=1                              # The command failed with an unspecified error (as a predicate: false; or the input ended).

# alternatively as boolean return codes:
declare -xri positive=0                             # Boolean return codes (truthy), you cannot use `return true` in bash but you can `return $positive`;
declare -xri negative=1                             # Boolean return codes (falsy), you cannot use `return false` in bash but you can `return $negative`;

declare -xri eof=1                                  # Alias for failure: end-of-file is encountered  (e.g., when using the read command)

# or comparison result constants
declare -xri rc_equal=0                             # akin to 0 in signed integer comparison
declare -xri rc_greater_than=1                      # akin to 1 in signed integer comparison
declare -xri rc_less_than=255                       # akin to -1 in signed integer comparison

# RETURN CODES THAT MUST NOT BE REUSED FOR OTHER PURPOSES:
declare -xri err_invalid_arguments=2                # The arguments are invalid: the wrong number of arguments, or values that failed validation.
declare -xri err_argument_type=3                    # An argument has the wrong type.
declare -xri err_argument_value=4                   # An argument has an invalid value.
declare -xri err_invalid_nameref=5                  # An argument is not a valid variable name.
declare -xri err_missing_argument=6                 # A required argument is missing.
declare -xri err_too_many_arguments=7               # There are more arguments than allowed.
declare -xri err_unknown_argument=8                 # An argument is not recognized.
declare -xri err_not_found=9                        # No item matches the criteria.
declare -xri err_found_too_many=10                  # Too many items match the criteria.
declare -xri err_unsafe_argument=11                 # An argument is unsafe to use.
declare -xri err_invalid_json=12                    # An argument is not valid JSON.
declare -xri err_invalid_json_array=13              # An argument is not a valid JSON array.
declare -xri err_invalid_item=14                    # An item of a collection is invalid.

declare -xri err_not_file=16                        # An argument is not a file.
declare -xri err_not_directory=17                   # An argument is not a directory.
declare -xri err_invalid_file=18                    # An argument is not a valid file or directory name.
declare -xri err_invalid_path=19                    # An argument is not a valid path.
declare -xri err_non_existent_path=20               # An argument is a path that does not exist.
declare -xri err_io_failure=21                      # An I/O operation failed.

declare -xri err_not_overridden=64                  # A function that the calling script must override is not overridden.
declare -xri err_tool_not_found=65                  # A required external tool is not installed.
declare -xri err_tool_error=66                      # An external tool failed.
declare -xri err_tool_unauthenticated=67            # An external tool is not authenticated.
declare -xri err_logic_error=68                     # The script reached an invalid state: a bug or an unexpected condition.
declare -xri err_tool_version=69                    # An external tool's version is not supported.
declare -xri err_access_denied=70                   # Access to a resource was denied.

declare -xri err_not_git_directory=80               # The directory is not in a Git working tree.
declare -xri err_not_git_root=81                    # The directory is not the root of a Git working tree.
declare -xri err_behind_latest_stable_tag=82        # The repository is behind the tag of the latest stable release.
declare -xri err_invalid_repo=83                    # The repository is not valid.
declare -xri err_invalid_branch=84                  # The repository is not on the expected branch.
declare -xri err_repo_with_no_ci=85                 # The repository has no CI configuration (.github/workflows).
declare -xri err_dir_with_ci=86                     # The directory is not in a Git repository yet, but it has a CI configuration (.github/workflows).
declare -xri err_dir_with_no_ci=87                  # The directory is not in a Git repository and has no CI configuration (.github/workflows).
declare -xri err_root_not_repo_name=90              # The repository's directory name is not its GitHub repository name.
declare -xri err_repo_not_in_vm2_repos=91           # The repository is not in the vm2 repositories directory.
declare -xri err_invalid_repo_name=92               # The specified string is not a valid repository name.
declare -xri err_invalid_branch_name=93             # The specified string is not a valid branch name.
declare -xri err_invalid_tag=94                     # The specified string is not a valid tag.
declare -xri err_invalid_sha=95                     # The specified string is not a valid commit SHA.
declare -xri err_no_stable_tag=96                   # The repository does not have a tag that marks a stable release.
declare -xri err_not_after_latest_stable_tag=97     # The repository is not after the tag of the latest stable release.

declare -xri time_out=128                           # The command timed out.

declare -xri err_unknown=250                        # An unknown error occurred.

declare -xri err_unexpected_error=252               # An unexpected error occurred.
declare -xri err_has_errors=253                     # Errors were reported above.
declare -xri err_has_bugs=254                       # Bugs (violations of a function's calling contract) were reported above.

# vm2 core lib constants
declare -x bug_prefix

declare -rA __error_messages=(
    [$success]="The command succeeded (as a predicate: true)."
    [$failure]="The command failed with an unspecified error (as a predicate: false; or the input ended)."

    [$err_invalid_arguments]="The arguments are invalid: the wrong number of arguments, or values that failed validation."
    [$err_argument_type]="An argument has the wrong type."
    [$err_argument_value]="An argument has an invalid value."
    [$err_invalid_nameref]="An argument is not a valid variable name."
    [$err_missing_argument]="A required argument is missing."
    [$err_too_many_arguments]="There are more arguments than allowed."
    [$err_unknown_argument]="An argument is not recognized."
    [$err_not_found]="No item matches the criteria."
    [$err_found_too_many]="Too many items match the criteria."
    [$err_unsafe_argument]="An argument is unsafe to use."
    [$err_invalid_json]="An argument is not valid JSON."
    [$err_invalid_json_array]="An argument is not a valid JSON array."
    [$err_invalid_item]="An item of a collection is invalid."

    [$err_not_file]="An argument is not a file."
    [$err_not_directory]="An argument is not a directory."
    [$err_invalid_file]="An argument is not a valid file or directory name."
    [$err_invalid_path]="An argument is not a valid path."
    [$err_non_existent_path]="An argument is a path that does not exist."
    [$err_io_failure]="An I/O operation failed."

    [$err_not_overridden]="A function that the calling script must override is not overridden."
    [$err_tool_not_found]="A required external tool is not installed."
    [$err_tool_error]="An external tool failed."
    [$err_tool_unauthenticated]="An external tool is not authenticated."
    [$err_logic_error]="The script reached an invalid state: a bug or an unexpected condition."
    [$err_tool_version]="An external tool's version is not supported."
    [$err_access_denied]="Access to a resource was denied."

    [$err_not_git_directory]="The directory is not in a Git working tree."
    [$err_not_git_root]="The directory is not the root of a Git working tree."
    [$err_behind_latest_stable_tag]="The repository is behind the tag of the latest stable release."
    [$err_invalid_repo]="The repository is not valid."
    [$err_invalid_branch]="The repository is not on the expected branch."
    [$err_repo_with_no_ci]="The repository has no CI configuration (.github/workflows)."
    [$err_dir_with_ci]="The directory is not in a Git repository yet, but it has a CI configuration (.github/workflows)."
    [$err_dir_with_no_ci]="The directory is not in a Git repository and has no CI configuration (.github/workflows)."
    [$err_root_not_repo_name]="The repository's directory name is not its GitHub repository name."
    [$err_repo_not_in_vm2_repos]="The repository is not in the vm2 repositories directory."
    [$err_invalid_repo_name]="The specified string is not a valid repository name."
    [$err_invalid_branch_name]="The specified string is not a valid branch name."
    [$err_invalid_tag]="The specified string is not a valid tag."
    [$err_invalid_sha]="The specified string is not a valid commit SHA."
    [$err_no_stable_tag]="The repository has no tag that marks a stable release."
    [$err_not_after_latest_stable_tag]="The repository is not after the tag of the latest stable release."

    [$time_out]="The command timed out."

    [$err_unknown]="An unknown error occurred."
    [$err_unexpected_error]="An unexpected error occurred."
    [$err_has_errors]="Errors were reported above."
    [$err_has_bugs]="Bugs (violations of a function's calling contract) were reported above."
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
    [$err_invalid_file]="\$err_invalid_file"
    [$err_invalid_path]="\$err_invalid_path"
    [$err_non_existent_path]="\$err_non_existent_path"
    [$err_io_failure]="\$err_io_failure"

    [$err_not_overridden]="\$err_not_overridden"
    [$err_tool_not_found]="\$err_tool_not_found"
    [$err_tool_error]="\$err_tool_error"
    [$err_tool_unauthenticated]="\$err_tool_unauthenticated"
    [$err_logic_error]="\$err_logic_error"
    [$err_tool_version]="\$err_tool_version"
    [$err_access_denied]="\$err_access_denied"

    [$err_not_git_directory]="\$err_not_git_directory"
    [$err_not_git_root]="\$err_not_git_root"
    [$err_behind_latest_stable_tag]="\$err_behind_latest_stable_tag"
    [$err_invalid_repo]="\$err_invalid_repo"
    [$err_invalid_branch]="\$err_invalid_branch"
    [$err_repo_with_no_ci]="\$err_repo_with_no_ci"
    [$err_dir_with_ci]="\$err_dir_with_ci"
    [$err_dir_with_no_ci]="\$err_dir_with_no_ci"
    [$err_root_not_repo_name]="\$err_root_not_repo_name"
    [$err_repo_not_in_vm2_repos]="\$err_repo_not_in_vm2_repos"
    [$err_invalid_repo_name]="\$err_invalid_repo_name"
    [$err_invalid_branch_name]="\$err_invalid_branch_name"
    [$err_invalid_tag]="\$err_invalid_tag"
    [$err_invalid_sha]="\$err_invalid_sha"
    [$err_no_stable_tag]="\$err_no_stable_tag"
    [$err_not_after_latest_stable_tag]="\$err_not_after_latest_stable_tag"

    [$time_out]="\$time_out"

    [$err_unknown]="\$err_unknown"
    [$err_unexpected_error]="\$err_unexpected_error"
    [$err_has_errors]="\$err_has_errors"
    [$err_has_bugs]="\$err_has_bugs"
)

#-----------------------------------------------------------------------------------------------
# @description Looks up an error code in the `_error_messages` associative array and prints
#   "<code>: <message>" to stdout. An unrecognized code falls back to the generic "unknown
#   error" message instead of failing.
#
# Notes:
#   - Deliberately does NOT use `bug`/`exit_if_has_bugs` for its own argument validation, to
#     avoid recursion (this function is itself used to translate error codes for `bug`/`error`
#     messages) -- it prints a bug-style message directly and exits the process immediately.
#
# @arg $1 int Error code (0-255) to look up.
#
# @stdout an error message string with format: "<code>: <message>" for the given error code.
#
# @exitcode success=0: The message was printed (always, once past argument validation).
# @exitcode err_invalid_arguments=2: Never returns -- exits the process immediately if called
#   with other than 1 argument.
# @exitcode err_argument_type=3: Never returns -- exits the process immediately if argument 1
#   is not a non-negative integer.
#
# @example
#   error_message "$err_not_found"
#-----------------------------------------------------------------------------------------------
function error_message()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires 1 argument (provided $#): an error code.\n" "$bug_prefix"
        show_stack 2 4
    }
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ ! -v 1 ]] || is_exit_code "$1" || {
        _rc="$err_argument_type"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires argument 1 to be an error code (0..255) (provided '${1-<missing>}')." "$bug_prefix"
        show_stack 2 4
    }
    (( _rc == success )) || exit "$_rc";

    [[ -v __error_messages[$1] ]] && _rc=$1 || _rc=$err_unknown

    printf "vm2 %s (%d): %s" "${__error_names[$_rc]}" "$1" "${__error_messages[$_rc]}"
}

#-----------------------------------------------------------------------------------------------
# @description Prints the corresponding error name. Looks up the error code in the
# `_error_names` associative array. An unrecognized code prints the literal string
#   "err_unknown" instead of failing.
#
# Notes:
#   - Deliberately does NOT use `bug`/`exit_if_has_bugs` for its own argument validation, to
#     avoid recursion (this function is itself used while translating error codes for
#     `bug`/`error` messages) -- it prints a bug-style message directly and exits the process
#     immediately.
#
# @arg $1 int Error code (0-255) to look up.
#
# @stdout "<name>" for the given error code.
#
# @exitcode success=0: The name was printed (always, once past argument validation).
# @exitcode err_invalid_arguments=2: Never returns -- exits the process immediately if called
#   with other than 1 argument.
# @exitcode err_argument_type=3: Never returns -- exits the process immediately if argument 1
#   is not a non-negative integer.
#
# @example
#   error_name "$err_not_found"
#-----------------------------------------------------------------------------------------------
function error_name()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires 1 argument (provided $#): an error code.\n" "$bug_prefix"
        show_stack 2 4
    }
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ ! -v 1 ]] || is_non_negative "$1" || {
        _rc="$err_argument_type"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires argument 1 to be an error code (0..255) (provided '${1-<missing>}')." "$bug_prefix"
        show_stack 2 4
    }
    (( _rc == success )) || exit "$_rc"

    [[ -v __error_names[$1] ]] && _rc=$1 || _rc=$err_unknown
    printf "%s" "${__error_names[$_rc]}"
}

#-----------------------------------------------------------------------------------------------
# HTTP status codes -> vm2 codes, for the classifiers of `execute_with_retry --classify` (e.g.
# `gh_failure` in `_git.gh.sh`). Only the statuses a caller may want to tell apart have
# a row; any other status maps to $err_tool_error. `0` (`$positive`) means "transient": the
# request may succeed if it is retried.
#-----------------------------------------------------------------------------------------------
declare -rA __http_status_error_codes=(
    [401]=$err_tool_unauthenticated     # Unauthorized: no or bad credentials
    [403]=$err_access_denied            # Forbidden: the credentials lack a scope or a permission
    [404]=$err_not_found                # Not Found (GitHub also answers 404 for a resource the token may not see)
    [425]=0                             # Too Early
    [429]=0                             # Too Many Requests: rate limited
    [500]=0                             # Internal Server Error: on GitHub, mostly a transient hiccup
    [502]=0                             # Bad Gateway
    [503]=0                             # Service Unavailable
    [504]=0                             # Gateway Timeout
)

#-----------------------------------------------------------------------------------------------
# @description Translates an HTTP status code into a vm2 code: a plain table lookup, the
#   mechanism under a classifier's policy.
#
# @arg $1 int The HTTP status code [100, 599].
# @arg $2 string The name of the variable that receives the vm2 code: `0` for a transient
#   failure, the vm2 code of a status with a row in the table, or `$err_tool_error`.
#
# @exitcode success=0: Always, once past the argument validation.
#
# @example
#   http_status_to_error_code 404 code      # code=$err_not_found
#   http_status_to_error_code 503 code      # code=0: transient
#   http_status_to_error_code 422 code      # code=$err_tool_error
#-----------------------------------------------------------------------------------------------
function http_status_to_error_code()
{
    (( $# == 2 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                "  - the HTTP status code" \
                                                                                                                "  - the name of the variable that receives the vm2 code"
    [[ ! -v 1 || $1 =~ ^[1-5][0-9]{2}$ ]]                                       || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be an HTTP status code [100, 599] (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || is_variable "$2"                                            || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to be the name of a declared variable (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    local -n __http_error_code=$2
    __http_error_code=${__http_status_error_codes[$1]:-$err_tool_error}
}
