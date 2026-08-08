# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines functions for working with Git repositories in the vm2 environment.
# It includes functions for resolving the vm2_repos directory and checking the state of Git repositories.
# It is assumed that the vm2 repositories are cloned under a single parent directory, that can be specified by
# 1. a command line argument, or
# 2. the environment variable $VM2_REPOS or
# 3. the parent directory of the repo root of this script:
#    1) if this script is in $vm2_repos/vm2.DevOps/scripts/bash/lib
#    2) the repo root should be $vm2_repos/vm2.DevOps
#    3) the parent directory of the repo root should be $vm2_repos
# 4. the hard-coded default value $HOME/repos/vm2
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_GIT_VM2_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_GIT_VM2_SH_LOADED=1

declare -rx script_dir
declare -rx lib_dir
declare -x _ignore

declare -rxi success
declare -rxi failure

declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value
declare -rxi err_not_found
declare -rxi err_not_file
declare -rxi err_not_directory
declare -rxi err_not_git_root
declare -rxi err_behind_latest_stable_tag
declare -rxi err_invalid_repo
declare -rxi err_invalid_repo
declare -rxi err_found_too_many
declare -rxi err_repo_with_no_ci
declare -rxi err_dir_with_ci
declare -rxi err_dir_with_no_ci
declare -rxi err_not_git_directory
declare -rxi err_logic_error
declare -rxi err_not_on_current_commit

declare -xr vm2_devops_repo_name
declare -xr vm2_sot_repo_name

declare -a vm2_repos_instructions=(
    "Please, create a single directory for all vm2.* repositories. "
    "Clone the vm2.DevOps, vm2.Templates, and all vm2.* repositories that you work on into it."
    "Then, either:"
    "  - provide the path to that directory as an argument to the script using the '--vm2-repos <path>' option, or"
    "  - set the environment variable \$VM2_REPOS to the path of that directory, or"
    "  - start the script from the cloned vm2.DevOps repository in that directory."
)

