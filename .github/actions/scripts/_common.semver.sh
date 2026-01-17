#!/bin/bash

if ! declare -pF "error" > /dev/null; then
    semver_dir="$(dirname "${BASH_SOURCE[0]}")"
    source "$semver_dir/_common.diagnostics.sh"
fi

# Regular expressions that test if a string contains a semantic version:
declare -xr semverRex='([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?'
declare -xr semverReleaseRex='([0-9]+)\.([0-9]+)\.([0-9]+)'
declare -xr semverPrereleaseRex='([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z.-]+)(\+[0-9A-Za-z.-]+)?'

# Regular expressions that test if a string is exactly a semantic version:
declare -xr semverRegex="^$semverRex$"
declare -xr semverReleaseRegex="^$semverReleaseRex$"
declare -xr semverPrereleaseRegex="^$semverPrereleaseRex$"

# Regular expressions that test if a string is exactly a git tag with semantic version (e.g. v1.2.3)
declare -x semverTagRegex
declare -x semverTagReleaseRegex
declare -x semverTagPrereleaseRegex

## Shell function to create the regular expressions above for tags comprising a given prefix and a semantic version.
## Call once when the tag prefix is known. For example: create_tag_regexes "ver.".
function create_tag_regexes()
{
    local tag_prefix="${1:-"${MinVerTagPrefix:-"v"}"}"

    semverTagRegex="^${tag_prefix}${semverRex}$"
    semverTagReleaseRegex="^${tag_prefix}${semverReleaseRex}$"
    semverTagPrereleaseRegex="^${tag_prefix}${semverPrereleaseRex}$"
}

# create the regexes with default prefix from $MinVerTagPrefix or 'v' for now, they can be re-created later by calling
# create_tag_regexes with a different prefix if needed
create_tag_regexes

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

declare -ix errors=0

## Tests if the parameter is a valid semantic version (semver format).
## Returns 0 if valid semver, > 0 otherwise
## Usage: if is_semver "$version"; then ... fi
function is_semver() {
    [[ "$1" =~ $semverRegex ]]
}

## Tests if the parameter is a valid minimum version (semver format).
## Returns 0 if valid semver, > 0 otherwise
## Usage: if is_semver "$version"; then ... fi
function is_semverTag() {
    local tag="$1"
    local tag_prefix="${2:-"${MinVerTagPrefix:-"v"}"}"

    # Must match semver pattern (already defined in _common.semver.sh)
    [[ "$tag" =~ ^${tag_prefix}${semverRex}$ ]]
}

## Tests if the parameter is a valid semantic version (semver format).
## Returns 0 if valid semver, > 0 otherwise
## Usage: if is_semver "$version"; then ... fi
function is_semverPrerelease() {
    [[ "$1" =~ $semverPrereleaseRegex ]]
}

## Tests if the parameter is a valid minimum version (semver format).
## Returns 0 if valid semver, > 0 otherwise
## Usage: if is_semver "$version"; then ... fi
function is_semverPrereleaseTag() {
    local tag="$1"
    local tag_prefix="${2:-"${MinVerTagPrefix:-"v"}"}"

    # Must match semver pattern (already defined in _common.semver.sh)
    [[ "$tag" =~ ^${tag_prefix}${semverPrereleaseRex}$ ]]
}

## Tests if the parameter is a valid semantic version (semver format).
## Returns 0 if valid semver, > 0 otherwise
## Usage: if is_semver "$version"; then ... fi
function is_semverRelease() {
    [[ "$1" =~ $semverReleaseRegex ]]
}

## Tests if the parameter is a valid minimum version (semver format).
## Returns 0 if valid semver, > 0 otherwise
## Usage: if is_semver "$version"; then ... fi
function is_semverReleaseTag() {
    local tag="$1"
    local tag_prefix="${2:-"${MinVerTagPrefix:-"v"}"}"

    # Must match semver pattern (already defined in _common.semver.sh)
    [[ "$tag" =~ ^${tag_prefix}${semverReleaseRex}$ ]]
}

## Compares two semantic versions, see https://semver.org/.
## Returns $isEq if '$1 == $2', $isGt if '$1 > $2', $isLt if '$1 < $2'.
## Returns $argsError if invalid arguments are provided (also increments $errors).
## Usage: compare_semver <version1> <version2>
function compare_semver() {
    local -i e=0

    if [[ $# -ne 2 ]]; then
        error "The function compare_semver() requires at exactly 2 arguments: version1 and version2." >&2
        e=$((e + 1))
    fi

    if [[ "$1" =~ $semverRegex ]]; then
        local -i major1=${BASH_REMATCH[$semver_major]}
        local -i minor1=${BASH_REMATCH[$semver_minor]}
        local -i patch1=${BASH_REMATCH[$semver_patch]}
        local prerelease1=${BASH_REMATCH[$semver_prerelease]#-}
    else
        error "version1 argument to compare_semver() must be a valid [Semantic Versioning 2.0.0](https://semver.org/) string." >&2
        e=$((e + 1))
    fi
    # local build1=${BASH_REMATCH[semver_build]#-} does not participate in comparison by spec

    if [[ "$2" =~ $semverRegex ]]; then
        local -i major2=${BASH_REMATCH[$semver_major]}
        local -i minor2=${BASH_REMATCH[$semver_minor]}
        local -i patch2=${BASH_REMATCH[$semver_patch]}
        local prerelease2=${BASH_REMATCH[$semver_prerelease]#-}
    else
        error "version2 argument to compare_semver() must be a valid [Semantic Versioning 2.0.0](https://semver.org/) string." >&2
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
