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

source "$lib_dir/gh_core.sh"

declare -xr check_em

# Declare error codes defined in the core library
declare -xri success
declare -xri err_tool_error

# Declare variables defined in the core library.
declare -x _ignore

# Define CI common variables passed in as common dotnet arguments
declare -x preprocessor_symbols
declare -x configuration
declare -x framework
declare -x runtime
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password

declare -x package_project
declare -x reason
declare -x build

source "$script_dir/pack.usage.sh"
source "$script_dir/pack.args.sh"

get_arguments "$@"

declare -x pack_exec_path
get_target_path "$package_project" pack_exec_path
declare -xr pack_exec_path

# Build when explicitly requested (--build), or when the artifacts directory has no build output for this
# project yet -- e.g. --skip-build-cache callers (template packages) that never downloaded a prior build.
if $build || [[ ! -s $pack_exec_path ]]; then
    [[ -s $pack_exec_path ||
       $package_project == vm2.Templates* ]]                                    || warning "Build output '$pack_exec_path' was not found in the artifacts directory. Building the project before packing..."
    # The templates do not have a build phase, so it is natural that the build output would not exist.
    update_nuget_sources_with_github_vm2                                        || exit_with_error "Updating the NuGet sources with GitHub packages from vm2 failed." -ec $?
    dotnet_clean "$package_project"                                             || exit_with_error "Cleaning the build project failed." -ec $?
    dotnet_restore "$package_project"                                           || exit_with_error "Restoring the build project failed." -ec $?
    dotnet_build "$package_project"                                             || exit_with_error -sd 3 "Building the build project failed." -ec $?
    [[ -s $pack_exec_path ]]                                                    || exit_with_error -sd 3 "After building, the output '$pack_exec_path' was still NOT FOUND." -ec "$err_tool_error"
fi

declare -A _pack_properties=()
dotnet_pack "$package_project" "$reason" "_pack_properties"
exit_if_has_errors

# Expose the resolved package output directory (from dotnet_pack's own MSBuild query above) so callers can locate
# the produced .nupkg/.snupkg without duplicating or guessing the "artifacts/packages" convention themselves.
# shellcheck disable=SC2034
declare package_output_path="${_pack_properties[PackageOutputPath]}"
args_to_github_output package_output_path

{
    echo "### $check_em Packages Built Successfully"
    echo ""
    echo "| Packages             |                                                       |"
    echo "|:---------------------|:------------------------------------------------------|"
    echo "| Package Id           | ${_pack_properties[PackageId]}                        |"
    echo "| Version              | ${_pack_properties[PackageVersion]}                   |"
    echo "| Package Path         | ${_pack_properties[PackagePath]}                      |"
    echo "| Symbols Package Path | ${_pack_properties[SymbolsPath]:-N/A (IncludeSymbols=false)}                      |"
    echo "| Git Tag              | $minver_tag_prefix${_pack_properties[PackageVersion]} |"
    echo ""
} | to_summary
