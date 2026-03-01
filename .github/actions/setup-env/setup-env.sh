#!/usr/bin/env bash
# Determines the correct paths and adds DevOps scripts to PATH.
# Works for both internal (vm2.DevOps) and external repos.

set -euo pipefail

declare -x GITHUB_WORKSPACE
declare -x GITHUB_PATH
declare -x GITHUB_ENV

if [[ -d "${GITHUB_WORKSPACE}/vm2-devops" ]]; then
    # We're running inside vm2.DevOps
    base="${GITHUB_WORKSPACE}/vm2-devops"
else
    # We're running outside vm2.DevOps itself
    base="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../../../")"
fi

# we need the scripts in these two directories:
scripts_dir="${base}/.github/scripts"
lib_dir="${base}/scripts/bash/lib"

{
    echo "$scripts_dir"
    echo "$lib_dir"
} >> "$GITHUB_PATH"

{
    echo "DEVOPS_SCRIPTS_DIR=$scripts_dir"
    echo "DEVOPS_LIB_DIR=$lib_dir"
} >> "$GITHUB_ENV"

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
# source the gh_core.sh script but we still cannot use GITHUB_PATH and GITHUB_ENV, so we use the direct $lib_dir
source "$lib_dir/gh_core.sh"

echo "ℹ️  INFO: DevOps scripts and libraries are now available in PATH
    DEVOPS_SCRIPTS_DIR='$scripts_dir'
    DEVOPS_LIB_DIR='$lib_dir'
    GITHUB_PATH='$GITHUB_PATH'
"
