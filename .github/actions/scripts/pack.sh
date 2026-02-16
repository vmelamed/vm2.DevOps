#!/usr/bin/env bash
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../../scripts/bash/lib")

declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

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

source "$script_dir/pack.usage.sh"
source "$script_dir/pack.utils.sh"

get_arguments "$@"

dump_vars --quiet \
    --header "Inputs" \
    package_project \
    configuration \
    preprocessor_symbols \
    minver_tag_prefix \
    minver_prerelease_id

# sanitize inputs
is_safe_path "$package_project" || true
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
validate_minverTagPrefix "$minver_tag_prefix" || true
is_safe_minverPrereleaseId "$minver_prerelease_id" || true

dump_all_variables
exit_if_has_errors

# create a temporary output directory for packed packages
pack_output_dir=$(mktemp -d)
trap 'rm -rf "$pack_output_dir"' EXIT

# pack the project (validation only — no restore, no build)
temp_output=$(mktemp)
trap 'rm -f "$temp_output"; rm -rf "$pack_output_dir"' EXIT

pack_exit=0
execute dotnet pack \
    "${package_project}" \
    --configuration "$configuration" \
    --output "$pack_output_dir" \
    --no-build \
    --no-restore \
    "-p:preprocessor_symbols=$preprocessor_symbols" \
    "-p:MinVerTagPrefix=$minver_tag_prefix" \
    "-p:MinVerPrereleaseIdentifiers=$minver_prerelease_id" > "$temp_output" 2>&1 || pack_exit=$?

# shellcheck disable=SC2005 # Useless echo? Instead of 'echo $(cmd)', just use 'cmd'.
echo "$(summarizeDotnetBuild < "$temp_output")" | to_summary

if [[ $pack_exit -eq 0 ]]; then
    nupkg_count=$(find "$pack_output_dir" -name "*.nupkg" | wc -l)
    {
        echo "### ✅ Pack Validation Passed"
        echo ""
        echo "Project: **${package_project}**"
        echo "Packages produced: **${nupkg_count}**"
        echo ""
        for f in "$pack_output_dir"/*.nupkg; do
            [[ -f "$f" ]] && echo "  - $(basename "$f")"
        done
    } | to_summary
fi

exit "$pack_exit"
