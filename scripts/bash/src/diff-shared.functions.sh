# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_not_directory
declare -xri err_tool_not_found
declare -xri err_config_not_found
declare -xri err_file_not_found
declare -xri err_directory_not_found
declare -xri err_invalid_arguments
declare -xri err_action_not_found
declare -xri err_tool_not_configured
declare -xri err_tool_not_supported
declare -xri err_logic_error
declare -xri err_tool_error
declare -xri err_dir_with_ci
declare -xri err_argument_type
declare -xri err_not_file

declare -xr reset
declare -xr bold
declare -xr red
declare -xr green
declare -xr yellow
declare -xr blue
declare -xr bold_red
declare -xr bold_green
declare -xr bold_yellow
declare -xr bold_blue

declare -x _ignore

declare -xr vm2_sot_repo_name

declare -x vm2_repos
declare -x custom_config=""
declare -x diff_only
declare -x sot

declare -xr action_ignore="ignore"
declare -xr action_merge_or_copy="merge or copy"
declare -xr action_ask_to_merge="ask to merge"
declare -xr action_merge="merge"
declare -xr action_ask_to_copy="ask to copy"
declare -xr action_copy="copy"
declare -xr action_copy_shared="copy shared"
declare -xr action_ask_to_copy_shared="ask to copy shared"

declare -xra valid_actions=(
    "$action_ignore"
    "$action_merge_or_copy"
    "$action_ask_to_merge"
    "$action_merge"
    "$action_ask_to_copy"
    "$action_copy"
    "$action_copy_shared"
    "$action_ask_to_copy_shared"
)

#---------------------------------------------------------------------------------------------
# @description Markers that delimit a "shared" block within an otherwise private/local file -- content between
# them is expected to stay synced with the SoT, while everything outside is left entirely to the target
# repository. Matched as a plain substring anywhere on a line; any trailing text after the marker on that line
# (e.g. a human-readable "Beginning of shared content" label) is purely descriptive and ignored by the scanner.
# The two marker LINES themselves are delimiters and are never considered part of the shared content.
#---------------------------------------------------------------------------------------------
declare -xr shared_begin_marker='<<<==='
declare -xr shared_end_marker='===>>>'

# Additional 'are_different()' outcomes, alongside the existing '$positive'/'$negative':
declare -xri shared_equal=2
declare -xri shared_not_equal=3

all_actions_str=$(print_sequence -s=', ' -q='"' "${valid_actions[@]}")
declare -xr all_actions_str

# follow the git diff and merge commands parameters naming convention
declare LOCAL=""
declare REMOTE=""

# These are the diff and merge tools and respective commands from the main config file.
# Once read they are frozen and copied for every target repository.
declare -x config_diff_tool=""
declare -x config_diff_command=""
declare -x config_merge_tool=""
declare -x config_merge_command=""

# These are the data model of the script from the main config file.
# Once read they are also frozen and copied for every target repository.
# Bash does not have complex data structures, so we use parallel arrays to store the
# source files, target files and actions. The index of the arrays corresponds to the same file pair and action. For example,
# source_files[0], target_files[0] and file_actions[0] correspond to the same file pair and action:
declare -xa config_source_files    # array of the paths of the SoT files
declare -xa config_target_files    # array of target paths TEMPLATES corresponding to the SoT files by index
declare -xa config_file_actions    # array of default action strings corresponding to the SoT files by index

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

# the diff and merge tools in effect for the current target. It starts with copying the config_* tools from the main
# configuration and then get customized from the custom configuration, as needed.
declare -x diff_tool=""
declare -x diff_command=""
declare -x merge_tool=""
declare -x merge_command=""

# this is the data model of the script for the current target. It starts with copying the config_* arrays from the main
# configuration and then get customized from the config and the CLI commands, as needed.
declare -xa source_files
declare -xa target_files
declare -xa file_actions

# array [file] => [action string] for files specified on the CLI with --file* options
declare -xA selectors_actions

