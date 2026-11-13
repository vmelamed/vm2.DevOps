# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines functions and regular expressions for working with semantic versions
# (SemVer 2.0.0) and MinVer tags.
# It includes functions for validating and comparing semantic versions, parsing version
# components.
#===============================================================================================

# Circular include guard
(( ${__VM2_LIB_SEMVER_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_SEMVER_SH_LOADED=1

# vm2 core lib exit codes
declare -xri success
declare -xri failure
declare -xri positive
declare -xri negative
declare -xri err_invalid_arguments
declare -xri err_argument_type
declare -xri err_argument_value

# vm2 core lib constants
declare -xr prereleaseLabelRex
declare -xr minverTagPrefixRex
declare -xr minverPrereleaseIdRex
declare -xr minverTagPrefixRegex
declare -xr minverPrereleaseIdRegex

# vm2 core lib variables
declare -x _ignore

if [[ ! -v lib_dir || -z "$lib_dir" ]]; then
    lib_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
fi

if ! declare -pF "error" > "$_ignore"; then
    source "$lib_dir/_diagnostics.sh"
fi

# Regular expressions that test if a string contains a semantic version:
declare -xr majorLabelRex='(0|[1-9][0-9]*)'
declare -xr minorLabelRex='(0|[1-9][0-9]*)'
declare -xr patchLabelRex='(0|[1-9][0-9]*)'
declare -xr buildLabelRex='[-0-9A-Za-z.]+'

declare -xr semverReleaseRex="$majorLabelRex\\.$minorLabelRex\\.$patchLabelRex(\\+$buildLabelRex)?"
declare -xr semverPrereleaseRex="$majorLabelRex\\.$minorLabelRex\\.$patchLabelRex(-$prereleaseLabelRex)(\\+$buildLabelRex)?"
declare -xr semverRex="$majorLabelRex\\.$minorLabelRex\\.$patchLabelRex(-$prereleaseLabelRex)?(\\+$buildLabelRex)?"

# Regular expressions that test if a string is exactly a semantic version:
declare -xr semverRegex="^$semverRex$"
declare -xr semverReleaseRegex="^$semverReleaseRex$"
declare -xr semverPrereleaseRegex="^$semverPrereleaseRex$"

# Regular expressions that test if a string contains a git tag with semantic version and MinVer prefix (e.g. v1.2.3-alpha.3)
declare -xr semverTagRex="$minverTagPrefixRex$semverRex"
declare -xr semverTagPrereleaseRex="$minverTagPrefixRex$semverPrereleaseRex"
declare -xr semverTagReleaseRex="$minverTagPrefixRex$semverReleaseRex"

# Regular expressions that test if a string is a git tag with semantic version (e.g. v1.2.3-alpha.3)
declare -xr semverTagRegex="^$minverTagPrefixRex$semverRex$"
declare -xr semverTagPrereleaseRegex="^$minverTagPrefixRex$semverPrereleaseRex$"
declare -xr semverTagReleaseRegex="^$minverTagPrefixRex$semverReleaseRex$"

#-----------------------------------------------------------------------------------------------
# @description Dumps the SemVer/MinVer regular expression constants to stdout, grouped by
#   category, via `dump_vars`.
#
# @noargs
#
# @stdout Formatted table of the regex constants (see `dump_vars`).
#
# @example
#   print_semver_regexes
#-----------------------------------------------------------------------------------------------
function print_semver_regexes()
{
    local -a dump_regexes=(
        --quiet
        --force
        --header "Semantic Version Components"
        majorLabelRex
        minorLabelRex
        patchLabelRex
        prereleaseLabelRex
        buildLabelRex
        --header "Semantic Versions"
        semverPrereleaseRex
        semverReleaseRex
        semverRex
        --header "Semantic Versions"
        semverPrereleaseRegex
        semverReleaseRegex
        semverRegex
        --header "Semantic Version/MinVer Tags"
        semverTagRegex
        semverTagReleaseRegex
        semverTagPrereleaseRegex
        minverTagPrefixRegex
        minverPrereleaseIdRegex
    )

    dump_vars "${dump_regexes[@]}"
}

#-----------------------------------------------------------------------------------------------
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
# @exitcode success=0: Both arguments (or just the prefix, if $2 is omitted) are valid.
#
# @example
#   validate_minver_tag_components "v" "preview.0"
#-----------------------------------------------------------------------------------------------
function validate_minver_tag_components()
{
    (( $# == 1 || $# == 2 ))                                                    || bug "${FUNCNAME[0]}() requires one or two arguments (provided $#):" \
                                                                                       "  - the SemVer tag prefix used by MinVer" \
                                                                                       "  - default prerelease identifier template, optional" \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success

    [[ $1 =~ $minverTagPrefixRegex ]]                                           || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1, the MinVer tag prefix, to match '$minverTagPrefixRegex' (provided '${1-<missing>}')."
    [[ -z ${2:-} || $2 =~ $minverPrereleaseIdRegex ]]                           || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires optional argument 2, the MinVer prerelease identifier template, to match '$minverPrereleaseIdRegex' (provided '${2-<missing>}'). Did you pass a variable name instead of its value?"
    return "$_rc"
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
declare -xri rc_equal
declare -xri rc_greater_than
declare -xri rc_less_than

#-----------------------------------------------------------------------------------------------
# @description Gets the Major version component from a semver 2.0.0 string.
#
# arg1 string semver - must contain a valid semver string
#
# @exitcode success=0: the Major version component was extracted successfully and output to
#   stdout.
#
# @exitcode err_invalid_arguments=2: 0 or more than 1 arguments were passed to the function
# @exitcode err_argument_value=4: the argument's value is not a valid semver 2.0.0 string
#
# @stdout string The Major version component of the argument
#
# @example
#   declare semver="4.2.3-beta.5"
#   declare major=$(get_semver_major "$semver")     # outputs "4" to stdout
#-----------------------------------------------------------------------------------------------
function get_semver_major()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): - a valid semver string to extract the 'Major' version component from." \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success
    local _semver=$1

    [[ $_semver =~ $semverRegex ]]                                              || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid Semantic Versioning 2.0.0 string (provided '${1-<missing>}')."
    (( _rc != success )) || printf "%s\n" "${BASH_REMATCH[$semver_major]}"
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Gets the Minor version component from a semver 2.0.0 string.
#
# arg1 string semver - must contain a valid semver string
#
# @exitcode success=0: the Minor version component was extracted successfully and output to
#   stdout.
# @exitcode err_invalid_arguments=2: 0 or more than 1 arguments were passed to the function
# @exitcode err_argument_value=4: the argument's value is not a valid semver 2.0.0 string
#
# @stdout string The Minor version component of the argument
#
# @example
#   declare semver="4.2.3-beta.5"
#   declare minor=$(get_semver_minor "$semver")     # outputs "2" to stdout
#-----------------------------------------------------------------------------------------------
function get_semver_minor()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): - a valid semver string to extract the 'Minor' version component from." \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success
    local _semver=$1

    [[ $_semver =~ $semverRegex ]]                                              || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid Semantic Versioning 2.0.0 string (provided '${1-<missing>}')."
    (( _rc != success )) || printf "%s\n" "${BASH_REMATCH[$semver_minor]}"
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Gets the Patch version component from a semver 2.0.0 string.
#
# arg1 string semver - must contain a valid semver string
#
# @exitcode success=0: the Patch version component was extracted successfully and output to
#   stdout.
# @exitcode err_invalid_arguments=2: 0 or more than 1 arguments were passed to the function
# @exitcode err_argument_value=4: the argument's value is not a valid semver 2.0.0 string
#
# @stdout string The Patch version component of the argument
#
# @example
#   declare semver="4.2.3-beta.5"
#   declare patch=$(get_semver_patch "$semver")     # outputs "3" to stdout
#-----------------------------------------------------------------------------------------------
function get_semver_patch()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): - a valid semver string to extract the 'Patch' version component from." \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success
    local _semver=$1

    [[ $_semver =~ $semverRegex ]]                                              || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid Semantic Versioning 2.0.0 string (provided '${1-<missing>}')."
    (( _rc != success )) || printf "%s\n" "${BASH_REMATCH[$semver_patch]}"
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Gets the Prerelease version component from a semver 2.0.0 string.
#
# arg1 string semver - must contain a valid semver string
#
# @exitcode success=0: the Prerelease version component was extracted successfully and output to
#   stdout (will be empty for stable releases).
# @exitcode err_invalid_arguments=2: 0 or more than 1 arguments were passed to the function
# @exitcode err_argument_value=4: the argument's value is not a valid semver 2.0.0 string
#
# @stdout string The Prerelease version component of the argument
#
# @example
#   declare semver="4.2.3-beta.5"
#   declare prerelease=$(get_semver_prerelease "$semver")     # outputs "beta.5" to stdout
#-----------------------------------------------------------------------------------------------
function get_semver_prerelease()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): - a valid semver string to extract the 'Prerelease' version component from." \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success
    local _semver=$1

    [[ $_semver =~ $semverRegex ]]                                              || { with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid Semantic Versioning 2.0.0 string (provided '${1-<missing>}')."
                                                                                     return "$_rc"
                                                                                }

    printf "%s\n" "${BASH_REMATCH[$semver_prerelease]:1}"
}

#-----------------------------------------------------------------------------------------------
# @description Gets the Build version component from a semver 2.0.0 string.
#
# arg1 string semver - must contain a valid semver string
#
# @exitcode success=0: the Build version component was extracted successfully and output to
#   stdout.
# @exitcode err_invalid_arguments=2: 0 or more than 1 arguments were passed to the function
# @exitcode err_argument_value=4: the argument's value is not a valid semver 2.0.0 string
#
# @stdout string The Build version component of the argument
#
# @example
#   declare semver="4.2.3-beta.5+2026-11-08"
#   declare build=$(get_semver_build "$semver")     # outputs "2026-11-08" to stdout
#-----------------------------------------------------------------------------------------------
function get_semver_build()
{
    (( $# == 1 ))                                                               || bug "${FUNCNAME[0]}() requires one argument (provided $#): - a valid semver string to extract the 'Build' version component from." \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc=$success
    local _semver=$1

    [[ $_semver =~ $semverRegex ]]                                              || { with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid Semantic Versioning 2.0.0 string (provided '${1-<missing>}')."
                                                                                     return "$_rc"
                                                                                }
    printf "%s\n" "${BASH_REMATCH[$semver_build]:1}"
    return "$_rc"
}

#-----------------------------------------------------------------------------------------------
# @description Compares two semantic versions according to the Semantic
#   Versioning 2.0.0 specification.
#
# Notes:
#   - Build metadata is ignored in comparisons, per the semver spec.
#
# @arg $1 string The first semantic version to compare.
# @arg $2 string The second semantic version to compare.
#
# @exitcode rc_equal=0: version1 == version2.
# @exitcode rc_greater_than=1: version1 > version2.
# @exitcode rc_less_than=255: version1 < version2.
# @exitcode err_argument_value=4: one of the provided arguments is not a valid Semantic Versioning 2.0.0 string.
#
# @example
#   compare_semver "1.2.3" "1.2.4"
#   case $? in
#     "$rc_less_than")     echo "1.2.3 < 1.2.4" ;;
#     "$rc_equal")         echo "equal" ;;
#     "$rc_greater_than")  echo "1.2.3 > 1.2.4" ;;
#     * )                  error "Error comparing versions"  -ec $? -sd 3 ;;
#   esac
#-----------------------------------------------------------------------------------------------
function compare_semver()
{
    (( $# == 2 ))                                                               || bug "${FUNCNAME[0]}() requires exactly two arguments (provided $#):" \
                                                                                       "  - the first semantic versions to compare" \
                                                                                       "  - second semantic versions to compare" \
                                                                                       -ec "$err_invalid_arguments"
                                                                                exit_if_has_bugs

    local -i _rc="$success"

    [[ $1 =~ $semverRegex ]]                                                    || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 1 to be a valid Semantic Versioning 2.0.0 string (provided '${1-<missing>}')."
    [[ $2 =~ $semverRegex ]]                                                    || with_error _rc "$err_argument_value" "${FUNCNAME[0]}() requires argument 2 to be a valid Semantic Versioning 2.0.0 string (provided '${2-<missing>}')."
    (( _rc == success ))                                                        || return "$_rc"
    [[ $1 != "$2" ]] ||  return "$rc_equal"

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

#-----------------------------------------------------------------------------------------------
# @description Tests whether two semantic versions are equal.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode positive=0: version1 == version2.
# @exitcode negative=1: version1 != version2.
# @exitcode err_argument_value=4: propagated from `compare_semver()` if either argument is not
#   a valid Semantic Versioning 2.0.0 string.
#
# @example
#   if semver_eq "1.2.3" "1.2.3"; then echo "Versions are equal"; fi
#-----------------------------------------------------------------------------------------------
function semver_eq()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_equal )); then
        return "$positive"
    elif (( _rc == rc_greater_than || _rc == rc_less_than )); then
        return "$negative"
    else
        return "$_rc"
    fi
}

#-----------------------------------------------------------------------------------------------
# @description Tests whether the first semantic version is greater than the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode positive=0: version1 > version2.
# @exitcode negative=1: version1 <= version2.
# @exitcode err_argument_value=4: propagated from `compare_semver()` if either argument is not
#   a valid Semantic Versioning 2.0.0 string.
#
# @example
#   if semver_gt "1.2.3" "1.2.2"; then echo "Version 1 is greater"; fi
#-----------------------------------------------------------------------------------------------
function semver_gt()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_greater_than )); then
        return "$positive"
    elif (( _rc == rc_equal || _rc == rc_less_than )); then
        return "$negative"
    else
        return "$_rc"
    fi
}

