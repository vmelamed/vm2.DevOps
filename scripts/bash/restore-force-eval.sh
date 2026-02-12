#!/usr/bin/env bash
set -euo pipefail

projects=(vm2.TestUtilities vm2.Glob vm2.Ulid)
repo_root=$(git rev-parse --show-toplevel)

for project in "${projects[@]}"; do
    cd "$repo_root/../$project"
    echo "Restoring project: $project"
    dotnet restore --force-evaluate "$@"
done
