#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/show-pr-comments.args.sh (with show-pr-comments.usage.sh), following the seams of the
# get_arguments() pipeline (see test_diff_shared_args.bats, the reference implementation). Each test sources core.sh and
# the files under test in a fresh, ambient-environment-free ('env -i') bash subshell.
#
# A fake 'gh' first on PATH answers the version and auth queries (verify_environment) and the two queries
# resolve_arguments() makes when the repository or the pull request number is not given: 'gh repo view' and
# 'gh pr view'. $FAKE_NO_REPO / $FAKE_NO_PR make them fail; $FAKE_UNAUTHENTICATED fails 'gh auth status'.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx err_missing_argument
declare -gx err_too_many_arguments
declare -gx err_unknown_argument

declare BATS_TEST_TMPDIR

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# Runs the snippet $1 with the optional environment assignments $2 (e.g. "FAKE_NO_PR=1").
_pc() {
    env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:+"$2"} bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/show-pr-comments.args.sh'
        source '$_src_dir/show-pr-comments.usage.sh'
        $1
    "
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} != version && ${1:-} != --version ]] || { echo "gh version $gh_min_version"; exit 0; }
case "$1 $2" in
    "auth status" ) [[ -z ${FAKE_UNAUTHENTICATED:-} ]] ;;
    "repo view" )   [[ -z ${FAKE_NO_REPO:-} ]] && echo acme/repo ;;
    "pr view" )     [[ -z ${FAKE_NO_PR:-} ]] && echo 7 ;;
    * )             exit 99 ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _pc "parse_arguments
             declare -p pr_number repo watch interval timeout"
    assert_success
    assert_output --partial 'pr_number=""'
    assert_output --partial 'repo=""'
    assert_output --partial 'watch="false"'
    assert_output --partial 'interval="15"'
    assert_output --partial 'timeout="900"'
}

@test "parse_arguments: the positional argument is the pull request number; the options set the other variables" {
    run _pc "parse_arguments 42 --repo acme/repo --watch --interval 5 --timeout 60
             declare -p pr_number repo watch interval timeout"
    assert_success
    assert_output --partial 'pr_number="42"'
    assert_output --partial 'repo="acme/repo"'
    assert_output --partial 'watch="true"'
    assert_output --partial 'interval="5"'
    assert_output --partial 'timeout="60"'
}

@test "parse_arguments: -r, -w, -i, and -t set the corresponding variables, case-insensitively" {
    run _pc "parse_arguments -R acme/repo -W -i 5 -T 60
             declare -p repo watch interval timeout"
    assert_success
    assert_output --partial 'repo="acme/repo"'
    assert_output --partial 'watch="true"'
    assert_output --partial 'interval="5"'
    assert_output --partial 'timeout="60"'
}

@test "parse_arguments: does not validate values (a non-numeric pull request number is taken as is)" {
    run _pc "parse_arguments abc --interval never
             declare -p pr_number interval"
    assert_success
    assert_output --partial 'pr_number="abc"'
    assert_output --partial 'interval="never"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --repo --interval --timeout; do
        run _pc "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: a second positional argument is rejected" {
    run _pc "parse_arguments 1 2; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Too many positional arguments: 2"
    refute_output --partial "AFTER"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the pull request number" {
    run _pc "parse_arguments --bogus; declare -p pr_number"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "pr_number="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _pc "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _pc "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when git and an authenticated gh are present" {
    run _pc "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing git and a missing gh together, and returns instead of exiting" {
    run _pc "is_tool_present() { [[ \$1 != git && \$1 != gh ]]; }
             verify_environment
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "'gh' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

@test "verify_environment: reports an unauthenticated gh" {
    run _pc "verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "FAKE_UNAUTHENTICATED=1"
    assert_success
    assert_output --partial "'gh' is not authenticated"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: keeps a given repository and number, and freezes the arguments" {
    run _pc "pr_number=42 repo=other/repo watch=true
             resolve_arguments
             declare -p pr_number repo watch interval timeout"
    assert_success
    assert_output --partial 'declare -rx pr_number="42"'
    assert_output --partial 'declare -rx repo="other/repo"'
    assert_output --partial 'declare -rx watch="true"'
    assert_output --partial 'declare -rx interval="15"'
    assert_output --partial 'declare -rx timeout="900"'
}

@test "resolve_arguments: without a repository and a number, takes both from gh (the current directory and branch)" {
    run _pc "resolve_arguments
             declare -p pr_number repo"
    assert_success
    assert_output --partial 'pr_number="7"'
    assert_output --partial 'repo="acme/repo"'
}

@test "resolve_arguments: with a number only, takes the repository from gh and keeps the number" {
    run _pc "pr_number=42
             resolve_arguments
             declare -p pr_number repo"
    assert_success
    assert_output --partial 'pr_number="42"'
    assert_output --partial 'repo="acme/repo"'
}

@test "resolve_arguments: reports every invalid value together, then exits before querying gh" {
    run _pc "pr_number=abc repo=just-a-name interval=0 timeout=-5
             resolve_arguments; echo AFTER" "FAKE_NO_REPO=1"
    assert_failure
    assert_output --partial "The pull request number must be a positive integer (provided 'abc')."
    assert_output --partial "The repository must be given as 'owner/repo' (provided 'just-a-name')."
    assert_output --partial "The interval must be a positive number of seconds (provided '0')."
    assert_output --partial "The timeout must be a positive number of seconds (provided '-5')."
    refute_output --partial "not in a GitHub repository"
}

@test "resolve_arguments: --repo without a number is an error" {
    run _pc "repo=acme/repo
             resolve_arguments; echo AFTER"
    assert_failure
    assert_output --partial "With '--repo', the pull request number is required"
}

@test "resolve_arguments: reports a directory outside a GitHub repository, and does not ask for its pull request" {
    run _pc "resolve_arguments
             echo \"errors=\$(get_errors)\"" "FAKE_NO_REPO=1"
    assert_success
    assert_output --partial "The current directory is not in a GitHub repository"
    refute_output --partial "has no pull request"
    assert_output --partial "errors=1"
}

@test "resolve_arguments: reports a current branch without a pull request" {
    run _pc "resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "FAKE_NO_PR=1"
    assert_success
    assert_output --partial "The current branch has no pull request"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _pc "get_arguments 42 --watch
             declare -p pr_number repo watch"
    assert_success
    assert_output --partial 'declare -rx pr_number="42"'
    assert_output --partial 'declare -rx repo="acme/repo"'
    assert_output --partial 'declare -rx watch="true"'
}

@test "get_arguments: -h prints the usage and exits 0, even with invalid values and no gh login" {
    run _pc "get_arguments -h abc --interval 0; echo AFTER" "FAKE_UNAUTHENTICATED=1"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: no pull request for the current branch ends the run with the error and the usage" {
    run _pc "get_arguments; echo AFTER" "FAKE_NO_PR=1"
    assert_failure
    assert_output --partial "The current branch has no pull request"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
