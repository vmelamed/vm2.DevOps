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

function update_dependencies() {
    local repos=$1
    local repo=$2

    set +e
    cd "$repos/$repo"
    gh workflow run "ClearCache.yaml" --repo "vmelamed/$repo"
    rm ./**/*.lock.json
    dotnet restore --force-evaluate
    git add -A
    git commit -m "chore: update dependencies"
    gh run watch --repo "vmelamed/$repo"
    git push origin --force-with-lease
    set -e
}

for r in ${vm2_repositories[$]}; do
    if [[ $r == "$vm2_devops_repo_name" ]]; then continue; fi
    update_dependencies "$vm2_repos" "$r"
done
