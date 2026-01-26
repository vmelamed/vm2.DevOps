#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: restore-locked.sh [solution-or-project]

Refresh package lock files with --force-evaluate, then verify in --locked-mode
(the same enforcement used in CI). Defaults to the solution, project, or file
in the current directory, when no target is provided.
EOF
}

if [[ ${1-} == "-h" || ${1-} == "--help" ]]; then
  usage
  exit 0
fi

target=${1:-vm2.Glob.slnx}

if [[ ${1:-} == "1" ]]; then
  echo "Error: positional argument must be a solution or project file." 1>&2
  usage
  exit 1
fi

echo "[restore-locked] refreshing lock files for ${target} (force-evaluate)…"
dotnet restore "${target}" --force-evaluate

echo "[restore-locked] verifying lock files for ${target} (locked-mode)…"
dotnet restore "${target}" --locked-mode >/dev/null

echo "[restore-locked] done. Lock files are in sync with restore inputs."
