# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# Circular include guard
(( ${__VM2_LIB_PREDICATES_TOOLS_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_PREDICATES_TOOLS_SH_LOADED=1

# vm2 core lib exit codes
declare -x success
declare -x positive
declare -x negative
declare -x err_invalid_arguments
declare -x err_invalid_path
declare -x err_tool_not_found
declare -x err_tool_unauthenticated
declare -x err_tool_version
declare -x err_tool_error

# vm2 core lib constants
declare -x ci
declare -x semverReleaseRex

# vm2 core lib variables
declare -x noise_sink

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
    (( $# == 1 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 argument (provided $#): the name of the tool to check."
                                                                                exit_if_has_bugs

    command -v "$1" &>"$noise_sink"
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
function verify_git()
{
    (( $# == 0 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires no arguments (provided $#)."
                                                                                exit_if_has_bugs

    if [[ -z $git_present ]]; then
        local -i _rc=$success
        local _ver=''

        is_tool_present git                                                     || with_error _rc "$err_tool_not_found" "'git' is not installed." "Install it from <https://github.com/git-guides/install-git>."
        (( _rc != success ))  || {
                                    _ver=$(git --version | grep -Eo "$semverReleaseRex") &&
                                    semver_gte "$_ver" "$git_min_version"; }    || with_error _rc "$err_tool_version" "Invalid 'git' version '$_ver': use '$git_min_version' or greater." "Upgrade it from <https://github.com/git-guides/install-git>."
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
function verify_gh()
{
    (( $# == 0 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires no arguments (provided $#)."
                                                                                exit_if_has_bugs

    if [[ -z $gh_present ]]; then
        local -i _rc=$success
        local _ver=''

        is_tool_present gh                                                      || with_error _rc "$err_tool_not_found" "'gh' is not installed." "Install it from <https://cli.github.com/>."
        (( _rc != success )) || _ver=$(gh --version | grep -Eo "$semverReleaseRex" | head -n1) \
                                                                                || with_error _rc "$err_tool_error" "Failed to get the version of 'gh'." "Reinstall it from <https://cli.github.com/>."
        (( _rc != success )) || is_semver_release "$_ver"                       || with_error _rc "$err_tool_version" "Invalid 'gh' version '$_ver': use a release version." "Install one from <https://cli.github.com/>."
        (( _rc != success )) || semver_gte "$_ver" "$gh_min_version"            || with_error _rc "$err_tool_version" "Invalid 'gh' version '$_ver': use '$gh_min_version' or greater." "Upgrade it from <https://cli.github.com/>."
        (( _rc != success )) || execute_with_retry --query --classify gh_failure \
                                    gh auth status &> "$noise_sink"             || with_error _rc "$err_tool_unauthenticated" "'gh' is not authenticated." "Run 'gh auth login'."
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
function verify_jq()
{
    (( $# == 0 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires no arguments (provided $#)."
                                                                                exit_if_has_bugs

    if [[ -z $jq_present ]]; then
        local -i _rc=$success
        local _ver=''

        is_tool_present jq                                                      || with_error _rc "$err_tool_not_found" "'jq' is not installed." "Install it from <https://jqlang.org/download/>."
        (( _rc != success )) || { _ver=$(jq --version | grep -Eo "$semverReleaseRex") && \
                                semver_gte "$_ver" "$jq_min_version"; }         || with_error _rc "$err_tool_version" "Invalid 'jq' version '$_ver': use '$jq_min_version' or greater." "Upgrade it from <https://jqlang.org/download/>."
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
function verify_check_jsonschema()
{
    (( $# == 0 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires no arguments (provided $#)."
                                                                                exit_if_has_bugs

    if [[ -z $check_jsonschema_present ]]; then
        if is_tool_present check-jsonschema; then
            check_jsonschema_present=true
        else
            check_jsonschema_present=false
            warning "'check-jsonschema' is not installed." "Install it: 'pip install check-jsonschema'." -ec "$err_tool_not_found"
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
function verify_yq()
{
    (( $# == 0 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires no arguments (provided $#)."
                                                                                exit_if_has_bugs

    if [[ -z $yq_present ]]; then
        local -i _rc=$success

        is_tool_present yq                                                      || with_error _rc "$err_tool_not_found" "'yq' is not installed." "Install Mike Farah's 'yq': 'wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/.local/bin/yq && chmod +x ~/.local/bin/yq'."
        (( _rc != success )) || [[ $(yq --version) =~ https://github\.com/mikefarah/yq/ ]] \
                                                                                || with_error _rc "$err_tool_version" "Invalid 'yq': it is not Mike Farah's 'yq'." "Install it: 'wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/.local/bin/yq && chmod +x ~/.local/bin/yq'."
        (( _rc == success )) && yq_present=true || yq_present=false
        readonly yq_present
    fi

    $yq_present
}

#-----------------------------------------------------------------------------------------------
# @description Checks if 'dotnet' is available on the `$PATH` and its version is compatible with
#   the project in the current repo.
#
# @exitcode positive=0: 'dotnet' is present.
# @exitcode negative=1: 'dotnet' is not present.
#-----------------------------------------------------------------------------------------------
function verify_dotnet()
{
    (( $# == 0 ))                                                               || bug "$err_invalid_arguments" "${FUNCNAME[0]}() requires no arguments (provided $#)."
                                                                                exit_if_has_bugs
    # no caching - has different answers in different cwd-s
    local -i _rc=$success
    local _output

    is_tool_present dotnet                                                      || with_error _rc "$err_tool_not_found" "'dotnet' is not installed." "Install it from <https://dotnet.microsoft.com/en-us/download>."
    (( _rc != success )) || _output=$(dotnet --version 2>&1)                    || with_error _rc "$err_tool_version" "Failed to find the .NET SDK that this directory requires." "$_output"
    (( _rc == success ))
}
