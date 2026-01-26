# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x build_result
declare -x warnings_count
declare -x errors_count
declare -x assembly_version
declare -x file_version
declare -x informational_version
declare -x version
declare -x package_version

## Summarizes the output of a 'dotnet build -v d ...' command.
##  Parameters:
##    $1 - The output of the 'dotnet build -v d ...' command, e.g. captured via command substitution
##         'build_output=$(dotnet build -v d ...)'
##  Sets the following global variables for later use:
##    build_result
##    warnings_count
##    errors_count
##    assembly_version
##    file_version
##    informational_version
##    version
##    package_version
function summarizeDotnetBuild()
{
    if [[ $# -eq 0 || -z "$1" ]]; then
        echo "summarizeDotnet requires the output of 'dotnet build -v d ...' as a parameter"
        return 1
    fi
    local bo="$1"
    local build_result

    restoreShopt=$(shopt -p nocasematch)
    shopt -s nocasematch

    regex="Build (succeeded)|(FAILED)"
    [[ $bo =~ $regex ]]
    [[ ${BASH_REMATCH[1]} == "succeeded" ]] && build_result="Successful" || build_result="Failed"

    regex="([0-9]+) Warning(s)?"
    [[ $bo =~ $regex ]]
    warnings_count=${BASH_REMATCH[1]}

    regex="([0-9]+) Error(s)?"
    [[ $bo =~ $regex ]]
    errors_count=${BASH_REMATCH[1]}

    if [[ $build_result == "Successful" ]]; then

        regex="AssemblyVersion: ([^ ]*)"
        [[ $bo =~ $regex ]]
        assembly_version=${BASH_REMATCH[1]}

        regex="FileVersion: ([^ ]*)"
        [[ $bo =~ $regex ]]
        file_version=${BASH_REMATCH[1]}

        regex="InformationalVersion: ([^ ]*)"
        [[ $bo =~ $regex ]]
        informational_version=${BASH_REMATCH[1]}

        regex=" Version: ([^ ]*)"
        [[ $bo =~ $regex ]]
        version=${BASH_REMATCH[1]}

        regex="PackageVersion: ([^ ]*)"
        [[ $bo =~ $regex ]]
        package_version=${BASH_REMATCH[1]}
    fi

    echo "Build result:        $build_result"
    echo "Errors:              $errors_count"
    echo "Warnings:            $warnings_count"
    if [[ $build_result == "Successful" ]]; then
        echo "Assembly Version:     $assembly_version"
        echo "File Version:         $file_version"
        echo "InformationalVersion: $informational_version"
        echo "Version:              $version"
        echo "PackageVersion:       $package_version"
    fi

    # shellcheck disable=SC2154 # _ignore is referenced but not assigned.
    eval "$restoreShopt" &> "$_ignore"
}
