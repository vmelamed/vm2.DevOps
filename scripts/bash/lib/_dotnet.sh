# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#---------------------------------------------------------------------------------------------
# This script defines functions for extracting build information from the output of a 'dotnet
# build -v d' command. It sets global exported variables with the extracted information.
#---------------------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_DOTNET_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DOTNET_SH_LOADED=1

declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_argument_type
declare -xri err_invalid_nameref
declare -xri err_missing_argument
declare -xri err_tool_error
declare -xri err_logic_error
declare -xri err_not_found
declare -xri err_not_file

declare -xr ci
declare -x _ignore
declare -x glow_present


#=============================================================================================
# Build keys used in the build and build result associative arrays:
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with the respective value of the
#   project name.
#---------------------------------------------------------------------------------------------
declare -xr key_project='Project'

#---------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective values like
#   `"Debug"` or `"Release"`. The value is usually specified on the `dotnet` command line with
#   the switch `--configuration`, or `-property:Configuration=<value>`. If not specified, the
#   default value is set to "Release" in CI/CD environments ($ci == true), otherwise -
#   "Debug".
#---------------------------------------------------------------------------------------------
declare -xr key_configuration='Configuration'

#---------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective values -
#   semicolon-separated list of valid target framework monikers (TFMs), like
#   `"net9.0;net10.0"`.The value MUST be specified in the respective `Directory.Build.props`,
#   or defined/overridden in project files (`*.csproj`). It does not have a default value.
#---------------------------------------------------------------------------------------------
declare -xr key_target_frameworks='TargetFrameworks'

#---------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective values of a valid
#   target framework monikers (TFMs), like `net9.0` or `net10.0`. For single-targeting
#   projects the value CAN be specified in the respective `Directory.Build.props`, or
#   defined/overridden in project files (`*.csproj`) that SHOULD NOT use `TargetFrameworks`.
#   For multi-targeting projects it may be specified on the `dotnet` command line with the
#   switch `--target` or `-property:TargetFramework=<value>` but the value must be one of the
#   'TargetFrameworks'. Specifying the key and value for multi-targeting projects ensures that
#   only one build/pack/publish process is executed with the specified target framework.
#---------------------------------------------------------------------------------------------
declare -xr key_target_framework='TargetFramework'

#---------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective value of a valid
#   runtime identifier (RIDs), like `linux-x64` or `win-x64`. It is usually specified on the
#   `dotnet` command line with the switch `--runtime`, or
#   `-property:RuntimeIdentifier=<value>`. Not specifying it means the build will produce a
#   platform-agnostic output.
#---------------------------------------------------------------------------------------------
declare -xr key_runtime_identifier='RuntimeIdentifier'

#---------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective value of the
#   platform, like `AnyCPU`, `x64`, or `x86`. It is either derived from `RuntimeIdentifier`
#   (the vm2 default) or specified on the `dotnet` command line with the switch `--platform`,
#   or `-property:Platform=<value>`. Not specifying it means the build will use the default
#   platform.
#---------------------------------------------------------------------------------------------
declare -xr key_platform='Platform'

#---------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective value of the path
#   where build artifacts are stored. Usually specified in the respective
#   `Directory.Build.props`, defined/overridden in project files (`*.csproj`), or specified on
#   the `dotnet` command line with the switch `--artifacts-path` or
#   `-property:ArtifactsPath=<value>`.
#
#   NOTE: This key-value pair works the best when specified in `Directory.Build.props` along
#   the artifacts layout property `<UseArtifactsPath>true</UseArtifactsPath>`. In this case,
#   if not specified, the default value of this property is `artifacts`.
#
#   NOTE: `<UseArtifactsPath>true</UseArtifactsPath>` specified in `Directory.Build.props` is
#   the adopted convention for the vm2 build system.
#---------------------------------------------------------------------------------------------
declare -xr key_artifacts_path='ArtifactsPath'

#---------------------------------------------------------------------------------------------
# @description Array of keys representing some of the build keys that are used by the
#   `dotnet_build` function.
#---------------------------------------------------------------------------------------------
declare -xra build_keys=(
    "$key_project"
    "$key_configuration"
    "$key_target_framework"
    "$key_runtime_identifier"
    "$key_platform"
    "$key_artifacts_path"
)

#=============================================================================================
# Build result keys used in the build result associative arrays:
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays with
#   respective value like `"succeeded"` or `"FAILED"`
#---------------------------------------------------------------------------------------------
declare -xr key_build_result='build_result'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the number of errors encountered during the build.
#---------------------------------------------------------------------------------------------
declare -xr key_errors_count='errors_count'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the number of warnings encountered during the build.
#---------------------------------------------------------------------------------------------
declare -xr key_warnings_count='warnings_count'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the built assembly's absolute path.
#   E.g. /home/runner/work/vm2.Ulid/artifacts/bin/Ulid/release/Ulid.dll
#---------------------------------------------------------------------------------------------
declare -xr key_target_path='TargetPath'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the exit code of the build process.
#---------------------------------------------------------------------------------------------
declare -xr key_exit_code='ExitCode'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the message associated with the exit code of the build process.
#---------------------------------------------------------------------------------------------
declare -xr key_exit_message='ExitMessage'

