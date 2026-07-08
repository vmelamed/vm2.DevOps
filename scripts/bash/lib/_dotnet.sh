# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines functions for extracting build information from the output of a 'dotnet build -v d' command.
# It sets global exported variables with the extracted information.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_DOTNET_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_DOTNET_SH_LOADED=1

declare -rxi success
declare -rxi failure
declare -rxi err_invalid_arguments
declare -rxi err_argument_value
declare -rxi err_logic_error

declare -rx ci

if $ci; then
    # In CI, we want to fail immediately if the output cannot be parsed, as it likely indicates a problem with the build or the parsing logic.
    default_configuration="Release"
    default_tfm="net10.0"
else
    # Locally, we want to be more forgiving and allow the script to continue even if the parsing fails, so that we can still see the full build output and debug any issues.
    default_configuration="Debug"
    default_tfm="net10.0"
fi

declare -rx default_configuration
declare -rx default_tfm

# export global variables that hold the results
declare -xi warnings_count=0
declare -xi errors_count=0
declare -x build_result="N/A"
declare -x assembly_version='N/A'
declare -x file_version='N/A'
declare -x informational_version='N/A'
declare -x version='N/A'
declare -x package_version='N/A'

#-------------------------------------------------------------------------------
# @description Extracts build information from the output of a 'dotnet build -v d' command, read line by line from stdin.
#
# Notes:
#   - Sets the global exported variables $build_result, $warnings_count, $errors_count, $assembly_version, $file_version,
#     $informational_version, $version, and $package_version.
#   - These globals are only valid after the function returns and the input has been fully read, and only if the function
#     runs in the current shell context (not piped into, or run in, a subshell).
#   - If $build_result ends up "FAILED", the version fields ($assembly_version, $file_version, $informational_version,
#     $version, $package_version) are reset to 'N/A'.
#   - $build_result is informational only: it does not gate CI. The actual pass/fail decision is the exit code of
#     'dotnet build' itself, captured separately by callers via '${PIPESTATUS[0]}' (see e.g. build.sh).
#
# @exitcode 0 always
#
# @stdout key=value pairs, one per line, for each of the extracted build information variables
#-------------------------------------------------------------------------------
function extractDotnetBuildInfo()
{
    # reset the globals
    warnings_count=0
    errors_count=0
    build_result="N/A"
    assembly_version='N/A'
    file_version='N/A'
    informational_version='N/A'
    version='N/A'
    package_version='N/A'

    local restoreShopt
    restoreShopt=$(shopt -p nocasematch) || true
    shopt -s nocasematch

    local line
    while IFS= read -r line; do
        if [[ $line =~ Build\ (succeeded|FAILED) ]]; then
            build_result="${BASH_REMATCH[1]}"
        elif [[ -z $warnings_count && $line =~ ([0-9]+)\ Warning ]]; then
            warnings_count=${BASH_REMATCH[1]}
        elif [[ -z $errors_count && $line =~ ([0-9]+)\ Error ]]; then
            errors_count=${BASH_REMATCH[1]}
        elif [[ -z $assembly_version && $line =~ AssemblyVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            assembly_version=${BASH_REMATCH[1]}
        elif [[ -z $file_version && $line =~ FileVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            file_version=${BASH_REMATCH[1]}
        elif [[ -z $informational_version && $line =~ InformationalVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            informational_version=${BASH_REMATCH[1]}
        elif [[ -z $version && $line =~ Version:\ ([[:alnum:][:punct:]]+) ]]; then
            version=${BASH_REMATCH[1]}
        elif [[ -z $package_version && $line =~ PackageVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            package_version=${BASH_REMATCH[1]}
        fi
    done

    echo "build_result=$build_result"
    echo "warnings_count=$warnings_count"
    echo "errors_count=$errors_count"
    echo "assembly_version=$assembly_version"
    echo "file_version=$file_version"
    echo "informational_version=$informational_version"
    echo "version=$version"
    echo "package_version=$package_version"

    # shellcheck disable=SC2154 # _ignore is referenced but not assigned.
    eval "$restoreShopt" &> "$_ignore"
}

#-------------------------------------------------------------------------------
# @description Displays a formatted summary of build information, read line by line from stdin as key=value pairs (the
# format produced by extractDotnetBuildInfo).
#
# Notes:
#   - Unlike extractDotnetBuildInfo, this function stores the parsed values into function-local variables (declared with
#     `local`), not the module's global exported variables of the same name.
#
# @exitcode 0 always
#
# @stdout "Build Results" header followed by a formatted table (via dump_vars) with the build result, warning/error
#   counts, and version information
#-------------------------------------------------------------------------------
function displayDotnetBuildSummary()
{
    local warnings_count=0
    local errors_count=0
    local build_result="N/A"
    local assembly_version='N/A'
    local file_version='N/A'
    local informational_version='N/A'
    local version='N/A'
    local package_version='N/A'

    local var value
    while IFS='=' read -r var value; do
        case $var in
            build_result )
                build_result="$value"
                ;;
            warnings_count )
                warnings_count="$value"
                ;;
            errors_count )
                errors_count="$value"
                ;;
            assembly_version )
                assembly_version="$value"
                ;;
            file_version )
                file_version="$value"
                ;;
            informational_version )
                informational_version="$value"
                ;;
            version )
                version="$value"
                ;;
            package_version )
                package_version="$value"
                ;;
            * )
                ;;

        esac
    done

    echo "Build Results"
    dump_vars --force --quiet \
        --header "Dotnet Build Summary:" \
        build_result \
        --line \
        warnings_count \
        errors_count \
        --header "Version Information:" \
        assembly_version \
        file_version \
        version \
        package_version \
        informational_version

    return "$success"
}

