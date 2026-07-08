# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x _ignore
declare -x script_name
declare -x lib_dir

declare -rxi success
declare -rxi err_invalid_arguments
declare -rxi err_tool_error
declare -rxi err_logic_error

declare -xri admin_role_id

declare -xr secret_str

declare -x repo_name
declare -x owner
declare -x repo
declare -x visibility
declare -x branch
declare -x audit
declare -x interactive_vars
declare -x interactive_secrets
declare -x main_protection_rs_name

declare -xrA default_repo_settings
declare -xra default_repo_settings_order

declare -xrA default_repo_permissions

declare -xrA default_ruleset
declare -xra default_ruleset_order

declare -xra apps_with_secrets

declare -rxA actions_default_vars
declare -rxA actions_var_validators

declare -x ci_yaml
declare -x _ci_yaml

declare -xi actions_app_id
declare -xi dependabot_app_id
declare -xi codespaces_app_id

declare -xa required_checks

declare -xr github_url_regex
declare -xri url_authority
declare -xri url_owner
declare -xri url_name

declare -x path_repo
declare -x path_actions_secrets
declare -x path_dependabot_secrets
declare -x path_agents_secrets
declare -x path_codespaces_secrets
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

declare -xr missing_state
declare -xr present_state
declare -xr undefined_default

#-------------------------------------------------------------------------------
# @description Resolves the numeric GitHub App IDs for GitHub Actions, Dependabot, and Codespaces via the GitHub
# API, storing them in `actions_app_id`, `dependabot_app_id`, and `codespaces_app_id`. These IDs are used to pin
# required status checks and other GitHub-App-scoped settings to GitHub Actions specifically. Each resolved ID is
# checked against its well-known expected value and a warning is logged if it differs (the vm2 GitHub Apps have
# stable IDs across all repositories, so a mismatch likely signals an API change worth investigating).
#
# Notes:
#   - This function must run before `initialize_gh_paths()` and `initialize_jq_queries()`, since the latter rely on
#     `actions_app_id` already being set -- calling it after would be a circular dependency.
#
# @exitcode 0 All three app IDs resolved successfully.
# @exitcode (via exit_if_has_errors) Exits the process if any of the three API calls failed.
#-------------------------------------------------------------------------------
function resolve_github_app_ids()
{
    # Resolve the GitHub Actions app ID dynamically via the API.
    # Used to pin required status checks to GitHub Actions specifically.
    # this function cannot be called before initialize_gh_paths() because the latter relies on the actions_app_id variable being set - circular dependency
    actions_app_id=$(gh api --paginate apps/github-actions --jq '.id' 2>"$_ignore") || error -ec "$err_tool_error" "Failed to resolve GitHub Actions app ID from the API."
    trace "GitHub Actions app ID: $actions_app_id"
    [[ "$actions_app_id" == "15368" ]] || warning "Unexpected GitHub Actions app ID: $actions_app_id (expected 15368). Required status check matching may not work correctly."

    dependabot_app_id=$(gh api --paginate apps/dependabot --jq '.id' 2>"$_ignore") || error -ec "$err_tool_error" "Failed to resolve Dependabot app ID from the API."
    trace "Dependabot app ID: $dependabot_app_id"
    [[ "$dependabot_app_id" == "29110" ]] || warning "Unexpected Dependabot app ID: $dependabot_app_id (expected 29110). Required status check matching may not work correctly for Dependabot."

    codespaces_app_id=$(gh api --paginate apps/codespaces --jq '.id' 2>"$_ignore") || error -ec "$err_tool_error" "Failed to resolve Codespaces app ID from the API."
    trace "Codespaces app ID: $codespaces_app_id"
    [[ "$codespaces_app_id" == "231849" ]] || warning "Unexpected Codespaces app ID: $codespaces_app_id (expected 231849). Required status check matching may not work correctly for Codespaces."

    exit_if_has_errors

    declare -xr actions_app_id dependabot_app_id codespaces_app_id
}

