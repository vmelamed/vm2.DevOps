# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_PREDICATES_TOOLS_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_PREDICATES_TOOLS_SH_LOADED=1

# vm2 core lib exit codes
declare -xri success
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_invalid_path
declare -xri err_tool_not_found
declare -xri err_tool_unauthenticated
declare -xri err_tool_version

# vm2 core lib constants
declare -xr ci
declare -x semverReleaseRex

# vm2 core lib variables
declare -x _ignore

declare -xr dotnet_min_version='10.0.404'
declare -xr jq_min_version='1.8.0'
declare -x git_min_version
declare -x gh_min_version

# `setup-repo.sh` is never run in CI and we can relax the ver. requirement but
# on a local dev. machine the user will run `setup-repo.sh` which requires 2.37 for `push.autoSetupRemote`
$ci && git_min_version='2.34.1' || git_min_version='2.37.0'

gh_min_version='2.32.0'

readonly git_min_version
readonly gh_min_version

#-----------------------------------------------------------------------------------------------
# @description Checks if a given tool is available on the `$PATH`.
#
# @arg $1 string Name of the tool to check.
#
# @exitcode positive=0: The tool is present.
# @exitcode negative=1: The tool is not present.
#-----------------------------------------------------------------------------------------------
function is_tool_present()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): the name of the tool to check" -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    command -v "$1" &>"$_ignore"
}

declare git_present=''

