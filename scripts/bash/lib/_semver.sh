# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC1091 # Disable warnings for word splitting and globbing issues in the following source commands.

#=============================================================================================
# This script defines functions and regular expressions for working with semantic versions (SemVer) and MinVer tags.
# It includes functions for validating and comparing semantic versions, parsing version components.
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_SEMVER_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_SEMVER_SH_LOADED=1

declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value

declare -x _ignore

if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
fi

if ! declare -pF "error" > "$_ignore"; then
    source "$lib_dir/_diagnostics.sh"
fi

# Regular expressions that test if a string contains a semantic version:
declare -xr majorLabelRex='[0-9]+'
declare -xr minorLabelRex='[0-9]+'
declare -xr patchLabelRex='[0-9]+'
declare -xr prereleaseLabelRex='[-0-9A-Za-z.]+'
declare -xr buildLabelRex='[-0-9A-Za-z.]+'

declare -xr semverReleaseRex="($majorLabelRex)\\.($minorLabelRex)\\.($patchLabelRex)(\\+$buildLabelRex)?"
declare -xr semverPrereleaseRex="($majorLabelRex)\\.($minorLabelRex)\\.($patchLabelRex)(-$prereleaseLabelRex)(\\+$buildLabelRex)?"
declare -xr semverRex="($majorLabelRex)\\.($minorLabelRex)\\.($patchLabelRex)(-$prereleaseLabelRex)?(\\+$buildLabelRex)?"

# Regular expressions that test if a string is exactly a semantic version:
declare -xr semverRegex="^$semverRex$"
declare -xr semverReleaseRegex="^$semverReleaseRex$"
declare -xr semverPrereleaseRegex="^$semverPrereleaseRex$"

# Regular expressions that test if a string contains a MinVer tag prefix and MinVerDefaultPrereleaseIds (MinverPrereleaseId)
declare -xr minverTagPrefixRex='[0-9A-Za-z_]([-0-9A-Za-z._/]*[-A-Za-z_])?'
declare -xr minverPrereleaseIdRex=$prereleaseLabelRex

# Regular expressions that test if a string is a MinVer tag prefix and MinVerDefaultPrereleaseIds (MinverPrereleaseId)
declare -xr minverTagPrefixRegex="^$minverTagPrefixRex$"
declare -xr minverPrereleaseIdRegex="^$minverPrereleaseIdRex$"

# Regular expressions that test if a string contains a git tag with semantic version and MinVer prefix (e.g. v1.2.3-alpha.3)
declare -xr semverTagRex="$minverTagPrefixRex$semverRex"
declare -xr semverTagPrereleaseRex="$minverTagPrefixRex$semverPrereleaseRex"
declare -xr semverTagReleaseRex="$minverTagPrefixRex$semverReleaseRex"

# Regular expressions that test if a string is a git tag with semantic version (e.g. v1.2.3-alpha.3)
declare -xr semverTagRegex="^$minverTagPrefixRex$semverRex$"
declare -xr semverTagPrereleaseRegex="^$minverTagPrefixRex$semverPrereleaseRex$"
declare -xr semverTagReleaseRegex="^$minverTagPrefixRex$semverReleaseRex$"

#---------------------------------------------------------------------------------------------
# @description Dumps the SemVer/MinVer regular expression constants to stdout, grouped by
#   category, via `dump_vars`.
#
# @noargs
#
# @stdout Formatted table of the regex constants (see `dump_vars`).
#
# @example
#   print_semver_regexes
#---------------------------------------------------------------------------------------------
function print_semver_regexes()
{
    dump_vars \
    --quiet \
    --force \
    --header "Semantic Version Components" \
    majorLabelRex \
    minorLabelRex \
    patchLabelRex \
    prereleaseLabelRex \
    buildLabelRex \
    --header "Semantic Versions" \
    semverPrereleaseRex \
    semverReleaseRex \
    semverRex \
    --header "Semantic Version/MinVer Tags" \
    semverTagRegex \
    semverTagReleaseRegex \
    semverTagPrereleaseRegex
}

