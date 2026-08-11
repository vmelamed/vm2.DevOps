# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # variable is referenced but not assigned.

#-------------------------------------------------------------------------------
# This script defines functions for working with Git and GitHub repositories.
# It includes functions for validating GitHub repository owners and names, parsing GitHub URLs, and other Git-related utilities.
#-------------------------------------------------------------------------------


# Circular include guard
(( ${__VM2_LIB_GIT_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_GIT_SH_LOADED=1

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_found
declare -rxi err_not_file
declare -rxi err_not_directory
declare -rxi err_not_git_directory
declare -rxi err_not_git_root


declare -xr gh_ssh_authority='git@github.com'                           # OK, it is actually the URI schema only, but we only support GitHub SSH URLs for now, so we can hardcode the authority and just call it that. This is the part of the URL before the owner/name, e.g. "git@github.com"
declare -xr gh_https_authority='https://github.com'                     # OK, it is actually the URI schema + authority, but we only support GitHub HTTPS URLs for now, so we can hardcode the authority and just call it that. This is the part of the URL before the owner/name, e.g. "https://github.com"

declare -xr repo_ssh_schema_rex='git'
declare -xr repo_https_schema_rex='https'

declare -xr repo_schema_rex="($repo_ssh_schema_rex|$repo_https_schema_rex)"
declare -xr repo_authority_rex="github\.com"
# declare -xr repo_authority_rex='git@github\.com|https://github\.com'    # OK. it is actually the URI schema + authority, but we only support GitHub URLs for now, so we can hardcode the authority and just call it that. This is the part of the URL before the owner/name, e.g. "git@github.com" or "https://github.com"
declare -xr repo_owner_rex='[a-zA-Z0-9][a-zA-Z0-9-]{0,37}[a-zA-Z0-9]'   # GitHub owner/organization names can be up to 39 characters, must start and end with a letter or digit, and can contain letters, digits, and hyphens. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.
declare -xr repo_name_rex='[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}'             # GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.

declare -xr repo_owner_regex="^$repo_owner_rex$"
declare -xr repo_name_regex="^$repo_name_rex$"
declare -xr repo_regex="^$repo_owner_rex/$repo_name_rex$"

# declare -xr github_url_regex="^($repo_authority_rex)[:/]($repo_owner_rex)/($repo_name_rex)$"
declare -xr github_url_regex="^($repo_ssh_schema_rex|$repo_https_schema_rex)(@|://)($repo_authority_rex)[:/]($repo_owner_rex)/($repo_name_rex)$"

# BASH_REMATCH indexes after matching a URL with $github_url_regex:
declare -xri url_schema=1
declare -xri url_authority=3
declare -xri url_owner=4
declare -xri url_name=5

#-------------------------------------------------------------------------------
# @description Validates that the specified repository owner is valid according to GitHub naming
#   rules, i.e. it matches the regular expression for GitHub owner/organization names.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository owner naming rules.
#
# @arg $1 string The repository owner to validate.
#
# @exitcode 0 If the repository owner is valid.
# @exitcode 2 If the number of arguments is not exactly one, or if the owner does not match the
#   expected GitHub owner/organization name format.
#
# @example
#   if validate_gh_repo_owner "my-org"; then echo "Valid repo owner"; fi
#-------------------------------------------------------------------------------
function validate_gh_repo_owner()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository owner to validate."
    }
    [[ -v 1 && ( -z $1 || $1 =~ $repo_owner_regex ) ]] || {
        # repo owner can be empty (for user-level repos) or must match the regex for GitHub owner/organization names
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be empty or a valid repository owner (provided '${1-<missing>}'). $valid_repo_owners"
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    return "$success"
}

valid_repo_names="GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit.
See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details."

readonly valid_repo_names

#-------------------------------------------------------------------------------
# @description Validates that the specified repository name is valid according to GitHub naming
#   rules, i.e. it matches the regular expression for GitHub repository names and does not end
#   with `.git`.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository naming rules.
#
# @arg $1 string The repository name to validate.
#
# @exitcode 0 If the repository name is valid.
# @exitcode 2 If the number of arguments is not exactly one, or if the name is empty, ends with
#   `.git`, or does not match the expected GitHub repository name format.
#
# @example
#   if validate_gh_repo_name "my-repo"; then echo "Valid repo name"; fi
# @example
#   repo_name=$(enter_value "GitHub Repository name" "$default_repo_name" false validate_gh_repo_name)
#-------------------------------------------------------------------------------
function validate_gh_repo_name()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository name to validate."
    }
    [[ -v 1 && -n $1 && $1 != *.git && $1 =~ $repo_name_regex ]] || {
        # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be a valid repository name (provided '${1-<missing>}'). $valid_repo_names"
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    return "$success"
}

#-------------------------------------------------------------------------------
# @description Validates that the specified repository description is valid according to GitHub
#   rules, i.e. it is between 3 and 350 characters long.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository description rules.
#
# @arg $1 string The repository description to validate.
#
# @exitcode 0 If the repository description is valid.
# @exitcode 2 If the number of arguments is not exactly one, or if the description length is not
#   between 3 and 350 characters.
#
# @example
#   if validate_gh_repo_description "This is my repo"; then echo "Valid repo description"; fi
# @example
#   repo_description=$(enter_value "GitHub Repository description" "$default_repo_description" false validate_gh_repo_description)
#-------------------------------------------------------------------------------
function validate_gh_repo_description()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository description to validate."
    }
    [[ -v 1 ]] && (( ${#1} >= 3 && ${#1} <= 350 )) || {
        # GitHub repository descriptions must be between 3 and 350 characters long.
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the repository description, to contain between 3 and 350 characters (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    return "$success"
}

#-------------------------------------------------------------------------------
# @description Validates that the specified repository branch name is valid according to Git
#   branch naming rules, i.e. it is a valid Git ref name.
#
# Notes:
#   - See [git-check-ref-format](https://git-scm.com/docs/git-check-ref-format) for details on
#     valid Git ref names.
#
# @arg $1 string The repository branch name to validate.
#
# @exitcode 0 If the branch name is valid.
# @exitcode 2 If the number of arguments is not exactly one, or if the branch name is not a valid
#   Git ref name.
#
# @example
#   if validate_branch_name "main"; then echo "Valid branch name"; fi
# @example
#   branch_name=$(enter_value "Default branch name" "$default_branch" false validate_branch_name)
#-------------------------------------------------------------------------------
function validate_branch_name()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository branch name to validate."
    }
    [[ -v 1 ]] && git check-ref-format --branch "$1" &> "$_ignore" || {
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be a valid Git branch name (provided '${1-<missing>}'). See https://git-scm.com/docs/git-check-ref-format for details."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    return "$success"
}

#-------------------------------------------------------------------------------
# @description Validates that the specified secret value is valid, i.e. it is non-empty and
#   contains no control characters.
#
# Notes:
#   - See [GitHub encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
#     for details on GitHub secrets.
#
# @arg $1 string The secret value to validate.
#
# @exitcode 0 If the secret value is valid.
# @exitcode 2 If the number of arguments is not exactly one, if the value is empty, or if it
#   contains control characters.
# @exitcode 3 If the secret value has invalid value (e.g. empty or contains control characters).
#
# @example
#   if validate_gh_secret "c2VjcmV0VmFsdWU="; then echo "Valid secret"; fi
#-------------------------------------------------------------------------------
function validate_gh_secret()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the secret value to validate."
    }
    [[ -v 1 && -n $1 && ! $1 =~ [[:cntrl:]] ]] || {
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the secret value, to be non-empty and contain no control characters."
    }

    (( _rc == success )) || return "$err_invalid_arguments"
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Executes a GitHub CLI (`gh`) command with retry logic for transient failures.
#
# Notes:
#   - stdout is written to `$output` (either `/dev/stdout` or `$_ignore`, depending on
#     `ignore_output`); stderr is always written to the caller's stderr.
#   - Retries only on errors that look transient, based on a pattern match against stderr:
#     `rate limit`, `server error`, `timeout`, `temporarily unavailable`, `try again`,
#     `502`/`503`/`504`, `connection refused`, `network error`.
#   - Non-transient errors (invalid args, not found, permissions, etc.) fail immediately without
#     retrying.
#   - Honors `$dry_run`: if set, prints the command to stderr and returns success without
#     executing it.
#
# @arg $1 int Maximum number of attempts.
# @arg $2 int Delay between attempts, in seconds.
# @arg $3 bool If present and a valid boolean, suppresses stdout when true (optional, default:
#   false). If not a boolean, it is treated as the start of the `gh` command's own arguments.
# @arg $@ string The `gh` command and its arguments (subcommand, flags, etc.) — starts at $3 or
#   $4 depending on whether the optional `ignore_output` flag was given.
#
# @exitcode 0 If the command eventually succeeds.
# @exitcode 2 If fewer than three arguments are provided, or if $1/$2 are not natural numbers.
# @exitcode * Otherwise, the last exit code returned by `gh`, or `err_logic_error` if all retry
#   attempts are exhausted.
#
# @example
#   execute_gh_with_retry 3 5 repo create my-repo --public
# @example
#   execute_gh_with_retry 3 2 true repo delete owner/repo --yes
#-------------------------------------------------------------------------------
function execute_gh_with_retry()
{
    local -i _rc="$success"

    (( $# >= 3 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires at least three arguments (provided $#): <max_attempts> <delay> <gh-command> [args...]"
    }
    is_natural "$1" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires the first argument to be a natural number: <max_attempts>"
    }
    is_natural "$2" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires the second argument to be a natural number: <delay> in seconds"
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    # get the first two and the optional third (ignore_output) boolean parameter
    local _output

    local _max_attempts=$1; shift
    local _delay=$1; shift
    local _ignore_output=false
    is_boolean "$1" && _ignore_output=$1 && shift
    $_ignore_output && _output="$_ignore" || _output="/dev/stdout"

    "$dry_run" && echo "dry-run$ gh $*" >&2 && return "$success"

    # stderr goes to a temp file to preserve output fidelity (especially newlines), yet still allows us to process them separately
    local _stderr_file
    local _stdout_file
    _stderr_file=$(mktemp)
    _stdout_file=$(mktemp)

    local _attempt=0
    local _message=""
    trace "Executing with retry from (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): 'gh $*'"

    _rc=$success

    until gh "$@" >"$_stdout_file" 2>"$_stderr_file"; do
        _rc=$?

        cat "$_stderr_file" >&2
        _message=$(cat "$_stderr_file") || true

        # Check if error is transient - retry
        if [[ ! "$_message" =~ (rate.limit|server.error|timeout|temporarily.unavailable|try.again|502|503|504|connection.refused|network.error) ]]; then
            error -ec "$_rc" "'gh' command unrecoverable error during attempt: $_attempt/$_max_attempts."
            break # Permanent error (invalid args, not found, permissions, etc.) - don't retry
        fi

        # transient error - retry or give up
        if (( ++_attempt < _max_attempts )); then
            # retry and reset rc to success to avoid returning a failure code if the last attempt fails with a transient error
            warning "'gh' command failed. Attempt: $_attempt/$_max_attempts. Retrying in ${_delay}s."
            sleep "$_delay"
            _rc=$success
        else
            # give up and return the last error
            error -ec "$err_logic_error" "After $_attempt attempts, the 'gh' command is still failing."
            break
        fi
    done

    (( _rc == success )) && cat "$_stderr_file" >&2
    cat "$_stdout_file" >> "$_output"

    rm -f "$_stderr_file" "$_stdout_file"

    return "$_rc"
}

#-------------------------------------------------------------------------------
# @description Executes a `gh api` command with retry logic for transient failures.
#
# Notes:
#   - stdout is written to `$output` (either `/dev/stdout` or `$_ignore`, depending on
#     `ignore_output`); stderr is always written to the caller's stderr.
#   - Prefers the JSON `.status` field from the response body to decide whether an error is
#     transient: `425`, `429`, `500`, `502`, `503`, `504` are retried; `1xx`/`2xx`/`3xx` are treated
#     as success; anything else fails immediately.
#   - If the response has no usable JSON `.status`, falls back to a pattern match against stderr
#     (`authentication`, `network`, `timeout`, `dns`, `connection`) to decide whether to retry.
#   - Honors `$dry_run`: if set, prints the command to stderr and returns success without
#     executing it.
#
# @arg $1 int Maximum number of attempts.
# @arg $2 int Delay between attempts, in seconds.
# @arg $3 bool If present and a valid boolean, suppresses stdout when true (optional, default:
#   false). If not a boolean, it is treated as the start of the `gh api` command's own arguments.
# @arg $@ string The `gh api` route and its arguments — starts at $3 or $4 depending on whether the
#   optional `ignore_output` flag was given.
#
# @exitcode 0 If the command eventually succeeds.
# @exitcode 2 If fewer than three arguments are provided, or if $1/$2 are not natural numbers.
# @exitcode * Otherwise, the last exit code returned by `gh api`, or `err_logic_error` if all retry
#   attempts are exhausted.
#
# @example
#   execute_gh_api_with_retry 3 5 repos/vmelamed/my-repo
#-------------------------------------------------------------------------------
function execute_gh_api_with_retry()
{
    local -i _rc="$success"

    (( $# >= 3 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires at least three arguments (provided $#): <max_attempts> <delay> <command> [args...]"
    }
    is_natural "$1" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires the first argument to be a natural number: <max_attempts>"
    }
    is_natural "$2" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires the second argument to be a natural number: <delay> in seconds"
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    # get the first two and the optional third (ignore_output) boolean parameter
    local _output

    local _max_attempts=$1; shift
    local _delay=$1; shift
    local _ignore_output=false
    is_boolean "$1" && _ignore_output=$1 && shift
    $_ignore_output && _output="$_ignore" || _output="/dev/stdout"

    "$dry_run" && echo "dry-run$ gh $*" >&2 && return "$success"

    # stderr and stdout go to temp files to preserve output fidelity (especially newlines), yet still allow us to process them separately
    local _stderr_file
    local _stdout_file
    _stderr_file=$(mktemp)
    _stdout_file=$(mktemp)

    local _attempt=0
    local _response="" message="" status=""
    _rc=$success
    trace "Executing with retry @ (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): gh api $*"

    until gh api "$@" >"$_stdout_file" 2>"$_stderr_file"; do
        _rc=$?

        cat "$_stderr_file" >&2

        _response=$(cat "$_stdout_file")            || true
        status=$(jq -r '.status' <<< "$_response") || true

        # If no JSON status, check stderr for network/auth errors
        if [[ -z "$status" || "$status" == "null" ]]; then
            message=$(cat "$_stderr_file") || true
            # If it's a not a transient error in stderr - break(return), otherwise - retry
            if [[ ! "$message" =~ (authentication|network|timeout|dns|connection) ]]; then
                error -ec "$_rc" "'gh api' command unrecoverable error during attempt: $_attempt/$_max_attempts."
                break
            fi
        else
            # Normal JSON error/HTTP status handling
            case $status in
                425|429|500|502|503|504 )           # transient error HTTP status codes from 'gh api' - retry may fix it
                    ;;

                1*|2*|3* )
                    _rc=0                            # 1xx, 2xx, and 3xx HTTP status codes are considered successful
                    break
                    ;;

                * ) break                           # everything else is a bad outcome that will not be fixed by retrying
                    ;;
            esac
        fi

        # transient error - retry or give up
        if (( ++_attempt < _max_attempts )); then
            # retry and reset rc to success to avoid returning a failure code if the last attempt fails with a transient error
            warning "'gh api' command failed. Attempt $_attempt/$_max_attempts. Retrying in ${_delay}s."
            sleep "$_delay"
            _rc=$success
        else
            error -ec "$err_logic_error" "After $_attempt attempts, the 'gh api' command is still failing."
            break
        fi
    done

    (( _rc == success )) && cat "$_stderr_file" >&2
    cat "$_stdout_file" >> "$_output"

    rm -f "$_stderr_file" "$_stdout_file" 2> "$_ignore"

    return "$_rc"
}