#-----------------------------------------------------------------------------------------------
# @description Tests whether the first semantic version is greater than or equal to the
#   second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode positive=0: version1 >= version2.
# @exitcode negative=1: version1 < version2.
# @exitcode err_argument_value=4: propagated from `compare_semver()` if either argument is not
#   a valid Semantic Versioning 2.0.0 string.
#
# @example
#   if semver_gte "1.2.3" "1.2.2"; then echo "Version 1 is greater or equal"; fi
#-----------------------------------------------------------------------------------------------
function semver_gte()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_equal || _rc == rc_greater_than )); then
        return "$positive"
    elif (( _rc == rc_less_than )); then
        return "$negative"
    else
        return "$_rc"
    fi
}

#-----------------------------------------------------------------------------------------------
# @description Tests whether the first semantic version is less than the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode positive=0: version1 < version2.
# @exitcode negative=1: version1 >= version2.
# @exitcode err_argument_value=4: propagated from `compare_semver()` if either argument is not
#   a valid Semantic Versioning 2.0.0 string.
#
# @example
#   if semver_lt "1.2.3" "1.2.4"; then echo "Version 1 is less"; fi
#-----------------------------------------------------------------------------------------------
function semver_lt()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_less_than )); then
        return "$positive"
    elif (( _rc == rc_equal || _rc == rc_greater_than )); then
        return "$negative"
    else
        return "$_rc"
    fi
}

