#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2154 # GIT_REPOS is referenced but not assigned. It is expected to be set in the environment.
this_script=${BASH_SOURCE[0]}

script_name=$(basename "$this_script")
script_dir=$(dirname "$(realpath -e "$this_script")")
common_dir=$(realpath "${script_dir%/}/../../.github/actions/scripts")

declare -xr script_name
declare -xr script_dir
declare -xr common_dir

# shellcheck disable=SC1091
source "${common_dir}/_common.sh"

# arguments
declare -x repos="${GIT_REPOS:-$HOME/repos}"
declare -x target_dir=""
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-'v'}

source "${script_dir}/diff-common.utils.sh"
source "${script_dir}/diff-common.usage.sh"

get_arguments "$@"

repos=$(realpath -e "$repos")

# freeze the arguments
declare -xr repos
declare -xr target_dir
declare -xr minver_tag_prefix

create_tag_regexes "$minver_tag_prefix"

# shellcheck disable=SC2154
declare -xr semverTagReleaseRegex

# shellcheck disable=SC2119 # Use dump_all_variables "$@" if function's $1 should mean script's $1.
dump_all_variables

declare -a source_files
declare -a target_files
declare -A file_actions

# Validate environment:
if [[ -z "$repos" ]]; then
    error "The common directory of the repositories was not specified (GIT_REPOS env. var. or --repos option)."
    exit 2
fi
validate_source_repo ".github"
validate_source_repo "vm2.DevOps"
trace "All source repositories are in '$repos'"

# Resolve the project path
if ! find_target_path "$target_dir"; then
    error "Could not find a directory inside a working tree related to the parameter '$target_dir'."
    exit 2
fi
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

    echo -e "\n${source_file} <---------> ${target_file}:"

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
    if is_in "$actions" "copy" "merge" "ignore"; then
        show_diff=false
    fi

    if are_different "${source_file}" "${target_file}" "$show_diff"; then
        echo "File '${source_file}' is different from '${target_file}'."
        # shellcheck disable=SC2154
        if [[ "$quiet" != true ]]; then
            case $actions in
                "copy")
                    copy_file "$source_file" "$target_file"
                    ;;
                "merge")
                    merge "$target_file" "$source_file" || true
                    ;;
                "ignore")
                    continue
                    ;;
                "ask to copy")
                    confirm "Do you want to copy '${source_file}' to file '${target_file}'?" "y" && \
                    copy_file "$source_file" "$target_file"
                    ;;
                "ask to merge")
                    confirm "Do you want to merge '${source_file}' to file '${target_file}'?" "y" && \
                    merge "$target_file" "$source_file" || true
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
                *)
                    error "Unknown action '$actions' for files '${source_file}' and '${target_file}'." || 0
                    press_any_key
                    ;;
            esac
        fi
        echo ""
    fi
done
