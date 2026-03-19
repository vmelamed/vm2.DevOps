# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x _ignore
declare -x script_name
declare -x lib_dir

declare -x repo_name
declare -x owner
declare -x repo
declare -x visibility
declare -x branch
declare -x audit
declare -x interactive_vars
declare -x interactive_secrets
declare -x main_protection_rs_name

declare -xri admin_role_id
declare -xr secret_placeholder
declare -xrA default_repo_settings
declare -xra default_repo_settings_order
declare -xrA default_secrets
declare -xrA default_vars
declare -xrA var_validators
declare -xrA default_ruleset
declare -xra default_ruleset_order

declare -x ci_yaml
declare -x _ci_yaml

declare -xa required_checks
declare -xi github_actions_app_id

declare -xr github_url_regex
declare -xri url_authority
declare -xri url_owner
declare -xri url_name

declare -x path_vars
declare -x path_repo
declare -x path_permissions
declare -x path_secrets
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

function resolve_github_actions_app_id()
{
    # Resolve the GitHub Actions app ID dynamically via the API.
    # Used to pin required status checks to GitHub Actions specifically.
    # this function cannot be called before initialize_gh_paths() because the latter relies on the github_actions_app_id variable being set - circular dependency
    github_actions_app_id=$(gh api --paginate apps/github-actions --jq '.id' 2>"$_ignore") || error "Failed to resolve GitHub Actions app ID from the API."
    exit_if_has_errors
    trace "GitHub Actions app ID: ${github_actions_app_id}"
    [[ "$github_actions_app_id" == "15368" ]] || warning "Unexpected GitHub Actions app ID: ${github_actions_app_id} (expected 15368). Required status check matching may not work correctly."

    declare -xr github_actions_app_id
}

function detect_required_checks()
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
    gate_job=$(yq -r '.jobs | keys[] | select(test("postrun|ci-gate"))' "$ci_yaml" | head -n 1) || error "Failed to parse gate job from CI.yaml."
    gate_name=$(yq -r ".jobs.${gate_job:-postrun-ci}.name" "$ci_yaml")                          || error "Failed to parse gate job name from CI.yaml."
    exit_if_has_errors

    required_checks+=(
        "${gate_name}"
    )

    declare -xra required_checks

    trace "Required checks: ${required_checks[*]}"
}

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository exists, it is a git repository, and is at or ahead of the latest stable tag.
# Parameters:
#   $1: repository name (e.g. "vm2.DevOps")
# Returns:
#   Exit code:
#     0 - if the repository exists and meets the above criteria, or
#     2 - if the repository is invalid or does not meet the criteria
# Environment variables:
#   vm2_repos:
#     the parent directory where the repository is expected to have been cloned to, e.g. $VM2_REPOS or "$HOME/repos/vm2"
# Dependencies:
#   git CLI (functions root_working_tree, is_on_or_after_latest_stable_tag)
# Usage:
#   validate_source_repo "vm2.DevOps"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function validate_source_repo()
{
    if [[ $# -lt 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires at least 1 argument: the name of a repository."
        return 2
    fi

    local repo_name=$1
    local dir="${vm2_repos}/${repo_name}"

    [[ -d "${dir}" ]] || error "The '${repo_name}' repository was not cloned or is not under ${vm2_repos}."

    if [[ "$dir" == $(root_working_tree "$dir") ]]; then
        is_on_or_after_latest_stable_tag "$dir" "$semverTagReleaseRegex" || error "The HEAD of the '${repo_name}' repository is before the latest stable tag. Please synchronize."
    else
        confirm "The ${repo_name} repository at '$dir' is not a git repository. Do you want to continue?" "n" || error "The ${repo_name} repository at '$dir' is not a git repository."
    fi
}

# shellcheck disable=SC2089 # Quotes/backslashes will be treated literally. Use an array.
# shellcheck disable=SC2090 # Quotes/backslashes in this variable will not be respected.
function initialize_gh_paths()
{
    [[ -n $repo ]] || error "The 'repo' variable is not set. Cannot initialize GitHub paths."
    [[ -n $main_protection_rs_name ]] || error "The 'main_protection_rs_name' variable is not set. Cannot initialize GitHub paths."

    path_repo="repos/${repo}"
    path_vars="${path_repo}/actions/variables"
    path_secrets="${path_repo}/actions/secrets"
    path_permissions="${path_repo}/actions/permissions/workflow"
    path_rulesets="${path_repo}/rulesets"

    declare -xr path_vars
    declare -xr path_repo
    declare -xr path_permissions
    declare -xr path_secrets
    declare -xr path_vars
    declare -xr path_rulesets
}

# shellcheck disable=SC2089 # Quotes/backslashes will be treated literally. Use an array.
# shellcheck disable=SC2090 # Quotes/backslashes in this variable will not be respected.
function initialize_jq_queries()
{
    [[ -n $main_protection_rs_name ]] || error "The 'main_protection_rs_name' variable is not set. Cannot initialize GitHub paths."
    (( github_actions_app_id > 0 )) || error "The 'github_actions_app_id' variable is not set or is invalid. Cannot initialize jq queries."
    (( admin_role_id > 0 )) || error "The 'admin_role_id' variable is not set or is invalid. Cannot initialize jq queries."

    jq_entries='to_entries[] | "\(.key)=\(.value)"'
    jq_secrets='.secrets[] | "\(.name)=<set>"'
    jq_secret_names='.secrets[] | .name'
    jq_vars='.variables[] | "\(.name)=\(.value)"'
    jq_ruleset_id='.[] | select(.name == "'"$main_protection_rs_name"'") | .id // empty'
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
                                                                            select(.integration_id == '"$github_actions_app_id"') |
                                                                            length >= '"${#required_checks[@]}"' ] | is_present,
    non_fast_forward:                       count_rules("non_fast_forward"),
} | to_entries[] | "\(.key)=\(.value)"'

    jq_status_checks='.rules[] | select(.type == "required_status_checks") |
                      .parameters.required_status_checks[] | select(.integration_id == '"$github_actions_app_id"') |
                      .context'

    declare -xr jq_entries
    declare -xr jq_secrets
    declare -xr jq_secret_names
    declare -xr jq_vars
    declare -xr jq_ruleset_id
    declare -xr jq_ruleset_rules
    declare -xr jq_status_checks
}

