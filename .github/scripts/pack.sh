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

# variables specific to this script only with initial values from environment variables or defaults
declare -x package_project=""
declare -x reason=${REASON:-}
declare -x build=${BUILD:-false}

source "$script_dir/pack.usage.sh"
source "$script_dir/pack.args.sh"

get_arguments "$@"
package_project=${package_project:-"$PACKAGE_PROJECT"}

# validate the values of the variables common for many vm2.DevOps scripts,
# usually set from CLI arguments, environment variables, or defaults
is_safe_existing_file "$package_project"       || true
[[ $package_project == *.csproj ]]             || error "The script '${script_name}' accepts only project files (*.csproj) - not solutions (*.sln or *.slnx)."
is_safe_reason "$reason"                       || true
is_boolean "$build"                            || true
sanitize_common_dotnet_args "$package_project" || true

exit_if_has_errors

# freeze the parameters
declare -xr package_project
# declare -xr reason
declare -xr build

if $build; then
    dotnet_restore "$package_project"
    exit_if_has_errors

    dotnet_build "$package_project"
    exit_if_has_errors
fi

declare -A _pack_properties=()
dotnet_pack "$package_project" "$reason" "_pack_properties"
exit_if_has_errors

{
    echo "### ✅ Packages Built Successfully"
    echo ""
    echo "| Packages             |                                                       |"
    echo "|:---------------------|:------------------------------------------------------|"
    echo "| Package Id           | ${_pack_properties[PackageId]}                        |"
    echo "| Version              | ${_pack_properties[PackageVersion]}                   |"
    echo "| Package Path         | ${_pack_properties[PackagePath]}                      |"
    echo "| Symbols Package Path | ${_pack_properties[SymbolsPath]}                      |"
    echo "| Git Tag              | $minver_tag_prefix${_pack_properties[PackageVersion]} |"
    echo ""
} | to_summary