#-------------------------------------------------------------------------------
# With the following constants and functions we define the repository state: it is an associative array with predefined keys.
# The following constants define the predefined keys of a repo state:
#-------------------------------------------------------------------------------
declare -xr key_root='root'
declare -xr key_url='url'   # the URL used to access the repo, either SSH or HTTPS
declare -xr key_schema='schema'
declare -xr key_authority='authority'
declare -xr key_owner='owner'
declare -xr key_name='name'
declare -xr key_repo='repo'
declare -xr key_repo_id='repo_id'
declare -xr key_default_branch='default_branch'

# keys used in gh api results
declare -xr key_ssh_url='ssh_url'
declare -xr key_https_url='https_url'

#-------------------------------------------------------------------------------
# The following list contains the predefined keys of a repo state:
#-------------------------------------------------------------------------------
declare -xar repo_state_keys=(
    "$key_root"
    "$key_url"
    "$key_schema"
    "$key_authority"
    "$key_owner"
    "$key_name"
    "$key_repo"
    "$key_repo_id"
    "$key_default_branch"
)

declare -xr jq_gh_repo_state="{
    $key_https_url: .html_url,
    $key_ssh_url: .ssh_url,
    $key_owner: .owner.login,
    $key_name: .name,
    $key_repo: .full_name,
    $key_repo_id: .id,
    $key_default_branch: .default_branch,
} | to_entries[] | \"\\(.key)=\\(.value)\""