#-----------------------------------------------------------------------------------------------
# @description Checks if 'git' is available on the `$PATH` and if its version is greater than or
#   equal to `$git_min_version`. The result is cached and the errors are reported only on the
#   first run.
#
# @exitcode positive=0: 'git' is present.
# @exitcode negative=1: 'git' is not present.
#-----------------------------------------------------------------------------------------------
function is_git_present()
{
    (( $# == 0 ))                                                               || bug "${FUNCNAME[0]}() does not use arguments." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    if [[ -z $git_present ]]; then
        local -i _rc=$success
        local _ver=''

        is_tool_present git                                                     || with_error _rc "$err_tool_not_found" "'git' is not installed. Please install it: https://github.com/git-guides/install-git"
        (( _rc != success ))  || { _ver=$(git --version | grep -Eo "$semverReleaseRex") && \
                                semver_gte "$_ver" "$git_min_version"; }        || with_error _rc "$err_tool_version" "'git' version $git_min_version or greater is required. Please upgrade 'git': https://github.com/git-guides/install-git"
        (( _rc == success )) && git_present=true || git_present=false
        readonly git_present
    fi

    $git_present
}

declare gh_present=''

#-----------------------------------------------------------------------------------------------
# @description Checks if GitHub CLI 'gh' is available on the `$PATH`, its version is greater
#   than or equal to `$gh_min_version`, and if it is authenticated. The result is cached and
#   the errors are reported only on the first run.
#
# @exitcode positive=0: 'gh' is present.
# @exitcode negative=1: 'gh' is not present.
#-----------------------------------------------------------------------------------------------
function is_gh_present()
{
    (( $# == 0 ))                                                               || bug "${FUNCNAME[0]}() does not use arguments." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    if [[ -z $gh_present ]]; then
        local -i _rc=$success
        local _ver=''

        is_tool_present gh                                                      || with_error _rc "$err_tool_not_found" "'gh' is not installed. Please install it: https://cli.github.com/"
        (( _rc != success )) || { _ver=$(gh --version | grep -Eo "$semverReleaseRex" | head -n1) &&
                                semver_gte "$_ver" "$gh_min_version"; }         || with_error _rc "$err_tool_version" "'gh' version $gh_min_version or greater is required. Please upgrade 'gh': https://cli.github.com/"
        (( _rc != success )) || gh auth status &> "$_ignore"                    || with_error _rc "$err_tool_unauthenticated" "'gh' is not authenticated. Please run: 'gh auth login'"
        (( _rc == success )) && gh_present=true || gh_present=false
        readonly gh_present
    fi

    $gh_present
}

declare jq_present=''

#-----------------------------------------------------------------------------------------------
# @description Checks if 'jq' is available on the `$PATH` and its version is greater than or
#   equal to `$jq_min_version`. The result is cached and the errors are reported only on the
#   first run.
#
# @exitcode positive=0: 'jq' is present.
# @exitcode negative=1: 'jq' is not present.
#-----------------------------------------------------------------------------------------------
function is_jq_present()
{
    (( $# == 0 ))                                                               || bug "${FUNCNAME[0]}() does not use arguments." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    if [[ -z $jq_present ]]; then
        local -i _rc=$success
        local _ver=''

        is_tool_present jq                                                      || with_error _rc "$err_tool_not_found" "'jq' is not installed. Please install it: https://jqlang.org/download/"
        (( _rc != success )) || { _ver=$(jq --version | grep -Eo "$semverReleaseRex") && \
                                semver_gte "$_ver" "$jq_min_version"; }         || with_error _rc "$err_tool_version" "'jq' version $jq_min_version or greater is required. Please upgrade 'jq': https://jqlang.org/download/"
        (( _rc == success )) && jq_present=true || jq_present=false
        readonly jq_present
    fi

    $jq_present
}

declare check_jsonschema_present=''

#-----------------------------------------------------------------------------------------------
# @description Checks if 'check_jsonschema' is available on the `$PATH`. The result is cached
#   and the errors are reported only on the first run.
#
# @exitcode positive=0: 'check-jsonschema' is present.
# @exitcode negative=1: 'check-jsonschema' is not present.
#-----------------------------------------------------------------------------------------------
function is_check_jsonschema_present()
{
    (( $# == 0 ))                                                               || bug "${FUNCNAME[0]}() does not use arguments." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    if [[ -z $check_jsonschema_present ]]; then
        local -i _rc=$success
        local _ver=''

        if is_tool_present check-jsonschema; then
            check_jsonschema_present=true
        else
            check_jsonschema_present=false
            warning "'check-jsonschema' is not installed. Please install it with: pip install check-jsonschema" -ec "$err_tool_not_found"
        fi
        readonly check_jsonschema_present
    fi

    $check_jsonschema_present
}

declare yq_present=''

#-----------------------------------------------------------------------------------------------
# @description Checks if 'yq' is available on the `$PATH` and if it is a version by Mike Farah.
#   The result is cached and the errors are reported only on the first run.
#
# @exitcode positive=0: 'yq' is present.
# @exitcode negative=1: 'yq' is not present.
#-----------------------------------------------------------------------------------------------
function is_yq_present()
{
    (( $# == 0 ))                                                               || bug "${FUNCNAME[0]}() does not use arguments." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    if [[ -z $yq_present ]]; then
        local -i _rc=$success

        is_tool_present yq                                                      || with_error _rc "$err_tool_not_found" "'yq' is not installed. Please install 'yq' by Mike Farah: 'wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/.local/bin/yq4 && chmod +x ~/.local/bin/yq4'"
        (( _rc != success )) || [[ $(yq --version) =~ https://github\.com/mikefarah/yq/ ]] \
                                                                                || with_error _rc "$err_tool_version" "This script requires 'yq' by Mike Farah, e.g., 'wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/.local/bin/yq4 && chmod +x ~/.local/bin/yq4'"
        (( _rc == success )) && yq_present=true || yq_present=false
        readonly yq_present
    fi

    $yq_present
}

declare dotnet_present=''

#-----------------------------------------------------------------------------------------------
# @description Checks if 'dotnet' is available on the `$PATH` and its version is greater than or
#   equal to '$dotnet_min_version'. The result is cached and the errors are reported only on the
#   first run.
#
# @exitcode positive=0: 'dotnet' is present.
# @exitcode negative=1: 'dotnet' is not present.
#-----------------------------------------------------------------------------------------------
function is_dotnet_present()
{
    (( $# == 0 ))                                                               || bug "${FUNCNAME[0]}() does not use arguments." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    if [[ -z $dotnet_present ]]; then
        local -i _rc=$success
        local _ver=''

        is_tool_present dotnet                                                  || with_error _rc "$err_tool_not_found" "'dotnet' is not installed. Please install it: https://dotnet.microsoft.com/en-us/download"
        (( _rc != success )) || {
                                    _ver=$(dotnet --version) && \
                                    semver_gte "$_ver" "$dotnet_min_version";
                                }                                               || with_error _rc "$err_tool_version" "This script requires 'dotnet' version $dotnet_min_version. Please upgrade: https://dotnet.microsoft.com/en-us/download"
        (( _rc == success )) && dotnet_present=true || dotnet_present=false
        readonly dotnet_present
    fi

    $dotnet_present
}

#-----------------------------------------------------------------------------------------------
# @description Checks if a given string is valid JSON.
#
# @arg $1 string The JSON string to validate.
#
# @exitcode positive=0: The string is valid JSON.
# @exitcode negative=1: The string is not valid JSON.
#-----------------------------------------------------------------------------------------------
function is_valid_json()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the JSON string to validate." -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    jq empty <<< "$1" &> "$_ignore" && return "$positive" || return "$negative"
}

#-----------------------------------------------------------------------------------------------
# @description Checks if the file at a given path contains valid JSON.
#
# @arg $1 string Path to the file to validate.
#
# @exitcode positive=0: The file contains valid JSON.
# @exitcode negative=1: The file does not contain valid JSON.
#-----------------------------------------------------------------------------------------------
function is_valid_json_file()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires exactly one argument (provided $#): the JSON file to validate." -ec "$err_invalid_arguments"
    [[ ! -v 1 ]] || is_valid_path "$1"                                          || bug "${FUNCNAME[0]}() requires argument 1 to be a valid path (provided '${1-<missing>}')." -ec "$err_invalid_path"
                                                                                exit_if_has_bugs

    jq empty "$1" &> "$_ignore" && return "$positive" || return "$negative"
}
