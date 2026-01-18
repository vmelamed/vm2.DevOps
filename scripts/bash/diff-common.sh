#!/bin/bash

declare -r this_script=${BASH_SOURCE[0]}

common_dir=$(realpath "$(dirname "${this_script}")/../../.github/actions/scripts")

# shellcheck disable=SC1091
source "${common_dir}/_common.sh"

declare repos="${GIT_REPOS:-$HOME/repos}"
declare target_repo=""
declare minver_tag_prefix=${MinVerTagPrefix:-"v"}
declare interactive=false

script_dir="$(dirname "$(realpath -e "$this_script")")"

source "${script_dir}/diff-common.utils.sh"
source "${script_dir}/diff-common.usage.sh"

# shellcheck disable=SC2154
semverTagReleaseRegex="^${minver_tag_prefix}${semverReleaseRex}$"

get_arguments "$@"
create_tag_regexes "$minver_tag_prefix"

# TODO: remove these lines once the script is stable
# shellcheck disable=SC2034
{
    verbose=true
    quiet=false
}

# shellcheck disable=SC2119 # Use dump_all_variables "$@" if function's $1 should mean script's $1.
dump_all_variables

if [[ -z "$repos" ]]; then
    error "The source repositories directory is not specified."
fi
if [[ -z "$target_repo" ]]; then
    error "No target repository specified."
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
    error "The .github repository at '${repos}/.github' is not a valid git repository."
fi
if ! is_git_repo "${repos}/vm2.DevOps"; then
    error "The vm2.DevOps repository at '${repos}/vm2.DevOps' is not a valid git repository."
fi
if ! is_on_or_after_latest_stable_tag "${repos}/.github" "$semverTagReleaseRegex"; then
    error "The HEAD of the .github repository is before the latest stable tag."
fi
if ! is_on_or_after_latest_stable_tag "${repos}/vm2.DevOps" "$semverTagReleaseRegex"; then
    error "The HEAD of the vm2.DevOps repository is before the latest stable tag."
fi

if [[ "$target_repo" =~ ${repos%}/.* ]]; then
    target_path="$target_repo"
else
    target_path="${repos%}/$target_repo"
fi
trace "Target repository path: $target_path"

if [[ ! -d "$target_path" ]]; then
    error "The target repository '$target_path' does not exist."
fi
if [[ ! -d "$target_path/.github/workflows" ]]; then
    error "The target repository '$target_path' does not contain the .github/workflows directory."
fi
if [[ ! -d "$target_path/.github/scripts" ]]; then
    warning "The target repository '$target_path' does not contain the .github/scripts directory."
fi

# shellcheck disable=SC2154
source_files=(
    "${repos}/vm2.DevOps/.editorconfig"
    "${repos}/vm2.DevOps/.gitattributes"
    "${repos}/vm2.DevOps/.gitignore"
    "${repos}/vm2.DevOps/codecov.yml"
    "${repos}/vm2.DevOps/Directory.Build.props"
    "${repos}/vm2.DevOps/Directory.Packages.props"
    "${repos}/vm2.DevOps/global.json"
    "${repos}/vm2.DevOps/LICENSE"
    "${repos}/vm2.DevOps/NuGet.config"
    "${repos}/vm2.DevOps/test.runsettings"

    "${repos}/.github/workflow-templates/dependabot.yaml"
    "${repos}/.github/workflow-templates/CI.yaml"
    "${repos}/.github/workflow-templates/Prerelease.yaml"
    "${repos}/.github/workflow-templates/Release.yaml"
    "${repos}/.github/workflow-templates/ClearCache.yaml"

    "${repos}/vm2.DevOps/.github/actions/scripts/_common.diagnostics.sh"
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.dump_vars.sh"
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.flags.sh"
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.predicates.sh"
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.sanitize.sh"
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.semver.sh"
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.user.sh"
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.sh"
    "${repos}/vm2.DevOps/.github/actions/scripts/.shellcheckrc"
    "${repos}/vm2.DevOps/scripts/bash/diff-common.sh"
    "${repos}/vm2.DevOps/scripts/bash/diff-common.utils.sh"
    "${repos}/vm2.DevOps/scripts/bash/diff-common.usage.sh"
)
target_files=(
    "${target_path}/.editorconfig"
    "${target_path}/.gitattributes"
    "${target_path}/.gitignore"
    "${target_path}/codecov.yml"
    "${target_path}/Directory.Build.props"
    "${target_path}/Directory.Packages.props"
    "${target_path}/global.json"
    "${target_path}/LICENSE"
    "${target_path}/NuGet.config"
    "${target_path}/test.runsettings"

    "${target_path}/.github/dependabot.yaml"
    "${target_path}/.github/workflows/CI.yaml"
    "${target_path}/.github/workflows/Prerelease.yaml"
    "${target_path}/.github/workflows/Release.yaml"
    "${target_path}/.github/workflows/ClearCache.yaml"

    "${target_path}/scripts/_common.diagnostics.sh"
    "${target_path}/scripts/_common.dump_vars.sh"
    "${target_path}/scripts/_common.flags.sh"
    "${target_path}/scripts/_common.predicates.sh"
    "${target_path}/scripts/_common.sanitize.sh"
    "${target_path}/scripts/_common.semver.sh"
    "${target_path}/scripts/_common.user.sh"
    "${target_path}/scripts/_common.sh"
    "${target_path}/scripts/.shellcheckrc"
    "${target_path}/scripts/diff-common.sh"
    "${target_path}/scripts/diff-common.utils.sh"
    "${target_path}/scripts/diff-common.usage.sh"
    )
