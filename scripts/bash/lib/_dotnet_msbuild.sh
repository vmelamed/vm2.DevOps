# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_DOTNET_MSBUILD_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_DOTNET_MSBUILD_SH_LOADED=1

declare -xri success
declare -xri failure
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_argument_type
declare -xri err_invalid_nameref
declare -xri err_missing_argument
declare -xri err_tool_error
declare -xri err_not_found

declare -xr ci
declare -xr warn_em
declare -xr bug_prefix

declare -x _ignore

# Build keys used in the build and build result associative arrays:
declare -xr key_project
declare -xr key_configuration
declare -xr key_target_frameworks
declare -xr key_target_framework
declare -xr key_runtime_identifier
declare -xr key_platform
declare -xr key_artifacts_path
declare -xr key_artifacts_project_name


# Build keys used in the build and build result associative arrays:
declare -xr key_project
declare -xr key_configuration
declare -xr key_target_frameworks
declare -xr key_target_framework
declare -xr key_runtime_identifier
declare -xr key_platform
declare -xr key_artifacts_path
declare -xr key_artifacts_project_name

declare -xr key_build_result
declare -xr key_errors_count
declare -xr key_warnings_count
declare -xr key_target_path
declare -xr key_exit_code
declare -xr key_exit_message

declare -xr key_assembly_version
declare -xr key_file_version
declare -xr key_informational_version
declare -xr key_version

declare -xr key_package_output_path
declare -xr key_package_version
declare -xr key_package_id