#-------------------------------------------------------------------------------
# @description Determines the single, stable "gate job" check name from the target repository's `CI.yaml` and
# appends it to the `required_checks` array, then freezes the array read-only. See the inline comment below for why
# a gate job (rather than the individual matrix job names) is what gets pinned as a required status check.
#
# @exitcode 0 Success; `required_checks` populated and frozen.
# @exitcode (via exit_if_has_errors) Exits the process if the gate job or its name could not be parsed from
#   `$ci_yaml`.
#-------------------------------------------------------------------------------
function list_required_checks()
{
    # With reusable workflows + matrix strategies, GitHub Actions produces check names that include the workflow prefix, matrix
    # params, inner job names, and event suffixes — making them impossible to predict for branch protection rules. Instead, each
    # CI.yaml has a lightweight gate job that depends on all other jobs and reports a single, stable check name.
    #
    # The GitHub UI decorates check names as "Workflow / JobName (event)" but the check-runs API returns bare names and ruleset
    # matching uses the bare check-run name field. So we extract just the gate job's `name:` property from CI.yaml.
    local gate_job
    local gate_name

    # Find the gate job: look for postrun-ci first, fall back to ci-gate
    gate_job=$(yq -r '.jobs | keys[] | select(test("postrun|ci-gate"))' "$ci_yaml" | head -n 1) || error -ec "$err_tool_error" "Failed to parse gate job from CI.yaml."
    gate_name=$(yq -r ".jobs.${gate_job:-postrun-ci}.name" "$ci_yaml")                          || error -ec "$err_tool_error" "Failed to parse gate job name from CI.yaml."
    exit_if_has_errors

    required_checks+=(
        "$gate_name"
    )

    declare -xra required_checks

    trace "Required checks: ${required_checks[*]}"
}

#-------------------------------------------------------------------------------
# @description Computes and freezes the `path_*` GitHub API endpoint variables (`path_repo`, `path_permissions`,
# `path_rulesets`, `path_actions_secrets`, `path_dependabot_secrets`, `path_vars`) from the already-resolved `repo`
# and `main_protection_rs_name` globals.
#
# Notes:
#   - This is a precondition check on global/environment state set by earlier setup steps, not on the function's
#     own call arguments -- it takes no arguments. Per the accumulate-then-gate pattern used for preconditions in
#     this codebase, the final `return` uses `$err_logic_error`, the code that actually describes the failure, not
#     `$err_invalid_arguments`.
#
# @exitcode 0 Success; all `path_*` variables set and frozen read-only.
# @exitcode 67 `$repo` or `$main_protection_rs_name` is not set (`$err_logic_error`).
#-------------------------------------------------------------------------------
# shellcheck disable=SC2089 # Quotes/backslashes will be treated literally. Use an array.
# shellcheck disable=SC2090 # Quotes/backslashes in this variable will not be respected.
function initialize_gh_paths()
{
    local -i rc="$success"

    [[ -n $repo ]]                    || {
        rc="$err_logic_error"
        error -sd 3 -ec "$rc" "The 'repo' variable is not set. Cannot initialize GitHub paths."
    }
    [[ -n $main_protection_rs_name ]] || {
        rc="$err_logic_error"
        error -sd 3 -ec "$rc" "The 'main_protection_rs_name' variable is not set. Cannot initialize GitHub paths."
    }

    (( rc == success )) || return "$err_logic_error"

    path_repo="repos/$repo"

    path_permissions="$path_repo/actions/permissions/workflow"
    path_rulesets="$path_repo/rulesets"

    path_actions_secrets="$path_repo/actions/secrets"
    path_dependabot_secrets="$path_repo/dependabot/secrets"

    path_vars="$path_repo/actions/variables"

    # freeze the paths now
    declare -xr path_repo

    declare -xr path_permissions
    declare -xr path_rulesets

    declare -xr path_actions_secrets
    declare -xr path_dependabot_secrets

    declare -xr path_vars
}