declare -A file_actions
file_actions=(
    ["${repos}/vm2.DevOps/.editorconfig"]="mc"
    ["${repos}/vm2.DevOps/.gitattributes"]="mc"
    ["${repos}/vm2.DevOps/.gitignore"]="mc"
    ["${repos}/vm2.DevOps/codecov.yml"]="mc"
    ["${repos}/vm2.DevOps/Directory.Build.props"]="mc"
    ["${repos}/vm2.DevOps/Directory.Packages.props"]="mc"
    ["${repos}/vm2.DevOps/global.json"]="mc"
    ["${repos}/vm2.DevOps/LICENSE"]="c"
    ["${repos}/vm2.DevOps/NuGet.config"]="mc"
    ["${repos}/vm2.DevOps/test.runsettings"]="mc"

    ["${repos}/.github/workflow-templates/dependabot.yaml"]="mc"
    ["${repos}/.github/workflow-templates/CI.yaml"]="mc"
    ["${repos}/.github/workflow-templates/Prerelease.yaml"]="mc"
    ["${repos}/.github/workflow-templates/Release.yaml"]="mc"
    ["${repos}/.github/workflow-templates/ClearCache.yaml"]="mc"

    ["${repos}/vm2.DevOps/.github/actions/scripts/_common.diagnostics.sh"]="c"
    ["${repos}/vm2.DevOps/.github/actions/scripts/_common.dump_vars.sh"]="c"
    ["${repos}/vm2.DevOps/.github/actions/scripts/_common.flags.sh"]="c"
    ["${repos}/vm2.DevOps/.github/actions/scripts/_common.predicates.sh"]="c"
    ["${repos}/vm2.DevOps/.github/actions/scripts/_common.sanitize.sh"]="c"
    ["${repos}/vm2.DevOps/.github/actions/scripts/_common.semver.sh"]="c"
    ["${repos}/vm2.DevOps/.github/actions/scripts/_common.user.sh"]="c"
    ["${repos}/vm2.DevOps/.github/actions/scripts/_common.sh"]="c"
    ["${repos}/vm2.DevOps/.github/actions/scripts/.shellcheckrc"]="mc"
    ["${repos}/vm2.DevOps/scripts/bash/diff-common.sh"]="c"
    ["${repos}/vm2.DevOps/scripts/bash/diff-common.utils.sh"]="c"
    ["${repos}/vm2.DevOps/scripts/bash/diff-common.usage.sh"]="c"
)

if [[ ${#source_files[@]} -ne ${#target_files[@]} ]] || [[ ${#source_files[@]} -ne ${#file_actions[@]} ]]; then
    error "The data in the tables do not match."
fi

exit_if_has_errors

function copy_file() {
    local src_file="$1"
    local dest_file="$2"

    local dest_dir
    dest_dir=$(dirname "$dest_file")
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi
    cp "$src_file" "$dest_file"
    echo "File '${dest_file}' copied from '${src_file}'."
}

declare -i i=0

while [[ $i -lt ${#source_files[@]} ]]; do
    source_file="${source_files[i]}"
    target_file="${target_files[i]}"
    actions="${file_actions[$source_file]}"
    ((i++))

    echo -e "\n${source_file} <-----> ${target_file}:"

    if [[ ! -s "$target_file" ]]; then
        if [[ "$quiet" != true ]]; then
            yn=$(confirm "Target file '${target_file}' does not exist. Do you want to copy it from '${source_file}'?" "y")
            if [[ "$yn" == y ]]; then
                copy_file "$source_file" "$target_file"
            fi
        else
            echo "Target file '${target_file}' does not exist or is empty."
        fi
        continue
    fi

    diff -a -w -B --strip-trailing-cr -s -y -W 167 --suppress-common-lines --color=auto "${source_file}" "${target_file}"
    res=$?

    if [[ $res -ne 0 ]]; then
        echo "Files ${source_file} and ${target_file} are different"
        if [[ "$quiet" != true ]]; then
            if [[ "$actions" == "c" ]]; then
                yn=$(confirm "Do you want to copy the source file '${source_file}' to the target file '${target_file}'?" "n")
                if [[ "$yn" == y ]]; then
                    copy_file "$source_file" "$target_file"
                fi
            elif [[ "$actions" == "mc" ]]; then
                case $(choose "What do you want to do?" \
                    "Do nothing - continue" \
                    "Merge files using 'Visual Studio Code' (you need to have 'VSCode' installed)" \
                    "Copy source file to target file") in
                    2) code --diff "$source_file" "$target_file" --new-window --wait ;;
                    3) copy_file "$source_file" "$target_file" ;;
                    *) ;;
                esac
            else
                press_any_key
            fi
        fi
    fi
done