function initialize_main_protection_rs_id()
{
    (( main_protection_rs_id > 0 )) && return 0

    [[ -n $main_protection_rs_name ]] || error "The 'main_protection_rs_name' variable is not set. Cannot initialize main protection ruleset ID."
    [[ -n $path_rulesets ]] || error "The 'path_rulesets' variable is not set. Cannot initialize main protection ruleset ID."

    main_protection_rs_id=$(gh api --paginate "$path_rulesets" |
                            jq -r "$jq_ruleset_id" 2>"$_ignore") || return 1

    path_main_protection_ruleset="${path_rulesets}/${main_protection_rs_id}"

    declare -xir main_protection_rs_id
    declare -xr path_main_protection_ruleset

    return 0
}

function configure_default_repo_settings()
{
    info "Configuring repository settings..."
    local -a rs
    for key in "${!default_repo_settings[@]}"; do
        rs+=("-f ${key}=${default_repo_settings[$key]}")
    done
    execute gh api -X PATCH "${path_repo}" "${rs[@]}" >"$_ignore"
}

declare -xrA default_repo_permissions=(
    ["default_workflow_permissions"]="read"
    ["can_approve_pull_request_reviews"]=false
)

function configure_actions_permissions()
{
    info "Configuring Actions workflow permissions..."
    if ! execute gh api -X PUT "$path_permissions" \
            -H "Accept: application/vnd.github+json" \
            -f default_workflow_permissions=read \
            >"$_ignore"; then
        warning "Could not configure Actions workflow permissions (possibly restricted by owner policy)."
    fi
}

function configure_variables()
{
    info "Configuring repository variables..."

    # Get existing variables as name=value pairs
    local -A existing_vars
    local name value exists # about the current variable

    while IFS='=' read -r name value; do
        existing_vars["$name"]="$value"
    done < <(gh api --paginate "$path_vars" -q "$jq_vars")


    local new_value=""
    local default_value=""
    local skipped=0 set_new=0 set_default=0
    local -a ordered_names

    mapfile -t ordered_names < <(printf '%s\n' "${!default_vars[@]}" | sort)

    for name in "${ordered_names[@]}"; do
        is_in "$name" "${!existing_vars[@]}" && exists=true || exists=false

        $exists && ! $interactive_vars && (( ++skipped )) && continue

        $exists && value="${existing_vars[$name]}" || value=""
        default_value="${default_vars[$name]}"

        if $interactive_vars; then
            $exists && new_value=$(enter_value "            Enter value for variable ${name} (current: '${value}')" "$default_value" false "${var_validators["$name"]}") ||
                       new_value=$(enter_value "            Enter value for variable ${name}" "$default_value" false "${var_validators["$name"]}")
        fi

        $exists && [[ $value == "$new_value" ]] && (( ++skipped )) && continue # nothing to do if the new value is the prev. value

        execute gh variable set "$name" --body "$new_value" -R "$repo" >"$_ignore"
        trace "Set variable: ${name}=${new_value}"
        # shellcheck disable=SC2015
        [[ $new_value == "$default_value" ]] && (( ++set_default )) || (( ++set_new ))
    done

    (( set_new > 0 ))     && info "    ${set_new} variable(s) set to new value(s)."             || true
    (( set_default > 0 )) && info "    ${set_default} variable(s) set to default value(s)."     || true
    (( skipped > 0 ))     && info "    ${skipped} variable(s) - not modified."                  || true
}

