#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# core lib
source "$lib_dir/core.sh"

# core lib exit codes
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_tool_error
declare -xri err_not_directory

# core lib variables
declare -x _ignore

source "$script_dir/add-spdx.args.sh"
source "$script_dir/add-spdx.functions.sh"
source "$script_dir/add-spdx.usage.sh"

#---------------------------------------------------------------------------------------------
# @description Main script body: recursively scans a directory for '*.cs', '*.sh', '*.bats',
#   '*.yaml', and '*.yml' files and prepends an SPDX license-identifier header (with a copyright
#   line) to any file that does not already contain one. C# generated artifacts ('obj/', 'bin/',
#   'AssemblyInfo.cs', '*.g.cs', '*.designer.cs') are skipped, and so are '.git' and every git
#   submodule (third-party code). A leading UTF-8 BOM on a C# file is stripped (the vm2
#   convention is UTF-8 without a BOM); on bash files with a shebang, the header is inserted
#   after the shebang line rather than before it. YAML files (workflows, dependabot.yml, etc.)
#   use '#' comments just like bash and always have the header inserted at the top, since they
#   have no shebang-equivalent line to skip past.
#
# Notes:
#   - Bash files are matched purely by the '*.sh' and '*.bats' extensions; a bash file without
#     one of them (e.g. a shebang-only script named without an extension) is not discovered by
#     the 'find's below.
#   - Both '*.yaml' and '*.yml' are matched: GitHub requires the dependabot config specifically
#     at '.github/dependabot.yml', so the two extensions coexist in this repo's conventions.
#   - Each file is rewritten through a temporary file next to it, which then replaces the
#     original with 'mv' (an atomic rename on the same file system); the file mode is preserved.
#     In a dry run the 'mv' is only printed, and the temporary file is removed.
#
# @arg $@ string Arguments:
#   - '<directory>' (optional, default: the current directory): the directory to scan;
#   - '-l|--license <spdx-id>' (default: $LICENSE, or 'MIT');
#   - the usual common core arguments.
#
# @exitcode success=0: Every file found either got the header or already had one.
# @exitcode the specific 'err_*' code (via 'usage'): an invalid command line, e.g. an unknown
#   option, a missing option value, more than one directory, a directory that does not exist,
#   or an empty license.
# @exitcode the code of the last reported error (via 'exit_if_has_errors'): at least one file
#   could not be modified, e.g. it is read-only ('$err_not_file') or an I/O operation failed
#   ('$err_io_operation_failed'). All other files are still processed.
#
# @stdout Per-file progress lines (skipping/would've added/added) and a final summary line with
#   the scanned/modified/skipped/failed counts (scanned = modified + skipped + failed).
#
# @example
#   add-spdx.sh ./src --license MIT
# @example
#   add-spdx.sh --dry-run
#---------------------------------------------------------------------------------------------

# this scripts arguments
get_arguments "$@"
declare -xr dir
declare -xr license

declare -xr cs_header="// SPDX-License-Identifier: $license
// Copyright (c) 2025-2026 Val Melamed

"
declare -xr bash_header="# SPDX-License-Identifier: $license
# Copyright (c) 2025-2026 Val Melamed

"
declare -xr yaml_header=$bash_header

# this scripts constants
declare -x root
root=$(realpath -e "$dir")
readonly root

# this scripts variables
declare -xi processed=0
declare -xi modified=0
declare -xi skipped=0
declare -xi failed=0

# Submodules hold third-party code: never stamp our copyright on it. Outside a git work tree there are none; inside one, a
# failure to list them must stop the run, or their files would be treated as ours.
declare -a submodules=()
if git -C "$root" rev-parse --is-inside-work-tree &> "$_ignore"; then
    # shellcheck disable=SC2016 # single quotes on purpose: 'git submodule foreach' expands $toplevel/$sm_path itself
    submodule_list=$(git -C "$root" submodule foreach --quiet --recursive 'echo "$toplevel/$sm_path"') ||
        exit_with_error -ec "$err_tool_error" "Failed to list the git submodules of '$root'; no files were changed."
    [[ -z $submodule_list ]] || readarray -t submodules <<< "$submodule_list"
fi

declare -a prune=( \( -name .git )
for submodule in "${submodules[@]}"; do
    prune+=( -o -samefile "$submodule" )
done
prune+=( \) -prune -o )
readonly prune

# Process C# files
while IFS= read -r -d '' file; do
    process_file "$file" || true
done < <(find "$root" "${prune[@]}" -type f -name '*.cs' \
            ! -path '*/obj/*' \
            ! -path '*/bin/*' \
            ! -name 'AssemblyInfo.cs' \
            ! -name '*.g.cs' \
            ! -name '*.designer.cs' -print0)

# Process bash files
while IFS= read -r -d '' file; do
    process_file "$file" || true
done < <(find "$root" "${prune[@]}" -type f \( -name '*.sh' -o -name '*.bats' \) -print0)

# Process YAML files (workflows, dependabot.yml, etc.)
while IFS= read -r -d '' file; do
    process_file "$file" || true
done < <(find "$root" "${prune[@]}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

if is_dry_run; then
    info "Summary (dry run): scanned=$processed, modified=$modified, skipped=$skipped, failed=$failed"
else
    info "Summary: scanned=$processed, modified=$modified, skipped=$skipped, failed=$failed"
fi
exit_if_has_errors false
