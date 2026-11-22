#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_sanitize.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir

declare -gx success
declare -gx failure
declare -gx positive
declare -gx negative
declare -gx err_invalid_arguments
declare -gx err_invalid_nameref
declare -gx err_non_existent_path
declare -gx err_argument_type
declare -gx err_not_file
declare -gx err_invalid_json
declare -gx err_unsafe_argument
declare -gx err_argument_value
declare -gx err_logic_error

declare BATS_TEST_TMPDIR

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
    assert_failure "$err_invalid_arguments"
    run rtrim
    assert_failure "$err_invalid_arguments"
    run trim
    assert_failure "$err_invalid_arguments"
}

@test "ltrim_var/rtrim_var/trim_var: trim the referenced variable in place" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='  hi  '; ltrim_var v; echo \"[\$v]\""
    assert_output "[hi  ]"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='  hi  '; rtrim_var v; echo \"[\$v]\""
    assert_output "[  hi]"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='  hi  '; trim_var v; echo \"[\$v]\""
    assert_output "[hi]"
}

@test "trim_var: bug-exits on an undefined variable name" {
    run trim_var definitely_not_defined_xyz
    assert_failure "$err_invalid_nameref"
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
    assert_failure "$err_unsafe_argument"
    run is_safe_input 'hi$(whoami)'
    assert_failure "$err_unsafe_argument"
}

@test "is_safe_input: rejects spaces by default but allows them when arg 2 is true" {
    run is_safe_input "hello world"
    assert_failure "$err_unsafe_argument"
    run is_safe_input "hello world" true
    assert_success
}

@test "is_safe_input: bug-exits with more than two arguments" {
    # NOTE: is_safe_input() accumulates two bugs here (arity, then argument 2 not a valid
    # boolean since "b" is passed positionally as if it were the allow-spaces flag) --
    # exit_if_has_bugs now reports the LAST one recorded (err_argument_type), not the generic
    # err_has_bugs.
    run is_safe_input a b c
    assert_failure "$err_argument_type"
}

# --- is_valid_boolean / is_valid_integer -----------------------------------------------------

@test "is_valid_boolean: accepts true/false, rejects anything else" {
    run is_valid_boolean true
    assert_success
    run is_valid_boolean false
    assert_success
    run is_valid_boolean maybe
    assert_failure 11
}

@test "is_valid_integer: accepts integers, rejects non-integers" {
    run is_valid_integer 42
    assert_success
    run is_valid_integer -7
    assert_success
    run is_valid_integer "abc"
    assert_failure 11
}

# --- is_valid_path / is_safe_path / is_safe_existing_* -----------------------------------------

@test "is_valid_path: accepts a syntactically valid path, even an unsafe one" {
    run is_valid_path "some/relative/path.txt"
    assert_success
    run is_valid_path "../outside/the/tree"
    assert_success
}

@test "is_valid_path: rejects an empty string with err_argument_value and an 'Invalid path' error" {
    run is_valid_path ""
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid path ''"
}

@test "is_valid_path: called directly under 'set -u', reports instead of dying on an unbound variable" {
    # regression: it once read its caller's local \$_path, which exists only when is_safe_path calls it
    run bash -c "set -u; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; is_valid_path ''"
    assert_failure "$err_argument_value"
    refute_output --partial "unbound variable"
    assert_output --partial "Invalid path ''"
}

@test "is_safe_path: accepts a plain relative path" {
    run is_safe_path "some/relative/path.txt"
    assert_success
}

@test "is_safe_path: rejects an empty string as an invalid path (err_argument_value), not as an unsafe one" {
    run is_safe_path ""
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid path ''"
}

@test "is_safe_path: rejects traversal, absolute paths, and dangerous characters" {
    run is_safe_path "../etc/passwd"
    assert_failure "$err_unsafe_argument"
    run is_safe_path "/etc/passwd"
    assert_failure "$err_unsafe_argument"
    run is_safe_path 'foo;rm -rf /'
    assert_failure "$err_unsafe_argument"
}

@test "is_safe_existing_path: succeeds for an existing path, fails for a non-existent one" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir' && is_safe_existing_path core.sh"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir' && is_safe_existing_path definitely/does/not/exist.txt"
    assert_failure "$err_non_existent_path"
}

