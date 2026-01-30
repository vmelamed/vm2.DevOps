# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# export variables to hold the results
declare -x build_result='Unknown'
declare -x warnings_count=''
declare -x errors_count=''
declare -x assembly_version=''
declare -x file_version=''
declare -x informational_version=''
declare -x version=''
declare -x package_version=''

## Summarizes the output of a 'dotnet build -v d ...' command.
##  Parameters:
##    The redirected output of the 'dotnet build -v d ...' command, e.g. 'dotnet build -v d ... | summarizeDotnetBuild | to_summary'
function summarizeDotnetBuild()
{
    restoreShopt=$(shopt -p nocasematch)
    shopt -s nocasematch

    local line
    while IFS= read -r line; do
        if [[ $line =~ Build\ (succeeded)|(FAILED) ]]; then
            build_result="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
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

    if [[ $build_result == FAILED ]]; then
        assembly_version='N/A'
        file_version='N/A'
        informational_version='N/A'
        version='N/A'
        package_version='N/A'
    fi

    # shellcheck disable=SC2154 # _ignore is referenced but not assigned.
    eval "$restoreShopt" &> "$_ignore"

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

    return 0
}
