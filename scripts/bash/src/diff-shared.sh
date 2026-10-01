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

#===============================
# Imported constants
#===============================
# imported environment variables and defaults:
declare -xr default_vm2_repos_path
declare -x _ignore
declare -xr default_sot
declare -xra sources_of_truth
declare -xra vm2_repositories
declare -xr semverTagReleaseRegex
declare -xr vm2_devops_repo_name

declare -xr cross_ch
declare -xr check_ch
declare -xr equals_ch
declare -xr not_eq_ch

# import outcomes and error codes
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_not_found
declare -xri err_not_file
declare -xri err_not_directory
declare -xri err_not_git_root
declare -xri err_behind_latest_stable_tag
declare -xri err_invalid_repo
declare -xri err_found_too_many
declare -xri err_repo_with_no_ci
declare -xri err_dir_with_no_ci
declare -xri err_not_git_directory
declare -xri err_dir_with_ci
declare -xri err_logic_error
declare -xri err_unexpected_error

source "$script_dir/diff-shared.functions.sh"
source "$script_dir/diff-shared.args.sh"
source "$script_dir/diff-shared.usage.sh"

#===============================
# arguments:
#===============================
declare -x vm2_repos="${VM2_REPOS:-$default_vm2_repos_path}"
declare -x vm2_sot_repo_name
declare -x sot=$default_sot             # at the moment we support only one source of truth @ "$vm2_repos/$vm2_sot_repo_name/templates/$default_sot/content - $VM2_REPOS/templates/AddNewPackage/content
declare -xa target_repos=()             # the target repositories specified as arguments. If not specified, the current directory is used as the only target repo.
declare -xA selectors_actions=()        # array [file] => [action string] for files specified on the CLI with --file* options
declare -x diff_only=false              # if true, only show the differences without asking the user to take any actions. This is useful for CI validation of the shared content.
declare -x current_branch=false         # both vm2.DevOps and SoT repositories must be on the main branch by default, otherwise on their respective current branches
declare -x summary_file=""              # the file where the summary of the differences and actions will be written. If not specified, a temporary file will be created.

#===============================
# Script shared variables:
#===============================
declare -x action_ignore action_merge_or_copy action_ask_to_merge action_ask_to_copy action_merge action_copy \
          action_copy_shared action_ask_to_copy_shared
declare -xri shared_equal
declare -xri shared_not_equal
declare -xa arguments=(         # array of all arguments for logging and debugging purposes
    vm2_repos
    sot
    target_repos
    selectors_actions
    diff_only
    current_branch
    summary_file
)

# this is the data model of the script. Bash does not have complex data structures, so we use parallel arrays to store the
# source files, target files and actions. The index of the arrays corresponds to the same file pair and action. For example,
# source_files[0], target_files[0] and file_actions[0] correspond to the same file pair and action:
declare -xa source_files=()     # array of the paths of the SoT files
declare -xa target_files=()     # array of target paths corresponding to the SoT files by index
declare -xa file_actions=()     # array of default action strings corresponding to the SoT files by index

#===============================
# Summary variables:
#===============================
declare -xi summary_diff_count=0
declare -xi summary_identical_count=0
declare -xi summary_skipped_count=0
declare -xi summary_ignore_count=0
declare -xi summary_not_merged_count=0
declare -xi summary_merged_count=0
declare -xi summary_copied_count=0
declare -xi summary_shared_in_sync_count=0

#===============================
# Script start:
#===============================
get_arguments "$@"

is_in "$sot" "${sources_of_truth[@]}" ||
    usage -ec "$err_argument_value" "Invalid source of truth '$sot'. Valid values are: ${sources_of_truth[*]}."

if $diff_only; then
    for selector in "${!selectors_actions[@]}"; do
        selectors_actions["$selector"]="$action_ignore"   # diff only
    done
fi

#===============================
# Adjust and validate $vm2_repos:
#===============================
declare vm2_branch
declare sot_branch

if $current_branch; then
    vm2_branch=''
    sot_branch=''
else
    vm2_branch='main'
    sot_branch='main'
fi

declare -r vm2_branch
declare -r sot_branch

declare -xi rc="$success"

resolve_vm2_repos vm2_repos "$vm2_branch" "$sot_branch" || rc=$?
(( rc == success )) || usage "Could not resolve the path of the vm2 repositories directory from the specified value of '$vm2_repos'."
trace "All vm2 repositories are expected to be in '$vm2_repos'"

# if no repos were specified as arguments, use the current directory as the only target repo:
! is_empty_array target_repos || target_repos+=("$(pwd)")

#===============================
# Adjust and validate the source of truth:
#===============================
rc="$success"