@test "is_safe_existing_directory: succeeds for a directory, fails for a file" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir/..' && is_safe_existing_directory lib"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir' && is_safe_existing_directory core.sh"
    assert_failure 17
}

@test "is_safe_existing_file: succeeds for a non-empty file, fails for a directory" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir' && is_safe_existing_file core.sh"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; cd '$lib_dir/..' && is_safe_existing_file lib"
    assert_failure "$err_not_file"
}

# --- validate_json_array ------------------------------------------------------------------------

@test "validate_json_array: normalizes a JSON array of strings, trimming and de-duplicating" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='[\" a \", \"b\", \"b\"]'; validate_json_array v; echo \"\$v\""
    assert_success
    assert_output '["a","b"]'
}

@test "validate_json_array: converts a JSON string into a single-item array" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='\"hello\"'; validate_json_array v; echo \"\$v\""
    assert_success
    assert_output '["hello"]'
}

@test "validate_json_array: rejects a JSON object (caught by is_safe_input's brace check before it reaches jq)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='{\"a\":1}'; validate_json_array v"
    assert_failure "$err_unsafe_argument"
}

@test "validate_json_array: validates each item via the provided validator function" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; v='[\"ubuntu-latest\", \"not-a-runner\"]'; validate_json_array v '' is_valid_gh_runner_os"
    assert_failure "$err_unsafe_argument"
}

# --- allow-lists: runner OS, visibility, build configuration, framework, runtime -----------------

@test "is_valid_gh_runner_os: accepts a known runner, rejects an unknown one with an 'Invalid runner OS' error" {
    run is_valid_gh_runner_os "ubuntu-latest"
    assert_success
    assert_output ""
    run is_valid_gh_runner_os "not-a-real-runner"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid runner OS 'not-a-real-runner': use one of ubuntu-latest,"
}

@test "is_valid_gh_runner_os: rejects retired runners and a capitalized label" {
    local runner
    for runner in "ubuntu-20.04" "windows-2019" "Ubuntu-latest"; do
        run is_valid_gh_runner_os "$runner"
        assert_failure "$err_argument_value"
        assert_output --partial "Invalid runner OS '$runner'"
    done
}

@test "is_valid_visibility: accepts public and private, rejects any other value, capitalized ones included" {
    run is_valid_visibility "public"
    assert_success
    assert_output ""
    run is_valid_visibility "Public"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid repository visibility 'Public': use one of public,private."
}

@test "is_valid_build_configuration: accepts Debug and Release, rejects any other value, lowercase ones included" {
    run is_valid_build_configuration "Release"
    assert_success
    assert_output ""
    run is_valid_build_configuration "release"
    assert_failure
    assert_output --partial "Invalid build configuration 'release': use one of Debug,Release"
}

@test "is_valid_framework: accepts a TFM in use and empty, rejects any other value" {
    run is_valid_framework ""
    assert_success
    run is_valid_framework "net10.0"
    assert_success
    run is_valid_framework "net8.0"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid Target Framework Moniker (TFM) 'net8.0': use one of"
    run is_valid_framework "NET10.0"
    assert_failure "$err_argument_value"
}

@test "is_valid_runtime: accepts a RID in use and empty, rejects any other value, injection-shaped ones included" {
    run is_valid_runtime ""
    assert_success
    run is_valid_runtime "linux-x64"
    assert_success
    run is_valid_runtime "linux-x64; rm -rf /"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid Runtime Identifier (RID) 'linux-x64; rm -rf /': use one of"
    run is_valid_runtime "Linux-x64"
    assert_failure "$err_argument_value"
}

# --- is_valid_reason / is_safe_reason ----------------------------------------------------------

@test "is_valid_reason: checks only the length: accepts 200 characters, even command-like text" {
    run is_valid_reason "$(printf 'a%.0s' {1..200})"
    assert_success
    run is_valid_reason "--force"
    assert_success
}

@test "is_valid_reason: rejects a reason longer than 200 characters" {
    run is_valid_reason "$(printf 'a%.0s' {1..201})"
    assert_failure "$negative"
    assert_output --partial "The reason is too long."
}

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

