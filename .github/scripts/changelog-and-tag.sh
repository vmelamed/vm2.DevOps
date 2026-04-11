#!/usr/bin/env bash
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -xr default_minver_tag_prefix='v'

declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x tag=${TAG:-}
declare -x reason=${REASON:-}
declare -x needs_empty_commit=${NEEDS_EMPTY_COMMIT:-false}

source "$script_dir/changelog-and-tag.usage.sh"
source "$script_dir/changelog-and-tag.args.sh"

get_arguments "$@"

# Sanitize inputs
validate_semverTagComponents "$minver_tag_prefix" || true

# Determine tag type: release or prerelease
is_release=false
is_prerelease=false
if is_semverReleaseTag "$tag"; then
    is_release=true
    reason=${reason:-"stable release"}
elif is_semverPrereleaseTag "$tag"; then
    is_prerelease=true
    reason=${reason:-"pre-release"}
else
    error "Tag '$tag' is not a valid semver release or prerelease tag."
fi

is_safe_reason "$reason" || true

declare -xr tag
declare -xr reason
declare -xr minver_tag_prefix
declare -xr is_release
declare -xr is_prerelease
declare -xr needs_empty_commit

exit_if_has_errors

# Configure git for CI
# shellcheck disable=SC2154 # ci is referenced but not assigned.
if $ci; then
    execute git config user.name "github-actions[bot]"
    execute git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi

# ============================================================================
# STEP 0: Empty commit to advance HEAD past a prerelease tag (if needed)
# ============================================================================

if [[ "$needs_empty_commit" == true ]]; then
    execute git commit --allow-empty -m "chore: promote to stable $tag [skip ci]"
    execute git push
    info "✅ Empty commit created to advance HEAD past prerelease tag"
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
    if [[ ! -f CHANGELOG.md ]]; then
        error "Missing CHANGELOG.md in repo root. git-cliff uses --prepend and requires an existing file."
        error "Create CHANGELOG.md (can be an empty file) and rerun."
        exit 2
    fi

    # Determine the commit range
    # shellcheck disable=SC2154 # semverTagReleaseRegex is referenced but not assigned.
    if [[ "$is_release" == true ]]; then
        # For stable releases: range from last stable tag to HEAD
        last_ref=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1 || echo "")
    else
        # For prereleases: range from last tag of any kind to HEAD
        last_ref=$(git tag --list "${minver_tag_prefix}*" | sort -V | tail -n1 || echo "")
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
        execute git push
        info "✅ CHANGELOG updated and pushed"
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

if ! execute git tag -a "$tag" -m "$tag_message" -m "Reason: $reason"; then
    error "Failed to create tag $tag (does it already exist?)"
    exit 2
fi

execute git push origin "$tag"

info "✅ Tag $tag created and pushed"
