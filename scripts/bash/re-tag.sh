#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed
#
# Rename or delete a git tag in place — useful for correcting SemVer mistakes
# without losing the commit pointer.

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
source "${lib_dir}/core.sh"

declare -rxi err_invalid_arguments
declare -rxi err_argument_value
declare -rxi err_logic_error

declare -x _ignore

declare -x delete_mode=false
declare -x del_tag=""
declare -x old_tag=""
declare -x new_tag=""

# shellcheck disable=SC1091
source "$script_dir/re-tag.args.sh"
# shellcheck disable=SC1091
source "$script_dir/re-tag.usage.sh"

get_arguments "$@"

# ─── argument validation & pre-flight ────────────────────────────────────────

if [[ "$delete_mode" == false ]]; then
    if [[ -z "$old_tag" ]]; then usage -ec "$err_invalid_arguments" "Missing required old and new tag arguments."; fi
    if [[ -z "$new_tag" ]]; then usage -ec "$err_invalid_arguments" "Missing required new tag argument."; fi
fi
# We don't need to check for the presence of del_tag in delete mode, because get_arguments already checked for it.

git rev-parse --git-dir 1>"$_ignore" || { error -ec "$err_logic_error" "Not a git repository."; exit 1; }

# Resolve the commit the old/del tag points to (dereference annotated tags)
if [[ "$delete_mode" == false ]]; then
    commit=$(git rev-list -n1 "$old_tag" 2>"$_ignore")       || usage -ec "$err_argument_value" "Tag '$old_tag' not found locally."
    existing_sha=$(git rev-list -n1 "$new_tag" 2>"$_ignore") && usage -ec "$err_argument_value" "Tag '$new_tag' already exists → commit ${existing_sha:0:12}."
    info "Tag '$old_tag' → commit ${commit:0:12}"
else
    commit=$(git rev-list -n1 "$del_tag" 2>"$_ignore") || usage -ec "$err_argument_value" "Tag '$del_tag' not found locally."
    info "Tag '$del_tag' → commit ${commit:0:12}"
fi

# ─── helpers ─────────────────────────────────────────────────────────────────

delete_tag()
{
    local tag="$1"
    execute git tag -d "$tag"
    trace "Deleted local tag '$tag'."
    if git ls-remote --tags origin "$tag" | grep -q "$tag"; then
        execute git push origin ":refs/tags/$tag"
        trace "Deleted remote tag 'origin/$tag'."
    else
        warning "Tag '$tag' not found on origin — skipping remote deletion."
    fi
}

# ─── main ────────────────────────────────────────────────────────────────────

if [[ "$delete_mode" == true ]]; then
    delete_tag "$del_tag"
    info "Deleted '$del_tag'."
else
    delete_tag "$old_tag"

    execute git tag "$new_tag" "$commit"
    trace "Created new tag '$new_tag' → commit ${commit:0:12}."

    execute git push origin "$new_tag"
    trace "Pushed new tag 'origin/$new_tag'."

    info "Renamed '$old_tag' → '$new_tag' at ${commit:0:12}."
fi
