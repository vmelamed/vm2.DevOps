#!/usr/bin/env bash
set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
lib_dir="$script_dir/../../../scripts/bash/lib"

declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

# constants and default values
declare -xr default_nuget_server="github"
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"
declare -xr default_repo_owner="vmelamed"

# parameters with initial values from environment variables and defaults
declare -x package_project=${PACKAGE_PROJECT:-}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-""}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}
declare -x reason=${REASON:-}
declare -x nuget_server=${NUGET_SERVER:-"$default_nuget_server"}
declare -x repo_owner=${GITHUB_REPOSITORY_OWNER:-"$default_repo_owner"}
declare -x artifacts_saved=${ARTIFACTS_SAVED:-false}
declare -x artifacts_dir=${ARTIFACTS_DIR:-artifacts/pack}

source "$script_dir/publish-package.usage.sh"
source "$script_dir/publish-package.utils.sh"

get_arguments "$@"

is_safe_path "$package_project" || true
is_safe_input "$preprocessor_symbols" || true
validate_minverTagPrefix "$minver_tag_prefix" || true
is_safe_minverPrereleaseId "$minver_prerelease_id" || true
is_safe_reason "$reason" || true
validate_nuget_server "nuget_server" || true
is_safe_input "$repo_owner" || true
is_safe_path "$artifacts_dir" || true

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

dump_all_variables
exit_if_has_errors

# restore dependencies
execute dotnet restore "${package_project}" --locked-mode

# create output directory for packed packages
execute mkdir -p "$artifacts_dir"

# build and pack the project
s=$(execute dotnet pack \
    "${package_project}" \
    --configuration Release \
    --output "$artifacts_dir" \
    --no-restore \
    "/p:DefineConstants=$preprocessor_symbols" \
    "/p:MinVerTagPrefix=$minver_tag_prefix" \
    "/p:MinVerPrereleaseIdentifiers=$minver_prerelease_id" \
    "/p:PackageReleaseNotes=Prerelease: ${reason}" | summarizeDotnetBuild)
echo "$s" | to_summary

# the build/pack
declare -x build_result
declare -x warnings_count
declare -x errors_count
declare -x assembly_version
declare -x file_version
declare -x informational_version
declare -x version
declare -x package_version

if is_semverRelease "$version"; then
    summary_header="Release Summary"
    reason="${reason:="stable release"}"
    git_tag="${minver_tag_prefix}${version}"
else
    summary_header="Prerelease Summary"
    reason="${reason:="pre-release"}"
    git_tag="N/A"
fi

# push packages to NuGet server
execute dotnet nuget push "$artifacts_dir"/*.nupkg \
    --source "$server_url" \
    --api-key "$server_api_key" \
    --skip-duplicate

{
    echo "🎯 Package(s) $package_version pushed to $server_name:"
    for f in "$artifacts_dir"/*.nupkg; do
        echo "  - $(basename "$f")"
    done
    [[ "$artifacts_saved" == "true" ]] && echo "Will be saved as workflow artifacts to $artifacts_dir."
    echo "| ## ${summary_header} |                |"
    echo "|----------------------|----------------|"
    echo "| Server               | ${server_name} |"
    echo "| Server URL           | ${server_url}  |"
    echo "| Version              | ${version}     |"
    echo "| Git Tag              | ${git_tag}     |"
    echo "| Reason               | ${reason}      |"
} | to_summary