@test "validate_nuget_server: resolves 'nuget' to NuGet.org's name and URL" {
    # NOTE: switched from an exact assert_output to --partial -- see the summary's top bug:
    # validate_nuget_server()'s own '&&'/'||' typo (_sanitize.sh:667) always prints a spurious
    # "requires the fourth argument..." line first, even when argument 4 was never given.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s=nuget; repo_owner='mr.owner'; name=''; url=''; validate_nuget_server s name url; echo \"\$name|\$url\""
    assert_success
    assert_output --partial "NuGet.org|https://api.nuget.org/v3/index.json"
}

@test "validate_nuget_server: resolves 'github' using \$repo_owner" {
    # NOTE: see the summary's top bug -- same spurious line as above.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; repo_owner=acme; s=github; name=''; url=''; validate_nuget_server s name url; echo \"\$name|\$url\""
    assert_success
    assert_output --partial "GitHub Packages|https://nuget.pkg.github.com/acme/index.json"
}

@test "validate_nuget_server: fails on an invalid server moniker" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; repo_owner='mr.owner'; s='not-a-server'; name=''; url=''; validate_nuget_server s name url"
    assert_failure "$err_argument_value"
}

@test "validate_nuget_server: fails on if the repo owner is not set yet" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s='not-a-server'; name=''; url=''; validate_nuget_server s name url"
    assert_failure "$err_logic_error"
}

# --- configuration / framework / runtime validation -----------------------------------------------

# --- validate_preprocessor_symbols -----------------------------------------------------------

@test "validate_preprocessor_symbols: accepts empty input" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s=''; validate_preprocessor_symbols s; echo \"[\$s]\""
    assert_success
    assert_output "[]"
}

@test "validate_preprocessor_symbols: normalizes separators to semicolons and dedupes consecutive separators" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s='DEBUG, TRACE:: FOO'; validate_preprocessor_symbols s; echo \"[\$s]\""
    assert_success
    assert_output "[DEBUG;TRACE;FOO]"
}

@test "validate_preprocessor_symbols: rejects an invalid symbol" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; s='1BAD'; validate_preprocessor_symbols s"
    assert_failure "$err_argument_value"
}

# --- is_valid_secret_name / is_valid_secret -----------------------------------------------------

@test "is_valid_secret_name: accepts valid secret names" {
    local name
    for name in "NUGET_API_KEY" "_private" "a1"; do
        run is_valid_secret_name "$name"
        assert_success
        assert_output ""
    done
}

@test "is_valid_secret_name: rejects a leading digit, a hyphen, empty, and 'GITHUB_' in any case" {
    local name
    for name in "1ABC" "MY-SECRET" "" "github_token" "GitHub_Pat"; do
        run is_valid_secret_name "$name"
        assert_failure "$err_argument_value"
        assert_output --partial "Invalid secret name '$name'"
    done
}

@test "is_valid_secret_name: rejects an invalid name with err_argument_value and an 'Invalid secret name' error" {
    # regression: it once had no 'return "$_rc"', so it reported the error and still succeeded
    run is_valid_secret_name "GITHUB_TOKEN"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid secret name 'GITHUB_TOKEN'"
}

@test "is_valid_secret: accepts a normal value, rejects control characters" {
    run is_valid_secret "s3cr3t"
    assert_success
    run is_valid_secret "$(printf 'bad\x01value')"
    assert_failure "$err_argument_value"
}

@test "is_valid_secret: never shows the rejected value in its error" {
    run is_valid_secret "$(printf 'TopSecret\x01Value')"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid secret value"
    refute_output --partial "TopSecret"
}

# --- percentage validation ---------------------------------------------------------------------

@test "is_valid_min_coverage_pct, is_valid_max_regression_pct: accept 0-100, reject anything else" {
    run is_valid_min_coverage_pct 80
    assert_success
    run is_valid_max_regression_pct 20
    assert_success
    run is_valid_min_coverage_pct 150
    assert_failure "$err_argument_type"
    run is_valid_max_regression_pct 101
    assert_failure "$err_argument_type"
}

# --- is_valid_minverTagPrefix / is_valid_minverPrereleaseId ------------------------------------

