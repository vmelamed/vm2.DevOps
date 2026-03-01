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

declare -x artifact_name=${ARTIFACT_NAME:-}
declare -x artifacts_dir=${ARTIFACT_DIR:-}
declare -x repository=${REPOSITORY:-}
declare -x workflow_id=${WORKFLOW_ID:-}
declare -x workflow_name=${WORKFLOW_NAME:-}
declare -x workflow_path=${WORKFLOW_PATH:-}

source "$script_dir/download-artifact.args.sh"
source "$script_dir/download-artifact.usage.sh"

get_arguments "$@"

is_safe_input "$artifact_name"
if [[ -z "$artifact_name" ]]; then
    error "The name of the artifact to download must be specified." >&2
fi
is_safe_path "$artifacts_dir" || true
is_safe_input "$repository" || true
is_safe_input "$workflow_id" || true
is_safe_input "$workflow_name" || true
is_safe_path "$workflow_path" || true
if [[ -n "$workflow_id" && ! "$workflow_id" =~ ^[0-9]+$ ]]; then
    error "The specified workflow identifier '$workflow_id' is not valid." || true
fi

exit_if_has_errors

# freeze the variables
declare -rx artifact_name
declare -rx artifacts_dir
declare -rx repository
declare -rx workflow_name
declare -rx workflow_path

if [[ -d "$artifacts_dir" && -n "$(ls -A "$artifacts_dir")" ]]; then
    renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"
    declare -r renamed_artifacts_dir

    choice=$(choose \
                "The artifacts' directory '$artifacts_dir' already exists. What do you want to do?" \
                    "Delete the directory and continue" \
                    "Rename the directory to '$renamed_artifacts_dir' and continue" \
                    "Exit the script") || exit $?

    trace "User selected option: $choice"
    case $choice in
        1)  echo "Deleting the directory '$artifacts_dir'..."
            execute rm -rf "$artifacts_dir"
            ;;
        2)  echo "Renaming the directory '$artifacts_dir' to '$renamed_artifacts_dir'..."
            execute mv "$artifacts_dir" "$renamed_artifacts_dir"
            ;;
        3)  echo "Exiting the script."
            exit 0
            ;;
        *)  echo "Invalid option $choice. Exiting."
            exit 2
            ;;
    esac
fi

declare -x github_output=${github_output:-/dev/stdout}
declare -x github_step_summary=${github_step_summary:-/dev/stdout}

declare -x _ignore
declare -rx dry_run

# install GitHub CLI and jq if not already installed
if ! command -v -p jq &> "$_ignore" || ! command -v -p gh 2>&1 "$_ignore"; then
    if execute sudo apt-get update && sudo apt-get install -y gh jq; then
        info "GitHub CLI 'gh' and/or 'jq' successfully installed."
    else
        error "GitHub CLI 'gh' and/or 'jq' were not found and could not install them. Please have 'gh' and 'jq' installed."
        exit 1
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
        error "Either the workflow id, the workflow name, or the workflow path must be specified."
    fi
fi
exit_if_has_errors

workflow_id=$(execute gh workflow list --repo "$repository" --json "id,name,path" --jq "$query")

if [[ "$dry_run" == true ]]; then
    workflow_id=1234567890
fi

if [[ -z $workflow_id ]]; then
    if [[ -n "$workflow_id" && ! "$workflow_id" =~ ^[0-9]+$ ]]; then
        error "The specified workflow identifier '$workflow_id' is not valid."
    elif [[ -n "$workflow_path" ]]; then
        error "The specified workflow path '$workflow_path' does not exist in the repository '$repository'."
    else
        error "The specified workflow name '$workflow_name' does not exist in the repository '$repository'."
    fi
    exit_if_has_errors
fi

# get the IDs of the last 1000 successful runs of the specified workflow
mapfile -t runs < <(gh run list \
                        --repo "$repository" \
                        --workflow "$workflow_id" \
                        --status success \
                        --limit 100 \
                        --json databaseId \
                        --jq '.[].databaseId')

if [[ ${#runs[@]} == 0 ]]; then
# shellcheck disable=SC2154 # variable is referenced but not assigned.
    error "No successful runs found for the workflow '$workflow_id' in the repository '$repository'."
    exit 2
fi

# iterate over the runs and try to find and download the specified artifact
# starting from the most recent one down to the oldest one
i=0
for run in "${runs[@]}"; do
    i=$((i + 1))
    trace "Checking run $run for the artifact '$artifact_name'..."
    query="any(.artifacts[]; .name==\"$artifact_name\")"
    if [[ ! $(gh api "repos/$repository/actions/runs/$run/artifacts" --jq "$query") == "true" ]]; then
        # shellcheck disable=SC2154 # variable is referenced but not assigned.
        echo "The artifact '$artifact_name' not found in run $run." >> "$github_step_summary"
        continue
    fi

    if ((i > 80)); then
        warning "The artifact was found in a run $i out of 100. \
You may want to refresh the artifact. \
E.g. re-run the benchmarks with --force-new-baseline or vars.FORCE_NEW_BASELINE" >&2
    fi
    trace "The artifact '$artifact_name' found in run $run. Downloading..."
    if ! http_error=$(execute gh run download "$run" \
                                --repo "$repository" \
                                --name "$artifact_name" \
                                --dir "$artifacts_dir") ; then
        error "Error while downloading '$artifact_name': $http_error"
        exit 2
    fi
    info "✅ The artifact '$artifact_name' successfully downloaded to directory '$artifacts_dir'." >> "$github_step_summary"
    exit 0
done

error "The artifact '$artifact_name' was not found in the last ${#runs[@]} successful runs of the workflow '$workflow_name' in the repository '$repository'."
exit 2
