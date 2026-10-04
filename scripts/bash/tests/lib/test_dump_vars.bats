#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/lib/_dump_vars.sh.
#
# dump_vars' output is a formatted table; these tests assert on the key content present
# (--partial), not exact byte-for-byte formatting, which would be brittle.
#
# _write_line takes four positional arguments: nameref, secret flag, display name (empty for
# none), and GitHub-escape flag. Every call below passes all four, even when a value is ''.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_invalid_arguments
declare -gxi err_argument_type

# Runs a snippet in a fresh shell with core.sh loaded and a graphical table format selected.
_in_core() {
    bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; _current_table=graphical; $1"
}

# Same as _in_core, but with gh_core.sh (needed for gh_escape and the GitHub-context helpers).
_in_gh_core() {
    bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; _current_table=graphical; $1"
}

# --- _write_title -------------------------------------------------------------------------

@test "_write_title: prints the header text" {
    run _in_core "_write_title 'My Header'"
    assert_success
    assert_output --partial "My Header"
}

@test "_write_title: bug-exits with the wrong argument count" {
    run _write_title
    assert_failure "$err_invalid_arguments"
}

# --- _write_line ----------------------------------------------------------------------------

@test "_write_line: prints a scalar variable's name and value" {
    run _in_core "myvar=hello; _write_line myvar false '' false"
    assert_success
    assert_output --partial "myvar"
    assert_output --partial "hello"
}

@test "_write_line: masks the value with \$secret_str when the secret flag is true" {
    run _in_core "myvar=topsecret; _write_line myvar true '' false"
    assert_success
    assert_output --partial "myvar"
    refute_output --partial "topsecret"
    assert_output --partial "$secret_str"
}

@test "_write_line: prints entry count and contents for an associative array" {
    run _in_core "declare -A myarr=([a]=1 [b]=2); _write_line myarr false '' false"
    assert_success
    assert_output --partial "2 entries:"
    assert_output --partial "a"
    assert_output --partial "1"
}

@test "_write_line: prints item count and contents for an indexed array" {
    run _in_core "declare -a myarr=(x y z); _write_line myarr false '' false"
    assert_success
    assert_output --partial "3 items:"
    assert_output --partial "[1]:"
    assert_output --partial "y"
}

@test "_write_line: prints '()' suffix for a defined function" {
    run _in_core "_write_line is_boolean false '' false"
    assert_success
    assert_output --partial "is_boolean()"
}

@test "_write_line: with a custom display name, an unbound first argument is shown as a literal value" {
    run _in_core "_write_line 'literal-value' false 'Custom Label' false"
    assert_success
    assert_output --partial "Custom Label"
    assert_output --partial "literal-value"
    refute_output --partial "unbound, undefined, or invalid"
}

@test "_write_line: shows the unbound placeholder for an undefined name with no custom label" {
    run _in_core "_write_line definitely_not_defined_xyz false '' false"
    assert_success
    assert_output --partial "unbound, undefined, or invalid"
}

@test "_write_line: bug-exits with the wrong argument count" {
    run _write_line
    assert_failure "$err_invalid_arguments"
}

@test "_write_line: bug-exits on a non-boolean secret flag" {
    run _in_core "myvar=hello; _write_line myvar maybe '' false"
    assert_failure "$err_argument_type"
}

@test "_write_line: bug-exits on a non-boolean GitHub-escape flag" {
    run _in_core "myvar=hello; _write_line myvar false '' maybe"
    assert_failure "$err_argument_type"
}

# --- _write_line with GitHub escaping -----------------------------------------------------------

@test "_write_line: escapes a scalar's value when the GitHub-escape flag is true" {
    run _in_gh_core "myvar=\$'100%\nnext'; _write_line myvar false '' true"
    assert_success
    assert_output --partial "100%25%0Anext"
}

@test "_write_line: leaves a scalar's value untouched when the GitHub-escape flag is false" {
    run _in_gh_core "myvar='100%'; _write_line myvar false '' false"
    assert_success
    assert_output --partial "100%"
    refute_output --partial "100%25"
}

