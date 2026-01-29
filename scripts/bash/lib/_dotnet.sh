# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

## Summarizes the output of a 'dotnet build -v d ...' command.
##  Parameters:
##    The redirected output of the 'dotnet build -v d ...' command, e.g. 'dotnet build -v d ... | summarizeDotnetBuild | to_summary'
function summarizeDotnetBuild()
{
    local build_result='Unknown'
    local warnings_count
    local errors_count
    local assembly_version
    local file_version
    local informational_version
    local version
    local package_version
    local minver_version

    restoreShopt=$(shopt -p nocasematch)
    shopt -s nocasematch

    local built=false
    local line
    while IFS= read -r line; do
        if [[ $built == false ]]; then
            if [[ $line =~ Build\ (succeeded)|(FAILED) ]]; then
                built=true
                # shellcheck disable=SC2034
                build_result="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
            fi
            continue
        elif [[ -z $warnings_count && $line =~ ([0-9]+)\ Warning ]]; then
            warnings_count=${BASH_REMATCH[1]}
            continue
        elif [[ -z $errors_count && $line =~ ([0-9]+)\ Error ]]; then
            errors_count=${BASH_REMATCH[1]}
            continue
        elif [[ $build_result == FAILED ]]; then
            # in case of failed build, we stop processing after errors count
            assembly_version='N/A'
            file_version='N/A'
            informational_version='N/A'
            version='N/A'
            package_version='N/A'
            minver_version='N/A'
            break
        elif [[ -z $assembly_version && $line =~ AssemblyVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            assembly_version=${BASH_REMATCH[1]}
            continue
        elif [[ -z $file_version && $line =~ FileVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            file_version=${BASH_REMATCH[1]}
            continue
        elif [[ -z $informational_version && $line =~ InformationalVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            informational_version=${BASH_REMATCH[1]}
            continue
        elif [[ -z $version && $line =~ Version:\ ([[:alnum:][:punct:]]+) ]]; then
            version=${BASH_REMATCH[1]}
            continue
        elif [[ -z $package_version && $line =~ PackageVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            package_version=${BASH_REMATCH[1]}
            continue
        elif [[ -z $minver_version && $line =~ MinVerVersion:\ ([[:alnum:][:punct:]]+) ]]; then
            minver_version=${BASH_REMATCH[1]}
            continue
        fi
    done

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
        informational_version \
        minver_version

    return 0
}
