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

declare -xr repo_authority_rex='git@github\.com|https://github\.com'    # OK. it is actually the URI schema + authority, but we only support GitHub URLs for now, so we can hardcode the authority and just call it that. This is the part of the URL before the owner/name, e.g. "git@github.com" or "https://github.com"
declare -xr repo_owner_rex='[a-zA-Z0-9][a-zA-Z0-9-]{0,37}[a-zA-Z0-9]'   # GitHub owner/organization names can be up to 39 characters, must start and end with a letter or digit, and can contain letters, digits, and hyphens. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.
declare -xr repo_name_rex='[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}'             # GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.

declare -xr repo_owner_regex="^$repo_owner_rex$"
declare -xr repo_name_regex="^$repo_name_rex$"
declare -xr repo_regex="^$repo_owner_rex/$repo_name_rex$"

declare -xr github_url_regex="^($repo_authority_rex)[:/]($repo_owner_rex)/($repo_name_rex)$"

# BASH_REMATCH indexes after matching a URL with $github_url_regex:
declare -xri url_authority=1
declare -xri url_owner=2
declare -xri url_name=3

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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository owner to validate."
    }
    [[ $# -ne 1 || -z "$1" || "$1" =~ $repo_owner_regex ]] || {
        # repo owner can be empty (for user-level repos) or must match the regex for GitHub owner/organization names
        rc="$err_argument_value"
        error -ec "$rc" "Invalid repository owner. $valid_repo_owners."
    }

    (( rc == success )) || return "$err_invalid_arguments"

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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository name to validate."
    }
    [[ $# -ne 1 || ( -n "$1" && "$1" != *.git && "$1" =~ $repo_name_regex ) ]] || {
        # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
        rc="$err_argument_value"
        error -ec "$rc" "Invalid repository name. $valid_repo_names."
    }

    (( rc == success )) || return "$err_invalid_arguments"

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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository description to validate."
    }
    [[ $# -ne 1 ]] || (( ${#1} >= 3 && ${#1} <= 350 )) || {
        # GitHub repository descriptions must be between 3 and 350 characters long.
        rc="$err_argument_value"
        error -ec "$rc" "Repository description must be between 3 and 350 characters long."
    }

    (( rc == success )) || return "$err_invalid_arguments"

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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository branch name to validate."
    }
    [[ $# -ne 1 ]] || git check-ref-format --branch "$1" &> "$_ignore" || {
        rc="$err_argument_value"
        error -ec "$rc" "Invalid branch name '$1'. Branch names must be valid git ref names. See https://git-scm.com/docs/git-check-ref-format for details."
    }

    (( rc == success )) || return "$err_invalid_arguments"

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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the secret value to validate."
    }
    [[ $# -ne 1 || -z "$1" || ! "$1" =~ [[:cntrl:]] ]] || {
        rc="$err_argument_value"
        error -ec "$rc" "Invalid secret value. Secrets cannot have control characters or be empty."
    }
    return "$rc"
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
    local -i rc="$success"

    (( $# >= 3 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires at least three arguments (provided $#): <max_attempts> <delay> <gh-command> [args...]"
    }
    is_natural "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires the first argument to be a natural number: <max_attempts>"
    }
    is_natural "$2" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires the second argument to be a natural number: <delay> in seconds"
    }

    (( rc == success )) || return "$err_invalid_arguments"

    # get the first two and the optional third (ignore_output) boolean parameter
    local output

    local max_attempts=$1; shift
    local delay=$1; shift
    local ignore_output=false
    is_boolean "$1" && ignore_output=$1 && shift
    $ignore_output && output="$_ignore" || output="/dev/stdout"

    "$dry_run" && echo "dry-run$ gh $*" >&2 && return "$success"

    # stderr goes to a temp file to preserve output fidelity (especially newlines), yet still allows us to process them separately
    local stderr_file
    local stdout_file
    stderr_file=$(mktemp)
    stdout_file=$(mktemp)

    local attempt=0
    local message=""
    local -i rc=$success
    trace "Executing with retry from (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): 'gh $*'"

    until gh "$@" >"$stdout_file" 2>"$stderr_file"; do
        rc=$?

        cat "$stderr_file" >&2
        message=$(cat "$stderr_file") || true

        # Check if error is transient - retry
        if [[ ! "$message" =~ (rate.limit|server.error|timeout|temporarily.unavailable|try.again|502|503|504|connection.refused|network.error) ]]; then
            error -ec "$rc" "'gh' command unrecoverable error during attempt: $attempt/$max_attempts."
            break # Permanent error (invalid args, not found, permissions, etc.) - don't retry
        fi

        # transient error - retry or give up
        if (( ++attempt < max_attempts )); then
            # retry and reset rc to success to avoid returning a failure code if the last attempt fails with a transient error
            warning "'gh' command failed. Attempt: $attempt/$max_attempts. Retrying in ${delay}s."
            sleep "$delay"
            rc=$success
        else
            # give up and return the last error
            error -ec "$err_logic_error" "After $attempt attempts, the 'gh' command is still failing."
            break
        fi
    done

    (( rc == success )) && cat "$stderr_file" >&2
    cat "$stdout_file" >> "$output"

    rm -f "$stderr_file" "$stdout_file"

    return "$rc"
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
    local -i rc="$success"

    (( $# >= 3 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires at least three arguments (provided $#): <max_attempts> <delay> <command> [args...]"
    }
    is_natural "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires the first argument to be a natural number: <max_attempts>"
    }
    is_natural "$2" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires the second argument to be a natural number: <delay> in seconds"
    }

    (( rc == success )) || return "$err_invalid_arguments"

    # get the first two and the optional third (ignore_output) boolean parameter
    local output

    local max_attempts=$1; shift
    local delay=$1; shift
    local ignore_output=false
    is_boolean "$1" && ignore_output=$1 && shift
    $ignore_output && output="$_ignore" || output="/dev/stdout"

    "$dry_run" && echo "dry-run$ gh $*" >&2 && return "$success"

    # stderr and stdout go to temp files to preserve output fidelity (especially newlines), yet still allow us to process them separately
    local stderr_file
    local stdout_file
    stderr_file=$(mktemp)
    stdout_file=$(mktemp)

    local attempt=0
    local response="" message="" status=""
    local -i rc=0
    trace "Executing with retry @ (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): gh api $*"

    until gh api "$@" >"$stdout_file" 2>"$stderr_file"; do
        rc=$?

        cat "$stderr_file" >&2

        response=$(cat "$stdout_file")            || true
        status=$(jq -r '.status' <<< "$response") || true

        # If no JSON status, check stderr for network/auth errors
        if [[ -z "$status" || "$status" == "null" ]]; then
            message=$(cat "$stderr_file") || true
            # If it's a not a transient error in stderr - break(return), otherwise - retry
            if [[ ! "$message" =~ (authentication|network|timeout|dns|connection) ]]; then
                error -ec "$rc" "'gh api' command unrecoverable error during attempt: $attempt/$max_attempts."
                break
            fi
        else
            # Normal JSON error/HTTP status handling
            case $status in
                425|429|500|502|503|504 )           # transient error HTTP status codes from 'gh api' - retry may fix it
                    ;;

                1*|2*|3* )
                    rc=0                            # 1xx, 2xx, and 3xx HTTP status codes are considered successful
                    break
                    ;;

                * ) break                           # everything else is a bad outcome that will not be fixed by retrying
                    ;;
            esac
        fi

        # transient error - retry or give up
        if (( ++attempt < max_attempts )); then
            # retry and reset rc to success to avoid returning a failure code if the last attempt fails with a transient error
            warning "'gh api' command failed. Attempt $attempt/$max_attempts. Retrying in ${delay}s."
            sleep "$delay"
            rc=$success
        else
            error -ec "$err_logic_error" "After $attempt attempts, the 'gh api' command is still failing."
            break
        fi
    done

    (( rc == success )) && cat "$stderr_file" >&2
    cat "$stdout_file" >> "$output"

    rm -f "$stderr_file" "$stdout_file" 2> "$_ignore"

    return "$rc"
}

