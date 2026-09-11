# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#=============================================================================================
# This script defines functions for working with Git and GitHub repositories.
# It includes functions for validating GitHub repository owners and names, parsing GitHub
# URLs, and other Git-related utilities.
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_GIT_SH_LOADED:-0} == 1 )) && return 0
declare -xri __VM2_LIB_GIT_SH_LOADED=1

# Declare error codes defined in the core library.
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_invalid_nameref
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_logic_error
declare -xri err_not_found
declare -xri err_not_file
declare -xri err_not_directory
declare -xri err_not_git_directory
declare -xri err_not_git_root

# Declare variables defined in the core library.
declare -x _ignore
declare -xr semverTagReleaseRegex

# variables specific to this script only - regexes for validating GitHub repository URLs, owners, and names
declare -xr gh_ssh_authority='git@github.com'                           # OK, it is actually the URI schema only, but we only support GitHub SSH URLs for now, so we can hardcode the authority and just call it that. This is the part of the URL before the owner/name, e.g. "git@github.com"
declare -xr gh_https_authority='https://github.com'                     # OK, it is actually the URI schema + authority, but we only support GitHub HTTPS URLs for now, so we can hardcode the authority and just call it that. This is the part of the URL before the owner/name, e.g. "https://github.com"

declare -xr repo_ssh_schema_rex='git'
declare -xr repo_https_schema_rex='https'

declare -xr repo_schema_rex="($repo_ssh_schema_rex|$repo_https_schema_rex)"
declare -xr repo_authority_rex="github\.com"
# declare -xr repo_authority_rex='git@github\.com|https://github\.com'    # OK. it is actually the URI schema + authority, but we only support GitHub URLs for now, so we can hardcode the authority and just call it that. This is the part of the URL before the owner/name, e.g. "git@github.com" or "https://github.com"
declare -xr repo_owner_rex='[a-zA-Z0-9][a-zA-Z0-9-]{0,37}[a-zA-Z0-9]'     # GitHub owner/organization names can be up to 39 characters, must start and end with a letter or digit, and can contain letters, digits, and hyphens. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.
declare -xr repo_name_rex='[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}'               # GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.

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

readonly __valid_repo_names_msg="GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit.
See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details."

#---------------------------------------------------------------------------------------------
# @description Validates that the specified repository owner is valid according to GitHub
#   naming rules, i.e. it matches the regular expression for GitHub owner/organization names.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository owner naming rules.
#
# @arg $1 string The repository owner to validate.
#
# @exitcode success/positive=0: If the repository owner is valid.
#
# @example
#   if validate_gh_repo_owner "my-org"; then echo "Valid repo owner"; fi
#---------------------------------------------------------------------------------------------
function validate_gh_repo_owner()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository owner to validate."

    exit_if_has_bugs

    local -i _rc="$success"

    [[ -z $1 || $1 =~ $repo_owner_regex ]] || {
        # repo owner can be empty (for user-level repos) or must match the regex for GitHub owner/organization names
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be empty or a valid repository owner (provided '${1:-<none>}')."
        return "$_rc"
    }
}

#---------------------------------------------------------------------------------------------
# @description Validates that the specified repository name is valid according to GitHub
#   naming rules, i.e. it matches the regular expression for GitHub repository names and does
#   not end with `.git`.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository naming rules.
#
# @arg $1 string The repository name to validate.
#
# @exitcode success/positive=0: If the repository name is valid.
#
# @example
#   if validate_gh_repo_name "my-repo"; then echo "Valid repo name"; fi
# @example
#   enter_value "GitHub Repository name" repo_name "$default_repo_name" false validate_gh_repo_name
#---------------------------------------------------------------------------------------------
function validate_gh_repo_name()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository name to validate."

    exit_if_has_bugs

    local -i _rc="$success"

    [[ -n $1 && $1 != *.git && $1 =~ $repo_name_regex ]] || {
        # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be a valid repository name (provided '${1:-<none>}'). $__valid_repo_names_msg"
        return "$_rc"
    }
}

