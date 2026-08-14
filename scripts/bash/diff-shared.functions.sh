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

#-------------------------------------------------------------------------------
# @description Loads the diff/merge tool configuration and the list of source/target/action file entries from the SoT
# directory's 'diff-shared.config.json', populating the global model arrays 'source_files', 'target_files', and
# 'file_actions'. This is a top-level CLI configuration step: on any validation or configuration failure it reports the
# error(s) via 'error' and exits the process via 'exit_if_has_errors' rather than returning an error code.
#
# @arg $1 string the SoT directory path (must exist and be a directory; the configuration file '$1/diff-shared.config.json' MUST
#   exist, be non-empty, and contain valid JSON)
# @arg $2 string the target repository directory path (must exist and be a directory)
#
# @exitcode 0 configuration loaded and validated successfully
#
# @example
#   configure "$sot_path" "$target_path"
#-------------------------------------------------------------------------------
function configure()
{
    (( $# == 2 ))                        || error -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#): the SoT directory and the target directory."
    [[ -v 1 && -d $1 ]]                  || error -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the SoT directory, to be an existing directory (provided '${1-<missing>}')."
    [[ -v 2 && -d $2 ]]                  || error -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the target directory, to be an existing directory (provided '${2-<missing>}')."

    exit_if_has_errors

    local _config_file="$1/diff-shared.config.json"
    # shellcheck disable=SC2034 # target_file_path appears unused. Verify use (or export if used externally): used as a macro variable in the config files and evaluated with 'eval' below
    local target_file_path="$2"

    # validate the config file and load the diff and merge tools from it:
    [[ -s "$_config_file" ]]              || error -ec "$err_argument_value" "The configuration file '$_config_file' was not found or is empty."
    jq empty "$_config_file" 2>"$_ignore" || error -ec "$err_argument_value" "The configuration file '$_config_file' contains invalid JSON."

    exit_if_has_errors

    # get the configured tools
    { read -r diff_tool; read -r diff_command; read -r merge_tool; read -r merge_command; } < <(get_tools "$_config_file")

    # Populate the arrays
    local -i _index=0
    # shellcheck disable=SC2034
    local vm2_sot_shared="$vm2_sot_repo_name/templates/$sot/content"
    local _source_file _target_file _file_action

    while IFS='=' read -r _source_file _target_file _file_action; do
        [[ -n "$_source_file" ]]                    || error -ec "$err_argument_value" "Empty source file path found in '$_config_file'."
        [[ -n "$_target_file" ]]                    || error -ec "$err_argument_value" "Empty target file path found in '$_config_file'."
        [[ -n "$_file_action" ]]                    || error -ec "$err_argument_value" "Empty action found in '$_config_file'."
        is_in "$_file_action" "${valid_actions[@]}" || error -ec "$err_argument_value" "'$_file_action' is not a valid action. Must be one of: $all_actions_str."

        # Expand variables in paths
        eval "_source_file=\"$_source_file\""       # uses $vm2_repos and $vm2_sot_shared as a macro variables
        [[ -s "$_source_file" ]]                    || error -ec "$err_argument_value" "Source file '$_source_file' does not exist or is empty."
        eval "_target_file=\"$_target_file\""       # uses $target_file_path as a macro variable
        eval "_file_action=\"$_file_action\""

        # and assign into the model arrays by index:
        source_files[_index]="$_source_file"
        target_files[_index]="$_target_file"
        file_actions[_index]="$_file_action"

        ((++_index)) || true
    done < <(jq -r '.files[] | .sourceFile + "=" + .targetFile + "=" + .action' "$_config_file")

    trace "Loaded ${#source_files[@]} source files"
    trace "Loaded ${#target_files[@]} target files"
    trace "Loaded ${#file_actions[@]} pre-configured actions."

    # validate the configuration
    (( ${#source_files[@]} == ${#target_files[@]} && ${#source_files[@]} == ${#file_actions[@]} )) ||
        error -ec "$err_logic_error" "The data in the config tables does not match."

    exit_if_has_errors

    trace "$script_name was configured successfully with ${#source_files[@]} files and actions."
}

#-------------------------------------------------------------------------------
# @description: Changes the file actions from the config file(s) based on the provided command line arguments.
function parameterize()
{
    local -i _rc=$success

    (( ${#selectors_actions[@]} > 0 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "No command line arguments were provided to parameterize the file actions. Please provide at least one --file* argument to specify which files to compare and how."
    }

    (( _rc == success )) || return "$_rc"

    local _selector _action
    local -a _matching_actions
    local -i _index
    local -i _cnt
    local -i _count=0

    # for each source file
    for (( _index=0; _index<${#source_files[@]}; _index++ )); do
        _matching_actions=()
        # check if it matches any of the provided patterns in the command line arguments
        for _selector in "${!selectors_actions[@]}"; do
            if [[ "${source_files[_index]}" == */$_selector ]]; then
                # matches - override or keep the action for that file
                [[ -n ${selectors_actions[$_selector]} ]] &&
                    # get the action from the command line arguments if provided, otherwise use the pre-configured action
                    _action="${selectors_actions[$_selector]}" || _action="${file_actions[_index]}"
                # add the action to the list of matching actions if it is not already present
                ! is_in "$_action" "${_matching_actions[@]}" && {
                    _matching_actions+=("$_action")
                    trace "File '${source_files[_index]#"$vm2_repos/"}' matches selector '$_selector' with action '$_action'."
                }
            fi
        done

        _cnt=${#_matching_actions[@]}

        if (( _cnt == 1 )); then
            # exactly one action - use it
            file_actions[_index]="${_matching_actions[0]}"
            (( ++_count )) || true
        elif (( _cnt > 1 )); then
            # multiple different actions matched - this is a CLI error, report it and skip the file (clear the action, as we are not certain what to do) and report as a warning
            file_actions[_index]=""
            warning "Multiple patterns matched for '${source_files[_index]#"$vm2_repos/"}' resulting in different actions: ${_matching_actions[*]}. Please refine your file selectors so that each matches at most one file. The file will be skipped."
        else
            # no patterns matched - clear the action for that file (clear the action, as we are not certain what to do) and report as a warning
            file_actions[_index]=""
            trace "File '${source_files[_index]#"$vm2_repos/"}' does not match any of the provided patterns: ${!selectors_actions[*]}. It will not be processed."
        fi
    done

    if (( _count > 0 )); then
        trace "Parameterized actions for $_count files based on the provided command line arguments."
    else
        warning -sd 3 -ec "$err_argument_value" "No files were matched by the provided command line arguments."
    fi
    return "$_rc"
}

function resolve_target()
{
    local -i _rc="$success"

    (( $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]} expects two arguments (provided $#):" \
                              "  1) the directory of the repositories" \
                              "  2) the directory name of the target repository."
    }

    (( _rc == success )) || return "$_rc"

    local _repos="$1"
    local _r="$2"
    local _output _target_root _target_path

    _output=$(resolve_repo_root "$_repos" "$_r") || _rc=$?
    # We can only work with git repos or directories that have CI configured:
    (( _rc == success || _rc == err_dir_with_ci )) || {
        error -sd 3 -ec "$_rc" "The specified target directory '${_repos%/}/${_r#/}' is invalid." \
                              "It should have CI configured in '.github/workflows'."
        return "$_rc"
    }
    {
        read -r _target_root;
        read -r _target_path;
    } <<< "$_output"

    # if it is a git repo then make sure it is in a clean state:
    if (( _rc == success )); then
        branch="$(git -C "$_target_root" branch --show-current 2>"$_ignore")" || {
            _rc=$?
            error -sd 3 -ec "$err_tool_error" "The repository in the specified target directory '$1' appears corrupted."
        }
        (( _rc == success )) && {
            ensure_fresh_git_state "$_target_root" "$branch" ||
                error -sd 3 -ec "$err_logic_error" "The specified target repository at '$_target_root' on branch '$branch' is not in a clean state." \
                                                   "Commit or stash your changes."
        }
    else
        branch="<not a git repository>"
    fi

    exit_if_has_errors

    trace "The target project's working tree root directory is '$_target_root', on a branch '$branch'."
    echo "$_target_root"
    echo "$_target_path"
}

#-------------------------------------------------------------------------------
# @description Loads per-repository customizations from '<target_path>/diff-shared.custom.json', if present, overriding
# the configured diff/merge tools and (unless 'only_tools' is set) the per-file actions in the global 'file_actions'
# array. If the custom configuration file does not exist or is empty, the function leaves the configured tools and
# actions untouched and returns successfully.
#
# @arg $1 string target repository root directory path (must be an existing directory)
# @arg $2 bool whether to customize the diff/merge tools only, skipping the per-file action overrides (optional,
#   default: false)
#
# @exitcode 0 ($success) customization applied successfully, or no custom configuration file was found
# @exitcode 1 ($failure) the custom configuration file contains invalid JSON
#
# @example
#   customize "$target_root" true
#   customize "$target_root" false
#-------------------------------------------------------------------------------
function customize()
{
    (( $# == 1 || $# == 2 ))            || error -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one or two arguments (provided $#): the target repository directory and an optional tools-only flag."
    [[ -v 1 && -d $1 ]]                 || error -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the target repository path, to be an existing directory (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || is_boolean "$2"     || error -ec "$err_argument_type" "${FUNCNAME[0]}() requires optional argument 2, the tools-only flag, to be 'true' or 'false' (provided '${2-<missing>}')."

    exit_if_has_errors

    local _target_path=$1
    local _only_tools=${2:-false}
    local _custom_config="$_target_path/diff-shared.custom.json"

    [[ -s "$_custom_config" ]] || {
         trace "The customization file '$_custom_config' does not exist or is empty. Continuing with the default configuration."
         return "$success"
    }

    trace "Validate the custom configuration file $_custom_config."
    jq empty "$_custom_config" 2>"$_ignore" || {
        error -ec "$err_argument_value" "The custom configuration file $_custom_config contains invalid JSON."
        return "$failure"
    }

    { read -r custom_diff_tool; read -r custom_diff_command; read -r custom_merge_tool; read -r custom_merge_command; } < <(get_tools "$_custom_config")

    [[ -n $custom_diff_tool ]]     && diff_tool="$custom_diff_tool"         || diff_tool="$config_diff_tool"
    [[ -n $custom_diff_command ]]  && diff_command="$custom_diff_command"   || diff_command="$config_diff_command"
    [[ -n $custom_merge_tool ]]    && merge_tool="$custom_merge_tool"       || merge_tool="$config_merge_tool"
    [[ -n $custom_merge_command ]] && merge_command="$custom_merge_command" || merge_command="$config_merge_command"

    # make sure the tools and commands are valid if they were customized:
    [[ -n $diff_tool    &&
       -n $diff_command &&
       -n $merge_tool   &&
       -n $merge_command ]] ||
        error -ec "$err_argument_value" "The configuration and/or customization files and the defaults must determine the names of the diff and merge tools" \
              "and the corresponding commands: " \
              "  diff tool:    '$diff_tool'" \
              "  diff command: '$diff_command'" \
              "  merge tool:   '$merge_tool'" \
              "  merge command: '$merge_command'"

    if [[ "$_only_tools" == true ]]; then
        return "$success"
    fi

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
                if [[ "${target_files[_index]}" == $_target_path/$_file_name ||
                      "${target_files[_index]}" == $_target_path/*/$_file_name ]]; then
                    # Override the action:
                    file_actions[_index]="$_action"
                    (( ++_changed_actions )) || true
                    _found=true
                    break
                fi
            done

            [[ "$_found" == true ]] || {
                 [[ $_action != "ignore" ]] && warning "Path '$_file_name' from $_custom_config does not match any known target relative path."
                continue
            }
        done < <(jq -r '.action_overrides | to_entries | .[] | .key+"="+.value' "$_custom_config" 2>"$_ignore") # convert JSON object to key=value pairs

        $diff_only || info "$script_name was customized successfully with $_changed_actions modified actions."
    fi
}

function get_tools()
{
    (( $# == 1 ))            || error -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the configuration or customization file."
    [[ -v 1 && -s $1 ]]      || error -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be an existing, non-empty configuration or customization file (provided '${1-<missing>}')."

    exit_if_has_errors

    local _file="$1"
    local _dt _dc _mt _mc

    # get the diff and merge tool commands from the main config file
    { read -r _dt; read -r _dc; read -r _mt; read -r _mc; } < <(jq -r '.diff.tool, .diff.command, .merge.tool, .merge.command' "$_file" 2>"$_ignore")

    if [[ -n $_dt && -n $_dc ]] &&
       (command -p -v "$_dt" &>"$_ignore" || which "$_dt" &>"$_ignore"); then
        # the configured diff tool/command is good, use it
        trace "Diff tool configured in $_file: '$_dt': $_dc"
    else
        # get it from Git
        _dt=$(git config --global --get "diff.tool" 2>"$_ignore" || true) &&
        _dc=$(git config --global --get "diff.$_dt.cmd" 2>"$_ignore" || true)

        if [[ -n "$_dt" ]] && (command -v -p "$_dt" > "$_ignore" || which "$_dt" &>"$_ignore") &&
           ([[ -n "$_dc" ]] || is_in "$_dt" "${!diff_commands[@]}"); then
            # OK the git configured diff tool is available, if a command is not configured, get ours
            _dc=${_dc:-${diff_commands[$_dt]}}
            trace "Diff tool configured in Git: '$_dt': $_dc"
        else
            # use the hardcoded defaults from this script
            _dt="$default_diff_tool"
            _dc=${diff_commands[$_dt]}

            if [[ -n "$_dt" && -n "$_dc" ]] &&
               (command -v -p "$_dt" > "$_ignore" || which "$_dt" &>"$_ignore"); then
                trace "Diff tool configured by default: '$_dt': $_dc"
            else
                # fall-back to good ole 'diff' - it is not as good, but it will do the job and return good exit codes
                _dt="diff"
                _dc=${diff_commands[$_dt]}
                trace "Diff tool fall-back to classic diff: '$_dt': $_dc"
            fi
        fi
    fi

    # similar logic for the merge tool, but we prefer our default merge commands over the git configured ones
    if [[ -n $_mt && -n $_mc ]] &&
       (command -p -v "$_mt" &>"$_ignore" || which "$_mt" &>"$_ignore"); then
        # the configured merge tool/command is good, use it
        trace "Merge tool configured in $_file: '$_mt': $_mc"
    else
        # get it from Git
        _mt=$(git config --global --get "merge.tool" 2>"$_ignore" || true)
        _mc=$(git config --global --get "mergetool.$_mt.cmd" 2>"$_ignore" || true)
        local _mt_is_in_merge_commands="false"
        is_in "$_mt" "${!merge_commands[@]}" && _mt_is_in_merge_commands="true"

        if [[ -n $_mt ]] && (command -v -p "$_mt" > "$_ignore" || which "$_mt" &>"$_ignore") &&
           ([[ -n $_mc ]] || $_mt_is_in_merge_commands); then
            # for the purposes of this script, our merge commands work better than the ones configured in git,
            # so we ignore the git config here if we can
            $_mt_is_in_merge_commands && _mc=${merge_commands[$_mt]}
            trace "Merge tool from Git config with '$_mt': $_mc"
        else
            # use the hardcoded defaults from this script
            _mt="$default_merge_tool"
            _mc=${merge_commands[$_mt]}

            if [[ -n $_mt && -n $_mc ]] &&
               (command -v -p "$_mt" > "$_ignore" || which "$_mt" &>"$_ignore"); then
                trace "Merge tool configured by default: '$_mt': $_mc"
            else
                # fall-back to good ole 'code' if available
                _mt="code"
                if [[ -n $_mt && -n $_mc ]] &&
                   (command -v -p "$_mt" > "$_ignore" || which "$_mt" &>"$_ignore"); then
                    _mc=${merge_commands[$_mt]}
                    trace "Choosing Visual Studio Code as a merge tool '$_mt': $_mc"
                else
                    warning "No merge tool was configured or none is available. Merge operations will not be possible."
                    _mt=""
                    _mc=""
                fi
            fi
        fi
    fi

    echo "$_dt"
    echo "$_dc"
    echo "$_mt"
    echo "$_mc"
}

# shellcheck disable=SC2059
function trace_files()
{
    local _format
    case "${1,,}" in
        identical )
            _format="%-84s ==== Identical ==== %-s\n"
            ;;
        different )
            _format="%-84s ≠≠≠≠ Different ≠≠≠≠ %-s\n"
            ;;
        not_changed )
            _format="%-84s →←→← No change →←→← %-s\n"
            ;;
        merged )
            _format="%-84s →←→← Merged    →←→← %-s\n"
            ;;
        copied )
            _format="%-84s →→→→ Copied    →→→→ %-s\n"
            ;;
        skipped )
            _format="%-84s ---- Skipping  ---- %-s\n"
            ;;
        * )
            _format="%-84s ??????????????????? %-s\n"
    esac
    trace "$(printf "$_format" "${2#"$vm2_repos/$vm2_sot_repo_name/templates/"}" "${3#"$vm2_repos/"}")"
}

#-------------------------------------------------------------------------------
# @description Compares two files with a fast whitespace/blank-line-insensitive 'diff -q -w -B'. If they are identical,
# returns immediately. If they differ and 'show_diff' is true, also launches the configured (or default) visual diff
# tool via '$diff_command' against the global 'LOCAL'/'REMOTE' variables, which this function sets before evaluating it.
#
# @arg $1 string SoT (source of truth) file path; assigned to the global 'LOCAL' for '$diff_command' to use
# @arg $2 string target file path; assigned to the global 'REMOTE' for '$diff_command' to use
# @arg $3 bool whether to also display the visual diff when the files differ (optional, default: true)
#
# @exitcode 0 the files differ
# @exitcode 1 the files are identical
#
# @example
#   are_different "$source_file" "$target_file" false
#-------------------------------------------------------------------------------
function are_different()
{
    local -i _rc="$success"

    (( $# == 2 || $# == 3 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires two or three arguments (provided $#): the SoT file, target file, and optional display-diff flag."
    }
    [[ -v 1 && -f $1 ]] || {
        _rc="$err_not_file"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the SoT file, to be an existing file (provided '${1-<missing>}')."
    }
    [[ -v 2 && -f $2 ]] || {
        _rc="$err_not_file"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the target file, to be an existing file (provided '${2-<missing>}')."
    }
    [[ ! -v 3 ]] || is_boolean "$3" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 3, the display-diff flag, to be 'true' or 'false' (provided '${3-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _display_diff=${3:-true}

    # follow the git diff command parameters naming convention, so the eval command can use them correctly
    LOCAL=$1
    REMOTE=$2

    # compare fast, return fast, if no significant diffs; otherwise continue with the fancy diff tool of choice
    if diff -q -w -B "$LOCAL" "$REMOTE" > "$_ignore"; then
        trace_files "identical" "$LOCAL" "$REMOTE"
        return 1
    else
        trace_files "different" "$LOCAL" "$REMOTE"
        $_display_diff && eval "$diff_command"
        return 0
    fi
}

#-------------------------------------------------------------------------------
# @description Runs the configured (or default) merge tool via '$merge_command' to merge the SoT file into the target
# file in place. Follows the Git merge parameter naming convention ('LOCAL', 'REMOTE', 'MERGED', 'BASE') so that
# '$merge_command' can reference these globals. Detects whether the merge actually changed the target file by comparing
# a SHA-256 hash of the target file before and after running the tool.
#
# @arg $1 string target file path; assigned to the globals 'LOCAL' and 'MERGED' (the file the merge tool is expected to
#   modify in place)
# @arg $2 string SoT (source of truth) file path; assigned to the globals 'REMOTE' and 'BASE'
#
# @exitcode 0 the target file's content changed as a result of the merge
# @exitcode 1 the target file's content is unchanged after the merge tool ran
#
# @example
#   merge "$target_file" "$source_file"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2034 # BASE appears unused. Verify use (or export if used externally).
function merge()
{
    local -i _rc="$success"

    (( $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly two arguments (provided $#): the target file and SoT file."
    }
    [[ -v 1 && -f $1 ]] || {
        _rc="$err_not_file"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the target file, to be an existing file (provided '${1-<missing>}')."
    }
    [[ -v 2 && -f $2 ]] || {
        _rc="$err_not_file"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the SoT file, to be an existing file (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

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

#-------------------------------------------------------------------------------
# @description Copies the source file over the destination file, creating the destination directory first if it does
# not already exist. Both the directory creation and the copy go through 'execute', so they are skipped (and only
# printed) in dry-run mode.
#
# @arg $1 string source file path to copy from
# @arg $2 string destination file path to copy to
#
# @exitcode 0 the copy (or dry-run print) succeeded
#
# @example
#   copy_file "$source_file" "$target_file"
#-------------------------------------------------------------------------------
function copy_file()
{
    local -i _rc="$success"

    (( $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly two arguments (provided $#): the source and destination file paths."
    }
    [[ -v 1 && -f $1 ]] || {
        _rc="$err_not_file"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the source file, to be an existing file (provided '${1-<missing>}')."
    }
    [[ -n $2 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the destination file path, to be non-empty (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _src_file="$1"
    local _dest_file="$2"
    local _dest_dir

    _dest_dir=$(dirname "$_dest_file")

    if [[ ! -d "$_dest_dir" ]]; then
        execute mkdir -p "$_dest_dir"
    fi
    execute cp "$_src_file" "$_dest_file"
    trace_files "copied" "$_src_file" "$_dest_file"
}
