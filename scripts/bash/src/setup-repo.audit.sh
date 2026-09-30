# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x script_name
declare -x lib_dir

declare -xr error_em
declare -xr ok_em
declare -xr check_em
declare -xr question_em
declare -xr info_em
declare -xr warn_em
declare -xr not_eq_em

declare -xri success
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_argument_type
declare -xri err_invalid_nameref
declare -xri err_tool_error

declare -x _ignore
declare -xr secret_str

declare -x repo_path
declare -x repo
declare -x branch
declare -x required_checks

declare -xr missing_state
declare -xr present_state
declare -xr undefined_default
declare -xrA default_repo_settings
declare -xra default_repo_settings_order
declare -xrA default_repo_permissions
declare -xrA default_ruleset
declare -xra default_ruleset_order
declare -xa apps_with_vars
declare -xa apps_with_secrets
declare -xA default_local_git_settings
declare -xa default_local_git_settings_order

declare -xA actions_secrets_defaults
declare -xrA dependabot_secrets
declare -xrA agents_secrets
declare -xrA codespaces_secrets

declare -x main_protection_rs_name

declare -x jq_entries
declare -x jq_secrets
declare -x jq_vars
declare -x jq_ruleset_id
declare -x jq_ruleset_rules
declare -x jq_status_checks

declare -x purge_vars=false
declare -x purge_secrets=false

declare -r key_matches="matches"
declare -r key_diffs="diffs"
declare -r key_missing="missing"
declare -r key_unknowns="unknowns"

