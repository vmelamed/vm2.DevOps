# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# length-review: keep together -- low level helpers and primitives

declare -x script_name
declare -x lib_dir

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x err_invalid_arguments
declare -x err_argument_value
declare -x err_missing_argument
declare -x err_tool_error
declare -x err_not_found
declare -x err_logic_error
declare -x err_invalid_nameref

# vm2 core lib constants
declare -x secret_placeholder
declare -x default_repo_owner

# vm2 core lib variables
declare -x noise_sink

# this scripts constants
declare -xri admin_role_id=5

# this scripts variables
declare -x repo_name
declare -x repo
declare -x default_branch
declare -x branch_protection_rs_name
declare -x nuget_server

declare -x gh_apps_with_secrets
declare -x default_nuget_server

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
declare -x path_branch_protection_ruleset

declare -x jq_entries
declare -x jq_secrets
declare -x jq_secret_names
declare -x jq_vars
declare -x jq_ruleset_id
declare -x jq_ruleset_rules
declare -x jq_status_checks

#-----------------------------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------------------------
function resolve_github_app_ids()
{
    # Resolve the GitHub Actions app ID dynamically via the API.
    # Used to pin required status checks to GitHub Actions specifically.
    # this function cannot be called before initialize_gh_paths() because the latter relies on the actions_app_id variable being set - circular dependency
    actions_app_id=$(execute_with_retry --query --classify gh_failure \
                            gh api --paginate apps/github-actions \
                            --jq '.id' 2>"$noise_sink")                         || error "$err_tool_error" "Failed to resolve the app ID of GitHub Actions."
    trace "GitHub Actions app ID: $actions_app_id"
    [[ "$actions_app_id" == "15368" ]]                                          || warning "Unexpected GitHub Actions app ID: $actions_app_id (expected 15368). Required status check matching may not work correctly."

    dependabot_app_id=$(execute_with_retry --query --classify gh_failure \
                            gh api --paginate apps/dependabot \
                            --jq '.id' 2>"$noise_sink")                         || error "$err_tool_error" "Failed to resolve the app ID of Dependabot."
    trace "Dependabot app ID: $dependabot_app_id"
    [[ "$dependabot_app_id" == "29110" ]]                                       || warning "Unexpected Dependabot app ID: $dependabot_app_id (expected 29110). Required status check matching may not work correctly for Dependabot."

    codespaces_app_id=$(execute_with_retry --query --classify gh_failure \
                            gh api --paginate apps/codespaces \
                            --jq '.id' 2>"$noise_sink")                         || error "$err_tool_error" "Failed to resolve the app ID of Codespaces."
    trace "Codespaces app ID: $codespaces_app_id"
    [[ "$codespaces_app_id" == "231849" ]]                                      || warning "Unexpected Codespaces app ID: $codespaces_app_id (expected 231849). Required status check matching may not work correctly for Codespaces."
                                                                                exit_if_has_errors

    # `readonly` (a POSIX special builtin), not `declare -r`: this runs inside a function body,
    # and `declare -r` without `-g` only freezes a function-local shadow, leaving the real
    # globals unprotected.
    readonly actions_app_id dependabot_app_id codespaces_app_id
}

