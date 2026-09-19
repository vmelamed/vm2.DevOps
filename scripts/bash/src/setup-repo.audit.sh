# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x script_name
declare -x lib_dir

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
declare -xa apps_with_secrets
declare -xrA actions_default_vars
declare -xA default_local_git_settings
declare -xa default_local_git_settings_order

declare -xA actions_secrets
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

declare -xri err_invalid_nameref


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
# @arg $4 nameref to an associative array variable containing the expected key-value pairs, e.g. `default_repo_settings` or
#   `default_repo_permissions`.
# @arg $5 nameref to an indexed array variable to store the summary results in:
#   [0] - number of exact matches
#   [1] - number of differences
#   [2] - number of errors (e.g., missing settings)
# @arg $6 nameref - the name of an indexed array variable containing the display order of the setting keys (optional, default:
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

    (( $# == 5 || $# == 6 ))                                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires five or six arguments (provided $#):" \
                                                                                                        "  - the GitHub API endpoint path to fetch settings from" \
                                                                                                        "  - jq transform JSON -> key=value lines" \
                                                                                                        "  - display-format flag: if true, change expected-values array's keys to sentence-capitalized" \
                                                                                                        "  - name of an associative array variable to store the expected key-values" \
                                                                                                        "  - name of an indexed array variable to store the summary results: [0] matches, [1] differences, and [2] errors" \
                                                                                                        "  - optional name of an indexed array with the display order of the keys."
    [[ ! -v 1 || -n "$1" ]]                                      || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the GitHub API path, to be non-empty (provided '${1:-<none>}'); for example, 'repos/\$repo'."
    [[ ! -v 2 || -n "$2" ]]                                      || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the jq transformation query, to be non-empty (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_boolean "$3"                              || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 3, the display-key formatting flag, to be 'true' or 'false' (provided '${3:-<none>}')."
    [[ ! -v 4 ]] || is_defined_associative_array "$4"            || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 4 to name an associative array containing expected key-value pairs (provided '${4:-<none>}')."
    [[ ! -v 5 ]] || is_defined_indexed_array "$5"                || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 5 to name an indexed array for summary results: [0] matches, [1] differences, and [2] errors (provided '${5:-<none>}')."
    [[ ! -v 6 || -z "${6:-}" ]] || is_defined_indexed_array "$6" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires optional argument 6 to name an indexed array containing the display order (provided '${6:-<none>}')."

    exit_if_has_bugs

    local _gh_endpoint="$1"
    local _jq_transform=$2
    local _modify_keys="$3"
    local -n _expected_key_values="$4"
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

    local -a _keys
    if [[ -n "${6:-}" ]]; then
        # put the keys in the array in display order
        local -n _keys_in_order="$6"
        _keys=("${_keys_in_order[@]}")
    else
        # otherwise put the keys in the array in sorted order
        readarray -t _keys < <(printf '%s\n' "${!_expected_key_values[@]}" | sort)
    fi

    local _expected _actual
    local -i _pass=0 _diff=0 _errs=0

    for _key in "${_keys[@]}"; do
        if [[ $_key == --* ]]; then
            printf "    ➡️  %-38s %s\n" "${_key#--}" "────────────────────────────────────────────────────────────────────────"
            continue
        fi

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
    local -i _pass=0 _diff=0 _errs=0
    local -a _results=(0 0 0)

    echo "ℹ️  Audit of https://github.com/$repo"

    # --- Repo settings ---
    echo "  ℹ️  Repository settings:"
    compare_settings "$path_repo" "$jq_entries" true default_repo_settings _results default_repo_settings_order || {
        error -ec "$?" "Failed to compare repository settings."
        return 2
    }
    (( _pass += _results[0], _diff += _results[1], _errs += _results[2], 1 ))

    # --- Actions permissions ---
    echo "  ℹ️  Actions permissions:"
    compare_settings "$path_permissions" "$jq_entries" true default_repo_permissions _results || {
        error -ec "$?" "Failed to compare repository permissions settings."
        return 2
    }
    (( _pass += _results[0], _diff += _results[1], _errs += _results[2], 1 ))

    # --- Variables ---
    echo "  ℹ️  Actions Variables:"
    compare_settings "$path_vars" "$jq_vars" false actions_default_vars _results actions_default_vars_order || {
        error -ec "$?" "Failed to compare GitHub Actions variables."
        return 2
    }
    (( _pass += _results[0], _diff += _results[1], _errs += _results[2], 1 ))

    # --- Secrets ---
    if [[ -v actions_secrets["NUGET_API_KEY"] && ${actions_default_vars["NUGET_SERVER"]} == 'nuget' ]]; then
        # remove the NUGET_API_KEY secret if the NuGet server is set to 'nuget' - they use the Trusted Publishing now
        unset 'actions_secrets["NUGET_API_KEY"]'
    fi

    local app
    for app in "${apps_with_secrets[@]}"; do
        local _secrets_array_name="${app,,}_secrets"

        is_array_empty "$_secrets_array_name" && continue

        local _secrets_array_order_name="${app,,}_secrets_order"
        if ! is_defined_indexed_array "$_secrets_array_order_name" || is_array_empty "$_secrets_array_order_name"; then
            _secrets_array_order_name=
        fi

        echo "  ℹ️  ${app^} Secrets:"
        compare_settings "$path_repo/$app/secrets" "$jq_secrets" false "$_secrets_array_name" _results "$_secrets_array_order_name" || {
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
    compare_settings "$path_rulesets/$_ruleset_id" "$jq_ruleset_rules" true default_ruleset _results default_ruleset_order || {
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

    local _key _expected _actual
    local -i _rc
    for _key in "${default_local_git_settings_order[@]}"; do
        _rc=$success
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
