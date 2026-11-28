# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines functions for the repository state: an associative array that collects
# what the local Git working tree and the GitHub repository report about a repository (URL,
# owner, name, ID, default branch, etc.), and the predicates and readers over it.
#===============================================================================================

# Circular include guard
(( ${__VM2_LIB_GIT_STATE_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_GIT_STATE_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x positive
declare -x negative
declare -x err_argument_value
declare -x err_invalid_arguments
declare -x err_argument_type
declare -x err_logic_error
declare -x err_tool_error
declare -x err_invalid_nameref
declare -x err_not_directory
declare -x err_root_not_repo_name

# vm2 core lib constants
declare -x warn_em

declare -x l_letters_set
declare -x letters_set
declare -x digits_set


# vm2 core lib variables
declare -x noise_sink

declare -x github_url_regex

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

#-----------------------------------------------------------------------------------------------
# @description Predicate tests if an associative array is initialized as a Git/GitHub repository.
#
# @arg $1 nameref the name of an associative array variable to test
#
# @exitcode positive=0: yes, it is initialized properly as a repo state
# @exitcode negative=1: no, it isn't
#
# @example
# declare -A _gh_state
# if ! is_repo_state_initialized _gh_state; then initialize_repo_state _gh_state; fi
#-----------------------------------------------------------------------------------------------
function is_repo_state_initialized()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): nameref: the name of an associative array variable - to receive the initialized GitHub repo state."
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array that holds the repository state (provided '${1-<missing>}')."
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

#-----------------------------------------------------------------------------------------------
# @description Predicate tests if an associative array is initialized as a Git/GitHub repository.
#
# @arg $1 nameref the name of an associative array variable to initialize
#
# @exitcode success=0: always
#
# @example
# declare -A _gh_state
# if ! is_repo_state_initialized _gh_state; then initialize_repo_state _gh_state; fi
#-----------------------------------------------------------------------------------------------
function initialize_repo_state()
{
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): nameref: the name of an associative array variable - to receive the initialized GitHub repo state."
    [[ ! -v 1 ]] || { is_associative_array "$1" && is_mutable "$1"; }           || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name a writable associative array for the repository state (provided '${1-<missing>}')."
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
    (( $# == 2 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                "  - repo: the full name of the repository (<repo owner>/<repo name>)" \
                                                                                                                "  - nameref: the name of an associative array variable - to receive the GitHub repo state"
    [[ ! -v 1 ]] || is_gh_repo_full_name "$1"                                   || bug "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a full name (<repo owner>/<repo name>) of a GitHub repository (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || { is_repo_state_initialized "$2" && is_mutable "$2"; }      || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to name an initialized, writable associative array for the repository state (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    local _repo_full_name=$1
    local -n __gh_state=$2
    local -i _rc=$success

    local _query_result
    _query_result=$(execute_with_retry --query --classify gh_failure \
                        gh api --paginate "repos/$_repo_full_name" -q "$jq_gh_repo_state") \
                                                                                || with_error _rc "$err_tool_error" "Failed to get the status of the repository '$_repo_full_name' from GitHub."

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
declare -xri url_name=9

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
# @exitcode err_root_not_repo_name=90: The root directory's name differs from the repository name
#   in the `origin` URL (reported; the state is still filled in).
# @exitcode err_tool_error=66: The GitHub API query failed (reported by `get_gh_repo_state`).
# @exitcode err_logic_error=68: The GitHub API data does not match the local Git remote data.
#
# @example
#   get_repo_state "/home/valo/repos/vm2.Glob" repo_state
#-----------------------------------------------------------------------------------------------
function get_repo_state()
{
    (( $# == 2 || $# == 3 ))                                                    || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 or 3 arguments (provided $#):" \
                                                                                                                "  - the existing path to the root of the git repo working tree" \
                                                                                                                "  - nameref: the name of an associative array variable - to receive the repo state" \
                                                                                                                "  - full_info - if false, only retrieve the local Git repository state without trying to get GitHub API data (optional, default: true)"
    [[ ! -v 1 || -d $1 ]]                                                       || bug "$err_not_directory" "${FUNCNAME[0]}() requires argument 1 to be the existing root directory of the Git working tree (provided '${1-<missing>}')."
    [[ ! -v 2 ]] || { is_associative_array "$2" && is_mutable "$2"; }           || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to name a writable associative array for the repository state (provided '${2-<missing>}')."
    [[ ! -v 3 ]] || is_boolean "$3"                                             || bug "$err_argument_type" "${FUNCNAME[0]}() requires optional argument 3, the full-information flag, to be 'true' or 'false' (provided '${3-<missing>}')."
                                                                                exit_if_has_bugs

    local -i _rc="$success"
    local _root=$1
    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local _repo_state_var_name="$2"
    local -n __repo_state="$_repo_state_var_name" # associative array variable to receive the repo state, passed by name
    local _full_info=${3:-true}

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    initialize_repo_state "$_repo_state_var_name" # make sure we have all fields

    local _root_dir

    _root_dir=$(git -C "$_root" rev-parse --show-toplevel 2>"$noise_sink")      || return "$success" # no local git repo
    __repo_state["$key_git_root"]=$_root_dir

    local _url

    _url=$(git -C "$_root" remote get-url origin 2>"$noise_sink")               || return "$success" # no remote URL origin
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

    get_gh_repo_state "$_repo_full_name" "$_repo_state_var_name"                || return $?

    # make sure all is kosher: the names we've got from Git should match the names from GitHub:
    [[
        $_owner          == "${__repo_state["$key_owner"]}" &&
        $_name           == "${__repo_state["$key_name"]}"  &&
        $_repo_full_name == "${__repo_state["$key_gh_full_name"]}"
    ]]                                                                          || with_error _rc "$err_logic_error" "The properties of the repository '$_name' in the local repository do not match the properties on GitHub."

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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of an associative array variable."
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array that holds the repository state (provided '${1-<missing>}')."
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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of an associative array variable."
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array that holds the repository state (provided '${1-<missing>}')."
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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of an associative array variable."
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array that holds the repository state (provided '${1-<missing>}')."
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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of an associative array variable."
    [[ ! -v 1 ]] || { is_associative_array "$1" && is_mutable "$1"; }           || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name a writable associative array for the repository state (provided '${1-<missing>}')."
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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of an associative array variable."
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array that holds the repository state (provided '${1-<missing>}')."
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