#-----------------------------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------------------------
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
    _gate_job=$(yq -r '.jobs | keys[] | select(test("postrun|ci-gate"))' "$ci_yaml" | head -n 1) \
                                                                                || error "$err_tool_error" "Failed to parse the gate job from '$ci_yaml'."

    if [[ -n "$_gate_job" ]]; then
        _gate_name=$(yq -r ".jobs.${_gate_job:-postrun-ci}.name" "$ci_yaml")    || error "$err_tool_error" "Failed to parse the name of the gate job from '$ci_yaml'."

        # The canonical CI.yaml gives the gate job a different name in the push run, so that only the pull_request run
        # reports the required check: name: ${{ github.event_name == 'push' && 'Postrun-CI (push)' || 'Postrun-CI' }}.
        # Such a name MUST be one expression that makes up the whole name and ends with "|| '<name>'": that literal is the
        # check the ruleset requires. Registering the expression itself would require a check that no run ever reports,
        # and no PR could be merged. A literal prefix or suffix outside the expression ('Gate ${{ … }}') changes the
        # evaluated name, so the literal alone would be the wrong check: that is an error too, not a guess.
        local _gate_name_rex="^[[:space:]]*\\\$\{\{.*\|\|[[:space:]]*'([^']+)'[[:space:]]*\}\}[[:space:]]*$"
        # shellcheck disable=SC2016 # '${{' is the literal start of a GitHub Actions expression, not a shell expansion
        if [[ $_gate_name == *'${{'* ]]; then
            if [[ $_gate_name =~ $_gate_name_rex ]]; then
                _gate_name=${BASH_REMATCH[1]}
            else
                                                                                   error "$err_argument_value" "The name of the gate job '$_gate_job' in CI.yaml must be a single expression ending with \"|| '<check name>'\", with nothing before or after it: $_gate_name"
                                                                                   _gate_name=''
            fi
        fi

        [[ -z $_gate_name ]] || required_checks+=("$_gate_name")
    fi
                                                                                exit_if_has_errors

    # `readonly` (a POSIX special builtin), not `declare -r`: this runs inside a function body,
    # and `declare -r` without `-g` only freezes a function-local shadow, leaving the real
    # global unprotected (doubly so for `-a` here: arrays cannot be exported at all, so `-x`
    # was already a no-op on this line).
    readonly required_checks

    trace "Required checks: ${required_checks[*]}"
}

