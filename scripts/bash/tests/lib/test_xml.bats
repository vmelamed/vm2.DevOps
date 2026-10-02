#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_xml.sh. Uses the real 'yq' binary against real,
# throwaway XML fixture files -- 'yq' is a safe, side-effect-free, deterministic CLI tool, so
# there's no need to fake it the way tests fake 'gh'/'dotnet'.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gxi err_invalid_arguments
declare -gxi err_argument_value
declare -gxi err_invalid_nameref
declare -gxi err_tool_error

_write_fixture() {
    local _file="$1"
    cat > "$_file" <<'EOF'
<Project>
  <PropertyGroup>
    <IncludeSymbols>false</IncludeSymbols>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Foo" Version="1.2.3" />
  </ItemGroup>
</Project>
EOF
}

# --- formal validation ---------------------------------------------------------------------------

@test "get_xml_value: bug-exits with the wrong argument count" {
    run get_xml_value "a" "b"
    assert_failure "$err_invalid_arguments"
}

@test "get_xml_value: bug-exits on an empty query" {
    declare out
    run get_xml_value "a" "" out
    assert_failure "$err_argument_value"
}

@test "get_xml_value: bug-exits when argument 3 is not the name of a defined variable" {
    run get_xml_value "a" ".Project" ""
    assert_failure "$err_invalid_nameref"
}

# --- reading values --------------------------------------------------------------------------

@test "get_xml_value: reads an element's value" {
    _write_fixture "$BATS_TEST_TMPDIR/test.csproj"
    declare out
    run get_xml_value "$BATS_TEST_TMPDIR/test.csproj" ".Project.PropertyGroup.IncludeSymbols" out
    assert_success
}

@test "get_xml_value: writes the element's value to the output variable" {
    _write_fixture "$BATS_TEST_TMPDIR/test.csproj"
    out=''
    get_xml_value "$BATS_TEST_TMPDIR/test.csproj" ".Project.PropertyGroup.IncludeSymbols" out
    [[ $out == "false" ]]
}

@test "get_xml_value: reads an attribute's value" {
    _write_fixture "$BATS_TEST_TMPDIR/test.csproj"
    out=''
    get_xml_value "$BATS_TEST_TMPDIR/test.csproj" '.Project.ItemGroup.PackageReference.+@Version' out
    [[ $out == "1.2.3" ]]
}

@test "get_xml_value: a query that matches nothing returns success with an empty output, not an error" {
    _write_fixture "$BATS_TEST_TMPDIR/test.csproj"
    out='sentinel'
    run get_xml_value "$BATS_TEST_TMPDIR/test.csproj" ".Project.PropertyGroup.NoSuchElement" out
    assert_success
}

@test "get_xml_value: an empty match clears the output variable rather than leaving a stale value" {
    _write_fixture "$BATS_TEST_TMPDIR/test.csproj"
    out='sentinel'
    get_xml_value "$BATS_TEST_TMPDIR/test.csproj" ".Project.PropertyGroup.NoSuchElement" out
    [[ -z $out ]]
}

# --- error handling ------------------------------------------------------------------------------

@test "get_xml_value: fails with err_tool_error when the file does not exist" {
    declare out
    run get_xml_value "$BATS_TEST_TMPDIR/does-not-exist.csproj" ".Project" out
    assert_failure "$err_tool_error"
}

@test "get_xml_value: fails with err_tool_error when the file is empty" {
    : > "$BATS_TEST_TMPDIR/empty.csproj"
    declare out
    run get_xml_value "$BATS_TEST_TMPDIR/empty.csproj" ".Project" out
    assert_failure "$err_tool_error"
}
