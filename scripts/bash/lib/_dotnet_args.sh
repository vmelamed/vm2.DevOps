# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_DOTNET_ARGS_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DOTNET_ARGS_SH_LOADED=1

# reference error codes defined in the core library
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_missing_argument
declare -xri err_too_many_arguments
declare -xri err_unknown_argument

declare -xr ci

#=============================================================================================
# Define default, constant values whose names and roles are shared across vm2.DevOps scripts.
# They are usually set from CLI arguments, environment variables, or defaults.
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description The default value for the `MinVerTagPrefix` MSBuild property. It specifies the
#   prefix used in Git tags to indicate a version when using MinVer. For example, `v1.2.3`.
#---------------------------------------------------------------------------------------------
declare -xr default_minver_tag_prefix='v'

#---------------------------------------------------------------------------------------------
# @description The default value for the `MinVerPrereleaseIdentifiers` MSBuild property. It
#   specifies the default pre-release identifiers for SemVer when using MinVer. For example,
#   `v1.2.3-preview.2.3`.
#---------------------------------------------------------------------------------------------
declare -xr default_minver_prerelease_id="preview.0"

#---------------------------------------------------------------------------------------------
# @description The default owner of the GitHub repository.
#---------------------------------------------------------------------------------------------
declare -xr default_repo_owner="vmelamed"

# reference variables common for most vm2.DevOps scripts that are
# set usually from CLI arguments (below), environment variables, or defaults
# consider the following variables a contract for the names of the named options acquired by
# get_common_gh_action_arg
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-$default_minver_tag_prefix}                     # from GitHub Actions vars (MINVERTAGPREFIX)
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-}                         # from GitHub Actions vars (MINVERDEFAULTPRERELEASEIDENTIFIERS); may be empty for release, so do not put here $default_minver_prerelease_id. The value must come from CLI.
declare -x gh_nuget_username=${GH_ACTOR:-}                                                      # from GitHub Actions actor   github.actor -> GH_ACTOR
declare -x gh_nuget_password=${GH_TOKEN:-}                                                      # from GitHub Actions secrets github.token -> GH_TOKEN
declare -x configuration=${CONFIGURATION:-}                                                     # from Directory.Build.props
declare -x framework=${FRAMEWORK:-}                                                             # from Directory.Build.props
declare -x runtime=${RUNTIME:-}                                                                 # from Directory.Build.props
declare -x artifacts=${ARTIFACTS_PATH:-}                                                        # from Directory.Build.props

# for use in args_to_github_output() as "${common_dotnet_vars[@]}"
declare -xra common_dotnet_args_to_output=(
    preprocessor_symbols
    minver_tag_prefix
    minver_prerelease_id
    configuration
    framework
    runtime
    artifacts
)

#---------------------------------------------------------------------------------------------
# @description Processes one github-scripts-common command-line (`--define`,
#   `--configuration`/`-c`, `--framework`, `--runtime`, `--artifacts-path`, `--minver-tag-prefix`,
#   `--minver-prerelease-id`, `--nuget-username`, `--nuget-password`) argument and its value.
#   Only `--configuration` has a short form (`-c`); every other common option is long-form only,
#   to keep single letters free for callers to use for their own options without colliding with
#   this shared set. Calling scripts should ensure that there are no collisions with `-c` or any
#   of the long option names above. For example, they may have a first matching expression case
#   like:
#   `-c|--define|--configuration|--framework|--runtime|--artifacts-path|--minver-tag-prefix|--minver-prerelease-id|--nuget-username|--nuget-password ) ;;`
#   to satisfy this requirement, as they may no longer use any of these as their own option.
#
# Notes:
#   - Calls internally the `get_common_arg` from the lib, so the callers do not need to call
#     it. In turn it invokes the common setting functions `set_verbose`, `set_quiet`,
#     `set_trace_enabled`, `set_dry_run`, `set_table_format` for the common CLI arguments like
#     `--verbose`, etc.
#   - Sets the values of variables with names: `preprocessor_symbols`, `configuration`,
#     `framework`, `runtime`, `artifacts`, `minver_tag_prefix`, `minver_prerelease_id`,
#     `gh_nuget_username`, and `gh_nuget_password`.
#
# @arg $1 string The next command-line argument to process, e.g. `"--configuration"`.
# @arg $2 string The value of the next command-line argument, e.g. `"Release"`.
#
# @exitcode success/positive=0: The argument was a recognized common dotnet argument.
# @exitcode failure/negative=1: The argument was not a common dotnet argument.
#
# @example
#   for arg in "$@"; do
#     get_common_arg "$arg" && continue
#     # handle custom arguments
#   done
#---------------------------------------------------------------------------------------------
function get_common_dotnet_arg()
{
    (( $# == 2 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires two arguments ($# provided):" \
                                                        "  - the command-line option identifier" \
                                                        "  - the command-line option value"

    exit_if_has_bugs

    local _rc="$success"

    case "${1,,}" in
            # do not use the common options - they should be processed by get_common_arg:
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown ) ;;

            # get the values of the variables common for many vm2.DevOps scripts,
            --define                   ) [[ -n $2 ]] && preprocessor_symbols=$2   || _rc="$err_missing_argument" ;;
            --minver-tag-prefix        ) [[ -n $2 ]] && minver_tag_prefix="$2"    || _rc="$err_missing_argument" ;;
            --minver-prerelease-id     ) [[ -n $2 ]] && minver_prerelease_id="$2" || _rc="$err_missing_argument" ;;
            --nuget-username           ) [[ -n $2 ]] && gh_nuget_username="$2"    || _rc="$err_missing_argument" ;;
            --nuget-password           ) [[ -n $2 ]] && gh_nuget_password="$2"    || _rc="$err_missing_argument" ;;
            --configuration|-c         ) [[ -n $2 ]] && configuration=$2          || _rc="$err_missing_argument" ;;
            --framework                ) [[ -n $2 ]] && framework="$2"            || _rc="$err_missing_argument" ;;
            --runtime                  ) [[ -n $2 ]] && runtime="$2"              || _rc="$err_missing_argument" ;;
            --artifacts-path           ) [[ -n $2 ]] && artifacts=$2              || _rc="$err_missing_argument" ;;
            *                          ) return "$negative" ;;
    esac

    (( _rc == "$success" )) || usage -ec "$_rc" "The value for the argument '$1' is missing."

    return "$positive" # it was a common argument and was processed
}