function is_valid_secret()
{
    [[ "$1" =~ ^[a-zA-Z0-9_+=/@.-]+$ ]]
}

function configure_secrets()
{
    # get the names of the existing secrets
    local -a existing_secrets
    while IFS='=' read -r name; do
        existing_secrets+=("$name")
    done < <(gh api --paginate "$path_secrets" -q "$jq_secret_names")

    info "Configuring repository secrets..."

    local skipped=0 set_new=0 set_default=0
    local name value exists         # about the current secret
    local first=true
    local -a ordered_names

    mapfile -t ordered_names < <(printf '%s\n' "${!default_secrets[@]}" | sort)

    local set_verbose_on
    local set_tracing_on
    is_verbose && set_verbose_on=true || set_verbose_on=false
    [[ $- =~ .*x.* ]] && set_tracing_on=true || set_tracing_on=false

    for name in "${ordered_names[@]}"; do

        is_in "$name" "${existing_secrets[@]}" && exists=true || exists=false

        $exists && ! "$interactive_secrets" && (( ++skipped )) && continue # secret exists and we are not entering secrets - continue with the next secret

        # get the value for the secret or use the placeholder if we are not entering secrets
        if $interactive_secrets; then
            $first && {
                warning "  If you just press the Enter key, a PLACEHOLDER value will be used!"
                first=false
            }
            value=$(enter_value "            Enter value for secret ${name} [PLACEHOLDER]" "$secret_placeholder" true is_valid_secret)
            echo ""
        fi

        trace "gh secret set $name --body <secret> -R $repo"

        # suppress all tracing to avoid revealing the secret value
        unset_verbose
        set +x

        # set the secret on GitHub
        execute gh secret set "$name" --body "$value" -R "$repo" >"$_ignore"

        # restore all tracing
        # shellcheck disable=SC2015
        $set_verbose_on && set_verbose || unset_verbose
        $set_tracing_on && set -x || true

        trace "Set secret: ${name}"
        # shellcheck disable=SC2015
        if [[ $value == "$secret_placeholder" ]]; then
            (( ++set_default ))
        else
            (( ++set_new ))
        fi
    done

    (( set_new > 0 ))     && info "    ${set_new} secret(s) set to new value(s)."               || true
    (( set_default > 0 )) && info "    ${set_default} secret(s) set to placeholder value(s)."   || true
    (( skipped > 0 ))     && info "    ${skipped} secrets(s) were not modified."                || true
    (( set_default > 0 )) && warning "  Replace placeholder secrets with actual values."        || true
}

function configure_branch_protection()
{
    info "Configuring branch ruleset for '${branch}'..."

    local method
    local endpoint

    # Check if a ruleset named "main protection" already exists
    if initialize_main_protection_rs_id; then
        method="PUT"
        endpoint="${path_main_protection_ruleset}"
        info "Updating existing ruleset ${main_protection_rs_name} (id: ${main_protection_rs_id})..."
    else
        method="POST"
        endpoint="${path_rulesets}"
        info "Creating new ruleset ${main_protection_rs_name}..."
    fi

    # Build required status checks array
    local status_checks_json=""
    if [[ ${#required_checks[@]} -gt 0 ]]; then
        local entries=()
        for check in "${required_checks[@]}"; do
            entries+=("{\"context\":\"${check}\",\"integration_id\":${github_actions_app_id}}")
        done
        local IFS=','
        status_checks_json="${entries[*]}"
        status_checks_json="[$status_checks_json]"
    fi

    execute gh api -X "${method}" "${endpoint}" \
        -H "Accept: application/vnd.github+json" \
        --input - >"$_ignore" <<JSON
{
    "name": "$main_protection_rs_name",
    "target": "branch",
    "enforcement": "active",
    "conditions": {
        "ref_name": {
            "include": ["refs/heads/${branch}"],
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
                "required_status_checks": ${status_checks_json}
            }
        },
        {
            "type": "required_linear_history"
        }
    ]
}
JSON

    if (( main_protection_rs_id == 0 )); then
        initialize_main_protection_rs_id
    fi
}
