#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/set-secret.sh, run as a subprocess. 'gh' is replaced by a fake on
# PATH that records every call and answers the two commands the script uses:
#   gh api ... (list the current secret names; FAKE_EXISTING, newline-separated)
#   gh secret set ... (exit code from FAKE_SET_EXIT, default 0)
# The secret value and the Y/N answers come from stdin, the same way a person would type them.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

declare -gx lib_dir
declare -gxi err_argument_value

_src_dir="$(cd "$lib_dir/../src" && pwd)"
_script="$_src_dir/set-secret.sh"

setup() {
    _bin="$BATS_TEST_TMPDIR/bin"
    _gh_log="$BATS_TEST_TMPDIR/gh.log"
    mkdir -p "$_bin"
    cat > "$_bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$GH_CALL_LOG"
case "$*" in
    "secret set "*) exit "${FAKE_SET_EXIT:-0}" ;;
    *"/secrets"*)     [[ -n ${FAKE_EXISTING:-} ]] && printf '%s\n' "$FAKE_EXISTING"; exit 0 ;;
    *)                exit 0 ;;
esac
EOF
    chmod +x "$_bin/gh"
    : > "$_gh_log"
}

# Runs set-secret.sh with the given arguments and stdin text, using the fake gh.
#   $1 stdin text (printf format), remaining args go to the script
_run_set_secret() {
    local _input=$1; shift
    run env -i HOME="$HOME" PATH="$_bin:/usr/local/bin:/usr/bin:/bin" GH_CALL_LOG="$_gh_log" \
        FAKE_EXISTING="${FAKE_EXISTING:-}" FAKE_SET_EXIT="${FAKE_SET_EXIT:-0}" \
        bash -c "printf '$_input' | '$_script' \"\$@\"" _ "$@"
}

# Prints the same answer once per vm2 repository, one per line, in printf format.
_answers() {
    printf "$1\\n%.0s" $(seq "$2")
}

_set_calls() {
    grep -c ' secret set ' "$_gh_log" || true
}

# --- argument validation ----------------------------------------------------------------------

@test "set-secret: rejects a secret name that is not a valid identifier" {
    _run_set_secret 'hunter2\n' 'not a name' --app actions
    assert_failure
    assert_output --partial "Invalid secret name"
    [[ $(_set_calls) -eq 0 ]]
}

@test "set-secret: rejects an unknown application" {
    _run_set_secret 'hunter2\n' MY_SECRET --app nosuchapp
    assert_failure
    assert_output --partial "Invalid app specified"
    [[ $(_set_calls) -eq 0 ]]
}

# --- the secret is set in every repository ----------------------------------------------------

@test "set-secret: an existing secret is updated in every vm2 repository" {
    FAKE_EXISTING="MY_SECRET" _run_set_secret 'hunter2\n' MY_SECRET --app actions
    assert_success
    local _repos
    _repos=$(env -i HOME="$HOME" PATH="/usr/bin:/bin" bash -c "source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1; echo \${#vm2_repositories[@]}")
    [[ $(_set_calls) -eq $_repos ]]
}

@test "set-secret: the set succeeds without an 'unbound variable' crash (regression: _rc is only assigned on failure)" {
    FAKE_EXISTING="MY_SECRET" _run_set_secret 'hunter2\n' MY_SECRET --app actions
    assert_success
    refute_output --partial "unbound variable"
    refute_output --partial "Failed to set"
}

@test "set-secret: the secret value never appears in the script's output" {
    FAKE_EXISTING="MY_SECRET" _run_set_secret 'hunter2\n' MY_SECRET --app actions
    refute_output --partial "hunter2"
}

# --- creating a missing secret ----------------------------------------------------------------

@test "set-secret: a missing secret is not set when the user declines to create it" {
    FAKE_EXISTING="OTHER_SECRET" _run_set_secret "$(_answers 'n' 12)" MY_SECRET --app actions
    assert_success
    [[ $(_set_calls) -eq 0 ]]
}

@test "set-secret: a missing secret is created when the user confirms" {
    FAKE_EXISTING="OTHER_SECRET" _run_set_secret "y\\nhunter2\\n$(_answers 'y' 11)" MY_SECRET --app actions
    assert_success
    [[ $(_set_calls) -gt 0 ]]
}

@test "set-secret: a repository with no secrets at all still gets the new secret (regression: is_in gets no list)" {
    _run_set_secret "y\\nhunter2\\n$(_answers 'y' 11)" MY_SECRET --app actions
    refute_output --partial "is_in() requires"
    assert_success
}

# --- dry run ----------------------------------------------------------------------------------

@test "set-secret: --dry-run never calls 'gh secret set'" {
    FAKE_EXISTING="MY_SECRET" _run_set_secret 'hunter2\n' MY_SECRET --app actions --dry-run
    [[ $(_set_calls) -eq 0 ]]
}

# --- failures ---------------------------------------------------------------------------------

@test "set-secret: a failing 'gh secret set' is reported and makes the script fail" {
    FAKE_EXISTING="MY_SECRET" FAKE_SET_EXIT=1 _run_set_secret 'hunter2\n' MY_SECRET --app actions
    assert_failure
    assert_output --partial "Failed to set secret MY_SECRET"
}
