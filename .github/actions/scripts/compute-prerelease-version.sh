#!/bin/bash
set -euo pipefail

declare -r this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -r script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -r script_dir

source "$script_dir/_common.github.sh"

default_github_run_number="$(date -u +%H%M%S)"
declare -xr default_github_run_number

declare -xr default_package_projects='[""]'
declare -xr default_nuget_server="nuget"
declare -xr default_minver_tag_prefix='v'
declare -xr default_semver_prerelease_prefix="preview"
declare -xr default_reason="prerelease build"

declare -x package_projects=${PACKAGE_PROJECTS:-"$default_package_projects"}
declare -x nuget_server=${NUGET_SERVER:-"$default_nuget_server"}
declare -x minver_tag_prefix=${MinVerTagPrefix:-"$default_minver_tag_prefix"}
declare -x semver_prerelease_prefix=${SEMVER_PRERELEASE_PREFIX:-"$default_semver_prerelease_prefix"}
declare -x reason=${REASON:-"$default_reason"}

source "$script_dir/compute-prerelease-version.usage.sh"
source "$script_dir/compute-prerelease-version.utils.sh"

get_arguments "$@"

# Sanitize inputs to prevent injection attacks
if ! is_safe_nuget_server "$nuget_server"; then
    error "Invalid nuget-server: must be 'nuget', 'github', or a valid https:// URL"
fi
if ! is_safe_input "$semver_prerelease_prefix"; then
    error "Invalid semver-prerelease-prefix: contains unsafe characters"
fi
if [[ -n "$reason" ]] && ! is_safe_reason "$reason"; then
    error "Invalid reason: contains unsafe characters or exceeds length limit"
fi

declare -xr package_projects
declare -xr nuget_server
declare -xr minver_tag_prefix
declare -xr semver_prerelease_prefix
declare -xr reason

dump_all_variables

create_tag_regexes "$minver_tag_prefix"

# Validate NuGet server and package projects (these do not affect release version computation)
# but are here to fail fast if misconfigured
validate_projects "package_projects" "$default_package_projects"

# Validate NuGet server (does not affect release version computation)
validate_nuget_server "nuget_server" "$default_nuget_server"

# detect if the head is already tagged
head_tag=$(git tag --points-at HEAD)
if [[ -n $head_tag ]]; then
    error "The HEAD is already tagged with '$head_tag'. Possible remedy: delete the tag, or branch 'main' again, do a new PR, and release with a new, higher version number."
fi

exit_if_has_errors

# Find latest stable tag like v1.2.3
latest_stable=$(git tag --list "${minver_tag_prefix}*" | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1 || echo "")

declare -i major=0
declare -i minor=0
declare -i patch=0

if [[ $latest_stable =~ $semverTagReleaseRegex ]]; then
    major=${BASH_REMATCH[$semver_major]}
    minor=${BASH_REMATCH[$semver_minor]}
    patch=${BASH_REMATCH[$semver_patch]}
    if ((major <= 0 || minor < 0 || patch < 0)); then
        error "Invalid version numbers in latest stable tag '$latest_stable': $major.$minor.$patch. Major must be > 0, minor and patch must be >= 0."
        exit 2
    fi
    info "📌 Latest stable release: $latest_stable ($major.$minor.$patch)"
    patch=$(( patch + 1 ))
else
    # No stable tag yet - start with v0.1.0
    info "📌 No previous stable release found; starting at 0.1.0"
    major=0
    minor=1
    patch=0
fi

comp_semver_prerelease="$semver_prerelease_prefix.$(date -u +%Y%m%d).${GITHUB_RUN_NUMBER:-"$default_github_run_number"}"
prerelease_version="${major}.${minor}.${patch}-$comp_semver_prerelease"
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
