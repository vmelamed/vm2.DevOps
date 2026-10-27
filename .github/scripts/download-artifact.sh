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

# core constants
declare -xr check_em

declare -x _ignore

declare -xri failure
declare -xri err_missing_argument
declare -xri err_argument_type
declare -xri err_tool_not_found
declare -xri err_argument_value
declare -xri err_tool_error
declare -xri err_logic_error

# script arguments
declare -x artifact_name
declare -x artifacts
declare -x repository
declare -x workflow_id
declare -x workflow_name
declare -x workflow_path

source "$script_dir/download-artifact.args.sh"
source "$script_dir/download-artifact.usage.sh"

get_arguments "$@"

[[ -n $repository ]] ||
    repository=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>"$_ignore") ||
        exit_with_error -ec "$err_not_found" "The current directory is not in a GitHub repository; use '--repository <owner/repo>'."

readonly repository

declare -a runs
declare query

# get the workflow ID if not provided
# query for the workflow ID using the name or path
#
# NOTE: this block implements a precedence for determining the workflow ID:
#       1. Use the provided workflow ID if available.
#       2. Otherwise, use the workflow name if provided.
#       3. Otherwise, use the workflow path if provided.
#       4. If none of the above are provided, exit with an error.
if [[ -z "$workflow_id" ]]; then
    # shellcheck disable=SC2016 # Expressions don't expand in single quotes, use double quotes for that.
    if [[ -n "$workflow_name" ]]; then
        query='.[] | select(.name==$n).id'
    elif [[ -n "$workflow_path" ]]; then
        query='.[] | select(.path==$p).id'
    else
        exit_with_error -ec "$err_missing_argument" "Either the workflow id, the workflow name, or the workflow path must be specified."
    fi

    declare _workflows
    declare -a workflow_ids=()
    declare what=''

    _workflows=$(gh workflow list --repo "$repository" --json "id,name,path") ||
        exit_with_error -ec "$err_tool_error" "Could not list the workflows of '$repository'."

    readarray -t workflow_ids < <(jq -r --arg n "$workflow_name" --arg p "$workflow_path" "$query" <<< "$_workflows")

    case "${#workflow_ids[@]}" in
        0)  [[ -n "$workflow_name" ]] &&
                what="path '$workflow_name'" ||
                what="name '$workflow_path'"
            error -ec "$err_argument_value" "The specified workflow $what is not in the repository '$repository'."
            ;;
        1)  workflow_id="${workflow_ids[0]}"
            ;;
        *)  exit_with_error -ec "$err_argument_value" "Multiple workflows found: ${workflow_ids[*]}"
            ;;
    esac
fi
exit_if_has_errors

execute mkdir -p "$artifacts" || exit_with_error -ec "$err_tool_error" "Failed to create artifacts directory."

if [[ -d "$artifacts" && -n "$(ls -A "$artifacts")" ]]; then
    renamed_artifacts_dir="$artifacts-$(date -u +"%Y%m%dT%H%M%S")"

    declare -r renamed_artifacts_dir
    declare choice

    choose "The artifacts' directory '$artifacts' already exists. What do you want to do?" \
           choice \
               "Delete the directory and continue" \
               "Rename the directory to '$renamed_artifacts_dir' and continue" \
               "Exit the script"

    trace "User selected option: $choice"
    case $choice in
        1)  warning "Deleting the directory '$artifacts'..."
            execute rm -rf "$artifacts"
            ;;
        2)  info "Renaming the directory '$artifacts' to '$renamed_artifacts_dir'..."
            execute mv "$artifacts" "$renamed_artifacts_dir"
            ;;
        3)  trace "Exiting the script."
            exit 0
            ;;
        *)  exit_with_error -ec "$failure" -ns "Invalid option $choice. Exiting."
            ;;
    esac
fi

readonly workflow_id

declare -i rc=$success
declare _temp=''
_temp=$(mktemp) || exit_with_error -ec "$err_tool_error" "Failed to create a temporary file."

# get the IDs of the last 100 successful runs of the specified workflow
gh run list \
    --repo "$repository" \
    --workflow "$workflow_id" \
    --status success \
    --limit 100 \
    --json databaseId \
    --jq '.[].databaseId' > "$_temp" || rc=$?

(( rc != success ))   || readarray -t runs < "$_temp"   || rc=$err_tool_error
rm -f "$_temp"                                          || true
(( rc == success ))                                     || exit_with_error -ec "$rc" "Failed to retrieve the list of runs for the workflow '$workflow_id' in the repository '$repository'."
(( ${#runs[@]} > 0 ))                                   || exit_with_error -ec "$err_logic_error" "No successful runs found for the workflow '$workflow_id' in the repository '$repository'."

# iterate over the runs and try to find and download the specified artifact
# starting from the most recent one down to the oldest one
i=0
for run in "${runs[@]}"; do
    (( ++i ))
    trace "Checking run $run for the artifact '$artifact_name'..."

    artifacts_list=$(gh api "repos/$repository/actions/runs/$run/artifacts") ||
        exit_with_error -ec "$err_tool_error" "Could not list the artifacts of run $run."

    artifact_present=$(jq -r --arg n "$artifact_name" 'any (.artifacts[]; .name==$n)' <<< "$artifacts_list")

    if ! $artifact_present; then
        trace "The artifact '$artifact_name' not found in run $run."
        continue
    fi

    trace "The artifact '$artifact_name' found in run $run."
    if ((i > 80)); then
        warning "The artifact was found in run $i out of ${#runs[@]}." \
                "You may want to refresh the artifact."
    fi

    download_result=$(execute gh run download "$run" \
                            --repo "$repository" \
                            --name "$artifact_name" \
                            --dir "$artifacts" 2>&1) ||
        exit_with_error -ec "$err_tool_error" "Error while downloading '$artifact_name': $download_result"
    # the above capture also swallowed execute's dry-run$ line: show it, it is the point of a dry run
    if is_dry_run; then
        printf '%s\n' "$download_result" >&2
        info "$check_em The artifact '$artifact_name' would have been downloaded to directory '$artifacts'."
    else
        info "$check_em The artifact '$artifact_name' successfully downloaded to directory '$artifacts'."
    fi
    exit 0
done

exit_with_error -ec "$err_logic_error" "The artifact '$artifact_name' was not found in the last ${#runs[@]} successful runs of the workflow ID '$workflow_id' in the repository '$repository'."
