# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

# constants from lib:
declare -xri err_invalid_arguments
declare -xri err_argument_value

declare -xr default_vm2_repos_path

#---------------------------------------------------------------------------------------------
# @description Prints the usage text of 'update-packages.sh'.
#
# @arg $1 bool When `true`, print the long text, including the shared switches and environment variables.
#
# @exitcode success=0: Always.
# @stdout The usage text.
#---------------------------------------------------------------------------------------------
function usage_text()
{
    (( $# == 1 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one boolean argument (provided $#)."
    [[ ! -v 1 ]] || is_boolean "$1" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be 'true' or 'false' (provided '${1:-<none>}')."
    exit_if_has_bugs

    local _common_args=''
    $1 && _common_args=$common_args_usage

    cat << EOF
Usage:
  $script_name [<repository>]* [ --<long switch> | -<short switch> ]*

  Upgrades the NuGet package versions in 'Directory.Packages.props' to the newest stable version found in the
  configured NuGet sources, without downgrading. The shared block is upgraded in the SoT (vm2.Templates) first and then
  copied to the repositories with 'diff-shared.sh'; each repository's own section is upgraded afterwards.

  A repository is changed in one of three ways:
    publish  on 'main', clean, and identical to 'origin/main': a branch 'deps/update-packages-<yyyy-mm-dd-hh-mm-ss>' is created,
             the changes are committed there, and the branch is pushed (not 'main').
    inplace  anything else: the files are edited in the current branch and nothing is committed. A warning says so.
    skip     uncommitted changes exist: the repository is left untouched, with a warning.

Parameters:
  <repository>                  One or more repository names. Including 'vm2.Templates' also upgrades the shared block in the
                                SoT and copies it to the repositories. If omitted, the repository of the current directory is
                                used. The list of repositories can be replaced by the switch '--all-repositories', or
                                '--all-repos', or just '-all'.

Options:
  -r, --vm2-repos <dir>         The parent directory where all vm2 repositories are cloned. Initial value from \$VM2_REPOS or
                                '$default_vm2_repos_path'.
  -sf, --summary-file <file>    Write the run summary to <file> in Markdown format. If not specified, a temporary file is
                                created, displayed at the end, and then deleted.
Switches:
  -all, --all-repos, --all-repositories
                                Update all pre-defined vm2 repositories under \$VM2_REPOS with the SoT, one by one. The set is
                                defined in 'lib/_constants.sh'.

Examples:
  $script_name
  $script_name --dry-run vm2.Ulid
  $script_name --all-repositories --summary-file last-update-packages.md
  $script_name vm2.Ulid vm2.Glob
$_common_args
EOF
}
