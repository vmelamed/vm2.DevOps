#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/rebuild-bench-history.args.sh (with rebuild-bench-history.usage.sh), following the seams of
# the get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each
# test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell. A fake
# 'gh' (version + auth status only) stands in for the real one.
#
# resolve_arguments() falls back to the owner of the repository that holds the script ($script_dir) when neither --owner
# nor $GITHUB_REPOSITORY_OWNER is given. _rh points $script_dir at a local repository without an 'origin' remote (or, with
# $3 == plain, at a directory outside any repository), so that fallback finds no owner. The fallback itself is covered end
# to end in test_rebuild_bench_history.bats.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_unknown_argument

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 with the optional environment assignments $2 (several, space-separated); $3 is the directory
# $script_dir points at: 'repo' (default) or 'plain'.
_rh() {
    # shellcheck disable=SC2086 # $2 holds zero or more assignments: word splitting is intended
    env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:-} bash -c "
        script_dir='$BATS_TEST_TMPDIR/${3:-repo}'      # core.sh keeps a preset script_dir, then freezes it
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/rebuild-bench-history.usage.sh'
        source '$_gh_scripts_dir/rebuild-bench-history.args.sh'
        $1
    "
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/plain" "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" init --quiet --initial-branch=main
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} != version && ${1:-} != --version ]] || { echo "gh version $gh_min_version"; exit 0; }
[[ "$*" == "auth status" ]] && exit 0
exit 99
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _rh "parse_arguments
             declare -p owner repeat workflow"
    assert_success
    assert_output --partial 'owner=""'
    assert_output --partial 'repeat="10"'
    assert_output --partial 'workflow="RebuildBenchHistory.yaml"'
}

@test "parse_arguments: the default repeat comes from \$REPEAT when it is set" {
    run _rh "parse_arguments
             declare -p repeat" "REPEAT=3"
    assert_success
    assert_output --partial 'repeat="3"'
}

@test "parse_arguments: --owner/-o, --repeat/-n, and --workflow/-w set the corresponding variables, case-insensitively" {
    run _rh "parse_arguments --owner acme --repeat 5 --workflow Other.yaml
             declare -p owner repeat workflow"
    assert_success
    assert_output --partial 'owner="acme"'
    assert_output --partial 'repeat="5"'
    assert_output --partial 'workflow="Other.yaml"'

    run _rh "parse_arguments -O acme -N 7 -W More.yaml
             declare -p owner repeat workflow"
    assert_success
    assert_output --partial 'owner="acme"'
    assert_output --partial 'repeat="7"'
    assert_output --partial 'workflow="More.yaml"'
}

@test "parse_arguments: does not validate values (a non-numeric repeat is taken as is)" {
    run _rh "parse_arguments --repeat many
             declare -p repeat"
    assert_success
    assert_output --partial 'repeat="many"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --owner --repeat --workflow; do
        run _rh "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: rejects an unknown option and any positional argument" {
    run _rh "parse_arguments --bogus; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "AFTER"

    run _rh "parse_arguments acme; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: acme"
    refute_output --partial "AFTER"
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _rh "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _rh "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: with \$GH_TOKEN set, succeeds silently" {
    run _rh "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS" "GH_TOKEN=dummy"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: \$BENCH_DISPATCH_PAT becomes \$GH_TOKEN when \$GH_TOKEN is not set" {
    run _rh "verify_environment; echo \"GH_TOKEN=\$GH_TOKEN\"" "BENCH_DISPATCH_PAT=the-pat"
    assert_success
    assert_output --partial "GH_TOKEN=the-pat"
    refute_output --partial "WARN"
}

@test "verify_environment: an explicit \$GH_TOKEN wins over \$BENCH_DISPATCH_PAT" {
    run _rh "verify_environment; echo \"GH_TOKEN=\$GH_TOKEN\"" "GH_TOKEN=the-token BENCH_DISPATCH_PAT=the-pat"
    assert_success
    assert_output --partial "GH_TOKEN=the-token"
}

@test "verify_environment: without either token, only warns that it relies on the ambient 'gh auth'" {
    run _rh "verify_environment; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "Neither \$GH_TOKEN nor \$BENCH_DISPATCH_PAT is set"
    assert_output --partial "NO_ERRORS"
}

@test "verify_environment: reports a missing gh and returns instead of exiting" {
    run _rh "is_tool_present() { [[ \$1 != gh ]]; }
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "GH_TOKEN=dummy"
    assert_success
    assert_output --partial "'gh' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: keeps a given owner and freezes the arguments" {
    run _rh "owner=acme repeat=3
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p owner repeat workflow"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx owner="acme"'
    assert_output --partial 'declare -rx repeat="3"'
    assert_output --partial 'declare -rx workflow="RebuildBenchHistory.yaml"'
}

@test "resolve_arguments: without --owner, takes the owner from \$GITHUB_REPOSITORY_OWNER" {
    run _rh "resolve_arguments
             declare -p owner" "GITHUB_REPOSITORY_OWNER=from-env"
    assert_success
    assert_output --partial 'declare -rx owner="from-env"'
}

@test "resolve_arguments: --owner wins over \$GITHUB_REPOSITORY_OWNER" {
    run _rh "owner=acme
             resolve_arguments
             declare -p owner" "GITHUB_REPOSITORY_OWNER=from-env"
    assert_success
    assert_output --partial 'declare -rx owner="acme"'
}

@test "resolve_arguments: reports a non-positive repeat and an undeterminable owner together, and returns" {
    local _repeat
    for _repeat in 0 -1 many; do
        run _rh "repeat='$_repeat'
                 resolve_arguments
                 echo REACHED
                 echo \"errors=\$(get_errors)\""
        assert_success
        assert_output --partial "repeat must be a positive integer (got '$_repeat')."
        assert_output --partial "Could not determine the GitHub owner."
        assert_output --partial "REACHED"
        assert_output --partial "errors=2"
    done
}

@test "resolve_arguments: reports an undeterminable owner when the script is not in a git repository at all" {
    # The fallback must find no owner and report it -- not bug-exit because \$script_dir is outside a working tree.
    run _rh "owner='' repeat=3
             resolve_arguments
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "" plain
    assert_success
    assert_output --partial "Could not determine the GitHub owner."
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _rh "get_arguments --owner acme --repeat 2
             declare -p owner repeat" "GH_TOKEN=dummy"
    assert_success
    assert_output --partial 'declare -rx owner="acme"'
    assert_output --partial 'declare -rx repeat="2"'
}

@test "get_arguments: -h prints the usage and exits 0, even with invalid values" {
    run _rh "get_arguments -h --repeat 0; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: invalid values end the run with the errors and the usage" {
    run _rh "get_arguments --repeat 0; echo AFTER" "GH_TOKEN=dummy"
    assert_failure
    assert_output --partial "repeat must be a positive integer (got '0')."
    assert_output --partial "Could not determine the GitHub owner."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
