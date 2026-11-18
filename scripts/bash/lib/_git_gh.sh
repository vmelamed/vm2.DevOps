# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines functions for working with GitHub repositories.
# It includes functions for validating GitHub repository owners and names, parsing GitHub
# URLs, and other GitHub-related utilities.
#===============================================================================================

# Circular include guard
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

# vm2 core lib constants
declare -x warn_em

# vm2 core lib variables
declare -x _ignore

declare -xr default_default_branch="main"

declare -xr gh_authority_rex="github\.com"
declare -xr gh_ssh_authority_rex="git@$gh_authority_rex"                        # OK, this is not URI authority, but here we only support GitHub SSH URLs, so we can call GitHub SSH authority. This is the part of the URL before the owner/name, e.g. "git@github.com" from "git@github.com:vmelamed/vm2.DevOps.git"
declare -xr gh_https_authority_rex="https://$gh_authority_rex"                  # OK, this is not URI authority, but here we only support GitHub HTTPS URLs, so we can call GitHub HTTPS authority. This is the part of the URL before owner/name, e.g. "https://github.com" from https://github.com/vmelamed/vm2.DevOps

declare -xr gh_repo_owner_rex='[a-zA-Z0-9][a-zA-Z0-9-]{0,37}[a-zA-Z0-9]'        # GitHub owner/organization names can be up to 39 characters, must start and end with a letter or digit, and can contain letters, digits, and hyphens. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.
declare -xr gh_repo_owner_regex="^$gh_repo_owner_rex$"

declare -xr gh_repo_name_rex='[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}'                  # GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit. See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details.
declare -xr gh_repo_name_regex="^$gh_repo_name_rex$"                            # you still must strip off the suffix .git: _name=${_name%.git}

declare -xr gh_repo_full_name_rex="($gh_repo_owner_rex)/($gh_repo_name_rex)"
declare -xr gh_repo_full_name_regex="^$gh_repo_full_name_rex$"

declare -xr github_url_regex="^([a-z][a-z0-9+.-]*://([^/@]+@)?(ssh\.)?github\.com(:[0-9]+)?/|([^/@:]+@)?(ssh\.)?github\.com:)($gh_repo_owner_rex)/($gh_repo_name_rex)(\.git)?/?$"

#===============================================================================================
# With the following constants and functions we define the repository state: it is an
# associative array with predefined keys.
# The following constants define the predefined keys of a repo state:
#===============================================================================================
declare -xr key_git_root='root'
declare -xr key_git_url='url'
declare -xr key_owner='owner'
declare -xr key_name='name'
declare -xr key_gh_full_name='full_name'
declare -xr key_gh_repo_id='repo_id'
declare -xr key_default_branch='default_branch'

# keys used in gh api results
declare -xr key_ssh_url='ssh_url'
declare -xr key_clone_url='clone_url'

#===============================================================================================
# The following list contains the predefined keys of a repo state:
#===============================================================================================
declare -xar repo_state_keys=(
    "$key_git_root"
    "$key_git_url"
    "$key_owner"
    "$key_name"
    "$key_gh_full_name"
    "$key_gh_repo_id"
    "$key_default_branch"
)

# vm2 core lib variables
declare -x _ignore

#-----------------------------------------------------------------------------------------------
# @description Predicate - tests that the specified repository owner is valid according to GitHub naming
#   rules, i.e. it matches the regular expression for GitHub owner/organization names.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository owner naming rules.
#
# @arg $1 string The repository owner to validate.
#
# @exitcode positive=0: If the GitHub repository owner is valid.
# @exitcode negative=1: If the GitHub repository owner is not valid.
#
# @example
#   if is_valid_gh_repo_owner "my-org"; then echo "Valid repo owner"; fi
#-----------------------------------------------------------------------------------------------
function is_valid_gh_repo_owner()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository owner to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _owner=${1:-}
    [[ $_owner =~ $gh_repo_owner_regex ]]
}

