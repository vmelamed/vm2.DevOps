# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154

declare -x script_name
declare -x lib_dir

declare -x repo_name
declare -x owner
declare -x repo
declare -x visibility
declare -x branch
declare -x audit
declare -x required_checks

declare -x ci_yaml
declare -x _ci_yaml

declare -xrA default_repo_settings
declare -xrA default_repo_permissions
declare -xrA default_actions_secrets
declare -xrA default_dependabot_secrets
declare -xrA default_vars
declare -xrA default_ruleset

declare -x path_vars
declare -x path_repo
declare -x path_permissions
declare -x path_actions_secrets
declare -x path_dependabot_secrets
declare -x path_vars
declare -x path_rulesets
declare -x path_main_protection_ruleset

declare -x jq_entries
declare -x jq_secrets
declare -x jq_vars
declare -x jq_ruleset_id
declare -x jq_ruleset_rules
declare -x jq_status_checks

declare -rxi err_invalid_nameref

declare -rx varNameRegex

#-------------------------------------------------------------------------------
# Summary: Fetches the current settings from GitHub API and compares them to the expected settings, reporting equalities, differences,
#   and missing values (errors).
# Parameters:
#   $1: <hq_path> GitHub API path to fetch the settings from, e.g. "repos/${repo}" or "repos/${repo}/actions/permissions/workflow"
#   $2: <jq_transform> jq query to transform the JSON response into key=value pairs
#   $3: <expecteds> name of the associative array variable containing expected key-value pairs, e.g. default_repo_settings or default_repo_permissions
#   $4: <modify_keys> boolean flag specifying that the keys of the expected settings should be displayed sentence-capitalized and with spaces instead of underscores (for better readability), e.g. "allow_squash_merge" => "Allow squash merge"
#   $5: <keys_in_order> name of an array variable containing the display order of settings (optional, default: sorted alphabetically)
# Returns:
#   Exit code: 0 on success, 2 - failed to read the settings
#   stdout: the number of matches, differences from expected, and errors - not found: <matches> <differences> <errors>
# Dependencies: gh CLI, jq
# Usage:
# Example:
#-------------------------------------------------------------------------------
function compare_settings()
{
    [[ $# -eq 5 || $# -eq 6 ]] ||
        error 3 "${FUNCNAME[0]}() requires 4 or 5 arguments: <hq_path> <jq_transform> <expected_nameref_array> <mod_keys_flag> [<settings_order>]"
    [[ -n "$1" ]] ||
        error 3 "Argument 1 to ${FUNCNAME[0]}() must be a non-empty string specifying the GitHub API path to fetch the settings from, e.g. 'repos/\${repo}' or 'repos/\${repo}/actions/permissions/workflow'.";
    [[ -n "$2" ]] ||
        error 3 "Argument 2 to ${FUNCNAME[0]}() must be a non-empty string specifying the jq query to transform the JSON response into key=value pairs.";
    is_defined_associative_array "$3" ||
        error 3 "Argument 3 to ${FUNCNAME[0]}() must be the name of an associative array variable containing expected key-value pairs, e.g. default_repo_settings or default_repo_permissions."
    is_boolean "$4" ||
        error 3 "Argument 4 to ${FUNCNAME[0]}() must be a boolean flag specifying that the keys of the expected settings should be capitalized and displayed with spaces instead of underscores (for better readability)."
    [[ $# -lt 6 ]] || is_defined_array "$6" ||
        error 3 "Argument 5 to ${FUNCNAME[0]}() is optional. If provided, it must be the name of an array variable containing the names of settings in order to compare and display."

    ! has_errors || return "$err_invalid_arguments"

    local hq_path="$1"
    local jq_transform=$2
    local -n expecteds="$3"
    local modify_keys="$4"
    local -n results="$5"

    # query the GitHub API and transform the JSON response into key=value pairs using the provided jq query, then...
    local json

    if ! json=$(gh api --paginate "$hq_path"); then
        error "Failed to fetch data from GitHub API: $hq_path."
        return 2
    fi

    # read the key=value pairs into actuals
    local -A actuals=()
    local key='' actual=''

    while IFS='=' read -r key actual; do
        is_in "$key" "${!expecteds[@]}" &&
            actuals["$key"]="$actual"
    done < <(jq -r "$jq_transform" <<< "$json")

    # put the keys in the array in display order
    local -a keys
    if [[ $# -eq 6 ]]; then
        local -n keys_in_order="$6"
        keys=("${keys_in_order[@]}")
    else
        mapfile -t keys < <(printf '%s\n' "${!expecteds[@]}" | sort)
    fi

    local expected actual
    local -i pass=0 diff=0 errs=0

    for key in "${keys[@]}"; do
        expected="${expecteds[$key]:-"<not defined>"}"

        [[ "$expected" == "$secret_placeholder" ]] && expected="<set>"

        actual="${actuals[$key]:-"<missing>"}"

        [[  "$modify_keys" == true ]] &&
            key=${key//_/ } && key=${key^} # Replace underscores with spaces and capitalize first letter for better display

        if [[ "$actual" == "<missing>" ]]; then
            printf "      ❌  %-36s => %s (default: '%s')\n" "$key" "$actual" "$expected"
            (( ++errs ))
        elif [[ "$expected" == "<not defined>" ]]; then
            printf "      ❓  %-36s => %s (default: '%s')\n" "$key" "$actual" "$expected"
            (( ++diff ))
        elif [[ "$actual" != "$expected" ]]; then
            printf "      ❓  %-36s => %s (default: '%s')\n" "$key" "$actual" "$expected"
            (( ++diff ))
        elif [[ "$actual" == "<set>" ]]; then
            printf "      🆗  %-36s => %s\n" "$key" "$actual"
            (( ++pass ))
        else
            printf "      ✅  %-36s => %s\n" "$key" "$actual"
            (( ++pass ))
        fi
    done

    # shellcheck disable=SC2034 # it's a nameref
    results="$pass $diff $errs"
    return 0
}

function audit_repo()
{
    local -i pass=0 diff=0 errs=0
    local -i p=0 m=0 e=0
    local compare_results=""

    echo "ℹ️  Audit"

    # --- Repo settings ---
    echo "  ℹ️  Repository settings:"

    compare_settings "$path_repo" "$jq_entries" default_repo_settings true compare_results default_repo_settings_order
    read -r p m e <<< "$compare_results"
    (( pass += p, diff += m, errs += e, 1 ))

    # --- Actions permissions ---
    echo "  ℹ️  Actions permissions:"
    compare_settings "$path_permissions" "$jq_entries" default_repo_permissions true compare_results
    read -r p m e <<< "$compare_results"
    (( pass += p, diff += m, errs += e, 1 ))

    # --- Secrets ---
    echo "  ℹ️  Actions Secrets:"
    compare_settings "$path_actions_secrets" "$jq_secrets" default_actions_secrets false compare_results
    read -r p m e <<< "$compare_results"
    (( pass += p, diff += m, errs += e, 1 ))

    # --- Secrets ---
    echo "  ℹ️  Dependabot Secrets:"
    compare_settings "$path_dependabot_secrets" "$jq_secrets" default_dependabot_secrets false compare_results
    read -r p m e <<< "$compare_results"
    (( pass += p, diff += m, errs += e, 1 ))

    # --- Variables ---
    echo "  ℹ️  Variables:"
    compare_settings "$path_vars" "$jq_vars" default_vars false compare_results
    read -r p m e <<< "$compare_results"
    (( pass += p, diff += m, errs += e, 1 ))

    # --- Branch ruleset ---
    local rulesets_json
    rulesets_json=$(execute_gh_api_with_retry 3 2 --paginate "$path_rulesets") || true

    if [[ -z "${rulesets_json:-}" ]]; then
        echo "  ❌  Ruleset '$main_protection_rs_name' for branch '${branch}' is missing"
        exit 1
    fi

    local ruleset_id
    ruleset_id=$(jq -r "$jq_ruleset_id" <<< "$rulesets_json" 2>"$_ignore")

    [[ -z "$ruleset_id" ]] && {
        echo "  ❌  Ruleset '$main_protection_rs_name' for branch '${branch}' does not exist"
        exit 1;
    }

    echo "  ℹ️  Ruleset '$main_protection_rs_name' for branch '${branch}' (id: $ruleset_id):"

    compare_settings "$path_main_protection_ruleset" "$jq_ruleset_rules" default_ruleset true compare_results default_ruleset_order
    read -r p m e <<< "$compare_results"
    (( pass += p, diff += m, errs += e, 1 ))

    echo "      ℹ️  Required status checks list:"
    local json
    json=$(gh api --paginate "$path_main_protection_ruleset") || {
        error "Failed to fetch data from GitHub API: $path_main_protection_ruleset."
        return 2
    }
    local -a present_checks=()
    local check

    while read -r check; do
        present_checks+=("$check")
    done < <(jq -r "$jq_status_checks" <<< "$json")

    for check in "${required_checks[@]}"; do
        if is_in "$check" "${present_checks[@]}"; then
            printf "          ✅  %-32s => present\n" "$check"
            (( ++pass ))
        else
            printf "          ❌  %-32s => missing\n" "$check"
            (( ++errs ))
        fi
    done

    # --- Local Git Settings ---
    echo "  ℹ️  Local Git Settings:"

    local key expected actual rc=0
    for key in "${default_local_git_settings_order[@]}"; do
        expected="${default_local_git_settings[$key]}"
        actual=$(git -C "$repo_path" config --local --get "$key" 2>"$_ignore") || rc=$?
        if [[ $rc -ne "$success" ]]; then
            printf "      ❌  %-36s => %s (default: '%s')\n" "$key" "$actual" "$expected"
            (( ++errs ))
        elif [[ "$actual" != "$expected" ]]; then
            printf "      ❓  %-36s => %s (default: '%s')\n" "$key" "$actual" "$expected"
            (( ++diff ))
        else
            printf "      ✅  %-36s => %s\n" "$key" "$actual"
            (( ++pass ))
        fi
    done

    # --- Summary ---
    printf "
──────────────────────
ℹ️  Totals:
    ✅  passed:    %3d
    ❓  different: %3d
    ❌  missing:   %3d\n" "$pass" "$diff" "$errs"

    (( errs > 0 )) && echo "⚠️  TODO: Run without '--audit' to fix discrepancies."
    echo ""

    info "Audit of https://github.com/${repo} completed."
    return 0
}
