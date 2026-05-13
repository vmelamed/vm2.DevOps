# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # _ignore is referenced but not assigned.

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

declare -x vm2_repos
declare -x custom_config=""

declare -xr action_ignore="ignore"
declare -xr action_merge_or_copy="merge or copy"
declare -xr action_ask_to_merge="ask to merge"
declare -xr action_merge="merge"
declare -xr action_ask_to_copy="ask to copy"
declare -xr action_copy="copy"

declare -axr valid_actions=(
    "$action_ignore"
    "$action_merge_or_copy"
    "$action_ask_to_merge"
    "$action_merge"
    "$action_ask_to_copy"
    "$action_copy"
)

all_actions_str=$(print_sequence -s=', ' -q='"' "${valid_actions[@]}")
declare -xr all_actions_str

# follow the git diff and merge commands parameters naming convention
declare LOCAL=""
declare REMOTE=""

# the diff and merge tools in effect
declare -x diff_tool=""
declare -x diff_command=""
declare -x merge_tool=""
declare -x merge_command=""

# configured diff and merge tools from the main config file, before applying any overrides from the custom config file:
declare -x config_diff_tool=""
declare -x config_diff_command=""
declare -x config_merge_tool=""
declare -x config_merge_command=""

# the fall-back default diff and merge tools
declare -xr default_diff_tool="delta" # "diff"
declare -xr default_merge_tool="code"

# some diff and merge commands for popular tools. The command should use $LOCAL and $REMOTE as placeholders for the file paths
# to compare or merge.
# These commands are used if the tool is specified but does not have a command configured in the config file or Git, and there
# is a hardcoded default command for the tool in this script.
declare -rA diff_commands=(
    ["code"]="code --new-window --wait --diff \"\$LOCAL\" \"\$REMOTE\""
    ["vscode"]="code --new-window --wait --diff \"\$LOCAL\" \"\$REMOTE\""   # vscode is alias for code, but just in case someone has it configured separately
    ["delta"]="delta --side-by-side --line-numbers --paging never \"\$LOCAL\" \"\$REMOTE\""
    ["git-delta"]="delta --side-by-side --line-numbers --paging never \"\$LOCAL\" \"\$REMOTE\""
    ["icdiff"]="icdiff --line-numbers --no-bold \"\$LOCAL\" \"\$REMOTE\""
    ["difft"]="dift \"\$LOCAL\" \"\$REMOTE\""
    ["difftastic"]="difft \"\$LOCAL\" \"\$REMOTE\""
    ["ydiff"]="ydiff -s -w 0 \"\$LOCAL\" \"\$REMOTE\""
    ["colordiff"]="colordiff -a -w -B --strip-trailing-cr -s -y -W 167 --suppress-common-lines \"\$LOCAL\" \"\$REMOTE\""
    ["diff"]="diff -w -B -a --strip-trailing-cr -s -y -W 167 --suppress-common-lines --color=auto \"\$LOCAL\" \"\$REMOTE\"" # add/remove -w -B - ignore whitespace and blank lines
    ["meld"]="meld \"\$LOCAL\" \"\$REMOTE\""
)

declare -rA merge_commands=(
    # ["code"]="code --new-window --wait --merge \"\$REMOTE\" \"\$LOCAL\" \"\$REMOTE\" \"\$LOCAL\""
    ["code"]="code --new-window --wait --diff \"\$REMOTE\" \"\$LOCAL\""
        # for the purpose of this script --diff works better for merging than --merge, because it allows to keep the merged
        # result in the same file and does not require to specify a BASE file, which is not relevant for our use case.
        # The user can still use the merge command with the appropriate parameters if they configure it in Git or the config file.
    ["vscode"]="code --new-window --wait --diff \"\$REMOTE\" \"\$LOCAL\""
    ["meld"]="meld \"\$LOCAL\" \"\$REMOTE\""
    ["kdiff3"]="kdiff3 \"\$LOCAL\" \"\$REMOTE\""
    ["vimdiff"]="vimdiff \"\$LOCAL\" \"\$REMOTE\""
)

