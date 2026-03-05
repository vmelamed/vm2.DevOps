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
declare -x git_repos="${GIT_REPOS:-}"
declare -x target_dir=""
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-'v'}
declare -xa file_regexes=()

source "${script_dir}/diff-common.args.sh"
source "${script_dir}/diff-common.usage.sh"
source "${script_dir}/diff-common.functions.sh"

get_arguments "$@"

git_repos=$(realpath -e "$git_repos") || {
    warning "Neither --git-repos option nor GIT_REPOS environment variable is set or valid."
}

# Validate environment:
if [[ -z "$git_repos" ]] || ! git_repos=$(realpath -e "$git_repos"); then
    # git_repos was not set from option or env.var: try from the directory of the script's repo or from ($script_dir/../..)
    if ! r=$(root_working_tree "$script_dir") &&
       ! r=$(realpath -e "$(dirname "$script_dir/../..")"); then
        error "The common directory of the source repositories was not specified. Specify either the --git-repos option or export GIT_REPOS environment variable."
        exit 2
    fi
    git_repos=$(realpath -e "$(dirname "$r")") || {
        error "Could not determine the common directory of the source repositories. Specify either the --git-repos option or export GIT_REPOS environment variable."
        exit 2
    }
fi

# freeze the arguments
declare -xr git_repos
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

# make sure we are seeing .github and vm2.DevOps properly through git_repos
validate_source_repo ".github"
validate_source_repo "vm2.DevOps"
trace "All source repositories are in '$git_repos'"

# Resolve the target path
target_path=$(realpath "$target_dir")
if is_in "$target_path" "${git_repos}/vm2.DevOps" "${git_repos}/.github" ; then
    error "The target project cannot be '${git_repos}/vm2.DevOps' or '${git_repos}/.github'."
    exit 2
fi
trace "The target project is in '$target_path'"

ask=false
if [[ ! -d "$target_path/.github/workflows" ]]; then
    warning "The target directory '$target_path' does not contain a directory '.github/workflows' - it will be created."
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

# Load files and actions from the global config JSON
configure

# Modify the actions from custom config JSON if it exists
customize
if [[ ${#source_files[@]} -ne ${#target_files[@]} ]] || [[ ${#source_files[@]} -ne ${#file_actions[@]} ]]; then
    error "The data in the tables do not match."
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
                error "Unknown action '$actions' for files '${source_file}' and '${target_file}'." || 0
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
                    error "Unknown action '$actions' for files '${source_file}' and '${target_file}'." || 0
                    press_any_key
                    ;;
            esac
        fi
        echo ""
    fi
done
