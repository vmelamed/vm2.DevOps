# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# length-review: keep together -- all repository configuration functions

declare -x script_name
declare -x lib_dir

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x err_invalid_arguments
declare -x err_argument_value
declare -x err_tool_error
declare -x err_io_failure
declare -x err_logic_error

# vm2 core lib constants
declare -x question_em
declare -x secret_str
declare -x secret_placeholder

# vm2 core lib variables
declare -x noise_sink

# this scripts constants
declare -x admin_role_id

declare -x repo
declare -x default_branch
declare -x interactive_vars
declare -x interactive_secrets
declare -x branch_protection_rs_name
declare -x purge_vars
declare -x purge_secrets
declare -x nuget_server

declare -x default_repo_settings
declare -x default_repo_permissions

declare -x gh_apps_with_vars
declare -x gh_apps_with_vars_str
declare -x gh_apps_with_secrets

declare -xi branch_protection_rs_id=0

declare -xi actions_app_id

declare -xa required_checks

declare -x path_repo
declare -x path_permissions
declare -x path_rulesets
declare -x path_branch_protection_ruleset

declare -x jq_entries
declare -x jq_secret_names
declare -x jq_vars
declare -x jq_ruleset_id

#-----------------------------------------------------------------------------------------------
# @description Fetches the target repository's current settings and PATCHes any that differ
# from `default_repo_settings` via the GitHub API. Booleans are sent as JSON (`-F`), other
# values as strings (`-f`). Settings that already match the expected value are left untouched
# (no-op PATCH avoided when there is nothing to change).
#
# @exitcode success=0: Always (a failed PATCH call is logged as a warning, not
#   surfaced as a non-zero exit code).
# @exitcode err_tool_error=66: Retrieving the current repo settings failed.
#
# @stdout Progress/status messages via `info` ("Configuring repository settings...",
#   "...repository settings configured.").
#-----------------------------------------------------------------------------------------------
function configure_default_repo_settings()
{
    info "Configuring repository settings..."

    # get existing repository settings
    local -A _existing
    local _key _value
    local -i _rc=$success

    local _result
    _result=$(execute_with_retry --query --classify gh_failure \
                  gh api "$path_repo" -q "$jq_entries" 2>"$noise_sink")         || {
                                                                                        with_error _rc "$err_tool_error" "Retrieving the current repo settings failed."
                                                                                        return "$_rc"
                                                                                   }

    while IFS='=' read -r _key _value; do
        _existing["$_key"]="$_value"
    done <<< "$_result"

    local -a _rs=()
    local _actual
    local _expected

    for _key in "${!default_repo_settings[@]}"; do
        [[ -n ${_existing[$_key]+_} ]] && _actual="${_existing[$_key]}" || _actual=""
        _expected="${default_repo_settings[$_key]}"
        if [[ "$_actual" != "$_expected" ]]; then
            # Use -F for booleans to send as JSON instead of strings
            if is_boolean "$_expected"; then
                _rs+=("-F" "$_key=$_expected")
            else
                _rs+=("-f" "$_key=$_expected")
            fi
            trace "Setting repository setting: $_key=$_expected"
        else
            trace "Repository setting is already set: $_key=$_actual, skipping."
        fi
    done

    if [[ ${#_rs[@]} -gt 0 ]]; then
        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        execute_with_retry --quiet --classify gh_failure \
            gh api -X PATCH "$path_repo" "${_rs[@]}" 2>"$noise_sink" &&
            info "...repository settings configured." ||                        warning "Failed to configure the repository settings." "Run the script with '--verbose' for the details."
    else
        info "...repository settings configured."
    fi
}

#-----------------------------------------------------------------------------------------------
# @description Sets the target repository's Actions workflow permissions via the GitHub API to match
# `default_repo_permissions`. Unlike `configure_default_repo_settings()`, this always includes every key from
# `default_repo_permissions` in the PUT request body regardless of whether the current value already matches --
# the permissions endpoint is a full-replace PUT, not a partial PATCH, so there is no per-key skip optimization
# here. Booleans are sent as JSON (`-F`), other values as strings (`-f`).
#
# @exitcode success=0: Always (a failed PUT call is logged as a warning, not surfaced as a non-zero exit code).
#
# @stdout Progress/status messages via `info` ("Configuring Actions workflow permissions...", "...actions workflow
#   permissions configured.").
#-----------------------------------------------------------------------------------------------
function configure_actions_permissions()
{
    info "Configuring Actions workflow permissions..."

    # get existing repository permissions
    local -A _existing
    local _key _value
    local _result
    local -i _rc=$success
    _result=$(execute_with_retry --query --classify gh_failure \
                  gh api "$path_permissions" -q "$jq_entries" 2>"$noise_sink")  || {
                                                                                        with_error _rc "$err_tool_error" "Retrieving the current repo permissions failed."
                                                                                        return "$_rc"
                                                                                    }

    while IFS='=' read -r _key _value; do
        _existing["$_key"]="$_value"
    done <<< "$_result"

    local -a _rs=()
    local _actual
    local _expected

    for _key in "${!default_repo_permissions[@]}"; do
        [[ -n ${_existing[$_key]+_} ]] && _actual="${_existing[$_key]}" || _actual=""
        _expected="${default_repo_permissions[$_key]}"

        # Use -F for booleans to send as JSON instead of strings
        if is_boolean "$_expected"; then
            _rs+=("-F" "$_key=$_expected")
        else
            _rs+=("-f" "$_key=$_expected")
        fi
        trace "Setting repository setting: $_key=$_expected"
    done

    if [[ ${#_rs[@]} -gt 0 ]]; then
        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        execute_with_retry --quiet --classify gh_failure \
            gh api -X PUT "$path_permissions" -H "Accept: application/vnd.github+json" "${_rs[@]}" 2>"$noise_sink" &&
            info "...actions workflow permissions configured."                  || warning "Failed to configure the Actions workflow permissions." \
                                                                                           "Run the script with '--verbose' for the details."
    else
        info "...actions workflow permissions configured."
    fi
}

#-----------------------------------------------------------------------------------------------
# @description Reconciles the target repository's GitHub Actions variables against the default vars of the given
#   application ($1), and optionally purges variables that are neither a known default nor otherwise expected.
#   No-op (returns immediately) if the application has no default variables and `$purge_vars` is false, to avoid an
#   unnecessary API call.
#   - In non-interactive mode (the default), creates any missing variable with its default value and leaves
#     existing variables untouched.
#   - In interactive mode (`$interactive_vars == true`), prompts the user for each variable's value (pre-filled
#     with the current value if it exists, else with the default), validating input with the validator from
#     `_vars_validators`, and calls `set_var` only when the entered value differs from the current one.
#   - If `NUGET_SERVER`'s reconciled value differs from the current global `$nuget_server`, updates the global and
#     re-fetches the default tables via `get_vars_defaults` (since several other defaults, e.g. `NUGET_USERNAME`,
#     depend on which NuGet server is in effect).
#   - Any existing variable that is not among the application's known defaults is a purge candidate: when
#     `$purge_vars` is true, it is deleted via `delete_var` (asking for confirmation first when `$interactive_vars`
#     is also true); otherwise it is left alone and reported as "unknown or obsolete" in the summary.
#   - Prints a summary of how many variables were set to a new value, set to their default, left unmodified,
#     ignored as unknown/obsolete, or deleted, followed by a hint about `--purge-vars`/`--interactive-vars` when
#     applicable.
#
# @arg $1 string Application name; must be one of the entries in `gh_apps_with_vars` (currently `actions`, `agents`).
#
# @exitcode success=0: Always (individual `set_var`/`delete_var` failures are logged and skipped, not surfaced as a
#   non-zero exit code), including the no-op early return when there is nothing to reconcile or purge.
#
# @stdout Progress/status messages via `info`, (in interactive mode) prompts via `enter_value` and `confirm`, and a
#   final summary of the reconciliation/purge counts.
#-----------------------------------------------------------------------------------------------
# shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
function configure_variables()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of the GitHub application being configured, e.g. actions."
    [[ ! -v 1 ]] || is_in "$1" "${gh_apps_with_vars[@]}"                        || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the application name, to be one of: $gh_apps_with_vars_str (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs

    local _app=${1,,}
    local -i _rc=$success

    local -A _vars_defaults
    local -a _vars_order
    local -A _vars_validators

    # get the default values for the application's variables based on the current NuGet server
    get_vars_defaults "${_app,,}" _vars_defaults _vars_order _vars_validators

    # Nothing to reconcile and nothing to purge -- skip the API call entirely rather than fetch
    # the app's current variables just to discover there's nothing to do with them.
    (( ${#_vars_defaults[@]} > 0 )) || $purge_vars                              || return "$success"

    info "Configuring GitHub ${_app^} variables..."

    # get the currently existing variables from the GitHub repository
    local _var _value
    local -A _current=()
    local _result
    _result=$(execute_with_retry --query --classify gh_failure \
                  gh api --paginate "$path_repo/$_app/variables" -q "$jq_vars" 2>"$noise_sink") \
                                                                                ||  {
                                                                                        with_error _rc "$err_tool_error" "Retrieving the current repo variables failed."
                                                                                        return "$_rc"
                                                                                    }

    [[ -z $_result ]] ||
    while IFS='=' read -r _var _value; do
        _current["$_var"]="$_value"
    done <<< "$_result"

    local _exists _default
    local _new_value=''
    local _default_value=''
    local -i _skipped=0 _set_new=0 _set_default=0 _ignored=0 _deleted=0

    # work through the default vars
    for _var in "${_vars_order[@]}"; do
        if [[ $_var == --* ]]; then
            $interactive_vars && printf "    ➡️  %-38s %s\n" "${_var#--}" "────────────────────────────────────────────────────────────────────────"
            continue
        fi

        # it is possible that a variable in the order array is not in the default values array - e.g. programmatically removed
        # like NUGET_USERNAME which will be removed from the default values array if the NuGet server is GitHub Packages.
        [[ -v _vars_defaults[$_var] ]] || continue

        _default_value="${_vars_defaults[$_var]}"
        if [[ -v _current[$_var] ]]; then
            _exists=true
            _value="${_current[$_var]:-}"
        else
            _exists=false;
            _value='';
        fi

        if $interactive_vars; then
            local _prompt="            Enter value for variable $_var"
            local _validator=${_vars_validators["$_var"]:-true}

            # prompt the user for a value while showing them the current value (if it exists) and
            # the default value (if it is different from the current value)
            if $_exists; then
                _default="$_value"
                [[ $_default_value != "$_value" ]] && _prompt="$_prompt (default: '$_default_value')"
            else
                _default="$_default_value"
            fi

            enter_value "$_prompt" _new_value "$_default" false "$_validator"

            if [[ $_new_value != "$_value" ]]; then
                # set the variable to the value
                _value="$_new_value"
                set_var "$_var" "$_value" || continue
                trace "Setting variable: $_var=$_new_value"
                # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
                [[ $_value == "$_default_value" ]] && (( ++_set_default )) || (( ++_set_new ))

            else
                trace "Unchanged variable: '$_var==$_value'"
                (( ++_skipped ))
            fi
        else
            if $_exists; then
                trace "Unchanged variable: '$_var==$_value'"
                (( ++_skipped ))
            else
                trace "Creating a variable with its default value: '$_var=$_default_value'"
                _value="$_default_value"
                set_var "$_var" "$_value"
                (( ++_set_default ))
            fi
        fi

        # if the NuGet server has changed, update the global variable and refresh the defaults
        if [[ $_var == NUGET_SERVER && -n $_value ]]; then
            # for this to work the item NUGET_USERNAME in actions_vars_order MUST come after NUGET_SERVER
            nuget_server="$_value"
            # this is one off strange move but if the NuGet server is now "github" - remove the user name, GitHub is using the token
            if [[ $nuget_server == "github" ]]; then
                unset "_vars_defaults[NUGET_USERNAME]"
            else
                _vars_defaults[NUGET_SERVER]="$_value"
                _vars_defaults[NUGET_USERNAME]=''
            fi
        fi
    done

    for _var in "${!_current[@]}"; do
        if [[ ! -v _vars_defaults[$_var] ]]; then
            # it's a purge candidate
            if $purge_vars; then
                if $interactive_vars; then
                    if confirm "            $question_em  Do you want to delete the unknown or obsolete variable '$_var'?" "n"; then
                        delete_var "$_var" &&
                        (( ++_deleted )) &&
                        trace "Deleted the unknown or obsolete variable '$_var'."
                    else
                        (( ++_ignored )) &&
                        trace "The unknown or obsolete variable '$_var' was not deleted."
                    fi
                else
                    delete_var "$_var" &&
                    (( ++_deleted )) &&
                    warning "Deleted the unknown or obsolete variable '$_var'."
                fi
            else
                (( ++_ignored )) &&
                warning "Unknown or obsolete variable '$_var'."
            fi
        fi
    done

    # display the summary
    (( _set_new     == 1 )) && info "    1 variable was set to a new value."                        || true
    (( _set_new      > 1 )) && info "    $_set_new variables were set to new values."               || true

    (( _set_default == 1 )) && info "    1 variable was set to its default value."                  || true
    (( _set_default  > 1 )) && info "    $_set_default variables were set to their default values." || true

    (( _skipped     == 1 )) && info "    1 variable was not modified."                              || true
    (( _skipped      > 1 )) && info "    $_skipped variables were not modified."                    || true

    (( _ignored     == 1 )) && info "    1 unknown or obsolete variable was ignored."               || true
    (( _ignored      > 1 )) && info "    $_ignored unknown or obsolete variables were ignored."     || true

    (( _deleted     == 1 )) && info "    1 unknown or obsolete variable was deleted."               || true
    (( _deleted      > 1 )) && info "    $_deleted unknown or obsolete variables were deleted."     || true

    (( _ignored     == 0 )) || info "  Run the script with option '--purge-vars' or '-pv' to delete the unknown variables." \
                                    "  You may also add '--interactive-vars' or '-iv' to confirm the deletion of each unknown variable."
    $interactive_vars       || info "  Run the script with option '--interactive-vars' or '-iv' to set new values or delete unknown and obsolete variables for any of the ${_app^} vars."
}

#-----------------------------------------------------------------------------------------------
# @description Reconciles one GitHub App's repository secrets against the corresponding `<app>_secrets_order` list,
# and optionally purges secrets that are neither a known default nor otherwise expected. Secret values themselves
# cannot be read back from GitHub, so reconciliation of known secrets is presence-only: an existing secret is left
# untouched, and a missing secret is either created interactively (prompting the user, `$interactive_secrets ==
# true`) or flagged with a warning asking the user to create it (`$interactive_secrets == false`). No-op (returns
# immediately) if the application has no default secrets and `$purge_secrets` is false, to avoid an unnecessary API
# call.
#   - Any existing secret that is not among the application's known defaults is a purge candidate: when
#     `$purge_secrets` is true, it is deleted via `delete_secret` (asking for confirmation first when
#     `$interactive_secrets` is also true); otherwise it is left alone and reported as "unknown or obsolete".
#   - Prints a summary of how many secrets were set, left unmodified, still need a value, ignored as
#     unknown/obsolete, or deleted.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#   - `gh_apps_with_secrets` currently lists `actions`, `dependabot`, and `codespaces`; `agents` is commented out there
#     since agents are not used yet, so it is not presently a valid value for `$1` despite `agents_secrets_order`
#     still existing as an (empty) table.
#
# @arg $1 string Application name; must be one of the entries in `gh_apps_with_secrets` (currently `actions`,
#   `dependabot`, `codespaces`).
#
# @exitcode success=0: including the case where the app has no configured secrets at all and nothing to purge
#   (returns immediately).
#
# @stdout Progress/status messages via `info`/`warning`, (in interactive mode) prompts via `enter_value` and
#   `confirm`, and a final summary of the reconciliation/purge counts.
#-----------------------------------------------------------------------------------------------
function configure_secrets()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the application name."
    [[ ! -v 1 ]] || is_in "$1" "${gh_apps_with_secrets[@]}"                     || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the application name, to be one of: ${gh_apps_with_secrets[*]} (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs

    local _app=${1,,}

    local -A _secrets_defaults
    local -a _secrets_order
    local -A _secrets_validators

    # get the default values for the application's secrets based on the current NuGet server
    get_secrets_defaults "$_app" _secrets_defaults _secrets_order _secrets_validators

    # Nothing to reconcile and nothing to purge -- skip the API call entirely rather than fetch
    # the app's current secrets just to discover there's nothing to do with them.
    (( ${#_secrets_defaults[@]} > 0 )) || $purge_secrets                        || return "$success"

    info "Configuring ${_app^} secrets..."

    local -i _rc=$success
    local _temp
    _temp=$(mktemp)                                                             || with_error _rc "$err_io_failure" "  Failed to create a temporary file."

    (( _rc != success ))  || execute_with_retry --query --classify gh_failure \
                                gh api --paginate "$path_repo/$_app/secrets" -q "$jq_secret_names" > "$_temp" \
                                                                                || with_error _rc $? "  Failed to retrieve the list of secrets for the GitHub application '$_app' in repository '$repo'."

    local -a _current

    (( _rc != success ))  || readarray -t _current < "$_temp"                   || with_error _rc "$err_tool_error" "  Failed to read the list of secrets for the GitHub application '$_app' in repository '$repo'."
    rm -f "$_temp"

    (( _rc == success ))                                                        || return "$_rc"

    local _secret _value _exists _default # about the current secret
    local -i _skipped=0 _set_new=0 _need_new=0 _ignored=0 _deleted=0 # summary variables

    for _secret in "${_secrets_order[@]}"; do
        if [[ $_secret == --* ]]; then
            $interactive_secrets && printf "    ➡️  %-38s %s\n" "${_secret#--}" "────────────────────────────────────────────────────────────────────────"
            continue
        fi

        # it is possible that a secret in the order array is not in the default secrets array - e.g. programmatically removed
        # like NUGET_API_KEY which will be removed from the default values array if the NuGet server is GitHub Packages or NuGet.org.
        [[ -v _secrets_defaults[$_secret] ]] || continue

        is_in "$_secret" "${_current[@]}" && _exists=true || _exists=false

        # get the value for the secret or use the placeholder if we are not entering secrets interactively
        if $interactive_secrets; then

            # prompt the user for a (new) value of the secret
            local _prompt="        Enter value for secret $_secret"
            local _validator="${_secrets_validators[$_secret]:-true}"

            $_exists && _default="$secret_placeholder" || _default=''

            enter_value "$_prompt" _value "$_default" true "$_validator"

            if [[ -n $_value && $_value != "$secret_placeholder" ]]; then
                echo "$secret_str" # display '••••••' - UI feedback that we've got the value and it is secret
                set_secret "$_secret" "$_value" "$_app" || continue
                trace "Set value of secret: $_secret"
                (( ++_set_new ))

            elif [[ -n $_value && $_value == "$secret_placeholder" ]]; then
                echo ""
                trace "Unchanged secret: $_secret"
                (( ++_skipped ))

            elif [[ -z $_value ]]; then
                warning "      Create secret: $_secret."
                (( ++_need_new ))
            fi
        else
            # the secret exists in GH or it does not exist; but we are not in interactive mode, so either way skip it
            if $_exists; then
                trace "Unchanged secret: $_secret"
                (( ++_skipped ))
            else
                warning "      Create secret: $_secret."
                (( ++_need_new ))
            fi
        fi
    done

    for _secret in "${_current[@]}"; do
        if [[ ! -v _secrets_defaults[$_secret] ]]; then
            # it's a purge candidate
            if $purge_secrets; then
                if $interactive_secrets; then
                    if confirm "            $question_em  Do you want to delete the unknown or obsolete secret '$_secret'?" "n"; then
                        delete_secret "$_secret" "$_app" &&
                        (( ++_deleted )) &&
                        trace "Deleted the unknown or obsolete secret '$_secret'."
                    else
                        (( ++_ignored )) &&
                        trace "Did not delete unknown or obsolete secret '$_secret'."
                    fi
                else
                    delete_secret "$_secret" "$_app" &&
                    (( ++_deleted )) &&
                    warning "Deleted the unknown or obsolete secret '$_secret'."
                fi
            else
                (( ++_ignored )) &&
                warning "Unknown or obsolete secret '$_secret'."
            fi
        fi
    done

    (( _set_new == 1 )) && info "    1 secret was set to a new value."                                                                              || true
    (( _set_new  > 1 )) && info "    $_set_new secrets were set to new values."                                                                     || true

    (( _skipped == 1 )) && info "    1 secret was not modified."                                                                                    || true
    (( _skipped  > 1 )) && info "    $_skipped secrets were not modified."                                                                          || true

    (( _ignored == 1 )) && info "    1 unknown or obsolete secret was ignored."                                                                     || true
    (( _ignored  > 1 )) && info "    $_ignored unknown or obsolete secrets were ignored."                                                           || true

    (( _deleted == 1 )) && info "    1 unknown or obsolete secret was deleted."                                                                     || true
    (( _deleted  > 1 )) && info "    $_deleted unknown or obsolete secrets were deleted."                                                           || true

    (( _need_new == 1 )) && warning "Run the script with option '--interactive-secrets' or '-is' to set the value of 1 ${_app^} secret."            || true
    (( _need_new  > 1 )) && warning "Run the script with option '--interactive-secrets' or '-is' to set the values of $_need_new ${_app^} secrets." || true
}

#-----------------------------------------------------------------------------------------------
# @description Creates (POST) or updates (PUT, if `initialize_branch_protection_rs_id` finds one
#   already exists) the GitHub ruleset that protects the default branch: linear history, no
#   force pushes, a required pull request with rebase-only merges, and the required status
#   checks collected in `required_checks`. After the API call, re-runs
#   `initialize_branch_protection_rs_id` so `branch_protection_rs_id`/`path_branch_protection_ruleset`
#   reflect a newly-created ruleset (a no-op if the ruleset already existed and was just
#   updated).
#
# @exitcode success=0: Always (a failed `gh api` call is not
#   checked/propagated here).
#
# @stdout Progress/status messages via `info` ("Configuring branch ruleset...", "Updating
#   existing ruleset...", or "Creating new ruleset...").
#-----------------------------------------------------------------------------------------------
function configure_branch_protection()
{
    info "Configuring branch ruleset for '$default_branch'..."

    local _method
    local _endpoint

    # Check if a ruleset named "main protection" already exists
    if initialize_branch_protection_rs_id; then
        _method="PUT"
        _endpoint="$path_branch_protection_ruleset"
        info "Updating existing ruleset $branch_protection_rs_name (id: $branch_protection_rs_id)..."
    else
        _method="POST"
        _endpoint="$path_rulesets"
        info "Creating new ruleset $branch_protection_rs_name..."
    fi

    # Build required status checks array
    local _status_checks_json=""
    if [[ ${#required_checks[@]} -gt 0 ]]; then
        local -a _entries=()
        local check
        for check in "${required_checks[@]}"; do
            _entries+=("{\"context\":\"$check\",\"integration_id\":$actions_app_id}")
        done
        local IFS=','
        _status_checks_json="[${_entries[*]}]"
    fi

    execute_with_retry --quiet --classify gh_failure \
        gh api -X "$_method" "$_endpoint" -H "Accept: application/vnd.github+json" \
        --input - >"$noise_sink" << JSON
{
    "name": "$branch_protection_rs_name",
    "target": "branch",
    "enforcement": "active",
    "conditions": {
        "ref_name": {
            "include": ["refs/heads/$default_branch"],
            "exclude": []
        }
    },
    "bypass_actors": [
        {
            "actor_id": $admin_role_id,
            "actor_type": "RepositoryRole",
            "bypass_mode": "always"
        }
    ],
    "rules": [
        {
            "type": "deletion"
        },
        {
            "type": "non_fast_forward"
        },
        {
            "type": "pull_request",
            "parameters": {
                "allowed_merge_methods": [
                    "rebase"
                ],
                "dismiss_stale_reviews_on_push": true,
                "required_approving_review_count": 0,
                "required_reviewers": [],
                "require_code_owner_review": false,
                "require_last_push_approval": false,
                "required_review_thread_resolution": true
            }
        },
        {
            "type": "required_status_checks",
            "parameters": {
                "do_not_enforce_on_create": true,
                "strict_required_status_checks_policy": true,
                "required_status_checks": $_status_checks_json
            }
        },
        {
            "type": "required_linear_history"
        }
    ]
}
JSON

    initialize_branch_protection_rs_id
}

#-----------------------------------------------------------------------------------------------
# @description Resolves the numeric ID of the branch-protection ruleset named `$branch_protection_rs_name` via the
# GitHub API and stores it in `branch_protection_rs_id`, also deriving and freezing `path_branch_protection_ruleset`. If
# `branch_protection_rs_id` is already set (> 0), returns immediately without re-querying the API.
#
# Notes:
#   - This is a precondition check on global/environment state (`branch_protection_rs_name`, `path_rulesets` -- the
#     latter set by `initialize_gh_paths()`), not on call arguments -- it takes no arguments.
#   - Unlike the other precondition-check functions in this file, when the ruleset genuinely does not exist yet, this
#     function returns the generic `1`, not `$err_logic_error` -- callers use this as a "ruleset not found yet"
#     sentinel (see `setup-repo.sh`'s `initialize_branch_protection_rs_id || true` and `configure_branch_protection()`'s
#     success/failure branch below), not as an argument or logic error.
#
# @exitcode success=0: `branch_protection_rs_id` and `path_branch_protection_ruleset` set and frozen.
# @exitcode failure=1: The ruleset does not exist yet.
# @exitcode err_*: The GitHub API call failed (the vm2 code from `gh_failure`, e.g. `err_access_denied`); not reported.
#-----------------------------------------------------------------------------------------------
function initialize_branch_protection_rs_id()
{
    [[ -n $branch_protection_rs_name ]]                                         || bug "$err_logic_error" "${FUNCNAME[0]}() requires the variable 'branch_protection_rs_name' to be set."
    [[ -n $path_rulesets ]]                                                     || bug "$err_logic_error" "${FUNCNAME[0]}() requires the variable 'path_rulesets' to be set: call initialize_gh_paths() first."
                                                                                exit_if_has_bugs

    # branch_protection_rs_id is not 0 - already initialized
    (( branch_protection_rs_id <= 0 ))                                          || return "$success"

    # try to get the branch_protection_rs_id
    branch_protection_rs_id=$(execute_with_retry --query --classify gh_failure \
                                gh api --paginate "$path_rulesets" -q "$jq_ruleset_id" 2>"$noise_sink") \
                                                                                || return "$?"

    if (( branch_protection_rs_id > 0 )); then
        trace "Initialized main protection ruleset ID: $branch_protection_rs_id"

        path_branch_protection_ruleset="$path_rulesets/$branch_protection_rs_id"

        # `readonly` (a POSIX special builtin), not `declare -r`: this runs inside a function
        # body, and `declare -r` without `-g` only freezes a function-local shadow, leaving the
        # real globals unprotected.
        readonly branch_protection_rs_id
        readonly path_branch_protection_ruleset
        return "$success"
    else
        trace "Failed to initialize main protection ruleset ID."
        return "$failure"
    fi
}
