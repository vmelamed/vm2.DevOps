#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")
# freeze them!
declare -rx script_name
declare -rx script_dir
declare -rx lib_dir

# shellcheck disable=SC1091
{
    source "$lib_dir/core.sh"
    source "$lib_dir/_git_vm2.sh"
}

#===============================
# Imported constants
#===============================
# environment variables and defaults:
declare -rx default_sot

declare -rxi success
declare -rxi failure
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_found
declare -rxi err_not_file
declare -rxi err_not_directory
declare -rxi err_not_git_root
declare -rxi err_behind_latest_stable_tag
declare -rxi err_invalid_repo
declare -rxi err_found_too_many
declare -rxi err_repo_with_no_ci
declare -rxi err_dir_with_no_ci
declare -rxi err_not_git_directory
declare -rxi err_dir_with_ci

declare -rx semverTagReleaseRegex
declare -rx vm2_devops_repo_name
declare -ra sources_of_truth


source "${script_dir}/diff-shared.functions.sh"
source "${script_dir}/diff-shared.args.sh"
source "${script_dir}/diff-shared.usage.sh"

#===============================
# arguments:
#===============================
declare -x vm2_repos=""
declare -x sot=$default_sot
declare -xa target_repos=()         # the target repositories specified as arguments. If not specified, the current directory is used as the only target repo.
declare -xA selectors_actions=()    # array [file] => [action string] for files specified on the CLI with --file* options
declare -x diff_only="false"        # if true, only show the differences without asking the user to take any actions. This is useful for CI validation of the shared content. In this mode, the actions are ignored and the summary file will not contain the Action column.
declare -x summary_file=""          # the file where the summary of the differences and actions will be written. If not specified, a temporary file will be created.

#===============================
# Shared variables:
#===============================
declare -xi rc="$success"
declare -xa arguments=(             # array of all arguments for logging and debugging purposes
    vm2_repos
    selectors_actions
    target_repos
    sot
    diff_only
    summary_file
)

# this is the data model of the script. Bash does not have complex data structures, so we use parallel arrays to store the
# source files, target files and actions. The index of the arrays corresponds to the same file pair and action. For example,
# source_files[0], target_files[0] and file_actions[0] correspond to the same file pair and action:
declare -xa source_files=()         # array of the paths of the SoT files
declare -xa target_files=()         # array of target paths corresponding to the SoT files by index
declare -xa file_actions=()         # array of default action strings corresponding to the SoT files by index

#===============================
# Script start:
#===============================
get_arguments "$@"

[[ -n "$summary_file" ]] || {
    summary_file=$(mktemp -p /tmp "diff-shared-log-$(date +%Y%m%d-%H%M%S)-XXXXXX.md")
    trap 'rm -f "$summary_file"' EXIT
}

dump_args --quiet

is_in "$sot" "${sources_of_truth[@]}" || {
    error "Invalid source of truth '$sot'. Valid values are: ${sources_of_truth[*]}."
    exit "$err_argument_value"
}

#===============================
# Adjust, validate and freeze the arguments:
#===============================
vm2_repos=$(resolve_vm2_repos "$vm2_repos") ||
    usage "$rc" "Could not find the parent directory for the vm2 repositories. Please, set the VM2_REPOS environment variable or provide the path as an argument with '--vm2-repos' option."
trace "All vm2 repositories are expected to be in '$vm2_repos'"