#-----------------------------------------------------------------------------------------------
# @description Computes and freezes the `path_*` GitHub API endpoint variables (`path_repo`, `path_permissions`,
# `path_rulesets`, `path_actions_secrets`, `path_dependabot_secrets`, `path_vars`) from the already-resolved `repo`
# and `branch_protection_rs_name` globals.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#   - This is a precondition check on global/environment state set by earlier setup steps, not on the function's
#     own call arguments -- it takes no arguments. Per the accumulate-then-gate pattern used for preconditions in
#     this codebase, the final `return` uses `$err_logic_error`, the code that actually describes the failure, not
#     `$err_invalid_arguments`.
#
# @exitcode success=0: All `path_*` variables set and frozen read-only.
#-----------------------------------------------------------------------------------------------
function initialize_gh_paths()
{
    [[ -n $repo ]]                                                              || bug "$err_logic_error" "${FUNCNAME[0]}() requires the variable 'repo' to be set."
    [[ -n $branch_protection_rs_name ]]                                           || bug "$err_logic_error" "${FUNCNAME[0]}() requires the variable 'branch_protection_rs_name' to be set."
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

#-----------------------------------------------------------------------------------------------
# @description Builds and freezes the `jq_*` query strings (`jq_entries`, `jq_secrets`, `jq_secret_names`,
# `jq_vars`, `jq_ruleset_id`, `jq_status_checks`, `jq_ruleset_rules`) used throughout `setup-repo.sh` and
# `setup-repo.audit.sh` to extract and compare data from GitHub API JSON responses. The queries embed
# `$branch_protection_rs_name`, `$actions_app_id`, `$admin_role_id`, and `${#required_checks[@]}` at build time.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#   - This is a precondition check on global/environment state (`branch_protection_rs_name`, `actions_app_id`,
#     `admin_role_id`), not on call arguments -- it takes no arguments. The final `return` uses `$err_logic_error`
#     per the precondition-check pattern in this codebase.
#
# @exitcode success=0: All `jq_*` variables set and frozen read-only.
#-----------------------------------------------------------------------------------------------
# shellcheck disable=SC2089 # Quotes/backslashes will be treated literally. Use an array.
# shellcheck disable=SC2090 # Quotes/backslashes in this variable will not be respected.
function initialize_jq_queries()
{
    [[ -n $branch_protection_rs_name ]]                                           || bug "$err_logic_error" "${FUNCNAME[0]}() requires the variable 'branch_protection_rs_name' to be set."
    (( actions_app_id > 0 ))                                                    || bug "$err_logic_error" "${FUNCNAME[0]}() requires the variable 'actions_app_id' to be set to a valid ID."
    (( admin_role_id > 0 ))                                                     || bug "$err_logic_error" "${FUNCNAME[0]}() requires the variable 'admin_role_id' to be set to a valid ID."
                                                                                exit_if_has_bugs

    jq_entries='to_entries[] | "\(.key)=\(.value)"'
    jq_secrets='.secrets[] | "\(.name)='"$secret_placeholder"'"'
    jq_secret_names='.secrets[] | .name'
    jq_vars='.variables[] | "\(.name)=\(.value)"'
    jq_ruleset_id='.[] | select(.name == "'"$branch_protection_rs_name"'") | .id // empty'
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

#-----------------------------------------------------------------------------------------------
# @description Retrieves the repository's `NUGET_SERVER` variable into the global variable
#   $nuget_server, or $default_nuget_server when the repository is not known yet, or the variable
#   does not exist (HTTP 404: the repository itself is known to exist and to be readable here).
#
# @exitcode success=0: $nuget_server is set.
# @exitcode err_*: The variable could not be read (the vm2 code from `gh_failure`);
#   reported as an error.
#-----------------------------------------------------------------------------------------------
function get_current_nuget_server()
{
    if [[ -z $repo_name ]]; then
        nuget_server="$default_nuget_server"
        return "$success"
    fi

    local _repo_owner=${repo_owner:-$default_repo_owner}
    local -i _rc=$success
    local _result=''

    # stderr is discarded: an absent variable is an expected 404, and 'gh' would print it (--trace shows it)
    _result=$(execute_with_retry --query --classify gh_failure \
                  gh api "repos/$_repo_owner/$repo_name/actions/variables/NUGET_SERVER" --jq .value 2>"$noise_sink") \
                                                                                || _rc=$?
    (( _rc == success || _rc == err_not_found ))                                ||  {
                                                                                        with_error _rc "$_rc" "Failed to read the variable 'NUGET_SERVER' of the repository '$_repo_owner/$repo_name'."
                                                                                        return "$_rc"
                                                                                    }
    (( _rc == success )) && nuget_server=$_result || nuget_server=$default_nuget_server
    return "$success"
}

#-----------------------------------------------------------------------------------------------
# @description Gets the value of a single GitHub Actions repository variable via `gh api`.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string The name of the GitHub Actions variable whose value is requested
# @arg $2 string name of a Bash variable to receive the value of the GitHub Actions variable $1.
#
# @exitcode success=0: got it
# @exitcode err_tool_error=66: The `gh` call failed (logged as a warning, then propagated).
# @exitcode err_not_found=9: The requested GitHub Actions variable is not set.
#-----------------------------------------------------------------------------------------------
function get_var()
{
    (( $# == 2 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                "  - the name of the GitHub Actions variable whose value is to be requested" \
                                                                                                                "  - the variable value."
    [[ ! -v 1 || -n $1 ]]                                                       || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the name of the GitHub Actions variable whose value is to be requested, to be non-empty (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || { is_variable "$2" && is_mutable "$2"; }                    || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to name a writable variable for the value of the GitHub Actions variable (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    local _name="$1"
    local -n __value="$2"
    local -i _rc=$success

    # read the variable's value from GitHub
    __value=$(execute_with_retry --query --classify gh_failure \
                gh api "repos/$repo/actions/variables/$_name" --jq '.value' 2>"$noise_sink") \
                                                                                ||  {
                                                                                        _rc=$?
                                                                                        warning "Failed to get the value of the variable $_name. Run the script with '--verbose' to see more details and troubleshoot."
                                                                                    }
    (( _rc != success )) || [[ -n $__value ]]                                   ||  {
                                                                                        _rc=$err_not_found
                                                                                        warning "The variable $_name is not set."
                                                                                    }

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Creates or updates a single GitHub Actions repository variable via `gh variable set`.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string Name of the variable to create (if it does not exist).
# @arg $2 string Value to assign to the variable.
#
# @exitcode success=0: Variable set successfully.
# @exitcode err_tool_error=66: The `gh` call failed (logged as a warning, then propagated).
#-----------------------------------------------------------------------------------------------
function set_var()
{
    (( $# == 2 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                "  - the variable name" \
                                                                                                                "  - the variable value"
    [[ ! -v 1 || -n $1 ]]                                                       || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the variable name, to be non-empty (provided '${1-<missing>}')."
    [[ -v 2 ]]                                                                  || bug "$err_missing_argument" "${FUNCNAME[0]}() requires argument 2, the variable value, to be present (it may be empty)."
                                                                                exit_if_has_bugs

    local _name="$1"
    local _value="$2"
    local -i _rc=$success

    # create and/or set the secret value on GitHub
    execute_with_retry --quiet --classify gh_failure \
        gh variable set "$_name" --body "$_value" -R "$repo"                    ||  {
                                                                                        _rc=$?
                                                                                        warning "Failed to create or assign a value to the variable $_name. Run the script with '--verbose' to see more details and troubleshoot."
                                                                                    }

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Deletes a single GitHub Actions repository variable via `gh variable delete`.
#
# @arg $1 string Name of the variable to delete.
#
# @exitcode success=0: Variable deleted successfully.
# @exitcode err_tool_error=66: The `gh` call failed (logged as a warning, then propagated).
#-----------------------------------------------------------------------------------------------
function delete_var()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the variable name."
    [[ ! -v 1 || -n $1 ]]                                                       || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the variable name, to be non-empty (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs

    local _name="$1"

    trace "gh variable delete $_name --repo $repo"

    local -i _rc=$success

    # delete the variable on GitHub
    execute_with_retry --quiet --classify gh_failure \
        gh variable delete "$_name" --repo "$repo"                              || {
                                                                                        _rc=$?
                                                                                        warning "Failed to delete variable $_name. Run the script with '--verbose' to see more details and troubleshoot." -ec "$_rc"
                                                                                    }

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
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
# @exitcode err_tool_error=66: The `gh` call failed (logged as a warning, then propagated).
#-----------------------------------------------------------------------------------------------
function set_secret()
{
    (( $# == 3 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 3 arguments (provided $#):" \
                                                                                                                "  - the secret name" \
                                                                                                                "  - the secret value" \
                                                                                                                "  - the application"
    [[ ! -v 1 || -n $1 ]]                                                       || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the secret name, to be non-empty (provided '${1-<missing>}')."
    [[ ! -v 3 ]] || is_in "$3" "${gh_apps_with_secrets[@]}"                     || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 3, the application name, to be one of: ${gh_apps_with_secrets[*]} (provided '${3-<missing>}')."
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
    execute_with_retry --quiet --classify gh_failure \
        gh secret set "$_name" --body "$__value" --app "$_app" --repo "$repo"   || _rc=$?

    restore_state _core_state

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    (( _rc == success )) &&
        trace "Secret '$_name' was set successfully." ||
        warning "Failed to set secret $_name for ${_app^}. Run the script with '--verbose' to see more details and troubleshoot." -ec "$_rc"

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
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
# @exitcode err_tool_error=66: The `gh` call failed (logged as a warning, then propagated).
#-----------------------------------------------------------------------------------------------
function delete_secret()
{
    (( $# == 2 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                "  - the secret name" \
                                                                                                                "  - the application"
    [[ ! -v 1 || -n $1 ]]                                                       || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the secret name, to be non-empty (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || is_in "$2" "${gh_apps_with_secrets[@]}"                     || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the application name, to be one of: ${gh_apps_with_secrets[*]} (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    local _name="$1"
    local _app="$2"

    # we have a new legitimate value for the secret that we need to create and/or set:
    trace "gh secret delete $_name --app $_app --repo $repo"

    local -i _rc=$success

    # delete the secret value on GitHub
    execute_with_retry --quiet --classify gh_failure \
        gh secret delete "$_name" --app "$_app" --repo "$repo"                  ||  {
                                                                                        _rc=$?
                                                                                        warning "Failed to delete secret $_name for ${_app^}. Run the script with '--verbose' to see more details and troubleshoot." -ec "$_rc"
                                                                                    }

    return "$_rc"
}