declare sot_path
get_vm2_sot_path "$vm2_repos" "$sot" sot_path || rc=$?
(( rc == success )) || usage -ec "$rc" "Could not find the source of truth directory for the specified template '$sot' in the expected location in '$vm2_repos'."

declare -xr vm2_repos
declare -xr sot
declare -xr sot_path
declare -xra target_repos
declare -xrA selectors_actions
declare -xr diff_only
declare -xr summary_file

declare -a sot_dump_vars=(
    --quiet
    --header "Configuration for SoT $sot:"
    vm2_repos
    sot_path
    --header "Arguments:"
    "${arguments[@]}"
    --header "Core State:"
    --core-state
)

dump_vars "${sot_dump_vars[@]}"

# Resolve and validate all repositories specified as arguments, and prepare the list of target files and actions for each of them:
declare target_root target_path
declare -a target_roots=()
declare -a target_paths=()

for target in "${target_repos[@]}"; do
    resolve_target "$vm2_repos" "$target" target_root target_path || {
        error -ec "$?" "Could not resolve the Git working tree root of the target '$target'. Please, ensure that it exists and is a valid directory."
        continue
    }
    target_roots+=("$target_root")
    target_paths+=("$target_path")
done
exit_if_has_errors

declare -i targets_index

info "The Source of Truth '$sot' folder is in '$sot_path'"

{
    echo -e "# Summary\n"
    echo -e "## Source of truth: **$sot** (\`$sot_path\`)\n"
} >> "$summary_file"

configure "$sot_path" "$target_path" || exit_with_error -ec "$err_logic_error" "Failed to load configuration from the SoT directory '$sot_path'."
trace "Configured from SoT '$sot_path' for '$target_path'."

declare -x config_diff_tool
declare -x config_diff_command
declare -x config_merge_tool
declare -x config_merge_command

declare -xa config_source_files    # array of the paths of the SoT files
declare -xa config_target_files    # array of target paths TEMPLATES corresponding to the SoT files by index
declare -xa config_file_actions    # array of default action strings corresponding to the SoT files by index

declare -i targets_index
declare target_root target_path

declare -x diff_tool diff_command
declare -x merge_tool merge_command

declare -a source_files
declare -a target_files
declare -a file_actions

