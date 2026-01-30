# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed


# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# This script defines a number of general purpose functions.
# For the functions to be invocable by other scripts, this script needs to be sourced.
# When fatal parameter errors are detected, the script invokes exit, which leads to exiting the current shell.

#--------------------------------------------------------------------------------
# Common scripts variables and environment initialization
#--------------------------------------------------------------------------------

declare -x script_name
declare -x script_dir
declare -x lib_dir

if [[ ! -v script_name || -z "$script_name" ]]; then
    script_name="$(basename "${BASH_SOURCE[-1]}")"
fi
if [[ ! -v script_dir || -z "$script_dir" ]]; then
    script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[-1]}")")"
fi
if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
fi

# variables commonly used for diagnostics
declare -rx script_name
declare -rx script_dir
declare -rx lib_dir

# source the components of the core library
source "${lib_dir}/_constants.sh"
source "${lib_dir}/_diagnostics.sh"
source "${lib_dir}/_args.sh"
source "${lib_dir}/_predicates.sh"
source "${lib_dir}/_dump_vars.sh"
source "${lib_dir}/_semver.sh"
source "${lib_dir}/_user.sh"

#-------------------------------------------------------------------------------
# Summary: Depending on the value of $dry_run, either executes or displays what would have been executed.
# Parameters:
#   1 - command - the command to execute
#   2+ - args - arguments to pass to the command (optional)
# Returns:
#   Exit code: 0 on success or in dry-run mode, command's exit code otherwise, 2 on invalid arguments
# Env. Vars:
#   dry_run - when true, displays command without executing it
# Usage: execute <command> [args...]
# Example: execute git commit -m "Initial commit"
#-------------------------------------------------------------------------------
declare -x dry_run=${DRY_RUN:-false}

function execute()
{
    if [[ $# -eq 0 ]]; then
        error "${FUNCNAME[0]}() requires at least one argument: the command to execute."
        return 2
    fi
    if [[ "$dry_run" == true ]]; then
        echo "dry-run$ $*"
        return 0
    fi
    trace "$*"
    "$@"
}

#-------------------------------------------------------------------------------
# Summary: Tests if parameter is a valid file pattern and returns matching files, recursing into subdirectories.
# Parameters:
#   1 - file_pattern - glob pattern to match files (supports ** for recursive matching)
# Returns:
#   stdout: space-separated list of matching files
#   Exit code: 0 on success, 2 on invalid arguments
# Usage: files=$(list_of_files <file_pattern>)
# Example:
#   packages=$(list_of_files "artifacts/pack/*.nupkg")
#   for pkg in $packages; do echo "$pkg"; done
# Notes: Returns empty string if no files match pattern.
#-------------------------------------------------------------------------------
function list_of_files()
{
    if [[ $# -lt 1 ]]; then
        error "${FUNCNAME[0]}() requires at least one parameter: the file pattern."
        return 2
    fi

    # remember the current settings of the nullglob and globstar options
    restoreGlobstar=$(shopt -p globstar)
    restoreNullglob=$(shopt -p nullglob)

    # if a glob pattern does not match any files - expand to an empty string
    # enable globstar to allow **/ pattern to match directories and subdirectories recursively
    shopt -s globstar || true
    shopt -s nullglob || true

    local list=("$1")

    # restore the previous settings of the nullglob and globstar options
    eval "$restoreNullglob"
    eval "$restoreGlobstar"

    printf "%s" "${list[*]}"
    return 0
}