#-------------------------------------------------------------------------------
# With the following constants and functions we define the repository state: it is an associative array with predefined keys.
# The following constants define the predefined keys of a repo state:
#-------------------------------------------------------------------------------
declare -xr key_root='root'
declare -xr key_url='url'
declare -xr key_ssh_url='ssh_url'
declare -xr key_authority='authority'
declare -xr key_owner='owner'
declare -xr key_name='name'
declare -xr key_repo='repo'
declare -xr key_repo_id='repo_id'
declare -xr key_default_branch='default_branch'

#-------------------------------------------------------------------------------
# The following list contains the predefined keys of a repo state:
#-------------------------------------------------------------------------------
declare -xar repo_state_keys=(
    "$key_root"
    "$key_url"
    "$key_authority"
    "$key_owner"
    "$key_name"
    "$key_repo"
    "$key_repo_id"
    "$key_default_branch"
)

declare -xr jq_gh_repo_state="{
    $key_url: .html_url,
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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ $# -ne 1 ]] || is_defined_associative_array "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 1 nameref argument: the name of an associative array variable."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local -n state="$1"
    local key
    state=()
    for key in "${repo_state_keys[@]}"; do
        state+=(["$key"]='')
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
    local -i rc="$success"

    (( $# == 2 || $# == 3 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 2 or 3 arguments (provided $#):" \
                              "  - the existing path to the root of the git repo working tree" \
                              "  - nameref: the name of an associative array variable - to receive the repo state" \
                              "  - full_info - if false, only retrieve the local Git repository state without trying to get GitHub API data (optional, default: true)."
    }
    [[ $# -lt 1 || -d "$1" ]] || {
        rc="$err_not_directory"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires argument \$1 to be the existing path to the root of the git repo working tree"
    }
    [[ $# -lt 2 ]] || is_defined_associative_array "$2" || {
        rc="$err_invalid_nameref"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() require \$2 arguments to be a nameref: the name of an associative array variable - to receive the repo state."
    }
    (( $# != 3 )) || is_boolean "$3" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires argument \$3 to be a boolean if provided"
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local full_info=${3:-true}

    local -n state="$2" # associative array variable to receive the repo state, passed by nameref
    initialize_repo_state "$2" # make sure we have all fields

    state[$key_root]=$(git -C "$1" rev-parse --show-toplevel 2>"$_ignore") || return "$success" # no local git repo - return
    local url
    url=$(git -C "$1" remote get-url origin 2>"$_ignore")                  || return "$success" # no origin remote - return

    [[ -n $url && $url =~ $github_url_regex ]]                             || return "$success" # origin remote is not a GitHub URL - return

    local authority="${BASH_REMATCH[$url_authority]}"
    local owner="${BASH_REMATCH[$url_owner]}"
    local name="${BASH_REMATCH[$url_name]}"; name="${name%.git}"
    local repo=$owner/$name

    state[key_url]="$url"
    state[key_authority]="$authority"
    state[key_owner]="$owner"
    state[key_name]="$name"
    state[key_repo]="$repo"

    $full_info                                                             || return "$success" # caller does not want full info - return with what we have from git, without trying to get GitHub API data

    local -A gh_state

    while IFS='=' read -r name value; do
        gh_state["$name"]="$value"
    done < <(execute_gh_api_with_retry 3 2 --paginate "repos/$owner/$name" -q "$jq_gh_repo_state")

    local -i rc=0
    local -i errs
    errs=$(get_errors)

    # these are real logical problems that can occur if the git remote is misconfigured or the API is returning unexpected data,
    # so we check them all and report all mismatches rather than bailing on the first one
    [[ ${gh_state["$key_ssh_url"]} == "${state[$key_url]}" ||
       ${gh_state["$key_url"]}     == "${state[$key_url]}"   ]] || error -sd 3 -ec "$err_logic_error" "GitHub API returned URLs '${gh_state["$key_ssh_url"]}' and '${gh_state["$key_url"]}' that do not match the git remote URL '${state[$key_url]}'."
    [[ ${gh_state["$key_owner"]}   == "${state[$key_owner]}" ]] || error -sd 3 -ec "$err_logic_error" "GitHub API returned owner '${gh_state["$key_owner"]}' that does not match the git remote owner '${state[$key_owner]}'."
    [[ ${gh_state["$key_name"]}    == "${state[$key_name]}"  ]] || error -sd 3 -ec "$err_logic_error" "GitHub API returned name '${gh_state["$key_name"]}' that does not match the git remote name '${state[$key_name]}'."
    [[ ${gh_state["$key_repo"]}    == "${state[$key_repo]}"  ]] || error -sd 3 -ec "$err_logic_error" "GitHub API returned repo '${gh_state["$key_repo"]}' that does not match the expected repo '${state[$key_repo]}'."
    [[ -n ${gh_state["$key_repo_id"]}                        ]] || error -sd 3 -ec "$err_logic_error" "GitHub API did not return a repo ID for '${gh_state["$key_repo"]}'."

    rc=$(( errs < $(get_errors) ? failure : success ))

    state[key_repo_id]="${gh_state["$key_repo_id"]}"
    state[key_default_branch]="${gh_state["$key_default_branch"]}"

    return "$rc"
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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ $# -ne 1 ]] || is_defined_associative_array "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local -n state="$1"
    [[ -v state["$key_root"] && -n ${state["$key_root"]} && -d ${state["$key_root"]} ]]
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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ $# -ne 1 ]] || is_defined_associative_array "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local -n state="$1"
    [[ -v state["$key_url"] && -n ${state["$key_url"]} ]]
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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ $# -ne 1 ]] || is_defined_associative_array "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local -n state="$1"
    [[ -v state["$key_repo_id"] && -n ${state["$key_repo_id"]} ]]
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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ $# -ne 1 ]] || is_defined_associative_array "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    $verbose || return "$success"

    local -n __state="$1"
    local key

    {
        echo "Repository state '$1':"
        for key in "${repo_state_keys[@]}"; do
            [[ -v __state[$key] ]] && printf "  %-15s → '%s'\n" "$key" "${__state[$key]}" || printf "  %-15s ✗ not set\n" "$key"
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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ $# -ne 1 ]] || is_defined_associative_array "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    initialize_repo_state "$1"

    local -n state="$1"
    local key value
    while IFS='=' read -r key value; do
        is_in "$key" "${repo_state_keys[@]}" &&
            trace "read_repo_state: '$key'='$value'" ||
            trace "⚠️  WARNING: Unexpected key '$key' in the repo state input."
        state["$key"]="$value"
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
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
    }
    [[ $# -ne 1 ]] || is_defined_associative_array "$1" || {
        rc="$err_argument_type"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local -n state="$1"
    local key
    echo "Repository state:"
    for key in "${repo_state_keys[@]}"; do
        [[ -v state["$key"] ]] && echo "  $key: ${state[$key]}" || echo "  $key: "
    done
}

#-------------------------------------------------------------------------------
# @description Tests if the current or the specified directory is inside a Git working tree.
#
# @arg $1 string Path to the directory to test (optional, default: `$initial_dir`).
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
    local -i rc="$success"

    (( $# == 0 || $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires 0 or 1 argument (provided $#): path to a directory."
    }
    (( $# == 0 )) || [[ -d $1 ]] || {
        rc="$err_not_directory"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() the parameter \$1 must be a path to a directory."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    git -C "${1:-$initial_dir}" rev-parse --is-inside-work-tree &> "$_ignore"
}

#-------------------------------------------------------------------------------
# @description Retrieves the root of the Git repository working tree for the specified directory,
#   or the current directory.
#
# @arg $1 string Path to a directory inside a Git repository working tree (optional, default:
#   `$initial_dir`).
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
    local -i rc="$success"

    is_inside_work_tree "${1:-$initial_dir}" || {
        rc="$err_not_git_directory"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() the parameter \$1 or the current directory must be a path to a directory inside a Git repository working tree."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    git -C "${1:-$initial_dir}" rev-parse --show-toplevel 2> "$_ignore"
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
#   default: `$initial_dir`).
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
    local -i rc="$success"

    (( $# <= 2 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires no more than 2 arguments (provided $#):" \
                              "  - path to an existing directory (Git repository) (optional if the remaining parameters are not provided, default: current working directory)" \
                              "  - the branch name to compare against (optional, default: main)."
    }
    (( $# < 1 )) || [[ -d "$1" ]] || {
        rc="$err_not_directory"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() the parameter \$1 must be a path to an existing directory."
    }
    (( $# < 2 )) || validate_branch_name "$2" || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() the parameter \$2 must be a valid branch name."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local dir=${1:-$initial_dir}
    local branch=${2:-main}

    is_inside_work_tree "$dir" || {
        error -sd 3 -ec "$err_not_git_directory" "${FUNCNAME[0]}() the parameter \$1 or the current directory must be inside a Git work tree."
        return "$err_not_git_directory"
    }

    # Shallow repositories can miss history or tags needed by release predicates - yes we need a fetch
    [[ $(git -C "$dir" rev-parse --is-shallow-repository 2>"$_ignore") != true ]]            || return "$positive"

    local local_sha remote_sha

    # no locally-cached SHA - no fetch needed
    local_sha=$(git -C "$dir" rev-parse --verify "refs/remotes/origin/$branch" 2>"$_ignore") || return "$negative"
    # no remote SHA for the branch - no fetch needed
    remote_sha=$(git -C "$dir" ls-remote --heads origin "$branch" 2>"$_ignore" | awk 'NR==1 {print $1}')
    [[ -n "$remote_sha" ]]                                                                   || return "$negative"
    # SHAs are equal - no fetch needed
    [[ "$local_sha" != "$remote_sha" ]]                                                      || return "$negative"

    local local_stable_tag remote_stable_tag

    # Get latest stable tag
    local_stable_tag=$(git -C "$dir" tag | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    # no local stable tags - fetch needed
    [[ -n "$local_stable_tag" ]]                                                             || return "$positive"
    # Get latest stable tag from remote
    remote_stable_tag=$(git -C "$dir" ls-remote --tags --refs origin 2>"$_ignore" | awk '{print $2}' | sed 's#refs/tags/##' | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    # no local stable tags - fetch needed
    [[ -n "$remote_stable_tag" ]]                                                            || return "$positive"
    # stable tags are not the same - fetch needed
    [[ "$local_stable_tag" == "$remote_stable_tag" ]]                                        && return "$negative"

    # fetch needed
    return "$positive"
}

#-------------------------------------------------------------------------------
# @description Ensures that the Git repository in the specified directory has fresh metadata, by
#   fetching from the remote if `should_fetch_for_latest_stable_tag` recommends it.
#
# @arg $1 string Path to a Git repository (optional, if the remaining parameters are not provided;
#   default: `$initial_dir`).
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
    local -i rc=$positive

    should_fetch_for_latest_stable_tag "$@" || rc=$?

    case $rc in
        "$positive" )
            trace "Git metadata appears stale or repository is shallow. Fetching from origin..."
            rc=$success
            git -C "$1" fetch origin "${2:-main}" --quiet 2> "$_ignore" || {
                rc=$?
                error -ec "$err_logic_error" "Failed to fetch from origin: $rc"
            }
            ;;
        "$negative" )
            trace "Git metadata appears fresh. No fetch needed."
            rc="$success"
            ;;
        * )
            trace "Error while checking if Git metadata is fresh: $rc"
            ;;
    esac

    return "$rc"
}

#-------------------------------------------------------------------------------
# @description Gets the commit hash of the latest stable tag in the specified Git repository.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_dir`).
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
    local -i rc="$success"

    (( $# <= 2 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() takes 0, 1 or 2 arguments (provided $#)" \
                              "  \$1 - a directory. Optional, default: the current working directory." \
                              "  \$2 - boolean to fetch the latest changes in main from remote (default true)."
    }
    (( $# < 1 )) || [[ -d "$1" ]] || {
        rc="$err_not_directory"
        error -sd 3 -ec "$rc" "The specified directory '$1' does not exist."
    }
    is_inside_work_tree "${1:-$initial_dir}" || {
        rc="$err_not_git_directory"
        error -sd 3 -ec "$rc" "The specified directory '$1' is not a Git work tree."
    }
    (( $# < 2 )) || is_boolean "$2" || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "The second argument to ${FUNCNAME[0]}() must be a boolean if provided."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local dir=${1:-$initial_dir}
    local should_fetch=${2:-true}

    if $should_fetch; then
        ensure_fresh_git_state "$dir" || {
            rc=$?
            error -ec "$rc" "Failed to ensure fresh Git state for '$dir': $rc"
            return "$rc"
        }
    fi

    local latest_stable_tag latest_stable_hash

    # Get latest stable tag (excludes pre-release tags with -)
    latest_stable_tag=$(git -C "$dir" tag | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    [[ -n $latest_stable_tag ]] ||
        return "$failure" # no stable tags? - return 1

    # get the hash of the commit of the latest stable tag
    git -C "$dir" rev-parse "$latest_stable_tag^{commit}" 2>"$_ignore"
}

#-------------------------------------------------------------------------------
# @description Tests if the current commit in the specified directory is after the latest stable
#   tag. Depends on `get_latest_stable_tag_hash`.
#
# Notes:
#   - This function does not validate its own argument count directly; it relies entirely on
#     `get_latest_stable_tag_hash` to reject bad arguments.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_dir`).
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
    local latest_stable_hash commits_after_latest_stable
    local -i rc

    # get commit of the latest stable tag
    latest_stable_hash=$(get_latest_stable_tag_hash "$@") || return $?

    # How many commits since the latest stable tag
    commits_after_latest_stable=$(git -C "${1:-$initial_dir}" rev-list "$latest_stable_hash..HEAD" --count 2>"$_ignore")
    (( commits_after_latest_stable > 0 ))
}

#-------------------------------------------------------------------------------
# @description Tests if the current commit in the specified directory is on or after the latest
#   stable tag. Depends on `get_latest_stable_tag_hash`.
#
# Notes:
#   - Like `is_after_latest_stable_tag`, this function does not validate its own argument count
#     directly; it relies entirely on `get_latest_stable_tag_hash` to reject bad arguments.
#
# @arg $1 string Path to a Git repository (optional, default: `$initial_dir`).
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
    local latest_stable_tag_hash

    # get commit of the latest stable tag
    latest_stable_tag_hash=$(get_latest_stable_tag_hash "$@") || return $?

    # Check if current commit is on or after the latest tag
    # Returns 0 if tag commit is an ancestor of HEAD (i.e., HEAD is at or after the tag)
    git -C "${1:-$initial_dir}" merge-base --is-ancestor "$latest_stable_tag_hash" HEAD &> "$_ignore"
}