#-------------------------------------------------------------------------------
# @description Initializes a repo state to its initial state, where it contains all predefined
#   keys with empty-string values.
#
# @arg $1 nameref Name of an associative array variable to be initialized as a repo state.
#
# @exitcode 0 On success.
# @exitcode 2 If the number of arguments is not exactly one, or if $1 is not a declared associative
#   array.
#-------------------------------------------------------------------------------
function initialize_repo_state()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array for repository state (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _state="$1"
    local _key
    _state=()
    for _key in "${repo_state_keys[@]}"; do
        _state+=(["$_key"]='')
    done

    return "$success"
}

#-------------------------------------------------------------------------------
# @description Retrieves the Git repository state for a specified directory by finding the Git
#   repository root and parsing the origin remote URL, if it exists and is a GitHub URL.
#
# Notes:
#   - If the directory is not inside a Git work tree, has no `origin` remote, or the `origin`
#     remote is not a GitHub URL, the function returns success early with only the fields it
#     managed to populate (the rest stay at the empty-string default from `initialize_repo_state`).
#   - If `full_info` is false, the function stops after populating the local Git-derived fields
#     and does not call the GitHub API.
#   - When GitHub API data is fetched, the function cross-checks it against the local Git remote
#     data (URL, owner, name, repo, and presence of a repo ID) and logs an error for every mismatch
#     found, rather than stopping at the first one.
#
# @arg $1 string Path to the existing root of the Git repository working tree.
# @arg $2 nameref Name of an associative array variable to receive the repo state.
# @arg $3 bool If false, only retrieve the local Git repository state without querying the GitHub
#   API (optional, default: true).
#
# @exitcode 0 On success, or when the directory has no local/GitHub repo state to report.
# @exitcode 1 If the GitHub API data does not match the local Git remote data.
# @exitcode 2 If the number of arguments is not 2 or 3, if $1 is not an existing directory, if $2
#   is not a declared associative array, or if $3 (when provided) is not a boolean.
#
# @example
#   get_repo_state "/home/valo/repos/vm2.Glob" repo_state
#-------------------------------------------------------------------------------
function get_repo_state()
{
    local -i _rc="$success"

    (( $# == 2 || $# == 3 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires 2 or 3 arguments (provided $#):" \
                              "  - the existing path to the root of the git repo working tree" \
                              "  - nameref: the name of an associative array variable - to receive the repo state" \
                              "  - full_info - if false, only retrieve the local Git repository state without trying to get GitHub API data (optional, default: true)."
    }
    [[ -v 1 && -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be the existing root directory of the Git working tree (provided '${1-<missing>}')."
    }
    [[ -v 2 ]] && is_defined_associative_array "$2" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2 to name an associative array that will receive the repository state (provided '${2-<missing>}')."
    }
    [[ ! -v 3 ]] || is_boolean "$3" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 3, the full-information flag, to be 'true' or 'false' (provided '${3-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _full_info=${3:-true}

    local -n _state="$2" # associative array variable to receive the repo state, passed by nameref
    initialize_repo_state "$2" # make sure we have all fields

    local _url
    _state["$key_root"]=$(git -C "$1" rev-parse --show-toplevel 2>"$_ignore") || return "$success" # no local git repo
    _url=$(git -C "$1" remote get-url origin 2>"$_ignore")                    || return "$success" # no origin remote
    [[ -n $_url && $_url =~ $github_url_regex ]]                               || return "$success" # origin remote is not a GitHub URL

    local _schema="${BASH_REMATCH[$url_schema]}"
    local _authority="${BASH_REMATCH[$url_authority]}"
    local _owner="${BASH_REMATCH[$url_owner]}"
    local _name="${BASH_REMATCH[$url_name]}"

    _state["$key_url"]=$_url
    _state["$key_schema"]=$_schema
    _state["$key_authority"]=$_authority
    _state["$key_owner"]=$_owner
    if [[ $_schema == "$repo_ssh_schema_rex" ]]; then
        _name=${_name%.git}
    fi
    repo="$_owner/$_name"
    _state["$key_name"]=$_name
    _state["$key_repo"]=$repo

    $_full_info || return "$success" # caller does not want full info - return with what we have from git, without trying to get GitHub API data

    local -A _gh_state
    local _k _v

    while IFS='=' read -r _k _v; do
        _gh_state["$_k"]="$_v"
    done < <(execute_gh_api_with_retry 3 2 --paginate "repos/$repo" -q "$jq_gh_repo_state")

    # make sure all is kosher: the GitHub API data should match the local git remote data for the fields we care about
    # these are real logical problems that may occur if the git remote is misconfigured or the API is returning unexpected data,
    # so we check them all and report all mismatches rather than bailing on the first one
    [[ $_schema == "$repo_ssh_schema_rex"   && ${_gh_state["$key_ssh_url"]}   == "$_url" ||
       $_schema == "$repo_https_schema_rex" && ${_gh_state["$key_https_url"]} == "$_url"    ]] &&
    [[ ${_gh_state["$key_owner"]} == "$_owner" ]] &&
    [[ ${_gh_state["$key_name"]}  == "$_name"  ]] &&
    [[ ${_gh_state["$key_repo"]}  == "$repo"  ]] &&
    [[ -n ${_gh_state["$key_repo_id"]}        ]] &&
        _rc=$success || {
        _rc=$failure
        error -sd 3 -ec "$err_logic_error" "GitHub API returned URLs '${_gh_state["$key_ssh_url"]}' and '${_gh_state["$key_https_url"]}' that do not match the git remote URL '$_url'."
    }

    # merge GitHub API state into repo state for the fields we care about
    _state["$key_repo_id"]="${_gh_state["$key_repo_id"]}"
    _state["$key_default_branch"]="${_gh_state["$key_default_branch"]}"

    return "$_rc"
}

#-------------------------------------------------------------------------------
# @description Tests if the specified repo state has a local Git repository, i.e. if the `root`
#   key is set to a non-empty, existing directory path.
#
# @arg $1 nameref Name of an associative array variable holding the repo state.
#
# @exitcode 0 If the repo state has a local Git repository.
# @exitcode 1 If it does not.
# @exitcode 2 If the number of arguments is not exactly one, or if $1 is not a declared associative
#   array.
#-------------------------------------------------------------------------------
function has_local_repo()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _state="$1"
    [[ -v _state["$key_root"] && -n ${_state["$key_root"]} && -d ${_state["$key_root"]} ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the specified repo state has a remote Git repository, i.e. if the `url`
#   key is set to a non-empty value.
#
# @arg $1 nameref Name of an associative array variable holding the repo state.
#
# @exitcode 0 If the repo state has a remote Git repository.
# @exitcode 1 If it does not.
# @exitcode 2 If the number of arguments is not exactly one, or if $1 is not a declared associative
#   array.
#-------------------------------------------------------------------------------
function has_remote_repo()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _state="$1"
    [[ -v _state["$key_url"] && -n ${_state["$key_url"]} ]]
}

#-------------------------------------------------------------------------------
# @description Tests if the specified repo state has a remote GitHub repository, i.e. if the
#   `repo_id` key is set to a non-empty value.
#
# @arg $1 nameref Name of an associative array variable holding the repo state.
#
# @exitcode 0 If the repo state has a remote GitHub repository.
# @exitcode 1 If it does not.
# @exitcode 2 If the number of arguments is not exactly one, or if $1 is not a declared associative
#   array.
#-------------------------------------------------------------------------------
function has_github_remote()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _state="$1"
    [[ -v _state["$key_repo_id"] && -n ${_state["$key_repo_id"]} ]]
}


#-------------------------------------------------------------------------------
# @description Writes (serializes) a repo state as a trace message, one line per predefined key.
#   If a repo state key is missing, it is written as the missing key with an empty-string value.
#   Unknown keys are not written.
#
# Notes:
#   - Writes via `trace`, which is gated by `$verbose` and goes to stderr, not stdout.
#   - Returns immediately, without writing anything, if `$verbose` is false.
#
# @arg $1 nameref Name of an associative array variable holding the repo state to be serialized.
#
# @exitcode 0 On success (including the early no-op return when `$verbose` is false).
# @exitcode 2 If the number of arguments is not exactly one, or if $1 is not a declared associative
#   array.
#-------------------------------------------------------------------------------
function dump_repo_state()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    $verbose || return "$success"

    local -n __state="$1"
    local _key

    {
        echo "Repository state '$1':"
        for _key in "${repo_state_keys[@]}"; do
            [[ -v __state[$_key] ]] && printf "  %-15s → '%s'\n" "$_key" "${__state[$_key]}" || printf "  %-15s ✗ not set\n" "$_key"
        done
    } | trace

    return "$success"
}

#-------------------------------------------------------------------------------
# @description Reads (deserializes) a repo state from stdin, in `key=value` lines. If a repo state
#   key is missing from stdin, it is still added, with an empty-string value. Unknown keys are
#   stored as-is (a trace warning is emitted for each).
#
# @arg $1 nameref Name of an associative array variable to receive the deserialized repo state.
#
# @exitcode 0 On success.
# @exitcode 2 If the number of arguments is not exactly one, or if $1 is not a declared associative
#   array.
#-------------------------------------------------------------------------------
function read_repo_state()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    initialize_repo_state "$1"

    local -n _state="$1"
    local _key _value
    while IFS='=' read -r _key _value; do
        is_in "$_key" "${repo_state_keys[@]}" &&
            trace "read_repo_state: '$_key'='$_value'" ||
            trace "⚠️  WARNING: Unexpected key '$_key' in the repo state input."
        _state["$_key"]="$_value"
    done
}

