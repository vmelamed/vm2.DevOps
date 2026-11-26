# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x script_name
declare -x lib_dir

# vm2 error codes
declare -x success
declare -x err_missing_argument
declare -x err_too_many_arguments
declare -x err_unknown_argument
declare -x err_logic_error
declare -x err_dir_with_ci

# vm2 core lib constants
declare -x default_vm2_repos_path
declare -x default_default_branch
declare -x default_repo_owner
declare -x default_visibility
declare -x repo_visibilities
declare -x repo_visibilities_str
declare -x ci

# vm2 core lib variables
declare -x noise_sink

# script constants

# script arguments
declare -x vm2_repos=${VM2_REPOS:-$default_vm2_repos_path}
declare -x repo_owner=${ORGANIZATION:-$default_repo_owner}
declare -x repo_name=''
declare -x repo_path=''
declare -x repo=''
declare -x ci_yaml=''
declare -x default_branch=$default_default_branch
declare -x visibility=$default_visibility
declare -x main_protection_rs_name=''
declare -x description=''
declare -x use_ssh=true
declare -x use_https=false
declare -x audit=false
declare -x interactive_vars=false
declare -x interactive_secrets=false
declare -x purge_vars=false
declare -x purge_secrets=false
declare -x configure_local=true

declare -x branches=$default_default_branch

declare -xra arguments=(
    vm2_repos
    repo_owner
    repo_path
    repo_name
    default_branch
    visibility
    main_protection_rs_name
    description
    use_ssh
    use_https
    audit
    interactive_vars
    interactive_secrets
    purge_vars
    purge_secrets
    configure_local
)

#-----------------------------------------------------------------------------------------------
# @description Turns the command line of `setup-repo.sh` into the final script variables declared at the top of this
#   file. Only orchestrates the stages of the `get_arguments` pipeline (see CLAUDE.md), each a function of its own:
#   `parse_arguments`, `usage_if_requested`, `verify_environment`, `resolve_arguments`, `exit_if_has_errors` (the single
#   gate for both stages before it), and `dump_args`.
#
# Notes:
#   - This is a top-level CLI argument parser: it exits the process (through `usage` or `exit_if_has_errors`) on bad
#     input, or after printing the help, rather than returning an error code.
#
# @arg $@ string Command-line arguments passed to `setup-repo.sh`.
#
# @exitcode success=0: All arguments were parsed and resolved (the function returns; every failure exits the process).
#-----------------------------------------------------------------------------------------------
function get_arguments()
{
    parse_arguments "$@"
    usage_if_requested
    verify_environment
    resolve_arguments
    exit_if_has_errors
    dump_args
}

