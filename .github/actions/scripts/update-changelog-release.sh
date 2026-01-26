#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
lib_dir="$script_dir/../../../scripts/bash/lib"
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./github.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/github.sh"

declare -x minver_tag_prefix=${MINVERTAGPREFIX:-v}

source "$script_dir/update-changelog-release.usage.sh"
source "$script_dir/update-changelog-release.utils.sh"

get_arguments "$@"

dump_all_variables

declare -xr release_tag
declare -xr minver_tag_prefix

create_tag_regexes "$minver_tag_prefix"

if [[ -z "$release_tag" ]]; then
    error "Release tag is required" >&2
fi
if [[ ! -f changelog/cliff.release-header.toml ]]; then
    warning "Missing changelog/cliff.release-header.toml; skipping changelog update."
    exit 0
fi

exit_if_has_errors

# Use the range from last stable tag to HEAD
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
