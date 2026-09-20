#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091 # Not following
source "$lib_dir/core.sh"

#===============================
# Imported constants
#===============================
# imported environment variables and defaults:
declare -x _ignore
declare -xr default_sot
declare -xra sources_of_truth
declare -xra vm2_repositories
declare -xr semverTagReleaseRegex
declare -xr vm2_devops_repo_name

# import outcomes and error codes
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_not_found
declare -xri err_not_file
declare -xri err_not_directory
declare -xri err_not_git_root
declare -xri err_behind_latest_stable_tag
declare -xri err_invalid_repo
declare -xri err_found_too_many
declare -xri err_repo_with_no_ci
declare -xri err_dir_with_no_ci
declare -xri err_not_git_directory
declare -xri err_dir_with_ci
declare -xri err_logic_error

source "$script_dir/diff-shared.functions.sh"
source "$script_dir/diff-shared.args.sh"
source "$script_dir/diff-shared.usage.sh"

#===============================
# arguments:
#===============================
declare -x vm2_repos="${VM2_REPOS:-$HOME/repos/vm2}"
declare -x vm2_sot_repo_name
declare -x sot=$default_sot
declare -xa target_repos=()     # the target repositories specified as arguments. If not specified, the current directory is used as the only target repo.
declare -xA selectors_actions=() # array [file] => [action string] for files specified on the CLI with --file* options
declare -x diff_only="false"    # if true, only show the differences without asking the user to take any actions. This is useful for CI validation of the shared content. In this mode, the actions are ignored and the summary file will not contain the Action column.
declare -x summary_file=""      # the file where the summary of the differences and actions will be written. If not specified, a temporary file will be created.
declare -x current_branch="false"    # both vm2.DevOps and SoT repositories must be on the main branch by default, otherwise on their respective current branches

#===============================
# Script shared variables:
#===============================
declare -x action_ignore action_merge_or_copy action_ask_to_merge action_ask_to_copy action_merge action_copy
declare -xa arguments=(         # array of all arguments for logging and debugging purposes
    vm2_repos
    sot
    target_repos
    selectors_actions
    diff_only
    summary_file
    current_branch
)

# this is the data model of the script. Bash does not have complex data structures, so we use parallel arrays to store the
# source files, target files and actions. The index of the arrays corresponds to the same file pair and action. For example,
# source_files[0], target_files[0] and file_actions[0] correspond to the same file pair and action:
declare -xa source_files=()     # array of the paths of the SoT files
declare -xa target_files=()     # array of target paths corresponding to the SoT files by index
declare -xa file_actions=()     # array of default action strings corresponding to the SoT files by index

#===============================
# Summary variables:
#===============================
declare -xi summary_diff_count=0
declare -xi summary_identical_count=0
declare -xi summary_merged_count=0
declare -xi summary_not_merged_count=0
declare -xi summary_copied_count=0
declare -xi summary_ignore_count=0

#===============================
# Script start:
#===============================
get_arguments "$@"

is_in "$sot" "${sources_of_truth[@]}" || {
    usage -ec "$err_argument_value" "Invalid source of truth '$sot'. Valid values are: ${sources_of_truth[*]}."
}

#===============================
# Adjust, validate and freeze the arguments:
#===============================
declare -xi rc="$success"

declare branches
$current_branch && branches='' || branches='main'

resolve_vm2_repos "$vm2_repos" vm2_repos "$branches" "$branches" || rc=$?
(( rc == success )) || usage "Could not resolve the path of the vm2 repositories directory from the specified value of '$vm2_repos'."
trace "All vm2 repositories are expected to be in '$vm2_repos'"

