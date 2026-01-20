#!/bin/bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
if ! pushd "$GIT_REPOS" > /dev/null; then
    echo "❌  ERROR: Could not change directory to '\$GIT_REPOS: $GIT_REPOS'." >&2
    exit 2
fi
cp vm2.DevOps/.github/actions/scripts/_common.*.sh vm2.Templates/templates/AddNewPackage/content/scripts/
cp vm2.DevOps/scripts/bash/sync-devops-templates.sh vm2.Templates/templates/AddNewPackage/content/scripts/
cp vm2.DevOps/scripts/bash/sync-devops-templates.sh vm2.Templates/scripts/
chmod u+x vm2.Templates/templates/AddNewPackage/content/scripts/*.sh
popd > /dev/null || exit 3