declare -i files_index
declare source_file target_file
declare default_actions actions
declare -i difference
declare file_difference_txt todo_or_done_txt

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
    trace "Customized from target repository '$target_root'."

    if ! is_empty_array selectors_actions; then
        parameterize "$diff_only"
        trace "Parameterized for ${#source_files[@]} files with ${#selectors_actions[@]} actions."
    fi

    exit_if_has_errors

    add_summary_header "$target_path"

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

                    "$action_merge_or_copy" | "$action_ask_to_merge" | "$action_ask_to_copy" | "$action_ask_to_copy_shared" )
                        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                        confirm "Target file '$target_file' does not exist. Do you want to copy it from '$source_file'?" "y" && {
                            copy_file "$source_file" "$target_file"
                            todo_or_done_txt="copied"
                        } || {
                            (( ++summary_skipped_count ))
                            todo_or_done_txt="skipped"
                        }
                        ;;

                    "$action_merge" | "$action_copy" | "$action_copy_shared" )
                        # a missing target has no shared-block markers of its own to preserve -- bootstrap it
                        # with the whole SoT file, same as 'merge'/'copy' already do
                        copy_file "$source_file" "$target_file"
                        todo_or_done_txt="copied"
                        ;;

                    * ) error -ec "$err_logic_error" "Unknown action '$actions' for files '$source_file' and '$target_file'."
                        todo_or_done_txt="error"
                        press_any_key
                        ;;
                esac
            fi

            add_summary_line "$source_file" "$target_file" "$default_actions" "$file_difference_txt" "$todo_or_done_txt"
            continue
        fi

        declare show_in_diff_tool warn_no_markers
        rc=$success

        # if different, should we show the files in the diff tool?
        is_in "$actions" "$action_ignore" "$action_merge" "$action_copy" "$action_copy_shared" &&
            show_in_diff_tool=false ||
            show_in_diff_tool=true

        # if the action involves copying shared blocks, should we warn when no markers are found?
        is_in "$actions" "$action_copy_shared" "$action_ask_to_copy_shared" &&
            warn_no_markers=true ||
            warn_no_markers=false

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
                file_difference_txt=" $check_ch different (shared in sync)"
                ;;
            "$shared_not_equal" )
                file_difference_txt=" $cross_ch different (shared differs)"
                ;;
            * ) error -ec "$err_unexpected_error" "Unexpected return code: $difference"
                ;;
        esac

        if ! $different || $diff_only; then
            $diff_only && todo_or_done_txt="$actions"       # actions are to be done
            $different || todo_or_done_txt="$action_ignore" # if not different, override - nothing to do (ignore)
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
                        2 ) merge "$source_file" "$target_file" &&
                                todo_or_done_txt="merged" ||
                                todo_or_done_txt="not merged"
                            ;;

                        3 ) copy_file "$source_file" "$target_file"
                            todo_or_done_txt="copied"
                            ;;

                        * ) (( ++summary_skipped_count ))
                            todo_or_done_txt="skipped"
                            ;;
                    esac
                    ;;

                "$action_ask_to_merge" )
                    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                    confirm "Do you want to merge '$source_file' to file '$target_file'?" "n" && {
                        merge "$source_file" "$target_file" &&
                            todo_or_done_txt="merged" ||
                            todo_or_done_txt="not merged"
                    } || {
                        (( ++summary_skipped_count ))
                        todo_or_done_txt="skipped"
                    }
                    ;;

                "$action_merge" )
                    merge "$source_file" "$target_file" &&
                        todo_or_done_txt="merged" ||
                        todo_or_done_txt="not merged"
                    ;;

                "$action_ask_to_copy" )
                    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                    confirm "Do you want to copy '$source_file' to file '$target_file'?" "n" && {
                        copy_file "$source_file" "$target_file"
                        todo_or_done_txt="copied"
                    } || {
                        (( ++summary_skipped_count ))
                        todo_or_done_txt="skipped"
                    }
                    ;;

                "$action_copy" )
                    copy_file "$source_file" "$target_file"
                    todo_or_done_txt="copied"
                    ;;

                "$action_copy_shared" )
                    case $difference in
                        "$shared_equal" )
                            (( ++summary_shared_in_sync_count ))
                            todo_or_done_txt="shared in sync"
                            ;;

                        "$shared_not_equal" )
                            copy_shared_block "$source_file" "$target_file"
                            todo_or_done_txt="copied shared block"
                            ;;

                        * ) # shared-block markers missing/malformed in one of the files -- are_different()
                            # already warned; fall back to merge rather than risk clobbering private content
                            # with a full-file copy
                            merge "$source_file" "$target_file" &&
                                todo_or_done_txt="merged" ||
                                todo_or_done_txt="not merged"
                            ;;
                    esac
                    ;;

                "$action_ask_to_copy_shared" )
                    case $difference in
                        "$shared_equal" )
                            (( ++summary_shared_in_sync_count ))
                            todo_or_done_txt="shared in sync"
                            ;;

                        "$shared_not_equal" )
                            # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                            confirm "Do you want to copy the shared block from '$source_file' to '$target_file'?" "n" && {
                                copy_shared_block "$source_file" "$target_file"
                                todo_or_done_txt="copied shared block"
                            } || {
                                (( ++summary_skipped_count ))
                                todo_or_done_txt="skipped"
                            }
                            ;;

                        * ) # shared-block markers missing/malformed -- fall back to asking to merge
                            # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                            confirm "Do you want to merge '$source_file' to file '$target_file'?" "n" && {
                                merge "$source_file" "$target_file" &&
                                    todo_or_done_txt="merged" ||
                                    todo_or_done_txt="not merged"
                            } || {
                                (( ++summary_skipped_count ))
                                todo_or_done_txt="skipped"
                            }
                            ;;
                    esac
                    ;;

                * ) error -ec "$err_logic_error" "Unknown action '$actions' for files '$source_file' and '$target_file'."
                    todo_or_done_txt="error!"
                    press_any_key
                    ;;
            esac
        fi

        add_summary_line "$source_file" "$target_file" "$default_actions" "$file_difference_txt" "$todo_or_done_txt"

    done # SoT files loop

    echo "" >> "$summary_file"
done # repositories loop

declare -a args=(
    --force
    --quiet
    --markdown
    --header "Summary:"
    --name "Different"  summary_diff_count
    --name "Identical"  summary_identical_count
    --name "Skipped"    summary_skipped_count
    --name "Ignored"    summary_ignore_count
    --line
    --name "Not Merged" summary_not_merged_count
    --line
    --name "Merged"     summary_merged_count
    --name "Copied"     summary_copied_count
    --name "Shared In Sync" summary_shared_in_sync_count
)
dump_vars "${args[@]}" >> "$summary_file"

# shellcheck disable=SC2015 # A && B || C is not if-then-else. C may run when A is true but B is false.
is_tool_present glow &&
    glow "$summary_file" -w 180 ||
    cat "$summary_file"
