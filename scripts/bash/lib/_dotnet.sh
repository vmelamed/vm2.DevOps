# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_DOTNET_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DOTNET_SH_LOADED=1

declare -xri success
declare -xri failure
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_missing_argument
declare -xri err_tool_error
declare -xri err_not_file
declare -xri err_io_failure

declare -xr ci

# Build keys used in the build and build result associative arrays:
declare -xr key_configuration

# known return codes from the `dotnet` command
declare -xri dotnet_success

declare -xa build_info_keys

#===============================================================================================
# reference variables common for most vm2.DevOps scripts that are
# set usually from CLI arguments (below), environment variables, or defaults
# consider the following variables a contract for the names of the named options acquired by
# get_common_gh_action_arg
#===============================================================================================
declare -x preprocessor_symbols
declare -x configuration
declare -x framework
declare -x runtime
declare -x artifacts
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password
#===============================================================================================

#---------------------------------------------------------------------------------------------
# @description Updates the NuGet sources with GitHub Packages from vm2.
#
# @arg $1 string NuGet source username (optional, if provided, $2 also MUST be provided,
#   defaults to $GH_ACTOR in CI)
# @arg $2 string NuGet source password (optional, if $1 is provided, $2 also MUST be provided,
#   otherwise MUST not be provided, defaults to $GH_TOKEN in CI)
#
# @exitcode success=0: The NuGet source was updated, or no credentials were provided (a
#   warning is logged instead).
# @exitcode err_tool_error=66: If 'dotnet nuget update source' failed.
#---------------------------------------------------------------------------------------------
function update_nuget_sources_with_github_vm2()
{
    local -i _rc=$success

    (( $# == 0 || $# == 2 ))                                                    || bug "${FUNCNAME[0]}() accepts either 0 or 2 arguments (provided $#):" \
                                                                                       "  - NuGet source username (in CI defaults to \$GH_ACTOR)" \
                                                                                       "  - NuGet source password (in CI defaults to \$GH_TOKEN)" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 && ! -v 2 || -n "$1" && -n "$2" ]]                                || bug "${FUNCNAME[0]}() The arguments should either be not provided or both must be provided and non-empty." -ec "$err_argument_value"
                                                                                exit_if_has_bugs

    local _gh_nuget_username=${1:-${gh_nuget_username:-${GH_ACTOR:-}}}
    local _gh_nuget_password=${2:-${gh_nuget_password:-${GH_TOKEN:-}}}

    [[ -n $_gh_nuget_username && -n $_gh_nuget_password ]] || {
        local _message="${FUNCNAME[0]}() GitHub NuGet source credentials are not provided. Did not update the NuGet sources with GitHub packages from vm2."

        # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
        $ci &&
            warning "$_message" ||
            trace "$_message"
        return "$success"
    }

    execute dotnet nuget update source github.vm2 \
                --configfile NuGet.config \
                --username "$_gh_nuget_username" \
                --password "$_gh_nuget_password" \
                --store-password-in-clear-text || {
        _rc=$?
        error "${FUNCNAME[0]}() Failed to update the NuGet sources with GitHub packages from vm2." \
              "$(dotnet_error_message "$_rc")" -ec "$err_tool_error"
        return "$err_tool_error"
    }
}