#---------------------------------------------------------------------------------------------
# @description Validates that the specified repository description is valid according to GitHub
#   rules, i.e. it is between 3 and 350 characters long.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository description rules.
#
# @arg $1 string The repository description to validate.
#
# @exitcode success/positive=0: If the repository description is valid.
#
# @example
#   if validate_gh_repo_description "This is my repo"; then echo "Valid repo description"; fi
# @example
#   enter_value "GitHub Repository description" repo_description "$default_repo_description" false validate_gh_repo_description)
#---------------------------------------------------------------------------------------------
function validate_gh_repo_description()
{
    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository description to validate."

    exit_if_has_bugs

    local -i _rc="$success"

    (( ${#1} >= 3 && ${#1} <= 350 )) || {
        # GitHub repository descriptions must be between 3 and 350 characters long.
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the repository description, to contain between 3 and 350 characters (provided '${1:-<none>}')."
        return "$_rc"
    }
}

#---------------------------------------------------------------------------------------------
# @description Validates that the specified repository branch name is valid according to Git
#   branch naming rules, i.e. it is a valid Git ref name.
#
# Notes:
#   - See [git-check-ref-format](https://git-scm.com/docs/git-check-ref-format) for details on
#     valid Git ref names.
#
# @arg $1 string The repository branch name to validate.
#
# @exitcode success/positive=0: If the branch name is valid.
#
# @example
#   if validate_branch_name "main"; then echo "Valid branch name"; fi
# @example
#   enter_value "Default branch name" branch_name "$default_branch" false validate_branch_name)
#---------------------------------------------------------------------------------------------
function validate_branch_name()
{
    local -i _rc="$success"

    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository branch name to validate."

    exit_if_has_bugs

    git check-ref-format --branch "$1" &> "$_ignore" || {
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be a valid Git branch name (provided '${1:-<none>}'). See https://git-scm.com/docs/git-check-ref-format for details."
        return "$_rc"
    }
}

#---------------------------------------------------------------------------------------------
# @description Executes a GitHub CLI (`gh`) command with retry logic for transient failures.
#
# Notes:
#   - stdout is written to `$output` (either `/dev/stdout` or `$_ignore`, depending on
#     `ignore_output`); stderr is always written to the caller's stderr.
#   - Retries only on errors that look transient, based on a pattern match against stderr:
#     `rate limit`, `server error`, `timeout`, `temporarily unavailable`, `try again`,
#     `502`/`503`/`504`, `connection refused`, `network error`.
#   - Non-transient errors (invalid args, not found, permissions, etc.) fail immediately
#     without retrying.
#   - Honors `$dry_run`: if set, prints the command to stderr and returns success without
#     executing it.
#
# @arg $1 int Maximum number of attempts.
# @arg $2 int Delay between attempts, in seconds.
# @arg $3 bool If present and a valid boolean, suppresses stdout when true (optional, default:
#   false). If not a boolean, it is treated as the start of the `gh` command's own arguments.
# @arg $@ string The `gh` command and its arguments (subcommand, flags, etc.) — starts at $3
#   or $4 depending on whether the optional `ignore_output` flag was given.
#
# @exitcode success/positive=0: If the command eventually succeeds.
# @exitcode * Otherwise, the last exit code returned by `gh`, or `err_logic_error` if all
#   retry attempts are exhausted.
#
# @example
#   execute_gh_with_retry 3 5 repo create my-repo --public
# @example
#   execute_gh_with_retry 3 2 true repo delete owner/repo --yes
#---------------------------------------------------------------------------------------------
function execute_gh_with_retry()
{
    (( $# >= 3 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least three arguments (provided $#):" \
                                                                            "  - maximum number of attempts" \
                                                                            "  - delay between attempts, in seconds" \
                                                                            "  - <gh-command> [args...]"
    [[ ! -v 1 ]]  || is_natural "$1" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires the first argument to be a natural number: <max_attempts>"
    [[ ! -v 2 ]]  || is_natural "$2" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires the second argument to be a natural number: <delay> in seconds"

    exit_if_has_bugs

    local -i _rc="$success"

    # get the first two and the optional third (ignore_output) boolean parameter
    local _max_attempts=$1
    local _delay=$2
    shift 2

    local _ignore_output=false
    is_boolean "$1" && _ignore_output=$1 && shift

    local _output
    $_ignore_output &&
        _output="$_ignore" ||
        _output="/dev/stdout"

    is_dry_run && echo "dry-run$ gh $*" >&2 && return "$success"

    # stderr goes to a temp file to preserve output fidelity (especially newlines), yet still allows us to process them separately
    local _stderr_file
    local _stdout_file
    _stderr_file=$(mktemp)
    _stdout_file=$(mktemp)

    local _attempt=0
    local _message=""

    trace "Executing with retry from (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): 'gh $*'"

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

#---------------------------------------------------------------------------------------------
# @description Executes a `gh api` command with retry logic for transient failures.
#
# Notes:
#   - stdout is written to `$output` (either `/dev/stdout` or `$_ignore`, depending on
#     `ignore_output`); stderr is always written to the caller's stderr.
#   - Prefers the JSON `.status` field from the response body to decide whether an error is
#     transient: `425`, `429`, `500`, `502`, `503`, `504` are retried; `1xx`/`2xx`/`3xx` are
#     treated as success; anything else fails immediately.
#   - If the response has no usable JSON `.status`, falls back to a pattern match against
#     stderr (`authentication`, `network`, `timeout`, `dns`, `connection`) to decide whether
#     to retry.
#   - Honors `$dry_run`: if set, prints the command to stderr and returns success without
#     executing it.
#
# @arg $1 int Maximum number of attempts.
# @arg $2 int Delay between attempts, in seconds.
# @arg $3 bool If present and a valid boolean, suppresses stdout when true (optional, default:
#   false). If not a boolean, it is treated as the start of the `gh api` command's own
#   arguments.
# @arg $@ string The `gh api` route and its arguments — starts at $3 or $4 depending on
#   whether the optional `ignore_output` flag was given.
#
# @exitcode success/positive=0: If the command eventually succeeds.
# @exitcode * Otherwise, the last exit code returned by `gh api`, or `err_logic_error` if all
#   retry attempts are exhausted.
#
# @example
#   execute_gh_api_with_retry 3 5 repos/vmelamed/my-repo
#---------------------------------------------------------------------------------------------
function execute_gh_api_with_retry()
{
    (( $# >= 3 ))                        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at least three arguments (provided $#):" \
                                                                                "  - maximum number of attempts" \
                                                                                "  - delay between attempts, in seconds" \
                                                                                "  - if present and a valid boolean, suppresses stdout when true (optional, default: false)" \
                                                                                "  - the 'gh api' command to execute" \
                                                                                "  - [args...] Arguments for the 'gh api' command"
    [[ ! -v 1 ]] || is_non_negative "$1" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires the first argument to be a natural number: <max_attempts>"
    [[ ! -v 2 ]] || is_non_negative "$2" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires the second argument to be a natural number: <delay> in seconds"

    exit_if_has_bugs

    local -i _rc="$success"

    # get the first two and the optional third (ignore_output) boolean parameter
    local _max_attempts=$1
    local _delay=$2
    shift 2

    local _ignore_output=false
    is_boolean "$1" &&
        _ignore_output=$1 &&
        shift

    local _output
    $_ignore_output &&
        _output="$_ignore" ||
        _output="/dev/stdout"

    is_dry_run && echo "dry-run$ gh $*" >&2 && return "$success"

    # stderr and stdout go to temp files to preserve output fidelity (especially newlines), yet still allow us to process them separately
    local _stderr_file
    local _stdout_file
    _stderr_file=$(mktemp)
    _stdout_file=$(mktemp)

    local _attempt=0
    local _response="" message="" status=""

    trace "Executing with retry @ (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): gh api $*"

    until gh api "$@" >"$_stdout_file" 2>"$_stderr_file"; do
        _rc=$?

        cat "$_stderr_file" >&2

        _response=$(cat "$_stdout_file")           || true
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

    rm -f "$_stderr_file" "$_stdout_file"

    return "$_rc"
}

#=============================================================================================
# With the following constants and functions we define the repository state: it is an
# associative array with predefined keys.
# The following constants define the predefined keys of a repo state:
#=============================================================================================
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

#=============================================================================================
# The following list contains the predefined keys of a repo state:
#=============================================================================================
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


#---------------------------------------------------------------------------------------------
# @description Initializes a repo state to its initial state, where it contains all predefined
#   keys with empty-string values.
#
# @arg $1 nameref to an associative array variable to be initialized as a repo state.
#---------------------------------------------------------------------------------------------
function initialize_repo_state()
{
    (( $# == 1 ))                                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    [[ ! -v 1 ]] || is_defined_associative_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array for repository state (provided '${1:-<none>}')."

    exit_if_has_bugs

    local -n _state="$1"
    local _key
    _state=()
    for _key in "${repo_state_keys[@]}"; do
        _state+=(["$_key"]='')
    done
}

#---------------------------------------------------------------------------------------------
# @description Retrieves the Git repository state for a specified directory by finding the Git
#   repository root and parsing the origin remote URL, if it exists and is a GitHub URL.
#
# Notes:
#   - If the directory is not inside a Git work tree, has no `origin` remote, or the `origin`
#     remote is not a GitHub URL, the function returns success early with only the fields it
#     managed to populate (the rest stay at the empty-string default from
#     `initialize_repo_state`).
#   - If `full_info` is false, the function stops after populating the local Git-derived
#     fields and does not call the GitHub API.
#   - When GitHub API data is fetched, the function cross-checks it against the local Git
#     remote data (URL, owner, name, repo, and presence of a repo ID) and logs an error for
#     every mismatch found, rather than stopping at the first one.
#
# @arg $1 string path to the existing root of the Git repository working tree.
# @arg $2 nameref to an associative array variable to receive the repo state.
# @arg $3 bool If false, only retrieve the local Git repository state without querying the
#   GitHub API (optional, default: true).
#
# @exitcode success/positive=0: On success, or when the directory has no local/GitHub repo state to report.
# @exitcode failure/negative=1: If the GitHub API data does not match the local Git remote data.
#
# @example
#   get_repo_state "/home/valo/repos/vm2.Glob" repo_state
#---------------------------------------------------------------------------------------------
function get_repo_state()
{
    (( $# == 2 || $# == 3 ))                          || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 or 3 arguments (provided $#):" \
                                                                                            "  - the existing path to the root of the git repo working tree" \
                                                                                            "  - nameref: the name of an associative array variable - to receive the repo state" \
                                                                                            "  - full_info - if false, only retrieve the local Git repository state without trying to get GitHub API data (optional, default: true)"
    [[ ! -v 1 || -d $1 ]]                             || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 1 to be the existing root directory of the Git working tree (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_defined_associative_array "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to name an associative array that will receive the repository state (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_boolean "$3"                   || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires optional argument 3, the full-information flag, to be 'true' or 'false' (provided '${3:-<none>}')."

    exit_if_has_bugs

    local _full_info=${3:-true}

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local -n _state="$2" # associative array variable to receive the repo state, passed by nameref
    initialize_repo_state "$2" # make sure we have all fields

    local _url
    _state["$key_root"]=$(git -C "$1" rev-parse --show-toplevel 2>"$_ignore") || return "$success" # no local git repo
    _url=$(git -C "$1" remote get-url origin 2>"$_ignore")                    || return "$success" # no origin remote
    [[ -n $_url && $_url =~ $github_url_regex ]]                              || return "$success" # origin remote is not a GitHub URL

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
    local _repo="$_owner/$_name"
    _state["$key_name"]=$_name
    _state["$key_repo"]=$_repo

    $_full_info || return "$success" # caller does not want full info - return with what we have from git, without trying to get GitHub API data

    local -A _gh_state
    local _k _v

    while IFS='=' read -r _k _v; do
        _gh_state["$_k"]="$_v"
    done < <(execute_gh_api_with_retry 3 2 --paginate "repos/$_repo" -q "$jq_gh_repo_state")

    local -i _rc="$success"

    # make sure all is kosher: the GitHub API data should match the local git remote data for the fields we care about
    # these are real logical problems that may occur if the git remote is misconfigured or the API is returning unexpected data,
    # so we check them all and report all mismatches rather than bailing on the first one
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ $_schema == "$repo_ssh_schema_rex"   && ${_gh_state["$key_ssh_url"]}   == "$_url" ||
       $_schema == "$repo_https_schema_rex" && ${_gh_state["$key_https_url"]} == "$_url"    ]] &&
    [[ ${_gh_state["$key_owner"]} == "$_owner"                                              ]] &&
    [[ ${_gh_state["$key_name"]}  == "$_name"                                               ]] &&
    [[ ${_gh_state["$key_repo"]}  == "$_repo"                                               ]] &&
    [[ -n ${_gh_state["$key_repo_id"]}                                                      ]] &&
        _rc=$success || {
        _rc=$failure
        error -ec "$err_logic_error" "GitHub API returned URLs '${_gh_state["$key_ssh_url"]}' and '${_gh_state["$key_https_url"]}' that do not match the git remote URL '$_url'."
    }

    # merge GitHub API state into repo state for the fields we care about
    _state["$key_repo_id"]="${_gh_state["$key_repo_id"]}"
    _state["$key_default_branch"]="${_gh_state["$key_default_branch"]}"

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the specified repo state has a local Git repository, i.e. if the
#   `root` key is set to a non-empty, existing directory path.
#
# @arg $1 nameref to an associative array variable holding the repo state.
#
# @exitcode success/positive=0: If the repo state has a local Git repository.
# @exitcode failure/negative=1: If it does not.
#---------------------------------------------------------------------------------------------
function has_local_repo()
{
    (( $# == 1 ))                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    is_defined_associative_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1:-<none>}')."

    exit_if_has_bugs

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local -n _state="$1"
    [[ -v _state["$key_root"] && -n ${_state["$key_root"]} && -d ${_state["$key_root"]} ]]
}

#---------------------------------------------------------------------------------------------
# @description Tests if the specified repo state has a remote Git repository, i.e. if the
#   `url` key is set to a non-empty value.
#
# @arg $1 nameref to an associative array variable holding the repo state.
#
# @exitcode success/positive=0: If the repo state has a remote Git repository.
# @exitcode failure/negative=1: If it does not.
#---------------------------------------------------------------------------------------------
function has_remote_repo()
{
    (( $# == 1 ))                                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    [[ ! -v 1 ]] || is_defined_associative_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1:-<none>}')."

    exit_if_has_bugs

    local -n _state="$1"
    [[ -v _state["$key_url"] && -n ${_state["$key_url"]} ]]
}

#---------------------------------------------------------------------------------------------
# @description Tests if the specified repo state has a remote GitHub repository, i.e. if the
#   `repo_id` key is set to a non-empty value.
#
# @arg $1 nameref to an associative array variable holding the repo state.
#
# @exitcode success/positive=0: If the repo state has a remote GitHub repository.
# @exitcode failure/negative=1: If it does not.
#---------------------------------------------------------------------------------------------
function has_github_remote()
{
    (( $# == 1 ))                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    is_defined_associative_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1:-<none>}')."

    exit_if_has_bugs

    local -n _state="$1"
    [[ -v _state["$key_repo_id"] && -n ${_state["$key_repo_id"]} ]]
}

#---------------------------------------------------------------------------------------------
# @description Reads (deserializes) a repo state from stdin, in `key=value` lines. If a repo
#   state key is missing from stdin, it is still added, with an empty-string value. Unknown
#   keys are stored as-is (a trace warning is emitted for each).
#
# @arg $1 nameref to an associative array variable to receive the deserialized repo state.
#---------------------------------------------------------------------------------------------
function read_repo_state()
{
    (( $# == 1 ))                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    is_defined_associative_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1:-<none>}')."

    exit_if_has_bugs

    initialize_repo_state "$1"

    local -n _state="$1"
    local _key _value
    while IFS='=' read -r _key _value; do
        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        is_in "$_key" "${repo_state_keys[@]}" &&
            trace "read_repo_state: '$_key'='$_value'" ||
            trace "⚠️  WARNING: Unexpected key '$_key' in the repo state input."
        _state["$_key"]="$_value"
    done
}

#---------------------------------------------------------------------------------------------
# @description Prints the repository state to stdout, one line per predefined key.
#
# @arg $1 nameref to an associative array variable holding the repo state to be printed.
#
# @stdout `Repository state:` followed by one `  key: value` line per predefined key.
#---------------------------------------------------------------------------------------------
function print_repo_state()
{
    (( $# == 1 ))                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    is_defined_associative_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1:-<none>}')."

    exit_if_has_bugs

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local -n _state="$1"
    local _key
    echo "Repository state:"
    for _key in "${repo_state_keys[@]}"; do
        [[ -v _state["$_key"] ]] &&
            echo "  $_key: ${_state[$_key]}" ||
            echo "  $_key: "
    done
}

#---------------------------------------------------------------------------------------------
# @description Tests if the current or the specified directory is inside a Git working tree.
#
# @arg $1 string Path to the directory to test (optional, default: `$initial_cwd`).
#
# @exitcode success/positive=0: If the directory is inside a Git working tree.
# @exitcode failure/negative=1: If it is not.
#
# @example
#   if is_inside_work_tree "$PWD"; then echo "Inside Git repo"; fi
#---------------------------------------------------------------------------------------------
function is_inside_work_tree()
{
    (( $# == 0 || $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 0 or 1 argument (provided $#): path to a directory."
    [[ ! -v 1 || -d $1 ]]    || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires optional argument 1 to be an existing directory (provided '${1:-<none>}')."

    exit_if_has_bugs

    local _path="${1:-$initial_cwd}"

    # normalize to $positive/$negative -- `git rev-parse` exits 128 (its generic "fatal" code),
    # not 1, when the directory is not inside a work tree.
    git -C "$_path" rev-parse --is-inside-work-tree &> "$_ignore" && return "$positive" || return "$negative"
}

#---------------------------------------------------------------------------------------------
# @description Retrieves the root of the Git repository working tree for the specified
#   directory, or the current directory.
#
# @arg $1 string Path to a directory inside a Git repository working tree.
# @arg $2 nameref `_repo_root` to a variable to store the absolute path of the root of
#   the Git repository containing the found directory.
#
# @exitcode success/positive=0: The Git working tree root was resolved.
# @exitcode failure/negative=1: `git rev-parse --show-toplevel` failed.
#
# @example
#   root_working_tree "$PWD" _root
#---------------------------------------------------------------------------------------------
function root_working_tree()
{
    (( $# == 2 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two arguments (provided $#):" \
                                                                                    "  - a directory inside a Git working tree" \
                                                                                    "  - the name of the variable to store the absolute path of the root of the Git working tree containing the found directory"
    [[ ! -v 1 || -d $1 ]]                    || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 1 to be an existing directory (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_defined_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to be the name of the variable to store the absolute path of the root of the Git repository containing the found directory."

    exit_if_has_bugs # gate here: $2 must be validated before creating a nameref from it below

    local _path=$1
    local -n _repo_root_ref=$2

    is_inside_work_tree "$_path"             || bug -ec "$err_not_git_directory" "${FUNCNAME[0]}() the parameter \$1 or the current directory must be a path to a directory inside a Git repository working tree."

    exit_if_has_bugs

    _repo_root_ref=$(git -C "$_path" rev-parse --show-toplevel 2> "$_ignore")
}

#---------------------------------------------------------------------------------------------
# @description Tests whether local Git metadata is stale enough to justify fetching before
#   evaluating latest-stable-tag predicates.
#
# Notes:
#   - Conservative by design: uncertain states return `$positive` (fetch recommended).
#   - Compares the local vs. remote branch tip SHA, and the latest local vs. remote stable
#     release tag name.
#
# @arg $1 string Path to a Git repository (optional, if the remaining parameters are not
#   provided; default: `$initial_cwd`).
# @arg $2 string The branch to compare against (optional, default: `main`).
#
# @exitcode success/positive=0: If a fetch is recommended.
# @exitcode failure/negative=1: If local metadata appears fresh.
#
# @example
#   if should_fetch_for_latest_stable_tag "$repo_dir"; then git fetch ...; fi
# @example
#   should_fetch_for_latest_stable_tag "$repo_dir" && git -C "$repo_dir" fetch
#   origin --tags --quiet
#---------------------------------------------------------------------------------------------
function should_fetch_for_latest_stable_tag()
{
    local -i _rc="$success"

    (( $# <= 2 ))                                                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires no more than 2 arguments (provided $#):" \
                                                                                                            "  - path to an existing directory (Git repository) (optional if the remaining parameters are not provided, default: current working directory)" \
                                                                                                            "  - the branch name to compare against (optional, default: main)"
    [[ ! -v 1 || -d $1 ]]                                            || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires optional argument 1 to be an existing Git repository directory (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || git check-ref-format --branch "$2" &> "$_ignore" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires optional argument 2 to be a valid Git branch name (provided '${2:-<none>}')."

    local _dir=${1:-$initial_cwd}
    local _branch=${2:-main}

    is_inside_work_tree "$_dir"                                      || bug -ec "$err_not_git_directory" "${FUNCNAME[0]}() the parameter \$1 or the current directory must be inside a Git work tree."

    exit_if_has_bugs

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
    _local_stable_tag=$(
        git -C "$_dir" tag |
        grep -E "$semverTagReleaseRegex" |
        sort -V |
        tail -n1
    )
    # no local stable tags - fetch needed
    [[ -n "$_local_stable_tag" ]]                                                               || return "$positive"
    # Get latest stable tag from remote
    _remote_stable_tag=$(
        git -C "$_dir" ls-remote --tags --refs origin 2>"$_ignore" |
        awk '{print $2}' |
        sed 's#refs/tags/##' |
        grep -E "$semverTagReleaseRegex" |
        sort -V |
        tail -n1
    )
    # no local stable tags - fetch needed
    [[ -n "$_remote_stable_tag" ]]                                                               || return "$positive"
    # stable tags are not the same - fetch needed
    [[ "$_local_stable_tag" == "$_remote_stable_tag" ]]                                          && return "$negative"

    # fetch needed
    return "$positive"
}

#---------------------------------------------------------------------------------------------
# @description Ensures that the Git repository in the specified directory has fresh metadata,
#   by fetching from the remote if `should_fetch_for_latest_stable_tag` recommends it.
#
# @arg $1 string Path to a Git repository (optional, if the remaining parameters are not
#   provided; default: `$initial_cwd`).
# @arg $2 string The branch to compare against (optional, default: `main`).
#
# @exitcode success/positive=0: If no fetch was needed, or the fetch succeeded.
# @exitcode * If `git fetch` failed, or if `should_fetch_for_latest_stable_tag` itself
#   returned an error (e.g. invalid arguments, not a Git directory).
#
# @example
#   ensure_fresh_git_state "$repo_dir"
#---------------------------------------------------------------------------------------------
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

#---------------------------------------------------------------------------------------------
# @description Gets the commit hash of the latest stable tag in the specified Git repository.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_cwd`).
# @arg $2 bool Ensure fresh Git status (optional, default: true).
#
# @exitcode success/positive=0: On success.
# @exitcode failure/negative=1: If no stable tags are found.
#
# @stdout The commit hash of the latest stable tag.
#
# @example
#   latest_hash=$(get_latest_stable_tag_hash "$repo_dir")
#---------------------------------------------------------------------------------------------
function get_latest_stable_tag_hash()
{
    (( $# <= 2 ))                   || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() takes 0, 1 or 2 arguments (provided $#):" \
                                                                        "  - a directory. Optional, default: the current working directory" \
                                                                        "  - boolean to fetch the latest changes in main from remote (default true)"
    [[ ! -v 1 || -d $1 ]]           || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires optional argument 1 to be an existing Git repository directory (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_boolean "$2" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires optional argument 2, the fetch flag, to be 'true' or 'false' (provided '${2:-<none>}')."

    local _dir=${1:-$initial_cwd}
    local _should_fetch=${2:-true}

    is_inside_work_tree "$_dir"     || bug -ec "$err_not_git_directory" "${FUNCNAME[0]}() requires the selected directory '$_dir' to be inside a Git working tree."

    exit_if_has_bugs

    if $_should_fetch; then
        local -i _rc
        ensure_fresh_git_state "$_dir" || {
            _rc=$?
            error -ec "$_rc" "Failed to ensure fresh Git state for '$_dir': $_rc"
            return "$_rc"
        }
    fi

    local _latest_stable_tag _latest_stable_hash

    # Get latest stable tag (excludes pre-release tags with -)
    _latest_stable_tag=$(
        git -C "$_dir" tag |
        grep -E "$semverTagReleaseRegex" |
        sort -V |
        tail -n1
    )

    [[ -n $_latest_stable_tag ]] ||
        return "$failure" # no stable tags? - return 1

    # get the hash of the commit of the latest stable tag
    git -C "$_dir" rev-parse "$_latest_stable_tag^{commit}" 2>"$_ignore"
}

#---------------------------------------------------------------------------------------------
# @description Tests if the current commit in the specified directory is after the latest
#   stable tag. Depends on `get_latest_stable_tag_hash`.
#
# Notes:
#   - This function does not validate its own argument count directly; it relies entirely on
#     `get_latest_stable_tag_hash` to reject bad arguments.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_cwd`).
# @arg $2 bool Ensure fresh Git status - passed through to `get_latest_stable_tag_hash`.
#
# @exitcode success/positive=0: If the current commit is after the latest stable tag.
# @exitcode failure/negative=1: If it is not.
# @exitcode * Whatever `get_latest_stable_tag_hash` returns on error (e.g. no stable tags,
#   invalid arguments, not a Git directory).
#
# @example
#   if is_after_latest_stable_tag "$repo_dir"; then echo "Beyond latest stable"; fi
#---------------------------------------------------------------------------------------------
function is_after_latest_stable_tag()
{
    local _latest_stable_hash _commits_after_latest_stable

    # get commit of the latest stable tag
    _latest_stable_hash=$(get_latest_stable_tag_hash "$@") || return $?

    # How many commits since the latest stable tag
    _commits_after_latest_stable=$(git -C "${1:-$initial_cwd}" rev-list "$_latest_stable_hash..HEAD" --count 2>"$_ignore")
    (( _commits_after_latest_stable > 0 ))
}

#---------------------------------------------------------------------------------------------
# @description Tests if the current commit in the specified directory is on or after the
#   latest stable tag. Depends on `get_latest_stable_tag_hash`.
#
# Notes:
#   - Like `is_after_latest_stable_tag`, this function does not validate its own argument
#     count directly; it relies entirely on `get_latest_stable_tag_hash` to reject bad
#     arguments.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_cwd`).
# @arg $2 bool Passed through to `get_latest_stable_tag_hash`.
#
# @exitcode success/positive=0: If the current commit is on or after the latest stable tag.
# @exitcode failure/negative=1: If it is before.
# @exitcode * Whatever `get_latest_stable_tag_hash` returns on error (e.g. no stable tags,
#   invalid arguments, not a Git directory).
#
# @example
#   if is_on_or_after_latest_stable_tag "$repo_dir"; then echo "Ready for release"; fi
#---------------------------------------------------------------------------------------------
function is_on_or_after_latest_stable_tag()
{
    local _latest_stable_tag_hash

    # get commit of the latest stable tag
    _latest_stable_tag_hash=$(get_latest_stable_tag_hash "$@") || return $?

    # Check if current commit is on or after the latest tag
    # Returns 0 if tag commit is an ancestor of HEAD (i.e., HEAD is at or after the tag)
    git -C "${1:-$initial_cwd}" merge-base --is-ancestor "$_latest_stable_tag_hash" HEAD &> "$_ignore"
}