#-----------------------------------------------------------------------------------------------
# @description Tests whether the first semantic version is less than or equal to the second.
#
# @arg $1 string The first semantic version string.
# @arg $2 string The second semantic version string.
#
# @exitcode positive=0: version1 <= version2.
# @exitcode negative=1: version1 > version2.
# @exitcode err_argument_value=4: propagated from `compare_semver()` if either argument is not
#   a valid Semantic Versioning 2.0.0 string.
#
# @example
#   if semver_lte "1.2.3" "1.2.4"; then echo "Version 1 is less or equal"; fi
#-----------------------------------------------------------------------------------------------
function semver_lte()
{
    local -i _rc="$success"

    compare_semver "$@" || _rc=$?

    if (( _rc == rc_equal || _rc == rc_less_than )); then
        return "$positive"
    elif (( _rc == rc_greater_than )); then
        return "$negative"
    else
        return "$_rc"
    fi
}

#-----------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semantic version (SemVer 2.0.0 format).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups. Index into it with
#     `$semver_major`, `$semver_minor`, `$semver_patch`, `$semver_prerelease`, and
#     `$semver_build`.
#
# @arg $1 string The string to test.
#
# @exitcode positive=0: A valid semver.
# @exitcode negative=1: Not a valid semver.
#
# @example
#   if is_semver "$version"; then
#     major=${BASH_REMATCH[$semver_major]}
#     minor=${BASH_REMATCH[$semver_minor]}
#   fi
#-----------------------------------------------------------------------------------------------
function is_semver()
{
    __test_with_regex "$@" "$semverRegex"
}

