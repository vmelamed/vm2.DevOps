#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2154 # GIT_REPOS is referenced but not assigned. It is expected to be set in the environment.
this_script=${BASH_SOURCE[0]}

script_name=$(basename "$this_script")
script_dir=$(dirname "$(realpath -e "$this_script")")
common_dir=$(realpath "${script_dir%/}/../../.github/actions/scripts")

declare -r script_name
declare -r script_dir
declare -r common_dir
# shellcheck disable=SC1091
source "${common_dir}/_common.sh"

declare repos="${GIT_REPOS:-$HOME/repos}"
declare target_repo=""
declare minver_tag_prefix=${MINVERTAGPREFIX:-'v'}

source "${script_dir}/diff-common.utils.sh"
source "${script_dir}/diff-common.usage.sh"

declare -r config_file="${script_dir}/diff-common.config.json"

declare -a source_files
declare -a target_files
declare -A file_actions
declare -ar valid_actions=("ask to copy" "copy" "merge or copy" "ignore")

all_actions_str=$(print_sequence -s=', ' -q='"' "${valid_actions[@]}")
declare -r all_actions_str

declare -r default_diff_tool="diff" # "delta"
declare -r default_merge_tool="code"

## Loads all file actions from JSON configuration file
## Reads ${script_dir}/diff-common.config.json and populates arrays
function load_actions()
{
    if [[ ! -s "$config_file" ]]; then
        error "The configuration file $config_file was not found or is empty." || return 2
    fi
    # Validate JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        error "The configuration file $config_file contains invalid JSON." || return 2
    fi

    # Populate the arrays
    local -i i=0
    while IFS='=' read -r source_file target_file action; do
        if [[ -z "$source_file" ]]; then
            error "Empty source file path found in $config_file." || true
        fi
        if [[ -z "$target_file" ]]; then
            error "Empty target file path found in $config_file." || true
        fi
        if [[ -z "$action" ]]; then
            error "Empty action found in $config_file." || true
        fi
        if ! is_in "$action" "${valid_actions[@]}"; then
            error "$action is not a valid action. Must be one of: $all_actions_str." || true
        fi
        exit_if_has_errors

        # Expand variables in paths
        eval "source_file=\"$source_file\""
        eval "target_file=\"$target_file\""

        source_files[i]="$source_file"
        target_files[i]="$target_file"
        file_actions["$source_file"]="$action"
        i=$((i+1))
    done < <(jq -r '.[] | .sourceFile + "=" + .targetFile + "=" + .action' "$config_file")

    trace "Loaded ${#source_files[@]} source files"
    trace "Loaded ${#target_files[@]} target files"
    trace "Loaded ${#file_actions[@]} pre-configured actions."
    info "$script_name was configured successfully with ${#source_files[@]} files and actions."
}

