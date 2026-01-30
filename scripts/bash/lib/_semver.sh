# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed


# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir="$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")"
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

# Regular expressions that test if a string is a safe MinVer tag prefix and MinVerDefaultPrereleaseIds (MinverPrereleaseId)
declare -xr minverTagPrefixRex='[0-9A-Za-z_]([-0-9A-Za-z._/]*[-A-Za-z_])?'
declare -xr minverTagPrefixRegex="^$minverTagPrefixRex$"

declare -xr minverPrereleaseIdRex=$prereleaseLabelRex
declare -xr minverPrereleaseIdRegex="^$minverPrereleaseIdRex$"

# Regular expressions that test if a string is exactly a git tag with semantic version (e.g. v1.2.3)
declare -x semverTagRegex
declare -x semverTagReleaseRegex
declare -x semverTagPrereleaseRegex

## Flag indicating whether the tag regexes have been initialized with default value for the tag prefix or with actual parameter
## 0 - actual, 1 - default
declare -xi tag_regexes_initialized=1

#-------------------------------------------------------------------------------
# Summary: Validates MinVer tag prefix and creates tag validation regular expressions.
# Parameters:
#   1 - minver_tag_prefix - the MinVer tag prefix (e.g., "v", "ver.", "release-")
# Returns:
#   Exit code: 0 if valid prefix, 1 if invalid format, 2 on invalid arguments
# Side Effects: Sets global regex variables $semverTagRegex, $semverTagReleaseRegex, $semverTagPrereleaseRegex
# Usage: validate_minverTagPrefix <minver_tag_prefix>
# Example: validate_minverTagPrefix "v"  # creates regexes for tags like v1.2.3
# Notes: Call once when tag prefix is known. Sets tag_regexes_initialized=0 to indicate custom prefix. In contrast to other
# validate_* functions, this one takes a value not a nameref.
#-------------------------------------------------------------------------------
function validate_minverTagPrefix()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the semver tag prefix used by MinVer. Did you pass a nameref by mistake?"
        return 2
    fi

    local prefix="$1"

    if [[ ! "$prefix" =~ $minverTagPrefixRegex ]]; then
        error "The semver tag prefix used by MinVer ('$prefix') is not valid. It must match the regex: $minverTagPrefixRegex"
        return 1
    fi

    semverTagRegex="^${prefix}${semverRex}$"
    semverTagReleaseRegex="^${prefix}${semverReleaseRex}$"
    semverTagPrereleaseRegex="^${prefix}${semverPrereleaseRex}$"
}

# create the regexes with environment var prefix from $MINVERTAGPREFIX or the default 'v' for now, they should be re-created
# later by calling validate_minverTagPrefix with a different prefix
validate_minverTagPrefix "${MINVERTAGPREFIX:-"v"}"

# semver components indexes in BASH_REMATCH
declare -irx semver_major=1
declare -irx semver_minor=2
declare -irx semver_patch=3
declare -irx semver_prerelease=4
declare -irx semver_build=5

# comparison result constants
declare -irx isEq=0
declare -irx isGt=1
declare -irx isLt=3
declare -irx argsError=2

