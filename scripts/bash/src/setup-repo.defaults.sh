# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xri success                    # Operation completed successfully
declare -xri err_invalid_arguments      # The number of the arguments is invalid or more than one type of parameter error code is present
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_invalid_item

declare -x vm2_devops_repo_name

declare -xr secret_str
declare -xr default_nuget_server

declare -x nuget_server
declare -x repo_name

#===============================================================================
# GitHub repository settings
#===============================================================================

declare -xrA default_repo_settings=(
    ["default_branch"]="main"
    ["delete_branch_on_merge"]=true
    ["allow_squash_merge"]=false
    ["allow_merge_commit"]=false
    ["allow_rebase_merge"]=true
    ["allow_auto_merge"]=true
    ["has_issues"]=true
    ["has_wiki"]=false
    ["has_projects"]=false
    ["has_pull_requests"]=true
    ["pull_request_creation_policy"]="all"
    ["visibility"]="public"
)

declare -xra default_repo_settings_order=(
    "default_branch"
    "has_wiki"
    "has_issues"
    "has_projects"
    "has_pull_requests"
    "pull_request_creation_policy"
    "allow_merge_commit"
    "allow_squash_merge"
    "allow_rebase_merge"
    "allow_auto_merge"
    "delete_branch_on_merge"
    "visibility"
)

#===============================================================================
# GitHub repository permissions settings
#===============================================================================

declare -xrA default_repo_permissions=(
    ["default_workflow_permissions"]="read"
    ["can_approve_pull_request_reviews"]=false
)

#===============================================================================
# GitHub repository "main protection" ruleset
#===============================================================================

declare -xrA default_ruleset=(
    ["enforcement"]="active"
    ["repository_admin_bypass"]="present"
    ["deletion"]="present"
    ["required_linear_history"]="present"
    ["pull_request"]="present"
    ["required_approving_review_count"]="present"
    ["dismiss_stale_reviews_on_push"]="present"
    ["require_code_owner_review"]="present"
    ["require_last_push_approval"]="present"
    ["required_review_thread_resolution"]="present"
    ["required_reviewers"]="present"
    ["allowed_merge_methods"]="present"
    ["required_status_checks"]="present"
    ["do_not_enforce_on_create"]="present"
    ["strict_required_status_checks_policy"]="present"
    ["non_fast_forward"]="present"
)

declare -xra default_ruleset_order=(            # UI: Order in which rules appear in the GitHub UI "Rulesets/main protection"
    "enforcement"                               # Enforcement status: Active/Disabled ▾
    "repository_admin_bypass"                   # Bypass actors section
    "deletion"                                  # Restrict deletions
    "required_linear_history"                   # Require linear history
    "pull_request"                              # Require a pull request ▾
    "required_approving_review_count"           #   ↳ Required approvals
    "dismiss_stale_reviews_on_push"             #   ↳ Dismiss stale reviews
    "require_code_owner_review"                 #   ↳ Require Code Owners review
    "require_last_push_approval"                #   ↳ Require last push approval
    "required_review_thread_resolution"         #   ↳ Require conversation resolution
    "required_reviewers"                        #   ↳ Reviewers list
    "allowed_merge_methods"                     #   ↳ Allowed merge methods
    "required_status_checks"                    # Require status checks ▾
    "do_not_enforce_on_create"                  #   ↳ Do not enforce on create
    "strict_required_status_checks_policy"      #   ↳ Require up-to-date branches
    "non_fast_forward"                          # Block force pushes
)

#===============================================================================
# GitHub repository variables
#===============================================================================

declare -xra gh_apps_with_vars