#---------------------------------------------------------------------------------------------
# @description Cleans a .NET project or solution using the common dotnet arguments.
#
#
# @arg $1 The path to the project or solution file to clean.
# @arg $2..$@ string - additional arguments to pass to 'dotnet clean'. Optional.
#
# @exitcode success=0: If the clean operation is successful.
# @exitcode err_tool_error=66: If 'dotnet clean' failed.
#
# @stderr error messages if the clean operation fails.
#---------------------------------------------------------------------------------------------
function dotnet_clean()
{
    (( $# >= 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 or more arguments (provided $#):" \
                                                                                       "  - path to an existing project or solution file which should be cleaned" \
                                                                                       "  - additional arguments to pass to 'dotnet clean' (optional)" \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ -s $1 && $1 == *.@(csproj|slnx|sln) ]]                                   || { _rc="$err_argument_value"; error "${FUNCNAME[0]}() requires argument 1 to be a path to an existing project or solution file (provided '${1-<missing>}')." -ec "$_rc"; }
    (( _rc == "$success" ))                                                     || return "$_rc"

    local _project="$1"
    shift
    local -a _dotnet_args
    _dotnet_args=(
        "$_project"
        "--no-logo"
        "--verbosity" "quiet"
    )
    [[ -z $configuration ]] || _dotnet_args+=("--configuration" "$configuration")
    [[ -z $framework ]]     || _dotnet_args+=("--framework" "$framework")
    [[ -z $runtime ]]       || _dotnet_args+=("--runtime" "$runtime")
    [[ -z $artifacts ]]     || _dotnet_args+=("--artifacts-path" "$artifacts")

    # any remaining arguments go to 'dotnet <command>' as they are
    (( $# == 0 ))           || _dotnet_args+=("$@")

    # CLEAN the project using dotnet build
    execute --quiet dotnet clean "${_dotnet_args[@]}"                           || _rc=$?

    (( _rc == dotnet_success ))                                                 || { _rc="$err_tool_error"; error "Cleaning '$_project' failed: ($_rc)." "$(dotnet_error_message "$_rc")" -ec "$_rc"; }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Restores the dependencies of a .NET project for the current runtime
#   environment captured in the common dotnet arguments $runtime and $artifacts.
#
# Notes:
#   - The function uses the common dotnet arguments such as $runtime and $artifacts.
#
# @arg $1 string - the path to the solution or project file to restore.
# @arg $2..$@ string - additional arguments to pass to 'dotnet restore'.
#
# @exitcode success=0: if the restore operation succeeded.
# @exitcode err_tool_error=66: If 'dotnet restore' failed.
#
# @stderr error messages if the restore operation fails.
#
# @example
#   dotnet_restore src/vm2.Ulid/Ulid.csproj
#---------------------------------------------------------------------------------------------
function dotnet_restore()
{
    (( $# >= 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1 or more arguments (provided $#):" \
                                                                                       "  - path to an existing project or solution file which dependencies should be restored" \
                                                                                       "  - additional arguments to pass to 'dotnet restore' (optional)" \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ $1 == *.@(csproj|slnx|sln) && -s $1 ]]                                   || { _rc="$err_argument_value"; error "${FUNCNAME[0]}() requires argument 1 to be a path to an existing project or solution file (provided '${1-<missing>}')." -ec "$_rc"; }
    (( _rc == "$success" ))                                                     || return "$_rc"

    local _project="$1"
    shift
    local -a _dotnet_args
    _dotnet_args=(
        "$_project"
        "--no-logo"
        "--locked-mode"
        "--verbosity" "quiet"
    )
    [[ -z $runtime ]]   || _dotnet_args+=("--runtime" "$runtime")
    [[ -z $artifacts ]] || _dotnet_args+=("--artifacts-path" "$artifacts")
    # any remaining arguments go to 'dotnet <command>' as they are
    (( $# == 0 ))       || _dotnet_args+=("$@")

    # RESTORE
    execute --quiet dotnet restore "${_dotnet_args[@]}"                         || _rc=$?

    (( _rc == dotnet_success ))                                                 || { error "Restoring '$_project' failed." "$(dotnet_error_message "$_rc")" -ec "$err_tool_error"; return "$err_tool_error"; }
}

#---------------------------------------------------------------------------------------------
# @description Builds a .NET project or solution using the common dotnet arguments. Captures build
#   output information in an associative array with keys from the `$build_info_keys` array.
#
# Notes:
#   - The function DOES NOT RESTORE dependencies - they must be restored separately using
#     `dotnet_restore` or downloaded from a cache in CI before invoking this function.
#
# @arg $1 the path to the solution or project file to build.
# @arg $2 nameref to an associative array variable to receive the build information. Optional
#   if no other parameters are provided. If not provided or empty, the build information will
#   be captured internally and displayed in the log.
# @arg $@ string - additional arguments to pass to 'dotnet build'. To pass additional
#   arguments, argument 2 must be given; it may be empty.
#
# @exitcode success=0: if the build operation succeeded.
# @exitcode err_not_file=65: if argument 1 is not a path to a project or solution file.
# @exitcode err_tool_error=66: if an external command failed, e.g., 'dotnet build'.
#---------------------------------------------------------------------------------------------
function dotnet_build()
{
    (( $# >= 1 ))                                                               || bug "${FUNCNAME[0]}() requires one or more arguments (provided $#):" \
                                                                                       "  - path to an existing project or solution file to build" \
                                                                                       "  - name of an associative array to receive the build information (optional if this is the last argument)" \
                                                                                       "  - additional arguments to pass to 'dotnet build' (optional, if any are present - requires argument 2)" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_valid_path "$1"                                          || bug "${FUNCNAME[0]}() requires argument 1 to be a valid path to an existing file with a suffix .csproj or .slnx or .sln (provided '${1-<missing>}')." -ec "$err_not_file"
    [[ ! -v 2 || -z $2 ]] || is_associative_array "$2"                          || bug "${FUNCNAME[0]}() requires optional argument 2 to name an associative array that will receive the build information (provided '${2-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ "$1" == *.@(csproj|slnx|sln) && -s $1 ]]                                 || { _rc="$err_not_file"; error "${FUNCNAME[0]}() requires argument 1 to be a path to an existing project or solution file (provided '${1-<missing>}')." -ec "$_rc"; }
    (( _rc == "$success" )) || return "$_rc"

    local _project=$1 # the project or solution file to build
    shift
    local -A __build_info
    local _build_info_name=${1:-__build_info}
    [[ ! -v 1 ]] || shift
    local -n _build_info=$_build_info_name

    local _output_file
    _output_file=$(mktemp)                                                      || with_error "$err_io_failure" _rc "Failed to create a temporary file."
    (( _rc == success ))                                                        || return "$_rc"

    declare -a _dotnet_args
    _dotnet_args=(
        "$_project"
        --no-logo
        --no-restore
        --verbosity minimal
    )
    [[ -z $configuration ]]        || _dotnet_args+=("--configuration" "$configuration")
    [[ -z $framework ]]            || _dotnet_args+=("--framework" "$framework")
    [[ -z $runtime ]]              || _dotnet_args+=("--runtime" "$runtime")
    [[ -z $artifacts ]]            || _dotnet_args+=("--artifacts-path" "$artifacts")
    [[ -z $minver_tag_prefix ]]    || _dotnet_args+=("-property:MinVerTagPrefix=\"$minver_tag_prefix\"")
    [[ -z $minver_prerelease_id ]] || _dotnet_args+=("-property:MinVerPrereleaseIdentifiers=\"$minver_prerelease_id\"")
    [[ -z $preprocessor_symbols ]] || _dotnet_args+=("-property:preprocessor_symbols=\"$preprocessor_symbols\"")
    # any remaining arguments go to 'dotnet <command>' as they are
    (( $# == 0 ))                  || _dotnet_args+=("$@")

    _build_info=()

    # BUILD the project using dotnet build
    execute dotnet build "${_dotnet_args[@]}" > "$_output_file" 2>&1            || _rc=$?
    # in a dry run the file holds only execute's 'dry-run$ dotnet build ...' line: show it. The extraction below
    # still runs: it finds no build output and reports an 'Unknown' result, which is the truth for a dry run.
    [[ -s $_output_file ]] && { is_verbose || is_dry_run; } && cat "$_output_file"

    # EXTRACT and DISPLAY the build information from the output of 'dotnet build'
    extract_dotnet_build_info "$_project" "$_rc" "$_build_info_name" < "$_output_file"
    rm -f "$_output_file"

    display_dotnet_build_summary "$_build_info_name" | to_summary
    (( _rc == dotnet_success )) || return "$err_tool_error"
}

#---------------------------------------------------------------------------------------------
# @description Packs a .NET project using the common dotnet arguments, assuming that the
#   project has already been built.
#
# Notes:
#   - This function always runs 'dotnet pack --no-build'. When '$configuration' is empty,
#     'dotnet build' and 'dotnet msbuild' both fall back to 'Debug', but 'dotnet pack' falls
#     back to 'Release' instead -- a divergent SDK-level default. Left unhandled, a caller
#     that built without pinning a configuration (so the output landed under the 'debug'
#     artifacts folder) would then have this function pack with the empty '$configuration',
#     defaulting to 'Release' and looking for output under 'release' -- which '--no-build' can
#     never produce, since it's not there. To avoid that, this function resolves the already-
#     built project's actual property 'Configuration' via 'get_msbuild_property()' whenever
#     '$configuration' is empty, so packing always agrees with whatever was just built,
#     instead of silently diverging.
#
#   - "SymbolsPath" is only set (and only checked for existence) when the project's effective
#     'IncludeSymbols' property is not literally 'false' -- a project that opts out of symbols
#     (e.g. a template package with no compiled output) never produces a '.snupkg', so this
#     function must not expect or report one for it. 'IncludeSymbols' is read from the same
#     '_properties' scrape above (the shared 'Directory.Build.props' PrintVersion target
#     already logs it alongside PackageOutputPath/PackageId/PackageVersion), not via a second
#     MSBuild evaluation -- if it's ever missing from '_properties' (e.g. an older consumer
#     repo that hasn't re-synced its 'Directory.Build.props' yet), this defaults to 'true'
#     (assume symbols are expected, the common case) rather than silently skipping the check.
#
# @arg $1 string The path to a project (.csproj) file. Note that it must exist and be a valid
#   project file to pack
# @arg $2 string Package release notes, can be empty string. Optional if no more arguments
#   were provided.
# @arg $3 nameref to an associative array variable that will store the properties of the
#   produced packages, including the path to the built package at key "PackagePath", and (when
#   applicable -- see Notes) the symbols package path at key "SymbolsPath". Optional if no
#   more arguments were provided.
# @arg $4..$@ string - additional arguments to pass to 'dotnet pack'. Optional. To pass
#   additional arguments, arguments 2 and 3 must be given; they may be empty.
#
# @exitcode success=0: The operation was successful.
# @exitcode err_tool_error=66: If 'dotnet pack' failed, or the project's 'Configuration' could
#   not be resolved.
#---------------------------------------------------------------------------------------------
function dotnet_pack()
{
    (( $# >= 1 ))                                                               || bug "${FUNCNAME[0]}() requires 1, 2, 3, or more arguments (provided $#):" \
                                                                                       "  - path to an existing project file" \
                                                                                       "  - package release notes (can be empty string)" \
                                                                                       "  - nameref to an associative array variable that will store the properties of the produced packages" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_valid_path "$1"                                          || bug "${FUNCNAME[0]}() requires argument 1 to be a valid path to a file with a suffix .csproj (provided '${1-<missing>}')." -ec "$err_not_file"
    [[ ! -v 3 || -z $3 ]] || is_associative_array "$3"                          || bug "${FUNCNAME[0]}() requires argument 3 to be the name of an associative array (provided '${3-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ -s $1 && $1 == *.csproj ]]                                               || { _rc="$err_not_file"; error "${FUNCNAME[0]}() requires argument 1 to be a path to an existing project file (provided '${1-<missing>}')." -ec "$_rc"; }
    (( _rc == "$success" ))                                                     || return "$_rc"

    local _project=$1
    shift
    local _reason=${1:-}
    [[ ! -v 1 ]] || shift
    local -A __properties
    local _properties_name=${1:-__properties}
    [[ ! -v 1 ]] || shift
    local -n _properties=$_properties_name

    # 'dotnet pack' defaults to 'Release' on its own, unlike the 'Debug' default shared by
    # 'dotnet build' and 'dotnet msbuild' -- resolve the project's actual Configuration whenever
    # the caller didn't pin one, so this --no-build pack always matches what was already built.
    # See the function's doc comment above for the failure mode this avoids.
    local _pack_config=$configuration
    if [[ -z $_pack_config ]]; then
        get_msbuild_property "$_project" "$key_configuration" _pack_config      || { _rc=$err_tool_error; error "${FUNCNAME[0]}() Failed to resolve the 'Configuration' property for '$_project'." -ec "$_rc"; }
    fi
    (( _rc == "$success" ))                                                     || return "$_rc"

    # pack arguments for the dotnet pack command are a subset of the build arguments
    declare -a _dotnet_args
    _dotnet_args=(
        "$_project"
        --no-logo
        --no-build
        --verbosity minimal
        --configuration "$_pack_config"
    )
    [[ -z $runtime ]]              || _dotnet_args+=("--runtime" "$runtime")
    [[ -z $artifacts ]]            || _dotnet_args+=("--artifacts-path" "$artifacts")
    [[ -z $minver_tag_prefix ]]    || _dotnet_args+=("-property:MinVerTagPrefix=\"$minver_tag_prefix\"")
    [[ -z $minver_prerelease_id ]] || _dotnet_args+=("-property:MinVerPrereleaseIdentifiers=\"$minver_prerelease_id\"")
    [[ -z $_reason ]]              || _dotnet_args+=("-property:PackageReleaseNotes=\"$_reason\"")
    # any remaining arguments go to 'dotnet <command>' as they are
    (( $# == 0 ))                  || _dotnet_args+=("$@")

    # PACK
    execute --quiet dotnet pack "${_dotnet_args[@]}"                            || _rc=$?

    (( _rc == dotnet_success ))                                                 || { error "Packing '$_project' failed." "$(dotnet_error_message "$_rc")" -ec "$err_tool_error"; return "$err_tool_error"; }

    declare -a _msbuild_args=()
    convert_dotnet_args_to_msbuild_args _msbuild_args "${_dotnet_args[@]}"      || { _rc=$?; error "Converting 'dotnet pack' arguments to MSBuild arguments failed for '$_project'." -ec "$_rc"; return "$_rc"; }

    trace "Executing: \"dotnet msbuild ${_msbuild_args[*]}\":"
    # MSBUILD to find the packages paths
    local _msbuild_output=''
    _msbuild_output=$(dotnet msbuild "${_msbuild_args[@]}")                     || { _rc=$?; error "Executing MSBuild for '$_project' failed." "$(dotnet_error_message "$_rc")" -ec "$err_tool_error"; return "$err_tool_error"; }

    local _property='' _value=''
    local _path='' _id='' _version=''
    local line
    while IFS= read -r line; do
        [[ $line =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] && {
            _property="${BASH_REMATCH[1]}"

            _value="${BASH_REMATCH[2]}"
            rtrim_var _value

            _properties["$_property"]="$_value"

            case $_property in
                PackageOutputPath  ) _path="$_value"    ;;
                PackageId          ) _id="$_value"      ;;
                PackageVersion     ) _version="$_value" ;;
                *                  ) ;;
            esac
        }
    done <<< "$_msbuild_output"

    local _packs_path_and_name

    _packs_path_and_name="$(realpath "$_path")/${_id}.${_version}"

    local _package="${_packs_path_and_name}.nupkg"

    _properties["PackagePath"]="$_package"
    is_dry_run || [[ -s $_package ]]                                            || { _rc=$err_tool_error; error "Package '$_package' not found or empty." -ec "$_rc"; }

    # does it have symbols package and get their path
    #
    # IncludeSymbols is already among the properties Directory.Build.props's own PrintVersion
    # target logs (AfterTargets="Build"), so the scrape loop above already captured it into
    # _properties -- no need for a second, separate MSBuild evaluation here.
    local _include_symbols="${_properties[IncludeSymbols]:-}"
    _include_symbols="${_include_symbols,,}"
    _include_symbols="${_include_symbols:-true}"

    if $_include_symbols; then

        local _symbols="${_packs_path_and_name}.snupkg"

        _properties["SymbolsPath"]="$_symbols"

        is_dry_run || [[ -s $_symbols ]]                                        || warning -ec "$err_tool_error" "Package '$_symbols' not found or empty."
     fi

    dump_vars --quiet --header "Returning Properties:" "${!_properties}"

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Lists the constituent project paths of a solution file (*.sln or *.slnx) via
#   `dotnet sln <file> list`, skipping the fixed two-line header ("Project(s)" and the
#   underline) that command always prints. `dotnet sln list` reports paths relative to the
#   solution file's own directory; this function re-resolves them relative to the current
#   directory instead, so callers get paths consistent with the rest of the codebase's
#   repo-root-relative convention regardless of where the solution file itself lives.
#
# @arg $1 string Path to an existing, non-empty solution file (*.sln or *.slnx).
# @arg $2 nameref to an indexed array variable that will receive the list of project paths.
#
# @exitcode success=0: the solution's projects were listed successfully.
# @exitcode err_tool_error=66: `dotnet sln $1 list` failed, or returned no projects.
#---------------------------------------------------------------------------------------------
function list_solution_projects()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#):" \
                                                                                       "  - path to a solution file (*.sln or *.slnx)" \
                                                                                       "  - name of an indexed array variable to receive the list of project paths" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 2 ]] || is_array "$2"                                               || bug "${FUNCNAME[0]}() requires argument 2 to name a declared indexed-array variable (provided '${2-<missing>}')." -ec "$err_invalid_nameref"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ $1 == *.@(sln|slnx) && -s $1 ]]                                          || { _rc="$err_argument_value"; error "${FUNCNAME[0]}() requires argument 1 to be an existing, non-empty solution file (provided '${1-<missing>}')." -ec "$_rc"; }
    (( _rc == "$success" ))                                                     || return "$_rc"

    local _solution=$1
    local _proj_dir
    _proj_dir=$(dirname "$_solution")

    local -n _out=$2
    _out=()

    # Capture combined stdout+stderr (rather than discarding stderr) so that a failure or an
    # unexpected output shape can be reported with the tool's own diagnostic text, instead of
    # a bare "returned no projects" that gives no clue why.
    local _sln_output
    local -i _sln_rc=$success
    _sln_output=$(dotnet sln "$_solution" list 2>&1) || _sln_rc=$?

    local _proj
    while IFS= read -r _proj; do
        [[ -n $_proj ]] || continue
        _out+=("$(realpath -m --relative-to=. "$_proj_dir/$_proj")")
    # `dotnet sln list`'s own output is a fixed two-line header ("Project(s)" then a matching
    # dashed underline) followed by the project paths -- but on some runners `dotnet` prints
    # extra diagnostic lines (e.g. SDK resolution info) BEFORE that, so skip everything up to
    # and including the dashed separator line itself, rather than assuming a fixed line count.
    done < <(sed -n '/^-\+$/,$p' <<< "$_sln_output" | tail -n +2)

    # Prefer projects under src/ (the vm2 "deliverable source" convention) over ones elsewhere
    # (tests/, benchmarks/, examples/, etc.) -- a caller that just needs *any* project from the
    # solution (e.g. get_artifacts_path(), since ArtifactsPath is uniform repo-wide) gets a real
    # deliverable project first, rather than whatever `dotnet sln list` happened to print first.
    # A stable partition, not a sort: relative order within each group is preserved.
    local -a _src_projects=() _other_projects=()
    local _p
    for _p in "${_out[@]}"; do
        if [[ $_p == src/* ]]; then
            _src_projects+=("$_p")
        else
            _other_projects+=("$_p")
        fi
    done
    _out=("${_src_projects[@]}" "${_other_projects[@]}")

    (( ${#_out[@]} > 0 ))                                                       || { _rc="$err_tool_error"; error "${FUNCNAME[0]}() 'dotnet sln $_solution list' returned no projects (exit code $_sln_rc)." "Raw output:" "$_sln_output" -ec "$_rc"; }

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Expands any solution file (*.sln or *.slnx) entries in a JSON array of
#   project/solution paths into their constituent project paths, via list_solution_projects().
#   Non-solution entries pass through unchanged. Lets CI's build-projects input keep accepting a
#   solution file for developer convenience (and to guarantee no project is left out of the
#   build matrix) while the actual build matrix fans out per-project -- required for
#   Directory.Build.props's IsCI-conditional Configuration default to apply: a solution-level
#   `dotnet build` always resolves its own "solution configuration" (Debug, unless -c is given)
#   and passes it to every child project as an explicit global MSBuild property, which silently
#   overrides Directory.Build.props's conditional regardless of IsCI.
#
# @arg $1 nameref to a variable containing a JSON array of project/solution paths. The expanded,
#   de-duplicated JSON array is stored back into that variable.
#
# @exitcode success=0: every solution entry (if any) was expanded successfully.
# @exitcode err_tool_error=66: list_solution_projects() failed for one of the solution entries.
#---------------------------------------------------------------------------------------------
function expand_solution_projects()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly 1 argument (provided $#):" \
                                                                                       "  - the name of a variable containing a JSON array of project/solution paths" \
                                                                                       -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_variable "$1"                                            || bug "${FUNCNAME[0]}() requires argument 1 to name a declared variable (provided '${1-<missing>}')." -ec "$err_missing_argument"
                                                                                exit_if_has_bugs

    local -n _projects=$1
    local -a _expanded=()
    local _entry
    local -i _rc=$success

    while IFS= read -r _entry; do
        if [[ $_entry == *.@(sln|slnx) ]]; then
            local -a _sln_projects=()
            list_solution_projects "$_entry" _sln_projects || { _rc=$?; continue; }
            _expanded+=("${_sln_projects[@]}")
        else
            _expanded+=("$_entry")
        fi
    done < <(jq -r '.[]' <<< "$_projects")

    if (( _rc == success )); then
        if (( ${#_expanded[@]} > 0 )); then
            _projects=$(printf '%s\n' "${_expanded[@]}" | jq -R . | jq -sc 'unique')
        else
            _projects='[]'
        fi
    fi

    return "$_rc"
}
