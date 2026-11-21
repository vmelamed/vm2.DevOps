# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x common_args_usage
declare -x script_name

declare -x gh_apps_with_secrets
declare -x default_repo_owner

#-----------------------------------------------------------------------------------------------
# @description Builds and prints the full `--help` text for `set-secret.sh` to stdout: usage
#   line, description of what the script does, parameters, options, switches, examples, and
#   the list of local Git settings the script configures. When `$1` is `true`, the shared
#   switches and environment-variable sections (`$common_args_usage`) are appended as well.
#
# @arg $1 bool When `true`, include the shared/common switches and environment variables
#   sections in the output.
#
# @exitcode success=0: Always.
# @stdout The full help text for `set-secret.sh`.
#-----------------------------------------------------------------------------------------------
function usage_text()
{
    (( $# ==1 ))                     || bug "${FUNCNAME[0]}() requires 1 argument (provided $#): a boolean, whether to display the long or short usage text."
    [[ ! -v 1 ]]  || is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1, whether to display the long or short usage text, to be 'true' or 'false' (provided '${1-<missing>}')."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage:
  $script_name <secret-name> [ --<long option> <value> | -<short option> <value> | --<long switch> | -<short switch> ]*

  For each vm2 repository updates or creates a secret for a specified GitHub application.

Parameter:
  <secret-name>               The name of the secret to update. MUST contain only alphanumeric characters and underscores, start
                              with a letter or underscore, and does not start with 'GITHUB_'.

Options:
  -a, --app <value>           The application name. MUST be one of: ${gh_apps_with_secrets[*]}.
                              Optional, default is 'actions'.
  -o, --repo-owner <value>    The GitHub repository owner. Optional, default is '$default_repo_owner'.
$_common_args
Examples:
  $script_name --secret-name RELEASE_PAT --app actions
  $script_name -n RELEASE_PAT
EOF
}
