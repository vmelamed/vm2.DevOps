#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
source "$lib_dir/core.sh"

# arguments
declare -x target_dir=""
declare -x vm2_repos="${VM2_REPOS:-}"
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-'v'}
declare -xa file_regexes=()

source "${script_dir}/diff-common.args.sh"
source "${script_dir}/diff-common.usage.sh"
source "${script_dir}/diff-common.functions.sh"

get_arguments "$@"

#===============================
# Validate and adjust vm2_repos:
#===============================
if [[ -z "$vm2_repos" ]] || ! vm2_repos=$(realpath -e "$vm2_repos" 2> "$_ignore"); then
    trace "Neither the \$VM2_REPOS environment variable nor the --vm2-repos option is specified. Will assume that the source-of-truth repositories are located in the same parent directory."
    # use this script's path to find the vm2_repos
    if r=$(root_working_tree "$script_dir") ||
       r=$(realpath -e "$(dirname "$script_dir/../..")"); then
        vm2_repos=$(realpath -e "$(dirname "$r")")
    else
        error "The source directories are not located under the same parent directory. Specify the path of their parent directory either with the \$VM2_REPOS environment variable or the --vm2-repos option."
        exit 2
    fi
fi
# make sure we are seeing .github and vm2.DevOps properly through vm2_repos
validate_source_repo ".github"
validate_source_repo "vm2.DevOps"
trace "All source repositories are in '$vm2_repos'"

#=================================================
# Validate and adjust target_path from target_dir:
#=================================================
[[ -n $target_dir ]] || target_dir=$(pwd)

if  ! target_path=$(realpath -e "$target_dir" 2> "$_ignore") &&
    ! target_path=$(realpath -e "$vm2_repos/$target_dir" 2> "$_ignore"); then
     error "Could not find the target directory '$target_dir' in the current working directory or in '$VM2_REPOS'."
     exit 2
fi
if is_in "$target_path" "${vm2_repos}/vm2.DevOps" "${vm2_repos}/.github" ; then
    error "The target project cannot be '${vm2_repos}/vm2.DevOps' or '${vm2_repos}/.github'."
    exit 2
fi
trace "The target project is in '$target_path'"

[[ ! -d "$target_path/.github/workflows" ]] &&
warning "The target directory '$target_path' does not contain the expected directory '.github/workflows' - it will be created. Continue? " &&
! confirm "Are you sure that your project is in $target_path?" "n" &&
exit 2

# freeze the arguments
declare -xr vm2_repos
declare -xr target_dir
declare -xr target_path
declare -xr minver_tag_prefix

validate_minverTagPrefix "$minver_tag_prefix"

# shellcheck disable=SC2154
declare -xr semverTagReleaseRegex

dump_all_variables

declare -a source_files
declare -a target_files
declare -A file_actions

# Load files and actions from the global config JSON
configure
# Modify the actions from custom config JSON if it exists
customize
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

    trace -e "\n${source_file} <--- Comparing ---> ${target_file}"

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
        # shellcheck disable=SC2154
        if [[ "$quiet" != true ]]; then
            case $actions in
                "$action_ignore")
                    continue
                    ;;
                "$action_merge_or_copy")
                    case $(choose "What do you want to do?" \
                                  "Do nothing - continue" \
                                  "Merge the files" \
                                  "Copy '$source_file' file to '$target_file'") in
                        1) ;;
                        2) merge "$target_file" "$source_file" || true ;;
                        3) copy_file "$source_file" "$target_file" ;;
                        *) ;;
                    esac
                    ;;
                "$action_ask_to_merge")
                    confirm "Do you want to merge '${source_file}' to file '${target_file}'?" "n" && \
                    merge "$target_file" "$source_file" || true
                    ;;
                "$action_merge")
                    merge "$target_file" "$source_file" || true
                    ;;
                "$action_ask_to_copy")
                    confirm "Do you want to copy '${source_file}' to file '${target_file}'?" "n" && \
                    copy_file "$source_file" "$target_file"
                    ;;
                "$action_copy")
                    copy_file "$source_file" "$target_file"
                    ;;
                *)
                    error "Unknown action '$actions' for files '${source_file}' and '${target_file}'."
                    press_any_key
                    ;;
            esac
        fi
        echo ""
    fi
done
