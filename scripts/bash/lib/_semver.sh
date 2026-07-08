# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines functions and regular expressions for working with semantic versions (SemVer) and MinVer tags.
# It includes functions for validating and comparing semantic versions, parsing version components.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_SEMVER_SH_LOADED:-0} == 1 )) && return 0
declare -gr __VM2_LIB_SEMVER_SH_LOADED=1

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value

if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
fi

# shellcheck disable=SC2154 # _ignore is referenced but not assigned.
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
declare -rx semverTagRex="$minverTagPrefixRex$semverRex"
declare -rx semverTagPrereleaseRex="$minverTagPrefixRex$semverPrereleaseRex"
declare -rx semverTagReleaseRex="$minverTagPrefixRex$semverReleaseRex"

# Regular expressions that test if a string is a git tag with semantic version (e.g. v1.2.3-alpha.3)
declare -rx semverTagRegex="^$minverTagPrefixRex$semverRex$"
declare -rx semverTagPrereleaseRegex="^$minverTagPrefixRex$semverPrereleaseRex$"
declare -rx semverTagReleaseRegex="^$minverTagPrefixRex$semverReleaseRex$"

function print_semver_regexes()
{
    dump_vars --quiet --force \
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
    semverTagPrereleaseRegex \

}

#-------------------------------------------------------------------------------
# @description Validates the MinVer tag prefix and (optionally) the MinVer prerelease identifier template against their
# expected regular expressions.
#
# Notes:
#   - Unlike most other `validate_*` functions in this codebase, this one takes plain string values, not nameref-s.
#
# @arg $1 string The MinVer tag prefix (e.g., "v", "ver.", "release-").
# @arg $2 string The MinVer default prerelease identifier template (e.g., "preview.0", as in 1.2.3-preview.11). Optional.
#
# @exitcode 0 Both arguments (or just the prefix, if $2 is omitted) are valid.
# @exitcode 2 One or both arguments are invalid, or the wrong number of arguments was provided.
#
# @example
#   validate_semverTagComponents "v" "preview.0"
#-------------------------------------------------------------------------------
function validate_semverTagComponents()
{
    local -i rc=$success

    (( $# == 1 || $# == 2 )) || {
        rc=$err_invalid_arguments
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires 1 or 2 arguments ($# provided): the semver tag prefix used by MinVer and the optional default prerelease identifier template."
    }

    (( rc == success )) || return "$err_invalid_arguments"

    [[ "$1" =~ $minverTagPrefixRegex ]]                     || {
        rc=$err_argument_value
        error -sd 3 -ec "$rc" "The semver tag prefix used by MinVer ('$1') is not valid. It must match the regex: $minverTagPrefixRegex. Did you pass a nameref by mistake?"
    }
    [[ $# -eq 1 || "$2" =~ $minverPrereleaseIdRegex ]]      || {
        rc=$err_argument_value
        error -sd 3 -ec "$err_argument_value" "The semver prerelease identifier template used by MinVer ('$2') is not valid. It must match the regex: $minverPrereleaseIdRegex. Did you pass a nameref by mistake?"
    }

    return "$rc"
}

# semver components indexes in BASH_REMATCH
declare -irx semver_major=1
declare -irx semver_minor=2
declare -irx semver_patch=3
declare -irx semver_prerelease=4
declare -irx semver_build=5

declare -rxi success
declare -rxi failure

# RETURN CODES THAT SHOULD NOT BE REUSED FOR OTHER PURPOSES:
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value

# comparison result constants
declare -irx rc_equal=$success
declare -irx rc_greater_than=1
declare -irx rc_less_than=255

#-------------------------------------------------------------------------------
# @description Compares two semantic versions according to the Semantic Versioning 2.0.0 specification.
#
# Notes:
#   - Build metadata is ignored in comparisons, per the semver spec.
#
# @arg $1 string The first semantic version to compare.
# @arg $2 string The second semantic version to compare.
#
# @exitcode 0 ($rc_equal) version1 == version2.
# @exitcode 1 ($rc_greater_than) version1 > version2.
# @exitcode 255 ($rc_less_than) version1 < version2.
# @exitcode 2 ($err_invalid_arguments) Wrong argument count.
# @exitcode 4 ($err_argument_value) Either version1 or version2 fails to match $semverRegex.
#
# @example
#   compare_semver "1.2.3" "1.2.4"
#   case $? in
#     "$rc_less_than")     echo "1.2.3 < 1.2.4" ;;
#     "$rc_equal")         echo "equal" ;;
#     "$rc_greater_than")  echo "1.2.3 > 1.2.4" ;;
#     * )                  error -ec $? -ds 3 "Error comparing versions" ;;
#   esac
#-------------------------------------------------------------------------------
function compare_semver()
{
    local -i rc=$success

    (( $# == 2 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires at exactly 2 arguments (provided $#): version1 and version2."
        return "$err_invalid_arguments"
    }

    (( rc == success )) || return "$err_invalid_arguments"

    if [[ "$1" == "$2" ]]; then
        return "$rc_equal"
    fi

    if [[ "$1" =~ $semverRegex ]]; then
        local -i major1=${BASH_REMATCH[$semver_major]}
        local -i minor1=${BASH_REMATCH[$semver_minor]}
        local -i patch1=${BASH_REMATCH[$semver_patch]}
        local prerelease1=${BASH_REMATCH[$semver_prerelease]#-}
    else
        rc=$err_invalid_arguments
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires the version1 argument to be a valid [Semantic Versioning 2.0.0](https://semver.org/) string."
    fi
    # local build1=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    if [[ "$2" =~ $semverRegex ]]; then
        local -i major2=${BASH_REMATCH[$semver_major]}
        local -i minor2=${BASH_REMATCH[$semver_minor]}
        local -i patch2=${BASH_REMATCH[$semver_patch]}
        local prerelease2=${BASH_REMATCH[$semver_prerelease]#-}
    else
        rc=$err_invalid_arguments
        error -sd 3 -ec "$rc" "${FUNCNAME[0]}() requires the version2 argument to be a valid [Semantic Versioning 2.0.0](https://semver.org/) string."
    fi
    # local build2=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    (( rc == success )) || return "$err_argument_value"

    if (( major1 != major2 )); then
        if (( major1 > major2 )); then
            return "$rc_greater_than"
        else
            return "$rc_less_than"
        fi
    elif (( minor1 != minor2 )); then
        if (( minor1 > minor2 )); then
            return "$rc_greater_than"
        else
            return "$rc_less_than"
        fi
    elif (( patch1 != patch2 )); then
        if (( patch1 > patch2 )); then
            return "$rc_greater_than"
        else
            return "$rc_less_than"
        fi
    elif [[ -z "$prerelease1" && -n "$prerelease2" ]]; then
        return "$rc_greater_than"
    elif [[ -n "$prerelease1" && -z "$prerelease2" ]]; then
        return "$rc_less_than"
    elif [[ -z "$prerelease1" && -z "$prerelease2" ]]; then
        return "$rc_equal"
    fi

    local -a pre1 pre2

    IFS='.' read -r -a pre1 <<< "$prerelease1"
    IFS='.' read -r -a pre2 <<< "$prerelease2"

    local len1=${#pre1[@]}
    local len2=${#pre2[@]}
    local -i min_len=$(( len1 < len2 ? len1 : len2 ))
    local -i seg_index

    for (( seg_index=0; seg_index < min_len; seg_index++ )); do
        p1=${pre1[seg_index]}
        p2=${pre2[seg_index]}
        if is_natural "$p1"; then
            if is_natural "$p2"; then
                local -i n1=$p1 n2=$p2
                if (( n1 != n2 )); then
                    if (( n1 > n2 )); then
                        trace "Version '$1' is greater than '$2' because its prerelease identifier ($n1) is greater than prerelease identifier of '$2' ($n2)."
                        return "$rc_greater_than"
                    else
                        trace "Version '$1' is less than '$2' because its prerelease identifier ($n1) is less than prerelease identifier of '$2' ($n2)."
                        return "$rc_less_than"
                    fi
                fi
            else
                trace "Version '$1' is less than '$2' because its prerelease identifier ($p1) is less than prerelease identifier of '$2' ($p2)."
                return "$rc_less_than"
            fi
        else
            if is_natural "$p2"; then
                trace "Version '$1' is greater than '$2' because its prerelease identifier ($p1) is greater than prerelease identifier of '$2' ($p2)."
                return "$rc_greater_than"
            fi
        fi
        if [[ "$p1" != "$p2" ]]; then
            if [[ "$p1" > "$p2" ]]; then
                trace "Version '$1' is greater than '$2' because its prerelease identifier ($p1) is greater than prerelease identifier of '$2' ($p2)."
                return "$rc_greater_than"
            else
                trace "Version '$1' is less than '$2' because its prerelease identifier ($p1) is less than prerelease identifier of '$2' ($p2)."
                return "$rc_less_than"
            fi
        fi
    done

    if (( len1 != len2 )); then
        if (( len1 > len2 )); then
            trace "Version '$1' is greater than '$2' because it has more prerelease identifiers ($len1 vs $len2)."
            return "$rc_greater_than"
        else
            trace "Version '$1' is less than '$2' because it has fewer prerelease identifiers ($len1 vs $len2)."
            return "$rc_less_than"
        fi
    fi

    trace "Version '$1' is equal to '$2' because all components are equal."
    return "$rc_equal"
}

#-------------------------------------------------------------------------------
# @description Tests whether two semantic versions are equal.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode 0 version1 == version2.
# @exitcode 1 version1 != version2.
# @exitcode 2 Wrong argument count.
# @exitcode 4 Either version1 or version2 is not a valid semver string (propagated from compare_semver).
#
# @example
#   if semver_equal "1.2.3" "1.2.3"; then echo "Versions are equal"; fi
#-------------------------------------------------------------------------------
function semver_equal()
{
    local -i rc=$rc_equal

    (( $# == 2 )) || {
        rc=err_invalid_arguments
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
    }

    (( rc == rc_equal )) || return "$err_invalid_arguments"

    compare_semver "$1" "$2" || rc=$?

    if (( rc == rc_equal )); then
        return "$success"
    elif (( rc == rc_greater_than || rc == rc_less_than )); then
        return "$failure"
    else
        # Propagate invalid-arguments error from compare_semver, or any other unexpected error code.
        return "$rc"
    fi
}

#-------------------------------------------------------------------------------
# @description Tests whether the first semantic version is greater than the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode 0 version1 > version2.
# @exitcode 1 version1 <= version2.
# @exitcode 2 Wrong argument count.
# @exitcode 4 Either version1 or version2 is not a valid semver string (propagated from compare_semver).
#
# @example
#   if semver_greaterThan "1.2.3" "1.2.2"; then echo "Version 1 is greater"; fi
#-------------------------------------------------------------------------------
function semver_greaterThan()
{
    local -i rc=$rc_equal

    (( $# == 2 )) || {
        rc=err_invalid_arguments
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
    }

    (( rc == rc_equal )) || return "$err_invalid_arguments"

    compare_semver "$1" "$2" || rc=$?

    if (( rc == rc_greater_than )); then
        return "$success"
    elif (( rc == rc_equal || rc == rc_less_than )); then
        return "$failure"
    else
        # Propagate invalid-arguments error from compare_semver, or any other unexpected error code.
        return "$rc"
    fi
}

#-------------------------------------------------------------------------------
# @description Tests whether the first semantic version is greater than or equal to the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode 0 version1 >= version2.
# @exitcode 1 version1 < version2.
# @exitcode 2 Wrong argument count.
# @exitcode 4 Either version1 or version2 is not a valid semver string (propagated from compare_semver).
#
# @example
#   if semver_greaterThanOrEqual "1.2.3" "1.2.2"; then echo "Version 1 is greater or equal"; fi
#-------------------------------------------------------------------------------
function semver_greaterThanOrEqual()
{
    local -i rc=$rc_equal

    (( $# == 2 )) || {
        rc=err_invalid_arguments
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
    }

    (( rc == rc_equal )) || return "$err_invalid_arguments"

    compare_semver "$1" "$2" || rc=$?

    if (( rc == rc_equal || rc == rc_greater_than )); then
        return "$success"
    elif (( rc == rc_less_than )); then
        return "$failure"
    else
        # Propagate invalid-arguments error from compare_semver, or any other unexpected error code.
        return "$rc"
    fi
}

#-------------------------------------------------------------------------------
# @description Tests whether the first semantic version is less than the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode 0 version1 < version2.
# @exitcode 1 version1 >= version2.
# @exitcode 2 Wrong argument count.
# @exitcode 4 Either version1 or version2 is not a valid semver string (propagated from compare_semver).
#
# @example
#   if semver_lessThan "1.2.3" "1.2.4"; then echo "Version 1 is less"; fi
#-------------------------------------------------------------------------------
function semver_lessThan()
{
    local -i rc=$rc_equal

    (( $# == 2 )) || {
        rc=err_invalid_arguments
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
    }

    (( rc == rc_equal )) || return "$err_invalid_arguments"

    compare_semver "$1" "$2" || rc=$?

    if (( rc == rc_less_than )); then
        return "$success"
    elif (( rc == rc_equal || rc == rc_greater_than )); then
        return "$failure"
    else
        # Propagate invalid-arguments error from compare_semver, or any other unexpected error code.
        return "$rc"
    fi
}

#-------------------------------------------------------------------------------
# @description Tests whether the first semantic version is less than or equal to the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode 0 version1 <= version2.
# @exitcode 1 version1 > version2.
# @exitcode 2 Wrong argument count.
# @exitcode 4 Either version1 or version2 is not a valid semver string (propagated from compare_semver).
#
# @example
#   if semver_lessThanOrEqual "1.2.3" "1.2.4"; then echo "Version 1 is less or equal"; fi
#-------------------------------------------------------------------------------
function semver_lessThanOrEqual()
{
    local -i rc=$rc_equal

    (( $# == 2 )) || {
        rc=err_invalid_arguments
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
    }

    (( rc == rc_equal )) || return "$err_invalid_arguments"

    compare_semver "$1" "$2" || rc=$?

    if (( rc == rc_equal || rc == rc_less_than )); then
        return "$success"
    elif (( rc == rc_greater_than )); then
        return "$failure"
    else
        # Propagate invalid-arguments error from compare_semver, or any other unexpected error code.
        return "$rc"
    fi
}

#-------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semantic version (SemVer 2.0.0 format).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups. Index into it with `$semver_major`, `$semver_minor`,
#     `$semver_patch`, `$semver_prerelease`, and `$semver_build`.
#
# @arg $1 string The string to test.
#
# @exitcode 0 A valid semver.
# @exitcode 1 Not a valid semver.
# @exitcode 2 Invalid arguments (wrong argument count).
#
# @example
#   if is_semver "$version"; then
#     major=${BASH_REMATCH[$semver_major]}
#     minor=${BASH_REMATCH[$semver_minor]}
#   fi
#-------------------------------------------------------------------------------
function is_semver()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the version."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverRegex ]]
}

#-------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver tag (with the configured MinVer prefix).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#   - `$semverTagRegex` is set once at file-load time from the fixed placeholder pattern `$minverTagPrefixRex`.
#
# @arg $1 string The git tag string to test.
#
# @exitcode 0 A valid semver tag.
# @exitcode 1 Not a valid semver tag.
# @exitcode 2 Invalid arguments (wrong argument count).
#
# @example
#   validate_semverTagComponents "v"
#   if is_semverTag "v1.2.3"; then echo "Valid tag"; fi
#-------------------------------------------------------------------------------
function is_semverTag()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the semver tag."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverTagRegex ]]
}

#-------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver prerelease version.
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#
# @arg $1 string The string to test.
#
# @exitcode 0 A valid semver prerelease.
# @exitcode 1 Not a valid semver prerelease.
# @exitcode 2 Invalid arguments (wrong argument count).
#
# @example
#   if is_semverPrerelease "1.2.3-alpha.1"; then echo "Valid prerelease"; fi
#-------------------------------------------------------------------------------
function is_semverPrerelease()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the semver prerelease."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverPrereleaseRegex ]]
}

#-------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver prerelease tag (with the configured MinVer prefix).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#   - `$semverTagPrereleaseRegex` is set once at file-load time from the fixed placeholder pattern `$minverTagPrefixRex`.
#
# @arg $1 string The git tag string to test.
#
# @exitcode 0 A valid semver prerelease tag.
# @exitcode 1 Not a valid semver prerelease tag.
# @exitcode 2 Invalid arguments (wrong argument count).
#
# @example
#   validate_semverTagComponents "v"
#   if is_semverPrereleaseTag "v1.2.3-beta.2"; then echo "Valid prerelease tag"; fi
#-------------------------------------------------------------------------------
function is_semverPrereleaseTag()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the semver prerelease tag."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverTagPrereleaseRegex ]]
}

#-------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver release version (without a prerelease identifier).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#
# @arg $1 string The string to test.
#
# @exitcode 0 A valid semver release version.
# @exitcode 1 Not a valid semver release version.
# @exitcode 2 Invalid arguments (wrong argument count).
#
# @example
#   if is_semverRelease "1.2.3"; then echo "Valid release version"; fi
#-------------------------------------------------------------------------------
function is_semverRelease()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the version."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverReleaseRegex ]]
}

#-------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver release tag (with the configured MinVer prefix, no
# prerelease identifier).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#   - `$semverTagReleaseRegex` is set once at file-load time from the fixed placeholder pattern `$minverTagPrefixRex`.
#
# @arg $1 string The git tag string to test.
#
# @exitcode 0 A valid semver release tag.
# @exitcode 1 Not a valid semver release tag.
# @exitcode 2 Invalid arguments (wrong argument count).
#
# @example
#   validate_semverTagComponents "v"
#   if is_semverReleaseTag "v1.2.3"; then echo "Valid release tag"; fi
#-------------------------------------------------------------------------------
function is_semverReleaseTag()
{
    (( $# == 1 )) || {
        error -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 1 argument: the semver release tag."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverTagReleaseRegex ]]
}