## Loads custom file actions from JSON file
## Reads ${target_path}/diff-common.custom.json and overrides file_actions
function load_custom_actions()
{
    local custom_config="${target_path}/diff-common.custom.json"

    if [[ ! -s "$custom_config" ]]; then
        trace "The custom configuration file $custom_config was not found or is empty."
        return 0
    else
        trace "Loading actions from the custom configuration file $custom_config."
    fi
    if ! jq empty "$custom_config" 2>/dev/null; then
        warning "The custom configuration file $custom_config contains invalid JSON - skipping custom actions"
        return 0
    fi

    local -i num_actions=0

    # Read each key-value pair from JSON
    while IFS='=' read -r rel_path action; do
        # Validate action
        if ! is_in "$action" "${valid_actions[@]}"; then
            warning "Invalid action '$action' for '$rel_path' in $custom_config - must be one of: $all_actions_str."
            continue
        fi
        # Validate the path
        if [[ -z "$rel_path" ]]; then
            warning "Empty relative path in $custom_config."
            continue
        fi

        # Find corresponding target file and source file
        local target_file="${target_path}/${rel_path}"
        local source_file=""
        local found=false

        for ((idx=0; idx<${#target_files[@]}; idx++)); do
            if [[ "${target_files[idx]}" == "$target_file" ]]; then
                source_file="${source_files[idx]}"
                found=true
                break
            fi
        done

        if [[ "$found" == false ]]; then
            warning "Path '$rel_path' from $custom_config does not match any known target relative path."
            continue
        fi
        # Override the action
        file_actions["$source_file"]="$action"
        num_actions=$((num_actions + 1))
    done < <(jq -r 'to_entries | .[] | .key + "=" + .value' "$custom_config" 2>/dev/null) # convert JSON object to key=value pairs
    info "$script_name was customized successfully with ${num_actions} modified actions."
}

function differences()
{
    LOCAL=$1
    REMOTE=$2

    # Get configured git diff tool
    local git_diff_tool
    git_diff_tool=$(git config --global --get diff.tool 2>/dev/null || echo "")

    if [[ -z "$git_diff_tool" || "$git_diff_tool" =~ code ]]; then
        trace "No git diff tool configured, using diff as default"
        git_diff_tool="$default_diff_tool"
    fi

    trace "Using diff tool: $git_diff_tool"
    case "$git_diff_tool" in
        delta|git-delta)
            delta --side-by-side --line-numbers "$LOCAL" "$REMOTE"
            ;;
        icdiff)
            icdiff --line-numbers --no-bold "$LOCAL" "$REMOTE"
            ;;
        difftastic|difft)
            difft "$LOCAL" "$REMOTE"
            ;;
        ydiff)
            ydiff -s -w 0 "$LOCAL" "$REMOTE"
            ;;
        colordiff)
            colordiff -a -w -B --strip-trailing-cr -s -y -W 167 --suppress-common-lines "$LOCAL" "$REMOTE"
            ;;
        diff)
            diff -a -w -B --strip-trailing-cr -s -y -W 167 --suppress-common-lines --color=auto "$LOCAL" "$REMOTE"
            ;;
        *)
            warning "Unknown diff tool '$git_diff_tool', falling back to standard diff"
            diff -a -w -B --strip-trailing-cr -s -y -W 167 --suppress-common-lines --color=auto "$LOCAL" "$REMOTE"
            ;;
    esac
}

function merge()
{
    LOCAL=$1
    REMOTE=$2

    # Get configured git merge tool
    local git_merge_tool
    git_merge_tool=$(git config --global --get merge.tool 2>/dev/null || echo "")

    if [[ -z "$git_merge_tool" ]]; then
        trace "No git merge tool configured, using VS Code as default"
        git_merge_tool="$default_merge_tool"
    fi

    if [[ -n "$git_merge_tool" ]]; then
        trace "Using git configured merge tool: $git_merge_tool"
        case "$git_merge_tool" in
            code|vscode)
                code --wait --merge "$REMOTE" "$LOCAL" "$REMOTE" "$LOCAL"
                ;;
            meld)
                meld "$LOCAL" "$REMOTE"
                ;;
            kdiff3)
                kdiff3 "$LOCAL" "$REMOTE"
                ;;
            vimdiff)
                vimdiff "$LOCAL" "$REMOTE"
                ;;
            *)
                # Try to use git mergetool infrastructure
                warning "Unknown merge tool '$git_merge_tool', attempting to use git mergetool command"
                git mergetool --tool="$git_merge_tool" -- "$LOCAL" "$REMOTE" 2>/dev/null || {
                    warning "Failed to invoke '$git_merge_tool', falling back to VS Code"
                    code --wait --merge "$REMOTE" "$LOCAL" "$REMOTE" "$LOCAL"
                }
                ;;
        esac
    fi
}

function copy_file()
{
    local src_file="$1"
    local dest_file="$2"

    local dest_dir
    dest_dir=$(dirname "$dest_file")
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi
    cp "$src_file" "$dest_file"
    echo "File '${dest_file}' was copied from '${src_file}'."
}

# shellcheck disable=SC2154
semverTagReleaseRegex="^${minver_tag_prefix}${semverReleaseRex}$"

get_arguments "$@"
create_tag_regexes "$minver_tag_prefix"

# shellcheck disable=SC2119 # Use dump_all_variables "$@" if function's $1 should mean script's $1.
dump_all_variables