#-----------------------------------------------------------------------------------------------
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
# @exitcode positive=0: A valid semver tag.
# @exitcode negative=1: Not a valid semver tag.
#
# @example
#   validate_minver_tag_components "v"
#   if is_semver_tag "v1.2.3"; then echo "Valid tag"; fi
#-----------------------------------------------------------------------------------------------
function is_semver_tag()
{
    __test_with_regex "$@" "$semverTagRegex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver prerelease version.
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#
# @arg $1 string The string to test.
#
# @exitcode positive=0: A valid semver prerelease.
# @exitcode negative=1: Not a valid semver prerelease.
#
# @example
#   if is_semver_prerelease "1.2.3-alpha.1"; then echo "Valid prerelease"; fi
#-----------------------------------------------------------------------------------------------
function is_semver_prerelease()
{
    __test_with_regex "$@" "$semverPrereleaseRegex"
}

#-----------------------------------------------------------------------------------------------
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
# @exitcode positive=0: A valid semver prerelease tag.
# @exitcode negative=1: Not a valid semver prerelease tag.
#
# @example
#   validate_minver_tag_components "v"
#   if is_semver_prerelease_tag "v1.2.3-beta.2"; then echo "Valid prerelease tag"; fi
#-----------------------------------------------------------------------------------------------
function is_semver_prerelease_tag()
{
    __test_with_regex "$@" "$semverTagPrereleaseRegex"
}

#-----------------------------------------------------------------------------------------------
# @description Tests whether the argument is a valid semver release version (without a
#   prerelease identifier).
#
# Notes:
#   - On success, `BASH_REMATCH` holds the captured groups.
#
# @arg $1 string The string to test.
#
# @exitcode positive=0: A valid semver release version.
# @exitcode negative=1: Not a valid semver release version.
#
# @example
#   if is_semver_release "1.2.3"; then echo "Valid release version"; fi
#-----------------------------------------------------------------------------------------------
function is_semver_release()
{
    __test_with_regex "$@" "$semverReleaseRegex"
}

#-----------------------------------------------------------------------------------------------
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
# @exitcode positive=0: A valid semver release tag.
# @exitcode negative=1: Not a valid semver release tag.
#
# @example
#   validate_minver_tag_components "v"
#   if is_semver_release_tag "v1.2.3"; then echo "Valid release tag"; fi
#-----------------------------------------------------------------------------------------------
function is_semver_release_tag()
{
    __test_with_regex "$@" "$semverTagReleaseRegex"
}
