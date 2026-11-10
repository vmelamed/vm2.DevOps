# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_DOTNET_CONSTANTS_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DOTNET_CONSTANTS_SH_LOADED=1

# vm2 core error codes
declare -xri success
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_argument_type

# vm2 core constants
declare -xr bug_prefix

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

declare -xrA dotnet_err_names=(
    [$dotnet_success]="\$dotnet_success"
    [$dotnet_failure]="\$dotnet_failure"
    [$dotnet_err_test_failure]="\$dotnet_err_test_failure"
    [$dotnet_err_test_aborted]="\$dotnet_err_test_aborted"
    [$dotnet_err_invalid_setup]="\$dotnet_err_invalid_setup"
    [$dotnet_err_invalid_cmd_line]="\$dotnet_err_invalid_cmd_line"
    [$dotnet_err_test_session_failed]="\$dotnet_err_test_session_failed"
    [$dotnet_err_no_test_ran]="\$dotnet_err_no_test_ran"
    [$dotnet_err_min_exec_policy_violated]="\$dotnet_err_min_exec_policy_violated"
    [$dotnet_err_test_framework_failure]="\$dotnet_err_test_framework_failure"
    [$dotnet_err_proc_exit]="\$dotnet_err_proc_exit"
    [$dotnet_err_unsupported_protocol]="\$dotnet_err_unsupported_protocol"
    [$dotnet_err_max_failed_tests]="\$dotnet_err_max_failed_tests"
    [$dotnet_err_unknown]="\$dotnet_err_unknown"
)

#-----------------------------------------------------------------------------------------------
# @description Gets the error message corresponding to a dotnet error code. An unrecognized
#   code falls back to the generic "Unknown dotnet error code" message rather than failing.
#
# @arg $1 int The dotnet error code.
#
# @exitcode success=0: The error message was retrieved successfully (always, once past the
#   argument-validation gate).
#
# @stdout string "<code>: <message>" -- the provided code followed by its corresponding dotnet
#   error message (or the "unknown" message if the code is not recognized).
#
# @example
#   dotnet_error_message 1
#-----------------------------------------------------------------------------------------------
function dotnet_error_message()
{
    local -i _rc=$success
    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires exactly 1 argument: an error code (provided: $#).\n" "$bug_prefix"
        show_stack 2 5
    }

    [[ ! -v 1 ]] || is_exit_code "$1" || {
        _rc="$err_argument_type"
        # avoid calling the error function here to prevent recursion in case error_message is called from within error handling
        printf "%s ${FUNCNAME[0]}() requires argument 1 to be an error code (0..255) (provided '${1-<missing>}')." "$bug_prefix"
        show_stack 2 5
    }
    (( _rc == success )) || exit "$_rc";

    local -i _rc=$1
    [[ -v dotnet_err_messages[$_rc] ]]                                          || _rc=$dotnet_err_unknown

    printf "Dotnet %s (%d): %s" "${dotnet_err_names[$_rc]}" "$1" "${dotnet_err_messages[$_rc]}"
}

#===============================================================================================
# vm2 core minimum dotnet version:
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description The minimum dotnet version required by the vm2 ecosystem.
#-----------------------------------------------------------------------------------------------
declare -xr dotnet_min_version='10.0.204'

#===============================================================================================
# vm2 core build keys used in the build and build result associative arrays:
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with the respective value of the
#   project name.
#-----------------------------------------------------------------------------------------------
declare -xr key_project='Project'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective values like
#   `"Debug"` or `"Release"`. The value is usually specified on the `dotnet` command line with
#   the switch `--configuration`, or `-property:Configuration=<value>`. If not specified, the
#   default value is set to "Release" in CI/CD environments ($ci == true), otherwise -
#   "Debug".
#-----------------------------------------------------------------------------------------------
declare -xr key_configuration='Configuration'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective values -
#   semicolon-separated list of valid target framework monikers (TFMs), like
#   `"net9.0;net10.0"`.The value MUST be specified in the respective `Directory.Build.props`,
#   or defined/overridden in project files (`*.csproj`). It does not have a default value.
#-----------------------------------------------------------------------------------------------
declare -xr key_target_frameworks='TargetFrameworks'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective values of a valid
#   target framework monikers (TFMs), like `net9.0` or `net10.0`. For single-targeting
#   projects the value CAN be specified in the respective `Directory.Build.props`, or
#   defined/overridden in project files (`*.csproj`) that SHOULD NOT use `TargetFrameworks`.
#   For multi-targeting projects it may be specified on the `dotnet` command line with the
#   switch `--target` or `-property:TargetFramework=<value>` but the value must be one of the
#   'TargetFrameworks'. Specifying the key and value for multi-targeting projects ensures that
#   only one build/pack/publish process is executed with the specified target framework.
#-----------------------------------------------------------------------------------------------
declare -xr key_target_framework='TargetFramework'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective value of a valid
#   runtime identifier (RIDs), like `linux-x64` or `win-x64`. It is usually specified on the
#   `dotnet` command line with the switch `--runtime`, or
#   `-property:RuntimeIdentifier=<value>`. Not specifying it means the build will produce a
#   platform-agnostic output.
#-----------------------------------------------------------------------------------------------
declare -xr key_runtime_identifier='RuntimeIdentifier'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with respective value of the
#   platform, like `AnyCPU`, `x64`, or `x86`. It is either derived from `RuntimeIdentifier`
#   (the vm2 default) or specified on the `dotnet` command line with the switch `--platform`,
#   or `-property:Platform=<value>`. Not specifying it means the build will use the default
#   platform.
#-----------------------------------------------------------------------------------------------
declare -xr key_platform='Platform'