#---------------------------------------------------------------------------------------------
# @description Fetches the current settings from the GitHub API and compares them to the expected settings,
# reporting matches, differences, and missing values (errors) to stdout in a formatted list.
#
# For each key, the expected value is looked up in the `expected` associative array. If the expected value is the
# secret placeholder (`$secret_str`), the comparison degrades to presence-only: the actual value is reported
# as either present or missing, never compared for equality (this is how secrets, whose real values this script
# never reads back, are audited). Otherwise the actual and expected values are compared for equality.
#
# Notes:
#   - Will exit the script if an invalid argument(s) is/are provided with exit codes
#
# @arg $1 string GitHub API endpoint path to fetch the settings from, e.g. `repos/$repo` or
#   `repos/$repo/actions/permissions/workflow`.
# @arg $2 string jq query used to transform the JSON response into `key=value` lines.
# @arg $3 bool when `true`, in the following associative array, change the keys to sentence-capitalized with spaces instead of
#   underscores (for UI readability), e.g. `allow_squash_merge` => `Allow squash merge`.
# @arg $4 boolean when `true`, indicates that the unknown or obsolete values should be included in the comparison.
# @arg $5 nameref to an associative array variable containing the expected key-value pairs, e.g. `default_repo_settings` or
#   `default_repo_permissions`.
# @arg $6 nameref to an associative array variable to store the summary results in, keyed by:
#   $key_matches   - number of exact matches
#   $key_diffs     - number of differences
#   $key_missing   - number of errors (e.g., missing settings)
#   $key_unknowns  - number of unknown or obsolete values (strings or vars)
# @arg $7 nameref - the name of an indexed array variable containing the display order of the setting keys (optional, default:
#   sort alphabetically).
#
# @exitcode success/positive=0: (including the case where `expected` is empty and the function returns immediately).
# @exitcode err_tool_error=66: error after executing a tool - most likely a bug.
#
# @stdout One formatted line per compared key, prefixed with an emoji marker (match/present, difference, or
#   missing).
#---------------------------------------------------------------------------------------------
function compare_settings()
{
    local -i _rc="$success"

    (( $# == 6 || $# == 7 ))                             || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires six or seven arguments (provided $#):" \
                                                                                             "  - the GitHub API endpoint path to fetch settings from" \
                                                                                             "  - jq transform JSON -> key=value lines" \
                                                                                             "  - display-format flag: if true, change expected-values array's keys to sentence-capitalized" \
                                                                                             "  - unknown-or-obsolete flag: if true, include unknown or obsolete values in the comparison" \
                                                                                             "  - name of an associative array variable to store the expected key-values" \
                                                                                             "  - name of an indexed array variable to store the summary results: [matches], [diffs], [errors], and [unknowns]" \
                                                                                             "  - optional name of an indexed array with the display order of the keys."
    [[ ! -v 1 || -n "$1" ]]                              || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 1, the GitHub API path, to be non-empty (provided '${1:-<none>}'); for example, 'repos/\$repo'."
    [[ ! -v 2 || -n "$2" ]]                              || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2, the jq transformation query, to be non-empty (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_boolean "$3"                      || bug -ec "$err_argument_type"     "${FUNCNAME[0]}() requires argument 3, the display-key formatting flag, to be 'true' or 'false' (provided '${3:-<none>}')."
    [[ ! -v 4 ]] || is_boolean "$4"                      || bug -ec "$err_argument_type"     "${FUNCNAME[0]}() requires argument 4, the display unknown key flag, to be 'true' or 'false' (provided '${4:-<none>}')."
    [[ ! -v 5 ]] || is_associative_array "$5"            || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 5 to name an associative array containing expected key-value pairs (provided '${5:-<none>}')."
    [[ ! -v 6 ]] || is_associative_array "$6"            || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 6 to name an indexed array for summary results: [matches], [diffs], [errors], and [unknowns] (provided '${6:-<none>}')."
    [[ ! -v 7 || -z "${7:-}" ]] || is_indexed_array "$7" || bug -ec "$err_invalid_nameref"   "${FUNCNAME[0]}() requires argument 7 (if present) to name an indexed array containing the display order (provided '${7:-<none>}')."
    exit_if_has_bugs

    local -n _expected_key_values="$5"

    (( ${#_expected_key_values[@]} > 0 )) || return "$success"

    local _gh_endpoint="$1"
    local _jq_transform=$2
    local _modify_keys="$3"
    local _show_unknowns="$4"
    local -n __results="$6"
    local -a _keys

    if [[ -n "${7:-}" ]]; then
        # use the keys in the provided display order
        local -n _keys_in_order="$7"
        _keys=("${_keys_in_order[@]}")
        # make sure that all expected keys are included in the display order
        for _var in "${!_expected_key_values[@]}"; do
            is_in "$_var" "${_keys[@]}" || {
                warning "The variable '$_var' is not listed in the display order. Appending it at the end of the array."
                _keys+=("$_var")
            }
        done
    else
        # otherwise put the keys in the array in sorted order
        readarray -t _keys < <(printf '%s\n' "${!_expected_key_values[@]}" | sort)
    fi

    # query the GitHub API and transform the JSON response into key=value pairs using the provided jq query, then...
    local _json

    if ! _json=$(execute_gh_api_with_retry 3 2 --paginate "$_gh_endpoint"); then
        _rc="$err_tool_error"
        error -ec "$_rc" "Failed to fetch data from GitHub API: $_gh_endpoint."
        return "$_rc"
    fi

    # read the key=value pairs into $actual_key_values
    local -A _known_key_values=()
    local -A _unknown_key_values=()

    local _key='' _value=''
    while IFS='=' read -r _key _value; do
        [[ -v _expected_key_values["$_key"] ]] && _known_key_values["$_key"]="$_value" || _unknown_key_values["$_key"]="$_value"
    done < <(jq -r "$_jq_transform" <<< "$_json")

    local _expected_value='' _actual_value=''

    for _key in "${_keys[@]}"; do
        if [[ $_key == --* ]]; then
            printf "    ➡️  %-38s %s\n" "${_key#--}" "────────────────────────────────────────────────────────────────────────"
            continue
        fi
        if [[ ! -v _expected_key_values["$_key"] ]]; then
            trace "Skipping unknown key '$_key'."
            continue
        fi

        _expected_value="${_expected_key_values[$_key]}"
        if [[ $_expected_value == "$secret_str" ]]; then
            _expected_value=$undefined_default # mask as undefined expected value (which it is)
            [[ -v _known_key_values[$_key] ]] &&
                _actual_value=$present_state || # if the key exists, mark it as present, otherwise mark it as missing
                _actual_value=$missing_state
        else
            _expected_value="${_expected_value:-$undefined_default}"
            _actual_value=${_known_key_values[$_key]:-$missing_state}
        fi

        [[ "$_modify_keys" == true ]] &&
            _key=${_key//_/ } && _key=${_key^} # Replace underscores with spaces and capitalize first letter for better display

        # At this point we have 3 things to display: the key, the actual value, and the expected value:
        if [[ $_actual_value == "$missing_state" ]]; then
            if [[ $_expected_value != "$undefined_default" ]]; then
                printf "      $error_em  %-36s => %s (default: '%s')\n" "$_key" "$_actual_value" "$_expected_value"
            else
                printf "      $error_em  %-36s => %s\n" "$_key" "$_actual_value"
            fi
            # not a good state - the actual value is missing and must be fixed by the user
            (( ++__results["$key_missing"] )) # missing

        elif [[ $_actual_value == "$_expected_value" ]]; then
            # good state, actual value matches the expected (default) value
            printf "      $check_em  %-36s => %s\n" "$_key" "$_actual_value"
            (( ++__results["$key_matches"] )) # matches

        elif [[ $_actual_value == "$present_state" ]]; then
            printf "      $ok_em  %-36s => %s\n" "$_key" "$_actual_value"
            # good state, everything is as expected: expected: <unknown>, actual: <present>, but we don't want to reveal the secret
            (( ++__results["$key_matches"] )) # matches

        elif [[ $_actual_value != "$_expected_value" ]]; then
            # OK state - the actual value differs from the expected value
            printf "      $question_em  %-36s => %s (default: '%s')\n" "$_key" "$_actual_value" "$_expected_value"
            (( ++__results["$key_diffs"] )) # diffs

        else
            # we should never be here, but just in case...
            printf "      $error_em  %-36s => %s (default: '%s')\n" "$_key" "$_actual_value" "$_expected_value"
            (( ++__results["$key_missing"] )) # missing

        fi
    done

    if $_show_unknowns; then
        for _key in "${!_unknown_key_values[@]}"; do
            # these are most likely unknown or unexpected key-value pairs:
            printf "      $not_eq_em  %-36s => %s\n" "$_key" "${_unknown_key_values[$_key]}"
            (( ++__results["$key_unknowns"] )) # others
        done
    fi

    return 0
}

declare -x path_repo

declare -x path_permissions
declare -x path_rulesets

declare -x path_actions_secrets
declare -x path_dependabot_secrets

declare -x path_vars

declare -x path_main_protection_ruleset

#---------------------------------------------------------------------------------------------
# @description Runs a full, read-only audit of the target GitHub repository against the vm2 conventions, comparing
# repository settings, Actions workflow permissions, per-app secrets, Actions variables, the branch-protection
# ruleset (and its required status checks), and the local Git config -- then prints a totals summary. Requires
# `initialize_gh_paths`, `initialize_jq_queries`, and `resolve_github_app_ids` to have already run so the
# `path_*`/`jq_*` variables and `required_checks` are populated.
#
# @exitcode success/positive=0: Audit completed and printed.
# @exitcode failure/negative=1: The branch-protection ruleset for the configured branch is missing or could not be found (exits the
#   whole script via `exit 1`, not just this function).
#
# @stdout A multi-section, emoji-annotated audit report (repository settings, Actions permissions, secrets per app,
#   Actions variables, branch ruleset, required status checks, local Git settings) followed by a totals summary.
#---------------------------------------------------------------------------------------------
function audit_repo()
{
    local -A _results=(
        [$key_matches]=0
        [$key_diffs]=0
        [$key_missing]=0
        [$key_unknowns]=0
    )

    echo "$info_em  Audit of https://github.com/$repo"

    # --- Repo settings ---
    echo "  $info_em  Repository settings:"
    compare_settings "$path_repo" "$jq_entries" true false default_repo_settings _results default_repo_settings_order || {
        error -ec "$?" "Failed to compare repository settings."
        return 2
    }

    # --- Actions permissions ---
    echo "  $info_em  Actions permissions:"
    compare_settings "$path_permissions" "$jq_entries" true false default_repo_permissions _results || {
        error -ec "$?" "Failed to compare repository permissions settings."
        return 2
    }

    local _app

    # --- Variables ---
    local -A _vars_defaults
    local -a _vars_order

    for _app in "${apps_with_vars[@]}"; do
        get_vars_defaults "${_app,,}" _vars_defaults _vars_order

        is_empty_array _vars_defaults && continue

        echo "  $info_em  ${_app^} Variables:"
        compare_settings "$path_vars" "$jq_vars" false true _vars_defaults _results _vars_order || {
            error -ec "$?" "Failed to compare GitHub ${_app^} variables."
            return 2
        }
    done

    # --- Secrets ---
    local -A _secrets_defaults
    local -a _secrets_order

    for _app in "${apps_with_secrets[@]}"; do
        get_secrets_defaults "${_app,,}" _secrets_defaults _secrets_order

        is_empty_array _secrets_defaults && continue

        echo "  $info_em  ${_app^} Secrets:"
        compare_settings "$path_repo/$_app/secrets" "$jq_secrets" false true _secrets_defaults _results _secrets_order || {
            error -ec "$?" "Failed to compare $_app secrets."
            return 2
        }
    done

    # --- Branch ruleset ---
    local _rulesets_json
    _rulesets_json=$(execute_gh_api_with_retry 3 2 --paginate "$path_rulesets") || true

    if [[ -z "${_rulesets_json:-}" ]]; then
        echo "  $error_em  Ruleset '$main_protection_rs_name' for branch '$branch' is missing"
        exit 1
    fi

    local _ruleset_id
    _ruleset_id=$(jq -r "$jq_ruleset_id" <<< "$_rulesets_json" 2>"$_ignore")

    [[ -z "$_ruleset_id" ]] && {
        echo "  $error_em  Ruleset '$main_protection_rs_name' for branch '$branch' does not exist"
        exit 1;
    }

    echo "  $info_em  Ruleset '$main_protection_rs_name' for branch '$branch' (id: $_ruleset_id):"
    compare_settings "$path_rulesets/$_ruleset_id" "$jq_ruleset_rules" true false default_ruleset _results default_ruleset_order || {
        error -ec "$?" "Failed to compare branch protection ruleset settings."
        return 2
    }

    echo "      $info_em  Required status checks list:"
    local _json
    _json=$(execute_gh_api_with_retry 3 2 --paginate "$path_main_protection_ruleset") || {
        error -ec "$err_tool_error" "Failed to fetch data from GitHub API: $path_main_protection_ruleset."
        return 2
    }
    local -a _present_checks=()
    local _check

    while read -r _check; do
        _present_checks+=("$_check")
    done < <(jq -r "$jq_status_checks" <<< "$_json")

    for _check in "${required_checks[@]}"; do
        # [[ -z "$_check" || $_check == null ]] && continue
        if is_in "$_check" "${_present_checks[@]}"; then
            printf "          $check_em  %-32s => present\n" "$_check"
            (( ++_results["$key_matches"] ))
        else
            printf "          $error_em  %-32s => missing\n" "$_check"
            (( ++_results["$key_missing"] ))
        fi
    done

    # --- Local Git Settings ---
    echo "  $info_em  Local Git Settings:"

    local _key _expected _actual
    local -i _rc
    for _key in "${default_local_git_settings_order[@]}"; do
        _rc=$success
        _expected="${default_local_git_settings[$_key]}"
        _actual=$(git -C "$repo_path" config --local --get "$_key" 2>"$_ignore") || _rc=$?
        if [[ $_rc -ne "$success" ]]; then
            printf "      $error_em  %-36s => %s (default: '%s')\n" "$_key" "$_actual" "$_expected"
            (( ++_results["$key_missing"] ))
        elif [[ "$_actual" != "$_expected" ]]; then
            printf "      $question_em  %-36s => %s (default: '%s')\n" "$_key" "$_actual" "$_expected"
            (( ++_results["$key_diffs"] ))
        else
            printf "      $check_em  %-36s => %s\n" "$_key" "$_actual"
            (( ++_results["$key_matches"] ))
        fi
    done

    # --- Summary ---
    printf "
──────────────────────
$info_em  Totals:
    $check_em  expected:  %3d
    $error_em  missing:   %3d
    $question_em  different: %3d
    $not_eq_em  unknown:   %3d\n\n" "${_results[$key_matches]}" "${_results[$key_missing]}" "${_results[$key_diffs]}" "${_results[$key_unknowns]}"
    (( _results[$key_missing]  > 0 )) && echo "$warn_em  TODO: To fix the above discrepancies run the script without '--audit'." || true
    (( _results[$key_unknowns] > 0 )) && echo "$warn_em  TODO: To purge the unknown/obsolete variables and secrets run the script without '--audit' and with '--purge-vars' and/or '--purge_secrets', optionally with '--interactive-vars' and/or '--interactive-secrets'." || true

    return "$success"
}
