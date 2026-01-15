#!/bin/bash
set -euo pipefail

declare -xr this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

source "$script_dir/_common_github.sh"

declare -xr default_package_projects='[""]'
declare -xr default_nuget_server='nuget'
declare -xr default_minver_tag_prefix='v'
declare -xr default_reason="release build"

declare -x package_projects=${PACKAGE_PROJECTS:-"$default_package_projects"}
declare -x nuget_server=${NUGET_SERVER:-"$default_nuget_server"}
declare -x minver_tag_prefix=${MINVER_TAG_PREFIX:-"$default_minver_tag_prefix"}
declare -x reason=${REASON:-"$default_reason"}

source "$script_dir/compute-release-version.usage.sh"
source "$script_dir/compute-release-version.utils.sh"

get_arguments "$@"

# Sanitize inputs to prevent injection attacks
if [[ -n "$reason" ]] && ! is_safe_reason "$reason"; then
    error "Invalid reason: contains unsafe characters or exceeds length limit"
fi

if ! is_safe_nuget_server "$nuget_server"; then
    error "Invalid nuget-server: must be 'nuget', 'github', or a valid https:// URL"
fi

dump_all_variables

declare -xr package_projects
declare -xr nuget_server
declare -xr minver_tag_prefix

create_tag_regexes "$minver_tag_prefix"

# Validate NuGet server and package projects (these do not affect release version computation)
# but are here to fail fast if misconfigured
validate_projects "package_projects" "$default_package_projects"

# Validate NuGet server (does not affect release version computation)
validate_nuget_server "nuget_server" "$default_nuget_server"

# Find latest stable and prerelease tags
latest_stable=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1 || echo "")

declare -i major=0
declare -i minor=0
declare -i patch=0

if [[ -n "$latest_stable" && $latest_stable =~ $semverTagReleaseRegex ]]; then
    major=${BASH_REMATCH[$semver_major]}
    minor=${BASH_REMATCH[$semver_minor]}
    patch=${BASH_REMATCH[$semver_patch]}
    if ((major <= 0 || minor < 0 || patch < 0)); then
        error "Invalid version numbers in latest stable tag '$latest_stable': $major.$minor.$patch. Major must be > 0, minor and patch must be >= 0."
    else
        info "📌 Latest stable release: $latest_stable ($major.$minor.$patch)"
    fi
else
    info "📌 No previous stable release found; starting at 0.0.0"
fi

# Auto-detect from conventional commits
last_tag="${latest_stable:-$(git rev-list --max-parents=0 HEAD)}"
commits=$(git log "$last_tag"..HEAD --pretty=format:"%s" 2>"$_ignore" || echo "")

if echo "$commits" | grep -qiE '^[a-z]+(\(.+\))?!:|BREAKING CHANGE:'; then
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
    major=1
fi

release_version="$major.$minor.$patch"

# make sure the computed version so far is not lower than the latest prerelease
latest_prerelease_tag=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagPrereleaseRegex" | sort -V | tail -n1 || echo "")

if [[ -n "$latest_prerelease_tag" ]]; then
    latest_prerelease_version="${latest_prerelease_tag#"$minver_tag_prefix"}"
    # compare calculated so far release_version with latest_prerelease_version
    compare_semver "$release_version" "$latest_prerelease_version"
    if (( $? == isLt )) && [[ $latest_prerelease_version =~ $semverPrereleaseRegex ]]; then
        # we calculated a version that is less than the latest prerelease version,
        # so adopt the major, minor, and patch from it
        major=${BASH_REMATCH[$semver_major]}
        minor=${BASH_REMATCH[$semver_minor]}
        patch=${BASH_REMATCH[$semver_patch]}
        release_version="$major.$minor.$patch"
    fi
fi

info "🤖 Calculated new release version: $release_version [$bump_type]"

release_tag="${minver_tag_prefix}${release_version}"

declare -xr release_version
declare -xr release_tag

# Check if tag already exists
if git rev-parse "$release_tag" >"$_ignore" 2>&1; then
    error "Tag '$release_tag' already exists. Possible remedy: branch 'main' again, and do a new PR and release with a higher version number."
fi

exit_if_has_errors

# Output for GitHub Actions
args_to_github_output \
  package_projects \
  nuget_server \
  minver_tag_prefix \
  release_version \
  release_tag \
  reason

# Summary
summary "$(cat << EOF
## 🎯 Release Version: **$release_version**
- Git Tag: \`$release_tag\`
## Release version
- Reason: ${reason:-"release build"}
- Manual version: ${manual_version:-"none - automatic versioning"}
EOF
)"
