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

declare -xr missing_state
declare -xr present_state
declare -xr undefined_default

#-------------------------------------------------------------------------------
# @description Fetches the current settings from the GitHub API and compares them to the expected settings,
# reporting matches, differences, and missing values (errors) to stdout in a formatted list.
#
# For each key, the expected value is looked up in the `expected` associative array. If the expected value is the
# secret placeholder (`$secret_str`), the comparison degrades to presence-only: the actual value is reported
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
    local -i _rc="$success"

    (( $# == 5 || $# == 6 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires five or six arguments (provided $#): the API path, jq transform, expected-values array, display-format flag, results array, and optional key-order array."
    }
    [[ -n "$1" ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the GitHub API path, to be non-empty (provided '${1-<missing>}'); for example, 'repos/\$repo'."
    }
    [[ -n "$2" ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the jq transformation query, to be non-empty (provided '${2-<missing>}')."
    }
    [[ -v 3 ]] && is_defined_associative_array "$3" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 3 to name an associative array containing expected key-value pairs (provided '${3-<missing>}')."
    }
    [[ -v 4 ]] && is_boolean "$4" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 4, the display-key formatting flag, to be 'true' or 'false' (provided '${4-<missing>}')."
    }
    [[ -v 5 ]] && is_defined_array "$5" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 5 to name an indexed results array: [0] matches, [1] differences, and [2] errors (provided '${5-<missing>}')."
    }
    [[ ! -v 6 ]] || is_defined_array "$6" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 6 to name an indexed array containing the display order (provided '${6-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _gh_endpoint="$1"
    local _jq_transform=$2
    local -n _expected_key_values="$3"
    local _modify_keys="$4"
    local -n _rs="$5"

    (( ${#_expected_key_values[@]} > 0 )) ||
        return 0

    # query the GitHub API and transform the JSON response into key=value pairs using the provided jq query, then...
    local _json

    if ! _json=$(execute_gh_api_with_retry 3 2 --paginate "$_gh_endpoint"); then
        _rc="$err_tool_error"
        error -ec "$_rc" "Failed to fetch data from GitHub API: $_gh_endpoint."
        return "$_rc"
    fi

    # read the key=value pairs into $actual_key_values
    local -A _actual_key_values=()
    local _key='' _actual=''

    while IFS='=' read -r _key _actual; do
        [[ -v _expected_key_values["$_key"] ]] && _actual_key_values["$_key"]="$_actual"
    done < <(jq -r "$_jq_transform" <<< "$_json")

    # put the keys in the array in display order
    local -a _keys
    if [[ $# -eq 6 ]]; then
        local -n _keys_in_order="$6"
        _keys=("${_keys_in_order[@]}")
    else
        readarray -t _keys < <(printf '%s\n' "${!_expected_key_values[@]}" | sort)
    fi

    local _expected _actual
    local -i _pass=0 _diff=0 _errs=0

    for _key in "${_keys[@]}"; do
        _expected="${_expected_key_values[$_key]}"
        if [[ $_expected == "$secret_str" ]]; then
            _expected=$undefined_default
            [[ -v _actual_key_values[$_key] ]] &&
                _actual=$present_state ||
                _actual=$missing_state
        else
            _expected="${_expected:-$undefined_default}"
            _actual=${_actual_key_values[$_key]:-$missing_state}
        fi

        [[ "$_modify_keys" == true ]] &&
            _key=${_key//_/ } && _key=${_key^} # Replace underscores with spaces and capitalize first letter for better display

        if [[ $_actual == "$missing_state" ]]; then
            if [[ $_expected != "$undefined_default" ]]; then
                printf "      ❌  %-36s => %s (default: '%s')\n" "$_key" "$_actual" "$_expected"
            else
                printf "      ❌  %-36s => %s\n" "$_key" "$_actual"
            fi
            (( ++_errs ))
        elif [[ $_actual == "$present_state" ]]; then
            printf "      🆗  %-36s => %s\n" "$_key" "$_actual"
            (( ++_pass ))
        elif [[ $_actual == "$_expected" ]]; then
            printf "      ✅  %-36s => %s\n" "$_key" "$_actual"
            (( ++_pass ))
        elif [[ $_actual != "$_expected" ]]; then
            printf "      ❓  %-36s => %s (default: '%s')\n" "$_key" "$_actual" "$_expected"
            (( ++_diff ))
        else
            # we should never be here, but just in case...
            printf "      ❌  %-36s => %s (default: '%s')\n" "$_key" "$_actual" "$_expected"
            (( ++_errs ))
        fi
    done

    # shellcheck disable=SC2034 # it's a nameref
    {
        _rs[0]=$_pass
        _rs[1]=$_diff
        _rs[2]=$_errs
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
    local -i _pass=0 _diff=0 _errs=0
    local -a _results=(0 0 0)

    echo "ℹ️  Audit of https://github.com/$repo"

    # --- Repo settings ---
    echo "  ℹ️  Repository settings:"
    compare_settings "$path_repo" "$jq_entries" default_repo_settings true _results default_repo_settings_order || {
        error -ec "$?" "Failed to compare repository settings."
        return 2
    }
    (( _pass += _results[0], _diff += _results[1], _errs += _results[2], 1 ))

    # --- Actions permissions ---
    echo "  ℹ️  Actions permissions:"
    compare_settings "$path_permissions" "$jq_entries" default_repo_permissions true _results || {
        error -ec "$?" "Failed to compare repository permissions settings."
        return 2
    }
    (( _pass += _results[0], _diff += _results[1], _errs += _results[2], 1 ))

    # --- Variables ---
    echo "  ℹ️  Actions Variables:"
    compare_settings "$path_vars" "$jq_vars" actions_default_vars false _results || {
        error -ec "$?" "Failed to compare GitHub Actions variables."
        return 2
    }
    (( _pass += _results[0], _diff += _results[1], _errs += _results[2], 1 ))

    # --- Secrets ---
    for app in "${apps_with_secrets[@]}"; do
        local _secrets_array_name="${app,,}_secrets"
        local -n _app_secrets="$_secrets_array_name"

        (( ${#_app_secrets[@]} > 0 )) || continue
        if [[ ${actions_default_vars["NUGET_SERVER"]} == 'nuget' ]]; then
            unset 'app_secrets["NUGET_API_KEY"]'
        fi

        echo "  ℹ️  ${app^} Secrets:"
        compare_settings "$path_repo/$app/secrets" "$jq_secrets" "$_secrets_array_name" false _results || {
            error -ec "$?" "Failed to compare $app secrets."
            return 2
        }
        (( _pass += _results[0], _diff += _results[1], _errs += _results[2], 1 ))
    done

    # --- Branch ruleset ---
    local _rulesets_json
    _rulesets_json=$(execute_gh_api_with_retry 3 2 --paginate "$path_rulesets") || true

    if [[ -z "${_rulesets_json:-}" ]]; then
        echo "  ❌  Ruleset '$main_protection_rs_name' for branch '$branch' is missing"
        exit 1
    fi

    local _ruleset_id
    _ruleset_id=$(jq -r "$jq_ruleset_id" <<< "$_rulesets_json" 2>"$_ignore")

    [[ -z "$_ruleset_id" ]] && {
        echo "  ❌  Ruleset '$main_protection_rs_name' for branch '$branch' does not exist"
        exit 1;
    }

    echo "  ℹ️  Ruleset '$main_protection_rs_name' for branch '$branch' (id: $_ruleset_id):"
    compare_settings "$path_rulesets/$_ruleset_id" "$jq_ruleset_rules" default_ruleset true _results default_ruleset_order || {
        error -ec "$?" "Failed to compare branch protection ruleset settings."
        return 2
    }
    (( _pass += _results[0], _diff += _results[1], _errs += _results[2], 1 ))

    echo "      ℹ️  Required status checks list:"
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
        if is_in "$_check" "${_present_checks[@]}"; then
            printf "          ✅  %-32s => present\n" "$_check"
            (( ++_pass ))
        else
            printf "          ❌  %-32s => missing\n" "$_check"
            (( ++_errs ))
        fi
    done

    # --- Local Git Settings ---
    echo "  ℹ️  Local Git Settings:"

    local _key _expected _actual _rc=0
    for _key in "${default_local_git_settings_order[@]}"; do
        _expected="${default_local_git_settings[$_key]}"
        _actual=$(git -C "$repo_path" config --local --get "$_key" 2>"$_ignore") || _rc=$?
        if [[ $_rc -ne "$success" ]]; then
            printf "      ❌  %-36s => %s (default: '%s')\n" "$_key" "$_actual" "$_expected"
            (( ++_errs ))
        elif [[ "$_actual" != "$_expected" ]]; then
            printf "      ❓  %-36s => %s (default: '%s')\n" "$_key" "$_actual" "$_expected"
            (( ++_diff ))
        else
            printf "      ✅  %-36s => %s\n" "$_key" "$_actual"
            (( ++_pass ))
        fi
    done

    # --- Summary ---
    printf "
──────────────────────
ℹ️  Totals:
    ✅  expected:  %3d
    ❓  different: %3d
    ❌  missing:   %3d\n" "$_pass" "$_diff" "$_errs"
    echo ""
    (( _errs > 0 )) && echo "⚠️  TODO: Run without '--audit' to fix the above discrepancies."
    return 0
}
