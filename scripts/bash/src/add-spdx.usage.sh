# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

#---------------------------------------------------------------------------------------------
# @description Prints a short usage message for 'add-spdx.sh' to stderr and exits.
#
# @arg $1 bool Accepted but currently unused — the printed text and exit code are the same regardless of its value.
#
# @exitcode failure/negative=1: Always — including when called for '--help'/'-h'/'-?'.
#
# @stdout (none — the usage text is written to stderr, not stdout).
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
  $script_name [<repo-directory>...] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch>]*

Recursively scans a directory for '*.cs', '*.sh', '*.yaml', and '*.yml' files and prepends an SPDX license-identifier header
(with a copyright line) to any file that does not already contain one. C# generated artifacts ('obj/', 'bin/',
'AssemblyInfo.cs', '*.g.cs', '*.designer.cs') are skipped. UTF-8 BOMs on C# files are preserved ahead of the inserted header;
on bash files with a shebang, the header is inserted after the shebang line. YAML files always get the header at the top.

Arguments:
  <directory>                   The directory to scan (optional, default: current directory)

Options:
  -l, --license <spdx-id>       Specify the SPDX license identifier (optional, default: 'MIT')

Environment Variables:
  LICENSE                       The SPDX license identifier to use (optional, default: 'MIT')
$_common_args
EOF
}
