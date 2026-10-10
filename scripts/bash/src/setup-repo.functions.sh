# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x _ignore
declare -x script_name
declare -x lib_dir

declare -xri success
declare -xri failure
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_tool_error
declare -xri err_logic_error

declare -xr question_em

declare -xri admin_role_id=5

declare -xr secret_str
declare -xr secret_placeholder

declare -x repo_name
declare -x repo
declare -x branch
declare -x interactive_vars
declare -x interactive_secrets
declare -x main_protection_rs_name
declare -x purge_vars
declare -x purge_secrets
declare -x nuget_server

declare -xrA default_repo_settings
declare -xrA default_repo_permissions

declare -xra gh_apps_with_vars
declare -xra gh_apps_with_secrets
declare -xr default_nuget_server

declare -x ci_yaml

declare -xi actions_app_id=0
declare -xi dependabot_app_id=0
declare -xi codespaces_app_id=0

declare -xa required_checks=()

declare -x path_repo
declare -x path_actions_secrets
declare -x path_dependabot_secrets
declare -x path_permissions
declare -x path_vars
declare -x path_rulesets
declare -x path_main_protection_ruleset

declare -x jq_entries
declare -x jq_secrets
declare -x jq_secret_names
declare -x jq_vars
declare -x jq_ruleset_id
declare -x jq_ruleset_rules
declare -x jq_status_checks

#---------------------------------------------------------------------------------------------
# @description Resolves the numeric GitHub App IDs for GitHub Actions, Dependabot, and
#   Codespaces via the GitHub API, storing them in `actions_app_id`, `dependabot_app_id`, and
#   `codespaces_app_id`. These IDs are used to pin required status checks and other
#   GitHub-App-scoped settings to GitHub Actions specifically. Each resolved ID is checked
#   against its well-known expected value and a warning is logged if it differs (the vm2
#   GitHub Apps have stable IDs across all repositories, so a mismatch likely signals an API
#   change worth investigating).
#
# Notes:
#   - This function must run before `initialize_gh_paths()` and `initialize_jq_queries()`,
#     since the latter rely on `actions_app_id` already being set -- calling it after would be
#     a circular dependency.
#
# @exitcode success=0: All three app IDs resolved successfully.
# @exitcode (via exit_if_has_errors) Exits the process if any of the three API calls failed.
#---------------------------------------------------------------------------------------------
function resolve_github_app_ids()
{
    # Resolve the GitHub Actions app ID dynamically via the API.
    # Used to pin required status checks to GitHub Actions specifically.
    # this function cannot be called before initialize_gh_paths() because the latter relies on the actions_app_id variable being set - circular dependency
    actions_app_id=$(gh api --paginate apps/github-actions --jq '.id' 2>"$_ignore") || error -ec "$err_tool_error" "${FUNCNAME[0]}() Failed to resolve GitHub Actions app ID from the API."
    trace "GitHub Actions app ID: $actions_app_id"
    [[ "$actions_app_id" == "15368" ]]                                              || warning "Unexpected GitHub Actions app ID: $actions_app_id (expected 15368). Required status check matching may not work correctly."

    dependabot_app_id=$(gh api --paginate apps/dependabot --jq '.id' 2>"$_ignore")  || error -ec "$err_tool_error" "${FUNCNAME[0]}() Failed to resolve Dependabot app ID from the API."
    trace "Dependabot app ID: $dependabot_app_id"
    [[ "$dependabot_app_id" == "29110" ]]                                           || warning "Unexpected Dependabot app ID: $dependabot_app_id (expected 29110). Required status check matching may not work correctly for Dependabot."

    codespaces_app_id=$(gh api --paginate apps/codespaces --jq '.id' 2>"$_ignore")  || error -ec "$err_tool_error" "${FUNCNAME[0]}() Failed to resolve Codespaces app ID from the API."
    trace "Codespaces app ID: $codespaces_app_id"
    [[ "$codespaces_app_id" == "231849" ]]                                          || warning "Unexpected Codespaces app ID: $codespaces_app_id (expected 231849). Required status check matching may not work correctly for Codespaces."
    exit_if_has_errors

    # `readonly` (a POSIX special builtin), not `declare -r`: this runs inside a function body,
    # and `declare -r` without `-g` only freezes a function-local shadow, leaving the real
    # globals unprotected.
    readonly actions_app_id dependabot_app_id codespaces_app_id
}