#-------------------------------------------------------------------------------
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
#   parent directory of vm2.DevOps's repository root)
#
# @exitcode 0 ($success) the vm2_repos directory was successfully resolved and validated
# @exitcode 17 ($err_not_directory) the parameter, $VM2_REPOS, or the resolved default is not a valid, existing directory
# @exitcode 2 ($err_invalid_arguments) an invalid number of arguments was provided
# @exitcode N propagated from validate_repo_root (e.g. $err_not_found, $err_repo_with_no_ci, $err_behind_latest_stable_tag)
#   if vm2.DevOps or vm2.Templates fail validation under the resolved directory
#
# @stdout the absolute path to the vm2_repos directory
#
# @example
#   repos=$(resolve_vm2_repos "$VM2_REPOS")
#-------------------------------------------------------------------------------
# shellcheck disable=SC2120
function resolve_vm2_repos()
{
    local -i _rc="$success"

    (( $# <= 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() takes 1 optional argument ($# provided): the directory that is a parent to all vm2 repositories."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    # try to resolve vm2 from the
    #   1) argument (usually from a command line option --vm2-repos)
    #   2) environment variable $VM2_REPOS
    #   3) the lib/ directory
    # in this order of preference:
    local _source=""
    local _repos="${1:-${VM2_REPOS:-${HOME}/repos/vm2_repos}}"
    if [[ -n "$_repos" && -d "$_repos" ]]; then
        trace "vm2_repos='$_repos' from argument ${1:-'<none>'}, or env. var. '\$VM2_REPOS=${VM2_REPOS:-}', or default literal ${HOME}/repos/vm2_repos."
    elif [[ -d "$(get_devops_parent)" ]]; then
        _repos="$(get_devops_parent)"
        trace "vm2_repos='$_repos' from the location of vm2.DevOps."
    else
        error -sd 3 -ec "$err_not_directory" "Cannot resolve the parent directory of the vm2 repositories." "${vm2_repos_instructions[@]}"
        return "$err_not_directory"
    fi

    # ensure $vm2_repos is an existing, absolute path:
    _repos=$(realpath -e "$_repos" 2> "$_ignore") || {
        error -sd 3 -ec "$err_not_directory" "The resolved parent directory for the vm2 repositories '$_repos' does not exist or is not a directory." "${vm2_repos_instructions[@]}"
        return "$err_not_directory"
    }

    # validate that $vm2_repos is the parent directory of the git repository vm2.DevOps;
    # it is on the main branch;
    # and it is at or ahead of the latest stable tag:
    _rc="$success"
    validate_repo_root "$_repos" "$vm2_devops_repo_name" "main" || _rc=$?
    (( _rc == err_behind_latest_stable_tag )) &&
        error -ec "$err_logic_error" "The main branch of the repository '$vm2_devops_repo_name' is behind the latest stable tag." \
                                     "Please update it to the latest version of the main branch."

    # validate that $vm2_repos is the parent directory of the git repository vm2.Templates;
    # it is on the main branch;
    # and it is at or ahead of the latest stable tag:
    validate_repo_root "$_repos" "$vm2_sot_repo_name" "main" || _rc=$?
    (( _rc == err_behind_latest_stable_tag )) &&
        error -ec "$err_logic_error" "The main branch of the repository '$vm2_sot_repo_name' is behind the latest stable tag." \
                                     "Please update it to the latest version of the main branch."

    echo "$_repos"
    return "$_rc"
}

#-------------------------------------------------------------------------------
# @description Validates that:
#   1) the specified directory (or repository name resolved under $vm2_repos) exists,
#   2) it is the root of a Git repository working tree,
#   3) it has GitHub Actions workflows in the .github/workflows directory,
#   4) it is on the specified branch (or the currently checked-out branch if none is specified), and
#   5) it is at or ahead of the latest stable tag of that branch.
#
# @arg $1 string vm2_repos - the parent directory of all vm2 repositories, where the repository named by $2 can also be
#   located if it is given by name only. MUST already be resolved via `$(resolve_vm2_repos)`.
# @arg $2 string repo_name - repository name, or an absolute or relative path to the repository, e.g. "vm2.MyRepo" or
#   "./my_repos/vm2_packages/vm2.MyRepo".
# @arg $3 string branch - the branch to check against the latest stable tag (optional, default: the currently checked-out
#   branch)
#
# @exitcode 0 ($success) the repository directory exists and meets all the criteria above
# @exitcode 2 ($err_invalid_arguments) invalid number of arguments
# @exitcode 9 ($err_not_found) could not find the repository directory from $repo_name and $vm2_repos
# @exitcode 80 ($err_not_git_directory) the resolved path is not a Git repository
# @exitcode 81 ($err_not_git_root) the resolved path exists and is inside a Git repository, but is not the working tree root
# @exitcode 85 ($err_repo_with_no_ci) the repository has no GitHub Actions workflows in '$repo_path/.github/workflows'
# @exitcode 84 ($err_invalid_branch) the repository is not on the expected branch (when $3 is given)
# @exitcode 89 ($err_not_on_current_commit) the repository exists and is on the expected branch, but is not at or ahead of
#   the latest stable tag
#
# @stdout the absolute path to the working tree root of the resolved repository
#
# @example
#   validate_repo_root "$vm2_repos" "vm2.Glob"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2154 # variable is referenced but not assigned.
function validate_repo_root()
{
    local -i _rc="$success"

    (( $# == 2 || $# == 3 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires two or three arguments (provided $#):" \
                              "  - the parent directory of all vm2 repositories where the repository can be located as well (e.g. \$VM2_REPOS or \$(get_devops_parent))" \
                              "  - repository name, or, the absolute or relative path to the repository, e.g. 'vm2.MyRepo' or './my_repos/vm2_packages/vm2.MyRepo'" \
                              "  - the branch to check against the latest stable tag (optional, default: the currently checked out branch)"
    }
    [[ -v 1 && -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the vm2 repositories parent, to be an existing directory (provided '${1-<missing>}')."
    }
    [[ -v 2 && -n $2 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the repository name or path, to be non-empty (provided '${2-<missing>}')."
    }
    [[ ! -v 3 || -z $3 ]] || git check-ref-format --branch "$3" &> "$_ignore" || {
        _rc="$err_invalid_branch"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 3 to be a valid Git branch name (provided '${3-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _repos=$1
    local _repo=$2
    local _branch="$3"
    local _path # the full repo path

    # try to resolve repo_path relative to $repos

    # 1) the specified directory exists
    _path=$(realpath -e "$_repos/${_repo#/}" 2> "$_ignore") ||
    # try to resolve the repository path from the parameter alone
    # i.e., the current working directory or the absolute path provided as the first argument
    _path=$(realpath -e "$_repo" 2> "$_ignore") ||
    # couldn't resolve the repo path - error and exit
    {
       error -sd 3 -ec "$err_not_found" "Could not find the path '$_repo' neither in the current working directory, nor in '$_repos'."
       return "$err_not_found"
    }

    trace "repo_path='$_path' from parameter, \$(pwd), or vm2_repos with realpath"

    # 2) it is a root of the working directory of the git repository
    r=$(root_working_tree "$_path" 2> "$_ignore") || {
        _rc=$?
        error -sd 3 -ec "$err_not_git_directory" "The '$_repo' repository at '$_path' is not a git repository. $(error_message "$_rc")."
        return "$err_not_git_directory"
    }
    [[ "$_path" == "$r" ]] || {
        error -sd 3 -ec "$err_not_git_root" "The $_repo repository at '$_path' is not the root of the git repository working tree."
        return "$err_not_git_root"
    }

    # 3) it has GitHub Actions workflows in the .github/workflows directory
    [[ -d "$_path/.github/workflows" ]] || {
        error -sd 3 -ec "$err_repo_with_no_ci" "The '$_repo' repository does not have GitHub Actions workflows in '$_path/.github/workflows'."
        return "$err_repo_with_no_ci"
    }

    # 4) it is on the specified branch (or the currently checked out branch if not specified)
    if [[ -z "$_branch" ]]; then
        _branch=$(git -C "$_path" branch --show-current 2>"$_ignore")
    else
        [[ "$_branch" == $(git -C "$_path" branch --show-current 2>"$_ignore") ]] || {
            error -sd 3 -ec "$err_invalid_branch" "The '$_repo' repository at '$_path' is not on the expected branch '$_branch'."
            return "$err_invalid_branch"
        }
    fi

    # 5) it is at or ahead of the latest stable tag of the specified branch.
    ensure_fresh_git_state "$_path" "$_branch" || return $?

    is_on_or_after_latest_stable_tag "$_path" &&
        return "$success" ||
        return "$err_behind_latest_stable_tag"
}

#-------------------------------------------------------------------------------
# @description Internal helper used by resolve_repo_root. Searches for a directory with the given name (or relative
# path) under a specified parent directory, skipping common noise directories (.git, node_modules, .cache, bin, obj,
# TestResults, etc.) during the search.
#
# @arg $1 string start_from - parent directory under which to search for the specified directory
# @arg $2 string look_for - directory name or relative path to search for
#
# @exitcode 0 ($success) exactly one matching directory is found, and it is inside a Git repository
# @exitcode 80 ($err_not_git_directory) exactly one matching directory is found, but it is not inside a Git repository
# @exitcode 10 ($err_found_too_many) multiple matching directories are found
# @exitcode 9 ($err_not_found) no matching directory is found
#
# @stdout the absolute path of the found directory
#
# @example
#   dir=$(search_repo_dir <start-from> <directory-name>)
#-------------------------------------------------------------------------------
function search_repo_dir()
{
    local -i _rc="$success"

    (( $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly two arguments (provided $#): the search root and the directory name or relative path to find."
    }
    [[ -v 1 && -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the search root, to be an existing directory (provided '${1-<missing>}')."
    }
    [[ -v 2 && -n $2 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the directory name or relative path to find, to be non-empty (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _start_from=$1
    local _look_for=$2

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

    (( _found_repo_dirs + _found_dirs == 0 ))                               && return "$err_not_found"
    (( _found_repo_dirs == 1 ))                     && echo "$_in_repo_dir" && return "$success"
    (( _found_repo_dirs == 0 && _found_dirs == 1 )) && echo "$_dir"         && return "$err_not_git_directory"

    return "$err_found_too_many"
}

#-------------------------------------------------------------------------------
# @description Finds the root directory of a Git repository working tree by searching for a directory with the given
#   name (or relative path) under a specified parent directory (expected to be under $VM2_REPOS, falling back to a search
#   under $HOME if not found there). The target directory does not need to be a Git repository. If it is not, the
#   resolved "root" is instead the nearest parent directory containing a '.github/workflows' directory, or the found
#   directory itself if no such parent is found.
#   Note: This method uses `find` and parent directory traversal, so it is slow!
#   Prefer functions like `root_working_tree` that operate directly on known Git repository directories, or `$initial_cwd`.
#
# @arg $1 string vm2_repos - parent directory under which to search for the specified directory (resolved vm2_repos)
# @arg $2 string dir_path - directory name or relative path to search for (optional, default: the current directory)
#
# @exitcode 0 ($success) exactly one matching directory with a Git repository is found and it has CI configuration
# @exitcode 2 ($err_invalid_arguments) invalid number of arguments
# @exitcode 83 ($err_invalid_repo) the matching directory's Git working-tree root could not be resolved
# @exitcode 85 ($err_repo_with_no_ci) exactly one matching Git repository directory is found, but it has no CI configuration
# @exitcode 80 ($err_not_git_directory) exactly one matching directory with CI configuration is found via a parent walk, but
#   the original match is not a Git repository
# @exitcode 87 ($err_dir_with_no_ci) exactly one matching directory is found, but it is not a Git repository and no
#   ancestor up to $HOME has CI configuration
# @exitcode 10 ($err_found_too_many) multiple matching directories are found (fatal)
# @exitcode 9 ($err_not_found) no matching directory was found, under either $vm2_repos or $HOME (fatal)
#
# @stdout two lines:
#   1) the absolute path of the root of the Git repository containing the found directory (or, if the found directory is
#      not a Git repository, the nearest ancestor with CI configuration -- or the found directory itself if none exists)
#   2) the absolute path of the found directory
#
# @example
#   local output
#   output=$(resolve_repo_root "$vm2_repos" "$repo_path" 2>"$_ignore") || rc=$?
#   (( rc == success || rc == err_repo_with_no_ci || rc == err_not_git_directory || rc == err_dir_with_no_ci )) || exit "$rc"
#   { read -r root; read -r resolved_dir; } < <(resolve_repo_root "$vm2_repos" "$repo_path")
#-------------------------------------------------------------------------------
function resolve_repo_root()
{
    local -i _rc="$success"

    (( $# == 1 || $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires 1 or 2 arguments ($# provided): " \
                "  1) the parent directory under which to search for the vm2 repository (resolved vm2_repos)" \
                "  2) path to a directory inside the vm2 repository working tree (optional, default - the current directory)."
    }
    [[ -v 1 && -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the repositories parent directory, to be an existing directory (provided '${1-<missing>}')."
    }
    [[ ! -v 2 || -n $2 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 2, the directory path to resolve, to be non-empty when provided (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _repos
    local _dir_path

    _repos=$1
    _dir_path="${2:-"$(pwd)"}"

    trace "Searching for '$_dir_path' under '\$vm2_repos=$_repos'..."

    local _in_repo_dir=""
    local _dir=""
    local _repo_root=""
    local _d

    # find a directory with the same sub-path under $vm2_repos and check if it is a git work tree root (if root_only is true)
    _d=$(search_repo_dir "$_repos" "$_dir_path") || _rc=$?
    if (( _rc == err_not_found )); then
        # we didn't find it under vm2_repos, let's search under $HOME - it will take a lot longer though...
        trace "Searching for '$_dir_path' under '\$HOME=$HOME'..."
        _d=$(search_repo_dir "$HOME" "$_dir_path")
        _rc=$?
    fi

    # if rc is one of the fatal errors from the above searches - return
    is_in "$_rc" "$err_not_found" "$err_found_too_many" && return "$_rc"

    if (( _rc == success )); then
        # we found repo directory, find the root of the repository and check if it has CI configuration
        _in_repo_dir=$_d
        _repo_root=$(root_working_tree "$_in_repo_dir") || return "$err_invalid_repo"    # get the root of the repo working tree
        [[ -d "$_repo_root/.github/workflows" ]] || _rc="$err_repo_with_no_ci"        # check if the repository has CI configuration (is it initialized with setup-repo.sh)?
    elif (( _rc == err_not_git_directory )); then
        # the directory exists but is not a git repository
        _dir=$_d
        # walk the path up until we find a CI configuration
        _rc="$err_dir_with_ci"
        while [[ ! -d "$_d/.github/workflows" ]]; do
            _d=$(dirname "$_d")
            [[ $_d == "$HOME" ]] && _rc="$err_dir_with_no_ci" && break
        done

        case "$_rc" in
            "$err_dir_with_ci" )
                # we found a CI configuration, return
                #   - the directory with the CI configuration as the repo root, but
                #   - the found directory as the resolved path and
                #   - with the error code indicating that it is not a git repository yet
                # the root can be initialized as a repository
                _in_repo_dir="$_dir"
                _repo_root="$_d"
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

    echo "$_repo_root"
    echo "$_in_repo_dir"

    return "$_rc"
}

#-------------------------------------------------------------------------------
# @description Resolves the path to the SoT (Source of Truth) shared content directory inside the vm2.Templates
# repository (named by $vm2_sot_repo_name), expected to be located under $vm2_repos.
#
# @arg $1 string vm2_repos - the parent directory where all the vm2 repositories are cloned (required, non-empty,
#   must be an existing directory)
# @arg $2 string sot - the SoT directory name relative to the vm2.Templates repository (required, non-empty)
#
# @exitcode 0 ($success) the SoT shared content directory is found at the expected location
# @exitcode 2 ($err_invalid_arguments) wrong argument count, an empty argument, or $1 is not an existing directory
# @exitcode 17 ($err_not_directory) the SoT shared content directory does not exist at the expected conventional location
#   ('$vm2_repos/$vm2_sot_repo_name/templates/$sot/content')
#
# @stdout the absolute path to the SoT shared content directory
#
# @example
#   shared=$(get_vm2_sot_path "$vm2_repos" "AddNewPackage")
#-------------------------------------------------------------------------------
function get_vm2_sot_path()
{
    local -i _rc="$success"

    (( $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" \
                "${FUNCNAME[0]}() expects two arguments (provided $#):" \
                "  1) the parent directory of all vm2 repositories" \
                "  2) the SoT directory name relative to the vm2.Templates repository."
    }

    [[ -v 1 && -n $1 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the vm2 repositories parent directory, to be non-empty (provided '${1-<missing>}')."
    }
    [[ -v 1 && -d $1 ]] || {
        _rc="$err_not_directory"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to be an existing directory (provided '${1-<missing>}')."
    }
    [[ -v 2 && -n $2 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2, the SoT directory name, to be non-empty (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _repos="$1"
    local _source="$2"

    local _vm2_sot="$_repos/$vm2_sot_repo_name/templates/$_source/content"

    [[ -d "$_vm2_sot" ]] || {
        error -sd 3 -ec "$err_not_directory" "The SoT shared content directory is not found at the expected conventional location '$_vm2_sot' under the specified parent directory for the vm2 repositories '$_repos'. Please make sure it exists or correct the parameter/environment variable."
        return "$err_not_directory"
    }

    echo "$_vm2_sot"
    return "$success"
}
