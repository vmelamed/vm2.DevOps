# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#=============================================================================================
# This script defines functions for working with the Git repositories of the vm2 environment.
# It includes functions for resolving the vm2_repos directory and checking the state of Git repositories.
# It is assumed that the vm2 repositories are cloned under a single parent directory, that can be specified by
# 1. a command line argument, or
# 2. the environment variable $VM2_REPOS or
# 3. the parent directory of the repo root of this script:
#    1) if this script is in $vm2_repos/vm2.DevOps/scripts/bash/lib
#    2) the repo root should be $vm2_repos/vm2.DevOps
#    3) the parent directory of the repo root should be $vm2_repos
# 4. the hard-coded default value $HOME/repos/vm2
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_GIT_VM2_SH_LOADED:-0} == 1 )) && return 0
declare -xri __VM2_LIB_GIT_VM2_SH_LOADED=1

declare -xr script_dir
declare -xr lib_dir
declare -x _ignore

declare -xri success
declare -xri failure

declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_not_found
declare -xri err_not_file
declare -xri err_not_directory
declare -xri err_not_git_root
declare -xri err_behind_latest_stable_tag
declare -xri err_invalid_repo
declare -xri err_found_too_many
declare -xri err_repo_with_no_ci
declare -xri err_dir_with_ci
declare -xri err_dir_with_no_ci
declare -xri err_not_git_directory
declare -xri err_logic_error
declare -xri err_not_current_commit
declare -xri err_invalid_branch

declare -xr vm2_devops_repo_name
declare -xr vm2_sot_repo_name