#---------------------------------------------------------------------------------------------
# @description
#   Sanitizes and validates the common dotnet arguments.
#   This function should be called after all common dotnet arguments have been parsed.
#
# @arg $1 string A path to a project file (build, test, etc.) from the list of projects. This
#   is used to determine the artifacts path if it is not already set.
#
# @exitcode success/positive=0: The common dotnet arguments were sanitized and validated
#   successfully.
# @exitcode err_argument_value=4: The GitHub NuGet username/password pairing is invalid (one
#   is present without the other).
#
# @example
#   sanitize_common_dotnet_args "$build_projects"
#---------------------------------------------------------------------------------------------
function sanitize_common_dotnet_args()
{
    local -i _validation_rc="$success"

    (( $# == 1 )) || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument ($# provided):" \
                                                        "  - a path to a project file (build, test, etc.)"

    exit_if_has_bugs

    validate_preprocessor_symbols preprocessor_symbols                        || true
    validate_semverTagComponents "$minver_tag_prefix" "$minver_prerelease_id" || true
    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ -v gh_nuget_username ]] && {
        is_safe_input "$gh_nuget_username"                                    || true
        if [[ -n $gh_nuget_username ]]; then
            [[ -v gh_nuget_password && -n $gh_nuget_password ]] || {
                _validation_rc=$err_argument_value
                error -ec "$_validation_rc" "If the GitHub username is present, then the GitHub password also must be present and not empty."
            }
        else
            [[ ! -v gh_nuget_password || -z $gh_nuget_password ]] || {
                _validation_rc=$err_argument_value
                error -ec "$_validation_rc" "If the GitHub username is not present or empty, then the GitHub password also must be either not present or empty."
            }
        fi
    } || {
        [[ ! -v gh_nuget_password || -z $gh_nuget_password ]] || {
            _validation_rc=$err_argument_value
            error -ec "$_validation_rc" "If the GitHub username is not present or empty, then the GitHub password also must be either not present or empty."
        }
    }

    is_safe_configuration "$configuration"                                    || true
    is_safe_framework "$framework"                                            || true
    is_safe_runtime "$runtime"                                                || true
    # $artifacts is always resolved to a concrete, absolute path here -- this is a documented
    # contract (see --artifacts-path's own help text above: "...or the default 'artifacts'"),
    # and build.sh/pack.sh/run-tests.sh/run-benchmarks.sh genuinely need a concrete, resolved
    # path for their own filesystem bookkeeping (locating coverage files, archiving output,
    # etc.), independent of whether that value is also ever passed to `dotnet` as an explicit
    # -property:ArtifactsPath= override. (validate-input.sh, the one caller that doesn't want
    # that override forced downstream, never actually forwards this resolved value to any
    # dotnet invocation in the first place, so there's nothing to protect there.)
    [[ -z $artifacts ]] || is_safe_valid_path "$artifacts"                    || true
    is_safe_path "$1" && get_artifacts_path "$1" artifacts                    || true

    # freeze the common dotnet arguments -- `readonly` (a POSIX special builtin), not `declare
    # -r`, is required here: this runs inside a function body, and `declare -r` without `-g`
    # only freezes a function-local shadow that is discarded when the function returns, leaving
    # the real global variables unprotected. `readonly` has no such scoping quirk -- it always
    # freezes the actual global. The variables are already exported from their original
    # top-level declaration, so `readonly` alone (no `-x`) is sufficient here.
    readonly preprocessor_symbols
    readonly minver_tag_prefix
    readonly minver_prerelease_id
    readonly gh_nuget_username
    readonly gh_nuget_password
    readonly configuration
    readonly framework
    readonly runtime
    readonly artifacts

    return "$_validation_rc"
}

