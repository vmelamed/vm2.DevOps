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
declare -xrA actions_default_secrets
declare -xrA dependabot_default_secrets
declare -xrA default_ruleset

declare -x jq_entries
declare -x jq_secrets
declare -x jq_vars
declare -x jq_ruleset_id
declare -x jq_ruleset_rules
declare -x jq_status_checks

declare -xri err_invalid_nameref

declare -xr varNameRegex

declare -xr missing_state
declare -xr present_state
declare -xr undefined_default

#-------------------------------------------------------------------------------
# Summary: Fetches the current settings from GitHub API and compares them to the expected settings, reporting equalities, differences,
#   and missing values (errors).
# Parameters:
#   $1: <gh_endpoint> GitHub API endpoint path to fetch the settings from, e.g. "repos/$repo" or "repos/$repo/actions/permissions/workflow"
#   $2: <jq_transform> jq query to transform the JSON response into key=value pairs
#   $3: <expected> names of the associative array variable containing expected key-value pairs, e.g. default_repo_settings or
#       default_repo_permissions
#   $4: <modify_keys> boolean flag specifying that the keys of the expected settings should be displayed sentence-capitalized
#       and with spaces instead of underscores (for better readability), e.g. "allow_squash_merge" => "Allow squash merge"
#   $5: <results> name of an array variable (nameref) to store the results in, where the first element is the number of matches,
#       the second is the number of differences, and the third is the number of errors (missing settings)
#   $6: <keys_in_order> name of an array variable containing the display order of settings (optional, default: sorted
#       alphabetically)
# Returns:
#   Exit code: 0 on success, 2 - failed to read the settings
# Dependencies: gh CLI, jq
# Usage:
# Example:
#-------------------------------------------------------------------------------
function compare_settings()
{
    local -i rc="$success"

    [[ $# -eq 5 || $# -eq 6 ]] || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 4 or 5 arguments: <hq_path> <jq_transform> <expected_nameref_array> <mod_keys_flag> [<settings_order>]"
    }
    [[ -n "$1" ]] || {
        rc="$err_argument_value"
        error -sd 3 -ec "$rc" "Argument 1 to ${FUNCNAME[0]}() must be a non-empty string specifying the GitHub API path to fetch the settings from, e.g. 'repos/\$repo' or 'repos/\$repo/actions/permissions/workflow'."
    }
    [[ -n "$2" ]] || {
        rc="$err_argument_value"
        error -sd 3 -ec "$rc" "Argument 2 to ${FUNCNAME[0]}() must be a non-empty string specifying the jq query to transform the JSON response into key=value pairs."
    }
    is_defined_associative_array "$3" || {
        rc="$err_invalid_nameref"
        error -sd 3 -ec "$rc" "Argument 3 to ${FUNCNAME[0]}() must be the name of an associative array variable containing expected key-value pairs, e.g. default_repo_settings or default_repo_permissions."
    }
    is_boolean "$4" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "Argument 4 to ${FUNCNAME[0]}() must be a boolean flag (provided '$1') specifying that the keys of the expected settings should be capitalized and displayed with spaces instead of underscores (for better readability)."
    }
    is_defined_array "$5" || {
        rc="$err_invalid_nameref"
        error -sd 3 -ec "$rc" "Argument 5 to ${FUNCNAME[0]}() must be the name of an array variable (nameref) to store the results in: [0] is the number of matches, [1] is the number of differences, and [3] is the number of errors (missing settings)."
    }
    [[ $# -lt 6 ]] || is_defined_array "$6" || {
        rc="$err_invalid_nameref"
        error -sd 3 -ec "$rc" "Argument 6 to ${FUNCNAME[0]}() must be the name of an array variable containing the names of settings in order to compare and display (optional)."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local gh_endpoint="$1"
    local jq_transform=$2
    local -n expected_key_values="$3"
    local modify_keys="$4"
    local -n rs="$5"

    (( ${#expected_key_values[@]} > 0 )) ||
        return 0

    # query the GitHub API and transform the JSON response into key=value pairs using the provided jq query, then...
    local json

    if ! json=$(execute_gh_api_with_retry 3 2 --paginate "$gh_endpoint"); then
        error -ec "$err_tool_error" "Failed to fetch data from GitHub API: $gh_endpoint."
        return 2
    fi

    # read the key=value pairs into actual $actual_key_values
    local -A actual_key_values=()
    local key='' actual=''

    while IFS='=' read -r key actual; do
        [[ -v expected_key_values["$key"] ]] || continue
        # is_in "$key" "${!expected_key_values[@]}" &&
        actual_key_values["$key"]="$actual"
    done < <(jq -r "$jq_transform" <<< "$json")

    # put the keys in the array in display order
    local -a keys
    if [[ $# -eq 6 ]]; then
        local -n keys_in_order="$6"
        keys=("${keys_in_order[@]}")
    else
        readarray -t keys < <(printf '%s\n' "${!expected_key_values[@]}" | sort)
    fi

    local expected actual
    local -i pass=0 diff=0 errs=0

    for key in "${keys[@]}"; do
        expected="${expected_key_values[$key]}"
        if [[ $expected == "$secret_placeholder" ]]; then
            expected=$undefined_default
            [[ -v actual_key_values[$key] ]] && actual=$present_state || actual=$missing_state
        else
            expected="${expected:-$undefined_default}"
            actual=${actual_key_values[$key]:-$missing_state}
        fi

        [[ "$modify_keys" == true ]] &&
            key=${key//_/ } && key=${key^} # Replace underscores with spaces and capitalize first letter for better display

        if [[ $actual == "$missing_state" ]]; then
            [[ $expected != "$undefined_default" ]] &&
                printf "      ❌  %-36s => %s (default: '%s')\n" "$key" "$actual" "$expected" ||
                printf "      ❌  %-36s => %s\n" "$key" "$actual"
            (( ++errs ))
        elif [[ $actual == "$present_state" ]]; then
            printf "      🆗  %-36s => %s\n" "$key" "$actual"
            (( ++pass ))
        elif [[ $actual == "$expected" ]]; then
            printf "      ✅  %-36s => %s\n" "$key" "$actual"
            (( ++pass ))
        elif [[ $actual != "$expected" ]]; then
            printf "      ❓  %-36s => %s (default: '%s')\n" "$key" "$actual" "$expected"
            (( ++diff ))
        else
            # we should never be here, but just in case...
            printf "      ❌  %-36s => %s (default: '%s')\n" "$key" "$actual" "$expected"
            (( ++err ))
        fi
    done

    # shellcheck disable=SC2034 # it's a nameref
    {
        rs[0]=$pass
        rs[1]=$diff
        rs[2]=$errs
    }

    return 0
}

declare -x path_repo

declare -x path_permissions
declare -x path_rulesets

declare -x path_actions_secrets
declare -x path_dependabot_secrets

declare -x path_vars

declare -x path_main_protection_ruleset

function audit_repo()
{
    local -i pass=0 diff=0 errs=0
    local -a results=(0 0 0)

    echo "ℹ️  Audit of https://github.com/$repo"

    # --- Repo settings ---
    echo "  ℹ️  Repository settings:"
    compare_settings "$path_repo" "$jq_entries" default_repo_settings true results default_repo_settings_order || {
        error -ec "$?" "Failed to compare repository settings."
        return 2
    }
    (( pass += results[0], diff += results[1], errs += results[2], 1 ))

    # --- Actions permissions ---
    echo "  ℹ️  Actions permissions:"
    compare_settings "$path_permissions" "$jq_entries" default_repo_permissions true results || {
        error -ec "$?" "Failed to compare repository permissions settings."
        return 2
    }
    (( pass += results[0], diff += results[1], errs += results[2], 1 ))

    # --- Secrets ---
    for app in "${apps_with_secrets[@]}"; do
        local secrets_array_name="${app,,}_secrets"
        local -n app_secrets="$secrets_array_name"

        (( ${#app_secrets[@]} > 0 )) || continue

        echo "  ℹ️  ${app^} Secrets:"
        compare_settings "$path_repo/$app/secrets" "$jq_secrets" "$secrets_array_name" false results || {
            error -ec "$?" "Failed to compare $app secrets."
            return 2
        }
        (( pass += results[0], diff += results[1], errs += results[2], 1 ))
    done

    # --- Variables ---
    echo "  ℹ️  Actions Variables:"
    compare_settings "$path_vars" "$jq_vars" actions_default_vars false results || {
        error -ec "$?" "Failed to compare GitHub Actions variables."
        return 2
    }
    (( pass += results[0], diff += results[1], errs += results[2], 1 ))

    # --- Branch ruleset ---
    local rulesets_json
    rulesets_json=$(execute_gh_api_with_retry 3 2 --paginate "$path_rulesets") || true

    if [[ -z "${rulesets_json:-}" ]]; then
        echo "  ❌  Ruleset '$main_protection_rs_name' for branch '$branch' is missing"
        exit 1
    fi

    local ruleset_id
    ruleset_id=$(jq -r "$jq_ruleset_id" <<< "$rulesets_json" 2>"$_ignore")

    [[ -z "$ruleset_id" ]] && {
        echo "  ❌  Ruleset '$main_protection_rs_name' for branch '$branch' does not exist"
        exit 1;
    }

    echo "  ℹ️  Ruleset '$main_protection_rs_name' for branch '$branch' (id: $ruleset_id):"
    compare_settings "$path_rulesets/$ruleset_id" "$jq_ruleset_rules" default_ruleset true results default_ruleset_order || {
        error -ec "$?" "Failed to compare branch protection ruleset settings."
        return 2
    }
    (( pass += results[0], diff += results[1], errs += results[2], 1 ))

    echo "      ℹ️  Required status checks list:"
    local json
    json=$(execute_gh_api_with_retry 3 2 --paginate "$path_main_protection_ruleset") || {
        error -ec "$err_tool_error" "Failed to fetch data from GitHub API: $path_main_protection_ruleset."
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
    ✅  expected:  %3d
    ❓  different: %3d
    ❌  missing:   %3d\n" "$pass" "$diff" "$errs"
    echo ""
    (( errs > 0 )) && echo "⚠️  TODO: Run without '--audit' to fix the above discrepancies."
    return 0
}
