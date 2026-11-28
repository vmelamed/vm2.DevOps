# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines functions for working with GitHub repositories.
# It includes functions for validating GitHub repository owners and names, parsing GitHub
# URLs, and other GitHub-related utilities.
#===============================================================================================

(( ${__VM2_LIB_GIT_GH_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_GIT_GH_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x failure
declare -x positive
declare -x negative
declare -x err_argument_value
declare -x err_invalid_arguments
declare -x err_argument_type
declare -x err_io_failure
declare -x err_logic_error
declare -x err_tool_error
declare -x err_invalid_nameref
declare -x err_not_directory
declare -x err_root_not_repo_name
declare -x err_invalid_repo
declare -x err_invalid_repo_name
declare -x err_unsafe_argument

# vm2 core lib constants
declare -x warn_em
declare -x u_letters_set
declare -x l_letters_set
declare -x letters_set
declare -x nz_digits_set
declare -x digits_set

declare -xr gh_authority_rex="github\.com"
declare -xr gh_ssh_authority_rex="git@$gh_authority_rex"                        # OK, this is not URI authority, but here we only support GitHub SSH URLs, so we can call GitHub SSH authority. This is the part of the URL before the owner/name, e.g. "git@github.com" from "git@github.com:vmelamed/vm2.DevOps.git"
declare -xr gh_https_authority_rex="https://$gh_authority_rex"                  # OK, this is not URI authority, but here we only support GitHub HTTPS URLs, so we can call GitHub HTTPS authority. This is the part of the URL before owner/name, e.g. "https://github.com" from https://github.com/vmelamed/vm2.DevOps

declare -xr gh_repo_owner_rex="[${letters_set}${digits_set}]([${letters_set}${digits_set}-]{0,37}[${letters_set}${digits_set}])?"   # GitHub owner/organization names can be up to 39 characters, must start and end with a letter or digit, and can contain letters, digits, and hyphens. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.
declare -xr gh_repo_owner_regex="^$gh_repo_owner_rex$"

declare -xr gh_repo_name_rex="[${letters_set}${digits_set}][${letters_set}${digits_set}._-]{0,99}"                  # GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.
declare -xr gh_repo_name_regex="^$gh_repo_name_rex$"                            # you still must strip off the suffix .git: _name=${_name%.git}

declare -xr gh_repo_full_name_rex="($gh_repo_owner_rex)/($gh_repo_name_rex)"
declare -xr gh_repo_full_name_regex="^$gh_repo_full_name_rex$"

declare -xr github_url_regex="^([${l_letters_set}][${l_letters_set}${digits_set}+.-]*://([^/@]+@)?(ssh\.)?github\.com(:[${digits_set}]+)?/|([^/@:]+@)?(ssh\.)?github\.com:)($gh_repo_owner_rex)/($gh_repo_name_rex)(\.git)?/?$"

#-----------------------------------------------------------------------------------------------
# @description GitHub Actions runners
#-----------------------------------------------------------------------------------------------
declare -xra gh_runners_os_in_use=(
    "ubuntu-latest"
    "ubuntu-26.04"
    "ubuntu-24.04"
    "ubuntu-22.04"
    "windows-latest"
    "windows-2025"
    "windows-2022"
    "macos-latest"
    "macos-26"
    "macos-15"
    "macos-14"
)

declare -x gh_runners_os_in_use_str
gh_runners_os_in_use_str=$(IFS=,; echo "${gh_runners_os_in_use[*]}")
readonly gh_runners_os_in_use_str

# declare -xr gh_runners_os_in_use_rex=$(IFS='|'; echo "${gh_runners_os_in_use[*]}")


declare -xr default_repo_owner="vmelamed"
declare -xr default_default_branch="main"

#-----------------------------------------------------------------------------------------------
# @description GitHub repository visibilities
#-----------------------------------------------------------------------------------------------
declare -xra repo_visibilities=(
    "public"
    # "internal" # only for organizations
    "private"
)

declare -x repo_visibilities_str
repo_visibilities_str=$(IFS=,; echo "${repo_visibilities[*]}")
readonly repo_visibilities_str

# declare -x repo_visibilities_rex=$(IFS='|'; echo "${repo_visibilities[*]}")
# repo_visibilities_rex=$(IFS='|'; echo "${repo_visibilities[*]}")
# readonly repo_visibilities_rex

declare -xr default_visibility="public"

#-----------------------------------------------------------------------------------------------
# @description GitHub Actions applications that use variables (`vars`)
#-----------------------------------------------------------------------------------------------
declare -xra gh_apps_with_vars=(
    "actions"
    "agents"
)

declare -x gh_apps_with_vars_str
gh_apps_with_vars_str=$(IFS=,; echo "${gh_apps_with_vars[*]}")
readonly gh_apps_with_vars_str

# declare -xr gh_apps_with_vars_rex=$(IFS='|'; echo "${gh_apps_with_vars[*]}")

#-----------------------------------------------------------------------------------------------
# @description GitHub Actions applications that use secrets (`secrets`)
#-----------------------------------------------------------------------------------------------
declare -xra gh_apps_with_secrets=(
    "actions"
    "dependabot"
    "codespaces"
    # "agents"
)

declare -x gh_apps_with_secrets_str
gh_apps_with_secrets_str=$(IFS=,; echo "${gh_apps_with_secrets[*]}")
readonly gh_apps_with_secrets_str

# declare -x gh_apps_with_secrets_rex
# gh_apps_with_secrets_rex=$(IFS='|'; echo "${gh_apps_with_secrets[*]}")
# readonly gh_apps_with_secrets_rex

# vm2 core lib variables
declare -x noise_sink

#-----------------------------------------------------------------------------------------------
# @description Predicate - tests that the specified GitHub repository owner is valid according
#   to GitHub naming rules, i.e. it matches the regular expression for GitHub owner/organization names.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository owner naming rules.
#
# @arg $1 string The GitHub repository owner to validate.
#
# @exitcode positive=0: If the GitHub repository owner is valid.
# @exitcode negative=1: If the GitHub repository owner is not valid.
#
# @example
#   if is_gh_repo_owner "my-org"; then echo "Valid repo owner"; fi
#-----------------------------------------------------------------------------------------------
function is_gh_repo_owner()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the GitHub repository owner to validate."
                                                                                exit_if_has_bugs

    local _owner=${1:-}
    [[ $_owner =~ $gh_repo_owner_regex ]]
}

#-----------------------------------------------------------------------------------------------
# @description Predicate - tests that the specified GitHub repository name is valid according to
#   GitHub naming rules, i.e. it matches the regular expression for GitHub repository names and
#   does not end with `.git`.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository naming rules.
#
# @arg $1 string The GitHub repository name to validate.
#
# @exitcode positive=0: If the GitHub repository name is valid.
# @exitcode negative=1: If the GitHub repository name is not valid.
#
# @example
#   if is_gh_repo_name "my-repo"; then echo "Valid repo name"; fi
# @example
#   enter_value "GitHub Repository name" repo_name "$default_repo_name" false is_gh_repo_name
#-----------------------------------------------------------------------------------------------
function is_gh_repo_name()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the GitHub repository name to validate."
                                                                                exit_if_has_bugs

    local _repo="${1:-}"

    # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
    [[ $_repo =~ $gh_repo_name_regex && $_repo != *.git ]]
}

#-----------------------------------------------------------------------------------------------
# @description Predicate - tests that the specified GitHub repository full name (<owner>/<repo name>)
#   is valid according to GitHub naming rules above
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository naming rules.
#
# @arg $1 string The GitHub repository name to validate.
#
# @exitcode positive=0: If the GitHub repository name is valid.
# @exitcode negative=1: If the GitHub repository name is not valid.
#
# @example
#   if is_gh_repo_full_name "valo/my-repo"; then echo "Valid repo name"; fi
# @example
#   enter_value "GitHub Repository name" repo_name "$default_repo_name" false is_gh_repo_full_name
#-----------------------------------------------------------------------------------------------
function is_gh_repo_full_name()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the GitHub repository name to validate."
                                                                                exit_if_has_bugs

    local _full_name="${1:-}"

    # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository full names above
    [[ $_full_name =~ $gh_repo_full_name_regex && $_full_name != *.git ]]
}