# The vars defaults for each application not only gives the default values for the variables
# but also serves as a definition of the expected variables for the application. Some variables
# may be optional depending on the application's configuration or environment, e.g.,
# NUGET_USERNAME may not be required if the NuGet server is GitHub Packages. This is
# controlled in the function that retrieves the default values for the application's
# variables - see `get_vars_defaults()` below. That's why when iterating through the
# variables' order, the code MUST check if the current var from the order exists in the
# defaults array returned by `get_vars_defaults()`.
declare -xA actions_vars_defaults=(
    # Build and Pack:
    ["MINVERTAGPREFIX"]="v"
    ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="preview.0"
    # Test:
    ["MIN_COVERAGE_PCT"]="80"
    # Benchmarks:
    ["MAX_REGRESSION_PCT"]="20"
    ["MAX_GEN1_COLLECTS"]="2"
    ["MAX_GEN2_COLLECTS"]="1"
    ["RESET_BENCHMARK_THRESHOLDS"]=false
    # NuGet:
    ["NUGET_SERVER"]="$default_nuget_server"    # The default NuGet server to use for publishing packages. Can be 'nuget', 'github', or a custom server URL.
    ["NUGET_USERNAME"]="valo"                   # The default username to use for the selected NuGet server:
                                                #   - nuget - the NuGet.org username
                                                #   - GitHub Packages uses the caller's token and does not need a username.
                                                #   - Custom server - as required.
    # Trace:
    ["VERBOSE"]=false
    # GitHub Actions diagnostics
    ["ACTIONS_RUNNER_DEBUG"]=false
    ["ACTIONS_STEP_DEBUG"]=false
)

declare -xa actions_vars_order=(
    "--Build and Pack:"
    "MINVERTAGPREFIX"
    "MINVERDEFAULTPRERELEASEIDENTIFIERS"
    "--Nuget:"
    # DO NOT PLACE NUGET_USERNAME before NUGET_SERVER!!!
    "NUGET_SERVER"
    "NUGET_USERNAME"
    "--Test:"
    "MIN_COVERAGE_PCT"
    "--Benchmarks:"
    "MAX_REGRESSION_PCT"
    "MAX_GEN1_COLLECTS"
    "MAX_GEN2_COLLECTS"
    "RESET_BENCHMARK_THRESHOLDS"
    "--Trace:"
    "VERBOSE"
    "--GitHub Actions diagnostics:"
    "ACTIONS_RUNNER_DEBUG"
    "ACTIONS_STEP_DEBUG"
    "--Other:"
)

declare -xA actions_vars_validators=(
    # Build and Pack
    ["MINVERDEFAULTPRERELEASEIDENTIFIERS"]="is_valid_minverPrereleaseId"
    ["MINVERTAGPREFIX"]="validate_semverTagComponents"
    # Test
    ["MIN_COVERAGE_PCT"]="is_valid_percentage"
    # Benchmarks
    ["MAX_REGRESSION_PCT"]="is_valid_percentage"
    ["MAX_GEN1_COLLECTS"]="is_non_negative"
    ["MAX_GEN2_COLLECTS"]="is_non_negative"
    ["RESET_BENCHMARK_THRESHOLDS"]="is_boolean"
    # NuGet
    ["NUGET_SERVER"]="is_valid_nuget_server"
    ["NUGET_USERNAME"]="is_safe_input"
    # Trace
    ["VERBOSE"]="is_boolean"
    # GitHub Actions diagnostics
    ["ACTIONS_RUNNER_DEBUG"]="is_boolean"
    ["ACTIONS_STEP_DEBUG"]="is_boolean"
)

declare -xA agents_vars_defaults=()
declare -xa agents_vars_order=()
declare -xA agents_vars_validators=()