#-----------------------------------------------------------------------------------------------
# @description Predicate - tests that the specified repository name is valid according to GitHub
#   naming rules, i.e. it matches the regular expression for GitHub repository names and does
#   not end with `.git`.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository naming rules.
#
# @arg $1 string The repository name to validate.
#
# @exitcode positive=0: If the repository name is valid.
# @exitcode negative=1: If the repository name is not valid.
#
# @example
#   if is_valid_gh_repo_name "my-repo"; then echo "Valid repo name"; fi
# @example
#   enter_value "GitHub Repository name" repo_name "$default_repo_name" false is_valid_gh_repo_name
#-----------------------------------------------------------------------------------------------
function is_valid_gh_repo_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository name to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _repo="${1:-}"

    # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
    [[ $_repo =~ $gh_repo_name_regex && $_repo != *.git ]]
}

#-----------------------------------------------------------------------------------------------
# @description Predicate - tests that the specified repository full name (<owner>/<repo name>)
#   is valid according to GitHub naming rules above
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository naming rules.
#
# @arg $1 string The repository name to validate.
#
# @exitcode positive=0: If the repository name is valid.
# @exitcode negative=1: If the repository name is not valid.
#
# @example
#   if is_valid_gh_repo_name "my-repo"; then echo "Valid repo name"; fi
# @example
#   enter_value "GitHub Repository name" repo_name "$default_repo_name" false is_valid_gh_repo_name
#-----------------------------------------------------------------------------------------------
function is_valid_gh_repo_full_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository name to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _full_name="${1:-}"

    # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository full names above
    [[ $_full_name =~ $gh_repo_full_name_regex && $_full_name != *.git ]]
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
#   if validate_gh_repo_description "This is my repo"; then echo "Valid repo description"; fi
# @example
#   enter_value "GitHub Repository description" repo_description "$default_repo_description" false validate_gh_repo_description)
#-----------------------------------------------------------------------------------------------
function is_valid_gh_repo_description()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository description to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local _description=${1:-}

    # GitHub repository descriptions must be between 3 and 350 characters long.
    (( ${#_description} >= 3 && ${#_description} <= 350 ))
}

#-----------------------------------------------------------------------------------------------
# @description Validates that the specified repository owner is valid according to GitHub
#   naming rules, i.e. it matches the regular expression for GitHub owner/organization names.
#
# Notes:
#   - See [GitHub REST API docs](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user)
#     for details on GitHub repository owner naming rules.
#
# @arg $1 string The repository owner to validate.
#
# @exitcode success=0: If the repository owner is valid.
# @exitcode err_argument_value=4: If the repository owner is not empty and does not match the
#   GitHub owner/organization naming rules.
#
# @example
#   if validate_gh_repo_owner "my-org"; then echo "Valid repo owner"; fi
#-----------------------------------------------------------------------------------------------
function validate_gh_repo_owner()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository owner to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    # repo owner can be empty (for user-level repos) or must match the regex for GitHub owner/organization names
    is_valid_gh_repo_owner "$1"                                                 || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid repository owner (provided '${1-<missing>}')."
    return "$_rc"
}

readonly __valid_repo_names_msg="GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit.
See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details."

#-----------------------------------------------------------------------------------------------
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
# @exitcode success=0: If the repository name is valid.
# @exitcode err_argument_value=4: If the repository name is empty, ends with `.git`, or does
#   not match the GitHub repository naming rules.
#
# @example
#   if validate_gh_repo_name "my-repo"; then echo "Valid repo name"; fi
# @example
#   enter_value "GitHub Repository name" repo_name "$default_repo_name" false validate_gh_repo_name
#-----------------------------------------------------------------------------------------------
function validate_gh_repo_name()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository name to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
    is_valid_gh_repo_name "$1"                                                  || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid repository name (provided '${1-<missing>}'). $__valid_repo_names_msg"
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
#   if validate_gh_repo_description "This is my repo"; then echo "Valid repo description"; fi
# @example
#   enter_value "GitHub Repository description" repo_description "$default_repo_description" false validate_gh_repo_description)
#-----------------------------------------------------------------------------------------------
function validate_gh_repo_description()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the repository description to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    # GitHub repository descriptions must be between 3 and 350 characters long.
    is_valid_gh_repo_description "$1"                                           || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the repository description, to contain between 3 and 350 characters (provided '${1-<missing>}')."
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description The `--is-transient` predicate of `execute_with_retry` for every `gh` command,
#   `gh api` included: decides whether a failure is worth retrying. One rule: the HTTP status
#   decides; failing that, the message.
#
# Notes:
#   - `gh api` writes the error's JSON body to stdout. If it has a `.status`, only that status
#     decides: `425`, `429`, and `5xx` are transient, anything else is not.
#   - Otherwise (any other `gh` command, or a failure without a JSON body), stderr decides: an
#     `HTTP 425`/`HTTP 429`/`HTTP 5xx` status in the message, or a message about a rate limit, a
#     server error, a timeout, an unavailable service, "try again", the connection, the network,
#     or DNS.
#   - A number elsewhere in the message (e.g. a run ID with `500` in it) is not taken for a status.
#   - An authentication failure is not transient: a bad token does not fix itself in seconds.
#
# @arg $1 int The failed command's exit code [1, 255].
# @arg $2 string The name of the file holding the command's stdout.
# @arg $3 string The name of the file holding the command's stderr.
#
# @exitcode positive=0: The failure is transient: the command can be retried.
# @exitcode negative=1: The failure is persistent: retrying would not help.
#
# @example
#   execute_with_retry --delay 3 --quiet --is-transient is_transient_gh_error \
#       gh repo create my-repo --public
# @example
#   repo_id=$(execute_with_retry --query --is-transient is_transient_gh_error \
#                 gh api "repos/vmelamed/vm2.Ulid" --jq .id)
#-----------------------------------------------------------------------------------------------
function is_transient_gh_error()
{
    are_transient_args_valid "$@"

    local _exit_code=$1
    local _stdout_file=$2
    local _stderr_file=$3

    # 'gh api' writes the error's JSON body to stdout: its HTTP status decides ('?' tolerates a non-object, e.g. the
    # array of a partially paginated response)
    local _status
    _status=$(jq -r '.status? // empty' "$_stdout_file" 2>"$_ignore")           || true

    if [[ -n $_status ]]; then
        [[ $_status =~ ^(425|429|5[0-9]{2})$ ]] && return "$positive"
        trace "Non-transient 'gh' failure (exit code $_exit_code): HTTP status $_status."
        return "$negative"
    fi

    # otherwise (any other 'gh' command, or no JSON body): the message decides
    local _message
    _message=$(< "$_stderr_file")                                               || true

    [[ $_message =~ HTTP\ (425|429|5[0-9]{2})([^0-9]|$)|rate.limit|server.error|timeout|temporarily.unavailable|try.again|connection|network|dns ]] &&
        return "$positive"

    trace "Non-transient 'gh' failure (exit code $_exit_code): $_message"
    return "$negative"
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
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                       "  - repo: the full name of the repository (<repo owner>/<repo name>)" \
                                                                                       "  - property: the name of a property to get" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_valid_gh_repo_full_name "$1"                             || bug "${FUNCNAME[0]}() requires argument 1 to be a full name (<repo owner>/<repo name>) of a GitHub repository (provided '${1-<missing>}')." -ec "$err_argument_value"
    [[ ! -v 2 || "$2" =~ ^[a-z][a-z_.]*$ ]]                                     || bug "${FUNCNAME[0]}() requires argument 2 to be the name of a property to get (provided '${2-<missing>}')." -ec "$err_argument_value"
                                                                                exit_if_has_bugs

    local _repo_full_name=$1
    local _property_name=$2
    local -i _rc=$success

    execute_with_retry --query --is-transient is_transient_gh_error \
        gh api --paginate "repos/$_repo_full_name" -q ".$_property_name"        || with_error _rc "$err_tool_error" "Could not get the property '$_property_name' of the repository '$_repo_full_name' from GitHub"

    return "$_rc"
}

function is_repo_state_initialized()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#) - nameref: the name of an associative array variable - to receive the initialized GitHub repo state" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "${FUNCNAME[0]}() requires argument 1 to be a name of an associative array that will receive the repository state (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    # shellcheck disable=SC2178 # Warning: Variable was used as an array but is now assigned a string.
    local -n __state=$1

    (( ${#__state[@]} >= "${#repo_state_keys[@]}" ))                            || return "$negative"

    local _key

    for _key in "${repo_state_keys[@]}"; do
        [[ -v __state[$_key] ]]                                                 || return "$negative"
    done

    return "$positive"
}

function initialize_repo_state()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 argument (provided $#) - nameref: the name of an associative array variable - to receive the initialized GitHub repo state" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "${FUNCNAME[0]}() requires argument 1 to be a name of an associative array that will receive the repository state (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    # shellcheck disable=SC2178 # Warning: Variable was used as an array but is now assigned a string.
    local -n __state=$1
    local _key

    # initialize the entries read below, so a missing key does not trip 'set -u'.
    # shellcheck disable=SC2004
    for _key in "${repo_state_keys[@]}"; do
        __state[$_key]=''
    done
}

declare -r jq_gh_repo_state="{
    $key_owner: .owner.login,
    $key_name: .name,
    $key_gh_full_name: .full_name,
    $key_gh_repo_id: .id,
    $key_default_branch: .default_branch,
} | to_entries[] | \"\\(.key)=\\(.value)\""

#-----------------------------------------------------------------------------------------------
# @description Retrieves the state of a GitHub repository
#
# @arg $1 string the full GitHub repository name::=<repo owner>/<repo name>
# @arg $2 nameref the name of an associative array variable to receive the state
#
# @exitcode success=0: on success
# @exitcode err_tool_error=66: if querying GitHub failed (see the other errors)
#
# @example
# declare -i _rc=$success
# declare -A _gh_state
# get_repo_gh_state "vmelamed/vm2.DevOps" _gh_state || with_error _rc "Failed to get the GitHub state of 'vmelamed/vm2.DevOps'"
#-----------------------------------------------------------------------------------------------
function get_gh_repo_state()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                       "  - repo: the full name of the repository (<repo owner>/<repo name>)" \
                                                                                       "  - nameref: the name of an associative array variable - to receive the GitHub repo state" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_valid_gh_repo_full_name "$1"                             || bug "${FUNCNAME[0]}() requires argument 1 to be a full name (<repo owner>/<repo name>) of a GitHub repository (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
    [[ ! -v 2 ]] || { is_associative_array "$2" && is_repo_state_initialized "$2"; } \
                                                                                || bug "${FUNCNAME[0]}() requires argument 2 to be a name of initialized associative array that will receive the repository state (provided '${2-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local _repo_full_name=$1
    local -n __gh_state=$2
    local -i _rc=$success

    local _query_result
    _query_result=$(execute_with_retry --query --is-transient is_transient_gh_error \
                        gh api --paginate "repos/$_repo_full_name" -q "$jq_gh_repo_state") \
                                                                                || with_error _rc "$err_tool_error" "Could not get the status of the repository '$_repo_full_name' from GitHub"

    (( _rc != success )) || {
                                local _k _v
                                while IFS='=' read -r _k _v; do
                                    [[ -n $_k ]] || continue
                                    __gh_state["$_k"]="$_v"
                                done <<< "$_query_result"
                            }

    return "$_rc"
}

# BASH_REMATCH indexes after matching a URL with $github_url_regex:
declare -xri url_owner=7
declare -xri url_name=8

#-----------------------------------------------------------------------------------------------
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
# @arg $1 string path to an existing directory from the Git repository working tree.
# @arg $2 nameref to an associative array variable to receive the repo state.
# @arg $3 bool _full_info if false, only retrieve the local Git repository state without
#   querying the GitHub API for the GH properties (optional, default: true).
#
# @exitcode success=0: On success, or when the directory has no local/GitHub repo state to
#   report.
# @exitcode failure=1: If the GitHub API data does not match the local Git remote data.
#
# @example
#   get_repo_state "/home/valo/repos/vm2.Glob" repo_state
#-----------------------------------------------------------------------------------------------
function get_repo_state()
{
    (( $# == 2 || $# == 3 ))                                                    || bug "${FUNCNAME[0]}() requires 2 or 3 arguments (provided $#):" \
                                                                                       "  - the existing path to the root of the git repo working tree" \
                                                                                       "  - nameref: the name of an associative array variable - to receive the repo state" \
                                                                                       "  - full_info - if false, only retrieve the local Git repository state without trying to get GitHub API data (optional, default: true)" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "${FUNCNAME[0]}() requires argument 1 to be the existing root directory of the Git working tree (provided '${1-<missing>}')." -ec "$err_not_directory"
    [[ ! -v 2 ]] || is_associative_array "$2"                                   || bug "${FUNCNAME[0]}() requires argument 2 to name an associative array that will receive the repository state (provided '${2-<missing>}')." -ec "$err_invalid_nameref"
    [[ ! -v 3 ]] || is_boolean "$3"                                             || bug "${FUNCNAME[0]}() requires optional argument 3, the full-information flag, to be 'true' or 'false' (provided '${3-<missing>}')." -ec "$err_argument_type"
                                                                                exit_if_has_bugs

    local -i _rc="$success"
    local _root=$1
    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local __repo_state_name="$2"
    local -n __repo_state="$__repo_state_name" # associative array variable to receive the repo state, passed by name
    local _full_info=${3:-true}

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    initialize_repo_state "$__repo_state_name" # make sure we have all fields

    local _root_dir

    _root_dir=$(git -C "$_root" rev-parse --show-toplevel 2>"$_ignore")         || return "$success" # no local git repo
    __repo_state["$key_git_root"]=$_root_dir

    local _url

    _url=$(git -C "$_root" remote get-url origin 2>"$_ignore")                  || return "$success" # no remote URL origin
    [[ -n $_url && $_url =~ $github_url_regex ]]                                || return "$success" # origin remote is not a GitHub URL

    local _owner="${BASH_REMATCH[$url_owner]}"
    local _name="${BASH_REMATCH[$url_name]}"
    _name=${_name%.git} # strip off the .git suffix!

    [[ "$_name" == "$(basename "$_root_dir")" ]]                                || with_error _rc "$err_root_not_repo_name" "The root directory name '$(basename "$_root_dir")' does not match the repository name '$_name'."

    # never store credentials: drop the userinfo of an HTTP(S) URL, which may hold a token (e.g. https://ghp_…@github.com/…)
    [[ $_url =~ ^(https?://)[^/@]+@(.*)$ ]] && _url="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"

    local _repo_full_name="$_owner/$_name"

    __repo_state["$key_git_url"]=$_url
    __repo_state["$key_owner"]=$_owner
    __repo_state["$key_name"]=$_name
    __repo_state["$key_gh_full_name"]=$_repo_full_name

    $_full_info                                                                 || return "$_rc" # caller does not want full info - return with what we have from git, without trying to get GitHub API data

    get_gh_repo_state "$_repo_full_name" "$__repo_state_name"                   || return $?

    # make sure all is kosher: the names we've got from Git should match the names from GitHub:
    [[
        $_owner          == "${__repo_state["$key_owner"]}" &&
        $_name           == "${__repo_state["$key_name"]}"  &&
        $_repo_full_name == "${__repo_state["$key_gh_full_name"]}"
    ]]                                                                          || with_error _rc "$err_logic_error" "The properties of the repository '$_name' in the local repository do not match the properties on GitHub"

    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the specified repo state has a local Git repository, i.e. if the
#   `root` key is set to a non-empty, existing directory path.
#
# @arg $1 nameref to an associative array variable holding the repo state.
#
# @exitcode positive=0: If the repo state has a local Git repository.
# @exitcode negative=1: If it does not.
#-----------------------------------------------------------------------------------------------
function has_local_repo()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local -n __state="$1"
    [[ -v __state["$key_git_root"] && -n ${__state["$key_git_root"]} && -d ${__state["$key_git_root"]} ]]
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the specified repo state has a remote Git repository, i.e. if the
#   `url` key is set to a non-empty value.
#
# @arg $1 nameref to an associative array variable holding the repo state.
#
# @exitcode positive=0: If the repo state has a remote Git repository.
# @exitcode negative=1: If it does not.
#-----------------------------------------------------------------------------------------------
function has_remote_repo()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -n __state="$1"
    [[ -v __state["$key_git_url"] && -n ${__state["$key_git_url"]} ]]
}

#-----------------------------------------------------------------------------------------------
# @description Tests if the specified repo state has a remote GitHub repository, i.e. if the
#   `repo_id` key is set to a non-empty value.
#
# @arg $1 nameref to an associative array variable holding the repo state.
#
# @exitcode positive=0: If the repo state has a remote GitHub repository.
# @exitcode negative=1: If it does not.
#-----------------------------------------------------------------------------------------------
function has_github_remote()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable." -ec "$err_invalid_arguments"
    is_associative_array "$1"                                                   || bug "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -n __state="$1"
    [[ -v __state["$key_gh_repo_id"] && -n ${__state["$key_gh_repo_id"]} ]]
}

#-----------------------------------------------------------------------------------------------
# @description Reads (deserializes) a repo state from stdin, in `key=value` lines. If a repo
#   state key is missing from stdin, it is still added, with an empty-string value. Unknown
#   keys are stored as-is (a trace warning is emitted for each).
#
# @arg $1 nameref to an associative array variable to receive the deserialized repo state.
#
# @exitcode success=0: The repo state was deserialized (always, once past the argument
#   validation gate).
#-----------------------------------------------------------------------------------------------
function read_repo_state()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable." -ec "$err_invalid_arguments"
    is_associative_array "$1"                                                   || bug "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    initialize_repo_state "$1"

    local -n __state="$1"
    local _key _value
    while IFS='=' read -r _key _value || [[ -n $_key ]]; do
        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        is_in "$_key" "${repo_state_keys[@]}" &&
            trace "read_repo_state: '$_key'='$_value'" ||
            trace "$warn_em  WARNING: Unexpected key '$_key' in the repo state input."
        __state["$_key"]="$_value"
    done
}

#-----------------------------------------------------------------------------------------------
# @description Prints the repository state to stdout, one line per predefined key.
#
# @arg $1 nameref to an associative array variable holding the repo state to be printed.
#
# @exitcode success=0: The repo state was printed (always, once past the argument validation
#   gate).
#
# @stdout `Repository state:` followed by one `  key: value` line per predefined key.
#-----------------------------------------------------------------------------------------------
function print_repo_state()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly 1 nameref argument (provided $#): the name of an associative array variable." -ec "$err_invalid_arguments"
    is_associative_array "$1"                                                   || bug "${FUNCNAME[0]}() requires argument 1 to name an associative array containing repository state (provided '${1-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local -n __state="$1"
    local _key
    echo "Repository state:"
    for _key in "${repo_state_keys[@]}"; do
        [[ -v __state["$_key"] ]] &&
            echo "  $_key: ${__state[$_key]}" ||
            echo "  $_key: "
    done
}
