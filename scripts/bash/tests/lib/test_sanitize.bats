#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_sanitize.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- ltrim / rtrim / trim ------------------------------------------------------------------

@test "ltrim: removes only leading whitespace" {
    run ltrim "  hi  "
    assert_success
    assert_output "hi  "
}

@test "rtrim: removes only trailing whitespace" {
    run rtrim "  hi  "
    assert_success
    assert_output "  hi"
}

@test "trim: removes leading and trailing whitespace" {
    run trim "  hi  "
    assert_success
    assert_output "hi"
}

@test "ltrim/rtrim/trim: bug-exit with wrong argument count" {
    run ltrim
    assert_failure 254
    run rtrim
    assert_failure 254
    run trim
    assert_failure 254
}

@test "ltrim_var/rtrim_var/trim_var: trim the referenced variable in place" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; v='  hi  '; ltrim_var v; echo \"[\$v]\""
    assert_output "[hi  ]"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; v='  hi  '; rtrim_var v; echo \"[\$v]\""
    assert_output "[  hi]"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; v='  hi  '; trim_var v; echo \"[\$v]\""
    assert_output "[hi]"
}

@test "trim_var: bug-exits on an undefined variable name" {
    run trim_var definitely_not_defined_xyz
    assert_failure 254
}

# --- is_safe_input -----------------------------------------------------------------------------

@test "is_safe_input: accepts empty and plain alphanumeric input" {
    run is_safe_input ""
    assert_success
    run is_safe_input "hello123"
    assert_success
}

@test "is_safe_input: rejects dangerous shell metacharacters" {
    run is_safe_input 'hi; rm -rf /'
    assert_failure 11
    run is_safe_input 'hi$(whoami)'
    assert_failure 11
}

@test "is_safe_input: rejects spaces by default but allows them when arg 2 is true" {
    run is_safe_input "hello world"
    assert_failure 11
    run is_safe_input "hello world" true
    assert_success
}

@test "is_safe_input: bug-exits with more than two arguments" {
    run is_safe_input a b c
    assert_failure 254
}

# --- is_safe_boolean / is_safe_integer -----------------------------------------------------

@test "is_safe_boolean: accepts true/false, rejects anything else" {
    run is_safe_boolean true
    assert_success
    run is_safe_boolean false
    assert_success
    run is_safe_boolean maybe
    assert_failure 11
}

@test "is_safe_integer: accepts integers, rejects non-integers" {
    run is_safe_integer 42
    assert_success
    run is_safe_integer -7
    assert_success
    run is_safe_integer "abc"
    assert_failure 11
}

# --- is_safe_path / is_safe_valid_path / is_safe_existing_* ------------------------------------

@test "is_safe_path: accepts a plain relative path, empty string" {
    run is_safe_path "some/relative/path.txt"
    assert_success
    run is_safe_path ""
    assert_success
}

@test "is_safe_path: rejects traversal, absolute paths, and dangerous characters" {
    run is_safe_path "../etc/passwd"
    assert_failure 11
    run is_safe_path "/etc/passwd"
    assert_failure 11
    run is_safe_path 'foo;rm -rf /'
    assert_failure 11
}

@test "is_safe_valid_path: accepts a safe, syntactically valid path" {
    run is_safe_valid_path "some/relative/path.txt"
    assert_success
}

@test "is_safe_existing_path: succeeds for an existing path, fails for a non-existent one" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; cd '$lib_dir' && is_safe_existing_path core.sh"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; cd '$lib_dir' && is_safe_existing_path definitely/does/not/exist.txt"
    assert_failure 19
}

@test "is_safe_existing_directory: succeeds for a directory, fails for a file" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; cd '$lib_dir/..' && is_safe_existing_directory lib"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; cd '$lib_dir' && is_safe_existing_directory core.sh"
    assert_failure 17
}

@test "is_safe_existing_file: succeeds for a non-empty file, fails for a directory" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; cd '$lib_dir' && is_safe_existing_file core.sh"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; cd '$lib_dir/..' && is_safe_existing_file lib"
    assert_failure
}

# --- validate_json_array ------------------------------------------------------------------------

@test "validate_json_array: normalizes a JSON array of strings, trimming and de-duplicating" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; v='[\" a \", \"b\", \"b\"]'; validate_json_array v; echo \"\$v\""
    assert_success
    assert_output '["a","b"]'
}

@test "validate_json_array: converts a JSON string into a single-item array" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; v='\"hello\"'; validate_json_array v; echo \"\$v\""
    assert_success
    assert_output '["hello"]'
}

@test "validate_json_array: rejects a JSON object (caught by is_safe_input's brace check before it reaches jq)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; v='{\"a\":1}'; validate_json_array v"
    assert_failure 12
}

@test "validate_json_array: validates each item via the provided validator function" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; v='[\"ubuntu-latest\", \"not-a-runner\"]'; validate_json_array v '' is_safe_runner_os"
    assert_failure 11
}

# --- is_safe_runner_os -------------------------------------------------------------------------

@test "is_safe_runner_os: accepts a known runner, rejects an unknown one" {
    run is_safe_runner_os "ubuntu-latest"
    assert_success
    run is_safe_runner_os "not-a-real-runner"
    assert_failure 1
}

# --- is_safe_reason ----------------------------------------------------------------------------

@test "is_safe_reason: accepts a normal sentence with spaces" {
    run is_safe_reason "Emergency hotfix release"
    assert_success
}

