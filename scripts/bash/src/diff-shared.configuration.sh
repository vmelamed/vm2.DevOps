# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# length-review: keep together -- Well-focused on configuration variables, constants, tools, and functions.

#=============================================================================================
# Configuration, customization and parametrization of the script environment, including:
# variables, constants, tools, and functions for the VM2 DevOps diff and merge scripts.
#=============================================================================================

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_not_directory
declare -xri err_invalid_arguments
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

declare -x _ignore

declare -xr vm2_sot_repo_name
declare -x sot
declare -xa valid_actions
declare -x all_actions_str
declare -x diff_only

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
# @arg $1 string _file - the configuration or customization file containing the diff and merge
#   tool settings (must exist and be non-empty).
# @arg $2 bool _use_defaults - if the file does not provide any of the diff or the merge tools -
#   use the defaults: either from the Git configuration or from the script defaults.
#
# @exitcode success=0: The diff and merge tool commands were retrieved successfully (this
#   function does not itself fail at runtime; 'bug' aborts the process on a caller-contract
#   violation before this point is reached).
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
# @exitcode success=0: configuration loaded and validated successfully
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
# @exitcode success=0: customization applied successfully, or no custom configuration file was found
#
# Note: an invalid customization JSON schema is reported via 'error' and exits the entire process via
#   'exit_if_has_errors' -- it is not returned as a non-zero code to this function's caller.
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
# @description Overrides the per-file actions in the global 'file_actions' array based on the '--file*' selectors
#   collected on the command line (the global associative array 'selectors_actions'). For each configured source
#   file, matches it against every selector pattern (a trailing-path glob, e.g. '*/<selector>'); if exactly one
#   distinct action results from the matching selectors, applies it. If multiple selectors matched the same file
#   with different actions, the file's action is cleared (set to empty) and a warning is issued, since it is
#   ambiguous which action should apply. If no selector matched a file, its action is also cleared, so only
#   explicitly selected files are processed afterwards. A no-op (returns immediately) when 'selectors_actions' is
#   empty, i.e. no '--file*' options were given on the command line.
#
# @exitcode success=0: Always (even when no files matched any selector -- that case is reported via 'warning', not
#   a non-zero return).
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
