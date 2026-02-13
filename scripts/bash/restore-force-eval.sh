#!/usr/bin/env bash
set -euo pipefail

projects=(vm2.TestUtilities vm2.Glob vm2.Ulid)
repo_root=$(git rev-parse --show-toplevel)

for project in "${projects[@]}"; do
    project_dir="$repo_root/../$project"
    if [[ ! -d "$project_dir" ]]; then
        echo "Warning: Project directory not found: $project_dir" >&2
        continue
    fi
    cd "$project_dir"
    echo "Restoring project: $project"
    dotnet restore --force-evaluate "$@"

    if gh workflow view ClearCache.yaml --repo "vmelamed/$project" &>/dev/null; then
        if ! gh workflow run ClearCache.yaml \
            --repo "vmelamed/$project" \
            --raw-field reason="Change in $project dependencies." \
            --raw-field cache-pattern="nuget-"; then
            echo "Warning: Failed to trigger workflow for $project" >&2
        fi
    else
        echo "Info: No ClearCache workflow for $project, skipping cache clear" >&2
    fi
done
