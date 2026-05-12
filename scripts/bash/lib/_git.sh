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

declare -xr repo_owner_regex="^${repo_owner_rex}$"
declare -xr repo_name_regex="^${repo_name_rex}$"
declare -xr repo_regex="^${repo_owner_rex}/${repo_name_rex}$"

declare -xr github_url_regex="^(${repo_authority_rex})[:/](${repo_owner_rex})/(${repo_name_rex})$"

# BASH_REMATCH indexes after matching a URL with $github_url_regex:
declare -xri url_authority=1
declare -xri url_owner=2
declare -xri url_name=3

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository owner is valid according to
#   GitHub naming rules, i.e. it matches the regular expression for GitHub
#   owner/organization names.
# Parameters:
#   1 - repository owner to validate
# Returns:
#   Exit code: 0 if the repository owner is valid, 1 if it is invalid
# Examples:
#   if validate_gh_repo_owner "my-org"; then echo "Valid repo owner"; fi
# See also: https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details on GitHub repository owner naming rules.
#-------------------------------------------------------------------------------
function validate_gh_repo_owner()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository owner to validate."
        return "$err_invalid_arguments"
    }

    [[ -z "$1" || "$1" =~ $repo_owner_regex ]] || {
        # repo owner can be empty (for user-level repos) or must match the regex for GitHub owner/organization names
        error "Invalid repository owner. $valid_repo_owners."
        return "$err_argument_value"
    }

    return "$success"
}

valid_repo_names="GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit.
See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details."

