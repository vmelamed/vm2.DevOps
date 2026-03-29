# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -rxi success
declare -rxi failure
declare -rxi positive
declare -rxi negative
declare -rxi err_invalid_arguments
declare -rxi err_argument_type
declare -rxi err_argument_value

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
declare -xr minverTagPrefixRegex="^${minverTagPrefixRex}$"
declare -xr minverPrereleaseIdRegex="^${minverPrereleaseIdRex}$"

# Regular expressions that test if a string contains a git tag with semantic version and MinVer prefix (e.g. v1.2.3-alpha.3)
declare -rx semverTagRex="${minverTagPrefixRex}${semverRex}"
declare -rx semverTagPrereleaseRex="${minverTagPrefixRex}${semverPrereleaseRex}"
declare -rx semverTagReleaseRex="${minverTagPrefixRex}${semverReleaseRex}"

# Regular expressions that test if a string is a git tag with semantic version (e.g. v1.2.3-alpha.3)
declare -rx semverTagRegex="^${minverTagPrefixRex}${semverRex}$"
declare -rx semverTagPrereleaseRegex="^${minverTagPrefixRex}${semverPrereleaseRex}$"
declare -rx semverTagReleaseRegex="^${minverTagPrefixRex}${semverReleaseRex}$"

## Flag indicating whether the tag regexes have been initialized with default value for the tag prefix or with actual parameter
## 0 - actual, 1 - default
declare -xi tag_regexes_initialized=1

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

declare -x latest_stable
declare -x latest_prerelease

declare -x errors

