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
# @description Fetches the current settings from the GitHub API and compares them to the expected settings,
# reporting matches, differences, and missing values (errors) to stdout in a formatted list.
#
# For each key, the expected value is looked up in the `expected` associative array. If the expected value is the
# secret placeholder (`$secret_placeholder`), the comparison degrades to presence-only: the actual value is reported
# as either present or missing, never compared for equality (this is how secrets, whose real values this script
# never reads back, are audited). Otherwise the actual and expected values are compared for equality.
#
# @arg $1 string GitHub API endpoint path to fetch the settings from, e.g. `repos/$repo` or
#   `repos/$repo/actions/permissions/workflow`.
# @arg $2 string jq query used to transform the JSON response into `key=value` lines.
# @arg $3 nameref Name of the associative array variable containing the expected key-value pairs, e.g.
#   `default_repo_settings` or `default_repo_permissions`.
# @arg $4 bool When `true`, display keys sentence-capitalized with spaces instead of underscores (for readability),
#   e.g. `allow_squash_merge` => `Allow squash merge`.
# @arg $5 nameref Name of an array variable to store the results in: `[0]` is the number of matches, `[1]` is the
#   number of differences, and `[2]` is the number of errors (missing settings).
# @arg $6 nameref Name of an array variable containing the display order of the setting keys (optional; default:
#   sorted alphabetically).
#
# @exitcode 0 Success (including the case where `expected` is empty and the function returns immediately).
# @exitcode 2 Invalid arguments, or failed to fetch data from the GitHub API.
# @exitcode 66 error after executing a tool - most likely a bug.
#
# @stdout One formatted line per compared key, prefixed with an emoji marker (match/present, difference, or
#   missing).
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
        rc="$err_tool_error"
        error -ec "$rc" "Failed to fetch data from GitHub API: $gh_endpoint."
        return "$rc"
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
            (( ++errs ))
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

#-------------------------------------------------------------------------------
# @description Runs a full, read-only audit of the target GitHub repository against the vm2 conventions, comparing
# repository settings, Actions workflow permissions, per-app secrets, Actions variables, the branch-protection
# ruleset (and its required status checks), and the local Git config -- then prints a totals summary. Requires
# `initialize_gh_paths`, `initialize_jq_queries`, and `resolve_github_app_ids` to have already run so the
# `path_*`/`jq_*` variables and `required_checks` are populated.
#
# @exitcode 0 Audit completed and printed.
# @exitcode 1 The branch-protection ruleset for the configured branch is missing or could not be found (exits the
#   whole script via `exit 1`, not just this function).
# @exitcode 2 A `compare_settings` call failed (e.g. GitHub API fetch error), or fetching the required-status-checks
#   list from the GitHub API failed.
#
# @stdout A multi-section, emoji-annotated audit report (repository settings, Actions permissions, secrets per app,
#   Actions variables, branch ruleset, required status checks, local Git settings) followed by a totals summary.
#-------------------------------------------------------------------------------
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
