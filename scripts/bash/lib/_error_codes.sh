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
declare -rxi success=0   # The command completed successfully. When tested as boolean returns the same as the command 'true' all other return codes are considered failures.
declare -rxi failure=1   # A general, unspecified error occurred. vm2 scripts return this code also as 'false' when the command is usually tested as boolean, e.g. in 'if' statements: 'if ! is_boolean $2; then ...'
# boolean return codes:
declare -rxi positive=0
declare -rxi negative=1

# RETURN CODES THAT SHOULD NOT BE REUSED FOR OTHER PURPOSES:
declare -rxi err_invalid_arguments=2    # the number of the arguments is invalid or more than one type of parameter error code is present
declare -rxi err_argument_type=3        # an argument is of the wrong type (types: string, integer, boolean, array, associative array, etc.)
declare -rxi err_argument_value=4       # an argument has an invalid value (out of range, not in allowed set. E.g. expected non-negative integer but got negative value)
declare -rxi err_invalid_nameref=5      # an argument has an invalid nameref (e.g., expected a valid variable name reference but got an invalid one)
declare -rxi err_missing_argument=6      # a required argument is missing
declare -rxi err_more_than_one_argument=7      # more than one argument was provided when only one is allowed
declare -rxi err_unknown_argument=8      # an unknown argument was provided

declare -rxi err_not_overridden=64      # a function that should be overridden in the calling script (e.g. usage) was not overridden

# RETURN CODES THAT CAN BE REUSED FOR OTHER PURPOSES:
declare -rxi err_not_found=5            # file, directory, or something else could not be found
declare -rxi err_not_file=6             # parameter value is not a file
declare -rxi err_not_directory=7        # parameter value is not a directory

declare -rxi err_not_git_directory=80   # the specified directory is not a directory from a Git repository working tree
declare -rxi err_not_git_repository=81  # the specified directory is not a git repository
declare -rxi err_behind_latest_stable_tag=82 # the repository is behind the latest stable tag
declare -rxi err_invalid_repo=83        # the specified repository is not valid
declare -rxi err_found_more_than_one=84 # found more than one item matching the criteria
declare -rxi err_repo_has_no_ci=85      # the specified repository does not have a CI configuration in repo/.github/workflows
declare -rxi err_dir_has_no_ci=86       # the specified directory is not a repository and does not have a CI configuration in dir/.github/workflows
