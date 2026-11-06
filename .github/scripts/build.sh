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

# core lib
source "$lib_dir/gh_core.sh"

# core lib exit codes

# core lib constants

# core lib defaults

# core lib variables
declare -x _ignore

# core lib constants
declare -xr key_artifacts_path

# this script's components
source "$script_dir/build.args.sh"
source "$script_dir/build.usage.sh"

# this script's arguments
get_arguments "$@"
declare -xr build_project

# this script's variables
declare -A build_info=()

update_nuget_sources_with_github_vm2                                                            || exit_with_error -ec "$?" "Updating the NuGet sources with GitHub packages from vm2 failed."
dotnet_clean "$build_project"                                                                   || exit_with_error -ec "$?" "Cleaning the build project failed."
dotnet_restore "$build_project"                                                                 || exit_with_error -ec "$?" "Restoring the build project failed."
dotnet_build "$build_project" build_info                                                        || exit_with_error -ec "$?" -sd 3 "Building the build project failed."

# Expose the resolved ArtifactsPath (from Directory.Build.props, already captured by dotnet_build() above) so callers
# would never need to hardcode or duplicate the "artifacts" default themselves.
printf "artifacts-path=%s\n" "${build_info[$key_artifacts_path]:-}" | to_output