#---------------------------------------------------------------------------------------------
# @description Determines the single, stable "gate job" check name from the target repository's `CI.yaml` (looking
# for a job whose key matches `postrun|ci-gate`, preferring `postrun-ci` if present) and appends it to the
# `required_checks` array, then freezes the array read-only. See the inline comment below for why a gate job
# (rather than the individual matrix job names) is what gets pinned as a required status check.
#
# Notes:
#   - If the target repository's `CI.yaml` has no job matching `postrun|ci-gate`, this is treated as a legitimate
#     configuration (not every consumer repo is required to have a gate job yet): `required_checks` is left empty
#     and frozen as such, silently -- no error or warning is raised.
#
# @exitcode success=0: `required_checks` populated (or left empty, if no gate job was found) and frozen.
# @exitcode (via exit_if_has_errors) Exits the process if a gate job was found but 'yq' failed to parse its `name:`
#   property from `$ci_yaml`.
#---------------------------------------------------------------------------------------------
function list_required_checks()
{
    # With reusable workflows + matrix strategies, GitHub Actions produces check names that include the workflow prefix, matrix
    # params, inner job names, and event suffixes — making them impossible to predict for branch protection rules. Instead, each
    # CI.yaml has a lightweight gate job that depends on all other jobs and reports a single, stable check name.
    #
    # The GitHub UI decorates check names as "Workflow / JobName (event)" but the check-runs API returns bare names and ruleset
    # matching uses the bare check-run name field. So we extract just the gate job's `name:` property from CI.yaml.
    local _gate_job
    local _gate_name

    # Find the gate job: look for postrun-ci first, fall back to ci-gate
    _gate_job=$(yq -r '.jobs | keys[] | select(test("postrun|ci-gate"))' "$ci_yaml" | head -n 1) || error -ec "$err_tool_error" "${FUNCNAME[0]}() Failed to parse gate job from CI.yaml."

    if [[ -n "$_gate_job" ]]; then
        _gate_name=$(yq -r ".jobs.${_gate_job:-postrun-ci}.name" "$ci_yaml")                     || error -ec "$err_tool_error" "${FUNCNAME[0]}() Failed to parse gate job name from CI.yaml."
        required_checks+=("$_gate_name")
    fi
    exit_if_has_errors

    # `readonly` (a POSIX special builtin), not `declare -r`: this runs inside a function body,
    # and `declare -r` without `-g` only freezes a function-local shadow, leaving the real
    # global unprotected (doubly so for `-a` here: arrays cannot be exported at all, so `-x`
    # was already a no-op on this line).
    readonly required_checks

    trace "Required checks: ${required_checks[*]}"
}

#---------------------------------------------------------------------------------------------
# @description Computes and freezes the `path_*` GitHub API endpoint variables (`path_repo`, `path_permissions`,
# `path_rulesets`, `path_actions_secrets`, `path_dependabot_secrets`, `path_vars`) from the already-resolved `repo`
# and `main_protection_rs_name` globals.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#   - This is a precondition check on global/environment state set by earlier setup steps, not on the function's
#     own call arguments -- it takes no arguments. Per the accumulate-then-gate pattern used for preconditions in
#     this codebase, the final `return` uses `$err_logic_error`, the code that actually describes the failure, not
#     `$err_invalid_arguments`.
#
# @exitcode success=0: All `path_*` variables set and frozen read-only.
#---------------------------------------------------------------------------------------------
function initialize_gh_paths()
{
    [[ -n $repo ]]                    || bug -ec "$err_logic_error" "${FUNCNAME[0]}() The 'repo' variable is not set. Cannot initialize GitHub paths."
    [[ -n $main_protection_rs_name ]] || bug -ec "$err_logic_error" "${FUNCNAME[0]}() The 'main_protection_rs_name' variable is not set. Cannot initialize GitHub paths."
    exit_if_has_bugs

    path_repo="repos/$repo"

    path_permissions="$path_repo/actions/permissions/workflow"
    path_rulesets="$path_repo/rulesets"

    path_actions_secrets="$path_repo/actions/secrets"
    path_dependabot_secrets="$path_repo/dependabot/secrets"

    path_vars="$path_repo/actions/variables"

    # freeze the paths now -- `readonly` (a POSIX special builtin), not `declare -r`: this runs
    # inside a function body, and `declare -r` without `-g` only freezes a function-local
    # shadow, leaving the real globals unprotected.
    readonly path_repo

    readonly path_permissions
    readonly path_rulesets

    readonly path_actions_secrets
    readonly path_dependabot_secrets

    readonly path_vars
}

