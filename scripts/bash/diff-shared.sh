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

source "${script_dir}/diff-shared.args.sh"
source "${script_dir}/diff-shared.usage.sh"
source "${script_dir}/diff-shared.functions.sh"

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
declare -rxi err_not_git_root
declare -rxi err_behind_latest_stable_tag
declare -rxi err_invalid_repo
declare -rxi err_invalid_repo
declare -rxi err_found_too_many
declare -rxi err_repo_with_no_ci
declare -rxi err_dir_with_no_ci
declare -rxi err_not_git_directory

declare -xr semverTagReleaseRegex

declare target_repo_root
declare -xi rc="$success"

#===============================
# Find and validate vm2_repos:
#===============================
vm2_repos=$(resolve_vm2_repos "$vm2_repos") ||
    usage "$rc" "Could not find the parent directory for the vm2 repositories. Please, set the VM2_REPOS environment variable or provide the path as an argument with '--vm2-repos' option."

trace "All vm2 repositories are expected in '$vm2_repos'"

# make sure we are seeing .github and vm2.DevOps properly through vm2_repos
[[ -d "$vm2_repos/.github" && -d "$vm2_repos/vm2.DevOps" ]] ||
    usage "$err_not_found" "The GitHub Actions workflow templates directory .github and/or the vm2.DevOps directory is missing in '$vm2_repos', Please clone the repositories into '$vm2_repos'."

validate_repo_root "$vm2_repos/.github" "$vm2_repos" "main" || rc=$?
(( rc == err_behind_latest_stable_tag )) &&
    error "The repository in '$vm2_repos/.github' is behind the latest stable tag. Please update it to the latest commit on the main branch."

rc="$success"
validate_repo_root "$vm2_repos/vm2.DevOps" "$vm2_repos" "main" || rc=$?
(( rc == err_behind_latest_stable_tag )) &&
    error "The repository in '$vm2_repos/vm2.DevOps' is behind the latest stable tag. Please update it to the latest commit on the main branch."

exit_if_has_errors

#=================================================
# Validate and adjust target_path from target_dir:
#=================================================
rc="$success"
output=$(resolve_repo_root "$target_dir" "$vm2_repos") || rc=$?

# here we can only work with git repos and directories that have CI configured:
(( rc == success || rc == err_not_git_directory )) ||
    usage "$rc" "The specified target directory '$target_dir' is invalid. It should have CI configured in '$target_dir/.github/workflows'."

{ IFS= read -r target_repo_root; IFS= read -r target_path; } <<< "$output"

# if it is a git repo then make sure it is in a clean state:
if (( rc == success )); then
    branch="$(git -C "$target_repo_root" branch --show-current 2>"$_ignore")" || {
        rc=$?
        error "The repository in the specified target directory '$target_dir' appears corrupted."
    }
    (( rc == success )) && ensure_fresh_git_state "$target_repo_root" "$branch" ||
        error "The specified target repository at '$target_repo_root' on branch '$branch' is not in a clean state. Please, commit or stash your changes."
else
    branch="<not a git repository>"
fi

exit_if_has_errors

trace "The target project is in '$target_path' with working tree directory root '$target_repo_root', on branch '$branch'."

# freeze the arguments
declare -xr vm2_repos
declare -xr target_dir
declare -xr target_path

dump_args

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

    is_verbose && trace < <(printf "\n%-84s ---- Comparing ---- %-s\n" "$source_file" "$target_file")

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
        if ! is_quiet; then
            case $actions in
                "$action_ignore" )
                    continue
                    ;;

                "$action_merge_or_copy" )
                    echo "File '${source_file}' is different from '${target_file}'."
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
                    echo "File '${source_file}' is different from '${target_file}'."
                    confirm "Do you want to merge '${source_file}' to file '${target_file}'?" "n" && \
                    merge "$target_file" "$source_file" || true
                    ;;

                "$action_merge" )
                    merge "$target_file" "$source_file" || true
                    ;;

                "$action_ask_to_copy" )
                    echo "File '${source_file}' is different from '${target_file}'."
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
