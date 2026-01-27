#!/usr/bin/env bash
set -euo pipefail

# Adds SPDX headers to C# sources, skipping generated artifacts.
usage()
{
  echo "Usage: $(basename "$0") [-d DIR] [--what-if]" 1>&2
  exit 1
}

dir="."
what_if=false
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
    -n|--what-if)
      what_if=true
      shift
      ;;
    -h|--help)
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

header="// SPDX-License-Identifier: $license
// Copyright (c) 2025 Val Melamed


"

processed=0
modified=0
skipped=0

while IFS= read -r -d '' file; do
  processed=$((processed + 1))
  rel=".${file#"${root}"}"

  if grep -q "SPDX-License-Identifier" "$file"; then
    echo "Skipping (has header): $rel"
    skipped=$((skipped + 1))
    continue
  fi

  if $what_if; then
    echo "Would add header to: $rel"
    continue
  fi

  python - "$file" "$header" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
header = sys.argv[2]
data = path.read_bytes()
bom = b"\xef\xbb\xbf" if data.startswith(b"\xef\xbb\xbf") else b""
body = data[len(bom):]
path.write_bytes(bom + header.encode("utf-8") + body)
PY

  echo "Added header to: $rel"
  modified=$((modified + 1))
done < <(find "$root" -type f -name '*.cs' \
  ! -path '*/obj/*' \
  ! -path '*/bin/*' \
  ! -name 'AssemblyInfo.cs' \
  ! -name '*.g.cs' \
  ! -name '*.designer.cs' -print0)

if $what_if; then
  echo "Summary (dry run): scanned=$processed, would modify=$((processed - skipped)), skipped=$skipped"
else
  echo "Summary: scanned=$processed, modified=$modified, skipped=$skipped"
fi
