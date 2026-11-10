#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

source "$lib_dir/core.sh"

# vm2 core error codes
declare -xri success
declare -xri positive
declare -xri negative
declare -xri err_logic_error
declare -xri err_unexpected_error

# vm2 core constants
declare -xr cross_ch
declare -xr check_ch
declare -xr equals_ch
declare -xr not_eq_ch

declare -xr vm2_sot_repo_name
declare -xra vm2_repositories

# vm2 core variables
declare -x _ignore

# this script's components
source "$script_dir/diff-shared.configuration.sh"
source "$script_dir/diff-shared.functions.sh"
source "$script_dir/diff-shared.args.sh"
source "$script_dir/diff-shared.usage.sh"
source "$script_dir/diff-shared.summary.sh"

# this script arguments:
get_arguments "$@"
declare -xr vm2_repos
declare -xr sot
declare -xra target_repos
declare -xrA selectors_actions
declare -xr diff_only
declare -xr summary_file
declare -xr sot_path

# this script variables
declare -xr action_ignore
declare -xr action_merge_or_copy
declare -xr action_ask_to_merge
declare -xr action_ask_to_copy
declare -xr action_merge action_copy
declare -xr action_copy_shared
declare -xr action_ask_to_copy_shared

declare -xri shared_equal
declare -xri shared_not_equal
declare -xa arguments

# Summary variables:
declare -xi summary_ignore_count
declare -xi summary_shared_ignore_count
declare -xi summary_skipped_count
declare -xi summary_shared_skipped_count

declare -xra target_roots
declare -xra target_paths

# this is the data model of the script. Bash does not have complex data structures, so we use parallel arrays to store the
# source files, target files and actions. The index of the arrays corresponds to the same file pair and action. For example,
# source_files[0], target_files[0] and file_actions[0] correspond to the same file pair and action:
declare -xa source_files=()     # array of the paths of the SoT files
declare -xa target_files=()     # array of target paths corresponding to the SoT files by index
declare -xa file_actions=()     # array of default action strings corresponding to the SoT files by index

info "The Source of Truth '$sot' folder is in '$sot_path'"

{
    echo -e "# Summary\n"
    echo -e "## Source of truth: **$sot** (\`$sot_path\`)\n"
} >> "$summary_file"

configure "$sot_path" "$target_path"                                            || exit_with_error "Failed to load configuration from the SoT directory '$sot_path'." -ec "$err_logic_error"
trace "Configured from SoT '$sot_path' for '$target_path'."

declare -x config_diff_tool
declare -x config_diff_command
declare -x config_merge_tool
declare -x config_merge_command

declare -xa config_source_files    # array of the paths of the SoT files
declare -xa config_file_actions    # array of default action strings corresponding to the SoT files by index

declare -x diff_tool
declare -x diff_command
declare -x merge_tool
declare -x merge_command

declare source_file
declare target_file
declare default_actions
declare actions
declare -i difference
declare file_difference_txt todo_or_done_txt

declare -A repo_state=()
declare -xr key_name
declare repo_name

declare -i targets_index
declare -i files_index
declare target_root target_path