#---------------------------------------------------------------------------------------------
# @description Validates the consistency of an application's default-variable tables:
#   '<app>_vars_defaults' (associative array of default values), '<app>_vars_order' (display
#   order), and '<app>_vars_validators' (per-variable validator function names). Backfills a
#   missing/short display order (alphabetically, with a warning) and appends any default
#   variable missing from the display order. Every default variable must have an entry in
#   '<app>_vars_validators' whose value is either a defined function name or the literal
#   string 'true' (meaning "no validation"); that validator (when not 'true') is then run
#   against the variable's own default value. On success, freezes all three tables as
#   read-only. A no-op if '<app>_vars_defaults' is empty.
#
# @arg $1 string _app - the application name (must be one of '${gh_apps_with_vars[@]}', e.g.
#   'actions').
#
# @exitcode success=0: The tables are consistent and were frozen (or '<app>_vars_defaults' was
#   empty).
#
# Note: a caller-contract violation (unknown app, missing table, an undefined validator
#   function, or a default value that fails its own validator) is reported via 'bug' and
#   aborts the process via 'exit_if_has_bugs' -- this function never returns a non-zero code
#   to a caller.
#---------------------------------------------------------------------------------------------
function validate_app_default_vars()
{
    (( $# == 1 ))                                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#):" \
                                                                                          "  - the name of the application (e.g., actions)"
    [[ ! -v 1 ]] || is_in "$1" "${gh_apps_with_vars[@]}" || bug "${FUNCNAME[0]}() requires the argument to be one of (${gh_apps_with_vars[*]}) - provided ${1:-<none>}."
    exit_if_has_bugs

    local _app=$1
    local _vars_defaults_name="${_app,,}_vars_defaults"
    local _vars_order_name="${_app,,}_vars_order"
    local _vars_validators_name="${_app,,}_vars_validators"

    is_associative_array "$_vars_defaults_name"       || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() the required associative array '$_vars_defaults_name' is not defined."
    is_indexed_array "$_vars_order_name"              || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() the required indexed array '$_vars_order_name' is not defined."
    is_associative_array "$_vars_validators_name"     || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() the required associative array '$_vars_validators_name' is not defined."
    exit_if_has_bugs

    local -n _app_vars_defaults=$_vars_defaults_name
    local -n _app_vars_order=$_vars_order_name
    local -n _app_vars_validators=$_vars_validators_name

    is_empty_array "$_vars_defaults_name" && return

    # make sure that default values, and display order are consistent: there is an entry for each default variable in the display order.
    if [[ "${#_app_vars_order}" < ${#_app_vars_defaults[@]} ]]; then
        warning "The number of elements in '$_vars_order_name' (${#_app_vars_order}) is less than the number of elements in '$_vars_defaults_name' (${#_app_vars_defaults}), assuming sorted order."
        readarray -t "$_vars_order_name" < <(printf "%s\n" "${!_app_vars_defaults[@]}" | sort)
    else
        for _var in "${!_app_vars_defaults[@]}"; do
            is_in "$_var" "${_app_vars_order[@]}" || {
                warning "The variable '$_var' is not listed in the display order. Appending it at the end of the array."
                _app_vars_order+=("$_var")
            }
        done
    fi

    # make sure that each default variable has a corresponding validator
    local _validator _default_value
    for _var in "${!_app_vars_defaults[@]}"; do
        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        [[ -v _app_vars_validators[$_var] ]] && {
            _validator=${_app_vars_validators[$_var]}

            is_function "$_validator" || [[ $_validator == "true" ]] || {
                bug -ec "$err_invalid_item" "${FUNCNAME[0]}() '$_validator' is not a name of a defined function.";
                continue;
            }

            _default_value=${_app_vars_defaults[$_var]}

            $_validator "$_default_value" || {
                bug -ec "$err_invalid_item" "${FUNCNAME[0]}() the default value '$_default_value' of the variable '$_var' is not pass the validator '$_validator'.";
            }
        } || {
            bug -ec "$err_invalid_item" "There is no validator set for the variable '$_var'."
        }
    done
    exit_if_has_bugs

    readonly -A "$_vars_defaults_name"
    readonly -a "$_vars_order_name"
    readonly -A "$_vars_validators_name"
}

#---------------------------------------------------------------------------------------------
# @description Gets the default data for the current repo application's GitHub Actions 'vars':
#   the default values (copied mostly from '<app>_vars_defaults') and the display order
#   (copied from '<app>_vars_order'). For 'actions', 'NUGET_SERVER's default value is
#   overridden with the current global '$nuget_server' (rather than the hardcoded table
#   default), and 'NUGET_USERNAME' is dropped entirely when '$nuget_server' is 'github'
#   (GitHub Packages authenticates with the caller's token and needs no username).
#
# @arg $1 string _app - the application name (must be one of '${gh_apps_with_vars[@]}', e.g.
#   'actions').
# @arg $2 string __vars - name of an associative array to receive the variables' names and
#   default values.
# @arg $3 string __vars_order - name of an indexed array to receive the variables' display
#   order.
# @arg $4 string (optional) name of an associative array intended to receive the names of each
#   variable's validation function.
#
# @exitcode success=0: Always (the output arrays were populated, or left empty if
#   '<app>_vars_defaults' is empty).
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
# shellcheck disable=SC2004 # $/${} is unnecessary on arithmetic variables.
function get_vars_defaults()
{
    (( $# == 3 || $# == 4 ))                          || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three or four arguments (provided $#):" \
                                                                                          "  - the name of the application (e.g., actions)" \
                                                                                          "  - the name of the associative array that will receive the variables names and their default values" \
                                                                                          "  - the name of the indexed array that will receive the variables display order" \
                                                                                          "  - the name of the associative array that will receive the names of the variables' validation functions (optional)"
    [[ ! -v 1 ]] || is_in "$1" "${gh_apps_with_vars[@]}" || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1 to be a valid application name - provided: '$1'."
    [[ ! -v 2 ]] || is_associative_array "$2"         || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 2 to be a valid associative array name to receive the variables names and their default values - provided: '$2'."
    [[ ! -v 3 ]] || is_indexed_array "$3"             || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 3 to be a valid indexed array name to receive the variables display order - provided: '$3'."
    [[ ! -v 4 ]] || is_associative_array "$4"         || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 4 to be a valid associative array name to receive the names of the variables' validation functions - provided: '$4'."
    exit_if_has_bugs

    local -r _app=$1
    local -n __vars=$2
    local -n __vars_order=$3

    __vars=()
    __vars_order=()
    [[ ! -v 4 ]] || __vars_validators=()

    local _vars_defaults_name="${_app,,}_vars_defaults"

    ! is_empty_array "$_vars_defaults_name" || return "$success"

    local -n __app_vars_defaults=$_vars_defaults_name

    # copy the vars default values
    local _var
    local _validator

    for _var in "${!__app_vars_defaults[@]}"; do

        local _default_value=${__app_vars_defaults[$_var]}

        if [[ $_app == "actions" ]]; then
            case "$_var" in
                "NUGET_SERVER" )
                    __vars["$_var"]="$nuget_server"
                    continue
                    ;;

                "NUGET_USERNAME")
                    # If github - the current token is the full credentials - skip this entry; the others (nuget.org) do require a username - below
                    [[ $nuget_server == "github" ]] && continue
                    ;;

                * ) ;;
            esac
        fi

        __vars["$_var"]="$_default_value"
    done

    # copy the default vars display order
    local _vars_order_name="${_app,,}_vars_order"
    local -n _app_vars_order=$_vars_order_name

    __vars_order=("${_app_vars_order[@]}")

    if [[ -v 4 ]]; then
        # copy the _vars_validators
        local _vars_validators_name="${_app,,}_vars_validators"
        local -n _app_vars_validators=$_vars_validators_name

        local -n __vars_validators=$4

        __vars_validators=()
        for _var in "${!_app_vars_validators[@]}"; do
            __vars_validators[$_var]=${_app_vars_validators[$_var]}
        done
    fi
}

#===============================================================================
# GitHub repository "main protection" ruleset
#===============================================================================

declare -xra gh_apps_with_secrets

# There is no application secrets defaults - only secrets order. The defaults MUST be
# retrieved dynamically from the `get_secrets_defaults()` function. The defaults' values are
# always the secret placeholder. Some secrets may be optional depending on the application's
# configuration or environment, e.g., NUGET_API_KEY may not exist if the NuGet server is
# GitHub Packages or NuGet.org. This is controlled by `get_secrets_defaults()`. That's why
# when iterating through the secrets' order, the code MUST check if the current secret from
# the order exists in the defaults array returned by `get_secrets_defaults()`.
declare -xra actions_secrets_order=(
    "--Build and Pack:"
    "NUGET_API_KEY"                            # The NuGet API key for the selected NuGet server. Note that GitHub Packages use
                                               # the callers's token; nuget.org uses Trusted Publishing and also does not need
                                               # secret.
                                               # (see https://learn.microsoft.com/en-us/nuget/nuget-org/trusted-publishing)
    "GH_PACKAGES_TOKEN"                        # The GitHub Packages token used to update the local GitHub Packages (Dependabot
                                               # reads its own copy). MUST be a classic PAT, read:packages only.
    "RELEASE_PAT"                              # PAT for a user listed as a bypass actor (e.g. Admin) in the branch ruleset
                                               # protecting main. Required to push changelog commits and version tags directly
                                               # to main
    "--Test:"
    "REPORTGENERATOR_LICENSE"                  # License key used by ReportGenerator for generating coverage reports
    "CODECOV_TOKEN"                            # Token used by Codecov to upload coverage reports - different for different
                                               # projects
    "--Benchmarks:"
    "BENCHER_API_TOKEN"                        # API token used by Bencher for authentication
    "BENCH_DISPATCH_PAT"                       # Fine-grained PAT with `Actions: write` + `Contents: read` on the package repos.
                                               # Used by `RebuildBenchHistory-AllRepos.yaml` to dispatch each repo's
                                               # benchmark-history rebuild.
)
declare -xra dependabot_secrets_order=(
    "GH_PACKAGES_TOKEN"                        # Needed by dependabot.yml's own "github-packages" registry entry, so
                                               # Dependabot can authenticate to check the private NuGet feed for
                                               # updates. This is a SEPARATE secret store from Actions secrets, even
                                               # for the identically-named secret -- see
                                               # https://docs.github.com/en/code-security/dependabot/working-with-dependabot/configuring-access-to-private-registries-for-dependabot#storing-credentials-for-dependabot-to-use
                                               # MUST be a classic PAT, read:packages only.
)
declare -xra agents_secrets_order=()
declare -xra codespaces_secrets_order=()

#---------------------------------------------------------------------------------------------
# @description Validates that one application's secrets display-order table
#   ('<app>_secrets_order') is defined. Unlike 'validate_app_default_vars', there are
#   no default values or per-secret validators for secrets (secret values are never defaulted
#   in source -- see 'get_secrets_defaults'), so there is nothing to backfill or freeze here
#   beyond the existence check.
#
# @arg $1 string _app - the application name (must be one of '${gh_apps_with_secrets[@]}', e.g.
#   'actions').
#
# @exitcode success=0: '<app>_secrets_order' is defined.
#
# Note: a caller-contract violation (unknown app, or '<app>_secrets_order' not defined) is
#   reported via 'bug' and aborts the process via 'exit_if_has_bugs' -- this function never
#   returns a non-zero code to a caller.
#---------------------------------------------------------------------------------------------
function validate_app_default_secrets()
{
    (( $# == 1 ))                                        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#):" \
                                                                                             "  - the name of the application (e.g., actions)"
    [[ ! -v 1 ]] || is_in "$1" "${gh_apps_with_secrets[@]}" || bug "${FUNCNAME[0]}() requires the argument to be one of (${gh_apps_with_secrets[*]}) - provided ${1:-<none>}."

    local _app=$1
    local _app_secrets_order_name="${_app,,}_secrets_order"

    is_indexed_array "$_app_secrets_order_name"          || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() the required indexed array '$_app_secrets_order_name' is not defined."
    exit_if_has_bugs
}

#---------------------------------------------------------------------------------------------
# @description Gets the default data for one application's GitHub secrets: a placeholder
#   default value ('secret_placeholder=$secret_str') for each secret name listed in
#   '<app>_secrets_order', the display order itself, and (optionally) 'is_valid_secret' as the
#   validator for every secret. For 'actions', 'NUGET_API_KEY' is skipped entirely when the
#   current '$nuget_server' is 'nuget' or 'github' -- neither needs a stored API key secret
#   (trusted publishing for nuget.org, the caller's token for GitHub Packages).
#
# @arg $1 string _app - the application name (must be one of '${gh_apps_with_secrets[@]}', e.g.
#   'actions').
# @arg $2 string __secrets - name of an associative array to receive the secrets' names and
#   placeholder values.
# @arg $3 string __secrets_order - name of an indexed array to receive the secrets' display
#   order.
# @arg $4 string (optional) name of an associative array to receive 'is_valid_secret' as every
#   secret's validation function.
#
# @exitcode success=0: Always (the output arrays were populated, or left empty if '<app>_secrets_order' is empty).
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
# shellcheck disable=SC2004 # $/${} is unnecessary on arithmetic variables.
function get_secrets_defaults()
{
    (( $# == 3 || $# == 4 ))                             || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires three or four arguments (provided $#):" \
                                                                                             "  - the name of the application (e.g., actions)" \
                                                                                             "  - the name of the associative array that will receive the secrets names and their default values" \
                                                                                             "  - the name of the indexed array that will receive the secrets display order" \
                                                                                             "  - the name of the associative array that will receive the names of the secrets' validation functions (optional)"
    [[ ! -v 1 ]] || is_in "$1" "${gh_apps_with_secrets[@]}" || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1 to be a valid application name as the first argument - provided: '$1'."
    [[ ! -v 2 ]] || is_associative_array "$2"            || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 2 to be a valid associative array name to receive the secrets names and their default values - provided: '$2'."
    [[ ! -v 3 ]] || is_indexed_array "$3"                || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 3 to be a valid indexed array name to receive the secrets display order - provided: '$3'."
    [[ ! -v 4 ]] || is_associative_array "$4"            || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 4 to be a valid associative array name to receive the names of the secrets' validation functions - provided: '$4'."
    exit_if_has_bugs

    local -r _app=$1
    local -n __secrets=$2
    local -n __secrets_order=$3

    __secrets=()
    __secrets_order=()

    local _app_secrets_order_name="${_app,,}_secrets_order"

    ! is_empty_array "$_app_secrets_order_name" || return "$success"

    local -n _app_secrets_order=$_app_secrets_order_name

    local _secret
    for _secret in "${_app_secrets_order[@]}"; do
        [[ $_app == "actions" && $_secret == "NUGET_API_KEY" ]] &&
        [[ $nuget_server == nuget || $nuget_server == github ]] && continue || true
        # BENCH_DISPATCH_PAT dispatches RebuildBenchHistory-AllRepos.yaml, which exists only in vm2.DevOps -- no
        # other repo ever needs it. Skipping it here (rather than just dropping it from actions_secrets_order) also
        # means it stays a *known* secret for vm2.DevOps itself, so --purge-secrets there never treats it as
        # "unknown or obsolete" and deletes it.
        [[ $_app == "actions" && $_secret == "BENCH_DISPATCH_PAT" ]] &&
        [[ $repo_name != "$vm2_devops_repo_name" ]] && continue || true
        __secrets[$_secret]=$secret_placeholder
    done

    __secrets_order=("${_app_secrets_order[@]}")

    if [[ -v 4 ]]; then
        local -n __secrets_validators=$4

        for _secret in "${_app_secrets_order[@]}"; do
            __secrets_validators[$_secret]=is_valid_secret
        done
    fi
}

declare -x defaults_validated=false

#---------------------------------------------------------------------------------------------
# @description Validates the integrity of the default values for the applications' variables
#   and secrets ('actions' and 'agents' for variables; 'actions', 'dependabot', and
#   'codespaces' for secrets -- 'agents' secrets are currently commented out of
#   'gh_apps_with_secrets' since agents are not used yet). Idempotent: guarded by the global
#   'defaults_validated' flag, so repeated calls after the first are a no-op.
#
# @exitcode success=0: Always (validation failures are reported via 'bug' and abort the
#   process directly via 'exit_if_has_bugs' inside the called
#   'validate_app_default_vars'/'validate_app_default_secrets').
#---------------------------------------------------------------------------------------------
function validate_defaults()
{
    ! $defaults_validated || return "$success"

    validate_app_default_vars actions
    validate_app_default_vars agents         # agents are not used yet

    validate_app_default_secrets actions
    validate_app_default_secrets dependabot
    validate_app_default_secrets codespaces  # codespaces are not used yet
    # validate_app_default_secrets agents      # agents are not used yet

    defaults_validated=true
    readonly defaults_validated
}

#===============================================================================
# Local Git repository configuration defaults
#===============================================================================

declare -xr vm2_repos
declare -xr vm2_sot_repo_name
declare -xr default_sot

declare -xrA default_local_git_settings=(
    # Set the default branch name for new repositories. This ensures that all new repositories initialized locally will have a
    # consistent default branch name "main".
    ["init.defaultBranch"]="main"

    # Set the hooks path to a githooks directory in the vm2_devops_repo, which can contain custom Git hooks for the team. This
    # allows for consistent enforcement of policies and automation of tasks such as pre-commit checks, commit message
    # validation, or post-merge actions across all team members who clone the repository.
    ["core.hooksPath"]="$vm2_repos/$vm2_devops_repo_name/scripts/githooks"

    # Set the commit template to a .gitmessage file located in the SOT directory, which can be customized by the user to provide
    # a consistent commit message format across the team. This helps ensure that all commits include necessary information such
    # as the type of change, scope, and a brief description, improving readability and traceability in the commit history.
    ["commit.template"]="$vm2_repos/$vm2_sot_repo_name/templates/$default_sot/content/.gitmessage"

    # Enforce fast-forward merges to maintain linear history, which is required by the branch protection rules. If you need to
    # merge a PR with a merge commit, you can do so locally with 'git merge --no-ff'
    ["merge.ff"]="only"

    # Enable rebasing by default when pulling to maintain a cleaner commit history, which is especially beneficial for feature
    # branches and when the team prefers a linear history. This setting can be overridden on a per-branch basis if needed.
    ["pull.rebase"]=true

    # Automatically remove remote-tracking references that no longer exist on the remote when fetching, to keep the local
    # repository clean and up-to-date.
    ["fetch.prune"]=true

    # Automatically set up tracking information when pushing a new branch to the remote, so that 'git pull' and 'git push' will
    # work without additional parameters.
    ["push.autoSetupRemote"]=true

    # Enable reuse of recorded resolution for conflicted merges (rerere) to streamline conflict resolution when rebasing or
    # merging branches with a shared history.
    ["rerere.enabled"]=true

    # Automatically stages files that have been resolved by rerere, which can further streamline the conflict resolution process
    # during rebases and merges.
    # AI: "Companion to rerere.enabled: also STAGE the auto-resolved files. Without it, rerere resolves the
    # conflict but leaves it unstaged — you still stop at every commit just to 'git add'."
    ["rerere.autoUpdate"]=true

    # Stash dirty working tree automatically before rebase/pull --rebase and reapply after. Removes the
    # "cannot rebase: you have unstaged changes" interruption mid-flow. (Promised in GIT_PLAYBOOK.md.)
    ["rebase.autoStash"]=true

    # Show the merged-base version in conflict hunks (3-way + base, compacted). You see WHAT both sides
    # changed relative to the common ancestor, not just the two results. (Promised in GIT_PLAYBOOK.md.)
    ["merge.conflictstyle"]="zdiff3"

    # Refuse a force-with-lease push if the remote has commits you haven't even fetched yet —
    # closes the race where dependabot/automation pushed while you were rebasing.
    ["push.useForceIfIncludes"]=true

    # Sort tags as versions, so 'git tag' lists v1.10.0 after v1.9.0, not before it.
    ["tag.sort"]="version:refname"

    # Custom merge driver for NuGet lockfiles, bound by the shared .gitattributes line
    # 'packages.lock.json merge=nugetlock'. Lockfiles are generated — merging them by hand is always wrong.
    # The driver takes the incoming side (%B — during a rebase that is the commit being replayed, i.e. the
    # same side as 'git checkout --theirs'), so a lockfile conflict never stops a rebase or merge; the file
    # must still be regenerated with 'dotnet restore --force-evaluate' before pushing (CI's locked-mode
    # restore catches a forgotten regeneration). In repos where the driver is not configured (clone without
    # setup-repo.sh), git falls back to the normal text merge — same behavior as before.
    ["merge.nugetlock.name"]="NuGet lockfile - take the incoming side and regenerate"
    ["merge.nugetlock.driver"]='cp -f %B %A && echo "vm2: %P auto-resolved (took the incoming side) - regenerate with: dotnet restore --force-evaluate" >&2'
)

declare -xa default_local_git_settings_order=(
    "init.defaultBranch"
    "core.hooksPath"
    "commit.template"
    "merge.ff"
    "pull.rebase"
    "fetch.prune"
    "push.autoSetupRemote"
    "rerere.enabled"
    "rerere.autoUpdate"
    "rebase.autoStash"
    "merge.conflictstyle"
    "push.useForceIfIncludes"
    "tag.sort"
    "merge.nugetlock.name"
    "merge.nugetlock.driver"
)