#-----------------------------------------------------------------------------------------------
# @description Maps the command-line tokens to the script variables. Pure: touches no files, no git, no network, so
#   e.g. a non-existent `--vm2-repos` directory is not an error here (`resolve_arguments` checks it). Common switches
#   (`-h`, `-v`, `-q`, `-x`, `-y`, etc.) are delegated to `get_common_arg` first. The only positional argument is the
#   project directory, `repo_path`.
#
# Notes:
#   - `--interactive|-i` sets both `interactive_vars` and `interactive_secrets`; `--purge|-p` sets both `purge_vars`
#     and `purge_secrets`. Each flag also has its own switch (`--interactive-vars|-iv`, `--interactive-secrets|-is`,
#     `--purge-vars|-pv`, `--purge-secrets|-ps`).
#   - `--ssh|-s` and `--https|-t` clear each other: the last one wins.
#   - `--current-branch|-cb` clears `branches`, so `resolve_arguments` does not require vm2.DevOps and vm2.Templates to
#     be on `main` (for testing only).
#
# @arg $@ string Command-line arguments passed to `setup-repo.sh`.
#
# @exitcode success=0: All tokens were parsed. A malformed command line (an unknown option, a missing option value, a
#   second positional argument) exits the process through `usage`.
#-----------------------------------------------------------------------------------------------
function parse_arguments()
{
    local _option
    local _option_set=false

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --vm2-repos )
                (( $# >= 1 ))                                                   || usage "Missing path after '$_option'." -ec "$err_missing_argument"
                vm2_repos="$1"; shift
                ;;

            --owner|-o )
                (( $# >= 1 ))                                                   || usage "Missing owner after '$_option'." -ec "$err_missing_argument"
                repo_owner="$1"; shift
                ;;

            --branch|-b )
                (( $# >= 1 ))                                                   || usage "Missing branch name after '$_option'." -ec "$err_missing_argument"
                default_branch="$1"; shift
                ;;

            --visibility )
                (( $# >= 1 ))                                                   || usage "Missing visibility after '$_option'." -ec "$err_missing_argument"
                visibility="$1"; shift
                ;;

            --ruleset-name|-rs )
                (( $# >= 1 ))                                                   || usage "Missing the name of the ruleset for protecting the default branch after '$_option'." -ec "$err_missing_argument"
                main_protection_rs_name="$1"; shift
                ;;

            --description )
                (( $# >= 1 ))                                                   || usage "Missing description after '$_option'." -ec "$err_missing_argument"
                description="$1"; shift
                ;;

            --ssh|-s )
                use_ssh=true
                use_https=false
                ;;

            --https|-t )
                use_ssh=false
                use_https=true
                ;;

            --audit|-a )
                audit=true
                ;;

            --current-branch|-cb )
                branches=''
                ;;

            --interactive-vars|-iv )
                interactive_vars=true
                ;;

            --interactive-secrets|-is )
                interactive_secrets=true
                ;;

            --interactive|-i )
                interactive_vars=true
                interactive_secrets=true
                ;;

            --purge-vars|-pv )
                purge_vars=true
                ;;

            --purge-secrets|-ps )
                purge_secrets=true
                ;;

            --purge|-p )
                purge_vars=true
                purge_secrets=true
                ;;

            --skip-local-config|-slc )
                configure_local=false
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." -ec "$err_logic_error"
                ;;

            -*) usage "Unknown argument: $_option" -ec "$err_unknown_argument"
                ;;

            * ) ! $_option_set                                                  || usage "Too many positional arguments (project directory or repository name): $_option" -ec "$err_too_many_arguments"
                repo_path="$_option"
                _option_set=true
                ;;
        esac
    done

    return "$success"
}

#-----------------------------------------------------------------------------------------------
# @description Verifies the argument-independent preconditions: `git`, `gh` (installed, recent enough, and
#   authenticated), `jq`, and `yq`. Reports every missing tool with `error` and returns; `exit_if_has_errors` in
#   `get_arguments` ends the run.
#
# @exitcode success=0: Always (the failures are counted by `error`).
#-----------------------------------------------------------------------------------------------
function verify_environment()
{
    verify_git                                                                  || true
    verify_gh                                                                   || true
    verify_jq                                                                   || true
    verify_yq                                                                   || true

    return "$success"
}

