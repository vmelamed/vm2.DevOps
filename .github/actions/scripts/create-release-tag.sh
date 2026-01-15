#!/bin/bash
set -euo pipefail

declare -r this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -r script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -r script_dir

source "$script_dir/_common_github.sh"

declare -x release_tag=${RELEASE_TAG:-}
declare -x reason=${REASON:-stable release}

source "$script_dir/create-release-tag.usage.sh"
source "$script_dir/create-release-tag.utils.sh"

get_arguments "$@"

# Sanitize inputs to prevent injection attacks
if [[ -n "$reason" ]] && ! is_safe_reason "$reason"; then
    error "Invalid reason: contains unsafe characters or exceeds length limit"
fi

dump_all_variables

declare -r release_tag
declare -r reason

if [[ -z "$release_tag" ]]; then
    error "Release tag is required"
fi

exit_if_has_errors

if [[ "$CI" == "true" ]]; then
    execute git config user.name "github-actions[bot]"
    execute git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi

# Ensure we have the latest changes (changelog)
if ! execute git pull --rebase; then
    error "Failed to pull latest changes from remote"
    exit 1
fi

if ! execute git tag -a "$release_tag" -m "Release $release_tag" -m "Reason: $reason"; then
    error "Failed to create tag $release_tag (may already exist)"
    exit 2
fi

execute git push origin "$release_tag"

info "Tag $release_tag created and pushed"
