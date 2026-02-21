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
declare -x repos="${GIT_REPOS:-$HOME/repos}"
declare -x target_dir=""
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-'v'}
declare -xa file_regexes=()

source "${script_dir}/diff-common.utils.sh"
source "${script_dir}/diff-common.usage.sh"
source "${script_dir}/diff-common.functions.sh"

get_arguments "$@"

repos=$(realpath -e "$git_repos")

# freeze the arguments
declare -xr repos
declare -xr target_dir
declare -xr minver_tag_prefix

validate_minverTagPrefix "$minver_tag_prefix"

# shellcheck disable=SC2154
declare -xr semverTagReleaseRegex

# shellcheck disable=SC2119 # Use dump_all_variables "$@" if function's $1 should mean script's $1.
dump_all_variables

declare -a source_files
declare -a target_files
declare -A file_actions

# Validate environment:
if [[ -z "$git_repos" ]]; then
    error "The common directory of the source repositories was not specified (export GIT_REPOS env. variable or use --git-repos option)."
    exit 2
fi
validate_source_repo ".github"
validate_source_repo "vm2.DevOps"
trace "All source repositories are in '$git_repos'"

# Resolve the project path
target_path=$(find_repo_root "$target_dir" true) || {
    error "Could not find a directory inside a working tree related to the parameter '$target_dir'."
    exit 2
}

if is_in "$target_path" "${repos}/vm2.DevOps" "${repos}/.github" ; then
    error "The target project cannot be '${repos}/vm2.DevOps' or '${repos}/.github'."
    exit 2
fi
trace "The target project is in '$target_path'"

ask=false
if [[ ! -d "$target_path/.github/workflows" ]]; then
    warning "The target directory '$target_path' does not contain a directory '.github/workflows'."
    ask=true
fi
if [[ ! -d "$target_path/src" ]]; then
    warning "The target directory '$target_path' does not contain a directory 'src'."
    ask=true
fi
if [[ $ask == true ]] && ! confirm "Are you sure that your project is in $target_path?" "n"; then
    return 2
fi

# freeze target_path too
declare -xr target_path

# Load file configurations from JSON
configure

# Modify the actions from JSON custom config if it exists
customize

if [[ ${#source_files[@]} -ne ${#target_files[@]} ]] || [[ ${#source_files[@]} -ne ${#file_actions[@]} ]]; then
    error "The data in the tables do not match."
fi
exit_if_has_errors

declare -i i=0

while [[ $i -lt ${#source_files[@]} ]]; do
    source_file="${source_files[i]}"
    target_file="${target_files[i]}"
    actions="${file_actions[$source_file]}"
    i=$((i+1))

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
        if [[ "$actions" != "ignore" ]]; then
            confirm "Target file '${target_file}' does not exist. Do you want to copy it from '${source_file}'?" "y" && \
            copy_file "$source_file" "$target_file"
        else
            warning "Target file '${target_file}' does not exist or is empty."
        fi
        continue
    fi

    show_diff=true
    if is_in "$actions" "ignore" "merge" "copy"; then
        show_diff=false
    fi

    if are_different "${source_file}" "${target_file}" "$show_diff"; then
        echo "File '${source_file}' is different from '${target_file}'."
        # shellcheck disable=SC2154
        if [[ "$quiet" != true ]]; then
            case $actions in
                "ignore")
                    continue
                    ;;
                "merge or copy")
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
                "ask to merge")
                    confirm "Do you want to merge '${source_file}' to file '${target_file}'?" "n" && \
                    merge "$target_file" "$source_file" || true
                    ;;
                "merge")
                    merge "$target_file" "$source_file" || true
                    ;;
                "ask to copy")
                    confirm "Do you want to copy '${source_file}' to file '${target_file}'?" "n" && \
                    copy_file "$source_file" "$target_file"
                    ;;
                "copy")
                    copy_file "$source_file" "$target_file"
                    ;;
                *)
                    error "Unknown action '$actions' for files '${source_file}' and '${target_file}'." || 0
                    press_any_key
                    ;;
            esac
        fi
        echo ""
    fi
done