#-----------------------------------------------------------------------------------------------
# @description Validates, canonicalizes, and derives the arguments, then freezes the ones that cannot change later:
#   - resolves `vm2_repos` (and checks that vm2.DevOps and vm2.Templates are on `$branches`, unless it is empty);
#   - resolves the project directory `repo_path` to the root of its Git working tree, or, if it is not a Git repository
#     yet, to the nearest ancestor with a `.github/workflows` directory (with an `info`: the repository will be
#     initialized);
#   - derives `repo_name` (the root's base name), `repo` (`<owner>/<name>`), and `ci_yaml`, which MUST exist;
#   - validates the owner, the description (if given), the default branch, and the visibility (canonicalized to lower
#     case);
#   - rejects `--audit` combined with `--interactive*` or `--purge*`: an audit is read-only.
#
# Notes:
#   - Two circuit breakers exit the process at once, because nothing after them can be checked meaningfully: an
#     unresolvable `vm2_repos`, and a target directory that cannot be resolved to a repository root (or to a directory
#     with a CI configuration that can become one).
#   - `repo_owner`, `repo_path`, `repo_name`, `description`, `default_branch`, `main_protection_rs_name`, `use_ssh`,
#     and `use_https` stay writable: `setup-repo.sh` adjusts them to what Git and GitHub report, or asks the user.
#
# @exitcode success=0: Always, unless a circuit breaker exits the process: every other failure is reported with
#   `error`, and `exit_if_has_errors` in `get_arguments` ends the run.
#-----------------------------------------------------------------------------------------------
function resolve_arguments()
{
    local -i _rc=$success

    is_valid_gh_repo_owner "$repo_owner"                                        || true

    resolve_vm2_repos vm2_repos "$branches" "$branches"                         || exit_with_error "Failed to resolve the parent directory of all vm2 repositories (usually \$VM2_REPOS)." -ec $?

    local _resolved
    resolve_repo_root "$vm2_repos" "$repo_path" _resolved void                  || _rc=$?
    case "$_rc" in
        "$success" )
            ;; # all good!

        "$err_dir_with_ci" )
            # OK, needs work
            info "'$repo_path' is not a Git repository, however there is '$_resolved/.github/workflows/CI.yaml'." \
                 "A new Git repository will be initialized in '$_resolved'."
            ;;

        * )                                                                     exit_with_error "Failed to resolve the path of the target repository '$repo_path'." -ec "$_rc"
            ;;
    esac

    repo_path=$_resolved
    repo_name=$(basename "$repo_path")
    is_valid_gh_repo_name "$repo_name"                                          || true

    repo="$repo_owner/$repo_name"

    ci_yaml="$repo_path/.github/workflows/CI.yaml"
    trace "ci_yaml='$ci_yaml' from \$repo_path"
    [[ -s "$ci_yaml" ]]                                                         || with_error _rc "$err_logic_error" "The specified path '$repo_path' is not a valid project/repository root (missing .github/workflows/CI.yaml)." \
                                                                                                                     "Specify a valid path to the root of the project/repository as a positional parameter or use 'dotnet new vm2pkg <name>' to create a valid directory."

    [[ -z $description ]] || is_valid_gh_repo_description "$description"        || true

    is_valid_branch_name "$default_branch"                                      || true

    visibility="${visibility,,}"
    is_valid_gh_visibility "$visibility"                                        || true

    # shellcheck disable=SC2015 # Info: Note that A && B || C is not if-then-else. C may run when A is true.
    if $audit; then
        ! $interactive_secrets && ! $interactive_vars                           || error "Secrets and variables cannot be interactively set during audit." \
                                                                                         "Remove the '--interactive-secrets' and '--interactive-vars' options when running the script with '--audit'." \
                                                                                         -ec "$err_logic_error"
        ! $purge_secrets && ! $purge_vars                                       || error "Secrets and variables cannot be purged during audit." \
                                                                                         "Remove the '--purge-secrets' and '--purge-vars' options when running the script with '--audit'." \
                                                                                         -ec "$err_logic_error"
    fi

    readonly vm2_repos
    readonly ci_yaml
    readonly visibility
    readonly audit
    readonly interactive_vars
    readonly interactive_secrets
    readonly purge_vars
    readonly purge_secrets
    readonly configure_local

    # these arguments may change later: manually or read from git/GitHub:
    # readonly repo_owner
    # readonly repo_path
    # readonly repo_name
    # readonly description
    # readonly default_branch
    # readonly main_protection_rs_name
    # readonly use_ssh
    # readonly use_https

    return "$success"
}

#-----------------------------------------------------------------------------------------------
# @description Dumps the script arguments (the variables listed in `arguments`) and the core state, as a table, when
#   running in CI or in verbose mode; otherwise does nothing. The last stage of the `get_arguments` pipeline.
#
# @arg $@ string Optional additional arguments forwarded to `dump_vars` (e.g. more variable names or `--header`s).
#
# @exitcode success=0: Always (the exit code of `dump_vars`).
#-----------------------------------------------------------------------------------------------
# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        "${arguments[@]}"

        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