#---------------------------------------------------------------------------------------------
# @description Validates that:
#   1) the specified directory (or repository name resolved under $1 - "$vm2_repos") exists,
#   2) it is the root of a Git repository working tree,
#   3) it has GitHub Actions workflows in the .github/workflows directory,
#   4) it is on the specified branch (or the currently checked-out branch if none is specified), and
#   5) it is at or ahead of the latest stable tag of that branch.
#
# @arg $1 string repository name, or a path (absolute or relative) of the repository, e.g. "vm2.MyRepo" or
#   "repos/vm2/vm2.MyRepo".
# @arg $2 string the parent directory of all vm2 repositories, where the repository named by $2 can also be
#   located if it is given by name only. MUST be already resolved via `resolve_vm2_repos`.
# @arg $3 string the branch to check against the latest stable tag (optional, default: the currently checked-out
#   branch)
#
# @exitcode success/positive=0: the repository directory exists and meets all the criteria above
# @exitcode err_not_found=9: could not find the repository directory from $repo_name and $vm2_repos
# @exitcode err_not_git_directory=80: the resolved path is not a Git repository
# @exitcode err_not_git_root=81: the resolved path exists and is inside a Git repository, but is not the working tree root
# @exitcode err_behind_latest_stable_tag=82: the repository is behind the latest stable tag of the specified branch
# @exitcode err_repo_with_no_ci=85: the repository has no GitHub Actions workflows in '$repo_path/.github/workflows'
# @exitcode err_invalid_branch=84: the repository is not on the expected branch (when $3 is given)
# @exitcode err_not_current_commit=89: the repository exists and is on the expected branch, but is not at or ahead of the
#   latest stable tag
#
# @stdout the absolute path to the working tree root of the resolved repository
#
# @example
#   validate_repo_root "$vm2_repos" "vm2.Glob"
#---------------------------------------------------------------------------------------------
function validate_repo_root()
{

    (( $# == 2 || $# == 3 ))                         || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two or three arguments (provided $#):" \
                                                                                            "  - repository name, or, the absolute or relative path to the repository, e.g. 'vm2.MyRepo' or './my_repos/vm2_packages/vm2.MyRepo'" \
                                                                                            "  - the parent directory of all vm2 repositories where the repository can be located as well (e.g. \$VM2_REPOS or \$(get_devops_parent))" \
                                                                                            "  - the branch to check against the latest stable tag (optional, default: the currently checked out branch)"
    [[ ! -v 1 || -n $1 ]]                            || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the repository name or path, to be non-empty (provided '${1:-<none>}')."
    [[ ! -v 2 || -d $2 ]]                            || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 2, the vm2 repositories parent, to be an existing directory (provided '${2:-<none>}')."
    [[ ! -v 3 || -z $3 ]] ||
    git check-ref-format --branch "$3" &> "$_ignore" || bug -ec "$err_invalid_branch" "${FUNCNAME[0]}() requires optional argument 3 to be a valid Git branch name (provided '${3:-<none>}')."

    exit_if_has_bugs

    local _repo=$1
    local _vm2_repos=$2
    local _branch="$3"
    local _path # the full repo path

    # try to resolve repo_path relative to $_vm2_repos

    # 1) the specified directory exists
    #   try to resolve the repository path from the parameter alone
    #   i.e., the current working directory or the absolute path provided as the first argument
    _path=$(realpath -e "$_repo" 2> "$_ignore") ||
    #   otherwise try to resolve the repository path relative to $_vm2_repos
    _path=$(realpath -e "$_vm2_repos/${_repo#/}" 2> "$_ignore") || {
        # couldn't resolve the repo path - error and exit
        error -ec "$err_not_found" "Could not find the path '$_repo' neither in the current working directory, nor in '$_vm2_repos'."
        return "$err_not_found"
    }

    trace "Resolved repo's path as '$_path' from parameter, or vm2_repos/parameter"

    # 2) it is a root of the working directory of the git repository
    local -i _rc="$success"
    local _r

    root_working_tree "$_path" _r 2> "$_ignore" || {
        _rc=$?
        error -ec "$err_not_git_directory" "The '${_repo:-<none>}' repository at '${_path:-<none>}' is not a git repository." \
                                                 "$(error_message "$_rc")."
        return "$err_not_git_directory"
    }
    [[ "$_path" == "$_r" ]] || {
        error -ec "$err_not_git_root" "The '${_repo:-<none>}' repository at '${_path:-<none>}' is not the root of the git repository working tree."
        return "$err_not_git_root"
    }

    # 3) it has GitHub Actions workflows in the .github/workflows directory
    [[ -d "$_path/.github/workflows" ]] || {
        error -ec "$err_repo_with_no_ci" "The '${_repo:-<none>}' repository does not have GitHub Actions workflows in '${_path:-<none>}/.github/workflows'."
        return "$err_repo_with_no_ci"
    }

    # 4) it is on the specified branch (or the currently checked out branch if not specified)
    if [[ -z "$_branch" ]]; then
        _branch=$(git -C "$_path" branch --show-current 2>"$_ignore")
    else
        [[ "$_branch" == $(git -C "$_path" branch --show-current 2>"$_ignore") ]] || {
            error -ec "$err_invalid_branch" "The '${_repo:-<none>}' repository at '${_path:-<none>}' is not on the branch '${_branch:-<none>}'."
            return "$err_invalid_branch"
        }
    fi

    # 5) it is at or ahead of the latest stable tag of the specified branch.
    ensure_fresh_git_state "$_path" "$_branch" ||
        return $?

    is_on_or_after_latest_stable_tag "$_path" &&
        return "$success" ||
        return "$err_behind_latest_stable_tag"
}

declare -a vm2_repos_instructions=(
    "Please, create a single directory for all vm2.* repositories. "
    "Clone the vm2.DevOps, vm2.Templates, and all vm2.* repositories that you work on into it."
    "Then, either:"
    "  - provide the path to that directory as an argument to the script using the '--vm2-repos <path>' option, or"
    "  - set the environment variable \$VM2_REPOS to the path of that directory, or"
    "  - start the script from the cloned vm2.DevOps repository in that directory."
)

#---------------------------------------------------------------------------------------------
# @description Resolves the vm2_repos directory (the parent directory of all vm2 repositories) from, in order of
# preference:
#   1) the parameter (usually the command-line option --vm2-repos),
#   2) the environment variable $VM2_REPOS, or
#   3) the parent directory of vm2.DevOps's own repository root (via get_devops_parent).
#
# Once resolved, validates that the directory is the parent of both the vm2.DevOps and vm2.Templates repositories, that
# each is on the "main" branch, and that each is at or ahead of its latest stable tag.
#
# Notes:
#   - Despite the exit-code table below (inherited from validate_repo_root), the "behind latest stable tag" warning
#     messages in this function can never actually fire.
#
# @arg $1 string the directory to use as the parent directory of all vm2 repos (optional, default: $VM2_REPOS, or the
#   parent directory of vm2.DevOps's repository root). Usually used with a parameter like '--vm2-repos' on the command line.
# @arg $2 nameref to a variable to receive the resolved vm2_repos directory
#
# @exitcode success/positive=0: the vm2_repos directory was successfully resolved and validated
# @exitcode err_not_directory=17: the parameter, $VM2_REPOS, or the resolved default is not a valid, existing directory
# @exitcode N propagated from validate_repo_root (e.g. $err_not_found, $err_repo_with_no_ci, $err_behind_latest_stable_tag)
#   if vm2.DevOps or vm2.Templates fail validation under the resolved directory
#
# @stdout the absolute path to the vm2_repos directory
#
# @example
#   resolve_vm2_repos vm2_repos "$VM2_REPOS"
#---------------------------------------------------------------------------------------------
# shellcheck disable=SC2120
function resolve_vm2_repos()
{
    (( $# <= 2 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() takes 1 or 2 arguments ($# provided):" \
                                                                                    "  - the directory that is a parent to all vm2 repositories" \
                                                                                    "  - name of a variable to receive the resolved vm2_repos directory"
    [[ ! -v 1 || -z "$1" || -d "$1" ]]       || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 1 to be an existing directory if provided (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_defined_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2 to be a variable name to store the resolved vm2_repos directory (provided '${2:-<none>}')."

    exit_if_has_bugs

    local -n _vm2_repos="$2"

    # try to resolve vm2 from the
    #   1) argument $1 (usually coming from a script command line option --vm2-repos)
    #   2) environment variable $VM2_REPOS
    #   3) the lib/ directory
    #   4) the hardcoded default location ${HOME}/repos/vm2_repos
    # in this order of preference:
    local _source=""

    # #1:
    local _repos="$1"
    if [[ -n "$_repos" && -d "$_repos" ]]; then
        trace "vm2_repos='$_repos' from argument '$1'"
    # #2:
    elif [[ -n "$VM2_REPOS" && -d "$VM2_REPOS" ]]; then
        _repos="$VM2_REPOS"
        trace "vm2_repos='$_repos' from environment variable '\$VM2_REPOS=$VM2_REPOS'"
    # #3:
    elif [[ -d "$(get_devops_parent)" ]]; then
        _repos="$(get_devops_parent)"
        trace "vm2_repos='$_repos' from the location of $vm2_devops_repo_name."
    # #4:
    elif [[ -d "${HOME}/repos/vm2" ]]; then
        _repos="${HOME}/repos/vm2"
        trace "vm2_repos='$_repos' from the default location '${HOME}/repos/vm2'"
    else
        error -ec "$err_not_directory" "Cannot resolve the parent directory of the vm2 repositories." "${vm2_repos_instructions[@]}"
        return "$err_not_directory"
    fi

    # ensure $vm2_repos is an existing, absolute path:
    _repos=$(realpath -e "$_repos" 2> "$_ignore") || {
        error -ec "$err_not_directory" "The resolved parent directory for the vm2 repositories '$_repos' does not exist or is not a directory." "${vm2_repos_instructions[@]}"
        return "$err_not_directory"
    }

    # 1) validate that $vm2_repos is the parent directory of the git repository vm2.DevOps;
    # 2) it is on the main branch;
    # 3) it is at or ahead of the latest stable tag:
    local -i _rc="$success"
    validate_repo_root "$vm2_devops_repo_name" "$_repos" "main" || {
        _rc=$?
        error -ec "$err_logic_error" "The main branch of the repository '$vm2_devops_repo_name' is not in a clean state:" \
                                     "$(error_message "$_rc")"
    }

    # validate that $vm2_repos is the parent directory of the git repository vm2.Templates;
    # it is on the main branch;
    # and it is at or ahead of the latest stable tag:
    validate_repo_root "$vm2_sot_repo_name" "$_repos" "main" || {
        _rc=$?
        error -ec "$err_logic_error" "The main branch of the repository '$vm2_sot_repo_name' is not in a clean state:" \
                                     "$(error_message "$_rc")"
    }

    _vm2_repos="$_repos"
    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Internal helper used by resolve_repo_root. Searches for a directory with the given name (or relative
# path) under a specified parent directory, skipping common noise directories (.git, node_modules, .cache, bin, obj,
# TestResults, etc.) during the search.
#
# @arg $1 string start_from - parent directory under which to search for the specified directory
# @arg $2 string look_for - directory name or relative path to search for
# @arg $3 nameref to a variable to receive the resolved directory path
#
# @exitcode success/positive=0: exactly one matching directory is found, and it is inside a Git repository
# @exitcode err_not_git_directory=80: err_not_git_directory: exactly one matching directory is found, but it is not inside a Git repository
# @exitcode err_found_too_many=10: multiple matching directories are found
# @exitcode err_not_found=9: no matching directory is found
#
# @example
#   search_repo_dir <start-from> <directory-name> <variable-name-to-receive-result>
#---------------------------------------------------------------------------------------------
function search_repo_dir()
{
    (( $# == 3 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly three arguments (provided $#):" \
                                                                                    "  - the search root" \
                                                                                    "  - the directory name or relative path to find" \
                                                                                    "  - the name of a variable to receive the resolved directory path"
    [[ ! -v 1 || -d $1 ]]                    || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 1, the search root, to be an existing directory (provided '${1:-<none>}')."
    [[ ! -v 2 || -n $2 ]]                    || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the directory name or relative path to find, to be non-empty (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_defined_variable "$3" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3, the name of a variable to receive the resolved directory path, to be defined (provided '${3:-<none>}')."

    exit_if_has_bugs

    local _start_from=$1
    local _look_for=$2
    local -n _result_dir="$3"

    local _found_repo_dirs=0
    local _found_dirs=0
    local _in_repo_dir=""
    local _dir=""

    local _dir_rel_path
    # remove the start_from prefix and the following slash, so that the path is relative to the search root and can be concatenated with the search prefix '*/'
    _dir_rel_path="${_look_for#"$_start_from"}"
    _dir_rel_path="${_dir_rel_path#/}"

    local _d
    while IFS= read -r _d; do

        if is_inside_work_tree "$_d"; then
            # good candidate - inside a git repository
            _in_repo_dir="$_d"
            (( ++_found_repo_dirs ))
        else
            # plain directory, it is not inside a git repository
            _dir="$_d"
            (( ++_found_dirs ))
        fi

    done < <(find "$_start_from" \
                  \( -name .git \
                  -o -name node_modules \
                  -o -name .cache \
                  -o -name .nuget \
                  -o -name .dotnet \
                  -o -name .local \
                  -o -name .npm \
                  -o -name .cargo \
                  -o -name .rustup \
                  -o -name __pycache__ \
                  -o -name bin \
                  -o -name obj \
                  -o -name artifacts \
                  -o -name TestResults \
                  -o -name BenchmarkDotNet.Artifacts \
                  \) -prune \
                  -o -type d -path "*/$_dir_rel_path" -print 2>"$_ignore")

    (( _found_repo_dirs + _found_dirs == 0 ))                                      && return "$err_not_found"
    (( _found_repo_dirs == 1 ))                     && _result_dir="$_in_repo_dir" && return "$success"
    (( _found_repo_dirs == 0 && _found_dirs == 1 )) && _result_dir="$_dir"         && return "$err_not_git_directory"

    return "$err_found_too_many"
}

#---------------------------------------------------------------------------------------------
# @description Finds the root directory of a Git repository working tree by searching for a directory with the given
#   name (or relative path) under a specified parent directory (expected to be under $VM2_REPOS, falling back to a search
#   under $HOME if not found there). The target directory does not need to be a Git repository. If it is not, the
#   resolved "root" is instead the nearest parent directory containing a '.github/workflows' directory, or the found
#   directory itself if no such parent is found.
#   Note: This method uses `find` and parent directory traversal, so it is slow!
#   Prefer functions like `root_working_tree` that operate directly on known Git repository directories, or `$initial_cwd`.
#
# @arg $1 string vm2_repos - parent directory under which to search for the specified directory (resolved vm2_repos)
# @arg $2 string dir_path - directory name or relative path to search for (if empty, the default is the current directory)
# @arg $3 nameref to a variable to store the absolute path of the root of the Git repository containing
#   the found directory (or, if the found directory is not a Git repository, the nearest ancestor with CI configuration -- or
#   the found directory itself if none exists)
# @arg $4 nameref to a variable to store the absolute path of the found directory
#
# @exitcode success/positive=0: exactly one matching directory with a Git repository is found and it has CI configuration
# @exitcode err_not_found=9: no matching directory was found, under either $vm2_repos or $HOME (fatal)
# @exitcode err_found_too_many=10: multiple matching directories are found (fatal)
# @exitcode err_invalid_repo=83: the matching directory's Git working-tree root could not be resolved
# @exitcode err_repo_with_no_ci=85: exactly one matching Git repository directory is found, but it has no CI configuration
# @exitcode err_not_git_directory=80: exactly one matching directory with CI configuration is found via a parent walk, but
#   the original match is not a Git repository
# @exitcode err_dir_with_no_ci=87: exactly one matching directory is found, but it is not a Git repository and no
#   ancestor up to $HOME has CI configuration
#
# @stdout two lines:
#   1) the absolute path of the root of the Git repository containing the found directory (or, if the found directory is
#      not a Git repository, the nearest ancestor with CI configuration -- or the found directory itself if none exists)
#   2) the absolute path of the found directory
#
# @example
#   local output path
#   resolve_repo_root "$vm2_repos" "$repo_path" 2>"$_ignore" output path || rc=$?
#   (( rc == success || rc == err_repo_with_no_ci || rc == err_not_git_directory || rc == err_dir_with_no_ci )) || exit "$rc"
#---------------------------------------------------------------------------------------------
function resolve_repo_root()
{
    (( $# == 4 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 4 arguments ($# provided): " \
                                                                                    "  - the parent directory under which to search for the vm2 repository (resolved vm2_repos)" \
                                                                                    "  - path to a directory inside the vm2 repository working tree (if empty, the default is the current directory)" \
                                                                                    "  - the name of the variable to store the absolute path of the root of the Git repository containing the found directory" \
                                                                                    "  - the name of the variable to store the absolute path of the found directory"
    [[ ! -v 1 || -d $1 ]]                    || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 1, the repositories parent directory, to be an existing directory (provided '${1:-<none>}')."
    [[ ! -v 3 ]] || is_defined_variable "$3" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3, the name of a variable to store the absolute path of the root of the Git repository containing the found directory (provided '${3:-<none>}')."
    [[ ! -v 4 ]] || is_defined_variable "$4" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 4, the name of a variable to store the absolute path of the found directory (provided '${4:-<none>}')."

    exit_if_has_bugs

    local _repos
    local _dir_path

    _repos=$1
    _dir_path="${2:-"$(pwd)"}"

    trace "Searching for '${_dir_path:-<none>}' under '\$vm2_repos=${_repos:-<none>}'..."

    local _in_repo_dir=''
    local _dir=''
    local _repo_root=''
    local _found_dir=''
    local -i _rc="$success"

    # find a directory with the same sub-path under $vm2_repos and check if it is a git work tree root (if root_only is true)
    search_repo_dir "$_repos" "$_dir_path" _found_dir || _rc=$?
    if (( _rc == err_not_found )); then
        # we didn't find it under vm2_repos, let's search under $HOME - it will take a lot longer though...
        trace "Searching for '${_dir_path:-<none>}' under '\$HOME=$HOME'..."
        search_repo_dir "$HOME" "$_dir_path" _found_dir || _rc=$?
    fi

    # if rc is one of the fatal errors from the above searches - return
    is_in "$_rc" "$err_not_found" "$err_found_too_many" && return "$_rc"

    if (( _rc == success )); then
        # we found repo directory, find the root of the repository and check if it has CI configuration
        _in_repo_dir=$_found_dir
        root_working_tree "$_in_repo_dir" _repo_root || return "$err_invalid_repo"    # get the root of the repo working tree
        [[ -d "$_repo_root/.github/workflows" ]] || _rc="$err_repo_with_no_ci"        # check if the repository has CI configuration (is it initialized with setup-repo.sh)?
    elif (( _rc == err_not_git_directory )); then
        # the directory exists but is not a git repository
        _dir=$_found_dir
        # walk the path up until we find a CI configuration
        _rc="$err_dir_with_ci"
        while [[ ! -d "$_found_dir/.github/workflows" ]]; do
            _found_dir=$(dirname "$_found_dir")
            [[ $_found_dir == "$HOME" ]] && _rc="$err_dir_with_no_ci" && break
        done

        case "$_rc" in
            "$err_dir_with_ci" )
                # we found a CI configuration, return
                #   - the directory with the CI configuration as the repo root, but
                #   - the found directory as the resolved path and
                #   - with the error code indicating that it is not a git repository yet
                # the root can be initialized as a repository
                _in_repo_dir="$_dir"
                _repo_root="$_found_dir"
                ;;

            "$err_dir_with_no_ci" )
                # we didn't find CI configuration, return
                #   - the found directory as the repo root (it may not be a repository, but at least it is the closest we got to the provided path)
                #   - the found directory also as the resolved path and
                #   - with the error code indicating that it's a directory with no CI configuration
                _in_repo_dir="$_dir"
                _repo_root="$_dir"
                ;;

            * ) error "Unexpected error code '$_rc' caught in ${FUNCNAME[0]}() function."
                return "$_rc"
        esac
    else
        error "Unexpected error code '$_rc' returned from search_repo_dir() function."
        return "$_rc"
    fi

    local -n _repo_root_ref="$3"
    local -n _in_repo_dir_ref="$4"

    _repo_root_ref="$_repo_root"
    _in_repo_dir_ref="$_in_repo_dir"

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Resolves the path to the SoT (Source of Truth) shared content directory inside the vm2.Templates repository
#   (named by $vm2_sot_repo_name), expected to be located under $vm2_repos.
#
# @arg $1 string vm2_repos - the parent directory where all the vm2 repositories are cloned (required, non-empty, must be an
#   existing directory)
# @arg $2 string sot - the SoT directory name relative to the vm2.Templates repository (required, non-empty)
# @arg $3 string _repo_root_ref - the name of the variable to store the absolute path of the path to the SoT shared content
#   directory (required, non-empty)
#
# @exitcode success/positive=0: the SoT shared content directory is found at the expected location
# @exitcode err_not_directory=17: the SoT shared content directory does not exist at the expected conventional location
#   ('$vm2_repos/$vm2_sot_repo_name/templates/$sot/content')
#
# @stdout the absolute path to the SoT shared content directory
#
# @example
#   get_vm2_sot_path "$vm2_repos" "AddNewPackage" sot_path
#---------------------------------------------------------------------------------------------
function get_vm2_sot_path()
{
    (( $# == 3 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects three arguments (provided $#):" \
                                                                                    "  - the parent directory of all vm2 repositories" \
                                                                                    "  - the SoT directory name relative to the vm2.Templates repository" \
                                                                                    "  - the name of the variable to store the absolute path of the path to the SoT shared content directory"
    [[ ! -v 1 || -n $1 ]]                    || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the vm2 repositories parent directory, to be non-empty (provided '${1:-<none>}')."
    # if $1 is missing/empty it is already reported above, otherwise validate its value
    [[ ! -v 1 || -z $1 || -d $1 ]]           || bug -ec "$err_not_directory" "${FUNCNAME[0]}() requires argument 1 to be an existing directory (provided '${1:-<none>}')."
    [[ ! -v 2 || -n $2 ]]                    || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the SoT directory name, to be non-empty (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_defined_variable "$3" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3, the name of the variable to store the absolute path of the path to the SoT shared content directory, to be defined (provided '${3:-<none>}')."

    exit_if_has_bugs

    local _repos="$1"
    local _source="$2"

    local -n _vm2_sot="$3"

    _vm2_sot="$_repos/$vm2_sot_repo_name/templates/$_source/content"

    [[ -d "$_vm2_sot" ]] || {
        error -ec "$err_not_directory" "The SoT shared content directory is not found at the expected conventional location '$_vm2_sot' under the specified parent directory for the vm2 repositories '$_repos'. Please make sure it exists or correct the parameter/environment variable."
        return "$err_not_directory"
    }

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Get the absolute path to the root of all artifacts directories.
#
# @arg $1 string project - A path inside a repository (e.g. project file).
# @arg $2 nameref to a variable that contains the relative or absolute path to the artifacts
#   directory to store the artifacts directory:
#   - if it is an absolute path, it must be a path to an existing directory and it will be
#     returned as is
#   - if it is a relative path, the artifacts root will be resolved from this value, relative
#     to the root of the Git repository's working tree that contains the parameter 1.
#   The resolved absolute path of the artifacts directory will be returned back in this
#   variable.
#
# @exitcode success/positive=0: if the absolute path to the artifacts directory is successfully determined,
#   non-zero otherwise.
#---------------------------------------------------------------------------------------------
function get_artifacts_path()
{

    (( $# == 2 ))                            || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() expects two arguments (provided $#):" \
                                                                                    "  - a path inside a repository (e.g. project file)" \
                                                                                    "  - the name of a variable containing/receiving the artifacts directory path"
    [[ ! -v 1 ]] || [[ -e $1 ]]              || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, to exist, to be non-empty, and to be a valid path inside of the repository (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_defined_variable "$2" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 2, to be a non-empty path to the root of all artifacts, that is either existing and absolute, or maybe missing and relative to the Git repository's root of the working tree (argument 2: '${2:-<none>}')."

    exit_if_has_bugs

    local _path_in_repo=$1

    [[ -d $1 ]] || _path_in_repo="$(dirname "$_path_in_repo" 2>"$_ignore")"

    local _repo_root
    local -i _rc=$success

    root_working_tree "$_path_in_repo" _repo_root || {
        _rc=$?
        error -ec "$_rc" "Failed to resolve the root of the Git repository containing '$1'."
        return "$_rc"
    }

    local -n _artifacts_path="$2"

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    if [[ $_artifacts_path == /* ]]; then
        # if absolute, it must exist
        _artifacts_path="$(realpath -e "$_artifacts_path" 2>"$_ignore")" || {
            _rc=$err_not_found
            error -ec "$_rc" "Failed to resolve the absolute path of the artifacts directory '$_artifacts_path'."
        }
        return "$_rc"
    fi

    # relative to the repository root
    _artifacts_path="$(realpath -m "$_repo_root/$_artifacts_path" 2>"$_ignore")"
    return "$success"
}
