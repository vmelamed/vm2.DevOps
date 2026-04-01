#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
{
    source "$lib_dir/core.sh"
    source "$lib_dir/_git_vm2.sh"
}

# environment variables:
declare -xr VM2_REPOS
declare -xr default_vm2_repos

# arguments
declare -x target_dir=""
declare -x vm2_repos=""
declare -xa file_regexes=()

source "${script_dir}/diff-common.args.sh"
source "${script_dir}/diff-common.usage.sh"
source "${script_dir}/diff-common.functions.sh"

get_arguments "$@"

declare -i rc=0

declare -rxi success
declare -rxi failure
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_found
declare -rxi err_not_file
declare -rxi err_not_directory
declare -rxi err_not_git_repository
declare -rxi err_behind_latest_stable_tag
declare -rxi err_invalid_repo
declare -rxi err_invalid_repo
declare -rxi err_found_more_than_one
declare -rxi err_repo_has_no_ci
declare -rxi err_dir_has_no_ci
declare -rxi err_not_git_directory

declare -xr semverTagReleaseRegex

declare target_repo_root
declare -xi rc=0

#===============================
# Find and validate vm2_repos:
#===============================
vm2_repos=$(resolve_vm2_repos "$vm2_repos")
(( $? == success )) ||
    exit "$rc"

[[ -d "$vm2_repos/.github" && -d "$vm2_repos/vm2.DevOps" ]] ||
    usage "$err_not_found" "The GitHub Actions workflow templates directory .github and/or the vm2.DevOps directory is missing in '$vm2_repos'."


# make sure we are seeing .github and vm2.DevOps properly through vm2_repos
validate_repo ".github" "$vm2_repos"
rc=$?
(( rc == err_behind_latest_stable_tag )) && { ensure_fresh_git_state "$vm2_repos/.github"; rc=$?; }
(( rc != success )) && exit "$rc"

validate_repo "vm2.DevOps" "$vm2_repos"
rc=$?
(( rc == err_behind_latest_stable_tag )) && { ensure_fresh_git_state "$vm2_repos/vm2.DevOps"; rc=$?; }
(( rc != success )) && exit "$rc"

exit_if_has_errors

trace "All vm2 repositories are expected generally in '$vm2_repos'"

#=================================================
# Validate and adjust target_path from target_dir:
#=================================================
output=$(resolve_repo_root "$target_dir" "$vm2_repos")
rc=$?
# here we can only work with git repos and directories that have CI configured:
(( rc == success ||
   rc == err_not_git_directory )) || exit "$rc"

{ read -r target_repo_root; read -r target_path; } <<< "$output"

((  rc == success )) &&
    ensure_fresh_git_state "$target_repo_root"

trace "The target project is in '$target_path' with root directory '$target_repo_root'."

# freeze the arguments
declare -xr vm2_repos
declare -xr target_dir
declare -xr target_path

dump_all_variables

declare -a source_files
declare -a target_files
declare -A file_actions

configure   # Load files and actions from the global config JSON
customize   # Load custom actions from the custom config JSON if it exists

# validate the configuration
if [[ ${#source_files[@]} -ne ${#target_files[@]} ]] ||
   [[ ${#source_files[@]} -ne ${#file_actions[@]} ]]; then
    error "The data in the config tables does not match."
fi

exit_if_has_errors

# get the diff and merge tools
get_diff_tool
get_merge_tool

declare -i i=0

while [[ $i -lt ${#source_files[@]} ]]; do
    source_file="${source_files[i]}"
    target_file="${target_files[i]}"
    actions="${file_actions[$source_file]}"
    (( ++i ))

    if [[ ${#file_regexes[@]} -gt 0 ]]; then
        matched=false
        for regex in "${file_regexes[@]}"; do
            if [[ "$source_file" =~ $regex ]]; then
                matched=true
                break
            fi
        done
        if [[ $matched == false ]]; then
            trace "Skipping file '$source_file' as it does not match any of the provided regexes."
            continue
        fi
    fi

    if is_verbose; then
        trace_msg=$(printf "\n%-84s <--- Comparing ---> %-s\n" "$source_file" "$target_file")
        trace "$trace_msg"
    fi

    if [[ ! -s "$target_file" ]]; then
        case $actions in
            "$action_ignore" )
                continue
                ;;
            "$action_merge_or_copy" | "$action_ask_to_merge" | "$action_ask_to_copy")
                confirm "Target file '${target_file}' does not exist. Do you want to copy it from '${source_file}'?" "y" && \
                copy_file "$source_file" "$target_file"
                ;;
            "$action_merge" | "$action_copy" )
                copy_file "$source_file" "$target_file"
                ;;
            *)
                error "Unknown action '$actions' for files '${source_file}' and '${target_file}'."
                press_any_key
                ;;
        esac
        continue
    fi

    show_diff=true
    if is_in "$actions" "$action_ignore" "$action_merge" "$action_copy"; then
        show_diff=false
    fi

    if are_different "${source_file}" "${target_file}" "$show_diff"; then
        echo "File '${source_file}' is different from '${target_file}'."
        if ! is_quiet; then
            case $actions in
                "$action_ignore" )
                    continue
                    ;;

                "$action_merge_or_copy" )
                    case $(choose "What do you want to do?" \
                                  "Do nothing - continue" \
                                  "Merge the files" \
                                  "Copy '$source_file' file to '$target_file'") in
                        2) merge "$target_file" "$source_file" || true
                           ;;
                        3) copy_file "$source_file" "$target_file"
                           ;;
                        *) ;;
                    esac
                    ;;

                "$action_ask_to_merge" )
                    confirm "Do you want to merge '${source_file}' to file '${target_file}'?" "n" && \
                    merge "$target_file" "$source_file" || true
                    ;;

                "$action_merge" )
                    merge "$target_file" "$source_file" || true
                    ;;

                "$action_ask_to_copy" )
                    confirm "Do you want to copy '${source_file}' to file '${target_file}'?" "n" && \
                    copy_file "$source_file" "$target_file"
                    ;;

                "$action_copy" )
                    copy_file "$source_file" "$target_file"
                    ;;

                * )
                    error "Unknown action '$actions' for files '${source_file}' and '${target_file}'."
                    press_any_key
                    ;;
            esac
        fi
        echo ""
    fi
done
