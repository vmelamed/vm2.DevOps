#!/bin/bash

declare -r this_script=${BASH_SOURCE[0]}

common_dir=$(realpath "$(dirname "${this_script}")/../../.github/actions/scripts")

# shellcheck disable=SC1091
source "${common_dir}/_common.sh"

declare repos="${GIT_REPOS:-$HOME/repos}"
declare target_repo=""
declare minver_tag_prefix=${MinVerTagPrefix:-"v"}

script_dir="$(dirname "$(realpath -e "$this_script")")"

source "${script_dir}/diff-common.utils.sh"
source "${script_dir}/diff-common.usage.sh"

# shellcheck disable=SC2154
semverTagReleaseRegex="^${minver_tag_prefix}${semverReleaseRex}$"

get_arguments "$@"

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

exit_if_has_errors

target_path="${repos%}/$target_repo"

# shellcheck disable=SC2154
source_files=( \
    "${repos}/.github/workflow-templates/CI.yaml" \
    "${repos}/.github/workflow-templates/Prerelease.yaml" \
    "${repos}/.github/workflow-templates/Release.yaml" \
    "${repos}/.github/workflow-templates/dependabot.yaml" \
    "${repos}/.github/workflow-templates/ClearCache.yaml" \
    "${repos}/vm2.DevOps/.editorconfig" \
    "${repos}/vm2.DevOps/.gitattributes" \
    "${repos}/vm2.DevOps/.gitignore" \
    "${repos}/vm2.DevOps/codecov.yml" \
    "${repos}/vm2.DevOps/Directory.Build.props" \
    "${repos}/vm2.DevOps/Directory.Packages.props" \
    "${repos}/vm2.DevOps/global.json" \
    "${repos}/vm2.DevOps/LICENSE" \
    "${repos}/vm2.DevOps/NuGet.config" \
    "${repos}/vm2.DevOps/test.runsettings" \
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.diagnostics.sh" \
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.dump_vars.sh" \
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.flags.sh" \
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.predicates.sh" \
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.sanitize.sh" \
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.semver.sh" \
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.user.sh" \
    "${repos}/vm2.DevOps/.github/actions/scripts/_common.sh" \
    "${repos}/vm2.DevOps/.github/actions/scripts/.shellcheckrc" \
    "${repos}/vm2.DevOps/scripts/bash/diff-common.sh" \
)
target_files=( \
    "${target_path}/.github/workflows/CI.yaml" \
    "${target_path}/.github/workflows/Prerelease.yaml" \
    "${target_path}/.github/workflows/Release.yaml" \
    "${target_path}/.github/workflows/dependabot.yaml" \
    "${target_path}/.github/workflows/ClearCache.yaml" \
    "${target_path}/.editorconfig" \
    "${target_path}/.gitattributes" \
    "${target_path}/.gitignore" \
    "${target_path}/codecov.yml" \
    "${target_path}/Directory.Build.props" \
    "${target_path}/Directory.Packages.props" \
    "${target_path}/global.json" \
    "${target_path}/LICENSE" \
    "${target_path}/NuGet.config" \
    "${target_path}/test.runsettings" \
    "${target_path}/.github/scripts/_common.diagnostics.sh" \
    "${target_path}/.github/scripts/_common.dump_vars.sh" \
    "${target_path}/.github/scripts/_common.flags.sh" \
    "${target_path}/.github/scripts/_common.predicates.sh" \
    "${target_path}/.github/scripts/_common.sanitize.sh" \
    "${target_path}/.github/scripts/_common.semver.sh" \
    "${target_path}/.github/scripts/_common.user.sh" \
    "${target_path}/.github/scripts/_common.sh" \
    "${target_path}/.github/scripts/.shellcheckrc" \
    "${target_path}/.github/scripts/diff-common.sh" \
)

declare -i i=0 j=0

while i < ${#source_files[@]}; do
    source_file="${source_files[i]}"
    target_file="${target_files[j]}"

    echo "Diffing ${source_file} to ${target_file}:"
    diff -a -w -B --strip-trailing-cr -s -y -W 167 --suppress-common-lines --color=auto "${source_file}" "${target_file}"
    res=$?
    if [[ $res -ne 0 ]]; then
        echo "Files ${source_file} and ${target_file} differ."
    else
        echo "Files ${source_file} and ${target_file} are identical."
    fi
    ((i++))
    ((j++))
done