#---------------------------------------------------------------------------------------------
# @description Retrieves the diff and merge tool commands from the specified configuration or
#   from the git configuration or will assume defaults (diff and VS Code)
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes.
#
# @arg $1 _file The configuration or customization file containing the diff and merge tool
#   settings.
# @arg $2 _use_defaults if the file does not provide any of the diff or the merge tools -
#   use the defaults: either from the Git configuration or from the script defaults.
#
# @exitcode success/positive=0: If the diff and merge tool commands are retrieved
#   successfully.
#
# @stdout
#   The retrieved diff and merge tool names and commands:
#     - line 1: diff tool name
#     - line 2: diff tool command
#     - line 3: merge tool name
#     - line 4: merge tool command
#---------------------------------------------------------------------------------------------
function get_tools()
{
    (( $# == 2 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two arguments (provided $#):" \
                                                                      "  - the configuration or customization file." \
                                                                      "  - a flag to proceed with the defaults (optional, default is true)."
    [[ -v 1 && -s $1 ]]           || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be an existing, non-empty configuration or customization file (provided '${1:-<none>}')."
    [[ -v 2 ]] || is_boolean "$2" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2 to be a boolean value (provided '${2:-<none>}')."

    exit_if_has_bugs

    local _file="$1"
    local _use_defaults="${2:-true}"
    local _dt='' _dc='' _mt='' _mc=''

    # get the diff and merge tool commands from the main config file
    {
        read -r _dt || true
        read -r _dc || true
        read -r _mt || true
        read -r _mc || true
    } < <(jq -r '.diff.tool // empty, .diff.command // empty, .merge.tool // empty, .merge.command // empty' "$_file" 2>"$_ignore")

    if [[ -n $_dt && -n $_dc ]] && is_tool_present "$_dt"; then
        # there is a good, configured diff tool and command - use it
        trace "'diff' tool configured in '$_file': '$_dt': $_dc"
    elif ! $_use_defaults; then
        _dt=''
        _dc=''
        trace "No 'diff' tool was configured or available in '$_file'. Proceeding with the main configuration."
    else
        # get it from Git
        _dt=$(git config --get "diff.tool" 2>"$_ignore" || true) &&
        _dc=$(git config --get "diff.$_dt.cmd" 2>"$_ignore" || true)

        if [[ -n "$_dt" ]] && is_tool_present "$_dt" && { [[ -n "$_dc" ]] || is_in "$_dt" "${!diff_commands[@]}"; }; then
            # OK the git configured diff tool is available, if a command is not configured, get ours
            _dc=${_dc:-${diff_commands[$_dt]}}
            trace "Using the 'diff' tool configured in Git: '$_dt': $_dc"
        else
            # use the hardcoded defaults from this script
            _dt="$default_diff_tool"
            _dc=${diff_commands[$_dt]}

            if [[ -n "$_dt" && -n "$_dc" ]] && is_tool_present "$_dt"; then
                trace "Using the default 'diff' tool: '$_dt': $_dc"
            else
                # fall-back to good ole 'diff' - it is not as good, but it will do the job and return good exit codes
                _dt="diff"
                _dc=${diff_commands[$_dt]}
                trace "Fall-back to the classic 'diff': '$_dt': $_dc"
            fi
        fi
    fi

    # similar logic for the merge tool, but we prefer our default merge commands over the git configured ones
    # unless the git configuration is in our list of known merge commands
    if [[ -n $_mt && -n $_mc ]] && is_tool_present "$_mt"; then
        # the configured merge tool/command is good, use it
        trace "'merge' tool configured in $_file: '$_mt': $_mc"
    elif ! $_use_defaults; then
        _mt=''
        _mc=''
        trace "No 'merge' tool was configured or available in '$_file'. Proceeding with the main configuration."
    else
        # get it from Git
        _mt=$(git config --get "merge.tool" 2>"$_ignore" || true)
        _mc=$(git config --get "mergetool.$_mt.cmd" 2>"$_ignore" || true)

        if [[ -n $_mt ]] && is_tool_present "$_mt" && { [[ -n $_mc ]] || is_in "$_mt" "${!merge_commands[@]}"; }; then
            # for the purposes of this script, our hardcoded merge commands work better than the ones configured in git,
            # so we ignore the git config here if we can
            is_in "$_mt" "${!merge_commands[@]}" && _mc=${merge_commands[$_mt]}
            trace "Using the 'merge' tool configured in Git: '$_mt': $_mc"
        else
            # use the hardcoded defaults from this script
            _mt="$default_merge_tool"
            _mc=${merge_commands[$_mt]}

            if [[ -n $_mt && -n $_mc ]] && is_tool_present "$_mt"; then
                trace "Using the default 'merge' tool: '$_mt': $_mc"
            else
                # fall-back to good ole 'code' if available
                _mt="code"
                if [[ -n $_mt && -n $_mc ]] && is_tool_present "$_mt"; then
                    _mc=${merge_commands[$_mt]}
                    trace "Choosing Visual Studio Code as a 'merge' tool '$_mt': $_mc"
                else
                    warning "No 'merge' tool was configured or none is available. Merge operations will not be possible."
                    _mt=""
                    _mc=""
                fi
            fi
        fi
    fi

    printf "%s\n" "$_dt"
    printf "%s\n" "$_dc"
    printf "%s\n" "$_mt"
    printf "%s\n" "$_mc"
}

#---------------------------------------------------------------------------------------------
# @description Loads the diff/merge tool configuration and the list of source/target/action file entries from the SoT
# directory's 'diff-shared.config.json', populating the global model arrays 'source_files', 'target_files', and
# 'file_actions'. This is a top-level CLI configuration step: on any validation or configuration failure it reports the
# error(s) via 'error' and exits the process via 'exit_if_has_errors' rather than returning an error code.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string the SoT directory path (must exist and be a directory; the configuration file '$1/diff-shared.config.json' MUST
#   exist, be non-empty, and contain valid JSON)
# @arg $2 string the target repository directory path (must exist and be a directory)
# @exitcode success/positive=0: configuration loaded and validated successfully
#
# @example
#   configure "$sot_path" "$target_path"
#---------------------------------------------------------------------------------------------
function configure()
{
    (( $# == 2 ))                 || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                      "  - the SoT directory" \
                                                                      "  - the target directory"
    [[ -v 1 && -d $1 ]]           || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the SoT directory, to be an existing directory (provided '${1:-<none>}')."
    [[ -v 2 && -d $2 ]]           || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the target directory, to be an existing directory (provided '${2:-<none>}')."
    exit_if_has_bugs

    local _sot_path=$1
    local _config_file="$_sot_path/diff-shared.config.json"
    local _schema_config="$_sot_path/diff-shared.config.schema.json"

    # validate the config file and load the diff and merge tools from it:
    [[ -s "$_config_file" ]]                               || error -ec "$err_argument_value" "The configuration file '$_config_file' was not found or is empty."
    jq empty "$_config_file" 2>"$_ignore"                  || error -ec "$err_argument_value" "The configuration file '$_config_file' contains invalid JSON."
    validate_json_schema "$_config_file" "$_schema_config" || error -ec "$err_argument_value" "The configuration file '$_config_file' does not conform to the schema '$_schema_config'."
    exit_if_has_errors

    trace "Configuration file '$_config_file' is valid."

    # get the configured tools and freeze them
    {
        read -r config_diff_tool;
        read -r config_diff_command;
        read -r config_merge_tool;
        read -r config_merge_command;
    } < <(get_tools "$_config_file" true)   # if not provided - use the defaults

    readonly config_diff_tool
    readonly config_diff_command
    readonly config_merge_tool
    readonly config_merge_command

    # Populate the arrays
    local -i _index=0

    # the name "vm2_sot_shared" is used as a macro variable in the source file paths in the json configuration - do not rename!
    # shellcheck disable=SC2034 # Variable was used as an array but is now assigned a string.
    local vm2_sot_shared="$vm2_sot_repo_name/templates/$sot/content"
    local _source_file _target_file _file_action

    while IFS='=' read -r _source_file _target_file _file_action; do
        [[ -n "$_source_file" ]]                    || error -ec "$err_argument_value" "Empty source file path found in '$_config_file'."
        [[ -n "$_target_file" ]]                    || error -ec "$err_argument_value" "Empty target file path found in '$_config_file'."
        [[ -n "$_file_action" ]]                    || error -ec "$err_argument_value" "Empty action found in '$_config_file'."
        is_in "$_file_action" "${valid_actions[@]}" || error -ec "$err_argument_value" "'$_file_action' is not a valid action. Must be one of: $all_actions_str."

        # Expand the macro-variables "vm2_repos" and "vm2_sot_shared" in the source file paths BUT
        # do not expand the target file path here, it will be expanded later when iterating the targets.
        # Thus config_target_files stores the target file paths as templates for later expansion.
        eval "_source_file=\"$_source_file\""       # uses $vm2_repos and $vm2_sot_shared as a macro variables
        [[ -s "$_source_file" ]]                    || error -ec "$err_argument_value" "Source file '$_source_file' does not exist or is empty."

        # and assign into the model arrays by index:
        config_source_files[_index]="$_source_file"
        config_target_files[_index]="$_target_file" # store the target file path as-is - as a template for later expansion
        config_file_actions[_index]=$_file_action

        ((++_index)) || true
    done < <(jq -r '.files[] | (.sourceFile // "") + "=" + (.targetFile // "") + "=" + (.action // "")' "$_config_file")

    readonly config_source_files
    readonly config_target_files
    readonly config_file_actions

    trace "Loaded ${#config_source_files[@]} source files"
    trace "Loaded ${#config_target_files[@]} target file templates"
    trace "Loaded ${#config_file_actions[@]} pre-configured actions."

    # validate the configuration
    (( ${#config_source_files[@]} == ${#config_target_files[@]} && ${#config_source_files[@]} == ${#config_file_actions[@]} )) ||
        error -ec "$err_logic_error" "The data in the config tables does not match."

    exit_if_has_errors

    trace "$script_name was configured successfully with ${#config_source_files[@]} files and actions."
}

# shellcheck disable=SC2034 # Variable was used as an array but is now assigned a string.
function configure_target_files()
{
    (( $# == 2 ))                          || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                               "  - the path to the target repository's working tree root directory" \
                                                                               "  - the name of an indexed array that will store the expanded target file paths"
    [[ ! -v 1 || -d $1 ]]                  || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the target repository's working tree root directory, to be an existing directory (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_indexed_array "$2"  || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2 to be the name of an indexed array variable (provided '${2:-<none>}')."
    exit_if_has_bugs

    # the name "target_repo_path" is used as a macro variable in the target file paths in the json configuration - do not rename!
    local target_repo_path=$1
    # shellcheck disable=SC2178
    local -n _target_files=$2
    _target_files=()

    local _target_file
    local -i _index

    for (( _index=0; _index<${#config_target_files[@]}; _index++ )); do
        eval "_target_file=\"${config_target_files[_index]}\""
        _target_files[_index]="$_target_file" # store the expanded actual target file path
    done
}

#---------------------------------------------------------------------------------------------
# @description Loads per-repository customizations from '<target_path>/diff-shared.custom.json', if present, overriding
# the configured diff/merge tools and (unless 'only_tools' is set) the per-file actions in the global 'file_actions'
# array. If the custom configuration file does not exist or is empty, the function leaves the configured tools and
# actions untouched and returns successfully.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string the SoT directory path (must exist and be a directory; the configuration file '$1/diff-shared.config.json' MUST
#   exist, be non-empty, and contain valid JSON)
# @arg $2 string target repository root directory path (must be an existing directory)
#
# @exitcode success/positive=0: customization applied successfully, or no custom configuration file was found
# @exitcode failure/negative=1: the custom configuration file contains invalid JSON
#
# @example
#   customize "$target_root" true
#   customize "$target_root" false
#---------------------------------------------------------------------------------------------
function customize()
{
    (( $# == 2 ))       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two arguments (provided $#)" \
                                                            "  - path to the SoT directory" \
                                                            "  - path to the target repository directory"
    [[ -v 1 && -d $1 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the SoT directory, to be an existing directory (provided '${1:-<none>}')."
    [[ -v 2 && -d $2 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the target repository path, to be an existing directory (provided '${1:-<none>}')."
    exit_if_has_bugs

    local _sot_path=$1
    local _target_root=$2
    local _custom_config="$_target_root/diff-shared.custom.json"
    local _schema_custom="$_sot_path/diff-shared.custom.schema.json"

    [[ -s "$_custom_config" ]] || {
         trace "The customization file '$_custom_config' does not exist or is empty. Continuing with the default configuration."
         return "$success"
    }
    # validate the customization config file and load the diff and merge tools from it:
    validate_json_schema "$_custom_config" "$_schema_custom"
    exit_if_has_errors

    trace "Configuration file '$_custom_config' is valid."

    # customize the tools based on the customization configuration file
    {
        read -r custom_diff_tool;
        read -r custom_diff_command;
        read -r custom_merge_tool;
        read -r custom_merge_command;
    } < <(get_tools "$_custom_config" false)    # do not use the defaults - if not customized, leave empty and we'll use the main configuration below

    [[ -n $custom_diff_tool && -n $custom_diff_command ]] && {
        diff_tool="$custom_diff_tool"
        diff_command="$custom_diff_command"
    }

    [[ -n $custom_merge_tool && -n $custom_merge_command ]] && {
        merge_tool="$custom_merge_tool"
        merge_command="$custom_merge_command"
    }

    local -i _changed_actions=0

    if [[ -s "$_custom_config" ]]; then
        # Read each key-value pair from JSON
        local  _file_name _action
        while IFS='=' read -r _file_name _action; do
            # Validate action
            is_in "$_action" "${valid_actions[@]}" || {
                warning "Invalid action '$_action' for '$_file_name' in $_custom_config - must be one of: $all_actions_str."
                continue
            }
            # Validate the path
            [[ -n "$_file_name" ]] || {
                warning "Empty relative path in $_custom_config."
                continue
            }

            # Find corresponding target file and source file
            local _found=false

            local -i _index
            for (( _index=0; _index<${#target_files[@]}; _index++ )); do
                if [[ "${target_files[_index]}" == $_target_root/$_file_name ||
                      "${target_files[_index]}" == $_target_root/*/$_file_name ]]; then
                    # Override the action:
                    file_actions[_index]="$_action"
                    (( ++_changed_actions )) || true
                    _found=true
                    break
                fi
            done

            [[ "$_found" == true ]] || {
                 [[ $_action != "ignore" ]] && trace "Path '$_file_name' from $_custom_config ${bold}does not match${reset} any known target relative path."
                continue
            }
        done < <(jq -r '.action_overrides | to_entries | .[] | .key+"="+.value' "$_custom_config" 2>"$_ignore") # convert JSON object to key=value pairs

        $diff_only || info "$script_name was customized successfully with $_changed_actions modified actions."
    fi
}

#---------------------------------------------------------------------------------------------
# @description: Changes the set of files and the respective file actions from the config
#   file(s) based on the provided command line arguments.
#---------------------------------------------------------------------------------------------
function parameterize()
{
    ((${#selectors_actions[@]} > 0 )) || return "$success"

    local _selector _action
    local -i _index
    local -i _count=0

    local _source_file _file_action
    local -a _matching_actions
    local -i _cnt_matching_actions

    for (( _index=0; _index<${#source_files[@]}; _index++ )); do
        # for each source file
        _source_file="${source_files[_index]}"
        _file_action="${file_actions[_index]}"

        _matching_actions=()

        # check if it matches any of the provided patterns in the command line arguments and if it does modify the action accordingly
        for _selector in "${!selectors_actions[@]}"; do
            if [[ $_source_file == */$_selector ]]; then

                # matches - override or keep the action for that file
                [[ -n ${selectors_actions[$_selector]} ]] &&
                    _action="${selectors_actions[$_selector]}" ||   # e.g. -fc|--file-copy
                    _action="$_file_action"                         # -f|--file

                { is_empty_array _matching_actions || ! is_in "$_action" "${_matching_actions[@]}"; } && {
                    # add the action to the list of matching actions if it is not already present
                    _matching_actions+=("$_action")
                    trace "File '${_source_file#"${vm2_repos:-}/"}' ${bold}${green}matches${reset} selector '${_selector:-<none>}' with action '${_action:-<none>}'."
                }
                # keep checking other selectors for this source file, if they specify different actions - we'll ignore it all together below
            fi
        done

        _cnt_matching_actions=${#_matching_actions[@]}

        if (( _cnt_matching_actions == 1 )); then
            # exactly one action - use it
            file_actions[_index]="${_matching_actions[0]}"
            (( ++_count )) || true
        elif (( _cnt_matching_actions > 1 )); then
            # multiple different actions matched - this is a CLI error, report it and skip the file (clear the action, as we are not certain what to do) and report as a warning
            file_actions[_index]=""
            warning "Multiple patterns matched for '${source_files[_index]#"$vm2_repos/"}' resulting in different actions: ${_matching_actions[*]}. Please refine your file selectors so that each matches at most one file. The file will not be processed."
        else
            # no patterns matched - clear the action for that file (clear the action, as we are not certain what to do) and report as a warning
            file_actions[_index]=""
            trace "File '${source_files[_index]#${vm2_repos}/}' ${red}does not match${reset} any of the provided patterns: ${!selectors_actions[*]}. The file will not be processed"
        fi
    done

    if (( _count > 0 )); then
        trace "Parameterized actions for $_count files based on the provided command line arguments."
    else
        warning -sd 3 -ec "$err_argument_value" "No files were matched by the provided command line arguments."
    fi
}

#---------------------------------------------------------------------------------------------
# @description Resolves the target repository directory and ensures it is in a valid state.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string the directory of the vm2 repositories (must be an existing directory)
# @arg $2 string the directory name of the target repository
# @arg $3 string nameref to the variable to store the absolute path of the root of the target repository
# @arg $4 string nameref to the variable to store the absolute path of the target repository directory
#
# @exitcode success/positive=0: the target repository directory is resolved and in a valid state
# @exitcode err_not_directory=17: the target repository directory does not exist or is not a valid git repository with CI configured
#---------------------------------------------------------------------------------------------
function resolve_target()
{
    local -i _rc="$success"

    (( $# == 4 ))        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects four arguments (provided $#):" \
                                                                "  - the directory of the repositories" \
                                                                "  - the directory name of the target repository" \
                                                                "  - the name of the variable to store the absolute path of the root of the target repository" \
                                                                "  - the name of the variable to store the absolute path of the target repository directory"
    [[ -n $1 && -d $1 ]] || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 1, the directory of the vm2 repositories, to be a non-empty existing directory."
    [[ -n $2 ]]          || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the directory name of the target repository, to be a non-empty existing directory."
    is_variable "$3"     || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3, the name of the variable to store the absolute path to the root of the working tree of the target repository."
    is_variable "$4"     || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 4, the name of the variable to store the absolute path to the target repository directory."

    exit_if_has_bugs

    local _repos="$1"
    local _r="$2"
    local -n _target_root="$3"
    local -n _target_path="$4"
    local branch="<not a git repository>"

    resolve_repo_root "$_repos" "$_r" _target_root _target_path || _rc=$?

    # We can only work with git repos or directories that have CI configured:
    (( _rc == success || _rc == err_dir_with_ci )) || {
        error -ec "$_rc" "The specified target directory '${_repos%/}/${_r#/}' is invalid. It should have CI configured in '.github/workflows'."
        return "$_rc"
    }

    (( _rc == err_dir_with_ci )) && {
        warning "The root directory of the target project is '$_target_root', but it is not a git repository yet."
        return "$success"
    }

    # if it is a git repo then make sure it is in a clean state:
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    branch="$(git -C "$_target_root" branch --show-current 2>"$_ignore")" && {
        ensure_fresh_git_state "$_target_root" "$branch" || {
            _rc=$err_logic_error
            error -ec "$_rc" "The specified target repository at '$_target_root' on branch '$branch' is not in a clean state." \
                                                "Commit or stash your changes."
        }
    } || {
        _rc=$err_tool_error
        error -ec "$_rc" "The repository in the specified target directory '$1' appears corrupted."
    }

    trace "The Git working tree root of the target repository is '$_target_root', on a branch '$branch'."
    return "$_rc"
}

function trace_files()
{
    local _format
    case "${1,,}" in
        identical )
            _format="%-84s ${green}==== Identical ====${reset} %-s\n"
            ;;
        different )
            _format="%-84s ${red}≠≠≠≠ Different ≠≠≠≠${reset} %-s\n"
            ;;
        not_changed )
            _format="%-84s ${yellow}→←→← No change →←→←${reset} %-s\n"
            ;;
        merged )
            _format="%-84s ${blue}→←→← Merged    →←→←${reset} %-s\n"
            ;;
        copied )
            _format="%-84s ${green}→→→→ Copied    →→→→${reset} %-s\n"
            ;;
        skipped )
            _format="%-84s ${yellow}---- Skipping  ----${reset} %-s\n"
            ;;
        * )
            _format="%-84s ??????????????????? %-s\n"
    esac
    # shellcheck disable=SC2059 # Suppress warnings about printf format strings being non-literal
    trace "$(printf "$_format" "${2#"$vm2_repos/$vm2_sot_repo_name/templates/"}" "${3#"$vm2_repos/"}")"
}

#---------------------------------------------------------------------------------------------
# @description Locates a single well-formed '$shared_begin_marker'/'$shared_end_marker' pair in the given file
# and reports their 1-based line numbers via the two nameref output variables.
#
# Notes:
#   - Fails (without a bug-exit -- this is an expected runtime outcome, not a caller contract violation) if the
#     file has zero or more than one begin marker, zero or more than one end marker, or the begin marker is not
#     strictly before the end marker. Only a single shared block per file is supported.
#
# @arg $1 string path to the file to scan
# @arg $2 string name of the variable to receive the begin marker's line number
# @arg $3 string name of the variable to receive the end marker's line number
#
# @exitcode success/positive=0: exactly one well-formed marker pair was found
# @exitcode failure/negative=1: no well-formed, single marker pair could be found
#---------------------------------------------------------------------------------------------
function __find_shared_markers()
{
    (( $# == 3 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly three arguments (provided $#):" \
                                                                         "  - the file to scan for a shared-content marker pair" \
                                                                         "  - the name of the variable to receive the begin marker's line number" \
                                                                         "  - the name of the variable to receive the end marker's line number"
    [[ -v 1 && -f $1 ]]              || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the file to scan, to be an existing file (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to be the name of a defined variable (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_variable "$3" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3 to be the name of a defined variable (provided '${3:-<none>}')."

    exit_if_has_bugs

    local -n _begin_line_out="$2"
    local -n _end_line_out="$3"

    local -i _begin_count _end_count

    _begin_count=$(grep -Fc -- "$shared_begin_marker" "$1") || true
    _end_count=$(grep -Fc -- "$shared_end_marker" "$1")     || true

    (( _begin_count == 1 && _end_count == 1 )) || return "$negative"

    _begin_line_out=$(grep -Fn -- "$shared_begin_marker" "$1" | cut -d: -f1)
    _end_line_out=$(grep -Fn -- "$shared_end_marker" "$1" | cut -d: -f1)

    (( _begin_line_out < _end_line_out )) || return "$negative"

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Extracts the content strictly between a single '$shared_begin_marker'/'$shared_end_marker' pair
# in the given file, via the nameref output variable. The two marker lines themselves are excluded.
#
# Notes:
#   - Fails (without a bug-exit -- see '__find_shared_markers()') if no well-formed, single marker pair exists.
#
# @arg $1 string path to the file to scan
# @arg $2 string name of the variable to receive the extracted shared block content
#
# @exitcode success/positive=0: exactly one well-formed marker pair was found; the shared block content
#   (possibly empty) was stored in the output variable
# @exitcode failure/negative=1: no well-formed, single marker pair could be found
#
# @example
#   get_shared_block "$source_file" _shared_content || warning "..."
#---------------------------------------------------------------------------------------------
function get_shared_block()
{
    (( $# == 2 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                         "  - the file to scan for a shared-content marker pair" \
                                                                         "  - the name of the variable to receive the extracted shared content"
    [[ -v 1 && -f $1 ]]              || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the file to scan, to be an existing file (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to be the name of a defined variable (provided '${2:-<none>}')."

    exit_if_has_bugs

    local -n _shared_content_out="$2"

    local -i _begin_line _end_line

    __find_shared_markers "$1" _begin_line _end_line || return "$negative"

    _shared_content_out=$(sed -n "$((_begin_line + 1)),$((_end_line - 1))p" "$1")

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Compares two files with a fast whitespace/blank-line-insensitive 'diff -q -w -B'. If they are identical,
# returns immediately. If they differ, also scans both files for a single '$shared_begin_marker'/'$shared_end_marker'
# pair and, when both are found and well-formed, compares only the content between them -- letting a caller sync just
# the "shared" portion of an otherwise private/local file (see 'copy_shared_block()'). If either file's markers are
# missing or malformed, falls back to the plain whole-file result, so a broken marker never blocks the file --
# warning about it only when 'warn_no_markers' is true (callers whose action doesn't understand shared blocks at
# all, e.g. plain 'copy'/'merge'/'ignore', pass false, since most files have no markers and a warning on every one
# of them would be noise; it still traces at the lower verbosity level either way).
# If 'show_diff' is true and the whole files differ, also launches the configured (or default) visual diff tool via
# '$diff_command' against the global 'LOCAL'/'REMOTE' variables, which this function sets before evaluating it.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string SoT (source of truth) file path; assigned to the global 'LOCAL' for '$diff_command' to use
# @arg $2 string target file path; assigned to the global 'REMOTE' for '$diff_command' to use
# @arg $3 bool _show_in_diff_tool whether to also display the visual diff when the files differ
# @arg $4 bool _warn_no_markers whether to warn if shared-block markers are missing or malformed
#
# @exitcode failure/negative=1: the files are identical
# @exitcode success/positive=0: the files differ, and either file lacks a well-formed shared-block marker pair
# @exitcode $shared_equal=2: the files differ, but their shared blocks (between the markers) are identical
# @exitcode $shared_not_equal=3: the files differ, and their shared blocks also differ
#
# @example
#   are_different "$source_file" "$target_file" false true
#---------------------------------------------------------------------------------------------
function are_different()
{
    (( $# == 4 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires four arguments (provided $#):" \
                                                                       "  - the SoT file" \
                                                                       "  - the target file" \
                                                                       "  - the display-diff flag." \
                                                                       "  - the warning if no shared-block markers flag."
    [[ ! -v 1 || -s $1 ]]           || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the SoT file, to be an existing, non-empty file (provided '${1:-<none>}')."
    [[ ! -v 2 || -s $2 ]]           || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 2, the target file, to be an existing, non-empty file (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_boolean "$3" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 3, the display-diff flag, to be 'true' or 'false' (provided '${4:-<none>}')."
    [[ ! -v 4 ]] || is_boolean "$4" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 4, the warn if shared-block markers are missing or malformed flag, to be 'true' or 'false' (provided '${4:-<none>}')."

    exit_if_has_bugs

    # follow the git diff command parameters naming convention, so the eval command can use them correctly
    LOCAL=$1
    REMOTE=$2

    local _show_in_diff_tool=$3
    local _warn_no_markers=$4

    # compare fast, return fast, if no significant diffs; otherwise continue with the fancy diff tool of choice
    if diff -q -w -B "$LOCAL" "$REMOTE" > "$_ignore"; then
        trace_files "identical" "$LOCAL" "$REMOTE"
        (( ++summary_identical_count ))
        return "$negative"
    fi

    trace_files "different" "$LOCAL" "$REMOTE"
    $_show_in_diff_tool && eval "$diff_command"
    (( ++summary_diff_count ))

    local _source_shared _target_shared

    if get_shared_block "$LOCAL" _source_shared && get_shared_block "$REMOTE" _target_shared; then
        local _source_shared_file _target_shared_file
        _source_shared_file=$(mktemp)
        _target_shared_file=$(mktemp)
        printf '%s\n' "$_source_shared" > "$_source_shared_file"
        printf '%s\n' "$_target_shared" > "$_target_shared_file"

        local -i _shared_rc
        if diff -q -w -B "$_source_shared_file" "$_target_shared_file" > "$_ignore"; then
            _shared_rc=$shared_equal
        else
            _shared_rc=$shared_not_equal
        fi

        rm -f "$_source_shared_file" "$_target_shared_file"
        return "$_shared_rc"
    fi

    declare warning_message="Could not find a single, well-formed shared-content marker pair ('$shared_begin_marker' / '$shared_end_marker') in '$LOCAL' and/or '$REMOTE' -- falling back to the whole-file result."

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    $_warn_no_markers &&
        warning "$warning_message" ||
        trace "$warning_message"

    return "$positive"
}

#---------------------------------------------------------------------------------------------
# @description Runs the configured (or default) merge tool via '$merge_command' to merge the SoT file into the target
# file in place. Follows the Git merge parameter naming convention ('LOCAL', 'REMOTE', 'MERGED', 'BASE') so that
# '$merge_command' can reference these globals. Detects whether the merge actually changed the target file by comparing
# a SHA-256 hash of the target file before and after running the tool.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string SoT (source of truth) file path; assigned to the globals 'REMOTE' and 'BASE'
# @arg $2 string target file path; assigned to the globals 'LOCAL' and 'MERGED' (the file the merge tool is expected to
#   modify in place)
#
# @exitcode success/positive=0: the target file's content changed as a result of the merge
# @exitcode failure/negative=1: the target file's content is unchanged after the merge tool ran
#
# @example
#   merge "$source_file" "$target_file"
#---------------------------------------------------------------------------------------------
function merge()
{
    (( $# == 2 ))       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                            "  - the SoT file" \
                                                            "  - the target file"
    [[ -v 1 && -f $1 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the SoT file, to be an existing file (provided '${1:-<none>}')."
    [[ -v 2 && -f $2 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 2, the target file, to be an existing file (provided '${2:-<none>}')."

    exit_if_has_bugs

    # follow the git merge command parameters naming convention, so the eval command can use them correctly
    LOCAL=$2
    REMOTE=$1
    MERGED=$2
    # BASE=$1 not used for now...

    before=$(sha256sum "$LOCAL")
    execute eval "$merge_command"
    after=$(sha256sum "$MERGED")

    # shellcheck disable=SC2015 # Suppress warnings about using '&&' and '||' for control flow instead of 'if' statements
    [[ "$before" == "$after" ]] && {
        trace_files "not_changed" "$REMOTE" "$LOCAL"
        (( ++summary_not_merged_count ))
        return "$failure"
    } || {
        trace_files "merged" "$REMOTE" "$LOCAL"
        (( ++summary_merged_count ))
        return "$success"
    }
}

#---------------------------------------------------------------------------------------------
# @description Copies the source file over the destination file, creating the destination directory first if it does
# not already exist. Both the directory creation and the copy go through 'execute', so they are skipped (and only
# printed) in dry-run mode.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string source file path to copy from
# @arg $2 string destination file path to copy to
#
# @exitcode success/positive=0: the copy (or dry-run print) succeeded
#
# @example
#   copy_file "$source_file" "$target_file"
#---------------------------------------------------------------------------------------------
function copy_file()
{
    (( $# == 2 ))       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                            "  - the source file path" \
                                                            "  - destination file path."
    [[ -v 1 && -f $1 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the source file, to be an existing file (provided '${1:-<none>}')."
    [[ -v 2 && -n $2 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the destination file path, to be non-empty (provided '${2:-<none>}')."

    exit_if_has_bugs

    local _src_file="$1"
    local _dest_file="$2"
    local _dest_dir

    _dest_dir=$(dirname "$_dest_file")

    if [[ ! -d "$_dest_dir" ]]; then
        execute mkdir -p "$_dest_dir"
    fi
    execute cp "$_src_file" "$_dest_file"
    trace_files "copied" "$_src_file" "$_dest_file"
    (( ++summary_copied_count ))
}

#---------------------------------------------------------------------------------------------
# @description Splices the SoT file's shared block (the content between '$shared_begin_marker' and
# '$shared_end_marker') into the target file, replacing the target's own shared block in place while leaving
# everything before and after it untouched. Goes through 'execute', so it is skipped (and only printed) in
# dry-run mode.
#
# Notes:
#   - Callers MUST have already confirmed (e.g. via 'are_different()' returning '$shared_not_equal') that both
#     files have exactly one well-formed marker pair; at that point a missing/malformed marker is a caller
#     contract violation, not an expected runtime outcome, so this function bug-exits instead of degrading.
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string SoT (source of truth) file path to copy the shared block from
# @arg $2 string target file path to splice the shared block into, in place
#
# @exitcode success/positive=0: the splice (or dry-run print) succeeded
#
# @example
#   copy_shared_block "$source_file" "$target_file"
#---------------------------------------------------------------------------------------------
function copy_shared_block()
{
    (( $# == 2 ))       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                            "  - the SoT file to copy the shared block from" \
                                                            "  - the target file to splice the shared block into"
    [[ -v 1 && -f $1 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 1, the SoT file, to be an existing file (provided '${1:-<none>}')."
    [[ -v 2 && -f $2 ]] || bug -ec "$err_not_file" "${FUNCNAME[0]}() requires argument 2, the target file, to be an existing file (provided '${2:-<none>}')."

    exit_if_has_bugs

    local _src_file="$1"
    local _dest_file="$2"
    local _shared_content
    local -i _dest_begin_line _dest_end_line

    get_shared_block "$_src_file" _shared_content ||
        bug -ec "$err_logic_error" "${FUNCNAME[0]}() requires the SoT file '$_src_file' to already have a single, well-formed shared-content marker pair (the caller is expected to have checked this via are_different())."
    __find_shared_markers "$_dest_file" _dest_begin_line _dest_end_line ||
        bug -ec "$err_logic_error" "${FUNCNAME[0]}() requires the target file '$_dest_file' to already have a single, well-formed shared-content marker pair (the caller is expected to have checked this via are_different())."

    exit_if_has_bugs

    local _tmp_file
    _tmp_file=$(mktemp)

    {
        sed -n "1,${_dest_begin_line}p" "$_dest_file"
        printf '%s\n' "$_shared_content"
        sed -n "${_dest_end_line},\$p" "$_dest_file"
    } > "$_tmp_file"

    execute cp "$_tmp_file" "$_dest_file"
    rm -f "$_tmp_file"

    trace_files "copied" "$_src_file" "$_dest_file"
    (( ++summary_copied_count ))
}

#===============================
# Summary variables:
#===============================
declare -x summary_file

declare -xi summary_diff_count
declare -xi summary_identical_count
declare -xi summary_skipped_count
declare -xi summary_ignore_count
declare -xi summary_not_merged_count
declare -xi summary_merged_count
declare -xi summary_copied_count
declare -xi summary_shared_in_sync_count

function add_summary_header()
{
    local target_path="$1"
    local target=${target_path#"$vm2_repos/"}
    local target=${target_path%%/*}

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    $diff_only && {
        echo -e "### Target Repository: $target ($target_path)\n"
        echo -e "| Source Path | Target Path | Filename | Default: | Difference | To do: |"
        echo -e "|:------------|:------------|:---------|:---------|:-----------|:-------|"
    } >> "$summary_file" || {
        echo -e "### Target Repository: $target ($target_path)\n"
        echo -e "| Source Path | Target Path | Filename | Default: | Difference | Done:  |"
        echo -e "|:------------|:------------|:---------|:---------|:-----------|:-------|"
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
}

function add_summary_line()
{
    local source_file="$1"
    local target_file="$2"
    local actions="$3"
    local difference="$4"
    local action="$5"

    filename="$(basename "$source_file")"

    rel_source_path="$(dirname "$source_file")"
    rel_source_file="${rel_source_path#"$vm2_repos/"}"

    rel_target_path="$(dirname "$target_file")"
    rel_target_file="${rel_target_path#"$vm2_repos/"}"

    echo "| $rel_source_file | $rel_target_file | $filename | $actions | $difference | $action |" >> "$summary_file"
}
