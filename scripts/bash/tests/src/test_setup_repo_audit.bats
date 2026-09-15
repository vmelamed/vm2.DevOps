#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for compare_settings() in scripts/bash/src/setup-repo.audit.sh, as it
# behaves TODAY.
#
# compare_settings() is the one pure-logic, reusable engine behind setup-repo.sh --audit; it is
# exercised here against a faked 'gh' on $PATH returning canned JSON, so no real GitHub API call
# is ever made. audit_repo() itself (the orchestrator that calls compare_settings() several
# times for different endpoints/tables and prints a totals summary) is not covered here -- it is
# a thin driver with no independent logic of its own.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_src_dir="$(cd "$lib_dir/../src" && pwd)"

_sr() {
    local _path="${2:-/usr/bin:/bin}"
    env -i HOME="$HOME" PATH="$_path" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/setup-repo.defaults.sh'
        source '$_src_dir/setup-repo.audit.sh'
        $1
    "
}

_install_fake_gh_json() {
    local _bindir="$1" _json="$2"
    mkdir -p "$_bindir"
    cat > "$_bindir/gh" <<EOF
#!/usr/bin/env bash
echo '$_json'
exit 0
EOF
    chmod +x "$_bindir/gh"
}

# =====================================================================================
# Formal validation
# =====================================================================================

@test "compare_settings: bug-exits with the wrong argument count" {
    run _sr 'compare_settings "a" "b" "c"'
    assert_failure 254
    assert_output --partial "requires five or six arguments"
}

@test "compare_settings: bug-exits on a non-boolean display-format flag" {
    run _sr 'declare -A expected=(); declare -a summary=(0 0 0); compare_settings "a" "b" "c" expected summary'
    assert_failure 254
    assert_output --partial "to be 'true' or 'false'"
}

@test "compare_settings: bug-exits when argument 4 does not name an associative array" {
    run _sr 'declare -a not_assoc=(); declare -a summary=(0 0 0); compare_settings "a" "b" false not_assoc summary'
    assert_failure 254
}

@test "compare_settings: returns success immediately (no API call) when the expected table is empty" {
    run _sr 'declare -A expected=(); declare -a summary=(0 0 0)
             compare_settings "repos/a" "jq" false expected summary
             echo "RC=$?"
             declare -p summary'
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'summary=([0]="0" [1]="0" [2]="0")'
}

# =====================================================================================
# Match / difference / missing classification
# =====================================================================================

@test "compare_settings: classifies matching, different, and missing keys and tallies the summary" {
    _install_fake_gh_json "$BATS_TEST_TMPDIR/bin" '{"allow_squash_merge": true, "allow_rebase_merge": true}'
    run _sr 'declare -A expected=(["allow_squash_merge"]="false" ["allow_rebase_merge"]="true" ["missing_key"]="true")
             declare -a summary=(0 0 0)
             compare_settings "repos/a/b" "to_entries[] | \"\(.key)=\(.value)\"" false expected summary
             echo "RC=$?"
             declare -p summary' "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "✅"
    assert_output --partial "allow_rebase_merge"
    assert_output --partial "❓"
    assert_output --partial "allow_squash_merge"
    assert_output --partial "❌"
    assert_output --partial "missing_key"
    assert_output --partial "RC=0"
    assert_output --partial 'summary=([0]="1" [1]="1" [2]="1")'
}

@test "compare_settings: treats a secret-placeholder expected value as presence-only, never comparing its value" {
    _install_fake_gh_json "$BATS_TEST_TMPDIR/bin" '{"secrets":[{"name":"NUGET_API_KEY"}]}'
    run _sr "declare -A expected=([\"NUGET_API_KEY\"]=\"\$secret_str\" [\"RELEASE_PAT\"]=\"\$secret_str\")
             declare -a summary=(0 0 0)
             compare_settings 'repos/a/secrets' '.secrets[] | \"\(.name)=\$secret_str\"' false expected summary
             declare -p summary" "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "🆗"
    assert_output --partial "NUGET_API_KEY"
    refute_output --partial "\$secret_str"
    assert_output --partial "❌"
    assert_output --partial "RELEASE_PAT"
    assert_output --partial 'summary=([0]="1" [1]="0" [2]="1")'
}

@test "compare_settings: fails with err_tool_error when the GitHub API call fails" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/gh"
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    run _sr 'declare -A expected=(["x"]="y"); declare -a summary=(0 0 0)
             compare_settings "repos/a" "jq" false expected summary
             echo "RC=$?"' "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "Failed to fetch data from GitHub API"
    assert_output --partial "RC=66"
}

# =====================================================================================
# Display formatting: key capitalization and explicit ordering
# =====================================================================================

@test "compare_settings: with the display-format flag, replaces underscores and capitalizes keys" {
    _install_fake_gh_json "$BATS_TEST_TMPDIR/bin" '{"allow_squash_merge": true}'
    run _sr 'declare -A expected=(["allow_squash_merge"]="true")
             declare -a summary=(0 0 0)
             compare_settings "repos/a" "to_entries[] | \"\(.key)=\(.value)\"" true expected summary' "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    assert_output --partial "Allow squash merge"
    refute_output --partial "allow_squash_merge"
}

@test "compare_settings: an optional display-order array controls row order and renders '--' section headers" {
    _install_fake_gh_json "$BATS_TEST_TMPDIR/bin" '{"allow_squash_merge": true}'
    run _sr 'declare -A expected=(["allow_squash_merge"]="true" ["has_wiki"]="false")
             declare -a order=("--Header:" "has_wiki" "allow_squash_merge")
             declare -a summary=(0 0 0)
             compare_settings "repos/a" "to_entries[] | \"\(.key)=\(.value)\"" false expected summary order' "$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin"
    assert_success
    local _header_line _wiki_line _squash_line
    _header_line=$(grep -n "Header:" <<< "$output" | cut -d: -f1)
    _wiki_line=$(grep -n "has_wiki" <<< "$output" | cut -d: -f1)
    _squash_line=$(grep -n "allow_squash_merge" <<< "$output" | cut -d: -f1)
    [[ $_header_line -lt $_wiki_line && $_wiki_line -lt $_squash_line ]]
}
