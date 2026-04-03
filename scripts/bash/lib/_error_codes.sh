# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines standard error codes used by vm2 scripts.
# Return codes 0 and 1 are used for success and general failure, respectively.
# Other return codes are used for specific argument errors but the error codes can also be reused by some modules for other purposes.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_ERROR_CODES_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_ERROR_CODES_SH_LOADED=1

# RETURN CODES THAT MUST NOT BE REUSED FOR OTHER PURPOSES:
declare -rxi success=0   # The command completed successfully.
declare -rxi failure=1   # A general, unspecified error occurred.
# alternatively as boolean return codes:
declare -rxi positive=0
declare -rxi negative=1

# RETURN CODES THAT SHOULD NOT BE REUSED FOR OTHER PURPOSES:
declare -rxi err_invalid_arguments=2    # The number of the arguments is invalid or more than one type of parameter error code is present
declare -rxi err_argument_type=3        # An argument is of the wrong type (types: string, integer, boolean, array, associative array, etc.)
declare -rxi err_argument_value=4       # An argument has an invalid value (out of range, not in allowed set. E.g. expected non-negative integer but got negative value)
declare -rxi err_invalid_nameref=5      # An argument has an invalid nameref (e.g., expected a valid variable name reference but got an invalid one)
declare -rxi err_missing_argument=6     # A required argument is missing
declare -rxi err_too_many_arguments=7   # More than one argument was provided when only one is allowed
declare -rxi err_unknown_argument=8     # An unknown argument was provided
declare -rxi err_not_found=9            # Could not find an item matching the criteria
declare -rxi err_found_too_many=10      # Found too many items matching the criteria

declare -rxi err_not_file=16            # Parameter value is not a file
declare -rxi err_not_directory=17       # Parameter value is not a directory

declare -rxi err_not_overridden=64      # A function that should be overridden in the calling script (e.g. usage_text()) was not overridden

declare -rxi err_not_git_directory=80   # The specified directory is not a directory from a Git repository working tree
declare -rxi err_not_git_root=81        # The specified directory is not a root directory of a Git repository working tree
declare -rxi err_behind_latest_stable_tag=82 # The repository is behind the latest stable tag
declare -rxi err_invalid_repo=83        # The specified repository is not valid
declare -rxi err_invalid_branch=84      # The specified directory is not on the expected branch
declare -rxi err_repo_with_no_ci=85     # The specified repository root does not have a CI configuration in repo/.github/workflows
declare -rxi err_dir_with_ci=86         # The specified directory is not a root directory but has a CI configuration
declare -rxi err_dir_with_no_ci=87      # The specified directory does not have a CI configuration in dir/.github/workflows (and  is not from a git repository)

declare -rxA error_codes=(
    [$success]="The command completed successfully."
    [$failure]="A general, unspecified error occurred."

    [$err_invalid_arguments]="The number of arguments is invalid or more than one type of parameter error code is present."
    [$err_argument_type]="An argument is of the wrong type (types: string, integer, boolean, array, associative array, etc.)."
    [$err_argument_value]="An argument has an invalid value (out of range, not in allowed set. E.g. expected non-negative integer but got negative value)."
    [$err_invalid_nameref]="An argument has an invalid nameref (e.g., expected a valid variable name reference but got an invalid one)."
    [$err_missing_argument]="A required argument is missing."
    [$err_too_many_arguments]="More than one argument was provided when only one is allowed."
    [$err_unknown_argument]="An unknown argument was provided."
    [$err_not_found]="Could not find an item matching the criteria."
    [$err_found_too_many]="Found too many items matching the criteria."

    [$err_not_file]="Parameter value is not a file."
    [$err_not_directory]="Parameter value is not a directory."

    [$err_not_overridden]="A function that should be overridden in the calling script (e.g. usage_text()) was not overridden."

    [$err_not_git_directory]="The specified directory is not a directory from a Git repository working tree."
    [$err_not_git_root]="The specified directory is not a root directory of a Git repository working tree."
    [$err_behind_latest_stable_tag]="The repository is behind the latest stable tag."
    [$err_invalid_repo]="The specified repository is not valid."
    [$err_invalid_branch]="The specified directory is not on the expected branch."
    [$err_repo_with_no_ci]="The specified repository root does not have a CI configuration in repo/.github/workflows."
    [$err_dir_with_ci]="The specified directory is not a root directory but has a CI configuration."
    [$err_dir_with_no_ci]="The specified directory does not have a CI configuration in dir/.github/workflows (and  is not from a git repository)."
)

function error_message()
{
    (( $# == 1 )) || {
        echo "error_message() requires exactly 1 argument: an error code." >&2
        return "$err_invalid_arguments"
    }
    is_non_negative "$1" || {
        echo "error_message() argument must be a non-negative integer error code." >&2
        return "$err_argument_type"
    }

    local -i code="$1"

    [[ -v error_codes[$code] ]] && echo "$code: ${error_codes[$code]}" || echo "Unknown error code: $code"
}
