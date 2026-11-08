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

declare -xri success
declare -xri failure
declare -xri err_argument_value
declare -xri err_tool_error
declare -xri err_io_failure

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

declare -i _rc=$success
declare repo
# shellcheck disable=SC2034 # core_state appears unused. Verify use (or export if used externally).
declare -A core_state=()
declare __value=''

for repo in "${vm2_repositories[@]}"; do
    trace "In repository '$repo':"
    trace "  Getting a list of all current secrets for the repository '$repo'."

    _rc=$success

    declare _temp
    _temp=$(mktemp)                                                             || with_error _rc "$err_io_failure" "Failed to create a temporary file."
    (( _rc == success ))                                                        || continue

    execute_gh_api_with_retry 3 2 --paginate "repos/$repo_owner/$repo/$app/secrets" -q '.secrets[] | .name' > "$_temp" || _rc=$?
    (( _rc != success ))  || readarray -t repo_secrets < "$_temp" || _rc=$err_tool_error
    rm -f "$_temp" || true
    (( _rc == success )) || {
        error "  Failed to retrieve the list of secrets for repository '$repo_owner/$repo'. Moving on to the next repository." -ec "$_rc"
        continue
    }

    is_in_i "$secret_name" "${repo_secrets[@]}" && secret_exists=true || secret_exists=false
    $secret_exists || confirm "  Secret '$secret_name' is not present in repository '$repo_owner/$repo'. Do you want to create it?" || continue

    save_state core_state
    unset_trace_enabled

    [[ -n $secret_value && $secret_value != "$secret_placeholder" ]] || {

        declare default=''

        $secret_exists && default="$secret_placeholder"
        enter_value "  Enter value for secret '$secret_name'" secret_value "$default" true is_valid_secret

        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        [[ -n "$secret_value" && $secret_value != "$secret_placeholder" ]] && echo "$secret_str" || {
            echo ''
            restore_state core_state    # before 'continue': the next repository's save_state needs a restored state
            continue
        }
    }

    # ! $secret_exists || {
    #     trace "  Deleting secret '$secret_name' from repository '$repo' if it exists."
    #     execute_gh_with_retry 3 2 true secret delete "$secret_name" --app "$app" --repo "$repo"
    # }

    trace "  Setting the secret '$secret_name' for application '$app' in repository '$repo'..."

    _rc=$success
    __value=$secret_value

    is_dry_run && __value=$secret_placeholder
    # This passes the plaintext secret into execute_gh_with_retry, whose trace at _git.sh:296 logs the complete argument list;
    # --trace can also expand this call before the helper runs. Thus --verbose, --trace, and dry-run output can disclose the
    # secret. Suppress verbose/xtrace before expanding the command and restore state afterward, following set_secret() at
    # setup-repo.functions.sh:861-877, while logging only a placeholder.
    execute_gh_with_retry 3 2 true secret set "$secret_name" --body "$__value" --app "$app" --repo "$repo_owner/$repo" || _rc=$?

    restore_state core_state

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    (( _rc == success )) &&
        trace "  Secret '$secret_name' was set successfully." ||
        error "  Failed to set secret $secret_name for ${app^}. Run the script with '--verbose' to see more details and troubleshoot." -ec "$_rc"

done

exit_if_has_errors