#---------------------------------------------------------------------------------------------
# @description Outputs the common dotnet arguments (`preprocessor_symbols`, `configuration`,
#   `framework`, `runtime`, `artifacts`, `minver_tag_prefix`, `minver_prerelease_id`) as
#   "key=value" pairs, via `args_to_github_output`.
#
# @noargs
#
# @stdout and $GITHUB_OUTPUT (if in GH actions) "key=value" for each common dotnet variable.
#
# @example
#   common_dotnet_to_output
#---------------------------------------------------------------------------------------------
function common_dotnet_to_output()
{
    args_to_github_output "${common_dotnet_args_to_output[@]}"
}

declare -xr common_dotnet_parameters="\
  -d, --define <symbols>        Defines one or more semicolon, comma, or space-separated pre-processor symbols.
                                Overrides the initial value from the environment value \$PREPROCESSOR_SYMBOLS or the default ''.
  -mp, --minver-tag-prefix <prefix>
                                Specifies the Git tag prefix used by MinVer. E.g., 'v' as in the tag v1.2.3.
                                Overrides the initial value from the environment value \$MINVERTAGPREFIX or the default 'v'
  -mi, --minver-prerelease-id <id>
                                Specifies semver prerelease identifiers used by MinVer, E.g., 'preview.0' as in the semver
                                'v1.2.3-preview.6', where MinVer automatically replaces preview.0 with preview.6.
                                Overrides the initial value from the environment value \$MINVERDEFAULTPRERELEASEIDENTIFIERS or
                                'preview.0'
  --nuget-username <user-name>  Username for authenticating with the NuGet repository if needed.
                                Overrides the initial value from the environment value \$GH_ACTOR or ''.
  --nuget-password <key|token|password>
                                Password or token for authenticating with the NuGet repository if needed.
                                Overrides the initial value from the environment value \$GH_TOKEN or ''.
                                Note: nuget.org uses Trusted Publishing and does not need this value, whereas other package
                                managers may still need it, e.g. GitHub Packages.
  -c, --configuration (Release|Debug)
                                Build configuration ('Release' or 'Debug').
                                Overrides the initial value from the environment value \$CONFIGURATION or the default 'Release'.
  -f, --framework <TFM>         Target framework moniker (TFM) for the build. E.g., 'net10.0'.
                                Overrides the initial value from the environment value \$FRAMEWORK or the default ''
  -r, --runtime <RID>           Runtime identifier for the build. E.g., 'linux-x64' or '' for CPU and OS agnostic builds.
                                Overrides the initial value from the environment value \$RUNTIME or the default ''
  -a, --artifacts-path <path>   Path to the root directory of the produced artifacts from the builds. The path MUST be relative
                                to the root of the Git repository's working tree.
                                Overrides the initial value from the environment value \$ARTIFACTS_PATH or the default
                                'artifacts'."

declare -xr common_dotnet_vars="\
  PREPROCESSOR_SYMBOLS          Semicolon, comma, or space-separated pre-processor symbols.
  MINVERTAGPREFIX               Prefix used by MinVer generated Git tags. E.g. 'v'.
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Prerelease identifier used by MinVer for SemVer pre-release versions. E.g., 'preview.0'.
  GH_ACTOR                      Username for authenticating with the NuGet package manager.
  GH_TOKEN                      Password or token for authenticating with the NuGet package manager.
  CONFIGURATION                 Build configuration. E.g. 'Release' or 'Debug'.
  ARTIFACTS_PATH                Path to the root directory of the produced artifacts. E.g. 'artifacts'.
  FRAMEWORK                     Target framework moniker (TFM). E.g., 'net10.0'.
  RUNTIME                       Runtime identifier. E.g., 'linux-x64' or '' for CPU and OS agnostic builds.
  GITHUB_STEP_SUMMARY           Path to the GitHub file where actions may append markdown text to the step summary.
  GITHUB_OUTPUT                 Path to the GitHub file where the actions and scripts can write '\<key\>=\<value\>' pairs to.
                                The keys should be declared by the publishing jobs in the 'outputs:' element and by the
                                downstream consuming jobs in the 'with:' element."

declare -xr common_dotnet_output="\
  preprocessor-symbols          Pre-processor symbols for compilation
  minver-tag-prefix             Prefix for MinVer version git tags
  minver-prerelease-id          Default semver pre-release identifiers for MinVer
  configuration                 Build configuration ('Release' or 'Debug')
  artifacts                     Directory to store build, test, benchmark, and test artifacts.
  target-framework              Version of .NET SDK to use
  runtime                       Runtime identifier for the build. E.g., 'linux-x64' or '' for CPU and OS agnostic builds."