@test "is_safe_reason: rejects a reason that looks like a command or path" {
    run is_safe_reason "--force"
    assert_failure
    run is_safe_reason "/etc/passwd"
    assert_failure
    run is_safe_reason "../secrets"
    assert_failure
}

@test "is_safe_reason: rejects a reason longer than 200 characters" {
    run is_safe_reason "$(printf 'a%.0s' {1..201})"
    assert_failure
}

# --- NuGet server validation ---------------------------------------------------------------------

@test "is_valid_nuget_server: accepts nuget, github, and https URLs; rejects garbage" {
    run is_valid_nuget_server "nuget"
    assert_success
    run is_valid_nuget_server "github"
    assert_success
    run is_valid_nuget_server "https://example.com/index.json"
    assert_success
    run is_valid_nuget_server "ftp://example.com"
    assert_failure
}

@test "validate_nuget_server: resolves 'nuget' to NuGet.org's name and URL" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; s=nuget; name=''; url=''; validate_nuget_server s name url; echo \"\$name|\$url\""
    assert_success
    assert_output "NuGet.org|https://api.nuget.org/v3/index.json"
}

@test "validate_nuget_server: resolves 'github' using \$repo_owner" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; repo_owner=acme; s=github; name=''; url=''; validate_nuget_server s name url; echo \"\$name|\$url\""
    assert_success
    assert_output "GitHub Packages|https://nuget.pkg.github.com/acme/index.json"
}

@test "validate_nuget_server: fails on an invalid server moniker" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; s='not-a-server'; name=''; url=''; validate_nuget_server s name url"
    assert_failure 4
}

# --- configuration / framework / runtime validation -----------------------------------------------

@test "is_valid_configuration / is_safe_configuration: accepts identifiers, warns on unknown ones" {
    run is_valid_configuration "Release"
    assert_success
    run is_safe_configuration "Release"
    assert_success
    run is_safe_configuration "Custom"
    assert_success
    run is_safe_configuration "not valid!"
    assert_failure 1
}

@test "is_valid_framework / is_safe_framework: accepts a TFM, rejects garbage" {
    run is_valid_framework "net10.0"
    assert_success
    run is_safe_framework "net10.0"
    assert_success
    run is_safe_framework "not-a-tfm"
    assert_failure 4
}

@test "is_valid_runtime / is_safe_runtime: accepts empty and known RIDs, rejects injection-shaped input" {
    run is_valid_runtime ""
    assert_success
    run is_safe_runtime "linux-x64"
    assert_success
    run is_safe_runtime "linux-x64; rm -rf /"
    assert_failure 4
}

@test "validate_runtime: lower-cases and trims the referenced variable" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; r='  LINUX-X64  '; validate_runtime r; echo \"[\$r]\""
    assert_success
    assert_output "[linux-x64]"
}

# --- validate_preprocessor_symbols -----------------------------------------------------------

@test "validate_preprocessor_symbols: accepts empty input" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; s=''; validate_preprocessor_symbols s; echo \"[\$s]\""
    assert_success
    assert_output "[]"
}

@test "validate_preprocessor_symbols: normalizes separators to semicolons and dedupes consecutive separators" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; s='DEBUG, TRACE:: FOO'; validate_preprocessor_symbols s; echo \"[\$s]\""
    assert_success
    assert_output "[DEBUG;TRACE;FOO]"
}

@test "validate_preprocessor_symbols: rejects an invalid symbol" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; s='1BAD'; validate_preprocessor_symbols s"
    assert_failure 4
}

# --- is_safe_secret ----------------------------------------------------------------------------

@test "is_safe_secret: accepts a normal value, rejects control characters" {
    run is_safe_secret "s3cr3t"
    assert_success
    run is_safe_secret "$(printf 'bad\x01value')"
    assert_failure 4
}

# --- percentage validation ---------------------------------------------------------------------

@test "is_valid_percentage: accepts 0-100, rejects out of range and non-integers" {
    run is_valid_percentage 0
    assert_success
    run is_valid_percentage 100
    assert_success
    run is_valid_percentage 101
    assert_failure
    run is_valid_percentage "abc"
    assert_failure
}

@test "is_safe_min_coverage_pct / is_safe_max_regression_pct: accept valid percentages" {
    run is_safe_min_coverage_pct 80
    assert_success
    run is_safe_max_regression_pct 20
    assert_success
    run is_safe_min_coverage_pct 150
    assert_failure 1
}

# --- MinVer tag prefix / prerelease id validation -----------------------------------------------

@test "is_valid_minverTagPrefix / is_safe_minverTagPrefix: accepts a plain tag prefix" {
    run is_valid_minverTagPrefix "v"
    assert_success
    run is_safe_minverTagPrefix "v"
    assert_success
}

@test "is_valid_minverPrereleaseId / is_safe_minverPrereleaseId: accepts a prerelease identifier" {
    run is_valid_minverPrereleaseId "preview.0"
    assert_success
    run is_safe_minverPrereleaseId "preview.0"
    assert_success
}

# --- escape_ere ----------------------------------------------------------------------------------

@test "escape_ere: escapes ERE special characters" {
    run escape_ere 'a.b*c[d]'
    assert_success
    assert_output 'a\.b\*c\[d\]'
}

@test "escape_ere: bug-exits with wrong argument count" {
    run escape_ere
    assert_failure 254
}
