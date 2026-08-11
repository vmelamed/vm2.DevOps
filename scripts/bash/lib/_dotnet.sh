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
declare -rxi err_invalid_nameref
declare -rxi err_missing_argument
declare -rxi err_tool_error
declare -rxi err_logic_error

declare -rx ci

$ci && default_configuration="Release" || default_configuration="Debug"
declare -rx default_configuration
declare -rx default_tfm="net10.0"
declare -rx defaultOutputType="Library"

# export global variables that hold the keys of the associative array with the build information
declare -rx key_warnings_count='warnings_count'
declare -rx key_errors_count='errors_count'
declare -rx key_build_result='build_result'
declare -rx key_assembly_version='assembly_version'
declare -rx key_file_version='file_version'
declare -rx key_informational_version='informational_version'
declare -rx key_version='version'
declare -rx key_package_version='package_version'

declare -arx build_info_keys=(
    "$key_build_result"
    "$key_errors_count"
    "$key_warnings_count"
    "$key_version"
    "$key_assembly_version"
    "$key_file_version"
    "$key_informational_version"
    "$key_package_version"
)

#-------------------------------------------------------------------------------
# @description Builds a .NET project using the provided build arguments and captures build information.
#
# @param $1 The name of an array with arguments to pass to 'dotnet build'. Required.
# @param $2 The name of an associative array to receive the build information (optional).
#
# @return Returns 0 on success, or an error code on failure. If @param $2 is provided, it will be populated with the build
#   information.
#
# @stdout will contain the build information as a stream of key=value lines.
#-------------------------------------------------------------------------------
function dotnet_build()
{
    local -A _internal_build_info=()
    local -i _rc=$success

    (( $# == 1 || $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires one or two arguments (provided $#):" \
                                                 "  1) the name of an array with arguments to pass to 'dotnet build'" \
                                                 "  2) the name of an associative array to receive the build information (optional)"
    }

    if [[ -v 1 ]] && is_defined_array "$1"; then
        local -n _validated_build_args=$1
        (( ${#_validated_build_args[@]} > 0 )) || {
            _rc="$err_argument_value"
            error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires the array named by argument 1 to contain at least one 'dotnet build' argument (provided '$1')."
        }
    else
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an indexed array of 'dotnet build' arguments (provided '${1-<missing>}')."
    fi

    [[ ! -v 2 || -z $2 ]] || is_defined_associative_array "$2" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 2 to name an associative array that will receive build information (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _build_args=$1
    local _build_info_name=${2:-_internal_build_info}

    local _build_project=''
    local -i _i
    local _arg
    local -i _v_index=-2
    local _v_value=''

    # make sure we have a project file and verbosity level is specified as detailed
    for (( _i=0; _i < "${#_build_args[@]}"; _i++ )); do
        _arg="${_build_args[_i]}"
        [[ $_arg == *.@(csproj|sln|slnx) && -s $_arg ]] && _build_project="$_arg" ||
        [[ $_arg == --verbosity ]] && _v_index=$_i
        (( _i == _v_index + 1 )) && [[ $_arg == @(quiet|q|minimal|m|detailed|d|diagnostic|diag) ]] && _build_args[_i]="detailed" && _v_value="detailed"
    done

    [[ -n $_build_project ]] || {
        error -sd 3 -ec "$err_argument_value" "Could not find the project argument in the build arguments array. It must be an existing file with a suffix '.csproj'."
        return "$err_argument_value"
    }

    # ensure verbosity is set to detailed
    if [[ $_v_value != "detailed" ]]; then
        (( _v_index >= 0 )) && unset "_build_args[_v_index]"
        _build_args+=(--verbosity detailed)
    fi

    local -n _build_info=$_build_info_name
    _build_info=()

    local _output_file
    _output_file=$(mktemp) || return "$err_tool_error"

    execute dotnet build "${_build_args[@]}" >"$_output_file" 2>&1 ||
        error sd 3 -ec "$err_tool_error" "Building '$_build_project' failed." | to_summary

    extractDotnetBuildInfo "$_build_info_name" <"$_output_file" ||
        error -sd 3 -ec "$err_logic_error" "Failed to extract build information from 'dotnet build' output." | to_summary

    rm -f -- "$_output_file"

    displayDotnetBuildSummary "$_build_info_name" | to_summary

    return "$_rc"
}

#-------------------------------------------------------------------------------
# @description Extracts build information from the output of a 'dotnet build' command and populates the specified associative
#   array with the results.
#
# @param $1 The name of an associative array to receive the build information.
#
# @exitcode 0 always
#-------------------------------------------------------------------------------
# shellcheck disable=SC2004  # $/${} is unnecessary on arithmetic variables.
function extractDotnetBuildInfo()
{
    local -i _rc=$success

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of an associative array that will receive build information."
    }

    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array that will receive build information (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _extracted=$1

    _extracted=(
        [$key_build_result]='Unknown'
        [$key_warnings_count]=0
        [$key_errors_count]=0
        [$key_assembly_version]=''
        [$key_file_version]=''
        [$key_informational_version]=''
        [$key_version]=''
        [$key_package_version]=''
    )

    local _restoreShopt
    _restoreShopt=$(shopt -p nocasematch) || true
    shopt -s nocasematch

    local _line
    while IFS= read -r _line; do
        if [[ $_line =~ Build\ (succeeded|FAILED) ]]; then
            _extracted[$key_build_result]="${BASH_REMATCH[1]}"
        elif [[ $_line =~ ([0-9]+)\ Warning ]]; then
            _extracted[$key_warnings_count]=${BASH_REMATCH[1]}
        elif [[ $_line =~ ([0-9]+)\ Error ]]; then
            _extracted[$key_errors_count]=${BASH_REMATCH[1]}
        elif [[ $_line =~ AssemblyVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            _extracted[$key_assembly_version]=${BASH_REMATCH[1]}
        elif [[ $_line =~ FileVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            _extracted[$key_file_version]=${BASH_REMATCH[1]}
        elif [[ $_line =~ InformationalVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            _extracted[$key_informational_version]=${BASH_REMATCH[1]}
        elif [[ $_line =~ Version:\ ([[:alnum:][:punct:]]+) ]]; then
            _extracted[$key_version]=${BASH_REMATCH[1]}
        elif [[ $_line =~ PackageVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            _extracted[$key_package_version]=${BASH_REMATCH[1]}
        fi
    done

    # shellcheck disable=SC2154 # _ignore is referenced but not assigned.
    eval "$_restoreShopt" &> "$_ignore"

    if [[ ${_extracted[$key_build_result]} == FAILED ]]; then
        _extracted[$key_assembly_version]='N/A'
        _extracted[$key_file_version]='N/A'
        _extracted[$key_informational_version]='N/A'
        _extracted[$key_version]='N/A'
        _extracted[$key_package_version]='N/A'
    fi
}

#-------------------------------------------------------------------------------
# @description Displays a formatted summary of build information stored in an associative array.
#
# @param $1 The name of an associative array containing the build information to display.
#
# @exitcode 0 always
#
# @stdout "Build Results" header followed by a formatted table (via dump_vars) with the build result, warning/error counts, and
#   version information
#-------------------------------------------------------------------------------
function displayDotnetBuildSummary()
{
    local -i _rc=$success

    (( $# == 1 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires exactly one argument (provided $#): the name of an associative array containing build information."
    }

    [[ -v 1 ]] && is_defined_associative_array "$1" || {
        _rc="$err_invalid_nameref"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing build information (provided '${1-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local -n _build_info=$1

    local _build_result=${_build_info[$key_build_result]:-Unknown}

    local _errors_count=${_build_info[$key_errors_count]:-0}
    local _warnings_count=${_build_info[$key_warnings_count]:-0}

    local _assembly_version=${_build_info[$key_assembly_version]:-N/A}
    local _file_version=${_build_info[$key_file_version]:-N/A}
    local _informational_version=${_build_info[$key_informational_version]:-N/A}
    local _version=${_build_info[$key_version]:-N/A}
    local _package_version=${_build_info[$key_package_version]:-N/A}

    echo "Build Results"
    dump_vars --force --quiet \
        --header "Dotnet Build Summary:" \
        _build_result \
        --line \
        _errors_count \
        _warnings_count \
        --header "Version Information:" \
        _assembly_version \
        _file_version \
        _version \
        _package_version \
        _informational_version

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
# @arg $1 string csproj - required path to the *.csproj file
# @arg $2 string artifacts - optional path to the root artifacts directory where the stages should put their outputs
#   (default: "<src>/<proj.dir>/bin")
# @arg $3 string configuration - optional build configuration, if not specified, will read it from $1 - the csproj, or from the
#   nearest Directory.Build.props, or the default: in CI - Release, otherwise Debug. If specified, #2 also MUST be specified
#
# @exitcode 0 ($success) the assembly file exists and is not empty
# @exitcode 1 ($failure) the assembly path was resolved but the file does not exist yet (the path is still written to stdout)
# @exitcode 2 ($err_invalid_arguments) wrong number of arguments
# @exitcode 4 ($err_argument_value) the argument is empty or not a valid, existing *.csproj file
#
# @stdout the full path to the produced assembly, e.g.:
#   /path/to/repo/src/proj/bin/Debug/net10.0/vm2.Ulid.dll or
#   /path/to/repo/artifacts/build/proj/Debug/net10.0/vm2.Ulid.dll
#
# @example
#   path=$(get_assembly_path src/vm2.Ulid/Ulid.csproj build $ARTIFACTS_DIR Release)
#-------------------------------------------------------------------------------
function get_assembly_path() {
    local -i _rc="$success"

    (( $# >= 1 && $# <= 4 )) || {
        _rc="$err_invalid_arguments"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires one, two, or three arguments (provided $#):" \
                              " 1) the path to a *.csproj file" \
                              " 2) the path to the artifacts directory (optional)" \
                              " 3) build configuration (optional)"
    }

    [[ -v 1 && -s $1 && $1 == @(*.csproj) ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 1 - the project to build - to be an existing, non-empty .csproj file (provided '${1-<missing>}')."
    }
    [[ -v 2 && -n $2 ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 2 - the artifacts directory, if specified, to be a non-empty string (provided '${2-<missing>}')."
    }
    [[ -v 3 && ${3^} == @(Release|Debug) ]] || {
        _rc="$err_argument_value"
        error -sd 3 -ec "$_rc" "${FUNCNAME[0]}() requires argument 3 - the build configuration, if specified, to be either 'Release' or 'Debug' (provided '${3-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _csproj="$1"
    local _artifacts="${2:-}"
    local _build_configuration="${3:-}"

    _csproj=$(realpath -e "$1")
    trace "Resolving assembly path for project: $_csproj"

    local _proj_dir
    _proj_dir=$(dirname "$_csproj")
    _proj_name=$(basename "$_csproj" ".$_suffix")
    trace "Project directory and name:" "$_proj_dir" "$_proj_name"

    # Find the nearest Directory.Build.props by walking up from the project directory
    local _dir_build_props=""
    local _search_dir="$_proj_dir"
    while [[ "$_search_dir" != / ]]; do
        if [[ -f "$_search_dir/Directory.Build.props" ]]; then
            _dir_build_props="$_search_dir/Directory.Build.props"
            break
        fi
        _search_dir=$(dirname "$_search_dir")
    done
    trace "Nearest 'Directory.Build.props': ${_dir_build_props:-None}"

    # TFM: *.csproj → Directory.Build.props → "net10.0"
    local _tfm=""
    _tfm=$(grep -oPm1 '(?<=<TargetFramework>)[^<]+' "$_csproj" 2>"$_ignore") ||
    _tfm=$(grep -oPm1 '(?<=<TargetFrameworks>)[^<]+' "$_csproj" 2>"$_ignore") || true

    if [[ -z "$_tfm" && -n "$_dir_build_props" ]]; then
        _tfm=$(grep -oPm1 '(?<=<TargetFramework>)[^<]+' "$_dir_build_props" 2>"$_ignore") ||
        _tfm=$(grep -oPm1 '(?<=<TargetFrameworks>)[^<]+' "$_dir_build_props" 2>"$_ignore") || true
    fi

    if [[ "$_tfm" == *";"* ]]; then
        warning "Multiple TFMs found in '$(basename "$_csproj")'. Using the last one: '${_tfm##*;}'."
        _tfm="${_tfm##*;}"
    fi
    [[ -n "$_tfm" ]] || _tfm=$default_tfm
    _tfm="${_tfm//[[:space:]]/}"
    trace "Using TFM: $_tfm"

    # Configuration: *.csproj → Directory.Build.props → $default_configuration
    if [[ -z $_build_configuration ]]; then
        _build_configuration=$(grep -oPm1 '(?<=<Configuration>)[^<]+' "$_csproj" 2>"$_ignore") || true
        if [[ -z "$_build_configuration" && -n "$_dir_build_props" ]]; then
            _build_configuration=$(grep -oPm1 '(?<=<Configuration>)[^<]+' "$_dir_build_props" 2>"$_ignore") || true
        fi
        _build_configuration=${_build_configuration:-${default_configuration}}
    fi
    _build_configuration="${_build_configuration//[[:space:]]/}"
    _build_configuration="${_build_configuration^}"
    trace "Using Configuration: $_build_configuration"

    # AssemblyName: *.csproj → filename without extension
    local _assembly_name=""
    _assembly_name=$(grep -oPm1 '(?<=<AssemblyName>)[^<]+' "$_csproj" 2>"$_ignore") || true
    [[ -n "$_assembly_name" ]] || _assembly_name=$(basename "${_csproj%.*}")
    _assembly_name="${_assembly_name//[[:space:]]/}"
    trace "Using AssemblyName: $_assembly_name"

    # OutputType: *.csproj → Directory.Build.props → default_output_type - determines the file suffix
    local _output_type=""
    _output_type=$(grep -oPm1 '(?<=<OutputType>)[^<]+' "$_csproj" 2>"$_ignore") || true
    if [[ -z "$_output_type" && -n "$_dir_build_props" ]]; then
        _output_type=$(grep -oPm1 '(?<=<OutputType>)[^<]+' "$_dir_build_props" 2>"$_ignore") || true
    fi
    _output_type="${_output_type//[[:space:]]/}"
    _output_type="${_output_type:-${defaultOutputType}}"

    local _suffix
    if [[ "${_output_type,,}" == "exe" ]]; then
        is_windows && _suffix=".exe" || _suffix=""
    else
        _suffix=".dll"
    fi
    trace "Using 'OutputType': ${_output_type:-None} → suffix: '$_suffix'"

    local _output_dir

    [[ -n "$_artifacts" ]] &&
        _output_dir="${_artifacts%/}/build/$_proj_name" ||
        _output_dir="$_proj_dir/bin" # the default output directory if no artifacts directory is specified

    trace "Assembly path: $_output_dir/$_build_configuration/$_tfm/$_assembly_name$_suffix"

    echo "$_output_dir/$_build_configuration/$_tfm/$_assembly_name$_suffix"
}
