#!/bin/bash
set -euo pipefail

declare -xr this_script=${BASH_SOURCE[0]}

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

source "$script_dir/_common.sh"

declare -x repository=${REPOSITORY:-}
declare -x workflow_id=${WORKFLOW_ID:-}
declare -x workflow_name=${WORKFLOW_NAME:-}
declare -x workflow_path=${WORKFLOW_PATH:-}
declare -x artifact_name=${ARTIFACT_NAME:-}
declare -x artifacts_dir=${ARTIFACT_DIR:-"./BmArtifacts/baseline"}

source "$script_dir/download-artifact.utils.sh"
source "$script_dir/download-artifact.usage.sh"

get_arguments "$@"

dump_all_variables

renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"
declare -r renamed_artifacts_dir

if [[ -d "$artifacts_dir" && -n "$(ls -A "$artifacts_dir")" ]]; then
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

if [[ -z "$artifact_name" ]]; then
    usage "The name of the artifact to download must be specified." >&2
    exit 2
fi

declare -rx repository
declare -rx workflow_name
declare -rx workflow_name
declare -rx workflow_path
declare -x workflow_id
declare -rx artifact_name
declare -rx artifacts_dir

# install GitHub CLI and jq if not already installed
if ! command -v jq >"$_ignore" 2>&1; then
    execute sudo apt-get update && sudo apt-get install -y gh jq
    echo "GitHub CLI and jq successfully installed."
fi

declare -a runs
declare query

# get the workflow ID if not provided
if [[ -n "$workflow_id" && -n "$workflow_id" && ! "$workflow_id" =~ ^[0-9]+$ ]]; then
    usage "The specified workflow identifier '$workflow_id' is not valid."
    exit 2
else
    # query for the workflow ID using the name or path
    if [[ -n "$workflow_name" && -n "$workflow_name" ]]; then
        query=".[] | select(.name==\"$workflow_name\").id"
    elif [[ -n "$workflow_path" && -n "$workflow_path" ]]; then
        query=".[] | select(.path==\"$workflow_path\").id"
    else
        usage "Either the workflow id, or the workflow name or the workflow path must be specified."
    fi
    workflow_id=$(execute gh workflow list --repo "$repository" --json "id,name,path" --jq "$query")
    if [[ "$dry_run" == true ]]; then
        workflow_id=1234567890
    fi
fi

if [[ -z $workflow_id ]]; then
    if [[ -n "$workflow_id" && ! "$workflow_id" =~ ^[0-9]+$ ]]; then
        usage "The specified workflow identifier '$workflow_id' is not valid."
    elif [[ -n "$workflow_path" ]]; then
        usage "The specified workflow path '$workflow_path' does not exist in the repository '$repository'."
    else
        usage "The specified workflow name '$workflow_name' does not exist in the repository '$repository'."
    fi
    exit 2
fi

dump_all_variables

# get the IDs of the last 1000 successful runs of the specified workflow
mapfile -t runs < <(execute gh run list \
                                --repo "$repository" \
                                --workflow "$workflow_id" \
                                --status success \
                                --limit 100 \
                                --json databaseId \
                                --jq '.[].databaseId')

if [[ "$dry_run" == true ]]; then
    runs=(1234567890 1234567889 1234567888)
fi

if [[ ${#runs[@]} == 0 ]]; then
    # shellcheck disable=SC2154
    usage "No successful runs found for the workflow '$workflow_id' in the repository '$repository'." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    exit 2
fi

# iterate over the runs and try to find and download the specified artifact
# starting from the most recent one down to the oldest one
i=0
for run in "${runs[@]}"; do
    i=$((i + 1))
    trace "Checking run $run for the artifact '$artifact_name'..."
    query="any(.artifacts[]; .name==\"$artifact_name\")"
    if [[ ! $(execute gh api "repos/$repository/actions/runs/$run/artifacts" --jq "$query") == "true" ]]; then
        # shellcheck disable=SC2154
        echo "The artifact '$artifact_name' not found in run $run." >> "$GITHUB_STEP_SUMMARY"
        continue
    fi

    if ((i > 80)); then
        echo "⚠️ Warning: The artifact was found in a run $i out of 100. \
You may want to refresh the artifact. \
E.g. run the benchmarks with --force-new-baseline or vars.FORCE_NEW_BASELINE" >&2
    fi
    trace "The artifact '$artifact_name' found in run $run. Downloading..."
    if ! http_error=$(execute gh run download "$run" \
                                --repo "$repository" \
                                --name "$artifact_name" \
                                --dir "$artifacts_dir") ; then
        echo "Error while downloading '$artifact_name': $http_error" | tee >> "$GITHUB_STEP_SUMMARY" >&2
        exit 2
    fi
    echo "✅ The artifact '$artifact_name' successfully downloaded to directory '$artifacts_dir'." >> "$GITHUB_STEP_SUMMARY"
    exit 0
done

usage "❌ The artifact '$artifact_name' was not found in the last ${#runs[@]} successful runs of the workflow '$workflow_name' in \
the repository '$repository'." | tee >> "$GITHUB_STEP_SUMMARY" >&2
exit 2
