# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_DOTNET_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_DOTNET_SH_LOADED=1

declare -rxi success

# export variables to hold the results
declare -x build_result="Unknown"
declare -x warnings_count=''
declare -x errors_count=''
declare -x assembly_version=''
declare -x file_version=''
declare -x informational_version=''
declare -x version=''
declare -x package_version=''

#-------------------------------------------------------------------------------
# Summary: Extracts build information from the output of a 'dotnet build -v d' command.
# Parameters: none (reads from stdin)
# Returns:
#   stdout: key=value pairs of build information
#   Exit code: 0 always
# Side Effects: Sets global exported variables: $build_result, $warnings_count, $errors_count,
#               $assembly_version, $file_version, $informational_version, $version, $package_version
# Caution: The values of the global variables are only valid after this function has been called and the input has been fully
#          read if and only if it is ran in the current shell context not piped or in a subshell.
#-------------------------------------------------------------------------------
function extractDotnetBuildInfo()
{
    # reset the globals
    build_result="Unknown"
    warnings_count=''
    errors_count=''
    assembly_version=''
    file_version=''
    informational_version=''
    version=''
    package_version=''

    local restoreShopt
    restoreShopt=$(shopt -p nocasematch) || true
    shopt -s nocasematch

    local line
    while IFS= read -r line; do
        echo "$line"
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
        rc=$?
        if [[ $rc -ne 0 ]]; then
            build_result="FAILED"
        fi
    done

    if [[ $build_result == FAILED ]]; then
        assembly_version='N/A'
        file_version='N/A'
        informational_version='N/A'
        version='N/A'
        package_version='N/A'
    fi

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
# Summary: Displays a formatted summary of the build information extracted by extractDotnetBuildInfo.
# Parameters: none (reads from stdin)
# Returns:
#   stdout: formatted table of build summary via dump_vars
#   Exit code: 0 always
# Side Effects: Sets global exported variables: $build_result, $warnings_count, $errors_count,
#               $assembly_version, $file_version, $informational_version, $version, $package_version
#-------------------------------------------------------------------------------
function displayDotnetBuildSummary()
{
    local build_result="Unknown"
    local warnings_count=''
    local errors_count=''
    local assembly_version=''
    local file_version=''
    local informational_version=''
    local version=''
    local package_version=''

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
                warning "Unrecognized variable: $var"
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
