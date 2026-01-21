#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"

declare -xr script_name
declare -xr script_dir

source "$script_dir/_common.github.sh"

# default constants for parameters
declare -xr default_package_projects='[""]'
declare -xr default_nuget_server="nuget"
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id='preview.0'
declare -xr default_reason="prerelease build"

# parameters with initial values from environment variables or defaults
declare -x package_projects=${PACKAGE_PROJECTS:-"$default_package_projects"}
declare -x nuget_server=${NUGET_SERVER:-"$default_nuget_server"}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}
declare -x reason=${REASON:-"$default_reason"}

# GitHub run date and number for prerelease versioning
github_run_date="$(date -u +%Y%m%d)"
github_run_number="${GITHUB_RUN_NUMBER:-"$(date -u +%H%M%S)"}"

declare -r github_run_date
declare -r github_run_number

source "$script_dir/compute-prerelease-version.usage.sh"
source "$script_dir/compute-prerelease-version.utils.sh"

get_arguments "$@"

# Sanitize inputs to prevent injection attacks
are_safe_projects "package_projects" "$default_package_projects" || true
validate_nuget_server "nuget_server" "$default_nuget_server" || true
is_safe_input "$minver_tag_prefix" || true
is_safe_input "$minver_prerelease_id" || true
is_safe_reason "$reason" || true
# detect if the head is already tagged
head_tag=$(git tag --points-at HEAD)
if [[ -n $head_tag ]]; then
    error "The HEAD is already tagged with '$head_tag'. Possible remedy: delete the tag, or branch 'main' again, do a new PR, and release with a new, higher version number." || true
fi

dump_all_variables
exit_if_has_errors

# freeze the parameters
declare -xr package_projects
declare -xr nuget_server
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr reason

create_tag_regexes "$minver_tag_prefix"

# Find latest stable tag like v1.2.3
latest_stable=$(git tag --list "${minver_tag_prefix}[0-9]*" | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1 || echo "")

declare -i major=0
declare -i minor=0
declare -i patch=0

if is_semverReleaseTag "$latest_stable"; then
    major=${BASH_REMATCH[$semver_major]}
    minor=${BASH_REMATCH[$semver_minor]}
    patch=${BASH_REMATCH[$semver_patch]}
    if ((major <= 0 || minor < 0 || patch < 0)); then
        error "Invalid version numbers in latest stable tag '$latest_stable': $major.$minor.$patch. Major must be > 0, minor and patch must be >= 0."
        exit 2
    fi
    info "📌 Latest stable release: $latest_stable"
    patch=$(( patch + 1 ))
else
    # No stable tag yet - start with v0.1.0
    info "📌 No previous stable release found; starting at 0.1.0"
    major=0
    minor=1
    patch=0
fi

semver_prerelease="$minver_prerelease_id.$github_run_date.$github_run_number"
prerelease_version="${major}.${minor}.${patch}-$semver_prerelease"
prerelease_tag="${minver_tag_prefix}$prerelease_version"

# Check if tag already exists
if git rev-parse "$prerelease_tag" >"$_ignore" 2>&1; then
    error "Tag '$prerelease_tag' already exists. Possible remedy: delete it, or branch 'main' again, and do a new PR and release with a higher version number."
fi
exit_if_has_errors

# Output for GitHub Actions
args_to_github_output \
  package_projects \
  nuget_server \
  minver_tag_prefix \
  minver_prerelease_id \
  prerelease_version \
  prerelease_tag \
  reason

# Summary

summary "$(cat << EOF
✅ Prerelease Version: **$prerelease_version**
- Git Tag: \`$prerelease_tag\`
## Prerelease Reason:
- Reason: ${reason:-"prerelease build"}
EOF
)"
