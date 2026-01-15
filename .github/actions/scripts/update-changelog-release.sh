#!/bin/bash
set -euo pipefail

declare -r this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -r script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -r script_dir

source "$script_dir/_common_github.sh"

declare -x release_tag=${RELEASE_TAG:-}
declare -x minver_tag_prefix=${MINVER_TAG_PREFIX:-v}

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