## Loads all file actions from JSON configuration file
## Reads ${lib_dir}/diff-shared.config.json and populates arrays
function configure()
{
    (( $# == 2 ))                       || usage "${FUNCNAME[0]}() takes 2 mandatory arguments (provided $#) - the SoT directory and the target directory."
    [[ -d $1 ]]                         || error "${FUNCNAME[0]}() the specified SoT directory '$1' does not exist or is not a directory."
    [[ -d $2 ]]                         || error "${FUNCNAME[0]}() the specified SoT directory '$2' does not exist or is not a directory."

    local config_file="$1/diff-shared.config.json"
    local target_path="$2"

    # validate the config file and load the diff and merge tools from it:
    [[ -s "$config_file" ]]              || error "The configuration file '$config_file' was not found or is empty."
    jq empty "$config_file" 2>"$_ignore" || error "The configuration file '$config_file' contains invalid JSON."

    exit_if_has_errors

    # get the configured tools
    {
        IFS=$'\n' read -r diff_tool     &&
        IFS=$'\n' read -r diff_command  &&
        IFS=$'\n' read -r merge_tool    &&
        IFS=$'\n' read -r merge_command;
    } < <(get_tools "$config_file")

    # Populate the arrays
    local -i index=0
    local source_file target_file action
    # shellcheck disable=SC2034
    local vm2_sot_shared="${vm2_sot_repo_name}/templates/${sot}/content"

    while IFS='=' read -r source_file target_file file_action; do
        [[ -n "$source_file" ]]                     || error "Empty source file path found in '$config_file'."
        [[ -n "$target_file" ]]                     || error "Empty target file path found in '$config_file'."
        [[ -n "$file_action" ]]                     || error "Empty action found in '$config_file'."
        is_in "$file_action" "${valid_actions[@]}"  || error "'$action' is not a valid action. Must be one of: $all_actions_str."

        # Expand variables in paths
        eval "source_file=\"$source_file\""
        [[ -s "$source_file" ]]                     || error "Source file '$source_file' does not exist or is empty."
        eval "target_file=\"$target_file\""
        eval "file_action=\"$file_action\""
        # and assign into the model arrays by index:
        source_files[index]="$source_file"
        target_files[index]="$target_file"
        file_actions[index]="$file_action"

        ((++index)) || true
    done < <(jq -r '.files[] | .sourceFile + "=" + .targetFile + "=" + .action' "$config_file")

    trace "Loaded ${#source_files[@]} source files"
    trace "Loaded ${#target_files[@]} target files"
    trace "Loaded ${#file_actions[@]} pre-configured actions."

    # validate the configuration
    (( ${#source_files[@]} == ${#target_files[@]} && ${#source_files[@]} == ${#file_actions[@]} )) ||
        error "The data in the config tables does not match."

    exit_if_has_errors

    trace "$script_name was configured successfully with ${#source_files[@]} files and actions."
}

function parameterize()
{
    local rc=$failure

    (( ${#selectors_actions[@]} > 0 )) || {
        error "No command line arguments were provided to parameterize the file actions. Please provide at least one --file* argument to specify which files to compare and how."
        return "$rc"
    }

    local selector action
    local -a matching_actions
    local -i index
    local -i cnt
    local -i count=0

    # for each source file
    for (( index=0; index<${#source_files[@]}; index++ )); do
        matching_actions=()
        # check if it matches any of the provided patterns in the command line arguments
        for selector in "${!selectors_actions[@]}"; do
            if [[ "${source_files[index]}" == */$selector ]]; then
                # matches - override or keep the action for that file
                [[ -n ${selectors_actions[$selector]} ]] &&
                    action="${selectors_actions[$selector]}" ||
                    action="${file_actions[index]}"
                ! is_in "$action" "${matching_actions[@]}" && {
                    matching_actions+=("$action")
                    trace "File '${source_files[index]#"$vm2_repos/"}' matches selector '$selector' with action '$action'."
                }
            fi
        done

        cnt=${#matching_actions[@]}

        if (( cnt == 1 )); then
            # exactly one action - use it
            file_actions[index]="${matching_actions[0]}"
            (( ++count )) || true
        elif (( cnt > 1 )); then
            # multiple different actions matched - this is a CLI error, report it and skip the file (clear the action)
            file_actions[index]=""
            warning "Multiple patterns matched for '${source_files[index]#"$vm2_repos/"}' resulting in different actions: ${matching_actions[*]}. Please refine your file selectors so that each matches at most one file. The file will be skipped."
        else
            # no patterns matched - clear the action for that file (it will not be processed) and report a warning
            file_actions[index]=""
            trace "File '${source_files[index]#"$vm2_repos/"}' does not match any of the provided patterns: ${!selectors_actions[*]}. It will not be processed."
        fi
    done

    if (( count > 0 )); then
        trace "Parameterized actions for ${count} files based on the provided command line arguments."
        rc=$success
    else
        error "No files were matched by the provided command line arguments."
        rc=$failure
    fi
    return "$rc"
}

function resolve_target()
{
    [[ $# -eq 1 ]] || {
        error 3 "${FUNCNAME[0]} expects one argument (provided $#):" \
                "  1) the directory name of the target repository."
        return "$err_invalid_arguments"
    }

    rc="$success"
    output=$(resolve_repo_root "$vm2_repos" "$1" 2>"$_ignore") || rc=$?

    # We can only work with git repos or directories that have CI configured:
    (( rc == success || rc == err_dir_with_ci )) || {
        error "$rc" "The specified target directory '$1' is invalid. It should have CI configured in '.github/workflows'."
        return "$rc"
    }

    local target_root=""
    local target_path=""

    {
        IFS= read -r target_root;
        IFS= read -r target_path;
    } <<< "$output"

    # if it is a git repo then make sure it is in a clean state:
    if (( rc == success )); then
        branch="$(git -C "$target_root" branch --show-current 2>"$_ignore")" || {
            rc=$?
            error "The repository in the specified target directory '$target_dir' appears corrupted."
        }
        (( rc == success )) && ensure_fresh_git_state "$target_root" "$branch" ||
            error "The specified target repository at '$target_root' on branch '$branch' is not in a clean state. Please, commit or stash your changes."
    else
        branch="<not a git repository>"
    fi

    exit_if_has_errors

    trace "The target project is in '$target_path' with working tree directory root '$target_root', on a branch '$branch'."
    echo "$target_root"
    echo "$target_path"
}

## Loads custom file actions from JSON file
## Reads ${target_path}/diff-shared.custom.json and overrides file_actions
function customize()
{
    (( $# == 1 || $# == 2 ))        || usage "${FUNCNAME[0]}() requires 1 or 2 arguments (provided $#):" \
                                             "  1) target repository root directory path" \
                                             "  2) optional flag to customize the tools only."
    [[ -d $1 ]]                     || usage "${FUNCNAME[0]}() the target path is not a valid directory."
    [[ -z $2 ]] || is_boolean "$2"  || usage "${FUNCNAME[0]}() the second optional argument must be a boolean flag indicating whether to customize the tools only."

    target_path=$1
    only_tools=${2:-false}

    custom_config="${target_path}/diff-shared.custom.json"

    [[ -s "$custom_config" ]] || {
         trace "The customization file '$custom_config' does not exist or is empty. Continuing with the default configuration."
         return "$success"
    }

    trace "Validate the custom configuration file $custom_config."
    jq empty "$custom_config" 2>"$_ignore" || {
        error "The custom configuration file $custom_config contains invalid JSON."
        return "$failure"
    }

    {
        IFS=$'\n' read -r custom_diff_tool     &&
        IFS=$'\n' read -r custom_diff_command  &&
        IFS=$'\n' read -r custom_merge_tool    &&
        IFS=$'\n' read -r custom_merge_command;
    } < <(get_tools "$custom_config")

    [[ -n $custom_diff_tool ]]     && diff_tool="$custom_diff_tool"         || diff_tool="$config_diff_tool"
    [[ -n $custom_diff_command ]]  && diff_command="$custom_diff_command"   || diff_command="$config_diff_command"
    [[ -n $custom_merge_tool ]]    && merge_tool="$custom_merge_tool"       || merge_tool="$config_merge_tool"
    [[ -n $custom_merge_command ]] && merge_command="$custom_merge_command" || merge_command="$config_merge_command"

    # make sure the tools and commands are valid if they were customized:
    [[ -n $diff_tool    &&
       -n $diff_command &&
       -n $merge_tool   &&
       -n $merge_command ]] ||
        error "The configuration and/or customization files and the defaults must determine the names of the diff and merge tools" \
              "and the corresponding commands: " \
              "  diff tool:    '$diff_tool'" \
              "  diff command: '$diff_command'" \
              "  merge tool:   '$merge_tool'" \
              "  merge command: '$merge_command'"

    if [[ "$only_tools" == true ]]; then
        return "$success"
    fi

    local -i changed_actions=0

    if [[ -s "$custom_config" ]]; then
        # Read each key-value pair from JSON
        local  file_name action
        while IFS='=' read -r file_name action; do
            # Validate action
            is_in "$action" "${valid_actions[@]}" || {
                warning "Invalid action '$action' for '$file_name' in $custom_config - must be one of: $all_actions_str."
                continue
            }
            # Validate the path
            [[ -n "$file_name" ]] || {
                warning "Empty relative path in $custom_config."
                continue
            }

            # Find corresponding target file and source file
            local source_file=""
            local found=false

            local -i index
            for (( index=0; index<${#target_files[@]}; index++ )); do
                if [[ "${target_files[index]}" == ${target_path}/**/${file_name} ]]; then
                    # Override the action:
                    file_actions[index]="$action"
                    (( ++changed_actions )) || true
                    found=true
                    break
                fi
            done

            [[ "$found" == true ]] || {
                 [[ $action != "ignore" ]] && warning "Path '$file_name' from $custom_config does not match any known target relative path."
                continue
            }
        done < <(jq -r '.action_overrides | to_entries | .[] | .key+"="+.value' "$custom_config" 2>"$_ignore") # convert JSON object to key=value pairs

        $diff_only || info "$script_name was customized successfully with ${changed_actions} modified actions."
    fi
}

function get_tools()
{
    [[ $# -eq 1 ]] || usage "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): configuration or customization file."
    [[ -s $1 ]]    || usage "${FUNCNAME[0]}() the configuration or customization file does not exists or is empty."

    local file="$1"
    local dt dc mt mc

    # get the diff and merge tool commands from the main config file
    {
        IFS=$'\n' read -r dt &&
        IFS=$'\n' read -r dc &&
        IFS=$'\n' read -r mt &&
        IFS=$'\n' read -r mc;
    } < <(jq -r '.diff.tool, .diff.command, .merge.tool, .merge.command' "$file" 2>"$_ignore")

    if [[ -n $dt && -n $dc ]] &&
       (command -p -v "$dt" &>"$_ignore" || which "$dt" &>"$_ignore"); then
        # the configured diff tool/command is good, use it
        trace "Diff tool configured in $file: '$dt': $dc"
    else
        # get it from Git
        dt=$(git config --global --get diff.tool 2>"$_ignore") &&
        dc=$(git config --global --get "diff.$dt.cmd" 2>"$_ignore" || true)

        if [[ -n "$dt" && -n "$dc" ]] &&
           (command -v -p "$dt" > "$_ignore" || which "$dt" &>"$_ignore"); then
            trace "Diff tool configured in Git: '$dt': $dc"
        else
            # use the hardcoded defaults from this script
            dt="$default_diff_tool"
            dc=${diff_commands[$dt]}

            if [[ -n "$dt" && -n "$dc" ]] &&
               (command -v -p "$dt" > "$_ignore" || which "$dt" &>"$_ignore"); then
                trace "Diff tool configured by default: '$dt': $dc"
            else
                # fall-back to good ole 'diff' - it is not as good, but it will do the job and return good exit codes
                dt="diff"
                dc=${diff_commands[$dt]}
                trace "Diff tool fall-back to diff: '$dt': $dc"
            fi
        fi
    fi

    if [[ -n $mt && -n $mc ]] &&
       (command -p -v "$mt" &>"$_ignore" || which "$mt" &>"$_ignore"); then
        # the configured merge tool/command is good, use it
        trace "Merge tool configured in $file: '$mt': $mc"
    else
        # get it from Git
        mt=$(git config --global --get merge.tool 2>"$_ignore") || true
        mc=$(git config --global --get "mergetool.$mt.cmd" 2>"$_ignore" || true)
        if [[ -n $mt ]] && ([[ -n $mc ]] || is_in "$merge_tool" "${!merge_commands[@]}") &&
           (command -v -p "$mt" > "$_ignore" || which "$mt" &>"$_ignore"); then
            if is_in "$merge_tool" "${!merge_commands[@]}"; then
                # for the purposes of this script, our merge commands work better than the ones configured in git
                mc=${merge_commands[$mt]}
            fi
            trace "Merge tool from Git config with '$mt': $mc"
        else
            # use the hardcoded defaults from this script
            mt="$default_merge_tool"
            mc=${merge_commands[$mt]}

            if [[ -n $mt && -n $mc ]] &&
               (command -v -p "$mt" > "$_ignore" || which "$mt" &>"$_ignore"); then
                trace "Diff tool configured by default: '$mt': $mc"
            else
                # fall-back to good ole 'code' if available
                mt="code"
                if [[ -n $mt && -n $mc ]] &&
                   (command -v -p "$mt" > "$_ignore" || which "$mt" &>"$_ignore"); then
                    mc=${merge_commands[$mt]}
                    trace "Default merge tool with '$mt': $mc"
                else
                    trace "No merge tool was configured or none is available. Merge operations will not be possible."
                    mt=""
                    mc=""
                fi
            fi
        fi
    fi

    echo "$dt"
    echo "$dc"
    echo "$mt"
    echo "$mc"
}

# shellcheck disable=SC2059
function trace_files()
{
    local format
    case "${1,,}" in
        identical )
            format="%-84s ==== Identical ==== %-s\n"
            ;;
        different )
            format="%-84s ≠≠≠≠ Different ≠≠≠≠ %-s\n"
            ;;
        not_changed )
            format="%-84s →←→← No change →←→← %-s\n"
            ;;
        merged )
            format="%-84s →←→← Merged    →←→← %-s\n"
            ;;
        copied )
            format="%-84s →→→→ Copied    →→→→ %-s\n"
            ;;
        skipped )
            format="%-84s ---- Skipping  ---- %-s\n"
            ;;
        * )
            format="%-84s ??????????????????? %-s\n"
    esac
    trace "$(printf "$format" "${2#"$vm2_repos/${vm2_sot_repo_name}/templates/"}" "${3#"$vm2_repos/"}")"
}

## Compares two files using the default tool or the configured git diff.
## Usage: are_different <sot-file> <target-file> [<show-diff>]
function are_different()
{
    local display_diff=${3:-true}

    # follow the git diff command parameters naming convention, so the eval command can use them correctly
    LOCAL=$1
    REMOTE=$2

    # compare fast, return fast, if no significant diffs; otherwise continue with the fancy diff tool of choice
    if diff -q -w -B "$LOCAL" "$REMOTE" > "$_ignore"; then
        trace_files "identical" "$LOCAL" "$REMOTE"
        return 1
    else
        trace_files "different" "$LOCAL" "$REMOTE"
        $display_diff && eval "$diff_command"
        return 0
    fi
}

## Loads the script arguments into the configured git merge.
## Usage: merge <target-file> <sot-file>
# shellcheck disable=SC2034 # BASE appears unused. Verify use (or export if used externally).
function merge()
{
    # follow the git merge command parameters naming convention, so the eval command can use them correctly
    LOCAL=$1
    REMOTE=$2
    MERGED=$1
    BASE=$2

    before=$(sha256sum "$LOCAL")
    execute eval "$merge_command"
    after=$(sha256sum "$MERGED")

    [[ "$before" == "$after" ]] && {
        trace_files "not_changed" "$REMOTE" "$LOCAL"
        return 1
    } || {
        trace_files "merged" "$REMOTE" "$LOCAL"
        return 0
    }
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
    trace_files "copied" "$src_file" "$dest_file"
}
