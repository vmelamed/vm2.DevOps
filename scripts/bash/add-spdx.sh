#!/usr/bin/env bash
set -euo pipefail

# Adds SPDX headers to C# sources and bash scripts, skipping generated artifacts.
usage()
{
  echo "Usage: $(basename "$0") [-l LICENSE] [-d DIR] [--dry-run]" 1>&2
  echo "  -l LICENSE    SPDX license identifier (default: MIT)" 1>&2
  exit 1
}

dir="."
license="MIT"
dry_run=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--license)
      [[ $# -ge 2 ]] || usage
      license="$2"
      shift 2
      ;;
    -d|--directory)
      [[ $# -ge 2 ]] || usage
      dir="$2"
      shift 2
      ;;
    -y|--dry-run)
      dry_run=true
      shift
      ;;
    -h|--help|-\?)
      usage
      ;;
    *)
      echo "Unknown option: $1" 1>&2
      usage
      ;;
  esac
done

[[ -d "$dir" ]] || { echo "Directory not found: $dir" 1>&2; exit 1; }
root=$(cd "$dir" && pwd)

cs_header="// SPDX-License-Identifier: $license
// Copyright (c) 2025 Val Melamed


"

bash_header="# SPDX-License-Identifier: $license
# Copyright (c) 2025 Val Melamed

"

processed=0
modified=0
skipped=0

# Process C# files
while IFS= read -r -d '' file; do
  processed=$((processed + 1))
  rel=".${file#"${root}"}"

  if grep -q "SPDX-License-Identifier" "$file"; then
    echo "Skipping (has header): $rel"
    skipped=$((skipped + 1))
    continue
  fi

  if $dry_run; then
    echo "Would add header to: $rel"
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

  echo "Added header to: $rel"
  modified=$((modified + 1))
done < <(find "$root" -type f -name '*.cs' \
  ! -path '*/obj/*' \
  ! -path '*/bin/*' \
  ! -name 'AssemblyInfo.cs' \
  ! -name '*.g.cs' \
  ! -name '*.designer.cs' -print0)

# Process bash files
while IFS= read -r -d '' file; do
  processed=$((processed + 1))
  rel=".${file#"${root}"}"

  if grep -q "SPDX-License-Identifier" "$file"; then
    echo "Skipping (has header): $rel"
    skipped=$((skipped + 1))
    continue
  fi

  if $dry_run; then
    echo "Would add header to: $rel"
    continue
  fi

  # Read first line to check for shebang
  first_line=$(head -n 1 "$file")
  if [[ "$first_line" =~ ^#! ]]; then
    # Has shebang - insert after it
    {
      echo "$first_line"
      echo "$bash_header"
      tail -n +2 "$file"
    } > "$file.tmp" && mv "$file.tmp" "$file"
  else
    # No shebang - insert at top
    {
      echo "$bash_header"
      cat "$file"
    } > "$file.tmp" && mv "$file.tmp" "$file"
  fi

  echo "Added header to: $rel"
  modified=$((modified + 1))
done < <(find "$root" -type f -name '*.sh' -print0)

if $dry_run; then
  echo "Summary (dry run): scanned=$processed, would modify=$((processed - skipped)), skipped=$skipped"
else
  echo "Summary: scanned=$processed, modified=$modified, skipped=$skipped"
fi