#-------------------------------------------------------------------------------
# @description Builds and freezes the `jq_*` query strings (`jq_entries`, `jq_secrets`, `jq_secret_names`,
# `jq_vars`, `jq_ruleset_id`, `jq_status_checks`, `jq_ruleset_rules`) used throughout `setup-repo.sh` and
# `setup-repo.audit.sh` to extract and compare data from GitHub API JSON responses. The queries embed
# `$main_protection_rs_name`, `$actions_app_id`, `$admin_role_id`, and `${#required_checks[@]}` at build time.
#
# Notes:
#   - This is a precondition check on global/environment state (`main_protection_rs_name`, `actions_app_id`,
#     `admin_role_id`), not on call arguments -- it takes no arguments. The final `return` uses `$err_logic_error`
#     per the precondition-check pattern in this codebase.
#
# @exitcode 0 Success; all `jq_*` variables set and frozen read-only.
# @exitcode 67 A required precondition variable is unset or invalid (`$err_logic_error`).
#-------------------------------------------------------------------------------
# shellcheck disable=SC2089 # Quotes/backslashes will be treated literally. Use an array.
# shellcheck disable=SC2090 # Quotes/backslashes in this variable will not be respected.
function initialize_jq_queries()
{
    local -i rc="$success"

    [[ -n $main_protection_rs_name ]] || {
        rc="$err_logic_error"
        error -sd 3 -ec "$rc" "The 'main_protection_rs_name' variable is not set. Cannot initialize jq queries."
    }
    (( actions_app_id > 0 ))          || {
        rc="$err_logic_error"
        error -sd 3 -ec "$rc" "The 'actions_app_id' variable is not set or is invalid. Cannot initialize jq queries."
    }
    (( admin_role_id > 0 ))           || {
        rc="$err_logic_error"
        error -sd 3 -ec "$rc" "The 'admin_role_id' variable is not set or is invalid. Cannot initialize jq queries."
    }

    (( rc == success )) || return "$err_logic_error"

    jq_entries='to_entries[] | "\(.key)=\(.value)"'
    jq_secrets='.secrets[] | "\(.name)=<set>"'
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

    # freeze the queries now
    declare -xr jq_entries
    declare -xr jq_secrets
    declare -xr jq_secret_names
    declare -xr jq_vars
    declare -xr jq_ruleset_id
    declare -xr jq_ruleset_rules
    declare -xr jq_status_checks
}

#-------------------------------------------------------------------------------
# @description Resolves the numeric ID of the branch-protection ruleset named `$main_protection_rs_name` via the
# GitHub API and stores it in `main_protection_rs_id`, also deriving and freezing `path_main_protection_ruleset`. If
# `main_protection_rs_id` is already set (> 0), returns immediately without re-querying the API -- callers can call
# this idempotently.
#
# Notes:
#   - This is a precondition check on global/environment state (`main_protection_rs_name`, `path_rulesets` -- the
#     latter set by `initialize_gh_paths()`), not on call arguments -- it takes no arguments.
#   - Unlike the other precondition-check functions in this file, when the ruleset genuinely does not exist yet (or
#     the API call fails), this function returns the generic `1`, not `$err_logic_error` -- callers use this as a
#     "ruleset not found yet" sentinel (see `setup-repo.sh`'s `initialize_main_protection_rs_id || true` and
#     `configure_branch_protection()`'s success/failure branch below), not as an argument or logic error.
#
# @exitcode 0 Success; `main_protection_rs_id` and `path_main_protection_ruleset` set and frozen.
# @exitcode 1 The ruleset does not exist yet, or the GitHub API call failed.
# @exitcode 67 A required precondition variable (`main_protection_rs_name`, `path_rulesets`) is unset
#   (`$err_logic_error`).
#-------------------------------------------------------------------------------
function initialize_main_protection_rs_id()
{
    # main_protection_rs_id is not 0 - already initialized
    (( main_protection_rs_id > 0 )) && return 0

    local -i rc="$success"

    [[ -n $main_protection_rs_name ]] || {
        rc="$err_logic_error"
        error -sd 3 -ec "$rc" "The 'main_protection_rs_name' variable is not set. Cannot initialize main protection ruleset ID."
    }
    [[ -n $path_rulesets ]]           || {
        rc="$err_logic_error"
        error -sd 3 -ec "$rc" "The 'path_rulesets' variable is not set. Run initialize_gh_paths() first. Cannot initialize main protection ruleset ID."
    }

    (( rc == success )) || return "$err_logic_error"

    # try to get the main_protection_rs_id
    main_protection_rs_id=$(execute_gh_api_with_retry 3 2 --paginate "$path_rulesets" -q "$jq_ruleset_id") ||
        return 1

    if (( main_protection_rs_id > 0 )); then
        trace "Initialized main protection ruleset ID: $main_protection_rs_id"

        path_main_protection_ruleset="$path_rulesets/$main_protection_rs_id"

        declare -xir main_protection_rs_id
        declare -xr path_main_protection_ruleset
        return 0
    else
        trace "Failed to initialize main protection ruleset ID."
        return 1
    fi

}

