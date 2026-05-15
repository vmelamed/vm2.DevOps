#!/usr/bin/env bash
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")
declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -rxi err_tool_error
declare -rxi err_logic_error

# default constants for parameters
declare -xr default_minver_tag_prefix='v'
declare -xr default_reason="release build"

# parameters with initial values from environment variables or defaults
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x reason=${REASON:-"$default_reason"}

source "$script_dir/compute-release-version.usage.sh"
source "$script_dir/compute-release-version.args.sh"

get_arguments "$@"

# Sanitize inputs to prevent injection attacks
validate_semverTagComponents "$minver_tag_prefix" || true
is_safe_reason "$reason" || true

# freeze the parameters
declare -xr minver_tag_prefix
declare -xr reason

# detect if the head is already tagged
head_tag=$(git tag --points-at HEAD)
needs_empty_commit=false

if [[ -n $head_tag ]]; then
    if is_semverReleaseTag "$head_tag"; then
        error -ec "$err_logic_error" "The HEAD is already tagged with stable tag '$head_tag'. Possible remedy: branch 'main' again, do a new PR, and release with a new, higher version number."
    elif is_semverPrereleaseTag "$head_tag"; then
        trace "HEAD is tagged with prerelease tag '$head_tag'; will promote to stable release."
        needs_empty_commit=true
    else
        error -ec "$err_logic_error" "The HEAD is already tagged with '$head_tag' (not a recognized semver tag). Possible remedy: delete the tag, or branch 'main' again, do a new PR, and release with a new, higher version number."
    fi
fi

exit_if_has_errors

# Find latest stable like v1.2.3
# shellcheck disable=SC2154 # semverTagReleaseRegex is referenced but not assigned.
latest_stable_tag=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1 || echo "")
# shellcheck disable=SC2154 # semverTagPrereleaseRegex is referenced but not assigned.
latest_prerelease_tag=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagPrereleaseRegex" | sort -V | tail -n1 || echo "")

latest_stable_ver="${latest_stable_tag#"$minver_tag_prefix"}"
latest_prerelease_ver="${latest_prerelease_tag#"$minver_tag_prefix"}"

declare -i major=0
declare -i minor=0
declare -i patch=0

if is_semverRelease "$latest_stable_ver"; then
    major=${BASH_REMATCH[$semver_major]}
    minor=${BASH_REMATCH[$semver_minor]}
    patch=${BASH_REMATCH[$semver_patch]}
    if ((major <= 0 || minor < 0 || patch < 0)); then
        error -ec "$err_logic_error" "Invalid version numbers in latest stable tag '$latest_stable_tag': $major.$minor.$patch. Major must be > 0, minor and patch must be >= 0."
        exit 2
    fi
    trace "Latest stable release: $latest_stable_tag ($major.$minor.$patch)"
else
    trace "No previous stable release found; starting at 0.0.0"
fi

# Auto-detect next stable version from conventional commits
last_tag="${latest_stable_tag:-$(git rev-list --max-parents=0 HEAD)}"
# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
commits=$(git log "$last_tag"..HEAD --pretty=format:"%s" 2>"$_ignore" || echo "")

if echo "$commits" | grep -qiE '^[a-z]+(\(.+\))?!:'; then
    # Major bump
    major=$((major + 1))
    minor=0
    patch=0
    bump_type="major (breaking changes detected)"
elif echo "$commits" | grep -qiE '^feat(\(.+\))?:'; then
    # Minor bump
    minor=$((minor + 1))
    patch=0
    bump_type="minor (new features detected)"
else
    # Patch bump (default)
    patch=$((patch + 1))
    bump_type="patch (fixes or other changes)"
fi
if ((major == 0)); then
    # SemVer 2.0.0 requires major version to be at least 1 for releases
    major=1
    minor=0
    patch=0
    bump_type="adjusted to 1.0.0 for SemVer compliance"
fi

release_version="$major.$minor.$patch"
trace "Calculated release version from commit messages: $release_version [$bump_type]"

# make sure the computed version is not lower than the latest prerelease

if [[ -n "$latest_prerelease_tag" ]]; then
    if semver_lessThan "$release_version" "$latest_prerelease_ver"; then
        # the computed release version is less than the latest prerelease version,
        # so adopt the major, minor, and patch from the latest prerelease version and make it a release version
        trace "Latest prerelease tag '$latest_prerelease_tag' is greater than computed release version '$release_version'; adjusting release version."
        # shellcheck disable=SC2154
        [[ "$latest_prerelease_ver" =~ $semverPrereleaseRegex ]]
        major=${BASH_REMATCH[$semver_major]}
        minor=${BASH_REMATCH[$semver_minor]}
        patch=${BASH_REMATCH[$semver_patch]}
        release_version="$major.$minor.$patch"
        bump_type="adjusted to be > latest prerelease version"
    fi
fi

info "Finalized new release version: $release_version [$bump_type]"

release_tag="${minver_tag_prefix}${release_version}"

# If HEAD is already tagged with a prerelease, verify the stable version is strictly greater
if [[ "$needs_empty_commit" == true && -n "$head_tag" ]]; then
    head_ver=${head_tag#"$minver_tag_prefix"}
    # shellcheck disable=SC2154
    if ! semver_greaterThan "$release_version" "$head_ver"; then
        error-ec "$err_logic_error" "Computed stable version '$release_version' is not greater than the prerelease tag '$head_tag' on HEAD. Possible remedy: branch 'main' again, do a new PR with commits that bump the version higher, then release."
    fi
fi

declare -xr release_version
declare -xr release_tag
declare -xr needs_empty_commit

# Check if tag already exists
if git rev-parse "$release_tag" >"$_ignore" 2>&1; then
    error -ec "$err_logic_error" "Tag '$release_tag' already exists. Possible remedy: branch 'main' again, and do a new PR and release with a higher version number."
fi

exit_if_has_errors

# Output for GitHub Actions
args_to_github_output \
  release_version \
  release_tag \
  reason \
  needs_empty_commit

# Summary
{
    echo "## 🎯 Release Version: **$release_version**"
    echo "- Git Tag: \`$release_tag\`"
    echo "- Reason: ${reason}"
    if [[ "$needs_empty_commit" == true ]]; then
        echo "- Promoting prerelease \`$head_tag\` → stable (empty commit will advance HEAD)"
    fi
} | to_summary
