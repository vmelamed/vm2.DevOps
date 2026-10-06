# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This file is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

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
    (( $# == 1 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one boolean argument (provided $#)."
    [[ ! -v 1 ]] || is_boolean "$1" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be 'true' or 'false' (provided '${1:-<none>}')."
    exit_if_has_bugs

    local _common_args=''
    $1 && _common_args=$common_args_usage

    cat << EOF
Usage:
  $script_name [<repository> ...] [ --<long switch> | -<short switch> ]*

  Upgrades the NuGet package versions in 'Directory.Packages.props' to the newest stable version found in the
  configured NuGet sources, without downgrading. The shared block is upgraded in the SoT (vm2.Templates) first and then
  copied to the repositories with 'diff-shared.sh'; each repository's own section is upgraded afterwards. Changes are
  committed on a new branch 'deps/update-packages-<yyyy-mm-dd>'; local changes are stashed first. Nothing is pushed.

Parameters:
  <repository>                One or more repository names (default: all vm2 repositories). Including 'vm2.Templates'
                              also upgrades the shared block in the SoT and copies it to the repositories.

Examples:
  $script_name
  $script_name --dry-run
  $script_name vm2.Ulid vm2.Glob
$_common_args
EOF
}
