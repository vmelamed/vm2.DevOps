#!/usr/bin/env bash

declare -xr script_name
declare -xr script_dir
declare -xr common_dir

declare -xr config_file="${script_dir}/diff-common.config.json"

declare -ar valid_actions=("copy" "merge" "ignore" "ask to copy" "ask to merge" "merge or copy")

all_actions_str=$(print_sequence -s=', ' -q='"' "${valid_actions[@]}")
declare -xr all_actions_str

declare LOCAL=""
declare REMOTE=""

declare -x diff_tool=""
declare -x diff_command=""
declare -xr default_diff_tool="delta" # "diff"
declare -rA diff_commands=(
    ["code"]="code --new-window --wait --diff \"\$LOCAL\" \"\$REMOTE\""
    ["vscode"]="code --new-window --wait --diff \"\$LOCAL\" \"\$REMOTE\""
    ["delta"]="delta --side-by-side --line-numbers --paging never \"\$LOCAL\" \"\$REMOTE\""
    ["git-delta"]="delta --side-by-side --line-numbers --paging never \"\$LOCAL\" \"\$REMOTE\""
    ["icdiff"]="icdiff --line-numbers --no-bold \"\$LOCAL\" \"\$REMOTE\""
    ["difft"]="dift \"\$LOCAL\" \"\$REMOTE\""
    ["difftastic"]="dift \"\$LOCAL\" \"\$REMOTE\""
    ["ydiff"]="ydiff -s -w 0 \"\$LOCAL\" \"\$REMOTE\""
    ["colordiff"]="colordiff -a -w -B --strip-trailing-cr -s -y -W 167 --suppress-common-lines \"\$LOCAL\" \"\$REMOTE\""
    ["diff"]="diff -a -w -B --strip-trailing-cr -s -y -W 167 --suppress-common-lines --color=auto \"\$LOCAL\" \"\$REMOTE\""
)

declare -x merge_tool=""
declare -x merge_command=""
declare -xr default_merge_tool="code"
declare -rA merge_commands=(
    ["code"]="code --new-window --wait --diff \"\$REMOTE\" \"\$LOCAL\""
    ["vscode"]="code --new-window --wait --merge \"\$REMOTE\" \"\$LOCAL\" \"\$REMOTE\" \"\$LOCAL\""
    ["meld"]="meld \"\$LOCAL\" \"\$REMOTE\""
    ["kdiff3"]="kdiff3 \"\$LOCAL\" \"\$REMOTE\""
    ["vimdiff"]="vimdiff \"\$LOCAL\" \"\$REMOTE\""
)

declare -x repos

