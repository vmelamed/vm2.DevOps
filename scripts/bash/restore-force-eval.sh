#!/usr/bin/env bash
set -euo pipefail

projects=(vm2.TestUtilities vm2.Glob vm2.Ulid vm2.Templates)
# should be executed from a git repository with the expected structure
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

    echo "Verifying lock files: $project"
    if ! dotnet restore --locked-mode > /dev/null 2>&1; then
        echo "Error: Lock file verification failed for $project" >&2
        continue
    fi

    # Stage updated lock files
    lock_files=$(git diff --name-only -- '**/packages.lock.json' 2>/dev/null || true)
    if [[ -n "$lock_files" ]]; then
        git add ./**/packages.lock.json
        echo "Staged lock files: $project"
    else
        echo "No lock file changes: $project"
    fi

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
