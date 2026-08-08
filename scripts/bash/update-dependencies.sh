#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")
# freeze them!
declare -rx script_name
declare -rx script_dir
declare -rx lib_dir

# shellcheck disable=SC1091
{
    source "$lib_dir/core.sh"
    source "$lib_dir/_git_vm2.sh"
}

declare -rxa vm2_repositories
declare -rx vm2_devops_repo_name

declare -x vm2_repos="${VM2_REPOS:-$HOME/repos/vm2}"
declare -x repo

#-------------------------------------------------------------------------------
# @description Refreshes a single vm2 repository's NuGet lock files and pushes the update. Clears the repo's GitHub Actions
# cache, deletes all local '*.lock.json' files, restores with '--force-evaluate' to regenerate them, commits the result,
# waits for the triggered CI run to finish, and force-pushes with lease.
#
# Notes:
#   - Temporarily disables 'set -e' ('set +e') for the sequence of git/gh/dotnet calls, so a failure partway through
#     (e.g. no lock file changes to commit) does not abort the whole loop over repositories.
#   - Changes directory into '$repos/$repo' and stays there — it does not restore the original working directory.
#
# @arg $1 string Path to the parent directory containing the vm2 repo clones.
# @arg $2 string Name of the repository (subdirectory of '$1') to update.
#
# @exitcode 0 Always (errors inside the function are suppressed via 'set +e' rather than propagated).
#
# @stdout Output from 'gh workflow run', 'dotnet restore', 'git commit', 'gh run watch', and 'git push'.
#
# @example
#   update_dependencies "$HOME/repos/vm2" "vm2.Glob"
#-------------------------------------------------------------------------------
function update_dependencies() {
    local _repos=$1
    local _repo=$2

    set +e
    cd "$_repos/$_repo"

    # Run the diff-shared script to update dependencies in the repo's Directory.Packages.props file from the SoT
    "$_repos/vm2.DevOps/scripts/bash/diff-shared.sh" --vm2-repos "$_repos" --file-merge Directory.Packages.props

    # Clear the cache for this repository via the ClearCache workflow
    gh workflow run "ClearCache.yaml" --repo "vmelamed/$_repo"
    rm ./**/packages.lock.json
    dotnet restore --force-evaluate

    # Stage and commit all changes
    git add ./**/packages.lock.json
    git commit -m "chore: update dependencies" || true

    # Watch the triggered ClearCache workflow run to finish before pushing changes
    gh run watch --repo "vmelamed/$_repo" || true

    # Push the committed changes to the remote repository
    git push origin --force-with-lease
    set -e
}

#-------------------------------------------------------------------------------
# @description Main script body: iterates over every repository listed in 'vm2_repositories' (from '_constants.sh'),
# skipping 'vm2_devops_repo_name' itself, and calls 'update_dependencies' on each to refresh its NuGet lock files.
#
# @arg $@ none Takes no command-line arguments.
#
# @exitcode 0 Always (failures within 'update_dependencies' are swallowed per-repo; see its own doc comment).
#
# @stdout Combined output of 'update_dependencies' for every processed repository.
#-------------------------------------------------------------------------------
for r in "${vm2_repositories[@]}"; do
    [[ $r != "$vm2_devops_repo_name" ]] && update_dependencies "$vm2_repos" "$r"
done
