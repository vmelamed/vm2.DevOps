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

# shellcheck disable=SC1091 # Not following
source "$lib_dir/core.sh"

# Adds SPDX headers to C# sources, bash scripts, and YAML files, skipping generated artifacts.

#===============================
# Imported constants
#===============================
# imported environment variables and defaults:
declare -x _ignore
declare -x initial_cwd

#===============================
# arguments:
#===============================
declare -x dir=''
declare -x license="${LICENSE:-MIT}"

# import outcomes and error codes
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments

source "$script_dir/add-spdx.args.sh"
source "$script_dir/add-spdx.usage.sh"

#---------------------------------------------------------------------------------------------
# @description Main script body: recursively scans a directory for '*.cs', '*.sh', '*.yaml', and
#   '*.yml' files and prepends an SPDX license-identifier header (with a copyright line) to any
#   file that does not already contain one. C# generated artifacts ('obj/', 'bin/',
#   'AssemblyInfo.cs', '*.g.cs', '*.designer.cs') are skipped. UTF-8 BOMs on C# files are
#   preserved ahead of the inserted header; on bash files with a shebang, the header is
#   inserted after the shebang line rather than before it. YAML files (workflows, dependabot.yml,
#   etc.) use '#' comments just like bash and always have the header inserted at the top, since
#   they have no shebang-equivalent line to skip past.
#
# Notes:
#   - Bash files are matched purely by the '*.sh' extension; a bash file without a '.sh'
#     extension (e.g. a shebang-only script named without an extension) is not discovered by
#     the 'find' below.
#   - Both '*.yaml' and '*.yml' are matched: GitHub requires the dependabot config specifically
#     at '.github/dependabot.yml', so the two extensions coexist in this repo's conventions.
#
# @arg $@ string Named options:
#   - '-l|--license <spdx-id>' (default: 'MIT')
#   - '-d|--directory <dir>' (default: '.'),
#   - the usual common core arguments.
#
# @exitcode success/positive=0: The scan completed (whether or not any files were modified).
# @exitcode failure/negative=1: An unknown option was given, a required option value was
#   missing, or '<dir>' does not exist (via 'usage' or the explicit directory check below).
#
# @stdout Per-file progress lines (skipped/would-add/added) and a final summary line with
#   scanned/modified/skipped counts.
#
# @example
#   add-spdx.sh --directory ./src --license MIT
# @example
#   add-spdx.sh --dry-run
#---------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------
# @description Prepends the SPDX header to a C# file, preserving a leading UTF-8 BOM (if any)
#   ahead of it.
#
# @arg $1 string Path to an existing C# file with no SPDX header yet.
#---------------------------------------------------------------------------------------------
function add_spdx_csharp_file()
{
    local _file="$1"

    # Check if file has UTF-8 BOM (0xEF 0xBB 0xBF)
    if head -c 3 "$_file" | od -An -tx1 | grep -q "ef bb bf"; then
        # Has BOM - preserve it at the start
        local _bom _body
        _bom=$(head -c 3 "$_file")
        _body=$(tail -c +4 "$_file")
        {
            printf "%s" "$_bom"
            printf "%s" "$cs_header"
            printf "%s" "$_body"
        } > "$_file.tmp" && mv "$_file.tmp" "$_file"
    else
        # No BOM - just prepend header
        {
            printf "%s" "$cs_header"
            cat "$_file"
        } > "$_file.tmp" && mv "$_file.tmp" "$_file"
    fi
}

#---------------------------------------------------------------------------------------------
# @description Prepends the SPDX header to a bash file, inserting it after the shebang line
#   when there is one, or at the very top otherwise.
#
# @arg $1 string Path to an existing bash file with no SPDX header yet.
#---------------------------------------------------------------------------------------------
function add_spdx_bash_file()
{
    local _file="$1"
    local _first_line

    _first_line=$(head -n 1 "$_file")
    {
        if [[ "$_first_line" =~ ^#! ]]; then
            # Has shebang - insert after it
            echo "$_first_line"
            printf "%s" "$bash_header"
            tail -n +2 "$_file"
        else
            # No shebang - insert at top
            printf "%s" "$bash_header"
            cat "$_file"
        fi
    } > "$_file.tmp" && mv "$_file.tmp" "$_file"
}

#---------------------------------------------------------------------------------------------
# @description Prepends the SPDX header to a YAML file. Always inserted at the top: unlike bash
#   scripts, YAML has no shebang-equivalent line to insert after.
#
# @arg $1 string Path to an existing YAML file with no SPDX header yet.
#---------------------------------------------------------------------------------------------
function add_spdx_yaml_file()
{
    local _file="$1"

    {
        printf "%s" "$bash_header"
        cat "$_file"
    } > "$_file.tmp" && mv "$_file.tmp" "$_file"
}

#---------------------------------------------------------------------------------------------
# @description Drives one file through the skip/dry-run/write decision shared by all file types,
#   updating the 'processed'/'skipped'/'modified' counters and delegating the actual header
#   insertion to the given writer function.
#
# @arg $1 string Name of the writer function to call when the file needs a header
#   ('add_spdx_csharp_file', 'add_spdx_bash_file', or 'add_spdx_yaml_file').
# @arg $2 string Path to the file to process.
#---------------------------------------------------------------------------------------------
function process_file()
{
    local _writer="$1"
    local _file="$2"
    local _rel=".${_file#"$root"}"

    trace "Processing $_file"
    (( ++processed ))

    if grep -q "SPDX-License-Identifier" "$_file"; then
        info "Skipping (has header): $_rel"
        (( ++skipped ))
        return
    fi

    if is_dry_run; then
        info "Would add header to: $_rel"
        return
    fi

    "$_writer" "$_file"

    info "Added header to: $_rel"
    (( ++modified ))
}

get_arguments "$@"

[[ -n "$dir" ]] || dir="$initial_cwd"
[[ -d "$dir" ]] || { echo "Directory not found: $dir" 1>&2; exit 1; }
root=$(cd "$dir" && pwd)

cs_header="// SPDX-License-Identifier: $license
// Copyright (c) 2025-2026 Val Melamed

"

bash_header="# SPDX-License-Identifier: $license
# Copyright (c) 2025-2026 Val Melamed

"

processed=0
modified=0
skipped=0

# Process C# files
while IFS= read -r -d '' file; do
    process_file add_spdx_csharp_file "$file"
done < <(find "$root" -type f -name '*.cs' \
            ! -path '*/obj/*' \
            ! -path '*/bin/*' \
            ! -name 'AssemblyInfo.cs' \
            ! -name '*.g.cs' \
            ! -name '*.designer.cs' -print0)

# Process bash files
while IFS= read -r -d '' file; do
    process_file add_spdx_bash_file "$file"
done < <(find "$root" -type f -name '*.sh' -print0)

# Process YAML files (workflows, dependabot.yml, etc.)
while IFS= read -r -d '' file; do
    process_file add_spdx_yaml_file "$file"
done < <(find "$root" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

if is_dry_run; then
    info "Summary (dry run): scanned=$processed, would modify=$((processed - skipped)), skipped=$skipped"
else
    info "Summary: scanned=$processed, modified=$modified, skipped=$skipped"
fi