#-------------------------------------------------------------------------------
# Summary: Compares two semantic versions according to semver 2.0.0 specification.
# Parameters:
#   1 - version1 - first semantic version to compare
#   2 - version2 - second semantic version to compare
# Returns:
#   Exit code:
#     $isEq (0) if version1 == version2
#     $isGt (1) if version1 > version2
#     $isLt (3) if version1 < version2
#     $argsError (2) on invalid arguments
# Usage: compare_semver <version1> <version2>
# Example:
#   compare_semver "1.2.3" "1.2.4"
#   case $? in
#     $isLt) echo "1.2.3 < 1.2.4" ;;
#     $isEq) echo "equal" ;;
#     $isGt) echo "1.2.3 > 1.2.4" ;;
#   esac
# Notes: Build metadata is ignored in comparisons per semver spec.
#-------------------------------------------------------------------------------
function compare_semver()
{
    local -i e=0

    if [[ $# -ne 2 ]]; then
        error "${FUNCNAME[0]}() requires at exactly 2 arguments: version1 and version2." >&2
        e=$((e + 1))
    fi

    if [[ "$1" =~ $semverRegex ]]; then
        local -i major1=${BASH_REMATCH[$semver_major]}
        local -i minor1=${BASH_REMATCH[$semver_minor]}
        local -i patch1=${BASH_REMATCH[$semver_patch]}
        local prerelease1=${BASH_REMATCH[$semver_prerelease]#-}
    else
        error "${FUNCNAME[0]}() requires the version1 argument to be a valid [Semantic Versioning 2.0.0](https://semver.org/) string." >&2
        e=$((e + 1))
    fi
    # local build1=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    if [[ "$2" =~ $semverRegex ]]; then
        local -i major2=${BASH_REMATCH[$semver_major]}
        local -i minor2=${BASH_REMATCH[$semver_minor]}
        local -i patch2=${BASH_REMATCH[$semver_patch]}
        local prerelease2=${BASH_REMATCH[$semver_prerelease]#-}
    else
        error "${FUNCNAME[0]}() requires the version2 argument to be a valid [Semantic Versioning 2.0.0](https://semver.org/) string." >&2
        e=$((e + 1))
    fi
    # local build2=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    if (( e > 0 )); then
        return "$argsError"
    fi

    if (( major1 != major2 )); then
        if (( major1 > major2 )); then return "$isGt"; else return "$isLt"; fi
    elif (( minor1 != minor2 )); then
        if (( minor1 > minor2 )); then return "$isGt"; else return "$isLt"; fi
    elif (( patch1 != patch2 )); then
        if (( patch1 > patch2 )); then return "$isGt"; else return "$isLt"; fi
    elif [[ -z "$prerelease1" && -n "$prerelease2" ]]; then
        return "$isGt"
    elif [[ -n "$prerelease1" && -z "$prerelease2" ]]; then
        return "$isLt"
    elif [[ -z "$prerelease1" && -z "$prerelease2" ]]; then
        return "$isEq"
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
        if [[ $p1 =~ ^[0-9]+$ ]]; then
            if [[ $p2 =~ ^[0-9]+$ ]]; then
                local -i n1=$p1 n2=$p2
                if (( n1 != n2 )); then
                    if (( n1 > n2 )); then return "$isGt"; else return "$isLt"; fi
                fi
            else
                return "$isLt"
            fi
        else
            if [[ $p2 =~ ^[0-9]+$ ]]; then return "$isGt"; fi
        fi
        if [[ "$p1" != "$p2" ]]; then
            if [[ "$p1" > "$p2" ]]; then return "$isGt"; else return "$isLt"; fi
        fi
        ((i++))
    done

    if (( len1 != len2 )); then
        if (( len1 > len2 )); then return "$isGt"; else return "$isLt"; fi
    fi

    return "$isEq"
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semantic version (semver 2.0.0 format).
# Parameters:
#   1 - version - string to test
# Returns:
#   Exit code: 0 if valid semver, non-zero otherwise, 2 on invalid arguments
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
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the version."
        return 2
    fi
    [[ "$1" =~ $semverRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver tag (with configured prefix).
# Parameters:
#   1 - tag - git tag string to test
# Returns:
#   Exit code: 0 if valid semver tag, non-zero otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverTag <tag>; then ... fi
# Example:
#   validate_minverTagPrefix "v"
#   if is_semverTag "v1.2.3"; then echo "Valid tag"; fi
# Notes: Requires validate_minverTagPrefix to be called first to set $semverTagRegex.
#-------------------------------------------------------------------------------
function is_semverTag()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the semver tag."
        return 2
    fi
    [[ "$1" =~ $semverTagRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver prerelease version.
# Parameters:
#   1 - version - string to test
# Returns:
#   Exit code: 0 if valid semver prerelease, non-zero otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverPrerelease <version>; then ... fi
# Example: if is_semverPrerelease "1.2.3-alpha.1"; then echo "Valid prerelease"; fi
#-------------------------------------------------------------------------------
function is_semverPrerelease()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the semver prerelease."
        return 2
    fi
    [[ "$1" =~ $semverPrereleaseRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver prerelease tag (with configured prefix).
# Parameters:
#   1 - tag - git tag string to test
# Returns:
#   Exit code: 0 if valid semver prerelease tag, non-zero otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverPrereleaseTag <tag>; then ... fi
# Example:
#   validate_minverTagPrefix "v"
#   if is_semverPrereleaseTag "v1.2.3-beta.2"; then echo "Valid prerelease tag"; fi
# Notes: Requires validate_minverTagPrefix to be called first to set $semverTagPrereleaseRegex.
#-------------------------------------------------------------------------------
function is_semverPrereleaseTag()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the semver prerelease tag."
        return 2
    fi
    [[ "$1" =~ $semverTagPrereleaseRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver release version (without prerelease identifier).
# Parameters:
#   1 - version - string to test
# Returns:
#   Exit code: 0 if valid semver release, non-zero otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverRelease <version>; then ... fi
# Example: if is_semverRelease "1.2.3"; then echo "Valid release version"; fi
#-------------------------------------------------------------------------------
function is_semverRelease()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the version."
        return 2
    fi
    [[ "$1" =~ $semverReleaseRegex ]]
}

#-------------------------------------------------------------------------------
# Summary: Tests if the parameter is a valid semver release tag (with configured prefix, without prerelease).
# Parameters:
#   1 - tag - git tag string to test
# Returns:
#   Exit code: 0 if valid semver release tag, non-zero otherwise, 2 on invalid arguments
# Side Effects: On success, sets BASH_REMATCH array with captured groups
# Usage: if is_semverReleaseTag <tag>; then ... fi
# Example:
#   validate_minverTagPrefix "v"
#   if is_semverReleaseTag "v1.2.3"; then echo "Valid release tag"; fi
# Notes: Requires validate_minverTagPrefix to be called first to set $semverTagReleaseRegex.
#-------------------------------------------------------------------------------
function is_semverReleaseTag()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the semver release tag."
        return 2
    fi
    [[ "$1" =~ $semverTagReleaseRegex ]]
}
