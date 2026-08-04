#!/usr/bin/env bash

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
declare -rxi err_tool_error
declare -rxi err_logic_error
declare -rxi err_argument_value

# constants and default values
declare -xr default_nuget_server="nuget"
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"
declare -xr default_repo_owner="vmelamed"

declare -rx default_configuration

# parameters with initial values from environment variables or defaults
declare -x package_project=""
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-""}
declare -x configuration=${CONFIGURATION:-"$default_configuration"}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"$default_minver_prerelease_id"}
declare -x reason=${REASON:-}
declare -x build=${BUILD:-false}
declare -x artifacts_dir=${ARTIFACTS_DIR:-artifacts}

source "$script_dir/pack.usage.sh"
source "$script_dir/pack.args.sh"

get_arguments "$@"
package_project=${package_project:-"$PACKAGE_PROJECT"}

# sanitize inputs
is_safe_boolean "$build" || true
is_safe_path "$artifacts_dir" || true
is_safe_path "$package_project" || true
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
validate_semverTagComponents "$minver_tag_prefix" "$minver_prerelease_id" || true
is_safe_reason "$reason" || true

exit_if_has_errors

# create output directory for the packages
declare -x artifacts_packages_dir="$artifacts_dir/packages"
execute mkdir -p "$artifacts_packages_dir"

# restore the project if the build is requested, otherwise skip restore and build - assume they are done already
$build && execute dotnet restore "$package_project" --locked-mode

# prepare the arguments for the dotnet pack command
dotnet_pack_arguments=(
    "$package_project"
    "--verbosity" "detailed"
    "--configuration" "$configuration"
    "--output" "$artifacts_packages_dir"
    "--no-restore"
    "-p:preprocessor_symbols=$preprocessor_symbols"
    "-p:MinVerTagPrefix=$minver_tag_prefix"
    "-p:MinVerPrereleaseIdentifiers=$minver_prerelease_id"
    "-p:PackageReleaseNotes=\"$reason\""
)
$build || dotnet_pack_arguments+=(
    "--no-build"
)

# build and pack the project
temp_output=$(mktemp)
build_info_output=$(mktemp)
trap 'rm -f "$temp_output" "$build_info_output"' EXIT

# execute the dotnet pack command and process its output
rc=$success
execute dotnet pack "${dotnet_pack_arguments[@]}" > "$temp_output" 2>&1 || rc=$?

# Run extractDotnetBuildInfo directly in THIS shell (not as the left side of a pipe or inside a
# $(...) command substitution, either of which would run it in a subshell and lose its variable
# assignments) so it can populate $version, $package_version, etc. for use below. Its stdout (the
# key=value pairs) is captured to a file and replayed into displayDotnetBuildSummary for the
# human-readable report.
extractDotnetBuildInfo < "$temp_output" > "$build_info_output"
displayDotnetBuildSummary < "$build_info_output" | to_summary

[[ $rc == "$success" ]] ||
    error -ec "$err_tool_error" "Packing '$package_project' failed."
exit_if_has_errors

nupkg_count=$(find "$artifacts_packages_dir" -name "*.nupkg" | wc -l)
version=$(get_build_info version)

if is_semverRelease "$version"; then
    summary_header="Release Summary"
    reason="${reason:="stable release"}"
else
    summary_header="Pre-release Summary"
    reason="${reason:="pre-release"}"
fi

{
    [[ $nupkg_count == 1 ]] &&
        echo "### ✅ 1 Package Built Successfully" ||
        echo "### ✅ $nupkg_count Packages Built Successfully"
    echo ""
    echo "| $summary_header   |                |"
    echo "|:------------------|:---------------|"
    echo "| Version           | $version       |"
    echo "| Reason            | $reason        |"
    echo ""
    echo "Packages:"
    for f in "$artifacts_dir"/*.nupkg; do
        [[ -f "$f" ]] && echo "  - $(basename "$f")"
    done
} | to_summary
