# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

declare -xr vm2_devops_repo_name
declare -xr vm2_sot_repo_name
declare -xr default_sot

declare -xra gh_apps_with_secrets

#---------------------------------------------------------------------------------------------
# @description Builds and prints the full `--help` text for `setup-repo.sh` to stdout: usage line, description of
# what the script does, parameters, options, switches, examples, and the list of local Git settings the script
# configures. When `$1` is `true`, the shared switches and environment-variable sections
# (`$common_args_usage`) are appended as well.
#
# @arg $1 bool When `true`, include the shared/common switches and environment variables sections in the output.
#
# @exitcode success=0: Always.
# @stdout The full help text for `setup-repo.sh`.
#---------------------------------------------------------------------------------------------
function usage_text()
{
    (( $# ==1 ))    || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage:
  $script_name <secret-name> [ --<long option> <value> | -<short option> <value> | --<long switch> | -<short switch> ]*

  For each vm2 repository updates or creates a secret for a specified GitHub application.

Parameter:
  <secret-name>               The name of the secret to update. MUST contains only
                              alphanumeric characters and underscores, start with a letter or underscore, and does not start
                              with 'GITHUB_'.

Options:
  -a, --app <value>           The application name. MUST be one of: ${gh_apps_with_secrets[*]}.
                              Optional, default is 'actions'.
  -o, --repo-owner <value>    The GitHub repository owner. Optional, default is 'vmelamed'.
$_common_args
Examples:
  $script_name --secret-name RELEASE_PAT --app actions
  $script_name -n RELEASE_PAT
EOF
}
