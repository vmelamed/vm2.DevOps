#!/bin/bash
set -euo pipefail

declare -r this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -r script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -r script_dir

source "$script_dir/_common_github.sh"

declare -xr default_nuget_server="github"
declare -xr default_minver_tag_prefix='v'
declare -xr default_repo_owner="vmelamed"

declare -x package_project=${PACKAGE_PROJECT:-}
declare -x nuget_server=${NUGET_SERVER:-"$default_nuget_server"}
declare -x minver_tag_prefix=${MINVER_TAG_PREFIX:-"$default_minver_tag_prefix"}
declare -x repo_owner=${GITHUB_REPOSITORY_OWNER:-"$default_repo_owner"}
declare -x version=${VERSION:-}
declare -x git_tag=${GIT_TAG:-}
declare -x reason=${REASON:-}
declare -x artifacts_dir=${ARTIFACTS_DIR:-artifacts/pack}
declare -x artifacts_saved=${ARTIFACTS_SAVED:-false}

source "$script_dir/publish-packages.usage.sh"
source "$script_dir/publish-packages.utils.sh"

get_arguments "$@"

# Sanitize inputs to prevent injection attacks
if [[ -n "$reason" ]] && ! is_safe_reason "$reason"; then
    error "Invalid reason: contains unsafe characters or exceeds length limit"
fi

if [[ -n "$version" ]] && ! is_safe_version "$version"; then
    error "Invalid version: must be valid semantic version"
fi

dump_all_variables

create_tag_regexes "$minver_tag_prefix"

# validate inputs
if [[ ! -s "${package_project}" ]]; then
    error "Invalid package_project file '${package_project}' specified"
fi
validate_nuget_server "$nuget_server"
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
if [[ ! "$version" =~ $semverRegex ]]; then
    error "Version '$version' is not a valid semantic version."
fi
if [[ -n "$git_tag" && ! "$git_tag" =~ $semverTagRegex ]]; then
    error "Tag '$git_tag' is not a valid Git tag."
else
    git_tag="${minver_tag_prefix}${version}"
fi
if [[ -z "$reason" ]]; then
    if [[ "$version" =~ $semverReleaseRegex ]]; then
        reason="${reason:-"stable release"}"
        summary_header="Release Summary"
    else
        reason="${reason:-"prerelease"}"
        summary_header="Prerelease Summary"
    fi
fi

exit_if_has_errors

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
    /p:MinVerTagPrefix="${minver_tag_prefix}" \
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