#---------------------------------------------------------------------------------------------
# @description Builds and freezes the `jq_*` query strings (`jq_entries`, `jq_secrets`, `jq_secret_names`,
# `jq_vars`, `jq_ruleset_id`, `jq_status_checks`, `jq_ruleset_rules`) used throughout `setup-repo.sh` and
# `setup-repo.audit.sh` to extract and compare data from GitHub API JSON responses. The queries embed
# `$main_protection_rs_name`, `$actions_app_id`, `$admin_role_id`, and `${#required_checks[@]}` at build time.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#   - This is a precondition check on global/environment state (`main_protection_rs_name`, `actions_app_id`,
#     `admin_role_id`), not on call arguments -- it takes no arguments. The final `return` uses `$err_logic_error`
#     per the precondition-check pattern in this codebase.
#
# @exitcode success=0: All `jq_*` variables set and frozen read-only.
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2089 # Quotes/backslashes will be treated literally. Use an array.
# shellcheck disable=SC2090 # Quotes/backslashes in this variable will not be respected.
function initialize_jq_queries()
{
    [[ -n $main_protection_rs_name ]] || bug -ec "$err_logic_error" "${FUNCNAME[0]}() The 'main_protection_rs_name' variable is not set. Cannot initialize jq queries."
    (( actions_app_id > 0 ))          || bug -ec "$err_logic_error" "${FUNCNAME[0]}() The 'actions_app_id' variable is not set or is invalid. Cannot initialize jq queries."
    (( admin_role_id > 0 ))           || bug -ec "$err_logic_error" "${FUNCNAME[0]}() The 'admin_role_id' variable is not set or is invalid. Cannot initialize jq queries."
    exit_if_has_bugs

    jq_entries='to_entries[] | "\(.key)=\(.value)"'
    jq_secrets='.secrets[] | "\(.name)='"$secret_placeholder"'"'
    jq_secret_names='.secrets[] | .name'
    jq_vars='.variables[] | "\(.name)=\(.value)"'
    jq_ruleset_id='.[] | select(.name == "'"$main_protection_rs_name"'") | .id // empty'
    jq_status_checks='.rules[] | select(.type == "required_status_checks") |
                      .parameters.required_status_checks[] | select(.integration_id == '"$actions_app_id"') | .context'
    jq_ruleset_rules='
def is_present: if any then "present" else "missing" end;
def count_rules(type): [.rules[] | select(.type == type)] | is_present;
def count_pr_param(check): [.rules[] | select(.type == "pull_request" and check)] | is_present;
def count_pr_checks_param(check): [.rules[] | select(.type == "required_status_checks" and check)] | is_present;

{
    enforcement:                            .enforcement // "disabled",
    repository_admin_bypass:                [.bypass_actors[] | select(.actor_id == '"$admin_role_id"' and
                                                                       .actor_type == "RepositoryRole" and
                                                                       .bypass_mode == "always")] | is_present,
    deletion:                               count_rules("deletion"),
    required_linear_history:                count_rules("required_linear_history"),
    pull_request:                           count_rules("pull_request"),
    required_approving_review_count:        count_pr_param(.parameters.required_approving_review_count == 0),
    dismiss_stale_reviews_on_push:          count_pr_param(.parameters.dismiss_stale_reviews_on_push),
    require_code_owner_review:              count_pr_param(.parameters.require_code_owner_review | not),
    require_last_push_approval:             count_pr_param(.parameters.require_last_push_approval | not),
    required_review_thread_resolution:      count_pr_param(.parameters.required_review_thread_resolution),
    required_reviewers:                     count_pr_param((.parameters.required_reviewers | length == 0)),
    allowed_merge_methods:                  count_pr_param((.parameters.allowed_merge_methods | length == 1) and
                                                            .parameters.allowed_merge_methods[0] == "rebase"),
    do_not_enforce_on_create:               count_pr_checks_param(.parameters.do_not_enforce_on_create == true),
    strict_required_status_checks_policy:   count_pr_checks_param(.parameters.strict_required_status_checks_policy == true),
    required_status_checks:                 [.rules[] | select(.type == "required_status_checks") |
                                                                            .parameters.required_status_checks[] |
                                                                            select(.integration_id == '"$actions_app_id"') |
                                                                            length >= '"${#required_checks[@]}"' ] | is_present,
    non_fast_forward:                       count_rules("non_fast_forward"),
} | to_entries[] | "\(.key)=\(.value)"'

    # freeze the queries now -- `readonly` (a POSIX special builtin), not `declare -r`: this
    # runs inside a function body, and `declare -r` without `-g` only freezes a function-local
    # shadow, leaving the real globals unprotected.
    readonly jq_entries
    readonly jq_secrets
    readonly jq_secret_names
    readonly jq_vars
    readonly jq_ruleset_id
    readonly jq_ruleset_rules
    readonly jq_status_checks
}

