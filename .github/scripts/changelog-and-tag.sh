#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")

declare -x script_name
declare -x script_dir
declare -x lib_dir

# vm2 core lib
source "$lib_dir/gh_core.sh"

# vm2 core lib exit codes
declare -x err_argument_value
declare -x err_not_found

# vm2 core lib constants
declare -x check_em
declare -x ci
declare -x key_artifacts_path
declare -x semverTagReleaseRegex
declare -x default_repo_owner

# vm2 core lib defaults
declare -x default_minver_tag_prefix

# vm2 core lib variables
declare -x noise_sink

# this script's components
source "$script_dir/changelog-and-tag.usage.sh"
source "$script_dir/changelog-and-tag.args.sh"

# this script's arguments
get_arguments "$@"
declare -x tag
declare -x reason
declare -x minver_tag_prefix
declare -x is_release
declare -x is_prerelease
declare -x needs_empty_commit

# Configure git for CI
if $ci; then
    execute git config user.name "$default_repo_owner"
    execute git config user.email "$default_repo_owner@users.noreply.github.com"
fi

# ============================================================================
# STEP 0: Empty commit to advance HEAD past a prerelease tag (if needed)
# ============================================================================

if [[ "$needs_empty_commit" == true ]]; then
    execute git commit --allow-empty -m "chore: promote to stable $tag [skip ci]"
    execute git push
    info "$check_em Empty commit created to advance HEAD past prerelease tag"
fi

# ============================================================================
# STEP 1: Update CHANGELOG
# ============================================================================

# Select cliff config based on tag type
if [[ "$is_release" == true ]]; then
    cliff_config="changelog/cliff.release-header.toml"
else
    cliff_config="changelog/cliff.prerelease.toml"
fi

if [[ ! -s "$cliff_config" ]]; then
    warning "Missing $cliff_config; skipping changelog update."
else
    # Fail fast: changelog bootstrapping should be explicit in repo setup.
    [[ -f CHANGELOG.md ]]                                                       || exit_with_error "$err_not_found" "Missing CHANGELOG.md in repo root. git-cliff uses --prepend and requires an existing file." \
                                                                                                                    "Create CHANGELOG.md (can be an empty file) and rerun."

    # Determine the commit range
    if [[ "$is_release" == true ]]; then
        # For stable releases: range from last stable tag to HEAD
        last_ref=$(git tag --list "$minver_tag_prefix*" | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1 || echo "")
    else
        # For prereleases: range from last tag of any kind to HEAD
        last_ref=$(git tag --list "$minver_tag_prefix*" | sort -V | tail -n1 || echo "")
    fi

    if [[ -n "$last_ref" ]]; then
        range="$last_ref..HEAD"
    else
        range=""
    fi

    echo "Generating changelog for $tag (range: ${range:-all commits})"

    if [[ -n "$range" ]]; then
        execute git-cliff -c "$cliff_config" \
            --tag "$tag" \
            --prepend CHANGELOG.md \
            "$range"
    else
        execute git-cliff -c "$cliff_config" \
            --tag "$tag" \
            --unreleased \
            --prepend CHANGELOG.md
    fi

    if git status --porcelain -- CHANGELOG.md | grep -q .; then
        execute git add CHANGELOG.md
        execute git commit -m "chore: update changelog for $tag [skip ci]"
        execute git push --force-with-lease
        info "$check_em CHANGELOG updated and pushed"
    else
        warning "No changelog changes to commit"
    fi
fi

# ============================================================================
# STEP 2: Create and push tag
# ============================================================================

tag_message="Release $tag"
if [[ "$is_prerelease" == true ]]; then
    tag_message="Prerelease $tag"
fi

execute git tag -a "$tag" -m "$tag_message" -m "Reason: $reason"                || exit_with_error "$err_argument_value" "Failed to create tag $tag (does it already exist?)"
execute git push origin "$tag"

info "$check_em Tag $tag created and pushed"
