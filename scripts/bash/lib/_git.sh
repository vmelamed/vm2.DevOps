# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # variable is referenced but not assigned.

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
#   if validate_repo_owner "my-org"; then echo "Valid repo owner"; fi
# See also: https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details on GitHub repository owner naming rules.
#-------------------------------------------------------------------------------
function validate_repo_owner()
{
    if [[ $# -ne 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires exactly one argument: the repository owner to validate."
        return 2
    fi
    [[ -z "$1" || "$1" =~ $repo_owner_regex ]] || {
        # repo owner can be empty (for user-level repos) or must match the regex for GitHub owner/organization names
        error "Invalid repository owner. $valid_repo_owners"
        return 1
    }
}

declare -r valid_repo_names="GitHub repository names can be up to 100 characters, cannot end with .git, and can contain letters, digits, dots, underscores, and hyphens, but must start with a letter or digit.
See https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details."

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository name is valid according to
#   GitHub naming rules, i.e. it matches the regular expression for GitHub
#   repository names and does not end with ".git".
# Parameters:
#   1 - repository name to validate
# Returns:
#   Exit code: 0 if the repository name is valid, 1 if it is invalid
# Examples:
#   if validate_repo_name "my-repo"; then echo "Valid repo name"; fi
#   repo_name=$(enter_value "GitHub Repository name" "$default_repo_name" false validate_repo_name)
# See also: https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details on GitHub repository naming rules.
#-------------------------------------------------------------------------------
function validate_repo_name()
{
    if [[ $# -ne 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires exactly one argument: the repository name to validate."
        return 2
    fi
    [[ -n "$1" && "$1" != *.git && "$1" =~ $repo_name_regex ]] || {
        # repo name cannot be empty, cannot end with .git, and must match the regex for GitHub repository names above
        error "Invalid repository name. $valid_repo_names"
        return 1
    }
}

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository description is valid according to
#   GitHub naming rules, i.e. it is between 3 and 350 characters long.
# Parameters:
#   1 - repository description to validate
# Returns:
#   Exit code: 0 if the repository description is valid, 1 if it is invalid
# Examples:
#   if validate_repo_description "This is my repo"; then echo "Valid repo description"; fi
#   repo_description=$(enter_value "GitHub Repository description" "$default_repo_description" false validate_repo_description)
# See also: https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user for details on GitHub repository description rules.
#--------------------------------------------------------------------------------
function validate_repo_description()
{
    if [[ $# -ne 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires exactly one argument: the repository description to validate."
        return 2
    fi
    (( ${#1} >= 3 && ${#1} <= 350 )) || {
        # GitHub repository descriptions must be between 3 and 350 characters long.
        error "Repository description must be between 3 and 350 characters long"
        return 1
    }
}

#-------------------------------------------------------------------------------
# Summary: Validates that the specified repository branch name is valid according to
#   git branch naming rules, i.e. it is a valid git ref name.
# Parameters:
#   1 - repository branch name to validate
# Returns:
#   Exit code: 0 if the repository branch name is valid, 1 if it is invalid
# Examples:
#   if validate_repo_branch "main"; then echo "Valid branch name"; fi
#   branch_name=$(enter_value "Default branch name" "$default_branch" false validate_repo_branch)
# See also: https://git-scm.com/docs/git-check-ref-format for details on valid git ref names
#--------------------------------------------------------------------------------
function validate_repo_branch()
{
    if [[ $# -ne 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires exactly one argument: the repository branch name to validate."
        return 2
    fi
    git check-ref-format --branch "$1" &> "$_ignore" || {
        error "Invalid branch name '$1'. Branch names must be valid git ref names. See https://git-scm.com/docs/git-check-ref-format for details."
        return 1
    }
}

#-------------------------------------------------------------------------------
# Summary: Validates that the specified secret value is valid according to
#   GitHub secret rules, i.e. it is base64 encoded.
# Parameters:
#   1 - secret value to validate
# Returns:
#   Exit code: 0 if the secret value is valid, 1 if it is invalid
# Examples:
#   if validate_secret "c2VjcmV0VmFsdWU="; then echo "Valid secret"; fi
# See also: https://docs.github.com/en/actions/security-guides/encrypted-secrets for details on GitHub secrets
#-------------------------------------------------------------------------------
function validate_secret()
{
    if [[ $# -ne 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires exactly one argument: the secret value to validate."
        return 2
    fi
    [[ -z "$1" ]] || is_base64 "$1" || {
        error "Invalid secret value. Secrets must be base64 encoded or empty."
        return 1
    }
}


#-------------------------------------------------------------------------------
# With the following constants and functions we define the repository state: it is an associative array with predefined keys.
# The following constants define the predefined keys of a repo state:
#-------------------------------------------------------------------------------
declare -xr key_root='root'
declare -xr key_url='url'
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

#-------------------------------------------------------------------------------
# Summary: initializes a repo state to an initial state where it contains all predefined keys with values - empty strings
# Parameters:
#   1 - nameref: the name of an associative array variable to be initialized as repo state.
#-------------------------------------------------------------------------------
function initialize_repo_state()
{
    if [[ $# != 1 ]] || ! is_defined_associative_array "$1"; then
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument - the name of an associative array variable."
        return 2
    fi
    local -n state="$1"
    local key
    state=()
    for key in "${repo_state_keys[@]}"; do
        state+=(["$key"]='')
    done
    return 0
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
# shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string - it's a nameref
# shellcheck disable=SC2004 # $/${} is unnecessary on arithmetic variables - state is assoc.array
function get_repo_state()
{
    if [[ $# -lt 2 || $# -gt 3 || ! -d "$1" ]] || ! is_defined_associative_array "$2"; then
        error 3 "${FUNCNAME[0]}() requires 2 or 3 arguments:
1) the existing path to the root of the git repo working tree
2) nameref: the name of an associative array variable - to receive the repo state
3) full_info (optional, default: true) - if false, only retrieve the local Git repository state without trying to get GitHub API data."
        return 2
    fi

    local full_info=true

    [[ $# == 3 ]] && is_boolean "$3" && full_info=$3

    local -n state="$2" # associative array variable to receive the repo state, passed by nameref
    initialize_repo_state "$2" # make sure we have all fields

    state[$key_root]=$(git -C "$1" rev-parse --show-toplevel 2>"$_ignore") || return 0 # no local git repo - return
    url=$(git -C "$1" remote get-url origin 2>"$_ignore")                  || return 0 # no origin remote - return

    [[ -n $url && $url =~ $github_url_regex ]]                             || return 0 # origin remote is not a GitHub URL - return

    local authority="${BASH_REMATCH[$url_authority]}"
    local owner="${BASH_REMATCH[$url_owner]}"
    local name="${BASH_REMATCH[$url_name]}"
    name="${name%.git}"

    state[$key_url]="$url"
    state[$key_authority]="${authority}"
    state[$key_owner]="${owner}"
    state[$key_name]="${name}"
    state[$key_repo]="${owner}/${name}"

    $full_info                                                             || return 0 # caller does not want full info - return with what we have from git, without trying to get GitHub API data

    local gh_repo_id gh_default_branch gh_owner gh_name gh_repo gh_ssh_url gh_url

    {
        IFS= read -r gh_repo_id
        IFS= read -r gh_default_branch
        IFS= read -r gh_owner
        IFS= read -r gh_name
        IFS= read -r gh_repo
        IFS= read -r gh_ssh_url
        IFS= read -r gh_url
    } < <(gh repo view \
                --json id,defaultBranchRef,owner,name,nameWithOwner,sshUrl,url \
                --jq '.id,.defaultBranchRef.name,.owner.login,.name,.nameWithOwner,.sshUrl,.url' \
                "$owner/$name" 2>"$_ignore")                               || return 0 # gh command failed, e.g. due to API error or authentication issue - return with what we have from git, without GitHub API data

    local -i errs=$errors
    local -i rc=0

    # these are real logical problems that can occur if the git remote is misconfigured or the API is returning unexpected data,
    # so we check them all and report all mismatches rather than bailing on the first one
    [[ "$gh_ssh_url" == "${state[$key_url]}"            ||
       "$gh_url" == "${state[$key_url]}" ]]             || error "GitHub API returned URLs '$gh_ssh_url' and '$gh_url' that do not match the git remote URL '${state[$key_remote_url]}'."
    [[ "$gh_owner" == "${state[$key_owner]}" ]]         || error "GitHub API returned owner '$gh_owner' that does not match the git remote owner '${state[$key_owner]}'."
    [[ "$gh_name" == "${state[$key_name]}" ]]           || error "GitHub API returned name '$gh_name' that does not match the git remote name '${state[$key_name]}'."
    [[ "$gh_repo" == "${state[$key_repo]}" ]]           || error "GitHub API returned repo '$gh_repo' that does not match the expected repo '${state[$key_repo]}'."
    [[ -n "$gh_repo_id" ]]                              || error "GitHub API did not return a repo ID for '$gh_repo'."

    rc=$(( errs < errors ? 1 : 0 ))

    state[$key_repo_id]="$gh_repo_id"
    state[$key_default_branch]="$gh_default_branch"

    return "$rc"
}

#-------------------------------------------------------------------------------
# Summary: Tests if the specified repo state has a local Git repository, i.e. if the "root" key is set to a non-empty value.
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state.
#-------------------------------------------------------------------------------
function has_local_repo()
{
    if [[ $# != 1 ]] || ! is_defined_associative_array "$1"; then
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument - the name of an associative array variable."
        return 2
    fi
    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string. It's a nameref to an associative array.
    local -n state="$1"
    [[ -v state["$key_root"] && -n ${state["$key_root"]} ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the specified repo state has a remote Git repository, i.e. if the "url" key is set to a non-empty value.
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state.
#-------------------------------------------------------------------------------
function has_remote_repo()
{
    if [[ $# != 1 ]] || ! is_defined_associative_array "$1"; then
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument - the name of an associative array variable."
        return 2
    fi
    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string. It's a nameref to an associative array.
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
    if [[ $# != 1 ]] || ! is_defined_associative_array "$1"; then
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument - the name of an associative array variable."
        return 2
    fi
    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string. It's a nameref to an associative array.
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
    $verbose || return 0

    if [[ $# != 1 ]] || ! is_defined_associative_array "$1"; then
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument - the name of an associative array variable to write to stdout."
        return 2
    fi

    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string. It's a nameref to an associative array.
    local -n __state="$1"
    local key

    {
        echo "Repository state '$1':"
        for key in "${repo_state_keys[@]}"; do
            [[ -v __state[$key] ]] && printf "  %-15s → '%s'\n" "$key" "${__state[$key]}" || printf "  %-15s ✗ not set\n" "$key"
        done
    } | trace

    return 0
}

#-------------------------------------------------------------------------------
# Summary: Reads (deserializes) a repo state from stdin. If a repo state key is missing in stdin, it is still added but with
#   empty string value. Unknown keys are written as they are (but you may get a trace warning).
# Parameters:
#   1 - nameref: the name of an associative array variable - the repo state to be serialized.
#-------------------------------------------------------------------------------
function read_repo_state()
{
    if [[ $# != 1 ]] || ! is_defined_associative_array "$1"; then
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument - the name of an associative array variable to read from to stdin."
        return 2
    fi
    initialize_repo_state "$1"
    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string - it's a nameref to an associative array
    local -n state="$1"
    local key value
    while IFS='=' read -r key value; do
        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true - trace always returns true
        is_in "$key" "${repo_state_keys[@]}" &&
            trace "read_repo_state: '$key'='$value'" ||
            trace "⚠️  WARNING: Unexpected key '$key' in the repo state input."
        state["$key"]="$value"
    done
}

function print_repo_state()
{
    if [[ $# != 1 ]] || ! is_defined_associative_array "$1"; then
        error 3 "${FUNCNAME[0]}() requires exactly 1 nameref argument - the name of an associative array variable to print."
        return 2
    fi
    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string - it's a nameref to an associative array.
    local -n state="$1"
    local key
    echo "Repository state:"
    for key in "${repo_state_keys[@]}"; do
        [[ -v state["$key"] ]] && echo "  $key: ${state[$key]}" || echo "  $key: "
    done
}

#-------------------------------------------------------------------------------
# Summary: Finds the root directory of a Git repository working tree by searching for a directory with the given name under a
# specified parent directory.
# Parameters:
#  1 - dir - directory name or relative path to search for (optional, default: current directory)
#  2 - root_only - if true, only accept directories that are the root of a Git repository working tree
#      if false, accept any directory inside a Git repository working tree (optional, default: true)
#  3 - repos_parent - parent directory under which to search for the specified directory (optional, default: $VM2_REPOS or $HOME)
# Returns:
#  stdout: the absolute path to the Git repository root
#  Exit code: 0 if exactly one matching root is found, 1 if none or multiple found, 2 on invalid arguments
# Dependencies: git, find
# Usage: root=$(find_repo_root <directory-name> [root-only] [repos-parent])
# Example: root=$(find_repo_root "vm2.Glob") # Finds the root of the Git repository containing a directory named "vm2.Glob"
#  under $HOME
# Example: root=$(find_repo_root "vm2.Templates/templates/AddNewPackage/content" true) # Finds the directory path
#  "vm2.Templates/templates/AddNewPackage/content" that is inside a Git repository work tree
#-------------------------------------------------------------------------------
function find_repo_root()
{
    local dir_path=${1:-"$(pwd)"}
    dir_path=${dir_path#/*/} # remove leading path components to be able to match the directory name with "*/$dir_path" in find
                             # this allows the caller to specify either a directory name or a relative path, e.g. "vm2.Glob" or "vm2.Glob/subdir"
    local root_only=${2:-true}
    local repos_parent="${3:-${VM2_REPOS:-$HOME}}"
    # dir_path=${dir_path%/}
    local root=""
    local found_roots=0
    local d
    local e

    # find a directory with the same sub-path under $repos_parent and check if it is a git work tree root (if root_only is true)
    # or inside a git work tree (if root_only is false)
    while IFS= read -r d; do
        if [[ "$root_only" == true ]]; then
            e="$(git -C "$d" rev-parse --show-toplevel 2>"$_ignore")" || continue
            root="$e"
            ((++found_roots))
        elif is_inside_work_tree "$d"; then
            root="$d"
            ((++found_roots))
        fi
    done < <(find "$repos_parent" -type d -path "*/$dir_path" 2>"$_ignore")

    local rc=0
    (( found_roots == 1 )) && rc=0 || rc=1
    (( found_roots  > 1 )) && { rc=2; root=""; error "Multiple directories named '$dir_path' were found that are roots of Git repository work trees."; }

    # send the root to stdout
    echo "${root}"

    return "$rc"
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
    if [[ -d $1 ]]; then
        git -C "$1" rev-parse --show-toplevel 2> "$_ignore"
    else
        git rev-parse --show-toplevel 2> "$_ignore"
    fi
}

#-------------------------------------------------------------------------------
# Summary: Tests if the specified directory is inside a Git repository (inside a git working tree).
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
    if [[ $# -ne 1 ]]; then
        error 3 "${FUNCNAME[0]}() requires exactly one argument: the directory to test."
        return 2
    fi

    [[ -d $1 ]] && git -C "$1" rev-parse --is-inside-work-tree &> "$_ignore"
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is on the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
#   2 - stable_tag_regex - regular expression for matching stable tags
#   3 - skip_fetch - if true, skip fetching from remote (optional, default: fetch from remote)
# Returns:
#   Exit code: 0 if on latest stable tag, 1 if not, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_on_latest_stable_tag <directory> <stable-tag-regex> [skip-fetch]; then ... fi
# Example: if is_on_latest_stable_tag "$repo_dir" "^v[0-9]+\.[0-9]+\.[0-9]+$"; then echo "On latest stable"; fi
#-------------------------------------------------------------------------------
function is_on_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error 3 "${FUNCNAME[0]}() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch the latest changes in main from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag current_commit tag_commit

    is_inside_work_tree "$1" || return 2
    if [[ $# -lt 3 || "$3" != true ]]; then
        git -C "$1" fetch origin main --quiet
    fi

    # Get latest stable tag (excludes pre-release tags with -)
    latest_tag=$(git -C "$1" tag | grep -E "$2" | sort -V | tail -n1)
    [[ -n $latest_tag ]] || return 1

    current_commit=$(git -C "$1" rev-parse HEAD)

    tag_commit=$(git -C "$1" rev-parse "$latest_tag^{commit}" 2>"$_ignore")

    [[ "$current_commit" == "$tag_commit" ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is after the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
#   2 - stable_tag_regex - regular expression for matching stable tags
#   3 - skip_fetch - if true, skip fetching from remote (optional, default: fetch from remote)
# Returns:
#   Exit code: 0 if after latest stable tag, 1 if not, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_after_latest_stable_tag <directory> <stable-tag-regex> [skip-fetch]; then ... fi
# Example: if is_after_latest_stable_tag "$repo_dir" "^v[0-9]+\.[0-9]+\.[0-9]+$"; then echo "Beyond latest stable"; fi
#-------------------------------------------------------------------------------
function is_after_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error 3 "${FUNCNAME[0]}() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch the latest changes in main from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag tag_commit commits_after

    is_inside_work_tree "$1" || return 2
    if [[ $# -lt 3 || "$3" != true ]]; then
        git -C "$1" fetch origin main --quiet
    fi

    # Get latest stable tag (excludes pre-release tags with -)
    latest_tag=$(git -C "$1" tag | grep -E "$2" | sort -V | tail -n1)
    [[ -n $latest_tag ]] || return 1

    tag_commit=$(git -C "$1" rev-parse "$latest_tag^{commit}" 2>"$_ignore")

    # Check if current commit is after the latest stable tag
    commits_after=$(git -C "$1" rev-list "$tag_commit..HEAD" --count 2>"$_ignore")
    [[ $commits_after -gt 0 ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the current commit in the specified directory is on or after the latest stable tag.
# Parameters:
#   1 - directory - path to Git repository
#   2 - stable_tag_regex - regular expression for matching stable tags
#   3 - skip_fetch - if true, skip fetching from remote (optional, default: fetch from remote)
# Returns:
#   Exit code: 0 if on or after latest stable tag, 1 if before, 2 on invalid arguments or errors
# Dependencies: git
# Usage: if is_on_or_after_latest_stable_tag <directory> <stable-tag-regex> [skip-fetch]; then ... fi
# Example: if is_on_or_after_latest_stable_tag "$repo_dir" "^v[0-9]+\.[0-9]+\.[0-9]+$"; then echo "Ready for release"; fi
#-------------------------------------------------------------------------------
function is_on_or_after_latest_stable_tag()
{
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        error 3 "${FUNCNAME[0]}() takes 2 arguments: directory and regular expression for stable tag." \
              "A third argument may be specified to fetch the latest changes in main from remote."
    fi
    if [[ ! -d "$1" ]]; then
        error "The specified directory '$1' does not exist."
    fi
    if [[ -z "$2" ]]; then
        error "The regular expression for stable tag cannot be empty."
    fi
    ((errors == 0 )) || return 2

    local latest_tag tag_commit

    is_inside_work_tree "$1" || return 2
    if [[ $# -lt 3 || "$3" != true ]]; then
        git -C "$1" fetch origin main --quiet
    fi

    # Get latest stable tag
    latest_tag=$(git -C "$1" tag | grep -E "$2" | sort -V | tail -n1)
    [[ -n $latest_tag ]] || return 1

    tag_commit=$(git -C "$1" rev-parse "$latest_tag^{commit}" 2>"$_ignore")

    # Check if current commit is on or after the latest stable tag
    # Returns 0 if tag commit is an ancestor of HEAD (i.e., HEAD is at or after the tag)
    git -C "$1" merge-base --is-ancestor "$tag_commit" HEAD &> "$_ignore"
}