#---------------------------------------------------------------------------------------------
# @description Resolves the numeric ID of the branch-protection ruleset named `$main_protection_rs_name` via the
# GitHub API and stores it in `main_protection_rs_id`, also deriving and freezing `path_main_protection_ruleset`. If
# `main_protection_rs_id` is already set (> 0), returns immediately without re-querying the API.
#
# Notes:
#   - This is a precondition check on global/environment state (`main_protection_rs_name`, `path_rulesets` -- the
#     latter set by `initialize_gh_paths()`), not on call arguments -- it takes no arguments.
#   - Unlike the other precondition-check functions in this file, when the ruleset genuinely does not exist yet (or
#     the API call fails), this function returns the generic `1`, not `$err_logic_error` -- callers use this as a
#     "ruleset not found yet" sentinel (see `setup-repo.sh`'s `initialize_main_protection_rs_id || true` and
#     `configure_branch_protection()`'s success/failure branch below), not as an argument or logic error.
#
# @exitcode success=0: `main_protection_rs_id` and `path_main_protection_ruleset` set and frozen.
# @exitcode failure=1: The ruleset does not exist yet, or the GitHub API call failed.
#---------------------------------------------------------------------------------------------
function initialize_main_protection_rs_id()
{
    [[ -n $main_protection_rs_name ]] || bug -ec "$err_logic_error" "${FUNCNAME[0]}() The 'main_protection_rs_name' variable is not set. Cannot initialize main protection ruleset ID."
    [[ -n $path_rulesets ]]           || bug -ec "$err_logic_error" "${FUNCNAME[0]}() The 'path_rulesets' variable is not set. Run initialize_gh_paths() first. Cannot initialize main protection ruleset ID."
    exit_if_has_bugs

    # main_protection_rs_id is not 0 - already initialized
    (( main_protection_rs_id > 0 )) && return "$success"

    # try to get the main_protection_rs_id
    main_protection_rs_id=$(execute_gh_api_with_retry 3 2 --paginate "$path_rulesets" -q "$jq_ruleset_id") ||
        return "$failure"

    if (( main_protection_rs_id > 0 )); then
        trace "Initialized main protection ruleset ID: $main_protection_rs_id"

        path_main_protection_ruleset="$path_rulesets/$main_protection_rs_id"

        # `readonly` (a POSIX special builtin), not `declare -r`: this runs inside a function
        # body, and `declare -r` without `-g` only freezes a function-local shadow, leaving the
        # real globals unprotected.
        readonly main_protection_rs_id
        readonly path_main_protection_ruleset
        return "$success"
    else
        trace "Failed to initialize main protection ruleset ID."
        return "$failure"
    fi

}

#---------------------------------------------------------------------------------------------
# @description Retrieves the current NuGet server moniker for the repository and stores it in
#   the global variable $nuget_server.
#
# @exitcode success=0: Always (a failure to retrieve the moniker is logged as a
#   warning, not surfaced as a non-zero exit code).
#---------------------------------------------------------------------------------------------
function get_current_nuget_server()
{
    if [[ -z $repo_name ]]; then
        nuget_server="$default_nuget_server"
        return "$success"
    fi

    local _repo_owner=${repo_owner:-$default_repo_owner}

    read -r nuget_server < <(execute_gh_api_with_retry 3 2 "repos/$_repo_owner/$repo_name/actions/variables/NUGET_SERVER" --jq .value 2> "$_ignore") ||
        nuget_server=$default_nuget_server
}