# if no repos were specified as arguments, use the current directory as the only target repo:
(( ${#target_repos[@]} != 0 )) || target_repos+=("$(pwd)")

declare -rx vm2_repos
declare -rx sot
declare -rxa target_repos
declare -rxA selectors_actions
declare -rx diff_only
declare -rx summary_file

#===============================
# Adjust, validate and freeze the source of truth:
#===============================
# ensure vm2.DevOps is a valid Git repository and is not behind the latest stable tag:
rc="$success"
validate_repo_root "$vm2_repos" "$vm2_devops_repo_name" "main" || rc=$?
(( rc == err_behind_latest_stable_tag )) &&
    error "The repository in '$vm2_devops_repo_name' is behind the latest stable tag. Please update it to the latest version of the main branch."

# ensure the SoT repository is a valid Git repository and is not behind the latest stable tag:
rc="$success"
validate_repo_root "$vm2_repos" "$vm2_sot_repo_name" "main" || rc=$?
(( rc == err_behind_latest_stable_tag )) &&
    error "The repository in '$vm2_sot_repo_name' is behind the latest stable tag. Please update it to the latest version of the main branch."

sot_path=$(get_vm2_sot_path "$vm2_repos" "$sot") || rc=$?
(( rc != success )) &&
    usage "$rc" "Could not find the source of truth directory for the specified template '$sot' in the expected location in '$vm2_repos'. Please make sure it exists or correct the parameter/environment variable."
readonly sot_path
trace "The source of truth directory for the '$sot' template is expected in '$sot_path'"

declare -a sot_dump_vars=(
    --header "Configuration for SoT $sot:"
    vm2_repos
    sot
    --header "Common Arguments:"
    "${common_args[@]}"
    --header "Arguments:"
    "${arguments[@]}"
    --header "Data Model:"
    source_files
    --quiet
    # --force
)
dump_vars "${sot_dump_vars[@]}"

{
    echo -e "# Summary\n"
    echo -e "## Source of truth: **$sot** (\`$sot_path\`)\n"
} >> "$summary_file"

info "Source of Truth '$sot' in '$sot_path'"

# Resolve and validate all repositories specified as arguments, and prepare the list of target files and actions for each of them:
declare -a target_roots=()
declare -a target_paths=()

for target in "${target_repos[@]}"; do
    output=$(resolve_target "$target") || {
        error "Could not resolve the path of the target repository '$target'. Please, ensure that it exists and is a valid directory."
        continue
    }
    {
        read -r target_root
        read -r target_path
    } <<< "$output"
    target_roots+=("$target_root")
    target_paths+=("$target_path")
done

exit_if_has_errors

declare -i targets_index

for (( targets_index=0; targets_index < ${#target_repos[@]}; targets_index++ )); do
    target_root="${target_roots[targets_index]}"
    target_path="${target_paths[targets_index]}"
    target="${target_root#"$vm2_repos/"}"

    # Load tools, file names and actions from the global config JSON
    configure "$sot_path" "$target_path" || {
        error "Failed to load configuration for the SoT directory '$sot_path'."
        reset_errors
        continue
    }

    # customize from the custom config JSON in the current target if it exists
    rc="$success"
    if (( ${#selectors_actions[@]} > 0 )); then
        parameterize
        customize "$target_root" true || rc=$?
    else
        customize "$target_root" false || rc=$?
    fi

    exit_if_has_errors

    {
        echo -e "### Target: ${target} ($target_path)\n"
        if $diff_only; then
            echo -e "| Source of Truth File | Shared Content File | Difference |"
            echo -e "|:---------------------|:--------------------|:-----------|"
        else
            echo -e "| Source of Truth File | Shared Content File | Difference | Action |"
            echo -e "|:---------------------|:--------------------|:-----------|:-------|"
        fi
    } >> "$summary_file"
    info "  Target '$target' ($target_path)..."

    target_dump_vars=(
        --header "Configuration for Target '$target':"
        --header "Data Model:"
        target_files
        file_actions
        --quiet
        # --force
    )
    dump_vars "${target_dump_vars[@]}"

    declare -i files_index
    for (( files_index=0; files_index < ${#source_files[@]}; files_index++ )); do

        source_file="${source_files[files_index]}"
        target_file="${target_files[files_index]}"
        actions="${file_actions[files_index]}"
        $diff_only && [[ -n $actions ]] && actions=$action_ignore

        if [[ -z $actions ]]; then
            trace "$(printf "%-84s ---- Skipping  ---- %-s\n" "${source_file#"$vm2_repos/${vm2_sot_repo_name}/templates/"}" "${target_file#"$vm2_repos/"}")"
            continue
        fi

        info "    SoT File: '${source_file#"$vm2_repos/${vm2_sot_repo_name}/templates/"}' vs Target File: '${target_file#"$vm2_repos/"}' with actions '$actions'..."

        declare difference=""
        declare action=""

        # if the target file does not exist - copy it or ask the user and then copy it
        # also, do not show visual diff for the actions that are not asking the user anything
        if [[ ! -s "$target_file" ]]; then
            trace "$(printf "%-s does not exist\n" "${target_file#"$vm2_repos"/}")"
            difference=" ✗ missing"
            action="ignored"
            case $actions in
                "$action_ignore" )
                    ;;

                "$action_merge_or_copy" | "$action_ask_to_merge" | "$action_ask_to_copy" )
                    confirm "Target file '$target_file' does not exist. Do you want to copy it from '${source_file}'?" "y" && {
                        copy_file "$source_file" "$target_file"
                        action="copied"
                    }
                    ;;

                "$action_merge" | "$action_copy" )
                    copy_file "$source_file" "$target_file"
                    action="copied"
                    ;;

                * )
                    error "Unknown action '$actions' for files '${source_file}' and '${target_file}'."
                    action="error"
                    press_any_key
                    ;;
            esac
            $diff_only &&
                echo "| ${source_file#"$vm2_repos/"} | ${target_file#"$vm2_repos/"} | $difference |" >> "$summary_file" ||
                echo "| ${source_file#"$vm2_repos/"} | ${target_file#"$vm2_repos/"} | $difference | $action |" >> "$summary_file"
            continue
        fi

        is_in "$actions" "$action_ignore" "$action_merge" "$action_copy" && show_diff=false || show_diff=true
        rc=$success
        are_different "$source_file" "$target_file" "$show_diff" || rc=$?
        (( rc == success )) &&
            difference=" ≠ different" ||
            difference=" = identical"
        action="ignored"

        if (( rc == success )); then
            case $actions in
                "$action_ignore" )
                    ;;

                "$action_merge_or_copy" )
                    case $(choose "What do you want to do?" \
                                "Do nothing - continue" \
                                "Merge the files" \
                                "Copy '$source_file' file to '$target_file'") in
                        2 ) merge "$target_file" "$source_file" && action="merged" || action="not merged"
                            ;;
                        3 ) copy_file "$source_file" "$target_file"
                            action="copied"
                            ;;
                        * ) ;;
                    esac
                    ;;

                "$action_ask_to_merge" )
                    confirm "Do you want to merge '${source_file}' to file '${target_file}'?" "n" && {
                        merge "$target_file" "$source_file" && action="merged" || action="not merged"
                    }
                    ;;

                "$action_merge" )
                    merge "$target_file" "$source_file" && action="merged" || action="not merged"
                    ;;

                "$action_ask_to_copy" )
                    confirm "Do you want to copy '${source_file}' to file '${target_file}'?" "n" && {
                        copy_file "$source_file" "$target_file"
                        action="copied"
                    }
                    ;;

                "$action_copy" )
                    copy_file "$source_file" "$target_file"
                    action="copied"
                    ;;

                * ) error "Unknown action '$actions' for files '${source_file}' and '${target_file}'."
                    action="error"
                    press_any_key
                    ;;
            esac
        fi
        $diff_only &&
            echo "| ${source_file#"$vm2_repos/${vm2_sot_repo_name}/templates/"} | ${target_file#"$vm2_repos/"} | $difference |" >> "$summary_file" ||
            echo "| ${source_file#"$vm2_repos/${vm2_sot_repo_name}/templates/"} | ${target_file#"$vm2_repos/"} | $difference | $action |" >> "$summary_file"
    done # SoT files loop

    echo "" >> "$summary_file"
done # repositories loop

[[ $(get_table_format) != "markdown" ]] && (command -v -p "glow" > "$_ignore" || which "glow" &>"$_ignore") &&
    glow -w 150 "$summary_file" ||
    cat "$summary_file"
