#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
lib_dir="$script_dir/../../../scripts/bash/lib"

declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -xr default_minver_tag_prefix='v'

declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x release_tag=${RELEASE_TAG:-}
declare -x reason=${REASON:-stable release}

source "$script_dir/create-release-tag.usage.sh"
source "$script_dir/create-release-tag.utils.sh"

get_arguments "$@"

# Sanitize inputs to prevent injection attacks
is_safe_reason "$reason" || true
is_safe_minverTagPrefix "$minver_tag_prefix" || true
create_tag_regexes "$minver_tag_prefix" || true
is_safeReleaseTag "$release_tag" || true

declare -xr release_tag
declare -xr reason

dump_all_variables
exit_if_has_errors

# shellcheck disable=SC2154 # ci is referenced but not assigned.
if [[ "$ci" == "true" ]]; then
    execute git config user.name "github-actions[bot]"
    execute git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi

# Ensure we have the latest changes (changelog)
if ! execute git pull --rebase; then
    error "Failed to pull latest changes from remote"
    exit 2
fi

if ! execute git tag -a "$release_tag" -m "Release $release_tag" -m "Reason: $reason"; then
    error "Failed to create tag $release_tag (does it already exist?)"
    exit 2
fi

execute git push origin "$release_tag"

info "Tag $release_tag created and pushed"