#---------------------------------------------------------------------------------------------
# @description Fetches the target repository's current settings and PATCHes any that differ
# from `default_repo_settings` via the GitHub API. Booleans are sent as JSON (`-F`), other
# values as strings (`-f`). Settings that already match the expected value are left untouched
# (no-op PATCH avoided when there is nothing to change).
#
# @exitcode success=0: Always (a failed PATCH call is logged as a warning, not
#   surfaced as a non-zero exit code).
#
# @stdout Progress/status messages via `info` ("Configuring repository settings...",
#   "...repository settings configured.").
#---------------------------------------------------------------------------------------------
function configure_default_repo_settings()
{
    info "Configuring repository settings..."

    # get existing repository settings
    local -A _existing
    local _key _value

    while IFS='=' read -r _key _value; do
        _existing["$_key"]="$_value"
    done < <(execute_gh_api_with_retry 3 2 "$path_repo" -q "$jq_entries")

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
        execute_gh_api_with_retry 3 2 true -X PATCH "$path_repo" "${_rs[@]}" &&
            info "...repository settings configured." ||
            warning "Could not configure repository settings. Run the script with '--verbose' to see more details and troubleshoot."
    else
        info "...repository settings configured."
    fi
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function configure_actions_permissions()
{
    info "Configuring Actions workflow permissions..."

    # get existing repository permissions
    local -A _existing
    local _key _value

    while IFS='=' read -r _key _value; do
        _existing["$_key"]="$_value"
    done < <(execute_gh_api_with_retry 3 2 "$path_permissions" -q "$jq_entries")

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
        execute_gh_api_with_retry 3 2 true -X PUT "$path_permissions" -H "Accept: application/vnd.github+json" "${_rs[@]}" &&
            info "...actions workflow permissions configured." ||
            warning "Could not configure Actions workflow permissions. Run the script with '--verbose' to see more details and troubleshoot."
    else
        info "...actions workflow permissions configured."
    fi
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
function configure_variables()
{
    (( $# == 1 ))                                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#):" \
                                                                                          "  - the name of the GitHub application being configured, e.g. actions"
    [[ ! -v 1 ]] || is_in "$1" "${gh_apps_with_vars[@]}" || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the application name, to be one of: ${gh_apps_with_vars[*]} (provided '${1:-<none>}')."
    exit_if_has_bugs

    local _app=${1,,}

    local -A _vars_defaults
    local -a _vars_order
    local -A _vars_validators

    # get the default values for the application's variables based on the current NuGet server
    get_vars_defaults "${_app,,}" _vars_defaults _vars_order _vars_validators

    # Nothing to reconcile and nothing to purge -- skip the API call entirely rather than fetch
    # the app's current secrets just to discover there's nothing to do with them.
    (( ${#_vars_defaults[@]} > 0 )) || $purge_vars || return "$success"

    info "Configuring GitHub ${_app^} variables..."

    # get the currently existing variables from the GitHub repository
    local _var _value
    local -A _current=()

    while IFS='=' read -r _var _value; do
        _current["$_var"]="$_value"
    done < <(execute_gh_api_with_retry 3 2 --paginate "$path_repo/$_app/variables" -q "$jq_vars")

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
        if [[ $_var == "NUGET_SERVER" && -n $_value && "$_value" != "$nuget_server" ]]; then
            nuget_server="$_value"
            get_vars_defaults "$_app" _vars_defaults _vars_order _vars_validators
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

#---------------------------------------------------------------------------------------------
# @description Creates or updates a single GitHub Actions repository variable via `gh variable set`.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string Name of the variable to create (if it does not exist).
# @arg $2 string Value to assign to the variable.
#
# @exitcode success=0: Variable set successfully.
# @exitcode * Whatever `execute_gh_with_retry` returned on failure (logged as a warning, then propagated).
#---------------------------------------------------------------------------------------------
function set_var()
{
    (( $# == 2 ))       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                            "  - the variable name" \
                                                            "  - the variable value."
    [[ -v 1 && -n $1 ]] || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the variable name, to be non-empty (provided '${1:-<none>}')."
    [[ -v 2 ]]          || bug -ec "$err_missing_argument"  "${FUNCNAME[0]}() requires argument 2, the variable value, to be provided."
    exit_if_has_bugs

    local _name="$1"
    local _value="$2"
    local -i _rc=$success

    # create and/or set the secret value on GitHub
    execute_gh_with_retry 3 2 true variable set "$_name" --body "$_value" -R "$repo" || {
        _rc=$?
        warning "Failed to create or assign a value to the variable $_name. Run the script with '--verbose' to see more details and troubleshoot."
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Deletes a single GitHub Actions repository variable via `gh variable delete`.
#
# @arg $1 string Name of the variable to delete.
#
# @exitcode success=0: Variable deleted successfully.
# @exitcode * Whatever `execute_gh_with_retry` returned on failure (logged as a warning, then propagated).
#---------------------------------------------------------------------------------------------
function delete_var()
{
    (( $# == 1 ))         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#):" \
                                                              "  - the variable name"
    [[ ! -v 1 || -n $1 ]] || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the variable name, to be non-empty (provided '${1:-<none>}')."
    exit_if_has_bugs

    local _name="$1"

    trace "gh variable delete $_name --repo $repo"

    local -i _rc=$success

    # delete the variable on GitHub
    execute_gh_with_retry 3 2 true variable delete "$_name" --repo "$repo" || {
        _rc=$?
        warning "Failed to delete variable $_name. Run the script with '--verbose' to see more details and troubleshoot." -ec "$_rc"
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------------------
function configure_secrets()
{
    (( $# == 1 ))                                        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#):" \
                                                                                             "  - the application name"
    [[ ! -v 1 ]] || is_in "$1" "${gh_apps_with_secrets[@]}" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the application name, to be one of: ${gh_apps_with_secrets[*]} (provided '${1:-<none>}')."
    exit_if_has_bugs

    local _app=${1,,}

    local -A _secrets_defaults
    local -a _secrets_order
    local -A _secrets_validators

    # get the default values for the application's secrets based on the current NuGet server
    get_secrets_defaults "$_app" _secrets_defaults _secrets_order _secrets_validators

    # Nothing to reconcile and nothing to purge -- skip the API call entirely rather than fetch
    # the app's current secrets just to discover there's nothing to do with them.
    (( ${#_secrets_defaults[@]} > 0 )) || $purge_secrets || return "$success"

    info "Configuring ${_app^} secrets..."

    local -i _rc=$success
    local _temp=''
    _temp=$(mktemp) || {
        _rc=$err_tool_error
        error -ec "$_rc" "Failed to create a temporary file."
        return "$_rc"
    }

    execute_gh_api_with_retry 3 2 --paginate "$path_repo/$_app/secrets" -q "$jq_secret_names" > "$_temp" || _rc=$?

    local -a _current

    (( _rc != success ))  || readarray -t _current < "$_temp" || _rc=$err_tool_error
    rm -f "$_temp" || true

    (( _rc == success )) || {
        error -ec "$_rc" "  Failed to retrieve the list of secrets for the GitHub application '$_app' in repository '$repo'."
        return "$_rc"
    }

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

#---------------------------------------------------------------------------------------------
# @description Creates or updates a single GitHub repository secret for the given app (currently `actions`,
# `dependabot`, or `codespaces` -- see `gh_apps_with_secrets`) via `gh secret set`. Temporarily suppresses verbose/trace
# output and `set -x` around the actual `gh` call so the secret's plaintext value is never written to logs,
# restoring the previous state afterward regardless of success or failure.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string Name of the secret to set.
# @arg $2 string Plaintext value to set the secret to.
# @arg $3 string GitHub App the secret belongs to; must be one of `gh_apps_with_secrets` (currently `actions`,
#   `dependabot`, `codespaces`).
#
# @exitcode success=0: Secret set successfully.
# @exitcode * Whatever `execute_gh_with_retry` returned on failure (logged as a warning, then propagated).
#---------------------------------------------------------------------------------------------
function set_secret()
{
    (( $# == 3 ))                                           || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly three arguments (provided $#):" \
                                                                                                "  - the secret name" \
                                                                                                "  - the secret value" \
                                                                                                "  - the application"
    [[ ! -v 1 || -n $1 ]]                                   || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the secret name, to be non-empty (provided '${1:-<none>}')."
    [[ ! -v 3 ]] || is_in "$3" "${gh_apps_with_secrets[@]}" || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 3, the application name, to be one of: ${gh_apps_with_secrets[*]} (provided '${3:-<none>}')."
    exit_if_has_bugs

    local _name="$1"
    local _value="$2"
    local _app="$3"

    # we have a new legitimate value for the secret that we need to create and/or set:
    trace "gh secret set $_name --body <secret> --app $_app --repo $repo"

    local -i _rc=$success
    local -A _core_state

    save_state _core_state
    # suppress all tracing to avoid revealing the secret value
    unset_trace_enabled
    is_dry_run && __value=$secret_placeholder || __value=$_value


    # create and/or set the secret value on GitHub
    execute_gh_with_retry 3 2 true secret set "$_name" --body "$__value" --app "$_app" --repo "$repo" || _rc=$?

    restore_state _core_state

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    (( _rc == success )) &&
        trace "Secret '$_name' was set successfully." ||
        warning "Failed to set secret $_name for ${_app^}. Run the script with '--verbose' to see more details and troubleshoot." -ec "$_rc"

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Deletes a GitHub secret for a specified application (currently `actions`, `dependabot`, or
#   `codespaces` -- see `gh_apps_with_secrets`) within the repository via `gh secret delete`. Temporarily suppresses
#   verbose/trace output and `set -x` around the actual `gh` call, restoring the previous state afterward
#   regardless of success or failure.
#
# @arg $1 string Name of the secret to delete.
# @arg $2 string GitHub App the secret belongs to; must be one of `gh_apps_with_secrets` (currently `actions`,
#   `dependabot`, `codespaces`).
#
# @exitcode success=0: The secret was successfully deleted.
# @exitcode * Whatever `execute_gh_with_retry` returned on failure (logged as a warning, then propagated).
#---------------------------------------------------------------------------------------------
function delete_secret()
{
    (( $# == 2 ))                                        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                                                "  - the secret name" \
                                                                                                "  - the application"
    [[ ! -v 1 || -n $1 ]]                                || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the secret name, to be non-empty (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_in "$2" "${gh_apps_with_secrets[@]}" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the application name, to be one of: ${gh_apps_with_secrets[*]} (provided '${2:-<none>}')."
    exit_if_has_bugs

    local _name="$1"
    local _app="$2"

    # we have a new legitimate value for the secret that we need to create and/or set:
    trace "gh secret delete $_name --app $_app --repo $repo"

    local -i _rc=$success

    # delete the secret value on GitHub
    execute_gh_with_retry 3 2 true secret delete "$_name" --app "$_app" --repo "$repo" || {
        _rc=$?
        warning "Failed to delete secret $_name for ${_app^}. Run the script with '--verbose' to see more details and troubleshoot." -ec "$_rc"
    }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Creates (POST) or updates (PUT, if `initialize_main_protection_rs_id` finds one
#   already exists) the GitHub ruleset that protects the default branch: linear history, no
#   force pushes, a required pull request with rebase-only merges, and the required status
#   checks collected in `required_checks`. After the API call, re-runs
#   `initialize_main_protection_rs_id` so `main_protection_rs_id`/`path_main_protection_ruleset`
#   reflect a newly-created ruleset (a no-op if the ruleset already existed and was just
#   updated).
#
# @exitcode success=0: Always (a failed API call from `execute_gh_api_with_retry` is not
#   checked/propagated here).
#
# @stdout Progress/status messages via `info` ("Configuring branch ruleset...", "Updating
#   existing ruleset...", or "Creating new ruleset...").
#---------------------------------------------------------------------------------------------
function configure_branch_protection()
{
    info "Configuring branch ruleset for '$branch'..."

    local _method
    local _endpoint

    # Check if a ruleset named "main protection" already exists
    if initialize_main_protection_rs_id; then
        _method="PUT"
        _endpoint="$path_main_protection_ruleset"
        info "Updating existing ruleset $main_protection_rs_name (id: $main_protection_rs_id)..."
    else
        _method="POST"
        _endpoint="$path_rulesets"
        info "Creating new ruleset $main_protection_rs_name..."
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

    execute_gh_api_with_retry 3 2 true -X "$_method" "$_endpoint" -H "Accept: application/vnd.github+json" \
        --input - >"$_ignore" << JSON
{
    "name": "$main_protection_rs_name",
    "target": "branch",
    "enforcement": "active",
    "conditions": {
        "ref_name": {
            "include": ["refs/heads/$branch"],
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

    initialize_main_protection_rs_id
}