#---------------------------------------------------------------------------------------------
# @description Array of keys representing some of the build result keys that are used by the
#   functions `dotnet_build`, `extract_dotnet_build_info, and `display_dotnet_build_summary`.
#---------------------------------------------------------------------------------------------
declare -xra result_keys=(
    "$key_build_result"
    "$key_errors_count"
    "$key_warnings_count"
    "$key_target_path"
    "$key_exit_code"
    "$key_exit_message"
)

#=============================================================================================
# Version information keys used in the build result associative arrays:
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the assembly version string (usually <major>.0.0.0, e.g. `5.0.0.0`).
#---------------------------------------------------------------------------------------------
declare -xr key_assembly_version='AssemblyVersion'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the assembly version string (usually <major>.<minor>.<patch>.0, e.g.
#   `5.2.2.0`).
#---------------------------------------------------------------------------------------------
declare -xr key_file_version='FileVersion'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the assembly version string (usually SemVer with build metadata, e.g.
#   `5.2.2-preview.8.2+f360cddbf3f63f7f0fdcfe52e24fd87dac5472ef`).
#---------------------------------------------------------------------------------------------
declare -xr key_informational_version='InformationalVersion'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the version string. (usually SemVer without build metadata, e.g.
#   `5.2.2-preview.8.2`).
#---------------------------------------------------------------------------------------------
declare -xr key_version='Version'

#---------------------------------------------------------------------------------------------
# @description Array of keys representing some of the version information keys that are used
#   by the `dotnet_build()`, `extract_dotnet_build_info(), and
#   `display_dotnet_build_summary()` functions.
#---------------------------------------------------------------------------------------------
declare -xra version_keys=(
    "$key_assembly_version"
    "$key_file_version"
    "$key_informational_version"
    "$key_version"
)

#=============================================================================================
# Version information keys used in the build result associative arrays:
#=============================================================================================

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the absolute path to the built package output directory.
#   E.g. /home/runner/work/vm2.Ulid/artifacts/package/...
#---------------------------------------------------------------------------------------------
declare -xr key_package_output_path='PackageOutputPath'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the package version string. (usually SemVer without build metadata, e.g.
#   `5.2.2-preview.8.2`).
#---------------------------------------------------------------------------------------------
declare -xr key_package_version='PackageVersion'

#---------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the built package ID. E.g. vm2.Ulid.
#---------------------------------------------------------------------------------------------
declare -xr key_package_id='PackageId'

declare -xra package_keys=(
    "$key_package_output_path"
    "$key_package_id"
    "$key_package_version"
)

declare -xa build_info_keys=()
build_info_keys+=("${build_keys[@]}")
build_info_keys+=("${result_keys[@]}")
build_info_keys+=("${version_keys[@]}")
build_info_keys+=("${package_keys[@]}")
declare -xra build_info_keys

# known return codes from the `dotnet` command
declare -xri dotnet_success=0                       # Build succeeded; no errors or warnings were reported
declare -xri dotnet_failure=1                       # Unknown error or catch-all error; check the build output for details
declare -xri dotnet_err_test_failure=2              # At least one test failure occurred (if running tests as part of build)
declare -xri dotnet_err_test_aborted=3              # Test session was aborted (e.g., by Ctrl+C)
declare -xri dotnet_err_invalid_setup=4             # Invalid setup of used extensions (e.g., test adapters)
declare -xri dotnet_err_invalid_cmd_line=5          # Invalid command-line arguments to the test app
declare -xri dotnet_err_test_session_failed=7       # Test session crashed or failed to complete
declare -xri dotnet_err_no_test_ran=8               # Zero tests ran (no tests found or configured)
declare -xri dotnet_err_min_exec_policy_violated=9  # Minimum execution policy for tests was violated
declare -xri dotnet_err_test_framework_failure=10   # Test framework or adapter failed to run due to infrastructure issues
declare -xri dotnet_err_proc_exit=11                # Dependent process exited; test process will exit too
declare -xri dotnet_err_unsupported_protocol=12     # Client does not support any supported protocol versions
declare -xri dotnet_err_max_failed_tests=13         # Maximum failed tests reached (if limit was set)
declare -xri dotnet_err_unknown=256                 # Unknown dotnet error code

declare -xrA dotnet_err_messages=(
    [$dotnet_success]="Build succeeded; no errors or warnings were reported"
    [$dotnet_failure]="Unknown error or catch-all error; check the build output for details"
    [$dotnet_err_test_failure]="At least one test failure occurred (if running tests as part of build)"
    [$dotnet_err_test_aborted]="Test session was aborted (e.g., by Ctrl+C)"
    [$dotnet_err_invalid_setup]="Invalid setup of used extensions (e.g., test adapters)"
    [$dotnet_err_invalid_cmd_line]="Invalid command-line arguments to the test app"
    [$dotnet_err_test_session_failed]="Test session crashed or failed to complete"
    [$dotnet_err_no_test_ran]="Zero tests ran (no tests found or configured)"
    [$dotnet_err_min_exec_policy_violated]="Minimum execution policy for tests was violated"
    [$dotnet_err_test_framework_failure]="Test framework or adapter failed to run due to infrastructure issues"
    [$dotnet_err_proc_exit]="Dependent process exited; test process will exit too"
    [$dotnet_err_unsupported_protocol]="Client does not support any supported protocol versions"
    [$dotnet_err_max_failed_tests]="Maximum failed tests reached (if limit was set)"
    [$dotnet_err_unknown]="Unknown dotnet error code"
)

#---------------------------------------------------------------------------------------------
# @description Gets the error message corresponding to a dotnet error code.
#
#
# @arg $1 int The dotnet error code.
#
# @exitcode success/positive=0: The error message was retrieved successfully.
#
# @stdout string The error message corresponding to the provided dotnet error code.
#
# @example
#   get_dotnet_error_message 1
#---------------------------------------------------------------------------------------------
function get_dotnet_error_message()
{
    (( $# == 1 ))                        || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 argument:" \
                                                                                "  - a non-negative integer error code returned from dotnet commands"
    [[ ! -v 1 ]] || is_non_negative "$1" || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 1 to be a positive integer error code from 1 to 255 with a corresponding dotnet error message (provided '${1:-<none>}')"

    exit_if_has_bugs

    local -i _ec=$1
    [[ -v dotnet_err_messages[$1] ]] || _ec=$dotnet_err_unknown
    echo "$1: ${dotnet_err_messages[$_ec]}"
}

# reference variables common for most vm2.DevOps scripts that are
# set usually from CLI arguments (below), environment variables, or defaults
# consider the following variables a contract for the names of the named options acquired by
# get_common_gh_action_arg
declare -x preprocessor_symbols
declare -x configuration
declare -x framework
declare -x runtime
declare -x artifacts
declare -x minver_tag_prefix
declare -x minver_prerelease_id
declare -x gh_nuget_username
declare -x gh_nuget_password

#---------------------------------------------------------------------------------------------
# @description Updates the NuGet sources with GitHub Packages from vm2.
#
# @arg $1 string NuGet source username (optional, if provided, $2 also MUST be provided, defaults to $GH_ACTOR in CI)
# @arg $2 string NuGet source password (optional, if $1 is provided, $2 also MUST be provided, otherwise MUST not be provided, defaults to $GH_TOKEN in CI)
#
# @exitcode success/positive=0: The NuGet source was updated, or no credentials were provided (a warning is logged instead).
# @exitcode err_tool_error=66: If 'dotnet nuget update source' failed.
#---------------------------------------------------------------------------------------------
function update_nuget_sources_with_github_vm2()
{
    local -i _rc=$success

    (( $# == 0 || $# == 2 ))                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() accepts either 0 or 2 arguments (provided $#):" \
                                                                                        "  - NuGet source username (in CI defaults to \$GH_ACTOR)" \
                                                                                        "  - NuGet source password (in CI defaults to \$GH_TOKEN)"
    [[ ! -v 1 && ! -v 2 || -n "$1" && -n "$2" ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() The arguments should either be not provided or both must be provided and non-empty."

    exit_if_has_bugs

    local _gh_nuget_username=${1:-${gh_nuget_username:-${GH_ACTOR:-}}}
    local _gh_nuget_password=${2:-${gh_nuget_password:-${GH_TOKEN:-}}}

    [[ -n $_gh_nuget_username && -n $_gh_nuget_password ]] || {
        warning "${FUNCNAME[0]}() GitHub NuGet source credentials are not provided. Did not update the NuGet sources with GitHub packages from vm2."
        return "$success"
    }

    execute dotnet nuget update source github.vm2 \
                --configfile NuGet.config \
                --username "$_gh_nuget_username" \
                --password "$_gh_nuget_password" \
                --store-password-in-clear-text || {
        _rc=$?
        error -ec "$err_tool_error" "${FUNCNAME[0]}() Failed to update the NuGet sources with GitHub packages from vm2." \
                         "$(get_dotnet_error_message "$_rc")"
        return "$err_tool_error"
    }
}

declare -xrA dotnet_args_to_msbuild_args=(
    [--configuration]="-property:Configuration=\"%s\""
    [-c]="-property:Configuration=\"%s\""

    [--framework]="-property:TargetFramework=\"%s\""
    [-f]="-property:TargetFramework=\"%s\""

    [--runtime]="-property:RuntimeIdentifier=\"%s\""
    [-r]="-property:RuntimeIdentifier=\"%s\""

    [--artifacts-path]="-property:ArtifactsPath=\"%s\""

    [--use-current-runtime]="-property:UseCurrentRuntimeIdentifier=true"
    [-ucr]="-property:UseCurrentRuntimeIdentifier=true"

    [--no-self-contained]="-property:SelfContained=false"
    [--self-contained]="-property:SelfContained=true"
    [--sc]="-property:SelfContained=true"

    [--no-dependencies]="-property:BuildProjectReferences=false"

    [--verbosity]="-verbosity:%s"
    [-v]="-verbosity:%s"

    [--interactive]="-interactive"
    [-nologo]="-noLogo:true"
    [--no-logo]="-noLogo:true"

    [--output]="-property:OutputPath=\"%s\"|@warning Please, use artifacts output layout: --artifacts-path <ARTIFACTS_PATH>"
    [-o]="-property:OutputPath=\"%s\"|@warning Please, use artifacts output layout: --artifacts-path <ARTIFACTS_PATH>"

    [--version-suffix]="-property:VersionSuffix=\"%s\"|@warning Please, use the MinVer features and properties."
    [-vs]="-property:VersionSuffix=\"%s\"|@warning Please, use the MinVer features and properties."

    [--os]="@remove \"%s\"|@error Please, use '--runtime <RID>' instead of '--arch <ARCH> --os <OS>'."
    [--arch]="@remove \"%s\"|@error Please, use '--runtime <RID> instead of '--arch <ARCH> --os <OS>'."

    [--no-build]="@remove"
    [--no-restore]="@remove"
    [--no-incremental]="@remove"
    [--disable-build-servers]="@remove"
)

#---------------------------------------------------------------------------------------------
# @description Converts the `dotnet <command>` arguments in the arguments $2..$N to the
#   corresponding `dotnet msbuild` arguments, e.g., converts `"--configuration" "Release"` to
#   `"--property:Configuration=Release"` based on the `dotnet_args_to_msbuild_args` mapping.
#   The converted results are placed in the output $1 array.
#
# @arg $1 nameref to the array variable in which MSBuild arguments and properties will be
#   placed
# @arg $@ string the `dotnet <command>` arguments to be converted to MSBuild arguments and properties
#
# @exitcode success/positive=0: All arguments were converted successfully.
# @exitcode err_missing_argument=6: An option that requires a value (e.g. `--configuration`) was
#   the last argument, with no value following it.
# @exitcode err_argument_type=3: An option that has been removed from `dotnet` in favor of
#   another (e.g. `--os`/`--arch` in favor of `--runtime`) was used.
#---------------------------------------------------------------------------------------------
function convert_dotnet_args_to_msbuild_args()
{
    (( $# > 1 ))                                  || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires more than one, arguments (provided $#):" \
                                                                                        "  - the name of the array variable to receive the MSBuild arguments" \
                                                                                        "  - the 'dotnet <command>' arguments to be converted"
    [[ ! -v 1 ]] || is_defined_indexed_array "$1" || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be the name of an indexed array variable to which the build arguments will be added (provided '${1:-<none>}')."

    exit_if_has_bugs

    local -n _msb_args=$1
    shift

    local _dot_option
    local _arg
    local _replacement
    local -a _replacement_parts
    local _part
    local _msb_option
    local _remove=false

    trace "Converting 'dotnet <restore/build/pack>...' arguments to 'dotnet msbuild ...' arguments."
    while (( $# > 0 )); do
        _dot_option=$1
        shift
        # if the curr.param is project file or directory - add it as is
        [[ $_dot_option == *.@(csproj|slnx|sln) || -d $_dot_option ]] &&
            _msb_args+=("$_dot_option") &&
            trace "  Added '$_dot_option' - project, solution, or directory." &&
            continue

        [[ ! -v dotnet_args_to_msbuild_args[$_dot_option] ]] &&
            _msb_args+=("$_dot_option") &&
            trace "  Added '$_dot_option' as is." &&
            continue

        # get the replacement string for the current dotnet option
        _replacement=${dotnet_args_to_msbuild_args[$_dot_option]}

        # does this option require an argument? - if the replacement string contains '%s', it does and it must be the next argument.
        if [[ $_replacement == *%s* ]]; then
            (( $# == 0 )) && error -ec "$err_missing_argument" "Missing argument for option '$_dot_option'" && return "$err_missing_argument"
            _arg=$1
            shift
        else
            _arg=''
        fi

        _replacement_parts=()
        _remove=false
        _msb_option=''

        IFS='|' read -r -a _replacement_parts <<< "$_replacement"

        for _part in "${_replacement_parts[@]}"; do
            # process the instructions
            [[ $_part == @remove* ]]  && _remove=true                && continue
            [[ $_part == @warning* ]] && warning "${_part#@warning}" && continue
            [[ $_part == @error* ]]   && error -ec "$err_argument_type" "${_part#@error}" && return "$err_argument_type"

            # otherwise the current _part is a format string for printf and the argument is _arg
            # shellcheck disable=SC2059 # Don't use variables in the printf format string.
            printf -v _msb_option -- "$_part" "$_arg"
        done

        if [[ -n $_msb_option ]] && ! $_remove; then
            _msb_args+=("$_msb_option")
            trace "  Replaced '$_dot_option $_arg' with '$_msb_option'."
        else
            trace "  ⚠️ Removed '$_dot_option $_arg'"
        fi
    done
}

declare -xr property_value_rex='^[[:space:]]*([[:alpha:]_][[:alnum:]_]*)=(.*)$'
declare -xr build_result_rex='^[[:space:]]*Build (succeeded|FAILED).*$'
declare -xr count_errors_rex='^[[:space:]]*([0-9]+) (Error|Warning).*$'

#---------------------------------------------------------------------------------------------
# @description Extracts build information from the output of a 'dotnet build' command and
#   populates the specified associative array with the results at indexes from the
#   `$build_info_keys` array.
#
#
# @arg $1 string The project file path for which the build information is being extracted
# @arg $2 int The result code from 'dotnet build'
# @arg $3 nameref to an associative array variable to receive the build information
#
# @stdin The standard input from which to read the build output, e.g. dotnet build --verbosity minimal
#
# @exitcode success/positive=0
#---------------------------------------------------------------------------------------------
function extract_dotnet_build_info()
{
    (( $# == 3 ))                                       || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly three arguments (provided $#):" \
                                                                                            "  - the name of an associative array that will receive build information" \
                                                                                            "  - the result code from 'dotnet build'" \
                                                                                            "  - the name of an associative array variable to receive the build information"
    [[ ! -v 1 || $1 == *.@(slnx|sln|csproj) && -s $1 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a project or solution file path (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_non_negative "$2"                || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 2 to be an exit code - non-negative number (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_defined_associative_array "$3"   || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3 to name an associative array that will receive build information (provided '${3:-<none>}')."

    exit_if_has_bugs

    local _project_file="$1"
    local _build_result="$2"
    local -n _extracted=$3

    # shellcheck disable=SC2004 # Variable: key_project, key_exit_code, key_exit_message, key_build_result, key_warnings_count, key_errors_count - defined elsewhere
    _extracted=(
        [$key_project]="$_project_file"
        [$key_exit_code]=$2
        [$key_exit_message]=$(get_dotnet_error_message "$2")
        [$key_build_result]='Unknown'
        [$key_warnings_count]=0
        [$key_errors_count]=0
    )

    # shellcheck disable=SC2034 # state appears unused. Verify use (or export if used externally).
    local -A state=()
    save_state state
    set_case_sensitive false

    local _line _property
    local _echo=false
    # shellcheck disable=SC2004 # Variable: _line, _property, _echo, _extracted, key_build_result, key_warnings_count, key_errors_count - defined elsewhere
    while IFS= read -r _line; do
        if [[ $_line =~ $property_value_rex ]]; then
            _property="${BASH_REMATCH[1]}"
            if is_in "$_property" "${build_info_keys[@]}"; then
                # we are interested in this property - store its value in the associative array
                _extracted["$_property"]=$(rtrim "${BASH_REMATCH[2]}")
            fi
        elif [[ $_line =~ $build_result_rex ]]; then
            # get the build result from the matched line
            _extracted[$key_build_result]="${BASH_REMATCH[1]}"
            _echo=true
        elif [[ $_line =~ $count_errors_rex ]]; then
            # get the errors count from the matched line
            [[ ${BASH_REMATCH[2]} == "Error" ]] &&
                _extracted[$key_errors_count]=${BASH_REMATCH[1]} ||
                _extracted[$key_warnings_count]=${BASH_REMATCH[1]}
        fi
        $_echo && is_verbose && echo "$_line"
    done

    if [[ $_project_file != *.csproj ]]; then
        # remove project specific properties for solutions - there are multiple projects and the properties
        # override each other - not useful
        unset "_extracted[$key_target_path]"
        unset "_extracted[$key_package_id]"
    fi

    restore_state state
}

#---------------------------------------------------------------------------------------------
# @description Displays a formatted summary of build information stored in an associative
#   array.
#
#
# @arg $1 nameref to an associative array variable to put the build information into.
#
# @exitcode success/positive=0: The function executed successfully
#
# @stdout Formatted table (via dump_vars) with the build result, warning/error counts, version
#   information, packages, target paths, etc.
#---------------------------------------------------------------------------------------------
function display_dotnet_build_summary()
{
    (( $# == 1 ))                                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#):" \
                                                                                            "  - the name of an associative array variable containing the build information"
    [[ ! -v 1 ]] || is_defined_associative_array "$1" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing build information (provided '${1:-<none>}')."

    exit_if_has_bugs

    local -n _build_info=$1
    local _table_format
    if $ci || $glow_present; then
        _table_format="--markdown"
    else
        _table_format="--graphical"
    fi

    local Package_Output_Path=${_build_info[$key_package_output_path]:-N/A}
    local Package_ID=${_build_info[$key_package_id]:-N/A}
    local Package_Version=${_build_info[$key_package_version]:-N/A}
    local Package_Path
    [[ $Package_ID != "N/A" ]] &&
        Package_Path="${Package_Output_Path%/}/${Package_ID}.${Package_Version}.nupkg" ||
        Package_Path="N/A"
    local Symbols_Package_Path
    [[ $Package_ID != "N/A" ]] &&
        Symbols_Package_Path="${Package_Output_Path%/}/${Package_ID}.${Package_Version}.snupkg" ||
        Symbols_Package_Path="N/A"

    local -a _dump_vars_args=(
        --force
        --quiet
        "$_table_format"
        --header "Configuration:"
        --name "Project"                    "${_build_info[$key_project]:-N/A}"
        --name "Configuration"              "${_build_info[$key_configuration]:-Debug}"
        --name "Target Framework"           "${_build_info[$key_target_framework]:-}"
        --name "Runtime ID"                 "${_build_info[$key_runtime_identifier]:-}"
        --name "Artifacts Path"             "${_build_info[$key_artifacts_path]:-}"
        --header "Build Summary:"
        --name "Dotnet Exit Code"           "${_build_info[$key_exit_code]:-Unknown}"
        --name "Dotnet Exit Message"        "${_build_info[$key_exit_message]:-Unknown}"
        --blank
        --name "Build Result"               "${_build_info[$key_build_result]:-Unknown}"
        --name "Errors"                     "${_build_info[$key_errors_count]:--}"
        --name "Warnings"                   "${_build_info[$key_warnings_count]:--}"
        --header "Version:"
        --name "Version"                    "${_build_info[$key_version]:-N/A}"
        --name "Assembly Version"           "${_build_info[$key_assembly_version]:-N/A}"
        --name "File Version"               "${_build_info[$key_file_version]:-N/A}"
        --name "Informational Version"      "${_build_info[$key_informational_version]:-N/A}"
        --header "Outputs:"
        --name "Target Path"                "${_build_info[$key_target_path]:-N/A}"
        --header "Package:"
        --name "Packages Output Path"       "$Package_Output_Path"
        --name "Package ID"                 "$Package_ID"
        --name "Version"                    "$Package_Version"
        --name "Package Path"               "$Package_Path"
        --name "Symbols Package Path"       "$Symbols_Package_Path"
    )

    dump_vars "${_dump_vars_args[@]}"
}

#---------------------------------------------------------------------------------------------
# @description Cleans a .NET project or solution using the common dotnet arguments.
#
#
# @arg $1 The path to the project or solution file to clean.
#
# @exitcode success/positive=0: If the clean operation is successful.
# @exitcode err_tool_error=66: If 'dotnet clean' failed.
#
# @stderr error messages if the clean operation fails.
#---------------------------------------------------------------------------------------------
function dotnet_clean()
{
    (( $# == 1 ))                                             || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#):" \
                                                                                                    "  - the path to the project which will be cleaned"
    [[ ! -v 1 ]] || [[ $1 == *.@(csproj|slnx|sln) && -s $1 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a project or solution file path (provided '${1:-<none>}')."

    exit_if_has_bugs

    local _project="$1"
    local -a _dotnet_args
    _dotnet_args=(
        "$_project"
        "--no-logo"
        "--verbosity" "quiet"
    )
    [[ -n $configuration ]]        && _dotnet_args+=("--configuration" "$configuration")
    [[ -n $framework ]]            && _dotnet_args+=("--framework" "$framework")
    [[ -n $runtime ]]              && _dotnet_args+=("--runtime" "$runtime")
    [[ -n $artifacts ]]            && _dotnet_args+=("--artifacts-path" "$artifacts")

    trace "Executing: dotnet clean ${_dotnet_args[*]}"
    # CLEAN the project using dotnet build
    local -i _rc="$success"
    execute dotnet clean "${_dotnet_args[@]}" > "$_ignore" 2>&1 || _rc=$?

    [[ $_rc == "$dotnet_success" ]] || {
        error -ec "$err_tool_error" "Cleaning '$_project' failed: ($_rc)." \
                                    "$(get_dotnet_error_message "$_rc")"
        return "$err_tool_error"
    }

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Restores the dependencies of a .NET project for the current runtime
#   environment captured in the common dotnet arguments $runtime and $artifacts.
#
# Notes:
#   - The function uses the common dotnet arguments such as $runtime and $artifacts.
#
# @arg $1 string - the path to the .csproj file of the project.
#
# @exitcode success/positive=0: if the restore operation succeeded.
# @exitcode err_tool_error=66: If 'dotnet restore' failed.
#
# @stderr error messages if the restore operation fails.
#
# @example
#   dotnet_restore src/vm2.Ulid/Ulid.csproj
#---------------------------------------------------------------------------------------------
function dotnet_restore()
{
    (( $# == 1 ))                                             || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#):" \
                                                                                                    "  - the path to the project which dependencies will be restored"
    [[ ! -v 1 ]] || [[ $1 == *.@(csproj|slnx|sln) && -s $1 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a project or solution file path (provided '${1:-<none>}')."

    exit_if_has_bugs

    local _project="$1"
    local -a _dotnet_args
    _dotnet_args=(
        "$_project"
        "--no-logo"
        "--locked-mode"
        "--verbosity" "quiet"
    )
    [[ -n $runtime ]]   && _dotnet_args+=("--runtime" "$runtime")
    [[ -n $artifacts ]] && _dotnet_args+=("--artifacts-path" "$artifacts")

    trace "Executing: dotnet restore ${_dotnet_args[*]}"
    # RESTORE
    local -i _rc="$success"
    execute dotnet restore "${_dotnet_args[@]}" > "$_ignore" 2>&1 || _rc=$?

    [[ $_rc == "$dotnet_success" ]] || {
        error -ec "$err_tool_error" "Restoring '$_project' failed: ($_rc)." \
                                    "$(get_dotnet_error_message "$_rc")"
        return "$err_tool_error"
    }

    return "$success"
}

#---------------------------------------------------------------------------------------------
# @description Builds a .NET project or solution using the common dotnet arguments. Captures build
#   output information in an associative array with keys from the `$build_info_keys` array.
#
# Notes:
#   - The function DOES NOT RESTORE dependencies - they must be restored separately using
#     `dotnet_restore` or downloaded from a cache in CI before invoking this function.
#
# @arg $1 name of the project to build.
# @arg $2 nameref to an associative array variable to receive the build information. Optional.
#   Even if not provided, the build information will be captured internally and displayed in
#   the log.
#
# @exitcode success/positive=0: if the build operation succeeded.
# @exitcode err_tool_error=66: if an external command failed, e.g., 'dotnet build'.
#---------------------------------------------------------------------------------------------
function dotnet_build()
{
    (( $# <= 2 ))                                             || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires no more than two arguments (provided $#):" \
                                                                                                    "  - path to the project or solution file to build" \
                                                                                                    "  - name of an associative array to receive the build information (optional)"
    [[ ! -v 1 ]] || [[ $1 == *.@(csproj|slnx|sln) && -s $1 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a project or solution file path (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_defined_associative_array "$2"         || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires optional argument 2 to name an associative array that will receive the build information (provided '${2:-<none>}')."

    exit_if_has_bugs

    local _project=$1 # the project or solution file to build
    local -i _rc=$success

    local _output_file
    _output_file=$(mktemp) || {
        _rc=$?
        error -ec "$err_tool_error" "Failed to create a temporary output file." "$(get_dotnet_error_message "$_rc")"
        return "$err_tool_error"
    }

    declare -a _dotnet_args
    _dotnet_args=(
        "$_project"
        --no-logo
        --no-restore
        --verbosity minimal
    )
    [[ -n $configuration ]]        && _dotnet_args+=("--configuration" "$configuration")
    [[ -n $framework ]]            && _dotnet_args+=("--framework" "$framework")
    [[ -n $runtime ]]              && _dotnet_args+=("--runtime" "$runtime")
    [[ -n $artifacts ]]            && _dotnet_args+=("--artifacts-path" "$artifacts")
    [[ -n $minver_tag_prefix ]]    && _dotnet_args+=("-property:MinVerTagPrefix=\"$minver_tag_prefix\"")
    [[ -n $minver_prerelease_id ]] && _dotnet_args+=("-property:MinVerPrereleaseIdentifiers=\"$minver_prerelease_id\"")
    [[ -n $preprocessor_symbols ]] && _dotnet_args+=("-property:preprocessor_symbols=\"$preprocessor_symbols\"")

    trace "Executing: dotnet build ${_dotnet_args[*]}"
    # BUILD the project using dotnet build
    dotnet build "${_dotnet_args[@]}" > "$_output_file" 2>&1 || _rc=$? # capture the output for extract and display

    (( _rc == success )) ||
        error -ec "$err_tool_error" "Building '$_project' failed."

    local -A __build_info
    local _build_info_name=${2:-__build_info}
    local -n _build_info=$_build_info_name

    _build_info=()
    local _rc_extract=$success

    # EXTRACT and DISPLAY the build information from the output of 'dotnet build'
    extract_dotnet_build_info "$_project" "$_rc" "$_build_info_name" < "$_output_file" || _rc_extract=$?
    rm -f "$_output_file" || true

    (( _rc_extract == success )) || {
        error -ec "$_rc_extract" "Failed to extract build information from the output of 'dotnet build'."
        return "$_rc_extract"
    }

    display_dotnet_build_summary "$_build_info_name" | to_summary

    (( _rc == success )) && return "$success" || return "$err_tool_error"
}

#---------------------------------------------------------------------------------------------
# @description Packs a .NET project using the common dotnet arguments, assuming that the project
#   has already been built.
#
# @arg $1 string The path to a .csproj file. Note that it must exist and be a valid project
#   file.
# @arg $2 string Package release notes, can be empty string.
# @arg $3 nameref to an associative array variable that will store the properties of the
#   produced packages, including the paths to the built package and symbols at keys
#   respectively "PackagePath" and "SymbolsPath".
#
# @exitcode success/positive=0: The operation was successful.
# @exitcode err_tool_error=66: If 'dotnet pack' failed.
#---------------------------------------------------------------------------------------------
function dotnet_pack()
{
    (( $# == 3 ))                                     || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 3 arguments (provided $#):" \
                                                                                            "  - path to a .csproj file" \
                                                                                            "  - package release notes (can be empty string)" \
                                                                                            "  - nameref to an associative array variable that will store the properties of the produced packages"
    [[ ! -v 1 ]] || [[ $1 == *.csproj && -s "$1" ]]   || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid project (.csproj) file (provided '${1:-<none>}')."
    [[ ! -v 3 ]] || is_defined_associative_array "$3" || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3 to be the name of a defined variable (provided '${3:-<none>}')."

    exit_if_has_bugs

    local _project=$1
    local _reason=${2:-}

    # pack arguments for the dotnet pack command are a subset of the build arguments
    local -i _rc=$success
    declare -a _dotnet_args
    _dotnet_args=(
        "$_project"
        --no-logo
        --no-build
        --verbosity minimal
    )
    [[ -n $configuration ]]        && _dotnet_args+=("--configuration" "$configuration")
    [[ -n $runtime ]]              && _dotnet_args+=("--runtime" "$runtime")
    [[ -n $artifacts ]]            && _dotnet_args+=("--artifacts-path" "$artifacts")
    [[ -n $minver_tag_prefix ]]    && _dotnet_args+=("-property:MinVerTagPrefix=\"$minver_tag_prefix\"")
    [[ -n $minver_prerelease_id ]] && _dotnet_args+=("-property:MinVerPrereleaseIdentifiers=\"$minver_prerelease_id\"")
    [[ -n $reason ]]               && _dotnet_args+=("-property:PackageReleaseNotes=\"$reason\"")

    # execute the dotnet pack command and process its output
    trace "Executing: dotnet pack ${_dotnet_args[*]}"
    # PACK
    # TEMP DEBUG: output un-suppressed to diagnose a live CI failure -- revert before merging.
    execute dotnet pack "${_dotnet_args[@]}" || _rc=$?
    [[ $_rc == "$dotnet_success" ]] || error -ec "$err_tool_error" "Packing '$_project' failed." "$(get_dotnet_error_message "$_rc")"
    exit_if_has_errors

    declare -a _msbuild_args=()
    convert_dotnet_args_to_msbuild_args _msbuild_args "${_dotnet_args[@]}" || {
        _rc=$?
        error -ec "$_rc" "Converting 'dotnet pack' arguments to MSBuild arguments failed for '$_project'."
    }
    exit_if_has_errors

    trace "Executing: \"dotnet msbuild ${_msbuild_args[*]}\":"
    # MSBUILD to find the packages paths
    local _msbuild_output=''
    _msbuild_output=$(dotnet msbuild "${_msbuild_args[@]}") || _rc=$?
    [[ $_rc == "$dotnet_success" ]] || error -ec "$err_tool_error" "Executing MSBuild for '$_project' failed." "$(get_dotnet_error_message "$_rc")"
    exit_if_has_errors

    local -n _properties=$3
    local _property='' _value=''
    local _path='' _id='' _version=''
    local line
    while IFS= read -r line; do
        [[ $line =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] && {
            _property="${BASH_REMATCH[1]}"

            _value="${BASH_REMATCH[2]}"
            rtrim_var _value

            _properties["$_property"]="$_value"

            [[ $_property == "PackageOutputPath" ]] && _path="$_value"    ||
            [[ $_property == "PackageId" ]]         && _id="$_value"      ||
            [[ $_property == "PackageVersion" ]]    && _version="$_value"
        }
    done <<< "$_msbuild_output"

    local _packs_path_and_name
    _packs_path_and_name="$(realpath "$_path")/${_id}.${_version}"

    local _package="${_packs_path_and_name}.nupkg"
    local _symbols="${_packs_path_and_name}.snupkg"

    _properties["PackagePath"]="$_package"
    _properties["SymbolsPath"]="$_symbols"

    dump_vars --quiet --header "Returning Properties:" "${!_properties}"

    [[ -s $_package ]] || error -ec "$err_tool_error" "Package '$_package' not found or empty."
    [[ -s $_symbols ]] || error -ec "$err_tool_error" "Package '$_symbols' not found or empty."
    exit_if_has_errors
}

#---------------------------------------------------------------------------------------------
# @description Gets the full path to the assembly that was or would be produced by
#   `dotnet build` using a .NET project and the common dotnet arguments, without actually building
#   the project.
#
#
# @arg $1 string _csproj - path to a .csproj file
# @arg $2 nameref to a variable to receive the full path to the assembly that was or would be
#   produced
#
# @exitcode success/positive=0: the assembly file exists and is not empty
#
# @stdout the full path of the produced assembly (it may not exist yet), e.g.:
#   /path/to/repo-root/artifacts/bin/Ulid/release/Ulid.dll or
#   /path/to/repo-root/artifacts/bin/GlobTool/debug/GlobTool (Linux executable)
#
# @example
#   declare target_path
#   get_target_path $project target_path
#---------------------------------------------------------------------------------------------
function get_target_path()
{
    (( $# == 2 ))                                  || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                        "  - path to a .csproj file" \
                                                                                        "  - nameref to a variable to receive the full path to the assembly that was or would be produced"
    [[ ! -v 1 ]] || [[ $1 == *.csproj && -s $1 ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the project, to be an existing, non-empty .csproj file (provided '${1:-<none>}')."
    [[ ! -v 2 ]] || is_defined_variable "$2"      || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the variable name to receive the full path to the assembly, to be a defined variable (provided '${2:-<none>}')."

    exit_if_has_bugs

    local _project="$1"
    local -a _dotnet_args
    _dotnet_args=(
        "$_project"
        --no-logo
        --no-restore
        --verbosity minimal
        -getProperty:TargetPath # put the MSBuild command that gets the property "TargetPath" in the msbuild arguments - this is da secret sauce!
    )
    # add the common dotnet parameters
    [[ -n $configuration ]]        && _dotnet_args+=("--configuration" "$configuration")
    [[ -n $framework ]]            && _dotnet_args+=("--framework" "$framework")
    [[ -n $runtime ]]              && _dotnet_args+=("--runtime" "$runtime")
    [[ -n $artifacts ]]            && _dotnet_args+=("--artifacts-path" "$artifacts")
    [[ -n $minver_tag_prefix ]]    && _dotnet_args+=("-property:MinVerTagPrefix=\"$minver_tag_prefix\"")
    [[ -n $minver_prerelease_id ]] && _dotnet_args+=("-property:MinVerPrereleaseIdentifiers=\"$minver_prerelease_id\"")
    [[ -n $preprocessor_symbols ]] && _dotnet_args+=("-property:preprocessor_symbols=\"$preprocessor_symbols\"")

    local -a _msbuild_args=()
    convert_dotnet_args_to_msbuild_args _msbuild_args "${_dotnet_args[@]}" || return $?

    local -n _target_path=$2
    _target_path=$(dotnet msbuild "${_msbuild_args[@]}" 2> "$_ignore") || return $?
}
