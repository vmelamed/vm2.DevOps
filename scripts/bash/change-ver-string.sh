#!/usr/bin/env bash

# shellcheck disable=SC2154

set -euo pipefail

projects=(vm2.TestUtilities vm2.Glob vm2.Ulid vm2.Templates vm2.SemVer vm2.Linq.Expressions)
old_version="10.0.203"
new_version="10.0.7"

cd "$VM2_REPOS"
# Only show:
find . -type f -name "Directory.Packages.props" -exec grep -nE "$old_version" {} +
find . -type f -name "global.json" -exec grep -nE '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' {} +
# replace:
find . -type f -name "global.json" -exec sed -Ei 's/"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"/"version": "'"$sdk_version"'"/g' {} +

for project in "${projects[@]}"; do
    project_dir="$VM2_REPOS/$project"
    if [[ ! -d "$project_dir" ]]; then
        echo "Warning: Project directory not found: $project_dir" >&2
        continue
    fi
    cd "$project_dir"
    echo "Changing .NET version for project: $project"
    dotnet new globaljson --sdk-version 8.0.100 --force
done