#-----------------------------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------------------------
declare -xr key_artifacts_path='ArtifactsPath'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build associative arrays with the respective value of the
#   per-project subfolder name under the artifacts layout's `bin`/`obj`/`publish` directories
#   (e.g. `artifacts/bin/<ArtifactsProjectName>/<configuration>/`). Defaults to
#   `$(MSBuildProjectName)` (the project file's own base name, not `$(AssemblyName)`) when
#   `UseArtifactsOutput=true`. Printed by the vm2 `PrintVersion` target in `Directory.Build.props`.
#-----------------------------------------------------------------------------------------------
declare -xr key_artifacts_project_name='ArtifactsProjectName'

#-----------------------------------------------------------------------------------------------
# @description Array of keys representing some of the build keys that are used by the
#   `dotnet_build` function.
#-----------------------------------------------------------------------------------------------
declare -xra build_keys=(
    "$key_project"
    "$key_configuration"
    "$key_target_framework"
    "$key_runtime_identifier"
    "$key_platform"
    "$key_artifacts_path"
    "$key_artifacts_project_name"
)

#===============================================================================================
# Build result keys used in the build result associative arrays:
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays with
#   respective value like `"succeeded"` or `"FAILED"`
#-----------------------------------------------------------------------------------------------
declare -xr key_build_result='build_result'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the number of errors encountered during the build.
#-----------------------------------------------------------------------------------------------
declare -xr key_errors_count='errors_count'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the number of warnings encountered during the build.
#-----------------------------------------------------------------------------------------------
declare -xr key_warnings_count='warnings_count'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the built assembly's absolute path.
#   E.g. /home/runner/work/vm2.Ulid/artifacts/bin/Ulid/release/Ulid.dll
#-----------------------------------------------------------------------------------------------
declare -xr key_target_path='TargetPath'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the exit code of the build process.
#-----------------------------------------------------------------------------------------------
declare -xr key_exit_code='ExitCode'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the message associated with the exit code of the build process.
#-----------------------------------------------------------------------------------------------
declare -xr key_exit_message='ExitMessage'

#-----------------------------------------------------------------------------------------------
# @description Array of keys representing some of the build result keys that are used by the
#   functions `dotnet_build`, `extract_dotnet_build_info, and `display_dotnet_build_summary`.
#-----------------------------------------------------------------------------------------------
declare -xra result_keys=(
    "$key_build_result"
    "$key_errors_count"
    "$key_warnings_count"
    "$key_target_path"
    "$key_exit_code"
    "$key_exit_message"
)

#===============================================================================================
# Version information keys used in the build result associative arrays:
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the assembly version string (usually <major>.0.0.0, e.g. `5.0.0.0`).
#-----------------------------------------------------------------------------------------------
declare -xr key_assembly_version='AssemblyVersion'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the assembly version string (usually <major>.<minor>.<patch>.0, e.g.
#   `5.2.2.0`).
#-----------------------------------------------------------------------------------------------
declare -xr key_file_version='FileVersion'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the assembly version string (usually SemVer with build metadata, e.g.
#   `5.2.2-preview.8.2+f360cddbf3f63f7f0fdcfe52e24fd87dac5472ef`).
#-----------------------------------------------------------------------------------------------
declare -xr key_informational_version='InformationalVersion'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the version string. (usually SemVer without build metadata, e.g.
#   `5.2.2-preview.8.2`).
#-----------------------------------------------------------------------------------------------
declare -xr key_version='Version'

#-----------------------------------------------------------------------------------------------
# @description Array of keys representing some of the version information keys that are used
#   by the `dotnet_build()`, `extract_dotnet_build_info(), and
#   `display_dotnet_build_summary()` functions.
#-----------------------------------------------------------------------------------------------
declare -xra version_keys=(
    "$key_assembly_version"
    "$key_file_version"
    "$key_informational_version"
    "$key_version"
)

#===============================================================================================
# Package information keys used in the build result associative arrays:
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the absolute path to the built package output directory.
#   E.g. /home/runner/work/vm2.Ulid/artifacts/package/...
#-----------------------------------------------------------------------------------------------
declare -xr key_package_output_path='PackageOutputPath'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the package version string. (usually SemVer without build metadata, e.g.
#   `5.2.2-preview.8.2`).
#-----------------------------------------------------------------------------------------------
declare -xr key_package_version='PackageVersion'

#-----------------------------------------------------------------------------------------------
# @description The key used in the build result associative arrays specifying
#   the built package ID. E.g. vm2.Ulid.
#-----------------------------------------------------------------------------------------------
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
