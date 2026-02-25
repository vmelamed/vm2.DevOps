#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

# shellcheck disable=SC1091
source "${lib_dir}/core.sh"

# defaults
declare -xr default_owner="vmelamed"
declare -xr default_visibility="public"
declare -xr default_branch="main"
declare -xr default_configure_only=false
declare -xr default_skip_secrets=false
declare -xr default_skip_variables=false
declare -xr default_force_defaults=false
declare -xr default_audit=false

# start with defaults
repo_path="$(pwd)"
repo_path="${repo_path#"${HOME}"/}" # get the name of the current directory as the default repo path

declare -x repo_path
declare -x git_repos="${GIT_REPOS:-}"
declare -x repo_name=""
declare -x owner=${ORGANIZATION:-$default_owner}
declare -x repo=""
declare -x visibility=${default_visibility}
declare -x branch=${default_branch}
declare -x configure_only=${default_configure_only}
declare -x skip_secrets=${default_skip_secrets}
declare -x skip_variables=${default_skip_variables}
declare -x force_defaults=${default_force_defaults}
declare -x audit=${default_audit}

# required checks enforced by branch protection; extended dynamically
declare -xa required_checks=()

source "${script_dir}/repo-setup.utils.sh"
source "${script_dir}/repo-setup.usage.sh"

get_arguments "$@"
dump_vars --quiet \
    --header "Inputs" \
    repo_path \
    owner \
    visibility \
    branch \
    configure_only \
    skip_secrets \
    skip_variables \
    audit

if [[ "$audit" == true ]]; then
    # for audit we require the repo path to be specified and configured already
    repo_path=$(find_repo_root "$repo_path") || { usage false; exit 2; }
else
    # for configuration we require the root of the repo to be specified, but it doesn't have to be configured already - we'll create it if it doesn't exist
    found=0
    while IFS= read -r d; do
        repo_path="$d"
        (( ++found ))
    done < <(find "$HOME" -type d -path "*/${repo_path}" 2>"$_ignore")
    if (( found == 0 )); then
        usage false "Could not find a directory named '${repo_path}' in your home directory. Please specify a valid path to the root of the project/repository using '--path <path>'."
        exit 2
    elif (( found > 1 )); then
        usage false "Multiple directories named '${repo_path}' found in your home directory. Please specify a more specific path to the root of the project/repository using '--path <path>'."
        exit 2
    fi
fi

# if we are here, repo_path is set to the root of the repo/project or the specified path
is_inside_work_tree "$repo_path" && is_repo=true || is_repo=false
if $is_repo; then
    # if we are inside the repo tree make sure we are at the root of the repo
    repo_path=$(git -C "$repo_path" rev-parse --show-toplevel 2>"$_ignore")
    # extract the name and the owner from the git metadata
    while IFS='=' read -r key value; do
        case "$key" in
            name ) repo_name="$value" ;;
            owner) owner="$value" ;;
            *    ) ;;
        esac
    done < <(gh_repo_info "$repo_path")
else
    # there is no repo yet: infer the repo name from the directory name
    repo_name=$(basename "$repo_path")
fi

[[ -n "$git_repos" ]] && _ci_yaml="${git_repos}/vm2.DevOps/.github/workflows/_ci.yaml"
if [[ ! -s "$_ci_yaml" ]]; then
    _ci_yaml="${repo_path}/../vm2.DevOps/.github/workflows/_ci.yaml"
    if [[ ! -s "$_ci_yaml" ]]; then
        if ! confirm "Could not find _ci.yaml workflow files to detect the names of the required checks. It is recommended to have all your ${owner} repositories and vm2.DevOps cloned in one directory specified by \$GIT_REPOS. Do you want to proceed with default names of the required checks? (y/n)" "n"; then
            info "Aborting."
            exit 0
        fi
    fi
fi

ci_yaml="${repo_path}/.github/workflows/CI.yaml"

[[ -s "$ci_yaml" ]] || {
    error "The specified path '${repo_path}' is not a valid project/repository root (missing .github/workflows/CI.yaml). Please specify a valid path to the root of the project/repository using '--path <path>'."
}
[[ "$repo_name" =~ $repo_name_regex ]] || {
    error "Could not determine repository name from the specified path '${repo_path}' or the name is invalid. Please specify a valid path to the root of the project/repository using '--path <path>'."
}
[[ "$owner" =~ $repo_owner_regex ]] || {
    error "Could not determine repository owner from the specified path '${repo_path}', or from the environment variable ORGANIZATION, or the owner name is invalid. Please specify a valid owner of the project/repository using '--owner <owner>' or set the ORGANIZATION environment variable."
}
visibility="${visibility,,}"
is_in "$visibility" "public" "private" || {
    error "Invalid visibility '${visibility}'. Valid options are 'public' or 'private'. Please specify a valid visibility using '--visibility <public|private>'."
}
git check-ref-format --branch "$branch" &> "$_ignore" || {
    error "Invalid branch name '${branch}'. Please specify a valid branch name using '--branch <branch>'."
}

declare -xr ci_yaml
declare -xr _ci_yaml

# ------------------------------------------------------------------
# Check Prerequisites
# ------------------------------------------------------------------
command -v jq &> "$_ignore" || {
    error "'jq' is not installed. Please install it first."
}
command -v yq &> "$_ignore" || {
    error "'yq' is not installed. Please install it first."
}
[[ $(yq --version) =~ https://github\.com/mikefarah/yq/ ]] || {
    error 'This script requires "yq" by Mike Farah: "wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/.local/bin/yq4; chmod +x ~/.local/bin/yq4"'
}
command -v gh &> "$_ignore" || {
    error "'gh' is not installed. Please install it first."
}
gh auth status &> "$_ignore" || {
    error "'gh' is not authenticated. Run 'gh auth login' first."
}

exit_if_has_errors

repo="${owner}/${repo_name}"

declare -rx repo
declare -rx branch
declare -rx configure_only
declare -rx skip_secrets
declare -rx skip_variables
declare -rx force_defaults
declare -rx audit

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

if [[ "$audit" == true ]]; then
    source "${script_dir}/repo-setup.audit.sh"
    info "Audit mode — reading current settings for ${repo}..."
    audit_repo
    exit 0
fi

source "${script_dir}/repo-setup.functions.sh"

if [[ "$configure_only" != true ]]; then
    # Ensure git initialized
    if [[ ! -d .git ]]; then
        execute git -C "$repo_path" init
        execute git -C "$repo_path" checkout -b "${branch}"
    fi

    execute git -C "$repo_path" add .
    if ! git -C "$repo_path" diff --cached --quiet; then
        execute git -C "$repo_path" commit -m "chore: initial scaffold" || true
    fi

    if gh repo view "$repo" &> "$_ignore"; then
        info "Repo ${repo} already exists; skipping creation."
    else
        info "Creating repository ${repo}..."
        execute gh repo create "$repo" "--${visibility}" --source . --remote origin --push --branch "${branch}"
    fi

    execute git -C "$repo_path" remote set-url origin "git@github.com:${repo}.git"
    execute git -C "$repo_path" push -u origin "${branch}"
fi

detect_required_checks

if [[ "$skip_secrets" != true ]]; then
    configure_secrets
fi

if [[ "$skip_variables" != true ]]; then
    configure_variables
fi

configure_repo_settings
configure_actions_permissions
configure_branch_protection

info "Repository ready: https://github.com/${repo}"
if [[ "$skip_secrets" != true ]]; then
    warning "All secrets have placeholder values — update them with real values."
fi
