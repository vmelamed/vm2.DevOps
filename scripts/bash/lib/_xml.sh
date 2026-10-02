# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#=============================================================================================
# This script defines generic functions for reading values out of XML documents (e.g. .csproj,
# .props, NuGet.config files) via `yq`'s XML support. It knows nothing about dotnet, MSBuild,
# or any other specific XML dialect -- callers supply the file and the query.
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_XML_SH_LOADED:-0} == 1 )) && return 0
declare -ri __VM2_LIB_XML_SH_LOADED=1

declare -xri success
declare -xri err_invalid_arguments
declare -xri err_argument_value
declare -xri err_invalid_nameref
declare -xri err_tool_error

declare -x _ignore

#---------------------------------------------------------------------------------------------
# @description Reads a single value out of an XML file via `yq`'s XML support, addressed by
#   element path or attribute, e.g. '.Project.PropertyGroup.IncludeSymbols' for an element, or
#   '.Project.ItemGroup.PackageReference.+@Version' for an attribute.
#
# Notes:
#   - This is a literal, single-file read via `yq -p=xml`: it does not resolve values that a
#     real XML-aware build tool would pull in from elsewhere (e.g. a dotnet project's
#     `Directory.Build.props`), and it does not evaluate any conditions the document's own
#     tooling might apply (e.g. MSBuild `Condition="..."` attributes). For a dotnet project's
#     effective, fully-resolved property value, use `get_msbuild_property()` in `_dotnet.sh`
#     instead.
#   - A query that matches nothing in the document is not an error: `$3` is set to an empty
#     string and the function still returns `$success`.
#
# @arg $1 string _xml_file - path to an existing, non-empty, readable XML file
# @arg $2 string _query - a yq path expression, e.g. '.Project.PropertyGroup.IncludeSymbols'
# @arg $3 nameref to a variable that will receive the value found, or an empty string if the
#   query matched nothing
#
# @exitcode success=0: The query ran; the value (or an empty string, if not present in the
#   document) was written to $3.
# @exitcode err_tool_error=66: The file does not exist or is not readable, or `yq` itself failed.
#
# @example
#   declare include_symbols
#   get_xml_value "MyPackage.csproj" ".Project.PropertyGroup.IncludeSymbols" include_symbols
#---------------------------------------------------------------------------------------------
function get_xml_value()
{
    (( $# == 3 ))                    || bug -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly 3 arguments (provided $#):" \
                                                                         "  - path to an XML file" \
                                                                         "  - a yq path expression (query)" \
                                                                         "  - nameref to a variable to receive the value"
    [[ ! -v 2 || -n $2 ]]            || bug -ec "$err_argument_value"   "${FUNCNAME[0]}() requires argument 2, the yq path expression, to be non-empty (provided '${2:-<none>}')."
    [[ ! -v 3 ]] || is_variable "$3" || bug -ec "$err_invalid_nameref"  "${FUNCNAME[0]}() requires argument 3 to be the name of a defined variable to receive the value (provided '${3:-<none>}')."
    exit_if_has_bugs

    local _xml_file=$1
    local _query=$2
    local -n _value=$3

    [[ -s $_xml_file ]] || {
        error -ec "$err_tool_error" "${FUNCNAME[0]}() requires argument 1 to be an existing, non-empty, readable XML file (provided '${_xml_file:-<none>}')."
        return "$err_tool_error"
    }

    local _result
    local -i _rc=$success

    _result=$(yq -p=xml -oy -r "$_query" "$_xml_file" 2>"$_ignore") || {
        _rc=$?
        error -ec "$err_tool_error" "${FUNCNAME[0]}() 'yq' failed to query '$_xml_file' with '$_query'."
        return "$err_tool_error"
    }

    # shellcheck disable=SC2015 # Note that A && B || C is not if-then-else. C may run when A is true.
    [[ $_result != "null" ]] && _value="$_result" || _value=""

    return "$_rc"
}
