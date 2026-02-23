#!/usr/bin/env bash
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../../scripts/bash/lib")
declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

# default constants for parameters
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"
declare -xr default_reason="pre-release"

# parameters with initial values from environment variables or defaults
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}
declare -x reason=${REASON:-"$default_reason"}

source "$script_dir/compute-prerelease-version.usage.sh"
source "$script_dir/compute-prerelease-version.utils.sh"

get_arguments "$@"

dump_vars --quiet \
    --header "Inputs" \
    minver_tag_prefix \
    minver_prerelease_id \
    reason

# Sanitize inputs
validate_minverTagPrefix "$minver_tag_prefix" || true
is_safe_minverPrereleaseId "$minver_prerelease_id" || true
is_safe_reason "$reason" || true

# freeze the parameters
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr reason

# Derive the prerelease prefix by stripping the MinVer height seed (e.g. "preview.0" → "preview")
prerelease_prefix="${minver_prerelease_id%.[0-9]*}"
declare -xr prerelease_prefix
trace "Prerelease prefix: $prerelease_prefix (from minver_prerelease_id: $minver_prerelease_id)"

# detect if the head is already tagged
head_tag=$(git tag --points-at HEAD)
if [[ -n $head_tag ]]; then
    error "The HEAD is already tagged with '$head_tag'. A prerelease requires at least one new commit on main." || true
fi

dump_all_variables
exit_if_has_errors

# ============================================================================
# Find the latest stable and prerelease tags
# ============================================================================

# shellcheck disable=SC2154 # semverTagReleaseRegex is referenced but not assigned.
latest_stable=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1 || echo "")

# shellcheck disable=SC2154 # semverTagPrereleaseRegex is referenced but not assigned.
latest_prerelease=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagPrereleaseRegex" | sort -V | tail -n1 || echo "")

trace "Latest stable tag: ${latest_stable:-<none>}"
trace "Latest prerelease tag: ${latest_prerelease:-<none>}"

# ============================================================================
# Scan commits since the last stable tag to determine the bump type
# ============================================================================

declare -i major=0
declare -i minor=0
declare -i patch=0

# Start from the latest stable version if one exists
if is_semverReleaseTag "$latest_stable"; then
    major=${BASH_REMATCH[$semver_major]}
    minor=${BASH_REMATCH[$semver_minor]}
    patch=${BASH_REMATCH[$semver_patch]}
    if ((major <= 0 || minor < 0 || patch < 0)); then
        error "Invalid version numbers in latest stable tag '$latest_stable': $major.$minor.$patch"
        exit 2
    fi
    trace "Base version from latest stable: $major.$minor.$patch"
else
    trace "No previous stable release found; starting at 0.0.0"
fi

last_stable_ref="${latest_stable:-$(git rev-list --max-parents=0 HEAD)}"
# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
commits=$(git log "$last_stable_ref"..HEAD --pretty=format:"%s" 2>"$_ignore" || echo "")

# Determine bump type from conventional commits
if echo "$commits" | grep -qiE '^[a-z]+(\(.+\))?!:|BREAKING CHANGE:'; then
    major=$((major + 1))
    minor=0
    patch=0
    bump_type="major (breaking changes detected)"
elif echo "$commits" | grep -qiE '^feat(\(.+\))?:'; then
    minor=$((minor + 1))
    patch=0
    bump_type="minor (new features detected)"
else
    patch=$((patch + 1))
    bump_type="patch (fixes or other changes)"
fi

# SemVer floor: major version must be at least 1
if ((major == 0)); then
    major=1
    minor=0
    patch=0
    bump_type="adjusted to 1.0.0 for SemVer compliance"
fi

base_version="$major.$minor.$patch"
trace "Base version from commits: $base_version [$bump_type]"

# ============================================================================
# Determine the prerelease counter
# ============================================================================

prerelease_counter=1

if [[ -n "$latest_prerelease" ]] && is_semverPrereleaseTag "$latest_prerelease"; then
    # Extract the base version from the latest prerelease tag
    lp_major=${BASH_REMATCH[$semver_major]}
    lp_minor=${BASH_REMATCH[$semver_minor]}
    lp_patch=${BASH_REMATCH[$semver_patch]}
    lp_prerelease=${BASH_REMATCH[$semver_prerelease]}
    lp_base="$lp_major.$lp_minor.$lp_patch"

    trace "Latest prerelease base: $lp_base, prerelease id: $lp_prerelease"

    result=0
    compare_semver "$base_version" "$lp_base" || result=$?
    # shellcheck disable=SC2154 # isEq is referenced but not assigned.
    if (( result == isEq )); then
        # Same base version — increment the prerelease counter
        # Extract the numeric suffix from the prerelease identifier (e.g., "-preview.3" → 3)
        if [[ "$lp_prerelease" =~ \.([0-9]+)$ ]]; then
            prerelease_counter=$(( BASH_REMATCH[1] + 1 ))
            trace "Same base version; incrementing counter to $prerelease_counter"
        else
            trace "Could not parse counter from '$lp_prerelease'; starting at 1"
        fi
    else
        trace "Base version changed ($lp_base → $base_version); resetting counter to 1"
    fi
fi

prerelease_version="${base_version}-${prerelease_prefix}.${prerelease_counter}"
prerelease_tag="${minver_tag_prefix}${prerelease_version}"

info "Computed prerelease version: $prerelease_version [$bump_type]"

# ============================================================================
# Duplicate guard
# ============================================================================

if git rev-parse "$prerelease_tag" >"$_ignore" 2>&1; then
    error "Tag '$prerelease_tag' already exists. Possible remedy: delete the tag, or merge another PR first."
fi

exit_if_has_errors

# ============================================================================
# Output for GitHub Actions
# ============================================================================

declare -xr prerelease_version
declare -xr prerelease_tag

args_to_github_output \
    prerelease_version \
    prerelease_tag \
    reason

# Summary
{
    echo "## 🏷️ Prerelease Version: **$prerelease_version**"
    echo "- Git Tag: \`$prerelease_tag\`"
    echo "- Bump: $bump_type"
    echo "- Reason: ${reason}"
} | to_summary