if [[ -z "$repos" ]]; then
    error "The source repositories directory was not specified."
fi
[[ -z "$target_repo" ]] && target_repo="$(basename "$(git rev-parse --show-toplevel 2> /dev/null)")" || true
if [[ -z "$target_repo" ]]; then
    error "No target repository specified and could not determine it from the current git repository."
else
    if [[ ! -d "$target_repo" ]] || ! is_git_repo "$target_repo"; then
        if [[ -d "${repos%}/$target_repo" ]] && is_git_repo "${repos%}/$target_repo"; then
            target_repo="${repos%}/$target_repo"
        else
            error "Neither '${target_repo}' nor '${repos%}/$target_repo' are valid git repositories."
        fi
    fi
fi
if ! is_git_repo "${repos}/.github"; then
    error "The .github repository at '${repos}/.github' is not a git repository."
fi
if ! is_git_repo "${repos}/vm2.DevOps"; then
    error "The vm2.DevOps repository at '${repos}/vm2.DevOps' is not a git repository."
fi
if ! is_on_or_after_latest_stable_tag "${repos}/.github" "$semverTagReleaseRegex"; then
    error "The HEAD of the '.github' repository is before the latest stable tag."
fi
if ! is_on_or_after_latest_stable_tag "${repos}/vm2.DevOps" "$semverTagReleaseRegex"; then
    error "The HEAD of the 'vm2.DevOps' repository is before the latest stable tag."
fi
if [[ "$target_repo" =~ ${repos%}/.* ]]; then
    target_path="$target_repo"
else
    target_path="${repos%/}/$target_repo"
fi
trace "Target repository path: $target_path"

if [[ ! -d "$target_path" ]]; then
    error "The target repository '$target_path' does not exist."
fi
if [[ ! -d "$target_path/.github/workflows" ]]; then
    error "The target repository '$target_path' does not contain the '.github/workflows' directory."
fi
if [[ ! -d "$target_path/src" ]]; then
    warning "The target repository '$target_path' does not contain the 'src' directory."
fi

# Load file configurations from JSON
load_actions
# Modify the actions from JSON custom config if it exists
load_custom_actions

if [[ ${#source_files[@]} -ne ${#target_files[@]} ]] || [[ ${#source_files[@]} -ne ${#file_actions[@]} ]]; then
    error "The data in the tables do not match."
fi
exit_if_has_errors

declare -r repos
declare -r target_repo
declare -r minver_tag_prefix

declare -i i=0

while [[ $i -lt ${#source_files[@]} ]]; do
    source_file="${source_files[i]}"
    target_file="${target_files[i]}"
    actions="${file_actions[$source_file]}"
    i=$((i+1))

    echo -e "\n${source_file} <-----> ${target_file}:"

    if [[ ! -s "$target_file" ]]; then
        if [[ "$actions" != "ignore" ]]; then
            confirm "Target file '${target_file}' does not exist. Do you want to copy it from '${source_file}'?" "y" && \
            copy_file "$source_file" "$target_file"
        else
            warning "Target file '${target_file}' does not exist or is empty."
        fi
        continue
    fi

    if ! differences "${source_file}" "${target_file}"; then
        echo "File '${source_file}' is different from '${target_file}'."
        # shellcheck disable=SC2154
        if [[ "$quiet" != true ]]; then
            case $actions in
                "copy")
                    copy_file "$source_file" "$target_file"
                    ;;
                "ask to copy")
                    confirm "Do you want to copy '${source_file}' to file '${target_file}'?" "y" && \
                    copy_file "$source_file" "$target_file" || true
                    ;;
                "merge or copy")
                    case $(choose "What do you want to do?" \
                                  "Do nothing - continue" \
                                  "Merge the files" \
                                  "Copy '$source_file' file to '$target_file'") in
                        1) ;;
                        2) code --diff "$source_file" "$target_file" --new-window --wait ;;
                        3) copy_file "$source_file" "$target_file" ;;
                        *) ;;
                    esac
                    ;;
                "ignore")
                    continue
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