declare -xa build_info_keys

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
# @description Gets the value of a single MSBuild property for a .NET project, via
#   `dotnet msbuild -getProperty:<Prop>`, without building the project (a static evaluation).
#   Use `get_msbuild_properties()` instead when two or more properties are needed in one call.
#
# @arg $1 string _csproj - path to a .csproj file
# @arg $2 string property_name - the name of the property whose value should be retrieved
# @arg $3 nameref to a variable to receive the value of the property
#
# @exitcode success=0: the property value was retrieved successfully.
# @exitcode err_argument_value=4: argument 1 is not an existing, non-empty project file.
# @exitcode N propagated from `convert_dotnet_args_to_msbuild_args()` on failure, or the raw
#   exit code of `dotnet msbuild` itself if it fails (not translated to `err_tool_error` here).
#
# @example
#   declare target_path
#   get_msbuild_property "$project" "$key_target_path" target_path
#---------------------------------------------------------------------------------------------
function get_msbuild_property()
{
    (( $# == 3 ))                                                               || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 3 arguments (provided $#):" \
                                                                                                                    "  - path to a .csproj file" \
                                                                                                                    "  - name of the property whose value should be retrieved" \
                                                                                                                    "  - nameref to a variable to receive the value of the property"
    [[ ! -v 2 ]] || is_variable_name "$2"                                       || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2, the name of the property whose value should be retrieved, to be a valid property name (provided '${2-<missing>}')."
    [[ ! -v 3 ]] || is_variable "$3"                                            || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 3, the name of a variable to receive the value of the property, to be a defined variable (provided '${3-<missing>}')."
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ $1 == *.csproj && -s $1 ]]                                               || with_error "$err_argument_value" _rc "${FUNCNAME[0]}() requires argument 1 to be an existing project file path (provided '${1-<missing>}')."
    (( _rc == "$success" ))                                                     || return "$_rc"

    local _project="$1"
    local -a _dotnet_args
    _dotnet_args=(
        "$_project"
        --no-logo
        --verbosity minimal
        "-getProperty:$2" # put the MSBuild command that gets the property in the msbuild arguments - dis is da secret sauce!
    )
    # add the common dotnet parameters
    [[ -z $configuration ]]        || _dotnet_args+=("--configuration" "$configuration")
    [[ -z $framework ]]            || _dotnet_args+=("--framework" "$framework")
    [[ -z $runtime ]]              || _dotnet_args+=("--runtime" "$runtime")
    [[ -z $artifacts ]]            || _dotnet_args+=("--artifacts-path" "$artifacts")
    [[ -z $minver_tag_prefix ]]    || _dotnet_args+=("-property:MinVerTagPrefix=\"$minver_tag_prefix\"")
    [[ -z $minver_prerelease_id ]] || _dotnet_args+=("-property:MinVerPrereleaseIdentifiers=\"$minver_prerelease_id\"")
    [[ -z $preprocessor_symbols ]] || _dotnet_args+=("-property:preprocessor_symbols=\"$preprocessor_symbols\"")

    local -a _msbuild_args=()
    convert_dotnet_args_to_msbuild_args _msbuild_args "${_dotnet_args[@]}"      || return "$?"

    local -n _property=$3
    _property=$(dotnet msbuild "${_msbuild_args[@]}" 2> "$_ignore")             || with_error "$err_tool_error" _rc "Executing MSBuild for '$_project' failed." -dec "$?"

    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Gets the values of two or more MSBuild properties for a .NET project, via
#   `dotnet msbuild -getProperty:<Prop1>;<Prop2>;...`, without building the project (a static
#   evaluation). Use `get_msbuild_property()` instead when only one property is needed --
#   `dotnet msbuild` returns a plain string for a single `-getProperty`, but a JSON object
#   (`{"Properties": {...}}`) once two or more are requested, so the two cases need different
#   parsing and are kept as separate functions rather than one with divergent output shapes.
#
# @arg $1 string _csproj - path to a .csproj file
# @arg $2 nameref to an associative-array variable to receive the property name/value pairs
# @arg $3..$@ string names of the properties whose values should be retrieved (at least 2 --
#   use `get_msbuild_property()` for exactly 1)
#
# @exitcode success=0: the properties were retrieved successfully.
# @exitcode err_argument_value=4: an invalid property name was given.
#
# @example
#   declare -A props
#   get_msbuild_properties "$project" props TargetPath Configuration ArtifactsPath
#---------------------------------------------------------------------------------------------
function get_msbuild_properties()
{
    (( $# > 3 ))                                                                || bug  "${FUNCNAME[0]}() requires at least 4 arguments (provided $#):" \
                                                                                        "  - path to a .csproj file" \
                                                                                        "  - nameref to an associative-array variable to receive the property name/value pairs" \
                                                                                        "  - names of two or more properties whose values should be retrieved"  -ec "$err_invalid_arguments"
    [[ ! -v 2 ]] || is_associative_array "$2"                                   || bug  "${FUNCNAME[0]}() requires argument 2, the name of an associative array variable to receive the property names and values (provided '${2-<missing>}')." -ec "$err_argument_value"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ $1 == *.csproj && -s $1 ]]                                               || with_error "$err_argument_value" _rc "${FUNCNAME[0]}() requires argument 1 to be a project or solution file path (provided '${1-<missing>}')."
    (( _rc == "$success" ))                                                     || return "$_rc"

    local _project="$1"
    # shellcheck disable=SC2178 # Variable was used as an array but is now assigned a string.
    local -n _properties=$2

    local _property
    local _all_properties=''
    local _first=true
    local _errs
    _errs=$(get_errors)

    shift 2
    for _property in "$@"; do
        is_variable_name "$_property"                                           || error "${FUNCNAME[0]}() requires all property names to be valid variable names (provided '$_property')." -ec "$err_argument_value"
        $_first && _first=false || _all_properties+=';'
        _all_properties+="$_property"
    done

    (( _errs != $(get_errors) )) && return "$err_argument_value"

    local -a _dotnet_args
    _dotnet_args=(
        "$_project"
        --no-logo
        --verbosity minimal
        "-getProperty:$_all_properties" # put the MSBuild command that gets the property in the msbuild arguments - this is da secret sauce!
    )
    # add the common dotnet parameters
    [[ -z $configuration ]]        || _dotnet_args+=("--configuration" "$configuration")
    [[ -z $framework ]]            || _dotnet_args+=("--framework" "$framework")
    [[ -z $runtime ]]              || _dotnet_args+=("--runtime" "$runtime")
    [[ -z $artifacts ]]            || _dotnet_args+=("--artifacts-path" "$artifacts")
    [[ -z $minver_tag_prefix ]]    || _dotnet_args+=("-property:MinVerTagPrefix=\"$minver_tag_prefix\"")
    [[ -z $minver_prerelease_id ]] || _dotnet_args+=("-property:MinVerPrereleaseIdentifiers=\"$minver_prerelease_id\"")
    [[ -z $preprocessor_symbols ]] || _dotnet_args+=("-property:preprocessor_symbols=\"$preprocessor_symbols\"")

    local -a _msbuild_args=()
    convert_dotnet_args_to_msbuild_args _msbuild_args "${_dotnet_args[@]}"      || return "$?"

    local _json=''
    _json=$(dotnet msbuild "${_msbuild_args[@]}" 2> "$_ignore")                 || return "$?"

    _properties=()

    local _key _value
    while IFS='=' read -r _key _value; do
        _properties["$_key"]="$_value"
    done < <(jq -r '.Properties | to_entries[] | "\(.key)=\(.value)"' <<< "$_json")
}

#---------------------------------------------------------------------------------------------
# @description Gets the full path to the assembly that was or would be produced by
#   `dotnet build` using a .NET project and the common dotnet arguments, without actually building
#   the project. A thin wrapper around `get_msbuild_property()` for the `TargetPath` property.
#
# @arg $1 string _csproj - path to a .csproj file
# @arg $2 nameref to a variable to receive the full path to the assembly that was or would be
#   produced
#
# @exitcode success=0: the target path was retrieved successfully.
# @exitcode N propagated unchanged from `get_msbuild_property()` on failure (see its own
#   @exitcode list).
#
# @example
#   declare target_path
#   get_target_path "$project" target_path
#---------------------------------------------------------------------------------------------
function get_target_path()
{
    (( $# == 2 ))                                                               || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                    "  - path to a .csproj file" \
                                                                                                                    "  - nameref to a variable to receive the full path to the assembly that was or would be produced"
    [[ ! -v 2 ]] || is_variable "$2"                                            || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2, the variable name to receive the full path to the assembly, to be a defined variable (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    get_msbuild_property "$1" "$key_target_path" "$2"
}

#---------------------------------------------------------------------------------------------
# @description Gets the full path to the `ArtifactsPath` directory for a .NET project or
#   solution, using the common dotnet arguments, without actually building the project.
#
# Notes:
#   - ArtifactsPath is uniform across an entire repo (set once via UseArtifactsOutput=true in the
#     root Directory.Build.props), so when $1 is a solution (*.sln/*.slnx) -- which MSBuild itself
#     has no notion of evaluating properties against, only a project's -- this resolves it to one
#     representative project via list_solution_projects() (preferring a project under src/) and
#     evaluates the property against that instead. Any real project in the solution would report
#     the identical answer.
#
# @arg $1 string _csproj - path to a .csproj, .sln, or .slnx file
# @arg $2 nameref to a variable to receive the full, absolute path to the `ArtifactsPath`
#   directory
#
# @exitcode success=0: the artifacts path was retrieved and is an absolute path.
# @exitcode err_not_found: the resolved artifacts path is empty or not an absolute path (the
#   project does not use the artifacts output layout -- see CONVENTIONS.md).
# @exitcode N propagated from `list_solution_projects()` (for a solution input) or from
#   `get_msbuild_property()` on failure.
#
# @example
#   declare artifacts_path
#   get_artifacts_path "$project" artifacts_path
#---------------------------------------------------------------------------------------------
function get_artifacts_path()
{
    (( $# == 2 ))                                                               || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 2 arguments (provided $#):" \
                                                                                                                    "  - path to a .csproj, .sln, or .slnx file" \
                                                                                                                    "  - nameref to a variable to receive the full path to the assembly that was or would be produced"
    [[ ! -v 2 ]] || is_variable "$2"                                            || bug -ec "$err_argument_value"    "${FUNCNAME[0]}() requires argument 2, the variable name to receive the full path to the assembly, to be a defined variable (provided '${2-<missing>}')."
                                                                                exit_if_has_bugs

    local -n _artifacts=$2
    local _project="$1"

    if [[ $1 == *.@(sln|slnx) ]]; then
        local -a _solution_projects=()
        list_solution_projects "$1" _solution_projects                          || return "$?"
        _project="${_solution_projects[0]}"
    fi

    get_msbuild_property "$_project" "$key_artifacts_path" "$2"

    local -i _rc=$success

    [[ -n $_artifacts && $_artifacts == /* ]]                                   || with_error "$err_not_found" _rc "Failed to get correct artifacts path for '$1'. Please use artifacts output layout in your Directory.Build.props. See CONVENTIONS.md"
    return "$_rc"
}

#---------------------------------------------------------------------------------------------
# @description Converts the `dotnet <command>` arguments in the arguments $2..$N to the
#   corresponding `dotnet msbuild` arguments, e.g., converts `"--configuration" "Release"` to
#   `"--property:Configuration=Release"` based on the `dotnet_args_to_msbuild_args` mapping.
#   The converted results are placed in the output $1 array.
#
# @arg $1 nameref to the array variable in which MSBuild arguments and properties will be
#   placed
# @arg $@ string the `dotnet <command>` arguments to be converted to MSBuild arguments and
#   properties
#
# @exitcode success=0: All arguments were converted successfully.
# @exitcode err_missing_argument=6: An option that requires a value (e.g. `--configuration`) was
#   the last argument, with no value following it.
# @exitcode err_argument_type=3: An option that has been removed from `dotnet` in favor of
#   another (e.g. `--os`/`--arch` in favor of `--runtime`) was used.
#---------------------------------------------------------------------------------------------
function convert_dotnet_args_to_msbuild_args()
{
    (( $# > 1 ))                                                                || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires more than one, arguments (provided $#):" \
                                                                                                                    "  - the name of the array variable to receive the MSBuild arguments" \
                                                                                                                    "  - the 'dotnet <command>' arguments to be converted"
    [[ ! -v 1 ]] || is_indexed_array "$1"                                       || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be the name of an indexed array variable to which the build arguments will be added (provided '${1-<missing>}')."
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
    local -i _rc=$success

    trace "Converting 'dotnet <restore/build/pack>...' arguments to 'dotnet msbuild ...' arguments."
    while (( $# > 0 )); do
        _dot_option=$1
        shift
        # if the curr.param is project file or directory - add it as is
        [[ $_dot_option == *.@(csproj|slnx|sln) || -d $_dot_option ]] &&
            _msb_args+=("$_dot_option") &&
            trace "  Added '$_dot_option' - project, solution, or directory." &&
            continue

        # if the current dotnet option is not mapped to any MSBuild argument,
        # add it as is - most likely it is already a "-p:<prop>=<value>" passed to dotnet directly
        [[ ! -v dotnet_args_to_msbuild_args[$_dot_option] ]] &&
            _msb_args+=("$_dot_option") &&
            trace "  Added '$_dot_option' as is." &&
            continue

        # get the replacement string for the current dotnet option
        _replacement=${dotnet_args_to_msbuild_args[$_dot_option]}

        if [[ $_replacement == *%s* ]]; then
            # this option needs an argument - the next argument is used as its value
            (( $# != 0 ))                                                       || with_error "$err_missing_argument" _rc "Missing argument for option '$_dot_option'"
            (( _rc == success ))                                                || return "$_rc"
            # consume the next argument as the value for the current MSBuild property
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

            # process the instruction part: it may contain special directives like @remove, @warning, or @error:
            [[ $_part == @remove* ]]  && _remove=true                                           && continue # remove this option all together
            [[ $_part == @warning* ]] && warning "${_part#@warning}"                            && continue # report a warning and skip this part
            [[ $_part == @error* ]]   && with_error "$err_argument_type" _rc "${_part#@error}"  && return "$_rc" # report and return an error


            # or it is a format string for printf with a single argument - _arg, printf into $_msb_option
            # shellcheck disable=SC2059 # Don't use variables in the printf format string.
            printf -v _msb_option -- "$_part" "$_arg"
        done

        # the MSBuild option has been constructed, add it to the list of MSBuild arguments if it is not marked for removal
        if [[ -n $_msb_option ]] && ! $_remove; then
            _msb_args+=("$_msb_option")
            trace "  Replaced '$_dot_option $_arg' with '$_msb_option'."
        else
            trace "  $warn_em Removed '$_dot_option $_arg'"
        fi
    done
}

declare -xr property_value_rex='^[[:space:]]*([[:alpha:]_][[:alnum:]_]*)=(.*)$'
declare -xr build_result_rex='^[[:space:]]*Build (succeeded|FAILED).*$'
declare -xr count_errors_rex='^[[:space:]]*([0-9]+) (Error|Warning).*$'

#---------------------------------------------------------------------------------------------
# @description Extracts build information from the output of a 'dotnet build' command and
#   populates the specified associative array with the results at keys from the
#   `$build_info_keys` array. For a solution (not a single *.csproj), the per-project keys
#   (`TargetPath`, `PackageId`, `ArtifactsProjectName`) are removed afterward, since a solution
#   build reports them once per constituent project and only the last one read would otherwise
#   be kept, which would misleadingly look like a single, authoritative answer.
#
# @arg $1 string _project_file The project or solution file path for which the build
#   information is being extracted
# @arg $2 int _build_result The result code from 'dotnet build'
# @arg $3 nameref _extracted The name of an associative array variable to receive the build
#   information
#
# @stdin The standard input from which to read the build output, e.g. dotnet build --verbosity
#   minimal
#
# @exitcode success=0: The build information was extracted (always, once past the argument
#   validation gate).
# @exitcode err_argument_value=4: argument 1 is not an existing, non-empty project or solution
#   file.
#---------------------------------------------------------------------------------------------
function extract_dotnet_build_info()
{
    (( $# == 3 ))                                                               || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly three arguments (provided $#):" \
                                                                                                                    "  - the project or solution file path for which the build information is being extracted" \
                                                                                                                    "  - the result code from 'dotnet build'" \
                                                                                                                    "  - the name of an associative array variable to receive the build information"
    [[ ! -v 2 ]] || is_non_negative "$2"                                        || bug -ec "$err_argument_type" "${FUNCNAME[0]}() requires argument 2 to be an exit code - non-negative number (provided '${2-<missing>}')."
    [[ ! -v 3 ]] || is_associative_array "$3"                                   || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 3 to name an associative array that will receive build information (provided '${3-<missing>}')."
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ $1 == *.@(slnx|sln|csproj) && -s $1 ]]                                   || with_error "$err_argument_value" _rc "${FUNCNAME[0]}() requires argument 1 to be a project or solution file path (provided '${1-<missing>}')."
    (( _rc == success ))                                                        || return "$_rc"

    local _project_file="$1"
    local _build_result="$2"
    local -n _extracted=$3

    # shellcheck disable=SC2004 # Variable: key_project, key_exit_code, key_exit_message, key_build_result, key_warnings_count, key_errors_count - defined elsewhere
    _extracted=(
        [$key_project]="$_project_file"
        [$key_exit_code]=$2
        [$key_exit_message]=$(dotnet_error_message "$2")
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
    while IFS= read -r _line || [[ -n $_line ]]; do
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
        # override each other - not useful. ArtifactsProjectName is per-project too (defaults to each
        # project's own MSBuildProjectName), so the last one seen in the build output would silently and
        # misleadingly look like a single answer -- callers that need every constituent project's own
        # ArtifactsProjectName for a solution build must enumerate them via list_solution_projects() and
        # query each one individually (e.g. via get_msbuild_property()), not read it from here.
        unset "_extracted[$key_target_path]"
        unset "_extracted[$key_package_id]"
        unset "_extracted[$key_artifacts_project_name]"
    fi

    restore_state state
}

#---------------------------------------------------------------------------------------------
# @description Displays a formatted summary of build information stored in an associative
#   array (as populated by `extract_dotnet_build_info()`).
#
# @arg $1 nameref to an associative array variable holding the build information to display.
#
# @exitcode success=0: The function executed successfully.
#
# @stdout Formatted table (via dump_vars) with the build result, warning/error counts, version
#   information, packages, target paths, etc.
#---------------------------------------------------------------------------------------------
function display_dotnet_build_summary()
{
    (( $# == 1 ))                                                               || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one argument (provided $#):" \
                                                                                                                    "  - the name of an associative array variable containing the build information"
    [[ ! -v 1 ]] || is_associative_array "$1"                                   || bug -ec "$err_invalid_nameref" "${FUNCNAME[0]}() requires argument 1 to name an associative array containing build information (provided '${1-<missing>}')."
                                                                                exit_if_has_bugs

    local -n _build_info=$1

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

    local _tbl_fmt
    $ci && _tbl_fmt="--markdown" || _tbl_fmt="--graphical"

    local -a _dump_vars_args=(
        --force
        --quiet
        "$_tbl_fmt"
        --header "Configuration:"
        --name "Project"                    "${_build_info[$key_project]:-N/A}"
        --name "Configuration"              "${_build_info[$key_configuration]:-}"
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
