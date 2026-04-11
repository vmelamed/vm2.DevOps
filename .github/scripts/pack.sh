#!/usr/bin/env bash

# shellcheck disable=SC2119

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../scripts/bash/lib")

declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -xir success
declare -xir failure

# default values for parameters
declare -xr default_configuration="Release"
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"

# parameters with initial values from environment variables or defaults
declare -x package_project=${PACKAGE_PROJECT:-}
declare -x configuration=${CONFIGURATION:-"$default_configuration"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-""}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}
declare -x build=${BUILD:-false}

source "$script_dir/pack.usage.sh"
source "$script_dir/pack.args.sh"

get_arguments "$@"

# sanitize inputs
is_safe_path "$package_project" || true
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
validate_semverTagComponents "$minver_tag_prefix" "$minver_prerelease_id" || true
is_safe_boolean "$build" || true

exit_if_has_errors

# create a temporary output directory and file to capture the output of the dotnet pack command
pack_output_dir=$(mktemp -d)
trap 'rm -rf "$pack_output_dir"' EXIT
temp_output=$(mktemp)
trap 'rm -f "$temp_output"; rm -rf "$pack_output_dir"' EXIT

execute dotnet restore "${package_project}"

pack_args=(
    "${package_project}"
    "--no-restore"
    "--verbosity" "detailed"
    "--configuration" "$configuration"
    "--output" "$pack_output_dir"
    "-p:preprocessor_symbols=$preprocessor_symbols"
    "-p:MinVerTagPrefix=$minver_tag_prefix"
    "-p:MinVerPrereleaseIdentifiers=$minver_prerelease_id"
)
if ! $build; then
    pack_args+=("--no-build")
fi

execute dotnet pack "${pack_args[@]}" 2>&1 |
            extractDotnetBuildInfo |
            displayDotnetBuildSummary |
            to_summary || true # prevent pipefail from exiting before we can capture the exit code
rc="${PIPESTATUS[0]}"

nupkg_count=$(find "$pack_output_dir" -name "*.nupkg" | wc -l)
{
    if [[ $rc == "$success" ]]; then
        echo "### ✅ Pack Validation Passed"
    else
        echo "### ❌ Pack Validation Failed"
    fi
    echo ""
    echo "Project: **${package_project}**"
    echo "Packages produced: **${nupkg_count}**"
    echo ""
    for f in "$pack_output_dir"/*.nupkg; do
        [[ -f "$f" ]] && echo "  - $(basename "$f")"
    done
} | to_summary

exit "$rc"
