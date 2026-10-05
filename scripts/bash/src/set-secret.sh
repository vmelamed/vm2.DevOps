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

declare -xri err_argument_value

declare -x secret_str
declare -x secret_placeholder
declare -xr default_repo_owner

declare -xra vm2_repositories

declare -x repo_owner
declare -x app
declare -x secret_name
declare -xra gh_apps_with_secrets

declare -a repo_secrets=()
declare secret_exists=false
declare secret_value=''

source "$script_dir/set-secret.args.sh"
source "$script_dir/set-secret.usage.sh"

get_arguments "$@"

declare repo

for repo in "${vm2_repositories[@]}"; do
    trace "In repository '$repo':"
    trace "  Getting a list of all current secrets for the repository '$repo'."
    readarray -t repo_secrets < <(execute_gh_api_with_retry 3 2 --paginate "repos/$repo_owner/$repo/actions/secrets" -q '.secrets[] | .name')

    is_in "$secret_name" "${repo_secrets[@]}" && secret_exists=true || secret_exists=false
    $secret_exists || confirm "  Secret '$secret_name' is not present in repository '$repo_owner/$repo'. Do you want to create it?" || continue
    [[ -n "$secret_value" ]] || {
        $secret_exists && default="$secret_placeholder" || default=''
        enter_value "  Enter value for secret '$secret_name'" secret_value "$default" true is_valid_secret
        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        [[ -n "$secret_value" && $secret_value != "$secret_placeholder" ]] && echo "$secret_str" || { echo ''; continue; }
    }

    # ! $secret_exists || {
    #     trace "  Deleting secret '$secret_name' from repository '$repo' if it exists."
    #     execute_gh_with_retry 3 2 true secret delete "$secret_name" --app "$app" --repo "$repo"
    # }

    trace "  Setting the secret '$secret_name' for application '$app' in repository '$repo'..."
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    execute_gh_with_retry 3 2 true secret set "$secret_name" --body "$secret_value" --app "$app" --repo "$repo_owner/$repo" && {
        trace "  Secret '$secret_name' set successfully."
    } || {
        _rc=$?
        warning -ec "$_rc" "  Failed to set secret $secret_name for ${app^}. Run the script with '--verbose' to see more details and troubleshoot."
    }
done