#-------------------------------------------------------------------------------
# @description Prints the repository state to stdout, one line per predefined key.
#
# @arg $1 nameref Name of an associative array variable holding the repo state to be printed.
#
# @exitcode 0 On success.
# @exitcode 2 If the number of arguments is not exactly one, or if $1 is not a declared associative
#   array.
#
# @stdout `Repository state:` followed by one `  key: value` line per predefined key.
#-------------------------------------------------------------------------------
function print_repo_state()
{
    local -i _rc="$success"

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _state="$1"
    local _key
    echo "Repository state:"
    for _key in "${repo_state_keys[@]}"; do
        [[ -v _state["$_key"] ]] && echo "  $_key: ${_state[$_key]}" || echo "  $_key: "
    done
}

#-------------------------------------------------------------------------------
# @description Tests if the current or the specified directory is inside a Git working tree.
#
# @arg $1 string Path to the directory to test (optional, default: `$initial_cwd`).
#
# @exitcode 0 If the directory is inside a Git working tree.
# @exitcode 1 If it is not.
# @exitcode 2 If more than one argument is provided, or if $1 (when provided) is not a directory.
#
# @example
#   if is_inside_work_tree "$PWD"; then echo "Inside Git repo"; fi
#-------------------------------------------------------------------------------
function is_inside_work_tree()
{
    local -i _rc="$success"

    (( $# == 0 || $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires 0 or 1 argument (provided $#): path to a directory."
    }
    [[ ! -v 1 || -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 1 to be an existing directory (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _path="${1:-$initial_cwd}"

    git -C "$_path" rev-parse --is-inside-work-tree &> "$_ignore"
}

#-------------------------------------------------------------------------------
# @description Retrieves the root of the Git repository working tree for the specified directory,
#   or the current directory.
#
# @arg $1 string Path to a directory inside a Git repository working tree (optional, default:
#   `$initial_cwd`).
#
# @exitcode 0 On success.
# @exitcode 2 If $1, or the current directory, is not inside a Git repository working tree.
#
# @stdout The absolute path to the root of the Git repository working tree.
#
# @example
#   root_working_tree "$PWD"
#-------------------------------------------------------------------------------
function root_working_tree()
{
    local -i _rc="$success"

    (( $# <= 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() accepts at most one argument (provided $#): an optional directory inside a Git working tree."
    }
    [[ ! -v 1 || -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 1 to be an existing directory (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _path="${1:-$initial_cwd}"

    is_inside_work_tree "$_path" || {
        _rc="$err_not_git_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() the parameter \$1 or the current directory must be a path to a directory inside a Git repository working tree."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    git -C "$_path" rev-parse --show-toplevel 2> "$_ignore"
}

#-------------------------------------------------------------------------------
# @description Tests whether local Git metadata is stale enough to justify fetching before
#   evaluating latest-stable-tag predicates.
#
# Notes:
#   - Conservative by design: uncertain states return `$positive` (fetch recommended).
#   - Compares the local vs. remote branch tip SHA, and the latest local vs. remote stable release
#     tag name.
#
# @arg $1 string Path to a Git repository (optional, if the remaining parameters are not provided;
#   default: `$initial_cwd`).
# @arg $2 string The branch to compare against (optional, default: `main`).
#
# @exitcode 0 (`$positive`) If a fetch is recommended.
# @exitcode 1 (`$negative`) If local metadata appears fresh.
# @exitcode 2 If more than 2 arguments are provided, if $1 (when provided) is not an existing
#   directory, or if $2 (when provided) is not a valid branch name.
# @exitcode * `err_not_git_directory` if $1, or the current directory, is not inside a Git work
#   tree.
#
# @example
#   if should_fetch_for_latest_stable_tag "$repo_dir"; then git fetch ...; fi
# @example
#   should_fetch_for_latest_stable_tag "$repo_dir" && git -C "$repo_dir" fetch origin --tags --quiet
#-------------------------------------------------------------------------------
function should_fetch_for_latest_stable_tag()
{
    local -i _rc="$success"

    (( $# <= 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires no more than 2 arguments (provided $#):" \
                              "  - path to an existing directory (Git repository) (optional if the remaining parameters are not provided, default: current working directory)" \
                              "  - the branch name to compare against (optional, default: main)."
    }
    [[ ! -v 1 || -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 1 to be an existing Git repository directory (provided '${1-<missing>}')."
    }
    [[ ! -v 2 ]] || git check-ref-format --branch "$2" &> "$_ignore" || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 2 to be a valid Git branch name (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _dir=${1:-$initial_cwd}
    local _branch=${2:-main}

    is_inside_work_tree "$_dir" || {
        error -sd 3 -ec "$err_not_git_directory" "${FUNCNAME[0]}() the parameter \$1 or the current directory must be inside a Git work tree."
        return "$err_not_git_directory"
    }

    # Shallow repositories can miss history or tags needed by release predicates - yes we need a fetch
    [[ $(git -C "$_dir" rev-parse --is-shallow-repository 2>"$_ignore") != true ]]              || return "$positive"

    local _local_sha _remote_sha

    # no locally-cached SHA - no fetch needed
    _local_sha=$(git -C "$_dir" rev-parse --verify "refs/remotes/origin/$_branch" 2>"$_ignore") || return "$negative"
    # no remote SHA for the branch - no fetch needed
    _remote_sha=$(git -C "$_dir" ls-remote --heads origin "$_branch" 2>"$_ignore" | awk 'NR==1 {print $1}')
    [[ -n "$_remote_sha" ]]                                                                     || return "$negative"
    # SHAs are equal - no fetch needed
    [[ "$_local_sha" != "$_remote_sha" ]]                                                       || return "$negative"

    local _local_stable_tag _remote_stable_tag

    # Get latest stable tag
    _local_stable_tag=$(git -C "$_dir" tag | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    # no local stable tags - fetch needed
    [[ -n "$_local_stable_tag" ]]                                                               || return "$positive"
    # Get latest stable tag from remote
    _remote_stable_tag=$(git -C "$_dir" ls-remote --tags --refs origin 2>"$_ignore" | awk '{print $2}' | sed 's#refs/tags/##' | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    # no local stable tags - fetch needed
    [[ -n "$_remote_stable_tag" ]]                                                               || return "$positive"
    # stable tags are not the same - fetch needed
    [[ "$_local_stable_tag" == "$_remote_stable_tag" ]]                                          && return "$negative"

    # fetch needed
    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Ensures that the Git repository in the specified directory has fresh metadata, by
#   fetching from the remote if `should_fetch_for_latest_stable_tag` recommends it.
#
# @arg $1 string Path to a Git repository (optional, if the remaining parameters are not provided;
#   default: `$initial_cwd`).
# @arg $2 string The branch to compare against (optional, default: `main`).
#
# @exitcode 0 If no fetch was needed, or the fetch succeeded.
# @exitcode * If `git fetch` failed, or if `should_fetch_for_latest_stable_tag` itself returned an
#   error (e.g. invalid arguments, not a Git directory).
#
# @example
#   ensure_fresh_git_state "$repo_dir"
#-------------------------------------------------------------------------------
function ensure_fresh_git_state()
{
    local -i _rc=$positive

    should_fetch_for_latest_stable_tag "$@" || _rc=$?

    case $_rc in
        "$positive" )
            trace "Git metadata appears stale or repository is shallow. Fetching from origin..."
            _rc=$success
            git -C "$1" fetch origin "${2:-main}" --quiet 2> "$_ignore" || {
                _rc=$?
                error -ec "$err_logic_error" "Failed to fetch from origin: $_rc"
            }
            ;;
        "$negative" )
            trace "Git metadata appears fresh. No fetch needed."
            _rc="$success"
            ;;
        * )
            trace "Error while checking if Git metadata is fresh: $_rc"
            ;;
    esac

    return "$_rc"
}

#-------------------------------------------------------------------------------
# @description Gets the commit hash of the latest stable tag in the specified Git repository.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_cwd`).
# @arg $2 bool Ensure fresh Git status (optional, default: true).
#
# @exitcode 0 On success.
# @exitcode 1 (`$failure`) If no stable tags are found.
# @exitcode 2 If more than 2 arguments are provided, if $1 (when provided) is not an existing
#   directory, or if $1/current directory is not inside a Git work tree.
#
# @stdout The commit hash of the latest stable tag.
#
# @example
#   latest_hash=$(get_latest_stable_tag_hash "$repo_dir")
#-------------------------------------------------------------------------------
function get_latest_stable_tag_hash()
{
    local -i _rc="$success"

    (( $# <= 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() takes 0, 1 or 2 arguments (provided $#)" \
                              "  \$1 - a directory. Optional, default: the current working directory." \
                              "  \$2 - boolean to fetch the latest changes in main from remote (default true)."
    }
    [[ ! -v 1 || -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 1 to be an existing Git repository directory (provided '${1-<missing>}')."
    }
    [[ ! -v 2 ]] || is_boolean "$2" || {
        _rc="$err_argument_type"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 2, the fetch flag, to be 'true' or 'false' (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _dir=${1:-$initial_cwd}
    local _should_fetch=${2:-true}

    is_inside_work_tree "$_dir" || {
        _rc="$err_not_git_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires the selected directory '$_dir' to be inside a Git working tree."
        return "$_rc"
    }

    if $_should_fetch; then
        ensure_fresh_git_state "$_dir" || {
            _rc=$?
            error -ec "$_rc" "Failed to ensure fresh Git state for '$_dir': $_rc"
            return "$_rc"
        }
    fi

    local _latest_stable_tag _latest_stable_hash

    # Get latest stable tag (excludes pre-release tags with -)
    _latest_stable_tag=$(git -C "$_dir" tag | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    [[ -n $_latest_stable_tag ]] ||
        return "$failure" # no stable tags? - return 1

    # get the hash of the commit of the latest stable tag
    git -C "$_dir" rev-parse "$_latest_stable_tag^{commit}" 2>"$_ignore"
}

#-------------------------------------------------------------------------------
# @description Tests if the current commit in the specified directory is after the latest stable
#   tag. Depends on `get_latest_stable_tag_hash`.
#
# Notes:
#   - This function does not validate its own argument count directly; it relies entirely on
#     `get_latest_stable_tag_hash` to reject bad arguments.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_cwd`).
# @arg $2 bool Ensure fresh Git status - passed through to `get_latest_stable_tag_hash`.
#
# @exitcode 0 If the current commit is after the latest stable tag.
# @exitcode 1 If it is not.
# @exitcode * Whatever `get_latest_stable_tag_hash` returns on error (e.g. no stable tags, invalid
#   arguments, not a Git directory).
#
# @example
#   if is_after_latest_stable_tag "$repo_dir"; then echo "Beyond latest stable"; fi
#-------------------------------------------------------------------------------
function is_after_latest_stable_tag()
{
    local _latest_stable_hash _commits_after_latest_stable
    local -i _rc

    # get commit of the latest stable tag
    _latest_stable_hash=$(get_latest_stable_tag_hash "$@") || return $?

    # How many commits since the latest stable tag
    _commits_after_latest_stable=$(git -C "${1:-$initial_cwd}" rev-list "$_latest_stable_hash..HEAD" --count 2>"$_ignore")
    (( _commits_after_latest_stable > 0 ))
}

#-------------------------------------------------------------------------------
# @description Tests if the current commit in the specified directory is on or after the latest
#   stable tag. Depends on `get_latest_stable_tag_hash`.
#
# Notes:
#   - Like `is_after_latest_stable_tag`, this function does not validate its own argument count
#     directly; it relies entirely on `get_latest_stable_tag_hash` to reject bad arguments.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_cwd`).
# @arg $2 bool Passed through to `get_latest_stable_tag_hash`.
#
# @exitcode 0 If the current commit is on or after the latest stable tag.
# @exitcode 1 If it is before.
# @exitcode * Whatever `get_latest_stable_tag_hash` returns on error (e.g. no stable tags, invalid
#   arguments, not a Git directory).
#
# @example
#   if is_on_or_after_latest_stable_tag "$repo_dir"; then echo "Ready for release"; fi
#-------------------------------------------------------------------------------
function is_on_or_after_latest_stable_tag()
{
    local _latest_stable_tag_hash

    # get commit of the latest stable tag
    _latest_stable_tag_hash=$(get_latest_stable_tag_hash "$@") || return $?

    # Check if current commit is on or after the latest tag
    # Returns 0 if tag commit is an ancestor of HEAD (i.e., HEAD is at or after the tag)
    git -C "${1:-$initial_cwd}" merge-base --is-ancestor "$_latest_stable_tag_hash" HEAD &> "$_ignore"
}

#-------------------------------------------------------------------------------
# @description Get the absolute path to the root of all artifacts directories.
#
# @arg $1 string project - The absolute or relative path to the project file. It MUST be resolvable from the current working
#   directory. (e.g. "src/Ulid/Ulid.csproj").
# @arg $2 string artifacts - The name of the artifacts directory. If it is a relative path, it will be resolved - relative to
#   the working tree root of the project's repository; it does not need to exist. If $2 is an absolute path, it will be used
#   as-is, but it MUST exist. Arg $1 will be ignored.
#
# @exitcode 0 if the absolute path to the artifacts directory is successfully determined, non-zero otherwise.
# @exitcode 4 if the specified absolute path to the artifacts directory is invalid, or does not exist, or is not a directory.
#
# @stdout The absolute path to the artifacts directory.
#-------------------------------------------------------------------------------
function get_artifacts_path()
{
    local -i _rc=$success

    (( $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" \
                "${FUNCNAME[0]}() expects two arguments (provided $#):" \
                "  1) the parent directory of all vm2 repositories" \
                "  2) the root of the artifacts directories"
    }

    local _artifacts="${2:-${ARTIFACTS_DIR:-}}"

    [[ -n $_artifacts ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, or ARTIFACTS_DIR, to provide a non-empty artifacts path (argument 2: '${2-<missing>}')."
    }
    [[ $_artifacts == /* || ( -v 1 && -n $1 ) ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the project path, to be non-empty when the artifacts path is relative (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    if [[ $_artifacts == /* ]]; then
        realpath -e "$_artifacts" && [[ -d "$_artifacts" ]] && return "$success"
        error -sd 3 -ec "$err_argument_value" "The artifacts directory '$_artifacts' is an absolute path, but it does not specify a valid, existing directory. Please, create it or correct the parameter/environment variable."
        return "$err_argument_value"
    fi

    local _project_path="$1"
    local _repo_root

    _project_path=$(dirname "$_project_path") || {
        error -ec "$err_argument_value" "Failed to resolve real path for '$1'."
        return "$err_argument_value"
    }
    _repo_root="$(root_working_tree "$_project_path")"
    realpath -m "${_repo_root}/${_artifacts}"
    return "$success"
}
