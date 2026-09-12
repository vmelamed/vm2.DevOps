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

# Adds SPDX headers to C# sources and bash scripts, skipping generated artifacts.

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
# @description Main script body: recursively scans a directory for '*.cs' and '*.sh' files and
#   prepends an SPDX license-identifier header (with a copyright line) to any file that does
#   not already contain one. C# generated artifacts ('obj/', 'bin/', 'AssemblyInfo.cs',
#   '*.g.cs', '*.designer.cs') are skipped. UTF-8 BOMs on C# files are preserved ahead of the
#   inserted header; on bash files with a shebang, the header is inserted after the shebang
#   line rather than before it.
#
# Notes:
#   - Bash files are matched purely by the '*.sh' extension; a bash file without a '.sh'
#     extension (e.g. a shebang-only script named without an extension) is not discovered by
#     the 'find' below.
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
    trace "Processing $file"

    processed=$((processed + 1))
    rel=".${file#"$root"}"

    if grep -q "SPDX-License-Identifier" "$file"; then
        info "Skipping (has header): $rel"
        skipped=$((skipped + 1))
        continue
    fi

    if is_dry_run; then
        info "Would add header to: $rel"
        continue
    fi

    # Check if file has UTF-8 BOM (0xEF 0xBB 0xBF)
    if head -c 3 "$file" | od -An -tx1 | grep -q "ef bb bf"; then
        # Has BOM - preserve it at the start
        bom=$(head -c 3 "$file")
        body=$(tail -c +4 "$file")
        {
            printf "%s" "$bom"
            printf "%s" "$cs_header"
            printf "%s" "$body"
        } > "$file.tmp" && mv "$file.tmp" "$file"
    else
        # No BOM - just prepend header
        {
            printf "%s" "$cs_header"
            cat "$file"
        } > "$file.tmp" && mv "$file.tmp" "$file"
    fi

    info "Added header to: $rel"
    modified=$((modified + 1))
done < <(find "$root" -type f -name '*.cs' \
            ! -path '*/obj/*' \
            ! -path '*/bin/*' \
            ! -name 'AssemblyInfo.cs' \
            ! -name '*.g.cs' \
            ! -name '*.designer.cs' -print0)

# Process bash files
while IFS= read -r -d '' file; do
    trace "Processing $file"

    processed=$((processed + 1))
    rel=".${file#"$root"}"

    if grep -q "SPDX-License-Identifier" "$file"; then
        info "Skipping (has header): $rel"
        skipped=$((skipped + 1))
        continue
    fi

    if is_dry_run; then
        info "Would add header to: $rel"
        continue
    fi

    # Read first line to check for shebang
    first_line=$(head -n 1 "$file")
    {
        if [[ "$first_line" =~ ^#! ]]; then
            # Has shebang - insert after it
            echo "$first_line"
            printf "%s" "$bash_header"
            tail -n +2 "$file"
        else
            # No shebang - insert at top
            printf "%s" "$bash_header"
            cat "$file"
        fi
    }  > "$file.tmp" && mv "$file.tmp" "$file"

    info "Added header to: $rel"
    modified=$(( modified + 1 ))
done < <(find "$root" -type f -name '*.sh' -print0)

if is_dry_run; then
    info "Summary (dry run): scanned=$processed, would modify=$((processed - skipped)), skipped=$skipped"
else
    info "Summary: scanned=$processed, modified=$modified, skipped=$skipped"
fi
