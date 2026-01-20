#!/bin/bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"

declare -xr script_name
declare -xr script_dir

source "$script_dir/_common.github.sh"

# constants and default values
declare -xr default_nuget_server="github"
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"
declare -xr default_repo_owner="vmelamed"

# parameters with initial values from environment variables and defaults
declare -x package_project=${PACKAGE_PROJECT:-}
declare -x nuget_server=${NUGET_SERVER:-"$default_nuget_server"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-""}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}
declare -x repo_owner=${GITHUB_REPOSITORY_OWNER:-"$default_repo_owner"}
declare -x version=${VERSION:-}
declare -x git_tag=${GIT_TAG:-}
declare -x reason=${REASON:-}
declare -x artifacts_saved=${ARTIFACTS_SAVED:-false}
declare -x artifacts_dir=${ARTIFACTS_DIR:-artifacts/pack}

source "$script_dir/publish-package.usage.sh"
source "$script_dir/publish-package.utils.sh"

get_arguments "$@"

is_valid_path "$package_project"
validate_nuget_server "$nuget_server"
is_safe_input "$preprocessor_symbols"
is_safe_input "$minver_tag_prefix"
is_safe_input "$minver_prerelease_id"
is_safe_input "$repo_owner"
is_safe_reason "$reason"
is_safe_path "$artifacts_dir"
create_tag_regexes "$minver_tag_prefix"
is_safe_semver "$version"
is_safe_semverTag "$git_tag"

# shellcheck disable=SC2154 # variable is referenced but not assigned.
# shellcheck disable=SC2153 # Possible Misspelling: MYVARIABLE may not be assigned. Did you mean MY_VARIABLE?
case "${nuget_server}" in
    github )
        server_name="GitHub Packages"
        server_url="https://nuget.pkg.github.com/${repo_owner}/index.json"
        server_api_key="${NUGET_API_GITHUB_KEY:-"${NUGET_API_KEY}"}"
        ;;
    nuget )
        server_name="NuGet.org"
        server_url="https://api.nuget.org/v3/index.json"
        server_api_key="${NUGET_API_NUGET_KEY:-"${NUGET_API_KEY}"}"
        ;;
    "https?://.+" )
        server_name="$nuget_server"
        server_url="$nuget_server"
        server_api_key="${NUGET_API_KEY}"
        ;;

    * ) error "Invalid NuGet server: $nuget_server"
        ;;
esac
if [[ -z "${server_api_key}" ]]; then
    error "No API key provided for server '$server_name'"
fi

exit_if_has_errors

if [[ -z "$reason" ]]; then
    if is_semverRelease "$version"; then
        reason="${reason:-"stable release"}"
        summary_header="Release Summary"
    else
        reason="${reason:-"prerelease"}"
        summary_header="Prerelease Summary"
    fi
fi

# restore dependencies
execute dotnet restore "${package_project}" --locked-mode

# create output directory for packed packages
execute mkdir -p "$artifacts_dir"

# build and pack the project
execute dotnet pack \
    "${package_project}" \
    --configuration Release \
    --output "$artifacts_dir" \
    --no-restore \
    "/p:DefineConstants=$preprocessor_symbols" \
    "/p:MinVerTagPrefix=$minver_tag_prefix" \
    "/p:MinVerPrereleaseIdentifiers=$minver_prerelease_id" \
    "/p:PackageReleaseNotes=Prerelease: ${reason}"

# push packages to NuGet server
execute dotnet nuget push "$artifacts_dir"/*.nupkg \
    --source "$server_url" \
    --api-key "$server_api_key" \
    --skip-duplicate

{
    printf "%s\n" "## Summary 🎯 Package(s) $git_tag pushed to $server_name:" | tee -a "$github_step_summary"
    for f in "$artifacts_dir"/*.nupkg; do
        printf "  - %s\n" "$(basename "$f")"
    done
    [[ "$artifacts_saved" == "true" ]] && printf "%s\n" "Saved as workload artifacts." | tee -a "$github_step_summary"
    printf "%s\n" "$(cat << EOF
## ${summary_header}
- Server: ${server_name}
- Server URL: ${server_url}
- Version: ${version}
- Git Tag: ${git_tag}
- Reason: ${reason}
EOF
)"
}  | tee -a "$github_step_summary"
