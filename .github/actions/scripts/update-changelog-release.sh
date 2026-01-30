#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
lib_dir="$script_dir/../../../scripts/bash/lib"

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -x minver_tag_prefix=${MINVERTAGPREFIX:-v}

source "$script_dir/update-changelog-release.usage.sh"
source "$script_dir/update-changelog-release.utils.sh"

declare -x release_tag
declare -x minver_tag_prefix

get_arguments "$@"

is_semverReleaseTag "$release_tag"
validate_minverTagPrefix "$minver_tag_prefix"

if [[ -z "$release_tag" ]]; then
    error "Release tag is required" >&2
fi
if [[ ! -f changelog/cliff.release-header.toml ]]; then
    warning "Missing changelog/cliff.release-header.toml; skipping changelog update."
    exit 0
fi

dump_all_variables
exit_if_has_errors

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
    # shellcheck disable=SC2154 # CI is referenced but not assigned.
    if [[ "$CI" == "true" ]]; then
        execute git config user.name "github-actions[bot]"
        execute git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    fi
    execute git add CHANGELOG.md
    execute git commit -m "chore: update changelog for $release_tag"
    execute git push
    info "✅ CHANGELOG updated and pushed"
else
    warning "No changelog changes to commit"
fi
