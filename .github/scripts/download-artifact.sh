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

declare -xri err_missing_argument
declare -xri err_argument_type
declare -xri err_tool_not_found
declare -xri err_argument_value
declare -xri err_tool_error
declare -xri err_logic_error

declare -x artifact_name=${ARTIFACT_NAME:-}
declare -x artifacts=${ARTIFACT_DIR:-}
declare -x repository=${REPOSITORY:-}
declare -x workflow_id=${WORKFLOW_ID:-}
declare -x workflow_name=${WORKFLOW_NAME:-}
declare -x workflow_path=${WORKFLOW_PATH:-}

source "$script_dir/download-artifact.args.sh"
source "$script_dir/download-artifact.usage.sh"

get_arguments "$@"

is_safe_input "$artifact_name"  || true
if [[ -z "$artifact_name" ]]; then
    error -ec "$err_missing_argument" "The name of the artifact to download must be specified."
fi
is_safe_valid_path "$artifacts" || true
is_safe_input "$repository"     || true
is_safe_input "$workflow_id"    || true
is_safe_input "$workflow_name"  || true
is_safe_path "$workflow_path"   || true
is_natural "$workflow_id"       || error -ec "$err_argument_type" "The specified workflow identifier '$workflow_id' is not valid."

exit_if_has_errors

# freeze the variables
declare -xr artifact_name
declare -xr artifacts
declare -xr repository
declare -xr workflow_name
declare -xr workflow_path

if [[ -d "$artifacts" && -n "$(ls -A "$artifacts")" ]]; then
    renamed_artifacts_dir="$artifacts-$(date -u +"%Y%m%dT%H%M%S")"

    declare -r renamed_artifacts_dir

    choose "The artifacts' directory '$artifacts' already exists. What do you want to do?" \
           choice \
               "Delete the directory and continue" \
               "Rename the directory to '$renamed_artifacts_dir' and continue" \
               "Exit the script" || exit $?

    trace "User selected option: $choice"
    case $choice in
        1)  echo "Deleting the directory '$artifacts'..."
            execute rm -rf "$artifacts"
            ;;
        2)  echo "Renaming the directory '$artifacts' to '$renamed_artifacts_dir'..."
            execute mv "$artifacts" "$renamed_artifacts_dir"
            ;;
        3)  echo "Exiting the script."
            exit 0
            ;;
        *)  echo "Invalid option $choice. Exiting."
            exit 2
            ;;
    esac
fi

declare -x GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/stdout}
declare -x GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/stdout}

declare -x _ignore

# install GitHub CLI and jq if not already installed
if ! command -v -p jq &> "$_ignore" || ! command -v -p gh &> "$_ignore"; then
    if execute sudo apt-get update && sudo apt-get install -y gh jq; then
        info "GitHub CLI 'gh' and/or 'jq' successfully installed."
    else
        error -ec "$err_tool_not_found" "GitHub CLI 'gh' and/or 'jq' were not found and could not install them. Please have 'gh' and 'jq' installed."
        exit "$err_tool_not_found"
    fi
fi

declare -a runs
declare query

# get the workflow ID if not provided
# query for the workflow ID using the name or path
if [[ -z "$workflow_id" ]]; then
    if [[ -n "$workflow_name" ]]; then
        query=".[] | select(.name==\"$workflow_name\").id"
    elif [[ -n "$workflow_path" ]]; then
        query=".[] | select(.path==\"$workflow_path\").id"
    else
        error -ec "$err_missing_argument" "Either the workflow id, the workflow name, or the workflow path must be specified."
    fi
fi
exit_if_has_errors

workflow_id=$(execute gh workflow list --repo "$repository" --json "id,name,path" --jq "$query")

if is_dry_run; then
    workflow_id=1234567890
fi

if ! is_natural "$workflow_id"; then
    if [[ -n "$workflow_path" ]]; then
        error -ec "$err_argument_value" "The specified workflow path '$workflow_path' does not exist in the repository '$repository'."
    elif [[ -n "$workflow_name" ]]; then
        error -ec "$err_argument_value" "The specified workflow name '$workflow_name' does not exist in the repository '$repository'."
    else
        error -ec "$err_argument_value" "The specified workflow identifier '$workflow_id' is not valid."
    fi
    exit_if_has_errors
fi

# get the IDs of the last 1000 successful runs of the specified workflow
readarray -t runs < <(
    gh run list \
        --repo "$repository" \
        --workflow "$workflow_id" \
        --status success \
        --limit 100 \
        --json databaseId \
        --jq '.[].databaseId')

if [[ ${#runs[@]} == 0 ]]; then
    error -ec "$err_logic_error" "No successful runs found for the workflow '$workflow_id' in the repository '$repository'."
    exit "$err_logic_error"
fi

# iterate over the runs and try to find and download the specified artifact
# starting from the most recent one down to the oldest one
i=0
for run in "${runs[@]}"; do
    i=$((i + 1))
    trace "Checking run $run for the artifact '$artifact_name'..."
    query="any(.artifacts[]; .name==\"$artifact_name\")"
    if [[ $(gh api "repos/$repository/actions/runs/$run/artifacts" --jq "$query") != true ]]; then
        echo "The artifact '$artifact_name' not found in run $run." >> "$GITHUB_STEP_SUMMARY"
        continue
    fi

    if ((i > 80)); then
        warning "The artifact was found in run $i out of 100. \
You may want to refresh the artifact. \
E.g. re-run the benchmarks with --force-new-baseline or vars.FORCE_NEW_BASELINE" >&2
    fi
    trace "The artifact '$artifact_name' found in run $run. Downloading..."
    if ! http_error=$(execute gh run download "$run" \
                                --repo "$repository" \
                                --name "$artifact_name" \
                                --dir "$artifacts") ; then
        error -ec "$err_tool_error" "Error while downloading '$artifact_name': $http_error"
        exit "$err_tool_error"
    fi
    info "✅ The artifact '$artifact_name' successfully downloaded to directory '$artifacts'." >> "$GITHUB_STEP_SUMMARY"
    exit 0
done

error -ec "$err_logic_error" "The artifact '$artifact_name' was not found in the last ${#runs[@]} successful runs of the workflow '$workflow_name' in the repository '$repository'."
exit "$err_logic_error"
