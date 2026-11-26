#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/lib/_predicates.json.sh: the JSON predicates and validators (jq, check-jsonschema).

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx failure
declare -gx err_invalid_arguments
declare -gx err_invalid_path
declare -gx err_not_file
declare -gx err_invalid_json
declare -gx err_unsafe_argument
declare BATS_TEST_TMPDIR

# --- is_json / is_json_file ----------------------------------------------------------

@test "is_json: accepts a well-formed JSON string, rejects garbage" {
    run is_json '{"a":1}'
    assert_success
    run is_json 'not json'
    assert_failure "$failure"
}

@test "is_json: bug-exits with the wrong argument count" {
    run is_json
    assert_failure "$err_invalid_arguments"
}

@test "is_json_file: accepts a file with well-formed JSON, rejects one with malformed JSON" {
    echo '{"a":1}' > "$BATS_TEST_TMPDIR/valid.json"
    echo 'not json' > "$BATS_TEST_TMPDIR/invalid.json"
    run is_json_file "$BATS_TEST_TMPDIR/valid.json"
    assert_success
    run is_json_file "$BATS_TEST_TMPDIR/invalid.json"
    assert_failure "$failure"
}

@test "is_json_file: fails for a non-existent file" {
    run is_json_file "$BATS_TEST_TMPDIR/does-not-exist.json"
    assert_failure "$failure"
}

@test "is_json_file: bug-exits on the wrong argument count or an invalid path" {
    run is_json_file
    assert_failure "$err_invalid_arguments"
    run is_json_file ""
    assert_failure "$err_invalid_path"
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

# --- is_valid_json_with_schema -------------------------------------------------------------------

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

@test "is_valid_json_with_schema: succeeds when the JSON file conforms to the schema" {
    _write_json_schema_fixtures
    run is_valid_json_with_schema "$BATS_TEST_TMPDIR/valid.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_success
}

@test "is_valid_json_with_schema: fails when the JSON file violates the schema" {
    _write_json_schema_fixtures
    run is_valid_json_with_schema "$BATS_TEST_TMPDIR/schema-violating.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_invalid_json"
    assert_output --partial "failed validation against the schema"
}

@test "is_valid_json_with_schema: fails with err_invalid_json for a malformed JSON document" {
    _write_json_schema_fixtures
    run is_valid_json_with_schema "$BATS_TEST_TMPDIR/malformed.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_invalid_json"
    assert_output --partial "is not well-formed"
}

@test "is_valid_json_with_schema: fails with err_invalid_json for a malformed schema file" {
    _write_json_schema_fixtures
    run is_valid_json_with_schema "$BATS_TEST_TMPDIR/valid.json" "$BATS_TEST_TMPDIR/malformed.json"
    assert_failure "$err_invalid_json"
    assert_output --partial "Schema file"
    assert_output --partial "is not well-formed"
}

@test "is_valid_json_with_schema: fails with err_not_file for a non-existent or empty JSON file, and never runs the schema check" {
    _write_json_schema_fixtures
    run is_valid_json_with_schema "$BATS_TEST_TMPDIR/does-not-exist.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_not_file"
    refute_output --partial "failed validation against the schema"
    run is_valid_json_with_schema "$BATS_TEST_TMPDIR/empty.json" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_not_file"
    refute_output --partial "failed validation against the schema"
}

@test "is_valid_json_with_schema: fails with err_not_file for a non-existent or empty JSON file when check-jsonschema is not on PATH" {
    _write_json_schema_fixtures
    local _path_without_check_jsonschema _json
    _path_without_check_jsonschema=$(echo "$PATH" | tr ':' '\n' | grep -v -F "$(dirname "$(command -v check-jsonschema)")" | paste -sd:)
    for _json in does-not-exist.json empty.json; do
        run bash -c "PATH='$_path_without_check_jsonschema'; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; is_valid_json_with_schema '$BATS_TEST_TMPDIR/$_json' '$BATS_TEST_TMPDIR/schema.json'"
        assert_failure "$err_not_file"
    done
}

@test "is_valid_json_with_schema: skips validation and succeeds when check-jsonschema is not on PATH" {
    _write_json_schema_fixtures
    local _path_without_check_jsonschema
    _path_without_check_jsonschema=$(echo "$PATH" | tr ':' '\n' | grep -v -F "$(dirname "$(command -v check-jsonschema)")" | paste -sd:)
    run bash -c "PATH='$_path_without_check_jsonschema'; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; is_valid_json_with_schema '$BATS_TEST_TMPDIR/schema-violating.json' '$BATS_TEST_TMPDIR/schema.json'"
    assert_success
    assert_output --partial "'check-jsonschema' is not installed"
}

@test "is_valid_json_with_schema: bug-exits with the wrong argument count" {
    run is_valid_json_with_schema "$BATS_TEST_TMPDIR/valid.json"
    assert_failure "$err_invalid_arguments"
}

@test "is_valid_json_with_schema: bug-exits on an invalid path argument" {
    run is_valid_json_with_schema "" "$BATS_TEST_TMPDIR/schema.json"
    assert_failure "$err_not_file"
}
