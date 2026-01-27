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

# Regular expressions that test if a string is exactly a git tag with semantic version (e.g. v1.2.3)
declare -x semverTagRegex
declare -x semverTagReleaseRegex
declare -x semverTagPrereleaseRegex

declare -xr minverTagPrefixRex='[0-9A-Za-z_]([-0-9A-Za-z._/]*[-A-Za-z_])?'
declare -xr minverTagPrefixRegex="^$minverTagPrefixRex$"

declare -xr minverPrereleaseIdRex=$prereleaseLabelRex
declare -xr minverPrereleaseIdRegex="^$minverPrereleaseIdRex$"

## Flag indicating whether the tag regexes have been initialized with default value for the tag prefix or with actual parameter
## 0 - actual, 1 - default
declare -xi tag_regexes_initialized=1

## Shell function to create the regular expressions above for tags comprising a given prefix and a semantic version.
## Call once when the tag prefix is known. For example: create_tag_regexes "ver.".
# shellcheck disable=SC2120 # create_tag_regexes references arguments, but none are ever passed.
function create_tag_regexes()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the semver tag prefix used by MinVer."
        return 2
    fi
    if [[ ! $1 =~ $minverTagPrefixRegex ]]; then
        error "The semver tag prefix used by MinVer ('$1') is not valid. It must match the regex: $minverTagPrefixRegex"
        return 1
    fi

    semverTagRegex="^${1}${semverRex}$"
    semverTagReleaseRegex="^${1}${semverReleaseRex}$"
    semverTagPrereleaseRegex="^${1}${semverPrereleaseRex}$"
}

# create the regexes with default prefix from $MINVERTAGPREFIX or 'v' for now, they can be re-created later by calling
# create_tag_regexes with a different prefix if needed
create_tag_regexes "${MINVERTAGPREFIX:-"v"}"

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

## Compares two semantic versions, see https://semver.org/.
## Returns one of the comparison result constants: $isEq if '$1 == $2', $isGt if '$1 > $2', $isLt if '$1 < $2', and
## $argsError if invalid arguments are provided.
## Returns $argsError if invalid arguments are provided (also increments $errors).
## Usage: compare_semver <version1> <version2>
function compare_semver()
{
    local -i e=0

    if [[ $# -ne 2 ]]; then
        error "The function ${FUNCNAME[0]}() requires at exactly 2 arguments: version1 and version2." >&2
        e=$((e + 1))
    fi

    if [[ "$1" =~ $semverRegex ]]; then
        local -i major1=${BASH_REMATCH[$semver_major]}
        local -i minor1=${BASH_REMATCH[$semver_minor]}
        local -i patch1=${BASH_REMATCH[$semver_patch]}
        local prerelease1=${BASH_REMATCH[$semver_prerelease]#-}
    else
        error "version1 argument to ${FUNCNAME[0]}() must be a valid [Semantic Versioning 2.0.0](https://semver.org/) string." >&2
        e=$((e + 1))
    fi
    # local build1=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    if [[ "$2" =~ $semverRegex ]]; then
        local -i major2=${BASH_REMATCH[$semver_major]}
        local -i minor2=${BASH_REMATCH[$semver_minor]}
        local -i patch2=${BASH_REMATCH[$semver_patch]}
        local prerelease2=${BASH_REMATCH[$semver_prerelease]#-}
    else
        error "version2 argument to ${FUNCNAME[0]}() must be a valid [Semantic Versioning 2.0.0](https://semver.org/) string." >&2
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

## Tests if the parameter is a valid semantic version (semver format).
## Returns 0 if valid semver, > 0 otherwise. On success sets the array variable BASH_REMATCH, and you can use the indexes:
## $semver_major, $semver_minor, $semver_patch, $semver_prerelease, and $semver_build.
## Usage: if is_semver "$version"; then ... fi
function is_semver()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the version."
        return 2
    fi
    [[ "$1" =~ $semverRegex ]]
}

## Tests if the parameter is a valid minimum version (semver format).
## Returns 0 if valid semver, > 0 otherwise. On success sets the array variable BASH_REMATCH, and you can use the indexes:
## $semver_major, $semver_minor, $semver_patch, $semver_prerelease, and $semver_build.
## Usage: if is_semver "$version"; then ... fi
function is_semverTag()
{
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        error "${FUNCNAME[0]}() requires 1 or 2 arguments: the version and the optional minver tag prefix used by MinVer."
        return 2
    fi

    local tag="$1"
    local tag_prefix
    [[ -z "$2" ]] && tag_prefix=$minverTagPrefixRegex || tag_prefix="$2"

    # Must match semver pattern (already defined in _common.semver.sh)
    [[ "$tag" =~ $tag_prefix ]]
}

## Tests if the parameter is a valid semantic version (semver format).
## Returns 0 if valid semver, > 0 otherwise. On success sets the array variable BASH_REMATCH, and you can use the indexes:
## $semver_major, $semver_minor, $semver_patch, $semver_prerelease, and $semver_build.
## Usage: if is_semver "$version"; then ... fi
function is_semverPrerelease()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the version."
        return 2
    fi
    [[ "$1" =~ $semverPrereleaseRegex ]]
}

## Tests if the parameter is a valid minimum version (semver format).
## Returns 0 if valid semver, > 0 otherwise
## Usage: if is_semver "$version"; then ... fi
function is_semverPrereleaseTag()
{
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        error "${FUNCNAME[0]}() requires 1 or 2 arguments: the version and the semver tag prefix used by MinVer."
        return 2
    fi

    local tag="$1"
    local tag_prefix="${2:-"${MINVERTAGPREFIX:-'v'}"}"

    # Must match semver pattern (already defined in _common.semver.sh)
    [[ "$tag" =~ ^${tag_prefix}${semverPrereleaseRex}$ ]]
}

## Tests if the parameter is a valid semantic version (semver format).
## Returns 0 if valid semver, > 0 otherwise. On success sets the array variable BASH_REMATCH, and you can use the indexes:
## $semver_major, $semver_minor, $semver_patch, $semver_prerelease, and $semver_build.
## Usage: if is_semver "$version"; then ... fi
function is_semverRelease()
{
    if [[ $# -ne 1 ]]; then
        error "${FUNCNAME[0]}() requires exactly 1 argument: the version."
        return 2
    fi
    [[ "$1" =~ $semverReleaseRegex ]]
}

## Tests if the parameter is a valid minimum version (semver format).
## Returns 0 if valid semver, > 0 otherwise. On success sets the array variable BASH_REMATCH, and you can use the indexes:
## $semver_major, $semver_minor, $semver_patch, $semver_prerelease, and $semver_build.
## Usage: if is_semver "$version"; then ... fi
function is_semverReleaseTag()
{
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        error "${FUNCNAME[0]}() requires 1 or 2 arguments: the version and optional semver tag prefix used by MinVer."
        return 2
    fi

    local tag="$1"
    local tag_prefix="${2:-"${MINVERTAGPREFIX:-'v'}"}"

    # Must match semver pattern (already defined in _common.semver.sh)
    [[ "$tag" =~ ^${tag_prefix}${semverReleaseRex}$ ]]; ret=$?
    dump_vars -q -f tag tag_prefix semverReleaseRex ret

    [[ "$tag" =~ ^${tag_prefix}${semverReleaseRex}$ ]]
}
