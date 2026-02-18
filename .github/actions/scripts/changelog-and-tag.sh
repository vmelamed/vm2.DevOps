#!/usr/bin/env bash
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../../scripts/bash/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -xr default_minver_tag_prefix='v'

declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x release_tag=${RELEASE_TAG:-}
declare -x reason=${REASON:-}

source "$script_dir/changelog-and-tag.usage.sh"
source "$script_dir/changelog-and-tag.utils.sh"

get_arguments "$@"

dump_vars --quiet \
    --header "Inputs" \
    minver_tag_prefix \
    release_tag \
    reason

# Sanitize inputs
validate_minverTagPrefix "$minver_tag_prefix" || true

# Determine tag type: release or prerelease
is_release=false
is_prerelease=false
if is_semverReleaseTag "$release_tag"; then
    is_release=true
    reason=${reason:-"stable release"}
elif is_semverPrereleaseTag "$release_tag"; then
    is_prerelease=true
    reason=${reason:-"pre-release"}
else
    error "Tag '$release_tag' is not a valid semver release or prerelease tag." || true
fi

is_safe_reason "$reason" || true

declare -xr release_tag
declare -xr reason
declare -xr minver_tag_prefix
declare -xr is_release
declare -xr is_prerelease

dump_all_variables
exit_if_has_errors

# Configure git for CI
# shellcheck disable=SC2154 # ci is referenced but not assigned.
if [[ "$ci" == "true" ]]; then
    execute git config user.name "github-actions[bot]"
    execute git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi

# ============================================================================
# STEP 1: Update CHANGELOG
# ============================================================================

# Select cliff config based on tag type
if [[ "$is_release" == "true" ]]; then
    cliff_config="changelog/cliff.release-header.toml"
else
    cliff_config="changelog/cliff.prerelease.toml"
fi

if [[ ! -s "$cliff_config" ]]; then
    warning "Missing $cliff_config; skipping changelog update."
else
    # Determine the commit range
    # shellcheck disable=SC2154 # semverTagReleaseRegex is referenced but not assigned.
    if [[ "$is_release" == "true" ]]; then
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

    echo "Generating changelog for $release_tag (range: ${range:-all commits})"

    if [[ -n "$range" ]]; then
        execute git-cliff -c "$cliff_config" \
            --tag "$release_tag" \
            --prepend CHANGELOG.md \
            "$range"
    else
        execute git-cliff -c "$cliff_config" \
            --tag "$release_tag" \
            --unreleased \
            --prepend CHANGELOG.md
    fi

    if git status --porcelain -- CHANGELOG.md | grep -q .; then
        execute git add CHANGELOG.md
        execute git commit -m "chore: update changelog for $release_tag"
        execute git push
        info "✅ CHANGELOG updated and pushed"
    else
        warning "No changelog changes to commit"
    fi
fi

# ============================================================================
# STEP 2: Create and push tag
# ============================================================================

tag_message="Release $release_tag"
if [[ "$is_prerelease" == "true" ]]; then
    tag_message="Prerelease $release_tag"
fi

if ! execute git tag -a "$release_tag" -m "$tag_message" -m "Reason: $reason"; then
    error "Failed to create tag $release_tag (does it already exist?)"
    exit 2
fi

execute git push origin "$release_tag"

info "✅ Tag $release_tag created and pushed"