# if no repos were specified as arguments, use the current directory as the only target repo:
(( ${#target_repos[@]} != 0 )) || target_repos+=("$(pwd)")

#===============================
# Adjust, validate and freeze the source of truth:
#===============================
# ensure vm2.DevOps is a valid Git repository and is not behind the latest stable tag:
rc="$success"
declare sot_path
get_vm2_sot_path "$vm2_repos" "$sot" sot_path || rc=$?
(( rc == success )) || usage -ec "$rc" "Could not find the source of truth directory for the specified template '$sot' in the expected location in '$vm2_repos'."

declare -xr vm2_repos
declare -xr sot
declare -xr sot_path
declare -xra target_repos
declare -xrA selectors_actions
declare -xr diff_only
declare -xr summary_file

declare -a sot_dump_vars=(
    --quiet
    --header "Configuration for SoT $sot:"
    vm2_repos
    sot_path
    --header "Arguments:"
    "${arguments[@]}"
    --header "Core State:"
    --core-state
)

dump_vars "${sot_dump_vars[@]}"

{
    echo -e "# Summary\n"
    echo -e "## Source of truth: **$sot** (\`$sot_path\`)\n"
} >> "$summary_file"

info "Source of Truth folder '$sot' in '$sot_path'"

# Resolve and validate all repositories specified as arguments, and prepare the list of target files and actions for each of them:
declare target_root target_path
declare -a target_roots=()
declare -a target_paths=()

for target in "${target_repos[@]}"; do
    resolve_target "$vm2_repos" "$target" target_root target_path || {
        error -ec "$?" "Could not resolve the Git working tree root of the target '$target'. Please, ensure that it exists and is a valid directory."
        continue
    }
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
        error -ec "$err_logic_error" "Failed to load configuration for the SoT directory '$sot_path'."
        reset_errors
        continue
    }

    # customize from the custom config JSON in the current target if it exists
    rc="$success"
    if (( ${#selectors_actions[@]} > 0 )); then
        parameterize
        $diff_only ||
            customize "$target_root" true || rc=$?
    else
        $diff_only ||
            customize "$target_root" false || rc=$?
    fi

    exit_if_has_errors

    declare source_path target_path filename

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    $diff_only && {
        echo -e "### Target Repository: $target ($target_path)\n"
        echo -e "| Source Path | Target Path | Filename | Difference | To do: | Default: |"
        echo -e "|:------------|:------------|:---------|:-----------|:-------|:---------|"
    } >> "$summary_file" || {
        echo -e "### Target Repository: $target ($target_path)\n"
        echo -e "| Source Path | Target Path | Filename | Difference | Done:  | Default: |"
        echo -e "|:------------|:------------|:---------|:-----------|:-------|:---------|"
    } >> "$summary_file"

    info "Target repository '$target' ($target_path)..."

    target_dump_vars=(
        --quiet
        --header "Configuration for Target '$target':"
        diff_tool
        diff_command
        merge_tool
        merge_command
        --header "Data Model:"
        source_files
        target_files
        file_actions
    )

    dump_vars "${target_dump_vars[@]}"

    declare -i files_index
    for (( files_index=0; files_index < ${#source_files[@]}; files_index++ )); do

        source_file="${source_files[files_index]}"
        target_file="${target_files[files_index]}"
        actions="${file_actions[files_index]}"

        if [[ -z $actions ]]; then
            trace "$(printf "%-84s ---- Skipping  ---- %-s\n" "${source_file#"$vm2_repos/$vm2_sot_repo_name/templates/"}" "${target_file#"$vm2_repos/"}")"
            continue
        fi

        trace "    SoT File: '${source_file#"$vm2_repos/$vm2_sot_repo_name/templates/"}' vs Target File: '${target_file#"$vm2_repos/"}' with actions '$actions'..."

        declare different=false
        declare difference=""
        declare action

        $diff_only && action=$actions || action="ignored"

        # if the target file does not exist - copy it or ask the user and then copy it
        # also, do not show visual diff for the actions that are not asking the user anything
        if [[ ! -s "$target_file" ]]; then
            trace "$(printf "%-s does not exist\n" "${target_file#"$vm2_repos"/}")"
            difference=" ✗ missing"
            if ! $diff_only; then
                case $actions in
                    "$action_ignore" )
                        (( ++summary_ignore_count ))
                        action="ignored"
                        ;;

                    "$action_merge_or_copy" | "$action_ask_to_merge" | "$action_ask_to_copy" )
                        confirm "Target file '$target_file' does not exist. Do you want to copy it from '$source_file'?" "y" && {
                            copy_file "$source_file" "$target_file"
                            action="copied"
                        }
                        ;;

                    "$action_merge" | "$action_copy" )
                        copy_file "$source_file" "$target_file"
                        action="copied"
                        ;;

                    * ) error -ec "$err_logic_error" "Unknown action '$actions' for files '$source_file' and '$target_file'."
                        action="error"
                        press_any_key
                        ;;
                esac
            fi
        else
            is_in "$actions" "$action_ignore" "$action_merge" "$action_copy" &&
                show_diff=false ||
                show_diff=true
            $diff_only && show_diff=false
            rc=$success
            are_different "$source_file" "$target_file" "$show_diff" || rc=$?

            # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
            (( rc == positive )) &&
                { different=true;  difference=" ≠ different"; } ||
                { different=false; difference=" = identical"; action="ignore"; }

            if $different && ! $diff_only; then
                action="ignored"
                case $actions in
                    "$action_ignore" )
                        (( ++summary_ignore_count ))
                        ;;

                    "$action_merge_or_copy" )
                        declare choice
                        choose "What do you want to do?" \
                            choice \
                                    "Do nothing - continue" \
                                    "Merge the files" \
                                    "Copy '$source_file' file to '$target_file'"
                        case $choice in

                            2 ) merge "$source_file" "$target_file" &&
                                    action="merged" ||
                                    action="not merged"
                                ;;

                            3 ) copy_file "$source_file" "$target_file"
                                action="copied"
                                ;;

                            * ) ;;
                        esac
                        ;;

                    "$action_ask_to_merge" )
                        confirm "Do you want to merge '$source_file' to file '$target_file'?" "n" && {
                            merge "$source_file" "$target_file" &&
                                action="merged" ||
                                action="not merged"
                        }
                        ;;

                    "$action_merge" )
                        merge "$source_file" "$target_file" &&
                            action="merged" ||
                            action="not merged"
                        ;;

                    "$action_ask_to_copy" )
                        confirm "Do you want to copy '$source_file' to file '$target_file'?" "n" && {
                            copy_file "$source_file" "$target_file"
                            action="copied"
                        }
                        ;;

                    "$action_copy" )
                        copy_file "$source_file" "$target_file"
                        action="copied"
                        ;;

                    * ) error -ec "$err_logic_error" "Unknown action '$actions' for files '$source_file' and '$target_file'."
                        action="error"
                        press_any_key
                        ;;
                esac
            fi
        fi
        filename="$(basename "$source_file")"
        source_path="$(dirname "$source_file")"
        target_path="$(dirname "$target_file")"
        echo "| ${source_path#"$vm2_repos/"} | ${target_path#"$vm2_repos/"} | $filename | $difference | $action | $actions |" >> "$summary_file"
    done # SoT files loop

    echo "" >> "$summary_file"
done # repositories loop

dump_vars \
    --force \
    --quiet \
    --header "Summary:" \
    --name "Different"  summary_diff_count \
    --name "Identical"  summary_identical_count \
    --name "Merged"     summary_merged_count \
    --name "Not Merged" summary_not_merged_count \
    --name "Copied"     summary_copied_count \
    --name "Ignored"    summary_ignore_count >> "$summary_file"

declare -x glow_present

# shellcheck disable=SC2015 # A && B || C is not if-then-else. C may run when A is true but B is false.
$glow_present &&
    glow "$summary_file" -w 180 ||
    cat "$summary_file"
