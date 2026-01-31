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
declare -x reason=${REASON:-stable release}

source "$script_dir/changelog-and-tag.usage.sh"
source "$script_dir/changelog-and-tag.utils.sh"

get_arguments "$@"

# Sanitize inputs
validate_minverTagPrefix "$minver_tag_prefix" || true
is_semverReleaseTag "$release_tag" || true
is_safe_reason "$reason" || true

declare -xr release_tag
declare -xr reason
declare -xr minver_tag_prefix

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

if [[ ! -s changelog/cliff.release-header.toml ]]; then
    warning "Missing changelog/cliff.release-header.toml; skipping changelog update."
else
    # Use the range from last stable tag to HEAD
    # shellcheck disable=SC2154 # semverTagReleaseRegex is referenced but not assigned.
    last_stable=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1 || echo "")
    if [[ -n "$last_stable" ]]; then
        range="$last_stable..HEAD"
    else
        range=""
    fi

    echo "Generating changelog for $release_tag (range: ${range:-all commits})"

    if [[ -n "$range" ]]; then
        execute git-cliff -c changelog/cliff.release-header.toml \
            --tag "$release_tag" \
            --prepend CHANGELOG.md \
            "$range"
    else
        execute git-cliff -c changelog/cliff.release-header.toml \
            --tag "$release_tag" \
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
# STEP 2: Create and push release tag
# ============================================================================

if ! execute git tag -a "$release_tag" -m "Release $release_tag" -m "Reason: $reason"; then
    error "Failed to create tag $release_tag (does it already exist?)"
    exit 2
fi

execute git push origin "$release_tag"

info "✅ Tag $release_tag created and pushed"