# iterate through the target repositories
for (( targets_index=0; targets_index < ${#target_roots[@]}; targets_index++ )); do
    target_root="${target_roots[targets_index]}"
    target_path="${target_paths[targets_index]}"

    # Re/load tools and model from the global configuration
    diff_tool=$config_diff_tool
    diff_command=$config_diff_command
    merge_tool=$config_merge_tool
    merge_command=$config_merge_command

    configure_target_files "$target_root" target_files
    source_files=("${config_source_files[@]}")
    file_actions=("${config_file_actions[@]}")

    customize "$sot_path" "$target_root"

    if ! is_empty_array selectors_actions; then
        parameterize "$diff_only"
        trace "Parameterized for ${#source_files[@]} files with ${#selectors_actions[@]} actions."
    fi
    exit_if_has_errors

    add_summary_header "$target_path"

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    for (( files_index=0; files_index < ${#source_files[@]}; files_index++ )); do
        # iterate through the source files for the current target repository
        source_file="${source_files[files_index]}"
        target_file="${target_files[files_index]}"
        default_actions="${file_actions[files_index]}"

        $diff_only && actions=$action_ignore || actions=$default_actions

        if [[ -z $actions ]]; then
            #  this file was excluded by the parameterize function
            trace "$(printf "%-84s ---- Skipping  ---- %-s\n" "${source_file#"$vm2_repos/$vm2_sot_repo_name/templates/"}" "${target_file#"$vm2_repos/"}")"
            continue
        fi

        trace "SoT File: '${source_file#"$vm2_repos/$vm2_sot_repo_name/templates/"}' vs Target File: '${target_file#"$vm2_repos/"}' with actions '$actions'..."

        file_difference_txt=''
        todo_or_done_txt=''

        if [[ ! -s "$target_file" ]]; then
            # if the target file does not exist - copy it or ask the user and if they say yes, then copy it
            # do not show visual diff for the actions that are not asking the user anything
            trace "$(printf "%-s does not exist\n" "${target_file#"$vm2_repos"/}")"

            file_difference_txt=" ✗ missing"

            if $diff_only; then
                # no action taken => "to do": $actions
                todo_or_done_txt=$actions
            else
                # action taken => "done": ...
                case $actions in
                    "$action_ignore" )
                        (( ++summary_ignore_count ))
                        todo_or_done_txt="ignored"
                        ;;

                    "$action_merge_or_copy" | "$action_ask_to_merge" | "$action_ask_to_copy" | "$action_ask_to_copy_shared")
                        confirm "Target file '$target_file' does not exist. Do you want to copy it from '$source_file'?" "y" && {
                            copy_file "$source_file" "$target_file" && todo_or_done_txt="copied" || todo_or_done_txt="copy failed"
                        } || {
                            (( ++summary_skipped_count ))
                            todo_or_done_txt="skipped"
                        }
                        ;;

                    "$action_merge" | "$action_copy" | "$action_copy_shared" )
                        # a missing target has no shared-block markers of its own to preserve -- bootstrap it
                        # with the whole SoT file, same as 'merge'/'copy' already do
                        copy_file "$source_file" "$target_file" && todo_or_done_txt="copied" || todo_or_done_txt="copy failed"
                        ;;

                    * ) error "Unknown action '$actions' for files '$source_file' and '$target_file'." -ec "$err_logic_error"
                        todo_or_done_txt="error"
                        press_any_key
                        ;;
                esac
            fi

            add_summary_line "$source_file" "$target_file" "$default_actions" "$file_difference_txt" "$todo_or_done_txt"
            continue
        fi

        declare show_in_diff_tool=false warn_no_markers=false

        case $actions in
            "$action_ignore"             ) ;;
            "$action_merge_or_copy"      ) show_in_diff_tool=true  ;;
            "$action_ask_to_merge"       ) show_in_diff_tool=true  ;;
            "$action_merge"              ) ;;
            "$action_ask_to_copy"        ) show_in_diff_tool=true  ;;
            "$action_copy"               ) ;;
            "$action_copy_shared"        ) warn_no_markers=true ;;
            "$action_ask_to_copy_shared" ) show_in_diff_tool=true
                                           warn_no_markers=true ;;
            * ) error "Unknown action '$actions' for files '$source_file' and '$target_file'."  -ec "$err_logic_error" ;;
        esac

        # calculate the difference and if required: warn about missing markers and/or show the files in the diff tool
        difference=$positive
        are_different "$source_file" "$target_file" "$show_in_diff_tool" "$warn_no_markers" || difference=$?

        # are_different() reports four outcomes now: identical, plain different (no usable shared-block
        # markers), or -- when both files have well-formed markers -- shared_equal/shared_not_equal for
        # just the marked-off portion. Every non-identical outcome is still "different" for the purposes of
        # every OTHER action below; only 'copy shared'/'ask to copy shared' branch on the finer-grained code.

        (( difference == negative )) && different=false || different=true

        case $difference in
            "$positive" )
                file_difference_txt=" $not_eq_ch different"
                ;;
            "$negative" )
                file_difference_txt=" $equals_ch identical"
                ;;
            "$shared_equal" )
                file_difference_txt=" $check_ch shared identical"
                ;;
            "$shared_not_equal" )
                file_difference_txt=" $cross_ch shared different"
                ;;
            * ) error "Unexpected return code: $difference" -ec "$err_unexpected_error"
                ;;
        esac

        if ! $different || $diff_only; then
            $diff_only && todo_or_done_txt="$actions"       # todo - actions MUST still to be done
            $different || todo_or_done_txt="$action_ignore" # if not different, correct the todo - ignore
        else
            case $actions in
                "$action_ignore" )
                    (( ++summary_ignore_count ))
                    todo_or_done_txt="ignored"
                    ;;

                "$action_merge_or_copy" )
                    declare choice
                    choose "What do you want to do?" \
                        choice \
                            "Do nothing - continue" \
                            "Merge the files" \
                            "Copy '$source_file' file to '$target_file'"
                    case $choice in
                        2 ) merge "$source_file" "$target_file"     &&          todo_or_done_txt="merged" || todo_or_done_txt="not merged" ;;
                        3 ) copy_file "$source_file" "$target_file" &&          todo_or_done_txt="copied" || todo_or_done_txt="failed to copy" ;;
                        * ) (( ++summary_skipped_count )) &&                    todo_or_done_txt="skipped" ;;
                    esac
                    ;;

                "$action_ask_to_merge" )
                    confirm "Do you want to merge '$source_file' to file '$target_file'?" "n" && {
                        merge "$source_file" "$target_file" &&                  todo_or_done_txt="merged" || todo_or_done_txt="not merged"
                    } || {
                        (( ++summary_skipped_count )) &&                        todo_or_done_txt="skipped"
                    }
                    ;;

                "$action_merge" )
                    merge "$source_file" "$target_file" &&                      todo_or_done_txt="merged" || todo_or_done_txt="not merged" ;;

                "$action_ask_to_copy" )
                    confirm "Do you want to copy '$source_file' to file '$target_file'?" "n" && {
                        copy_file "$source_file" "$target_file" &&              todo_or_done_txt="copied"
                    } || {
                        (( ++summary_skipped_count )) &&                        todo_or_done_txt="skipped"
                    }
                    ;;

                "$action_copy" )
                    copy_file "$source_file" "$target_file" &&                  todo_or_done_txt="copied" || todo_or_done_txt="failed to copy" ;;

                "$action_copy_shared" )
                    case $difference in
                        "$shared_equal" )
                            (( ++summary_shared_ignore_count )) &&              todo_or_done_txt="ignored shared" ;;

                        "$shared_not_equal" )
                            copy_shared_block "$source_file" "$target_file" &&  todo_or_done_txt="copied shared" || todo_or_done_txt="failed to copy shared" ;;

                        * ) # shared-block markers missing/malformed in one of the files -- are_different()
                            # already warned; fall back to merge rather than risk clobbering private content
                            # with a full-file copy
                            merge "$source_file" "$target_file" &&              todo_or_done_txt="merged" || todo_or_done_txt="not merged" ;;
                    esac
                    ;;

                "$action_ask_to_copy_shared" )
                    case $difference in
                        "$shared_equal" )
                            (( ++summary_shared_ignore_count )) &&              todo_or_done_txt="ignored shared" ;;

                        "$shared_not_equal" )
                            # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                            confirm "Do you want to copy the shared block from '$source_file' to '$target_file'?" "n" && {
                                copy_shared_block "$source_file" "$target_file" &&
                                                                                todo_or_done_txt="copied shared" || todo_or_done_txt="failed to copy shared"
                            } || {
                                (( ++summary_shared_skipped_count )) &&         todo_or_done_txt="skipped shared"
                            }
                            ;;

                        # shared-block markers missing/malformed -- fall back to asking to merge
                        * ) confirm "Do you want to merge '$source_file' to file '$target_file'?" "n" && {
                                merge "$source_file" "$target_file" &&          todo_or_done_txt="merged" || todo_or_done_txt="not merged"
                            } || {
                                (( ++summary_skipped_count )) &&                todo_or_done_txt="skipped"
                            }
                            ;;
                    esac
                    ;;

                * ) error "Unknown action '$actions' for files '$source_file' and '$target_file'." -ec "$err_logic_error"
                                                                                todo_or_done_txt="error!"
                    press_any_key
                    ;;
            esac
        fi

        add_summary_line "$source_file" "$target_file" "$default_actions" "$file_difference_txt" "$todo_or_done_txt"

    done # SoT files loop

    echo "" >> "$summary_file"

    get_repo_state "$target_root" repo_state false || true
    repo_name=${repo_state[$key_name]}
    if [[ -n "$repo_name" ]] && ! is_in "$repo_name" "${vm2_repositories[@]}"; then
        warning "The repository '$repo_name' is not in the list 'vm2_repositories' (see \$VM2_REPOS/vm2.DevOps/scripts/bash/lib/_constants.sh)."  \
                "Any vm2 script that works on all vm2 repositories or uses the '--all-repositories' switch will ignore the '$repo_name' in their operations." \
                "If it SHOULD be included, ensure that '$repo_name' is added to the 'vm2_repositories' list."
        press_any_key
    fi

done # repositories loop

summarize