@test "_write_line: escapes every element of an indexed array when the GitHub-escape flag is true" {
    run _in_gh_core "declare -a myarr=(\$'a\nb' 'c%d'); _write_line myarr false '' true"
    assert_success
    assert_output --partial "a%0Ab"
    assert_output --partial "c%25d"
}

@test "_write_line: escapes every value of an associative array when the GitHub-escape flag is true" {
    run _in_gh_core "declare -A myarr=([k]='50%'); _write_line myarr false '' true"
    assert_success
    assert_output --partial "50%25"
}

@test "_write_line: masking takes precedence over GitHub escaping for a secret" {
    run _in_gh_core "myvar=topsecret; _write_line myvar true '' true"
    assert_success
    refute_output --partial "topsecret"
    assert_output --partial "$secret_str"
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
    run _in_core "myvar=hello; dump_vars --force --quiet myvar"
    assert_success
    assert_output --partial "myvar"
    assert_output --partial "hello"
}

@test "dump_vars: --header prints the header text" {
    run _in_core "myvar=hello; dump_vars --force --quiet --header 'My Section' myvar"
    assert_success
    assert_output --partial "My Section"
}

@test "dump_vars: --secret masks only the immediately following variable" {
    run _in_core "secretvar=topsecret; plainvar=visible; dump_vars --force --quiet --secret secretvar plainvar"
    assert_success
    refute_output --partial "topsecret"
    assert_output --partial "visible"
}

@test "dump_vars: --name assigns a custom display label to the next entry only" {
    run _in_core "myvar=hello; othervar=world; dump_vars --force --quiet --name 'Custom Label' myvar othervar"
    assert_success
    assert_output --partial "Custom Label"
    assert_output --partial "othervar"
}

@test "dump_vars: --markdown and --graphical switch the table format" {
    run _in_core "myvar=hello; dump_vars --force --quiet --markdown myvar"
    assert_success
    assert_output --partial "|"

    run _in_core "myvar=hello; dump_vars --force --quiet --graphical myvar"
    assert_success
    assert_output --partial "║"
}

@test "dump_vars: --gh-escape escapes the dumped values" {
    run _in_gh_core "myvar=\$'a\nb'; dump_vars --force --quiet --gh-escape myvar"
    assert_success
    assert_output --partial "a%0Ab"
}

@test "dump_vars: without --gh-escape the dumped values are not escaped" {
    run _in_gh_core "myvar='100%'; dump_vars --force --quiet myvar"
    assert_success
    assert_output --partial "100%"
    refute_output --partial "100%25"
}

@test "dump_vars: --gh-escape with the short flag -e behaves like the long flag" {
    run _in_gh_core "myvar='100%'; dump_vars --force --quiet -e myvar"
    assert_success
    assert_output --partial "100%25"
}

@test "dump_vars: --core-state dumps the internal core-state snapshot" {
    run _in_core "dump_vars --force --quiet --core-state"
    assert_success
    assert_output --partial "PID"
    assert_output --partial "Verbose"
}

@test "dump_vars: dump_common_dotnet_args dumps the common dotnet variables without clobbering a caller's own \$arg (regression)" {
    run _in_core "arg='my-global-value'; dump_vars --force --quiet \"\${dump_common_dotnet_args[@]}\"; echo \"arg=[\$arg]\""
    assert_success
    assert_output --partial "configuration"
    assert_output --partial "arg=[my-global-value]"
}

@test "dump_vars: dump_common_dotnet_args masks the NuGet password" {
    run _in_core "gh_nuget_password='topsecret'; dump_vars --force --quiet \"\${dump_common_dotnet_args[@]}\""
    assert_success
    refute_output --partial "topsecret"
    assert_output --partial "gh_nuget_password"
}

@test "dump_vars: --blank and --line render without crashing" {
    run _in_core "myvar=hello; dump_vars --force --quiet myvar --blank --line myvar"
    assert_success
}

@test "dump_vars: restores the original quiet/verbose state after returning" {
    run _in_core "myvar=hello; dump_vars --force --quiet myvar; is_verbose && echo verbose=true || echo verbose=false; is_quiet && echo quiet=true || echo quiet=false"
    assert_success
    assert_line "verbose=false"
    assert_line "quiet=false"
}