function get_build_info()
{
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the name of the build information variable to retrieve."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    case $1 in
        build_result )
            echo "$build_result"
            ;;
        warnings_count )
            echo "$warnings_count"
            ;;
        errors_count )
            echo "$errors_count"
            ;;
        assembly_version )
            echo "$assembly_version"
            ;;
        file_version )
            echo "$file_version"
            ;;
        informational_version )
            echo "$informational_version"
            ;;
        version )
            echo "$version"
            ;;
        package_version )
            echo "$package_version"
            ;;
        * ) error -ec "$err_logic_error" "Unrecognized variable: '$1'"
            return "$failure"
            ;;
    esac
    return "$success"
}

#-------------------------------------------------------------------------------
# @description Returns the full path to the assembly produced by a .NET project.
#
# Notes:
#   - Configuration and TFM are read from the *.csproj first, then from the nearest Directory.Build.props found by
#     walking up from the project directory; the defaults ($default_configuration and $default_tfm, e.g. "Debug"/"Release"
#     and "net10.0") are used when neither file specifies a value.
#   - AssemblyName falls back to the *.csproj filename without the extension.
#   - OutputType "Exe" -> *.exe on Windows, no suffix on Linux. Any other OutputType -> *.dll on any OS.
#
# @arg $1 string csproj - path to the *.csproj file
#
# @exitcode 0 ($success) the assembly file exists and is not empty
# @exitcode 1 ($failure) the assembly path was resolved but the file does not exist yet (the path is still written to stdout)
# @exitcode 2 ($err_invalid_arguments) wrong number of arguments
# @exitcode 4 ($err_argument_value) the argument is empty or not a valid, existing *.csproj file
#
# @stdout the full path to the produced assembly (e.g. /path/to/proj/bin/Debug/net10.0/vm2.Ulid.dll)
#
# @example
#   path=$(assembly_path src/vm2.Ulid/Ulid.csproj)
#-------------------------------------------------------------------------------
function assembly_path() {
    local -i rc="$success"

    (( $# == 1 )) || {
        rc="$err_invalid_arguments"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the path to a *.csproj file."
    }
    [[ -n "$1" && -s "$1" && "$1" == *.csproj ]] || {
        rc="$err_argument_value"
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}(): '$1' is not a valid or existing *.csproj file."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    local csproj
    csproj=$(realpath -e "$1")
    trace "Resolving assembly path for project: $csproj"

    local proj_dir
    proj_dir=$(dirname "$csproj")
    trace "Project directory: $proj_dir"

    # Find the nearest Directory.Build.props by walking up from the project directory
    local dir_build_props=""
    local search_dir="$proj_dir"
    while [[ "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/Directory.Build.props" ]]; then
            dir_build_props="$search_dir/Directory.Build.props"
            break
        fi
        search_dir=$(dirname "$search_dir")
    done
    trace "Nearest 'Directory.Build.props': ${dir_build_props:-None}"

    # TFM: *.csproj → Directory.Build.props → "net10.0"
    local tfm=""
    tfm=$(grep -oPm1 '(?<=<TargetFramework>)[^<]+' "$csproj" 2>"$_ignore") ||
    tfm=$(grep -oPm1 '(?<=<TargetFrameworks>)[^<]+' "$csproj" 2>"$_ignore") || true

    if [[ -z "$tfm" && -n "$dir_build_props" ]]; then
        tfm=$(grep -oPm1 '(?<=<TargetFramework>)[^<]+' "$dir_build_props" 2>"$_ignore") ||
        tfm=$(grep -oPm1 '(?<=<TargetFrameworks>)[^<]+' "$dir_build_props" 2>"$_ignore") || true
    fi

    if [[ "$tfm" == *";"* ]]; then
        warning "Multiple TFMs found in '$(basename "$csproj")'. Using the last one: '${tfm##*;}'."
        tfm="${tfm##*;}"
    fi
    [[ -n "$tfm" ]] || tfm=$default_tfm
    tfm="${tfm//[[:space:]]/}"
    trace "Using TFM: $tfm"

    # Configuration: *.csproj → Directory.Build.props → $default_configuration
    local proj_configuration=""
    proj_configuration=$(grep -oPm1 '(?<=<Configuration>)[^<]+' "$csproj" 2>"$_ignore") || true

    if [[ -z "$proj_configuration" && -n "$dir_build_props" ]]; then
        proj_configuration=$(grep -oPm1 '(?<=<Configuration>)[^<]+' "$dir_build_props" 2>"$_ignore") || true
    fi
    [[ -n "$proj_configuration" ]] || proj_configuration=$default_configuration
    proj_configuration="${proj_configuration//[[:space:]]/}"
    trace "Using Configuration: $proj_configuration"

    # AssemblyName: *.csproj → filename without extension
    local assembly_name=""
    assembly_name=$(grep -oPm1 '(?<=<AssemblyName>)[^<]+' "$csproj" 2>"$_ignore") || true
    [[ -n "$assembly_name" ]] || assembly_name=$(basename "${csproj%.*}")
    assembly_name="${assembly_name//[[:space:]]/}"
    trace "Using AssemblyName: $assembly_name"

    # OutputType: determines the file suffix
    local output_type=""
    output_type=$(grep -oPm1 '(?<=<OutputType>)[^<]+' "$csproj" 2>"$_ignore") || true
    output_type="${output_type//[[:space:]]/}"
    local suffix
    if [[ "${output_type,,}" == "exe" ]]; then
        is_windows && suffix=".exe" || suffix=""
    else
        suffix=".dll"
    fi
    trace "Using 'OutputType': ${output_type:-None} → suffix: '$suffix'"

    local path="$proj_dir/bin/$proj_configuration/$tfm/$assembly_name$suffix"

    echo "$path"
    trace "Looking for assembly at: $path"

    [[ -s "$path" ]] && return "$success" || {
        warning "Assembly NOT FOUND at: $path"
        return "$failure"
    }
}