#-------------------------------------------------------------------------------
# Summary: Validates MinVer tag prefix and creates tag validation regular expressions.
# Parameters:
#   1 - minver_tag_prefix (NOT nameref!) - the MinVer tag prefix (e.g., "v", "ver.", "release-")
#   2 - optional minver_prerelease_id (NOT nameref!) - the MinVer default prerelease identifier template (e.g., "preview.0") as in 1.2.3-preview.11
# Returns:
#   Exit code: 0 if valid prefix, 1 if invalid format, 2 on invalid arguments
# Side Effects: Sets global regex variables $semverTagRegex, $semverTagReleaseRegex, $semverTagPrereleaseRegex
# Usage: validate_semverTagComponents <minver_tag_prefix> <minver_prerelease_id_template>
# Example: validate_semverTagComponents "v" "preview.0"  # creates regexes for tags like v1.2.3-preview.0
# Notes: Call once when tag prefix is known. Sets tag_regexes_initialized=0 to indicate custom prefix. In contrast to other
# validate_* functions, this one takes a value not a nameref.
#-------------------------------------------------------------------------------
function validate_semverTagComponents()
{
    (( $# == 1 || $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires 1 or 2 arguments ($# provided): the semver tag prefix used by MinVer and the optional default prerelease identifier template."
        return "$err_invalid_arguments"
    }

    local errs=$errors

    [[ "$1" =~ $minverTagPrefixRegex ]]                     || error "The semver tag prefix used by MinVer ('$1') is not valid. It must match the regex: $minverTagPrefixRegex. Did you pass a nameref by mistake?"
    [[ $# -eq 1 || "$2" =~ $minverPrereleaseIdRegex ]]      || error "The semver prerelease identifier template used by MinVer ('$2') is not valid. It must match the regex: $minverPrereleaseIdRegex. Did you pass a nameref by mistake?"
    (( errors == errs ))
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
declare -irx rc_greater_than=64
declare -irx rc_less_than=65

#-------------------------------------------------------------------------------
# Summary: Compares two semantic versions according to semver 2.0.0 specification.
# Parameters:
#   1 - version1 - first semantic version to compare
#   2 - version2 - second semantic version to compare
# Returns:
#   Exit code:
#     $rc_equal (0) if version1 == version2
#     $rc_greater_than (64) if version1 > version2
#     $rc_less_than (65) if version1 < version2
#     $err_invalid_arguments (2) on invalid arguments
# Usage: compare_semver <version1> <version2>
# Example:
#   compare_semver "1.2.3" "1.2.4"
#   case $? in
#     $rc_less_than) echo "1.2.3 < 1.2.4" ;;
#     $rc_equal) echo "equal" ;;
#     $rc_greater_than) echo "1.2.3 > 1.2.4" ;;
#   esac
# Notes: Build metadata is ignored in comparisons per semver spec.
#-------------------------------------------------------------------------------
function compare_semver()
{
    local -i errs=$errors

    (( $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires at exactly 2 arguments (provided $#): version1 and version2."
        return "$err_invalid_arguments"
    }

    if [[ "$1" =~ $semverRegex ]]; then
        local -i major1=${BASH_REMATCH[$semver_major]}
        local -i minor1=${BASH_REMATCH[$semver_minor]}
        local -i patch1=${BASH_REMATCH[$semver_patch]}
        local prerelease1=${BASH_REMATCH[$semver_prerelease]#-}
    else
        error 3 "${FUNCNAME[0]}() requires the version1 argument to be a valid [Semantic Versioning 2.0.0](https://semver.org/) string."
    fi
    # local build1=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    if [[ "$2" =~ $semverRegex ]]; then
        local -i major2=${BASH_REMATCH[$semver_major]}
        local -i minor2=${BASH_REMATCH[$semver_minor]}
        local -i patch2=${BASH_REMATCH[$semver_patch]}
        local prerelease2=${BASH_REMATCH[$semver_prerelease]#-}
    else
        error 3 "${FUNCNAME[0]}() requires the version2 argument to be a valid [Semantic Versioning 2.0.0](https://semver.org/) string."
    fi
    # local build2=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    (( errors == errs )) || return "$err_argument_value"

    if (( major1 != major2 )); then
        if (( major1 > major2 )); then return "$rc_greater_than"; else return "$rc_less_than"; fi
    elif (( minor1 != minor2 )); then
        if (( minor1 > minor2 )); then return "$rc_greater_than"; else return "$rc_less_than"; fi
    elif (( patch1 != patch2 )); then
        if (( patch1 > patch2 )); then return "$rc_greater_than"; else return "$rc_less_than"; fi
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
    local -i i=0

    while (( i < min_len )); do
        p1=${pre1[i]}
        p2=${pre2[i]}
        if is_natural "$p1"; then
            if is_natural "$p2"; then
                local -i n1=$p1 n2=$p2
                if (( n1 != n2 )); then
                    if (( n1 > n2 )); then return "$rc_greater_than"; else return "$rc_less_than"; fi
                fi
            else
                return "$rc_less_than"
            fi
        else
            if is_natural "$p2"; then return "$rc_greater_than"; fi
        fi
        if [[ "$p1" != "$p2" ]]; then
            if [[ "$p1" > "$p2" ]]; then return "$rc_greater_than"; else return "$rc_less_than"; fi
        fi
        ((i++))
    done

    if (( len1 != len2 )); then
        if (( len1 > len2 )); then return "$rc_greater_than"; else return "$rc_less_than"; fi
    fi

    return "$rc_equal"
}

#-------------------------------------------------------------------------------
# Summary: Tests if two semantic versions are equal.
# Parameters:
#   1 - version1 - first semantic version string
#   2 - version2 - second semantic version string
# Returns:
#   Exit code: 0 if version1 == version2, 1 - otherwise, 2 on invalid arguments
# Usage: if semver_equals <version1> <version2>; then ... fi
# Example:
#   if semver_equals "1.2.3" "1.2.3"; then echo "Versions are equal"; fi
#-------------------------------------------------------------------------------
function semver_equals()
{
    (( $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
        return "$err_invalid_arguments"
    }
    semver_compare "$1" "$2"
    (( $? == rc_equal ))
}

#-------------------------------------------------------------------------------
# Summary: Tests if the first semantic version is greater than the second.
# Parameters:
#   1 - version1 - first semantic version string
#   2 - version2 - second semantic version string
# Returns:
#   Exit code: 0 if version1 > version2, 1 - otherwise, 2 on invalid arguments
# Usage: if semver_greaterThan <version1> <version2>; then ... fi
# Example:
#   if semver_greaterThan "1.2.3" "1.2.2"; then echo "Version 1 is greater"; fi
#-------------------------------------------------------------------------------
function semver_greaterThan()
{
    (( $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
        return "$err_invalid_arguments"
    }
    semver_compare "$1" "$2"
    (( $? == rc_greater_than ))
}

#-------------------------------------------------------------------------------
# Summary: Tests if the first semantic version is greater than or equal to the second.
# Parameters:
#   1 - version1 - first semantic version string
#   2 - version2 - second semantic version string
# Returns:
#   Exit code: 0 if version1 >= version2, 1 - otherwise, 2 on invalid arguments
# Usage: if semver_greaterThanOrEqual <version1> <version2>; then ... fi
# Example:
#   if semver_greaterThanOrEqual "1.2.3" "1.2.2"; then echo "Version 1 is greater or equal"; fi
#-------------------------------------------------------------------------------
function semver_greaterThanOrEqual()
{
    (( $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
        return "$err_invalid_arguments"
    }
    semver_compare "$1" "$2"
    rc=$?
    (( rc == rc_greater_than || rc == rc_equal ))
}

#-------------------------------------------------------------------------------
# Summary: Tests if the first semantic version is less than the second.
# Parameters:
#   1 - version1 - first semantic version string
#   2 - version2 - second semantic version string
# Returns:
#   Exit code: 0 if version1 < version2, 1 - otherwise, 2 on invalid arguments
# Usage: if semver_lessThan <version1> <version2>; then ... fi
# Example:
#   if semver_lessThan "1.2.3" "1.2.4"; then echo "Version 1 is less"; fi
#-------------------------------------------------------------------------------
function semver_lessThan()
{
    (( $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
        return "$err_invalid_arguments"
    }
    semver_compare "$1" "$2"
    (( $? == rc_less_than ))
}

#-------------------------------------------------------------------------------
# Summary: Tests if the first semantic version is less than or equal to the second.
# Parameters:
#   1 - version1 - first semantic version string
#   2 - version2 - second semantic version string
# Returns:
#   Exit code: 0 if version1 <= version2, 1 - otherwise, 2 on invalid arguments
# Usage: if semver_lessThanOrEqual <version1> <version2>; then ... fi
# Example:
#   if semver_lessThanOrEqual "1.2.3" "1.2.4"; then echo "Version 1 is less or equal"; fi
#-------------------------------------------------------------------------------
function semver_lessThanOrEqual()
{
    (( $# == 2 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#): version1 and version2."
        return "$err_invalid_arguments"
    }
    semver_compare "$1" "$2"
    rc=$?
    (( rc == rc_less_than || rc == rc_equal ))
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semantic version (semver 2.0.0 format).
# Parameters:
#   1 - version - string to test
# Returns:
#   Exit code: 0 if valid semver, 1 - otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semver <version>; then ... fi
# Example:
#   if is_semver "$version"; then
#     major=${BASH_REMATCH[$semver_major]}
#     minor=${BASH_REMATCH[$semver_minor]}
#   fi
# Notes: Use indexes $semver_major, $semver_minor, $semver_patch, $semver_prerelease, $semver_build with BASH_REMATCH.
#-------------------------------------------------------------------------------
function is_semver()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the version."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver tag (with configured prefix).
# Parameters:
#   1 - tag - git tag string to test
# Returns:
#   Exit code: 0 if valid semver tag, 1 otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverTag <tag>; then ... fi
# Example:
#   validate_semverTagComponents "v"
#   if is_semverTag "v1.2.3"; then echo "Valid tag"; fi
# Notes: Requires validate_semverTagComponents to be called first to set $semverTagRegex.
#-------------------------------------------------------------------------------
function is_semverTag()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the semver tag."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverTagRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver prerelease version.
# Parameters:
#   1 - version - string to test
# Returns:
#   Exit code: 0 if valid semver prerelease, 1 otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverPrerelease <version>; then ... fi
# Example: if is_semverPrerelease "1.2.3-alpha.1"; then echo "Valid prerelease"; fi
#-------------------------------------------------------------------------------
function is_semverPrerelease()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the semver prerelease."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverPrereleaseRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver prerelease tag (with configured prefix).
# Parameters:
#   1 - tag - git tag string to test
# Returns:
#   Exit code: 0 if valid semver prerelease tag, 1 otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverPrereleaseTag <tag>; then ... fi
# Example:
#   validate_semverTagComponents "v"
#   if is_semverPrereleaseTag "v1.2.3-beta.2"; then echo "Valid prerelease tag"; fi
# Notes: Requires validate_semverTagComponents to be called first to set $semverTagPrereleaseRegex.
#-------------------------------------------------------------------------------
function is_semverPrereleaseTag()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the semver prerelease tag."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverTagPrereleaseRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver release version (without prerelease identifier).
# Parameters:
#   1 - version - string to test
# Returns:
#   Exit code: 0 if valid semver release, 1 otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverRelease <version>; then ... fi
# Example: if is_semverRelease "1.2.3"; then echo "Valid release version"; fi
#-------------------------------------------------------------------------------
function is_semverRelease()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 argument (provided $#): the version."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverReleaseRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver release tag (with configured prefix, without prerelease).
# Parameters:
#   1 - tag - git tag string to test
# Returns:
#   Exit code: 0 if valid semver release tag, 1 otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverReleaseTag <tag>; then ... fi
# Example:
#   validate_semverTagComponents "v"
#   if is_semverReleaseTag "v1.2.3"; then echo "Valid release tag"; fi
# Notes: Requires validate_semverTagComponents to be called first to set $semverTagReleaseRegex.
#-------------------------------------------------------------------------------
function is_semverReleaseTag()
{
    (( $# == 1 )) || {
        error 3 "${FUNCNAME[0]}() requires exactly 1 argument: the semver release tag."
        return "$err_invalid_arguments"
    }
    [[ "$1" =~ $semverTagReleaseRegex ]]
}