#---------------------------------------------------------------------------------------------
# @description Validates the MinVer tag prefix and (optionally) the MinVer prerelease
#   identifier template against their expected regular expressions.
#
# Notes:
#   - Unlike most other `validate_*` functions in this codebase, this one takes plain string
#     values, not nameref-s.
#
# @arg $1 string The MinVer tag prefix (e.g., "v", "ver.", "release-").
# @arg $2 string The MinVer default prerelease identifier template (e.g., "preview.0", as in
#   1.2.3-preview.11). Optional.
#
# @exitcode success/positive=0: Both arguments (or just the prefix, if $2 is omitted) are valid.
#
# @example
#   validate_semverTagComponents "v" "preview.0"
#---------------------------------------------------------------------------------------------
function validate_semverTagComponents()
{
    (( $# == 1 || $# == 2 ))                                || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires one or two arguments (provided $#):" \
                                                                                                "  - the SemVer tag prefix used by MinVer" \
                                                                                                "  - default prerelease identifier template, optional"
    [[ ! -v 1 || $1 =~ $minverTagPrefixRegex ]]             || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the MinVer tag prefix, to match '$minverTagPrefixRegex' (provided '${1:-<none>}'). Did you pass a variable name instead of its value?"
    [[ ! -v 2 || -z $2 || $2 =~ $minverPrereleaseIdRegex ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires optional argument 2, the MinVer prerelease identifier template, to match '$minverPrereleaseIdRegex' (provided '${2:-<none>}'). Did you pass a variable name instead of its value?"

    exit_if_has_bugs
}

# semver components indexes in BASH_REMATCH
declare -xri semver_major=1
declare -xri semver_minor=2
declare -xri semver_patch=3
declare -xri semver_prerelease=4
declare -xri semver_build=5

declare -xri success
declare -xri failure

# RETURN CODES THAT SHOULD NOT BE REUSED FOR OTHER PURPOSES:
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value

# comparison result constants
declare -xri rc_equal=$success
declare -xri rc_greater_than=1
declare -xri rc_less_than=255

#---------------------------------------------------------------------------------------------
# @description Compares two semantic versions according to the Semantic
#   Versioning 2.0.0 specification.
#
# Notes:
#   - Build metadata is ignored in comparisons, per the semver spec.
#
# @arg $1 string The first semantic version to compare.
# @arg $2 string The second semantic version to compare.
#
# @exitcode rc_equal=0/success: version1 == version2.
# @exitcode rc_greater_than=1/failure: version1 > version2.
# @exitcode rc_less_than=255: version1 < version2.
#
# @example
#   compare_semver "1.2.3" "1.2.4"
#   case $? in
#     "$rc_less_than")     echo "1.2.3 < 1.2.4" ;;
#     "$rc_equal")         echo "equal" ;;
#     "$rc_greater_than")  echo "1.2.3 > 1.2.4" ;;
#     * )                  error -ec $? -ds 3 "Error comparing versions" ;;
#   esac
#---------------------------------------------------------------------------------------------
function compare_semver()
{
    (( $# == 2 ))                      || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                            "  - the first semantic versions to compare" \
                                                                            "  - second semantic versions to compare"
    [[ ! -v 1 || $1 =~ $semverRegex ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid Semantic Versioning 2.0.0 string (provided '${1:-<none>}')."
    [[ ! -v 2 || $2 =~ $semverRegex ]] || bug -ec "$err_argument_value" "${FUNCNAME[0]}() requires argument 2 to be a valid Semantic Versioning 2.0.0 string (provided '${2:-<none>}')."

    exit_if_has_bugs

    if [[ "$1" == "$2" ]]; then
        return "$rc_equal"
    fi

    [[ "$1" =~ $semverRegex ]]
    local -i _major1=${BASH_REMATCH[$semver_major]}
    local -i _minor1=${BASH_REMATCH[$semver_minor]}
    local -i _patch1=${BASH_REMATCH[$semver_patch]}
    local _prerelease1=${BASH_REMATCH[$semver_prerelease]#-}
    # local build1=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    [[ "$2" =~ $semverRegex ]]
    local -i _major2=${BASH_REMATCH[$semver_major]}
    local -i _minor2=${BASH_REMATCH[$semver_minor]}
    local -i _patch2=${BASH_REMATCH[$semver_patch]}
    local _prerelease2=${BASH_REMATCH[$semver_prerelease]#-}
    # local build2=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    if (( _major1 != _major2 )); then
        if (( _major1 > _major2 )); then
            return "$rc_greater_than"
        else
            return "$rc_less_than"
        fi
    elif (( _minor1 != _minor2 )); then
        if (( _minor1 > _minor2 )); then
            return "$rc_greater_than"
        else
            return "$rc_less_than"
        fi
    elif (( _patch1 != _patch2 )); then
        if (( _patch1 > _patch2 )); then
            return "$rc_greater_than"
        else
            return "$rc_less_than"
        fi
    elif [[ -z "$_prerelease1" && -n "$_prerelease2" ]]; then
        return "$rc_greater_than"
    elif [[ -n "$_prerelease1" && -z "$_prerelease2" ]]; then
        return "$rc_less_than"
    elif [[ -z "$_prerelease1" && -z "$_prerelease2" ]]; then
        return "$rc_equal"
    fi

    local -a _pre1 _pre2

    IFS='.' read -r -a _pre1 <<< "$_prerelease1"
    IFS='.' read -r -a _pre2 <<< "$_prerelease2"

    local _len1=${#_pre1[@]}
    local _len2=${#_pre2[@]}
    local -i _min_len=$(( _len1 < _len2 ? _len1 : _len2 ))
    local -i _seg_index

    for (( _seg_index=0; _seg_index < _min_len; _seg_index++ )); do
        local _p1=${_pre1[_seg_index]}
        local _p2=${_pre2[_seg_index]}
        if is_natural "$_p1"; then
            if is_natural "$_p2"; then
                local -i _n1=$_p1 _n2=$_p2
                if (( _n1 != _n2 )); then
                    if (( _n1 > _n2 )); then
                        trace "Version '$1' is greater than '$2' because its prerelease identifier ($_n1) is greater than prerelease identifier of '$2' ($_n2)."
                        return "$rc_greater_than"
                    else
                        trace "Version '$1' is less than '$2' because its prerelease identifier ($_n1) is less than prerelease identifier of '$2' ($_n2)."
                        return "$rc_less_than"
                    fi
                fi
            else
                trace "Version '$1' is less than '$2' because its prerelease identifier ($_p1) is less than prerelease identifier of '$2' ($_p2)."
                return "$rc_less_than"
            fi
        else
            if is_natural "$_p2"; then
                trace "Version '$1' is greater than '$2' because its prerelease identifier ($_p1) is greater than prerelease identifier of '$2' ($_p2)."
                return "$rc_greater_than"
            fi
        fi
        if [[ "$_p1" != "$_p2" ]]; then
            if [[ "$_p1" > "$_p2" ]]; then
                trace "Version '$1' is greater than '$2' because its prerelease identifier ($_p1) is greater than prerelease identifier of '$2' ($_p2)."
                return "$rc_greater_than"
            else
                trace "Version '$1' is less than '$2' because its prerelease identifier ($_p1) is less than prerelease identifier of '$2' ($_p2)."
                return "$rc_less_than"
            fi
        fi
    done

    if (( _len1 != _len2 )); then
        if (( _len1 > _len2 )); then
            trace "Version '$1' is greater than '$2' because it has more prerelease identifiers ($_len1 vs $_len2)."
            return "$rc_greater_than"
        else
            trace "Version '$1' is less than '$2' because it has fewer prerelease identifiers ($_len1 vs $_len2)."
            return "$rc_less_than"
        fi
    fi

    trace "Version '$1' is equal to '$2' because all components are equal."
    return "$rc_equal"
}

#---------------------------------------------------------------------------------------------
# @description Tests whether two semantic versions are equal.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode success/positive=0: version1 == version2.
# @exitcode failure/negative=1: version1 != version2.
#
# @example
#   if semver_equal "1.2.3" "1.2.3"; then echo "Versions are equal"; fi
#---------------------------------------------------------------------------------------------
function semver_equal()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_equal )); then
        return "$success"
    elif (( _rc == rc_greater_than || _rc == rc_less_than )); then
        return "$failure"
    else
        # Unreachable in practice: compare_semver() exits the process (via bug/exit_if_has_bugs)
        # on invalid input rather than returning an error code to us.
        return "$_rc"
    fi
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the first semantic version is greater than the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode success/positive=0: version1 > version2.
# @exitcode failure/negative=1: version1 <= version2.
#
# @example
#   if semver_greaterThan "1.2.3" "1.2.2"; then echo "Version 1 is greater"; fi
#---------------------------------------------------------------------------------------------
function semver_greaterThan()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_greater_than )); then
        return "$success"
    elif (( _rc == rc_equal || _rc == rc_less_than )); then
        return "$failure"
    else
        # Unreachable in practice: compare_semver() exits the process (via bug/exit_if_has_bugs)
        # on invalid input rather than returning an error code to us.
        return "$_rc"
    fi
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the first semantic version is greater than or equal to the
#   second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode success/positive=0: version1 >= version2.
# @exitcode failure/negative=1: version1 < version2.
#
# @example
#   if semver_greaterThanOrEqual "1.2.3" "1.2.2"; then echo "Version 1 is greater or equal"; fi
#---------------------------------------------------------------------------------------------
function semver_greaterThanOrEqual()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_equal || _rc == rc_greater_than )); then
        return "$success"
    elif (( _rc == rc_less_than )); then
        return "$failure"
    else
        # Unreachable in practice: compare_semver() exits the process (via bug/exit_if_has_bugs)
        # on invalid input rather than returning an error code to us.
        return "$_rc"
    fi
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the first semantic version is less than the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode success/positive=0: version1 < version2.
# @exitcode failure/negative=1: version1 >= version2.
#
# @example
#   if semver_lessThan "1.2.3" "1.2.4"; then echo "Version 1 is less"; fi
#---------------------------------------------------------------------------------------------
function semver_lessThan()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_less_than )); then
        return "$success"
    elif (( _rc == rc_equal || _rc == rc_greater_than )); then
        return "$failure"
    else
        # Unreachable in practice: compare_semver() exits the process (via bug/exit_if_has_bugs)
        # on invalid input rather than returning an error code to us.
        return "$_rc"
    fi
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the first semantic version is less than or equal to the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode success/positive=0: version1 <= version2.
# @exitcode failure/negative=1: version1 > version2.
#
# @example
#   if semver_lessThanOrEqual "1.2.3" "1.2.4"; then echo "Version 1 is less or equal"; fi
#---------------------------------------------------------------------------------------------
function semver_lessThanOrEqual()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_equal || _rc == rc_less_than )); then
        return "$success"
    elif (( _rc == rc_greater_than )); then
        return "$failure"
    else
        # Unreachable in practice: compare_semver() exits the process (via bug/exit_if_has_bugs)
        # on invalid input rather than returning an error code to us.
        return "$_rc"
    fi
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semantic version (SemVer 2.0.0 format).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups. Index into it with
#     `$semver_major`, `$semver_minor`, `$semver_patch`, `$semver_prerelease`, and
#     `$semver_build`.
#
# @arg $1 string The string to test.
#
# @exitcode success/positive=0: A valid semver.
# @exitcode failure/negative=1: Not a valid semver.
#
# @example
#   if is_semver "$version"; then
#     major=${BASH_REMATCH[$semver_major]}
#     minor=${BASH_REMATCH[$semver_minor]}
#   fi
#---------------------------------------------------------------------------------------------
function is_semver()
{
    __test_with_regex "$@" "$semverRegex"
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver tag (with the configured MinVer
#   prefix).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#   - `$semverTagRegex` is set once at file-load time from the fixed placeholder pattern
#     `$minverTagPrefixRex`.
#
# @arg $1 string The git tag string to test.
#
# @exitcode success/positive=0: A valid semver tag.
# @exitcode failure/negative=1: Not a valid semver tag.
#
# @example
#   validate_semverTagComponents "v"
#   if is_semverTag "v1.2.3"; then echo "Valid tag"; fi
#---------------------------------------------------------------------------------------------
function is_semverTag()
{
    __test_with_regex "$@" "$semverTagRegex"
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver prerelease version.
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#
# @arg $1 string The string to test.
#
# @exitcode success/positive=0: A valid semver prerelease.
# @exitcode failure/negative=1: Not a valid semver prerelease.
#
# @example
#   if is_semverPrerelease "1.2.3-alpha.1"; then echo "Valid prerelease"; fi
#---------------------------------------------------------------------------------------------
function is_semverPrerelease()
{
    __test_with_regex "$@" "$semverPrereleaseRegex"
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver prerelease tag (with the
#   configured MinVer prefix).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#   - `$semverTagPrereleaseRegex` is set once at file-load time from the fixed placeholder
#     pattern `$minverTagPrefixRex`.
#
# @arg $1 string The git tag string to test.
#
# @exitcode success/positive=0: A valid semver prerelease tag.
# @exitcode failure/negative=1: Not a valid semver prerelease tag.
#
# @example
#   validate_semverTagComponents "v"
#   if is_semverPrereleaseTag "v1.2.3-beta.2"; then echo "Valid prerelease tag"; fi
#---------------------------------------------------------------------------------------------
function is_semverPrereleaseTag()
{
    __test_with_regex "$@" "$semverTagPrereleaseRegex"
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver release version (without a
#   prerelease identifier).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#
# @arg $1 string The string to test.
#
# @exitcode success/positive=0: A valid semver release version.
# @exitcode failure/negative=1: Not a valid semver release version.
#
# @example
#   if is_semverRelease "1.2.3"; then echo "Valid release version"; fi
#---------------------------------------------------------------------------------------------
function is_semverRelease()
{
    __test_with_regex "$@" "$semverReleaseRegex"
}

#---------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver release tag (with the configured
#   MinVer prefix, no prerelease identifier).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#   - `$semverTagReleaseRegex` is set once at file-load time from the fixed placeholder
#     pattern `$minverTagPrefixRex`.
#
# @arg $1 string The git tag string to test.
#
# @exitcode success/positive=0: A valid semver release tag.
# @exitcode failure/negative=1: Not a valid semver release tag.
#
# @example
#   validate_semverTagComponents "v"
#   if is_semverReleaseTag "v1.2.3"; then echo "Valid release tag"; fi
#---------------------------------------------------------------------------------------------
function is_semverReleaseTag()
{
    __test_with_regex "$@" "$semverTagReleaseRegex"
}
