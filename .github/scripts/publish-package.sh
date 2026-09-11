#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following
source "$lib_dir/gh_core.sh"

# Declare error codes defined in the core library
declare -xri success
declare -xri err_tool_error

# Declare defaults defined in the core library.
declare -xr default_nuget_server
declare -xr default_repo_owner

# Declare variables defined in the core library.
declare -x _ignore

# Define CI common variables passed in as common dotnet arguments
declare -x preprocessor_symbols
declare -x configuration
declare -x framework
declare -x runtime
declare -x artifacts
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password

# parameters specific to this script only with initial values from environment variables or defaults
declare -x package_project=""
declare -x reason=${REASON:-}
declare -x nuget_server=${NUGET_SERVER:-"$default_nuget_server"}
declare -x repo_owner=${GITHUB_REPOSITORY_OWNER:-"$default_repo_owner"}
declare -x save_artifacts=${SAVE_ARTIFACTS:-false}
declare -x server_api_key=${NUGET_API_KEY:-}

declare nuget_server_name
declare nuget_server_url

source "$script_dir/publish-package.usage.sh"
source "$script_dir/publish-package.args.sh"

get_arguments "$@"
package_project=${package_project:-"$PACKAGE_PROJECT"}

is_safe_existing_file "$package_project"                                      || true
[[ $package_project == *.csproj ]]                                            || error "The script '${script_name}' accepts only project files (*.csproj) - not solutions (*.sln or *.slnx)."
is_safe_reason "$reason"                                                      || true
is_safe_input "$repo_owner"                                                   || true
validate_nuget_server nuget_server nuget_server_name nuget_server_url "nuget" || true
sanitize_common_dotnet_args "$package_project"                                || true

exit_if_has_errors

declare -A properties=()

dotnet_pack "$package_project" "$reason" properties
exit_if_has_errors

package=${properties["PackagePath"]}
symbols=${properties["SymbolsPath"]}
version=${properties["Version"]}
id=${properties["PackageId"]}

if is_semverRelease "$version"; then
    summary_header="Release Summary"
    reason="${reason:-"Stable release of $id"}"
else
    summary_header="Pre-release Summary"
    reason="${reason:-"Pre-release of $id"}"
fi
declare git_tag="$minver_tag_prefix$version"

# push packages to NuGet server
{
    if [[ -n $nuget_server_url && -n $server_api_key ]]; then
        execute dotnet nuget push "$artifacts"/*.nupkg \
            --source "$nuget_server_url" \
            --api-key "$server_api_key" \
            --skip-duplicate

        echo "🎯 $id packages $git_tag were released to $nuget_server_name:"
    else
        echo "🎯 $id packages $git_tag were **NOT** released to $nuget_server_name:"
    fi
    echo "  - $(basename "$package")"
    echo "  - $(basename "$symbols")"
    echo ""
    [[ "$save_artifacts" == true ]] && echo "Will be saved as workflow artifacts to $artifacts."
    echo ""
    echo "| $summary_header   |                    |"
    echo "|:------------------|:-------------------|"
    echo "| Server            | $nuget_server_name |"
    echo "| Server URL        | $nuget_server_url  |"
    echo "| Version           | $version           |"
    echo "| Git Tag           | $git_tag           |"
    echo "| Reason            | $reason            |"
} | to_summary
