# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_switches
declare -xr common_vars
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
    local _long_text=$1
    local _common_switches=""
    local _common_vars=""

    if $_long_text; then
        _common_switches="$common_switches"
        _common_vars="$common_vars"
    fi

    cat << EOF
Usage: $script_name [<repo-directory>...] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch>]*

Recursively scans a directory for '*.cs' and '*.sh' files and prepends an SPDX license-identifier header (with a copyright line)
to any file that does not already contain one. C# generated artifacts ('obj/', 'bin/', 'AssemblyInfo.cs', '*.g.cs',
'*.designer.cs') are skipped. UTF-8 BOMs on C# files are preserved ahead of the inserted header; on bash files with a shebang,
the header is inserted after the shebang line.

Arguments:
  <directory>                   The directory to scan (optional, default: current directory)

Options:
  -l, --license <spdx-id>       Specify the SPDX license identifier (optional, default: 'MIT')

Switches:
$_common_switches
Environment Variables:
  LICENSE                       The SPDX license identifier to use (optional, default: 'MIT')
$_common_vars
EOF
}