readonly valid_repo_names

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository name is valid according to
#   GitHub naming rules, i.e. it matches the regular expression for GitHub
#   repository names and does not end with ".git".
# Parameters:
#   1 - repository name to validate
# Returns:
#   Exit code: 0 if the repository name is valid, 1 if it is invalid
# Examples:
#   if validate_gh_repo_name "my-repo"; then echo "Valid repo name"; fi
#   repo_name=$(enter_value "GitHub Repository name" "$default_repo_name" false validate_gh_repo_name)
# See also: https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details on GitHub repository naming rules.
#-------------------------------------------------------------------------------
function validate_gh_repo_name()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository name to validate."
        return "$err_invalid_arguments"
    }

    [[ -n "$1" && "$1" != *.git && "$1" =~ $repo_name_regex ]] || {
        # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
        error "Invalid repository name. $valid_repo_names."
        return "$err_argument_value"
    }

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository description is valid according to
#   GitHub naming rules, i.e. it is between 3 and 350 characters long.
# Parameters:
#   1 - repository description to validate
# Returns:
#   Exit code: 0 if the repository description is valid, 1 if it is invalid
# Examples:
#   if validate_gh_repo_description "This is my repo"; then echo "Valid repo description"; fi
#   repo_description=$(enter_value "GitHub Repository description" "$default_repo_description" false validate_gh_repo_description)
# See also: https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details on GitHub repository description rules.
#--------------------------------------------------------------------------------
function validate_gh_repo_description()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository description to validate."
        return "$err_invalid_arguments"
    }

    (( ${#1} >= 3 && ${#1} <= 350 )) || {
        # GitHub repository descriptions must be between 3 and 350 characters long.
        error "Repository description must be between 3 and 350 characters long."
        return "$err_argument_value"
    }

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository branch name is valid according to
#   git branch naming rules, i.e. it is a valid git ref name.
# Parameters:
#   1 - repository branch name to validate
# Returns:
#   Exit code: 0 if the repository branch name is valid, 1 if it is invalid
# Examples:
#   if validate_branch_name "main"; then echo "Valid branch name"; fi
#   branch_name=$(enter_value "Default branch name" "$default_branch" false validate_branch_name)
# See also: https://git-scm.com/docs/git-check-ref-format for details on valid git ref names
#--------------------------------------------------------------------------------
function validate_branch_name()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository branch name to validate."
        return "$err_invalid_arguments"
    }

    git check-ref-format --branch "$1" &> "$_ignore" || {
        error "Invalid branch name '$1'. Branch names must be valid git ref names. See https://git-scm.com/docs/git-check-ref-format for details."
        return "$err_argument_value"
    }

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Validates that the specified secret value is valid according to
#   GitHub secret rules, i.e. it is base64 encoded.
# Parameters:
#   1 - secret value to validate
# Returns:
#   Exit code: 0 if the secret value is valid, 1 if it is invalid
# Examples:
#   if validate_gh_secret "c2VjcmV0VmFsdWU="; then echo "Valid secret"; fi
# See also: https://docs.github.com/en/actions/security-guides/encrypted-secrets for details on GitHub secrets
#-------------------------------------------------------------------------------
function validate_gh_secret()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly one argument (provided $#): the secret value to validate."
        return "$err_invalid_arguments"
    }
    [[ -z "$1" || ! "$1" =~ [[:cntrl:]] ]] || {
        error "Invalid secret value. Secrets cannot have control characters or be empty."
        return "$err_argument_value"
    }

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Executes a GitHub CLI command with retry logic for transient failures.
# Parameters:
#   1 - max_attempts: Maximum number of attempts
#   2 - delay: Delay between attempts in seconds
#   3, if boolean - ignore_output: indicates whether to suppress output (true) or not (false)
#   3 or 4... - gh command parameters: subcommand, flags, etc...
# Returns:
#   Exit code: 0 if the command succeeds, non-zero if it fails after all attempts
# Examples:
#   execute_gh_with_retry 3 5 repo create my-repo --public
#   execute_gh_with_retry 3 2 true repo delete owner/repo --yes
#-------------------------------------------------------------------------------
function execute_gh_with_retry()
{
    (( $# >= 3 )) || {
        error 3 "${FUNCNAME[0]}() requires at least three arguments (provided $#): <max_attempts> <delay> <gh-command> [args...]"
        return "$err_invalid_arguments"
    }
    is_natural "$1" || {
        error 3 "${FUNCNAME[0]}() requires the first argument to be a natural number: <max_attempts>"
        return "$err_argument_type"
    }
    is_natural "$2" || {
        error 3 "${FUNCNAME[0]}() requires the second argument to be a natural number: <delay> in seconds"
        return "$err_argument_type"
    }

    # get the first two and the optional third (ignore_output) boolean parameter
    local output="/dev/stdout"
    local max_attempts=$1; shift
    local delay=$1; shift
    local ignore_output=false
    is_boolean "$1" && ignore_output=$1 && shift    # otherwise ignore_output remains false
    $ignore_output && output="$_ignore"             # otherwise output remains /dev/stdout

    "$dry_run" && echo "dry-run$ gh $*" >&2 && return "$success"

    # stderr goes to a temp file to preserve output fidelity (especially newlines), yet still allow us to process them separately
    local stderr_file
    local stdout_file
    stderr_file=$(mktemp)
    stdout_file=$(mktemp)

    local attempt=0
    local message=""
    local -i rc=0
    trace "Executing with retry from (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): 'gh $*'"

    until gh "$@" >"$output" 2>"$stderr_file"; do
        rc=$?

        message=$(cat "$stderr_file") || true

        # Check if error is transient - retry
        if [[ ! "$message" =~ (rate.limit|server.error|timeout|temporarily.unavailable|try.again|502|503|504|connection.refused|network.error) ]]; then
            # Permanent error (invalid args, not found, permissions, etc.) - don't retry
           break
        fi

        # Retry or give up
        if (( ++attempt >= max_attempts )); then
            error "After $attempt attempts, the 'gh' command is still failing."
            break
        fi

        warning "'gh' command failed. Attempt $attempt/$max_attempts. Retrying in ${delay}s."
        cat "$stderr_file" >&2
        sleep "$delay"
    done

    cat "$stderr_file" >&2
    cat "$stdout_file" >> "$output"

    rm -f "$stderr_file" "$stdout_file"

    return "$rc"
}

#-------------------------------------------------------------------------------
# Summary: Executes a GitHub API command with retry logic.
# Parameters:
#   1 - max_attempts: Maximum number of attempts
#   2 - delay: Delay between attempts in seconds
#   3, if boolean - ignore_output: indicates whether to suppress output (true) or not (false)
#   3 or 4... - gh api parameters: route, etc...
# Returns:
#   Exit code: 0 if the command succeeds, non-zero if it fails after all attempts
# Examples:
#   execute_gh_api_with_retry 3 5 gh api repos/vmelamed/my-repo
#-------------------------------------------------------------------------------

function execute_gh_api_with_retry()
{
    (( $# >= 3 )) || {
        error 3 "${FUNCNAME[0]}() requires at least three arguments (provided $#): <max_attempts> <delay> <command> [args...]"
        return "$err_invalid_arguments"
    }
    is_natural "$1" || {
        error 3 "${FUNCNAME[0]}() requires the first argument to be a natural number: <max_attempts>"
        return "$err_invalid_arguments"
    }
    is_natural "$2" || {
        error 3 "${FUNCNAME[0]}() requires the second argument to be a natural number: <delay> in seconds"
        return "$err_invalid_arguments"
    }

    # get the first two and the optional third (ignore_output) boolean parameter
    local output="/dev/stdout"
    local max_attempts=$1; shift
    local delay=$1; shift
    local ignore_output=false
    is_boolean "$1" && ignore_output=$1 && shift    # otherwise ignore_output remains false
    $ignore_output && output="$_ignore"             # otherwise output remains /dev/stdout

    "$dry_run" && echo "dry-run$ gh $*" >&2 && return "$success"

    # stderr and stdout go to temp files to preserve output fidelity (especially newlines), yet still allow us to process them separately
    local stderr_file stdout_file
    stderr_file=$(mktemp)
    stdout_file=$(mktemp)

    local attempt=0
    local response="" message="" status=""
    local -i rc=0
    trace "Executing with retry @ (${BASH_SOURCE[1]:-} ${BASH_LINENO[0]:-}): gh api $*"

    until gh api "$@" >"$stdout_file" 2>"$stderr_file"; do
        rc=$?

        response=$(cat "$stdout_file")            || true
        status=$(jq -r '.status' <<< "$response") || true

        # If no JSON status, check stderr for network/auth errors
        if [[ -z "$status" || "$status" == "null" ]]; then
            message=$(cat "$stderr_file") || true
            # If it's a not a transient error in stderr - break(return), otherwise - retry
            if [[ ! "$message" =~ (authentication|network|timeout|dns|connection) ]]; then
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

                * ) rc=1                            # everything else is a bad outcome that will not be fixed by retrying
                    break
                    ;;
            esac
        fi

        # transient error - retry
        if (( ++attempt >= max_attempts )); then
            error "After $attempt attempts, the 'gh api' command is still failing."
            break
        fi
        warning "'gh api' command failed. Attempt $attempt/$max_attempts. Retrying in ${delay}s."
        cat "$stderr_file" >&2
        sleep "$delay"
    done

    cat "$stderr_file" >&2
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
# Summary: initializes a repo state to an initial state where it contains all predefined keys with values - empty strings
# Parameters:
#   1 - nameref: the name of an associative array variable to be initialized as repo state.
#-------------------------------------------------------------------------------
function initialize_repo_state()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
        return "$err_invalid_arguments"
    }
    is_defined_associative_array "$1" || {
        error 3 "${FUNCNAME[0]}() requires 1 nameref argument: the name of an associative array variable."
        return "$err_argument_type"
    }

    local -n state="$1"
    local key
    state=()
    for key in "${repo_state_keys[@]}"; do
        state+=(["$key"]='')
    done

    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Retrieves the Git repository state for a specified directory by finding the Git repository root and parsing the
#   origin remote URL if it exists and is a GitHub URL.
# Parameters:
#   1 - dir - path to a directory inside a Git repository work tree
#   2 - nameref: the name of an associative array variable - to receive the repo state
#   3 - full_info - if false, only retrieve the local Git repository state without trying to get GitHub API data (optional, default: true)
# Returns:
#   Exit code: 0 on success,
#              1 if the directory is not inside a Git repository work tree
#              2 if the directory if the GitHub API returns inconsistent data for the repository.
# Dependencies: git, gh
# Usage: git_repo_state <directory>
# Example: git_repo_state "/home/valo/repos/vm2.Glob"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2004 # $/${} is unnecessary on arithmetic variables - state is assoc.array
function get_repo_state()
{
    (( $# == 2 || $# == 3 )) || {
        error 3 "${FUNCNAME[0]}() requires 2 or 3 arguments (provided $#):
1) the existing path to the root of the git repo working tree
2) nameref: the name of an associative array variable - to receive the repo state
3) full_info (optional, default: true) - if false, only retrieve the local Git repository state without trying to get GitHub API data."
        return "$err_invalid_arguments"
    }
    [[ -d "$1" ]] || {
        error 3 "${FUNCNAME[0]}() requires argument \$1 to be the existing path to the root of the git repo working tree"
        return "$err_not_directory"
    }
    is_defined_associative_array "$2" || {
        error 3 "${FUNCNAME[0]}() require \$2 arguments to be a nameref: the name of an associative array variable - to receive the repo state."
        return "$err_argument_type"
    }
    (( $# == 2 )) || is_boolean "$3" || {
        error 3 "${FUNCNAME[0]}() requires argument \$3 to be a boolean if provided"
        return "$err_argument_type"
    }

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
    local repo=${owner}/${name}

    state[$key_url]="$url"
    state[$key_authority]="${authority}"
    state[$key_owner]="${owner}"
    state[$key_name]="${name}"
    state[$key_repo]="${repo}"

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
    [[ ${gh_state["$key_ssh_url"]} == "${state[$key_url]}"      ||
       ${gh_state["$key_url"]}     == "${state[$key_url]}" ]]   || error "GitHub API returned URLs '${gh_state["$key_ssh_url"]}' and '${gh_state["$key_url"]}' that do not match the git remote URL '${state[$key_url]}'."
    [[ ${gh_state["$key_owner"]}   == "${state[$key_owner]}" ]] || error "GitHub API returned owner '${gh_state["$key_owner"]}' that does not match the git remote owner '${state[$key_owner]}'."
    [[ ${gh_state["$key_name"]}    == "${state[$key_name]}" ]]  || error "GitHub API returned name '${gh_state["$key_name"]}' that does not match the git remote name '${state[$key_name]}'."
    [[ ${gh_state["$key_repo"]}    == "${state[$key_repo]}" ]]  || error "GitHub API returned repo '${gh_state["$key_repo"]}' that does not match the expected repo '${state[$key_repo]}'."
    [[ -n ${gh_state["$key_repo_id"]} ]]                        || error "GitHub API did not return a repo ID for '${gh_state["$key_repo"]}'."

    rc=$(( errs < $(get_errors) ? failure : success ))

    state[$key_repo_id]="${gh_state["$key_repo_id"]}"
    state[$key_default_branch]="${gh_state["$key_default_branch"]}"

    return "$rc"
}

#-------------------------------------------------------------------------------
# Summary: Tests if the specified repo state has a local Git repository, i.e. if the "root" key is set to a non-empty value.
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state.
#-------------------------------------------------------------------------------
function has_local_repo()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
        return "$err_invalid_arguments"
    }
    is_defined_associative_array "$1" || {
        error 3 "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
        return "$err_argument_type"
    }

    local -n state="$1"
    [[ -v state["$key_root"] && -n ${state["$key_root"]} && -d ${state["$key_root"]} ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the specified repo state has a remote Git repository, i.e. if the "url" key is set to a non-empty value.
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state.
#-------------------------------------------------------------------------------
function has_remote_repo()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
        return "$err_invalid_arguments"
    }
    is_defined_associative_array "$1" || {
        error 3 "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
        return "$err_argument_type"
    }

    local -n state="$1"
    [[ -v state["$key_url"] && -n ${state["$key_url"]} ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the specified repo state has a remote GitHub repository, i.e. if the "repo_id" key is set to a non-empty value.
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state.
#-------------------------------------------------------------------------------
function has_github_remote()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
        return "$err_invalid_arguments"
    }
    is_defined_associative_array "$1" || {
        error 3 "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
        return "$err_argument_type"
    }

    local -n state="$1"
    [[ -v state["$key_repo_id"] && -n ${state["$key_repo_id"]} ]]
}


#-------------------------------------------------------------------------------
# Summary: Writes (serializes) a repo state to stdout. If a repo state key is missing, it is written as the missing key with
#   empty string value. Unknown keys are not written.
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state to be serialized.
#-------------------------------------------------------------------------------
function dump_repo_state()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
        return "$err_invalid_arguments"
    }
    is_defined_associative_array "$1" || {
        error 3 "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
        return "$err_argument_type"
    }

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
# Summary: Reads (deserializes) a repo state from stdin. If a repo state key is missing in stdin, it is still added but with
#   empty string value. Unknown keys are written as they are (but you may get a trace warning).
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state to be serialized.
#-------------------------------------------------------------------------------
function read_repo_state()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
        return "$err_invalid_arguments"
    }
    is_defined_associative_array "$1" || {
        error 3 "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
        return "$err_argument_type"
    }

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
# Summary: Prints the repository state to stdout.
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state to be printed.
#-------------------------------------------------------------------------------
function print_repo_state()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable."
        return "$err_invalid_arguments"
    }
    is_defined_associative_array "$1" || {
        error 3 "${FUNCNAME[0]}() requires 1 nameref argument - the name of an associative array variable."
        return "$err_argument_type"
    }

    local -n state="$1"
    local key
    echo "Repository state:"
    for key in "${repo_state_keys[@]}"; do
        [[ -v state["$key"] ]] && echo "  $key: ${state[$key]}" || echo "  $key: "
    done
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current or the specified directory is inside a git working tree.
# Parameters:
#   1 - directory - path to directory to test
# Returns:
#   Exit code: 0 if directory is inside a Git working tree, non-zero otherwise, 2 on invalid arguments
# Dependencies: git
# Usage: if is_inside_work_tree <directory>; then ... fi
# Example: if is_inside_work_tree "$PWD"; then echo "Inside Git repo"; fi
#-------------------------------------------------------------------------------
function is_inside_work_tree()
{
    (( $# == 0 || $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires 0 or 1 argument (provided $#): path to a directory."
        return "$err_invalid_arguments"
    }
    (( $# == 0 )) || [[ -d $1 ]] || {
        error 3 "${FUNCNAME[0]}() the parameter \$1 must be a path to a directory."
        return "$err_not_directory"
    }

    git -C "${1:-.}" rev-parse --is-inside-work-tree &> "$_ignore"
}

#-------------------------------------------------------------------------------
# Summary: Retrieves the root of the Git repository working tree for the specified
#          directory or the current directory.
# Parameters:
#   1 - directory - optional path to a directory inside a Git repository working tree
# Returns:
#   stdout: absolute path to the root of the Git repository working tree
#   Exit code: 0 on success, non-zero on failure
# Dependencies: git
# Usage: root_working_tree <directory>
# Example: root_working_tree "$PWD"
#-------------------------------------------------------------------------------
function root_working_tree()
{
    is_inside_work_tree "${1:-.}" || {
        error 3 "${FUNCNAME[0]}() the parameter \$1 or the current directory must be a path to a directory inside a Git repository working tree."
        return "$err_not_git_directory"
    }

    git -C "${1:-.}" rev-parse --show-toplevel 2> "$_ignore"
}

#-------------------------------------------------------------------------------
# Summary: Tests whether local Git metadata is stale enough to justify fetching
#   before evaluating latest-stable-tag predicates.
# Parameters:
#   1 - directory - optional path to Git repository (default: current directory)
#   2 - branch - optional, the branch to compare against (default: main)
# Returns:
#   Exit code:
#     0 - if fetch is recommended
#     1 - if local metadata appears fresh
#     anything else - if an error occurs (e.g. not a git repository, invalid branch, etc.)
# Dependencies: git
# Usage: if should_fetch_for_latest_stable_tag <directory>; then git fetch ...; fi
# Example: should_fetch_for_latest_stable_tag "$repo_dir" && git -C "$repo_dir" fetch origin --tags --quiet
# Notes:
#   - Conservative by design: uncertain states return 0 (fetch recommended).
#   - Compares local vs remote main tip and latest stable release tag name.
#-------------------------------------------------------------------------------
function should_fetch_for_latest_stable_tag()
{
    (( $# <= 2 )) || {
        error 3 "${FUNCNAME[0]}() requires no more than 2 arguments (provided $#): path to a Git repository and an optional branch name."
        return "$err_invalid_arguments"
    }
    (( $# >= 1 )) && [[ -d "$1" ]] || {
        error 3 "${FUNCNAME[0]}() the parameter \$1 must be a path to an existing directory."
        return "$err_not_directory"
    }
    (( $# >= 2 )) && validate_branch_name "$2" || {
        error 3 "${FUNCNAME[0]}() the parameter \$2 must be a valid branch name."
        return "$err_invalid_arguments"
    }

    local dir=${1:-.}
    local branch=${2:-main}

    is_inside_work_tree "$dir" || {
        error 3 "${FUNCNAME[0]}() the parameter \$1 or the current directory must be inside a Git work tree."
        return "$err_not_git_directory"
    }

    # Shallow repositories can miss history or tags needed by release predicates.
    [[ $(git -C "$dir" rev-parse --is-shallow-repository 2>"$_ignore") != true ]] || return "$positive"

    local local_sha remote_sha

    local_sha=$(git -C "$dir" rev-parse --verify refs/remotes/origin/"$branch" 2>"$_ignore") || return "$positive"
    remote_sha=$(git -C "$dir" ls-remote --heads origin "$branch" 2>"$_ignore" | awk 'NR==1 {print $1}')

    [[ -z "$remote_sha" ]] && return "$positive"
    [[ "$local_sha" != "$remote_sha" ]] && return "$positive"

    local local_stable_tag remote_stable_tag

    local_stable_tag=$(git -C "$dir" tag | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    [[ -n "$local_stable_tag" ]] || return "$positive"

    remote_stable_tag=$(git -C "$dir" ls-remote --tags --refs origin 2>"$_ignore" | awk '{print $2}' | sed 's#refs/tags/##' | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    [[ -n "$remote_stable_tag" ]] || return "$positive"

    [[ "$local_stable_tag" == "$remote_stable_tag" ]] || return "$positive"

    return "$negative"
}

#-------------------------------------------------------------------------------
# Summary: Ensures that the Git repository in the specified directory has fresh metadata by fetching from the remote if needed.
# Parameters:
#   1 - directory - optional path to Git repository (default: current directory)
#   2 - branch - optional, the branch to compare against (default: main)
# Returns:
#   None
# Dependencies: git
# Usage: ensure_fresh_git_state <directory>
#-------------------------------------------------------------------------------
function ensure_fresh_git_state()
{
    local -i rc

    should_fetch_for_latest_stable_tag "$@"; rc=$?

    case $rc in
        "$positive" )
            trace "Git metadata appears stale or repository is shallow. Fetching from remote is recommended."
            git -C "$1" fetch origin "${2:-main}" --quiet 2> "$_ignore" || {
                rc=$?
                error "Failed to fetch from remote repository: $rc"
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
# Summary: Gets the commit hash of the latest stable tag in the specified Git repository.
# Parameters:
#   1 - directory - path to Git repository
# Returns:
#   The commit hash of the latest stable tag, or 1 if no stable tags are found
# Dependencies: git
# Usage: latest_hash=$(get_latest_stable_tag_hash <directory> [should_fetch])
# Example: latest_hash=$(get_latest_stable_tag_hash "$repo_dir")
#-------------------------------------------------------------------------------
function get_latest_stable_tag_hash()
{
    (( $# <= 2 )) || {
        error 3 "${FUNCNAME[0]}() takes 0, 1 or 2 arguments (provided $#): \$1 - a directory. Optional \$2 - boolean to fetch the latest changes in main from remote (default true)."
        return "$err_invalid_arguments"
    }
    (( $# < 1 )) || [[ -d "$1" ]] || {
        error 3 "The specified directory '$1' does not exist."
        return "$err_not_directory"
    }
    is_inside_work_tree "${1:-.}" || {
        error 3 "The specified directory '$1' is not a Git work tree."
        return "$err_not_git_directory"
    }

    local dir=${1:-.}

    local latest_stable_tag latest_stable_hash

    # Get latest stable tag (excludes pre-release tags with -)
    latest_stable_tag=$(git -C "$dir" tag | grep -E "$semverTagReleaseRegex" | sort -V | tail -n1)
    [[ -n $latest_stable_tag ]] || return 1 # no stable tags? - return 1

    # get the hash of the commit of the latest stable tag
    git -C "$dir" rev-parse "$latest_stable_tag^{commit}" 2>"$_ignore"
    return "$success"
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is on the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
#   2 - optional, should_fetch - if true, fetch the latest changes from remote (optional, default: false)
# Returns:
#   Exit code: 0 if on latest stable tag, 1 if not, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_on_latest_stable_tag <directory> [should_fetch]; then ... fi
# Example: if is_on_latest_stable_tag "$repo_dir"; then echo "On latest stable"; fi
#-------------------------------------------------------------------------------
function is_on_latest_stable_tag()
{
    local latest_stable_hash commits_after_latest_stable
    local -i rc

    # get commit of the latest stable tag
    latest_stable_hash=$(get_latest_stable_tag_hash "$@")
    rc=$?
    (( rc == 0 )) || return "$rc"

    # How many commits since the latest stable tag
    commits_after_latest_stable=$(git -C "${1:-.}" rev-list "$latest_stable_hash..HEAD" --count 2>"$_ignore")
    (( commits_after_latest_stable == 0 ))
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is after the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
#   2 - optional, should_fetch - if true, fetch the latest changes from remote (optional, default: false)
# Returns:
#   Exit code: 0 if after latest stable tag, 1 if not, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_after_latest_stable_tag <directory> [should_fetch]; then ... fi
# Example: if is_after_latest_stable_tag "$repo_dir"; then echo "Beyond latest stable"; fi
#-------------------------------------------------------------------------------
function is_after_latest_stable_tag()
{
    local latest_stable_hash commits_after_latest_stable
    local -i rc

    # get commit of the latest stable tag
    latest_stable_hash=$(get_latest_stable_tag_hash "$@")
    rc=$?
    (( rc == 0 )) || return "$rc"

    # How many commits since the latest stable tag
    commits_after_latest_stable=$(git -C "${1:-.}" rev-list "$latest_stable_hash..HEAD" --count 2>"$_ignore")
    (( commits_after_latest_stable > 0 ))
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is on or after the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
# Returns:
#   Exit code: 0 if on or after latest stable tag, 1 if before, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_on_or_after_latest_stable_tag <directory> [should_fetch]; then ... fi
# Example: if is_on_or_after_latest_stable_tag "$repo_dir"; then echo "Ready for release"; fi
#-------------------------------------------------------------------------------
function is_on_or_after_latest_stable_tag()
{
    local latest_stable_hash commits_after_latest_stable
    local -i rc

    # get commit of the latest stable tag
    latest_stable_hash=$(get_latest_stable_tag_hash "$@")
    rc=$?
    (( rc == 0 )) || return "$rc"

    # Check if current commit is on or after the latest tag
    # Returns 0 if tag commit is an ancestor of HEAD (i.e., HEAD is at or after the tag)
    git -C "${1:-.}" merge-base --is-ancestor "$latest_stable_hash" HEAD &> "$_ignore"
}
