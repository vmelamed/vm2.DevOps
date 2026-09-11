#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_dump_vars.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.
#
# dump_vars' output is a formatted table; these tests assert on the key content present
# (--partial), not exact byte-for-byte formatting, which would be brittle.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- _write_title -------------------------------------------------------------------------

@test "_write_title: prints the header text" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; _current_table=graphical; _write_title 'My Header'"
    assert_success
    assert_output --partial "My Header"
}

@test "_write_title: bug-exits with the wrong argument count" {
    run _write_title
    assert_failure 254
}

# --- _write_line ----------------------------------------------------------------------------

@test "_write_line: prints a scalar variable's name and value" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; _current_table=graphical; myvar=hello; _write_line myvar false"
    assert_success
    assert_output --partial "myvar"
    assert_output --partial "hello"
}

@test "_write_line: masks the value with \$secret_str when the secret flag is true" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; _current_table=graphical; myvar=topsecret; _write_line myvar true"
    assert_success
    assert_output --partial "myvar"
    refute_output --partial "topsecret"
    assert_output --partial "$secret_str"
}

@test "_write_line: prints entry count and contents for an associative array" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; _current_table=graphical; declare -A myarr=([a]=1 [b]=2); _write_line myarr false"
    assert_success
    assert_output --partial "2 entries:"
    assert_output --partial "a"
    assert_output --partial "1"
}

@test "_write_line: prints item count and contents for an indexed array" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; _current_table=graphical; declare -a myarr=(x y z); _write_line myarr false"
    assert_success
    assert_output --partial "3 items:"
    assert_output --partial "[1]:"
    assert_output --partial "y"
}

@test "_write_line: prints '()' suffix for a defined function" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; _current_table=graphical; _write_line is_boolean false"
    assert_success
    assert_output --partial "is_boolean()"
}

@test "_write_line: uses a custom display name and treats \$1 as a literal value when unbound" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; _current_table=graphical; _write_line 'literal-value' false 'Custom Label'"
    assert_success
    assert_output --partial "Custom Label"
    assert_output --partial "literal-value"
}

@test "_write_line: shows the unbound placeholder for an undefined name with no custom label" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; _current_table=graphical; _write_line definitely_not_defined_xyz false"
    assert_success
    assert_output --partial "unbound, undefined, or invalid"
}

@test "_write_line: bug-exits with the wrong argument count" {
    run _write_line
    assert_failure 254
}

@test "_write_line: bug-exits on a non-boolean secret flag" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; myvar=hello; _write_line myvar maybe"
    assert_failure 254
}

# --- dump_vars --------------------------------------------------------------------------------

@test "dump_vars: no-op with no arguments" {
    run dump_vars
    assert_success
    refute_output
}

@test "dump_vars: silent when verbose is off and --force is not given" {
    run dump_vars --quiet myvar
    assert_success
    refute_output
}

@test "dump_vars: --force dumps even when verbose is off" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; myvar=hello; dump_vars --force --quiet myvar"
    assert_success
    assert_output --partial "myvar"
    assert_output --partial "hello"
}

@test "dump_vars: --header prints the header text" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; myvar=hello; dump_vars --force --quiet --header 'My Section' myvar"
    assert_success
    assert_output --partial "My Section"
}

@test "dump_vars: --secret masks only the immediately following variable" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; secretvar=topsecret; plainvar=visible; dump_vars --force --quiet --secret secretvar plainvar"
    assert_success
    refute_output --partial "topsecret"
    assert_output --partial "visible"
}

@test "dump_vars: --name assigns a custom display label to the next entry only" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; myvar=hello; othervar=world; dump_vars --force --quiet --name 'Custom Label' myvar othervar"
    assert_success
    assert_output --partial "Custom Label"
    assert_output --partial "othervar"
}

@test "dump_vars: --markdown and --graphical switch the table format" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; myvar=hello; dump_vars --force --quiet --markdown myvar"
    assert_success
    assert_output --partial "|"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; myvar=hello; dump_vars --force --quiet --graphical myvar"
    assert_success
    assert_output --partial "║"
}

@test "dump_vars: --core-state dumps the internal core-state snapshot" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; dump_vars --force --quiet --core-state"
    assert_success
    assert_output --partial "PID"
    assert_output --partial "Verbose"
}

@test "dump_vars: --common-dotnet-args dumps the common dotnet variables without clobbering a caller's own \$arg (regression)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; arg='my-global-value'; dump_vars --force --quiet --common-dotnet-args; echo \"arg=[\$arg]\""
    assert_success
    assert_output --partial "configuration"
    assert_output --partial "arg=[my-global-value]"
}

@test "dump_vars: --common-dotnet-args masks the NuGet password" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; gh_nuget_password='topsecret'; dump_vars --force --quiet --common-dotnet-args"
    assert_success
    refute_output --partial "topsecret"
    assert_output --partial "gh_nuget_password"
}

@test "dump_vars: --blank and --line render without crashing" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; myvar=hello; dump_vars --force --quiet myvar --blank --line myvar"
    assert_success
}

@test "dump_vars: restores the original quiet/verbose state after returning" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; myvar=hello; dump_vars --force --quiet myvar; is_verbose && echo verbose=true || echo verbose=false; is_quiet && echo quiet=true || echo quiet=false"
    assert_success
    assert_line "verbose=false"
    assert_line "quiet=false"
}
