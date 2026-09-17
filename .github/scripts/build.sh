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

# Declare variables defined in the core library.
declare -x _ignore

# Declare error codes defined in the core library
declare -xri success     # The command completed successfully.
declare -xri failure     # A general, unspecified error occurred.
declare -xri err_tool_error
declare -xri err_not_found

# Define CI common variables passed in as common dotnet arguments
declare -x preprocessor_symbols
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password
declare -x configuration
declare -x framework
declare -x runtime

# parameters specific to this script only with initial values from environment variables or defaults
declare -x build_project=""

source "$script_dir/build.args.sh"
source "$script_dir/build.usage.sh"

get_arguments "$@"
build_project=${build_project:-"${BUILD_PROJECT:-}"}

# sanitize inputs
if [[ -z $build_project ]]; then
    # search for *.slnx|*.sln|*.csproj file in the current directory
    build_project=$(find . -maxdepth 1 -type f \( -name "*.slnx" -o -name "*.sln" -o -name "*.csproj" \) | head -n 1)
    [[ -n $build_project ]] || {
        error -ec "$err_not_found" "No build project (*.slnx, *.sln, *.csproj) was specified or found in the current directory."
        exit "$err_not_found"
    }
    trace "Auto-detected build project: $build_project"
fi
is_safe_valid_path "$build_project"
sanitize_common_dotnet_args "$build_project"

exit_if_has_errors

# freeze the parameters
declare -xr build_project

update_nuget_sources_with_github_vm2     || error -ec $? "Updating the NuGet sources with GitHub packages from vm2 failed."
exit_if_has_errors
dotnet_clean "$build_project"            || error -ec $? "Cleaning the build project failed."
exit_if_has_errors
dotnet_restore "$build_project"          || error -ec $? "Restoring the build project failed."
exit_if_has_errors

declare -A build_info=()
dotnet_build "$build_project" build_info || error -ec $? -sd 3 "Building the build project failed."
exit_if_has_errors

# Expose the artifacts-layout subfolder name(s) (e.g. artifacts/bin/<name>/) this leg's build actually produced, so the
# caller can archive/upload only that output instead of the whole shared artifacts/ tree -- important because a leg may
# transitively rebuild project references into the SAME shared tree, so scoping the archive avoids uploading duplicate,
# overlapping content across legs.
#
# A single project build has exactly one ArtifactsProjectName (already captured in build_info). A solution build produces
# one per constituent project -- extract_dotnet_build_info() deliberately drops that key for solutions (the raw build
# output has one PrintVersion firing per project, so a single captured value would just be whichever project happened to
# build last), so enumerate the solution's own projects and query each one's real ArtifactsProjectName directly.
declare -a artifacts_project_names=()
if [[ $build_project == *.@(sln|slnx) ]]; then
    declare -a sln_projects=()
    list_solution_projects "$build_project" sln_projects || error -ec $? "Failed to enumerate the constituent projects of '$build_project'."
    exit_if_has_errors

    declare sln_proj
    for sln_proj in "${sln_projects[@]}"; do
        declare artifacts_project_name=''
        get_msbuild_property "$sln_proj" ArtifactsProjectName artifacts_project_name ||
            error -ec $? "Failed to determine the artifacts-project-name for '$sln_proj'."
        artifacts_project_names+=("$artifacts_project_name")
    done
    exit_if_has_errors
else
    artifacts_project_names=("${build_info[$key_artifacts_project_name]:-}")
fi

declare artifacts_project_name_json
artifacts_project_name_json=$(printf '%s\n' "${artifacts_project_names[@]}" | jq -R . | jq -sc .)
printf "artifacts-project-name=%s\n" "$artifacts_project_name_json" | to_output