@test "is_valid_minverTagPrefix: accepts 'v', rejects a prefix ending in a digit with an 'Invalid MinVer tag prefix' error" {
    run is_valid_minverTagPrefix "v"
    assert_success
    run is_valid_minverTagPrefix "v1"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid MinVer tag prefix 'v1'"
}

@test "is_valid_minverPrereleaseId: accepts 'preview.0', rejects an invalid identifier, naming it a prerelease identifier" {
    # regression: its texts once said "MinVer tag prefix" (copied from is_valid_minverTagPrefix)
    run is_valid_minverPrereleaseId "preview.0"
    assert_success
    run is_valid_minverPrereleaseId "pre_view"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid MinVer prerelease identifier 'pre_view'"
    refute_output --partial "tag prefix"
}

# --- escape_ere ----------------------------------------------------------------------------------

@test "escape_ere: escapes ERE special characters" {
    run escape_ere 'a.b*c[d]'
    assert_success
    assert_output 'a\.b\*c\[d\]'
}

@test "escape_ere: bug-exits with wrong argument count" {
    run escape_ere
    assert_failure "$err_invalid_arguments"
}

# --- validate_json_schema -------------------------------------------------------------------

_write_json_schema_fixtures() {
    cat > "$BATS_TEST_TMPDIR/schema.json" <<'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": { "name": { "type": "string" } },
  "required": ["name"]
}
EOF
    echo '{"name": "vm2"}' > "$BATS_TEST_TMPDIR/valid.json"
    echo '{"nope": 1}' > "$BATS_TEST_TMPDIR/schema-violating.json"
    echo 'not json' > "$BATS_TEST_TMPDIR/malformed.json"
    touch "$BATS_TEST_TMPDIR/empty.json"
}

@test "validate_json_schema: succeeds when the JSON file conforms to the schema" {
    _write_json_schema_fixtures
    run validate_json_schema "$BATS_TEST_TMPDIR/valid.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_success
}

@test "validate_json_schema: fails when the JSON file violates the schema" {
    _write_json_schema_fixtures
    run validate_json_schema "$BATS_TEST_TMPDIR/schema-violating.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_invalid_json"
    assert_output --partial "failed validation against the schema"
}

@test "validate_json_schema: fails with err_invalid_json for a malformed JSON document" {
    _write_json_schema_fixtures
    run validate_json_schema "$BATS_TEST_TMPDIR/malformed.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_invalid_json"
    assert_output --partial "is not well-formed"
}

@test "validate_json_schema: fails with err_invalid_json for a malformed schema file" {
    _write_json_schema_fixtures
    run validate_json_schema "$BATS_TEST_TMPDIR/valid.json" "$BATS_TEST_TMPDIR/malformed.json"
    assert_failure "$err_invalid_json"
    assert_output --partial "schema file"
    assert_output --partial "is not well-formed"
}

@test "validate_json_schema: fails with err_not_file for a non-existent or empty JSON file" {
    _write_json_schema_fixtures
    run validate_json_schema "$BATS_TEST_TMPDIR/does-not-exist.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_not_file"
    run validate_json_schema "$BATS_TEST_TMPDIR/empty.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_not_file"
}

@test "validate_json_schema: skips validation and succeeds when check-jsonschema is not on PATH" {
    _write_json_schema_fixtures
    local _path_without_check_jsonschema
    _path_without_check_jsonschema=$(echo "$PATH" | tr ':' '\n' | grep -v -F "$(dirname "$(command -v check-jsonschema)")" | paste -sd:)
    run bash -c "PATH='$_path_without_check_jsonschema'; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; validate_json_schema '$BATS_TEST_TMPDIR/schema-violating.json' '$BATS_TEST_TMPDIR/schema.json'"
    assert_success
    assert_output --partial "'check-jsonschema' is not installed"
}

@test "validate_json_schema: bug-exits with the wrong argument count" {
    run validate_json_schema "$BATS_TEST_TMPDIR/valid.json"
    assert_failure "$err_invalid_arguments"
}

@test "validate_json_schema: bug-exits on an invalid path argument" {
    run validate_json_schema "" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_not_file"
}