# shellcheck disable=SC2034 # variable appears unused. Verify it or export it.
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function get_arguments()
{
    local option

    while [[ $# -gt 0 ]]; do
        option="$1"; shift
        if get_common_arg "$option"; then
            continue
        fi
        case "${option,,}" in
            # do not use the common options:
            -h|-v|-q|-x|-y|--help|--debugger|--quiet|--verbose|--trace|--dry-run )
                ;;

            --repos|-r )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                repos="$1"; shift
                ;;

            --minver-tag-prefix|-t )
                [[ $# -ge 1 ]] || usage false "Missing value for ${option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            * ) if [[ -z "$target_dir" ]]; then
                    target_dir="$option"
                else
                    usage false "Too many positional arguments: ${value}"
                fi
                ;;
        esac
    done
}

dump_all_variables()
{
    dump_vars "$@" -q \
        --header "Script Arguments:" \
        debugger \
        dry_run \
        verbose \
        quiet \
        --blank \
        repos \
        minver_tag_prefix \
        target_dir \
        # add var names above this line
}

## Validates that the given repository exists under the repos directory,
## is a git repository, and its HEAD is on or after the latest stable tag.
## Usage: validate_source_repo <repo-name>
function validate_source_repo()
{
    local repo_name=$1

    if [[ ! -d "${repos}/${repo_name}" ]]; then
        error "The '${repo_name}' repository was not cloned or is not under ${repos}."
    fi
    if ! is_inside_work_tree "${repos}/${repo_name}"; then
        error "The ${repo_name} repository at '${repos}/${repo_name}' is not a git repository."
    fi
    # shellcheck disable=SC2154 # semverTagReleaseRegex is referenced but not assigned.
    if ! is_on_or_after_latest_stable_tag "${repos}/${repo_name}" "$semverTagReleaseRegex"; then
        error "The HEAD of the '${repo_name}' repository is before the latest stable tag."
    fi
}

function find_target_path()
{
    dir=${1:-"$(pwd)"}

    if [[ ! -d "$dir" ]]; then
        # if it is not a directory - try under $repos
        trace "'$dir' is not a directory."
        dir=${repos%/}/${dir}
        if [[ ! -d "$dir" ]]; then
            # still not a directory - return false
            error "Could not find directory '$1' or '$dir'."
            return 1
        fi
    fi
    trace "Candidate: '$dir'."

    # here dir is a directory!
    if is_inside_work_tree "$dir"; then
        # if it is inside a tree - this is it, return true
        target_path="$(realpath -e "${dir%/}")"
        trace "Found it: '$target_path'."
        return 0
    fi

    if [[ $dir =~ /.* ]]; then
        # starts at the root - nowhere to go, return false
        trace "Nowhere to go from here '$1' -> '$dir'"
        return 1
    fi

    # try under $repos
    dir=${repos%/}/${dir}
    trace "New candidate: '$dir'."
    if [[ -d $dir ]] && is_inside_work_tree "$dir"; then
        # if it is inside a tree - this is it, return true
        trace "Found it: '$target_path'."
        return 0
    fi

    # nowhere else to look - return false
    trace "No good candidates for '$1'"
    return 1
}

## Loads all file actions from JSON configuration file
## Reads ${script_dir}/diff-common.config.json and populates arrays
function configure()
{
    if [[ ! -s "$config_file" ]]; then
        error "The configuration file $config_file was not found or is empty." || return 2
    fi
    # Validate JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        error "The configuration file $config_file contains invalid JSON." || return 2
    fi
    exit_if_has_errors

    # Populate the arrays
    local -i i=0
    local source_file target_file action
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
# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
function customize()
{
    local custom_config="${target_path}/diff-common.custom.json"

    if [[ ! -s "$custom_config" ]]; then
        trace "The custom configuration file $custom_config was not found or is empty."
    else
        trace "Loading tools and actions from the custom configuration file $custom_config."
        if ! jq empty "$custom_config" 2>/dev/null; then
            error "The custom configuration file $custom_config contains invalid JSON."
            return 1
        fi
    fi

    local -i changed_actions=0

    if [[ -s "$custom_config" ]]; then
        # Read each key-value pair from JSON
        local  relative_path action
        while IFS='=' read -r relative_path action; do
            # Validate action
            if ! is_in "$action" "${valid_actions[@]}"; then
                warning "Invalid action '$action' for '$relative_path' in $custom_config - must be one of: $all_actions_str."
                continue
            fi
            # Validate the path
            if [[ -z "$relative_path" ]]; then
                warning "Empty relative path in $custom_config."
                continue
            fi

            # Find corresponding target file and source file
            local target_file="${target_path}/${relative_path}"
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
                warning "Path '$relative_path' from $custom_config does not match any known target relative path."
                continue
            fi

            # Override the action
            file_actions["$source_file"]="$action"
            changed_actions=$((changed_actions + 1))
        done < <(jq -r '.action_overrides | to_entries | .[] | .key+"="+.value' "$custom_config" 2>"$_ignore") # convert JSON object to key=value pairs

        info "$script_name was customized successfully with ${changed_actions} modified actions."

        { IFS=$'\n' read -r diff_tool && IFS=$'\n' read -r diff_command; } < <(jq -r '.diff.tool, .diff.command' "$custom_config" 2>"$_ignore")
        { IFS=$'\n' read -r merge_tool && IFS=$'\n' read -r merge_command; } < <(jq -r '.merge.tool, .merge.command' "$custom_config" 2>"$_ignore")
    fi

    # Which diff tool to use:
    if [[ -z $diff_tool || -z $diff_command ]] || ! (command -p -v "$diff_tool" || which "$diff_tool" &>"$_ignore"); then
        # If we didn't get a diff tool from the config file, get it from git, BUT VSCode and meld are not good for this script:
        diff_tool=$(git config --global --get diff.tool 2>/dev/null) && \
        diff_command=$(git config --global --get "diff.$diff_tool.cmd" 2>/dev/null || true)

        if [[ -z "$diff_tool" || $diff_tool =~ (vs)?code|meld ]] || \
              ! (command -v -p "$diff_tool" > "$_ignore" || which "$diff_tool" &>"$_ignore"); then
            trace "There is no diff tool configured in git, it is inaccessible, or the configured tool is VS Code, or meld."

            if command  -p -v "$default_diff_tool" > "$_ignore" || which "$default_diff_tool" &>"$_ignore"; then
                diff_tool="$default_diff_tool"
            else
                trace "Falling back to good old 'diff'."
                diff_tool='diff'
            fi
            diff_command=${diff_commands[$diff_tool]}
        fi
    fi
    if [[ -n "$diff_tool" && -n "$diff_command" ]]; then
        trace "Diff with '$diff_tool': $diff_command"
    fi

    # Which merge tool to use:
    if [[ -z $merge_tool || -z $merge_command ]] || ! (command -p -v "$merge_tool" || which "$merge_tool" &>"$_ignore"); then
        # If we didn't get a merge tool from the config file, get it from git:
        merge_tool=$(git config --global --get merge.tool 2>/dev/null)
        if is_in "$merge_tool" "${!merge_commands[@]}"; then
            # our merge commands work better in this script than the configured in git ones
            merge_command=${merge_commands[$merge_tool]}
        else
            # we don't know it - get the git configured command
            merge_command=$(git config --global --get "mergetool.$merge_tool.cmd" 2>/dev/null || true)
        fi
        if [[ -z "$merge_tool" ]] || \
              ! (command -v -p "$merge_tool" > "$_ignore" || which "$merge_tool" &>"$_ignore"); then
            trace "There is no merge tool configured in git, or it is inaccessible. Will try the default $default_merge_tool."

            if command  -p -v "$default_merge_tool" > "$_ignore" || which "$default_merge_tool" &>"$_ignore"; then
                # try the default merge tool
                trace "Falling back to '$default_merge_tool'."
                merge_tool="$default_merge_tool"
                merge_command=${merge_commands[$merge_tool]}
            else
                error "Could not find a merge tool in the configuration, or configured in git, and the default tool $default_merge_tool is not installed."
            fi
        fi
    fi
    if [[ -n "$merge_tool" && -n "$merge_command" ]]; then
        trace "Merge with '$merge_tool': $merge_command"
    fi
}

## Compares two files using the default tool or the configured git diff.
## Usage: are_different <local-file> <remote-file>
function are_different()
{
    local display_diff=${3:-true}

    LOCAL=$1
    REMOTE=$2

    # compare fast, return fast, if no significant diffs; otherwise continue with the fancy diff tool of choice
    if diff -q -w -B "$LOCAL" "$REMOTE" > "$_ignore"; then
        return 1
    fi
    if [[ "$display_diff" != true ]]; then
        return 0
    fi
    local line=$diff_command
    eval "$line"
    return 0
}

## Loads the script arguments into the configured git merge.
## Usage: merge <local-file> <remote-file>
# shellcheck disable=SC2034 # BASE appears unused. Verify use (or export if used externally).
function merge()
{
    REMOTE=$2
    LOCAL=$1
    BASE=$2
    MERGED=$1

    local line=$merge_command
    eval "$line"
    return 0
}

## Copies a source file over a destination file, creating the destination directory if needed.
## Usage: copy_file <source-file> <destination-file>
function copy_file()
{
    local src_file="$1"
    local dest_file="$2"
    local dest_dir

    dest_dir=$(dirname "$dest_file")

    if [[ ! -d "$dest_dir" ]]; then
        execute mkdir -p "$dest_dir"
    fi
    execute cp "$src_file" "$dest_file"
    info "File '${src_file}' was copied to '${dest_file}'."
}