#-----------------------------------------------------------------------------------------------
# @description Validates that the specified GitHub repository description is valid according to
#   GitHub rules, i.e. it is between 3 and 350 characters long.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository description rules.
#
# @arg $1 string The GitHub repository description to validate.
#
# @exitcode success=0: If the GitHub repository description is valid.
# @exitcode err_argument_value=4: If the GitHub repository description is not between 3 and 350
#   characters long.
#
# @example
#   if is_gh_repo_description "This is my repo"; then echo "Valid repo description"; fi
# @example
#   enter_value "GitHub Repository description" repo_description "$default_repo_description" false is_gh_repo_description)
#-----------------------------------------------------------------------------------------------
function is_gh_repo_description()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the GitHub repository description to validate."
                                                                                exit_if_has_bugs

    local _description=${1:-}

    # GitHub repository descriptions must be between 3 and 350 characters long.
    (( ${#_description} >= 3 && ${#_description} <= 350 ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates that the specified GitHub repository owner is valid according to GitHub
#   naming rules, i.e. it matches the regular expression for GitHub owner/organization names.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository owner naming rules.
#
# @arg $1 string The GitHub repository owner to validate.
#
# @exitcode success=0: If the GitHub repository owner is valid.
# @exitcode err_argument_value=4: If the GitHub repository owner is not empty and does not match
#   the GitHub owner/organization naming rules.
#
# @example
#   if is_valid_gh_repo_owner "my-org"; then echo "Valid repo owner"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_gh_repo_owner()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the GitHub repository owner to validate."
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    # repo owner can be empty (for user-level repos) or must match the regex for GitHub owner/organization names
    is_gh_repo_owner "$1"                                                       || with_error _rc "$err_argument_value" "Invalid GitHub repository owner '${1-<missing>}': use 2 to 39 letters, digits, or hyphens, and start and end it with a letter or a digit."

    return "$_rc"
}

readonly __valid_repo_names_msg="GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit.
See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details."

#-----------------------------------------------------------------------------------------------
# @description Validates that the specified GitHub repository name is valid according to GitHub
#   naming rules, i.e. it matches the regular expression for GitHub repository names and does
#   not end with `.git`.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository naming rules.
#
# @arg $1 string The GitHub repository name to validate.
#
# @exitcode success=0: If the GitHub repository name is valid.
# @exitcode err_argument_value=4: If the GitHub repository name is empty, ends with `.git`, or
#   does not match the GitHub repository naming rules.
#
# @example
#   if is_valid_gh_repo_name "my-repo"; then echo "Valid repo name"; fi
# @example
#   enter_value "GitHub Repository name" repo_name "$default_repo_name" false is_valid_gh_repo_name
#-----------------------------------------------------------------------------------------------
function is_valid_gh_repo_name()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the GitHub repository name to validate."
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
    is_gh_repo_name "$1"                                                        || with_error _rc "$err_invalid_repo_name" "Invalid GitHub repository name (provided '${1-<missing>}'). $__valid_repo_names_msg"

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that the specified repository description is valid according to GitHub
#   rules, i.e. it is between 3 and 350 characters long.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository description rules.
#
# @arg $1 string The repository description to validate.
#
# @exitcode success=0: If the repository description is valid.
# @exitcode err_argument_value=4: If the repository description is not between 3 and 350
#   characters long.
#
# @example
#   if is_valid_gh_repo_description "This is my repo"; then echo "Valid repo description"; fi
# @example
#   enter_value "GitHub Repository description" repo_description "$default_repo_description" false is_valid_gh_repo_description)
#-----------------------------------------------------------------------------------------------
function is_valid_gh_repo_description()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the repository description to validate."
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    # GitHub repository descriptions must be between 3 and 350 characters long.
    is_gh_repo_description "$1"                                                 || with_error _rc "$err_argument_value" "Invalid repository description '${1-<missing>}': use 3 to 350 characters."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a GitHub repository visibility: one of `$repo_visibilities`. The match is
#   case-sensitive: callers that take the value from a person lowercase it first.
#
# @arg $1 string The visibility to validate.
#
# @exitcode positive=0: If the visibility is valid.
# @exitcode err_argument_value=4: If the visibility is not one of `$repo_visibilities`.
#
# @example
#   if is_valid_gh_visibility "private"; then echo "Valid visibility"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_gh_visibility()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): a visibility."
                                                                                exit_if_has_bugs
    local -i _rc=$success

    is_in "$1" "${repo_visibilities[@]}"                                        || with_error _rc "$err_argument_value" "Invalid repository visibility '$1': use one of $repo_visibilities_str."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates that a runner OS name is in the allowed list of GitHub Actions
#   runners.
#
# Notes:
#   - The allowed values are defined in the `$gh_runners_os_in_use` array.
#
# @arg $1 string The runner OS name to validate.
#
# @exitcode positive=0: If the runner OS is valid.
# @exitcode err_argument_value=4: If the runner OS is not in the allowed list.
#
# @example
#   if is_valid_gh_runner_os "ubuntu-latest"; then echo "Valid runner"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_gh_runner_os()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the runner OS to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_in "$1" "${gh_runners_os_in_use[@]}"                                     || with_error _rc "$err_argument_value" "Invalid runner OS '$1': use one of $gh_runners_os_in_use_str."

    return "$_rc"
}

declare -rxi max_reason_length=200

#-----------------------------------------------------------------------------------------------
# @description Validates a GitHub Actions manual dispatch "reason" text input for length
#   constraints.
#
# Notes:
#   - Maximum length is 200 characters.
#
# @arg $1 string The reason text to validate.
#
# @exitcode success=0: If the reason is valid.
# @exitcode err_argument_value=4: If the reason is too long.
#
# @example
#   if is_valid_gh_reason "$user_reason"; then log_reason "$user_reason"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_gh_reason()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the reason text to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

    # Check length
    (( ${#1} <= max_reason_length ))                                            || with_error _rc "$err_argument_value" "The reason is too long. Maximum length is $max_reason_length characters."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a GitHub Actions manual dispatch "reason" text input for safety and
#   length constraints. Depends on `is_valid_gh_reason` and `is_safe_input`.
#
# Notes:
#   - Maximum length is 200 characters.
#   - Allows spaces but rejects shell meta-characters and command-like patterns (input starting
#     with `-`, `/`, or `.`).
#
# @arg $1 string The reason text to validate.
#
# @exitcode positive=0: If the reason is safe.
# @exitcode err_argument_value=4: If the reason is too long.
# @exitcode err_unsafe_argument=11: If it contains unsafe characters or looks like a command.
#
# @example
#   if is_safe_gh_reason "$user_reason"; then log_reason "$user_reason"; fi
#-----------------------------------------------------------------------------------------------
function is_safe_gh_reason()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the reason text to test."
                                                                                exit_if_has_bugs

    local _reason="$1"
    local -i _rc=$success

    is_valid_gh_reason "$_reason"                                               || _rc=$?

    # Allow spaces but reject dangerous shell meta-characters
    is_safe_input "$_reason" true                                               || _rc=$?

    # Reject if it looks like a command (starts with -, /, .)
    [[ ! "$_reason" =~ ^[-/.] ]]                                                || with_error _rc "$err_unsafe_argument" "Invalid reason '$_reason': it looks like a command, or contains unsafe characters."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Validates a GitHub secret name: contains only alphanumeric characters and
#   underscores, starts with a letter or underscore, and does not start case-insensitively with
#   'GITHUB_'.
#
# @arg $1 string Candidate secret name to validate.
#
# @exitcode positive=0: The secret name is valid.
# @exitcode err_argument_value=4: The value is not a valid name of a GitHub Actions secret.
#-----------------------------------------------------------------------------------------------
function is_valid_gh_secret_name()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the GitHub secret name to test."
                                                                                exit_if_has_bugs

    local -i _rc=$success

    is_variable_name "$1" && [[ ${1^^} != GITHUB_* ]]                           || with_error _rc "$err_argument_value" "Invalid secret name '$1': use only letters, digits, and underscores; do not start with a digit or with 'GITHUB_'."

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description The `--classify` function of `execute_with_retry` for every `gh` command, `gh api`
#   included: classifies a failure as transient (retry), or as persistent, with the vm2 code the
#   caller gets. One rule: the HTTP status decides; failing that, the message.
#
# Notes:
#   - The HTTP status comes from the `.status` of the JSON error body that `gh api` writes to
#     stdout, or else from an `HTTP <status>` in the message (any `gh` command). It is translated
#     by `http_status_to_error_code` (`_error_codes.sh`): `425`, `429`, `500`, and `502`-`504`
#     are transient; `401` -> `$err_tool_unauthenticated`, `403` -> `$err_access_denied`, `404`
#     -> `$err_not_found`; any other status -> `$err_tool_error`.
#   - A failure without a status is transient when the message is about a rate limit, a server
#     error, a timeout, an unavailable service, "try again", the connection, the network, or
#     DNS; anything else is `$err_tool_error`.
#   - A number elsewhere in the message (e.g. a run ID with `500` in it) is not taken for a status.
#
# @arg $1 int The failed command's exit code [1, 255].
# @arg $2 string The name of the file holding the command's stdout.
# @arg $3 string The name of the file holding the command's stderr.
#
# @exitcode 0: The failure is transient: the command can be retried.
# @exitcode err_*: The failure is persistent: the vm2 code `execute_with_retry` returns, e.g.
#   `$err_not_found` (HTTP 404) or `$err_tool_error`.
#
# @example
#   execute_with_retry --quiet --classify gh_failure \
#       gh repo create my-repo --public
# @example
#   value=$(execute_with_retry --query --classify gh_failure \
#               gh api "repos/$repo/actions/variables/NUGET_SERVER" --jq .value)        || rc=$?
#   (( rc == success || rc == err_not_found ))                                          || …   # absent: a default
#-----------------------------------------------------------------------------------------------
function gh_failure()
{
    assert_classifier_args "$@"

    local _exit_code=$1
    local _stdout_file=$2
    local _stderr_file=$3

    local _message
    _message=$(< "$_stderr_file")                                               || true

    # the HTTP status: from the JSON error body of 'gh api' ('?' tolerates a non-object, e.g. the array of a partially
    # paginated response), or else from the message of any 'gh' command
    local _status
    _status=$(jq -r '.status? // empty' "$_stdout_file" 2>"$noise_sink")        || true
    [[ $_status =~ ^[1-5][0-9]{2}$ ]]                                           || _status=''
    [[ -n $_status || ! $_message =~ HTTP\ ([1-5][0-9]{2})([^0-9]|$) ]]         || _status=${BASH_REMATCH[1]}

    local -i _code

    if [[ $_status == 403 && $_message =~ rate.limit ]]; then
         _code=0
    elif [[ -n $_status ]]; then
         http_status_to_error_code "$_status" _code
    elif [[ $_message =~ rate.limit|server.error|timeout|temporarily.unavailable|try.again|connection|network|dns ]]; then
        _code=0
    else
        _code=$err_tool_error
    fi

    (( _code == 0 )) || trace "Persistent 'gh' failure (exit code $_exit_code${_status:+, HTTP $_status}): $(error_name "$_code")"
    return "$_code"
}

#-----------------------------------------------------------------------------------------------
# @description Retrieves the value of a GitHub repository property
#
# @arg $1 string the full GitHub repository name::=<repo owner>/<repo name>
# @arg $2 string the name of a property to get, e.g. "default_branch", "description", "url"
#
# @exitcode success=0: on success
# @exitcode err_tool_error=66: if querying GitHub failed (see the other errors)
#
# @stdout the value of the property
#
# @example
# declare _default_branch=$(get_repo_gh_property "vmelamed/vm2.DevOps" "default_branch")
# declare _owner_type=$(get_repo_gh_property "vmelamed/vm2.DevOps" "owner.type")
#-----------------------------------------------------------------------------------------------
function get_gh_repo_property()
{
    (( $# == 2 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                "  - repo: the full name of the repository (<repo owner>/<repo name>)" \
                                                                                                                "  - property: the name of a property to get"
    [[ ! -v 1 ]] || is_gh_repo_full_name "$1"                                   || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a full name (<repo owner>/<repo name>) of a GitHub repository (provided '${1-<missing>}')."
    [[ ! -v 2 || "$2" =~ ^[a-z][a-z_.]*$ ]]                                     || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 2 to be the name of a property to get (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    local _repo_full_name=$1
    local _property_name=$2
    local -i _rc=$success

    execute_with_retry --query --classify gh_failure \
        gh api --paginate "repos/$_repo_full_name" -q ".$_property_name"        || with_error _rc "$err_tool_error" "Failed to get the property '$_property_name' of the repository '$_repo_full_name' from GitHub."

    return "$_rc"
}
