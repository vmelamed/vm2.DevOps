#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"

declare -r script_dir

source "$script_dir/_common.github.sh"
source "$script_dir/_common.dotnet.sh"

# default values for parameters
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"
declare -xr default_configuration="Release"

# parameters with initial values from environment variables or defaults
declare -x build_project=${BUILD_PROJECT:-}
declare -x configuration=${CONFIGURATION:-"$default_configuration"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-""}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}
declare -x nuget_username=${GITHUB_ACTOR:-""}
declare -x nuget_password=${GITHUB_TOKEN:-""}

source "$script_dir/build.usage.sh"
source "$script_dir/build.utils.sh"

get_arguments "$@"

# sanitize inputs
is_safe_path "$build_project" || true
is_safe_input "$configuration" || true
is_safe_input "$preprocessor_symbols" || true
is_safe_input "$minver_tag_prefix" || true
is_safe_input "$minver_prerelease_id" || true
is_safe_input "$nuget_username" || true

dump_all_variables
exit_if_has_errors

# freeze the parameters
declare -xr build_project
declare -xr configuration
declare -xr preprocessor_symbols
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr nuget_username
declare -xr nuget_password

# Configure NuGet source with GitHub Packages authentication
if [[ -n "$nuget_username" && -n "$nuget_password" ]]; then
    dotnet nuget update source github.vm2 \
        --username "$nuget_username" \
        --password "$nuget_password" \
        --store-password-in-clear-text \
        --configfile NuGet.config
fi

# Restore dependencies
dotnet restore --locked-mode

# Build the project
build_output=$(dotnet build "$build_project" \
    --verbosity detailed \
    --configuration "$configuration" \
    /p:DefineConstants="$preprocessor_symbols" \
    /p:MinVerTagPrefix="$minver_tag_prefix" \
    /p:MinVerPrereleaseIdentifiers="$minver_prerelease_id" | tail -n 200)

echo "$build_output"

# Summarize the build results
summarizeDotnetBuild "$build_output" | tee -a "$github_step_summary"