#-------------------------------------------------------------------------------
# @description Fetches the target repository's current settings and PATCHes any that differ from
# `default_repo_settings` via the GitHub API. Booleans are sent as JSON (`-F`), other values as strings (`-f`).
# Settings that already match the expected value are left untouched (no-op PATCH avoided when there is nothing to
# change).
#
# @exitcode 0 Always (a failed PATCH call is logged as a warning, not surfaced as a non-zero exit code).
#
# @stdout Progress/status messages via `info` ("Configuring repository settings...", "...repository settings
#   configured.").
#-------------------------------------------------------------------------------
function configure_default_repo_settings()
{
    info "Configuring repository settings..."

    # get existing repository settings
    local -A existing
    while IFS='=' read -r key value; do
        existing["$key"]="$value"
    done < <(execute_gh_api_with_retry 3 2 "$path_repo" -q "$jq_entries")

    local -a rs=()
    local actual
    local expected
    for key in "${!default_repo_settings[@]}"; do
        [[ -n ${existing[$key]+_} ]] && actual="${existing[$key]}" || actual=""
        expected="${default_repo_settings[$key]}"
        if [[ "$actual" != "$expected" ]]; then
            # Use -F for booleans to send as JSON instead of strings
            if is_boolean "$expected"; then
                rs+=("-F" "$key=$expected")
            else
                rs+=("-f" "$key=$expected")
            fi
            trace "Setting repository setting: $key=$expected"
        else
            trace "Repository setting is already set: $key=$actual, skipping."
        fi
    done

    if [[ ${#rs[@]} -gt 0 ]]; then
        execute_gh_api_with_retry 3 2 true -X PATCH "$path_repo" "${rs[@]}" &&
        info "...repository settings configured." ||
        warning "Could not configure repository settings. Run the script with '--verbose' to see more details and troubleshoot."
    else
        info "...repository settings configured."
    fi
}

#-------------------------------------------------------------------------------
# @description Sets the target repository's Actions workflow permissions via the GitHub API to match
# `default_repo_permissions`. Unlike `configure_default_repo_settings()`, this always includes every key from
# `default_repo_permissions` in the PUT request body regardless of whether the current value already matches --
# the permissions endpoint is a full-replace PUT, not a partial PATCH, so there is no per-key skip optimization
# here. Booleans are sent as JSON (`-F`), other values as strings (`-f`).
#
# @exitcode 0 Always (a failed PUT call is logged as a warning, not surfaced as a non-zero exit code).
#
# @stdout Progress/status messages via `info` ("Configuring Actions workflow permissions...", "...actions workflow
#   permissions configured.").
#-------------------------------------------------------------------------------
function configure_actions_permissions()
{
    info "Configuring Actions workflow permissions..."

    # get existing repository permissions
    local -A existing
    while IFS='=' read -r key value; do
        existing["$key"]="$value"
    done < <(execute_gh_api_with_retry 3 2 "$path_permissions" -q "$jq_entries")

    local -a rs=()
    local actual
    local expected
    for key in "${!default_repo_permissions[@]}"; do
        [[ -n ${existing[$key]+_} ]] && actual="${existing[$key]}" || actual=""
        expected="${default_repo_permissions[$key]}"

        # Use -F for booleans to send as JSON instead of strings
        if is_boolean "$expected"; then
            rs+=("-F" "$key=$expected")
        else
            rs+=("-f" "$key=$expected")
        fi
        trace "Setting repository setting: $key=$expected"
    done

    if [[ ${#rs[@]} -gt 0 ]]; then
        execute_gh_api_with_retry 3 2 true -X PUT "$path_permissions" -H "Accept: application/vnd.github+json" "${rs[@]}" &&
        info "...actions workflow permissions configured." ||
        warning "Could not configure Actions workflow permissions. Run the script with '--verbose' to see more details and troubleshoot."
    else
        info "...actions workflow permissions configured."
    fi
}

#-------------------------------------------------------------------------------
# @description Reconciles the target repository's GitHub Actions variables against `actions_default_vars`. In
# non-interactive mode (the default), creates any missing variable with its default value and leaves existing
# variables untouched. In interactive mode (`$interactive_vars == true`), prompts the user for each variable's
# value (pre-filled with the current value if it exists, else the default), validating input with the validator
# from `actions_var_validators`, and calls `set_var` only when the entered value differs from the current one.
# Prints a summary of how many variables were set to a new value, set to their default, or left unmodified.
#
# @exitcode 0 Always (individual `set_var` failures are logged and skipped, not surfaced as a non-zero exit code).
#
# @stdout Progress/status messages via `info`, and (in interactive mode) prompts via `enter_value`.
#-------------------------------------------------------------------------------
function configure_variables()
{
    info "Configuring GitHub Actions variables..."

    local path_vars="$path_repo/actions/variables"

    # Get existing variables as name=value pairs
    local -A existing
    local name value exists # about the current variable

    while IFS='=' read -r name value; do
        existing["$name"]="$value"
    done < <(execute_gh_api_with_retry 3 2 --paginate "$path_vars" -q "$jq_vars")

    local -i skipped=0 set_new=0 set_default=0
    local -a ordered_names

    readarray -t ordered_names < <(printf '%s\n' "${!actions_default_vars[@]}" | sort)

    local new_value=""
    local default_value=""

    for name in "${ordered_names[@]}"; do
        # does the var exists in GH?
        [[ -v existing[$name] ]] && exists=true || exists=false

        # we are not in interactive mode and we cannot modify the variable but it exists in GH -- continue to the next variable
        ! $interactive_vars && $exists && (( ++skipped )) && continue

        # get the variable's current and default values
        $exists && value="${existing[$name]:-}"
        default_value="${actions_default_vars[$name]}"

        if $interactive_vars; then
            # prompt the user for a value while showing them the current value (if it exists) and the default value
            $exists &&
                new_value=$(enter_value "        Enter value for variable $name (default: '$default_value')" "$value"         false "${actions_var_validators["$name"]}") ||
                new_value=$(enter_value "        Enter value for variable $name"                             "$default_value" false "${actions_var_validators["$name"]}")
            if [[ $new_value != "$value" ]]; then
                # set the variable to the value
                trace "Setting variable: $name=$new_value"
                set_var "$name" "$new_value" || continue
                [[ $new_value != "$default_value" ]] &&
                    (( ++set_new )) ||
                    (( ++set_default ))
            elif [[ $new_value == "$value" ]]; then
                trace "Unchanged variable: $name=$value"
                (( ++skipped ))
            else
                error -sd 3 -ec "$err_logic_error" "Unexpected error: new_value '$new_value' is not equal to either the current value '$value' or the default value '$default_value'. This should never happen."
                reset_errors
            fi
        else
            # we are not in interactive mode and the var does not exist, so we will create it using the default value
            ! $exists && new_value="$default_value" && (( ++set_default ))
            if $exists; then
                trace "Variable unchanged: $name=$value"
                (( ++skipped ))
            else
                trace "Setting variable to default value: $name=$default_value"
                set_var "$name" "$default_value" && (( ++set_default ))
            fi
        fi
    done

    # display the summary
    (( set_new > 0 ))     && info "    $set_new variable(s) set to new value(s)."             || true
    (( set_default > 0 )) && info "    $set_default variable(s) set to default value(s)."     || true
    (( skipped > 0 ))     && info "    $skipped variable(s) were not modified."               || true
    info "  Run the script with option '--interactive-vars' or '-iv' to set new values for any of the Actions vars."
}

#-------------------------------------------------------------------------------
# @description Creates or updates a single GitHub Actions repository variable via `gh variable set`.
#
# @arg $1 string Name of the variable to set.
# @arg $2 string Value to set the variable to.
#
# @exitcode 0 Variable set successfully.
# @exitcode 2 Wrong number of arguments (`$err_invalid_arguments`).
# @exitcode * Whatever `execute_gh_with_retry` returned on failure (logged as a warning, then propagated).
#-------------------------------------------------------------------------------
function set_var()
{
    (( $# == 2 )) || {
        error -sd 2 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments: name and value."
        return "$err_invalid_arguments"
    }

    local name="$1"
    local value="$2"

    local rc=$success

    # create and/or set the secret value on GitHub
    execute_gh_with_retry 3 2 true variable set "$name" --body "$value" -R "$repo" || {
        rc=$?
        warning "Failed to set variable $name. Run the script with '--verbose' to see more details and troubleshoot."
    }

    return "$rc"
}

#-------------------------------------------------------------------------------
# @description Checks whether a candidate secret value is safe to send to the GitHub API -- i.e. it contains no
# control characters.
#
# Notes:
#   - This function is not called anywhere in this file: `configure_secrets()` validates user-entered secret values
#     with `validate_gh_secret` (defined in `lib/_git.sh`), not with this one. Left in place undocumented-as-dead
#     since removing it is outside the scope of this documentation pass; flagged here for future cleanup
#     consideration.
#
# @arg $1 string Candidate secret value to validate.
#
# @exitcode 0 The value contains no control characters.
# @exitcode 1 The value contains at least one control character.
#-------------------------------------------------------------------------------
function is_valid_secret()
{
    [[ ! "$1" =~ [[:cntrl:]] ]]
}

#-------------------------------------------------------------------------------
# @description Reconciles one GitHub App's repository secrets (Actions, Dependabot, agents, or Codespaces) against
# the corresponding `<app>_secrets` associative array. Secret values themselves cannot be read back from GitHub, so
# reconciliation is presence-only: an existing secret is left untouched, and a missing secret is either created
# interactively (prompting the user, `$interactive_secrets == true`) or flagged with a warning asking the user to
# create it (`$interactive_secrets == false`). Prints a summary of how many secrets were set or still need a value.
#
# @arg $1 string Application name; must be one of the entries in `apps_with_secrets` (`actions`, `dependabot`,
#   `agents`, `codespaces`).
#
# @exitcode 0 Success, including the case where the app has no configured secrets at all (returns immediately).
# @exitcode 2 Wrong number of arguments, an unrecognized application name, or the corresponding `<app>_secrets`
#   array is not defined (`$err_invalid_arguments`).
#
# @stdout Progress/status messages via `info`, and (in interactive mode) prompts via `enter_value`.
#-------------------------------------------------------------------------------
function configure_secrets()
{
    # validate the parameter - the application name: actions, dependabot, agents, or codespaces
    local -i rc="$success"

    [[ $# -eq 1 ]] && is_in "$1" "${apps_with_secrets[@]}" || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument -- the application name. It should be one of: ${apps_with_secrets[*]}."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local app="$1"
    local secrets_array_name="${app,,}_secrets"

    is_defined_associative_array "$secrets_array_name" || {
        rc="$err_logic_error"
        error -sd 3 -ec "$rc" "The secrets array '$secrets_array_name' for the application '$app' is not defined. Cannot configure secrets for this application."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local -n app_secrets=$secrets_array_name

    (( ${#app_secrets[@]} > 0 )) || return 0 # no secrets to set for this app - we are done

    info "Configuring ${app^} secrets..."

    local path_secrets="$path_repo/$app/secrets"

    # get the names of the existing secrets
    local -A existing
    local name value exists # about the current variable

    while IFS='=' read -r name; do
        existing["$name"]="$present_state"
    done < <(execute_gh_api_with_retry 3 2 --paginate "$path_secrets" -q "$jq_secret_names")

    # remember the current verbose and tracing settings so we can restore them after setting the secret(s)
    local -i skipped=0 set_new=0 need_new=0
    local -a ordered_names

    readarray -t ordered_names < <(printf '%s\n' "${!app_secrets[@]}" | sort)

    for name in "${ordered_names[@]}"; do
        # does the secret exists in GH?
        [[ -v existing[$name] ]] && exists=true || exists=false

        # we are not in interactive mode and we cannot modify the secret but it exists in GH -- continue to the next variable
        ! $interactive_secrets && $exists && (( ++skipped )) && continue

        # get the value for the secret or use the placeholder if we are not entering secrets interactively
        if $interactive_secrets; then
            # prompt the user for a (new) value of the secret
            $exists &&
                value=$(enter_value "        Enter value for secret $name" "$secret_str" true validate_gh_secret) ||
                value=$(enter_value "        Enter value for secret $name" ""            true validate_gh_secret)
            echo ""
            if [[ -n $value && $value != "$secret_str" ]]; then
                set_secret "$name" "$value" "$app" || continue
                trace "Set value of secret: $name"
                (( ++set_new ))
            elif [[ -n $value && $value == "$secret_str" ]]; then
                trace "Unchanged secret: $name"
                (( ++skipped ))
            elif [[ -z $value ]]; then
                warning "      Create secret: $name."
                (( ++need_new ))
            fi
        else
            # the secret exists in GH or it does not exist; but we are not in interactive mode, so either way skip it
            if $exists; then
                trace "Secret unchanged: $name"
                (( ++skipped ))
            else
                warning "      Create secret: $name."
                (( ++need_new ))
            fi
            continue
        fi

    done

    (( set_new > 0 ))  && info "    $set_new secret(s) set to new value(s)."      || true
    (( skipped > 0 ))  && info "    $skipped secret(s) were not modified."        || true
    (( need_new > 0 )) && warning "  Run the script with option '--interactive-secrets' or '-is' to set the values for $need_new ${app^} secrets." || true
}

#-------------------------------------------------------------------------------
# @description Creates or updates a single GitHub repository secret for the given app (`actions`, `dependabot`,
# `agents`, or `codespaces`) via `gh secret set`. Temporarily suppresses verbose/trace output and `set -x` around
# the actual `gh` call so the secret's plaintext value is never written to logs, restoring the previous state
# afterward regardless of success or failure.
#
# @arg $1 string Name of the secret to set.
# @arg $2 string Plaintext value to set the secret to.
# @arg $3 string GitHub App the secret belongs to (`actions`, `dependabot`, `agents`, or `codespaces`).
#
# @exitcode 0 Secret set successfully.
# @exitcode 2 Wrong number of arguments (`$err_invalid_arguments`).
# @exitcode * Whatever `execute_gh_with_retry` returned on failure (logged as a warning, then propagated).
#-------------------------------------------------------------------------------
function set_secret()
{
    (( $# == 3 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly three arguments: name, value, and app."
        return "$err_invalid_arguments"
    }
    local name="$1"
    local value="$2"
    local app="$3"

    # we have a new legitimate value for the secret that we need to create and/or set:
    trace "gh secret set $name --body <secret> --app $app --repo $repo"

    save_state

    # suppress all tracing to avoid revealing the secret value
    unset_verbose
    set +x

    local rc=$success

    # create and/or set the secret value on GitHub
    execute_gh_with_retry 3 2 true secret set "$name" --body "$value" --app "$app" --repo "$repo" || {
        rc=$?
        warning "Failed to set secret $name for ${app^}. Run the script with '--verbose' to see more details and troubleshoot." -ec "$rc"
    }

    restore_state
    return "$rc"
}

#-------------------------------------------------------------------------------
# @description Creates (POST) or updates (PUT, if `initialize_main_protection_rs_id` finds one already exists) the
# GitHub ruleset that protects the default branch: linear history, no force pushes, a required pull request with
# rebase-only merges, and the required status checks collected in `required_checks`. After the API call, re-runs
# `initialize_main_protection_rs_id` so `main_protection_rs_id`/`path_main_protection_ruleset` reflect a
# newly-created ruleset (a no-op if the ruleset already existed and was just updated).
#
# @exitcode 0 Always (a failed API call from `execute_gh_api_with_retry` is not checked/propagated here).
#
# @stdout Progress/status messages via `info` ("Configuring branch ruleset...", "Updating existing ruleset...", or
#   "Creating new ruleset...").
#-------------------------------------------------------------------------------
function configure_branch_protection()
{
    info "Configuring branch ruleset for '$branch'..."

    local method
    local endpoint

    # Check if a ruleset named "main protection" already exists
    if initialize_main_protection_rs_id; then
        method="PUT"
        endpoint="$path_main_protection_ruleset"
        info "Updating existing ruleset $main_protection_rs_name (id: $main_protection_rs_id)..."
    else
        method="POST"
        endpoint="$path_rulesets"
        info "Creating new ruleset $main_protection_rs_name..."
    fi

    # Build required status checks array
    local status_checks_json=""
    if [[ ${#required_checks[@]} -gt 0 ]]; then
        local -a entries=()
        for check in "${required_checks[@]}"; do
            entries+=("{\"context\":\"$check\",\"integration_id\":$actions_app_id}")
        done
        IFS=',' status_checks_json="${entries[*]}"
        status_checks_json="[$status_checks_json]"
    fi

    execute_gh_api_with_retry 3 2 true -X "$method" "$endpoint" -H "Accept: application/vnd.github+json" \
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
            "actor_id": 5,
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
                "required_status_checks": $status_checks_json
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
