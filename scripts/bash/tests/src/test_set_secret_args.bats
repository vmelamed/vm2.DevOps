#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/set-secret.args.sh (with set-secret.usage.sh), following the seams of the get_arguments()
# pipeline (see test_diff_shared_args.bats, the reference implementation). Each test sources core.sh and the files under
# test in a fresh, ambient-environment-free ('env -i') bash subshell. A fake 'gh' (version + auth status only) stands in
# for the real one, so verify_environment() never depends on the machine's login.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_argument_value
declare -gxi err_missing_argument
declare -gxi err_too_many_arguments
declare -gxi err_unknown_argument
declare -gx  default_repo_owner

declare BATS_TEST_TMPDIR

_src_dir="$(cd "$lib_dir/../src" && pwd)"

_ss() {
    env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/set-secret.args.sh'
        source '$_src_dir/set-secret.usage.sh'
        $1
    "
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    _fake_gh 0
}

# A fake gh that reports $gh_min_version (inherited from core.sh) and answers 'auth status' with the exit code $1.
_fake_gh() {
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<EOF
#!/usr/bin/env bash
[[ \${1:-} != version && \${1:-} != --version ]] || { echo "gh version \$gh_min_version"; exit 0; }
[[ "\$*" == "auth status" ]] && exit $1
exit 99
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves everything empty when no arguments are given (the defaults are applied later)" {
    run _ss "parse_arguments
             declare -p repo_owner app secret_name"
    assert_success
    assert_output --partial 'repo_owner=""'
    assert_output --partial 'app=""'
    assert_output --partial 'secret_name=""'
}

@test "parse_arguments: --repo-owner, --app, and --secret-name set the corresponding variables" {
    run _ss "parse_arguments --repo-owner acme --app dependabot --secret-name MY_SECRET
             declare -p repo_owner app secret_name"
    assert_success
    assert_output --partial 'repo_owner="acme"'
    assert_output --partial 'app="dependabot"'
    assert_output --partial 'secret_name="MY_SECRET"'
}

@test "parse_arguments: -o, -a, and -n set the corresponding variables, case-insensitively" {
    run _ss "parse_arguments -O acme -a dependabot -N MY_SECRET
             declare -p repo_owner app secret_name"
    assert_success
    assert_output --partial 'repo_owner="acme"'
    assert_output --partial 'app="dependabot"'
    assert_output --partial 'secret_name="MY_SECRET"'
}

@test "parse_arguments: the positional argument is the secret name" {
    run _ss "parse_arguments MY_SECRET
             declare -p secret_name"
    assert_success
    assert_output --partial 'secret_name="MY_SECRET"'
}

@test "parse_arguments: a second positional argument is rejected" {
    run _ss "parse_arguments ONE TWO; echo AFTER"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Too many positional arguments (secret name): TWO"
    refute_output --partial "AFTER"
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --repo-owner --app --secret-name; do
        run _ss "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: rejects an unknown option instead of taking it as the secret name" {
    run _ss "parse_arguments --bogus; declare -p secret_name"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "secret_name="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _ss "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _ss "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when git and an authenticated gh are present" {
    run _ss "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing git and a missing gh together, and returns instead of exiting" {
    run _ss "is_tool_present() { [[ \$1 != git && \$1 != gh ]]; }
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
    _fake_gh 1
    run _ss "verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "'gh' is not authenticated"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: applies the default app and owner, and freezes the arguments" {
    run _ss "secret_name=MY_SECRET
             resolve_arguments
             declare -p repo_owner app secret_name"
    assert_success
    assert_output --partial "declare -rx repo_owner=\"$default_repo_owner\""
    assert_output --partial 'declare -rx app="actions"'
    assert_output --partial 'declare -rx secret_name="MY_SECRET"'
}

@test "resolve_arguments: accepts the app in any case" {
    run _ss "app=Dependabot
             secret_name=MY_SECRET
             resolve_arguments
             declare -p app"
    assert_success
    assert_output --partial 'declare -rx app="Dependabot"'
}

@test "resolve_arguments: reports an invalid app and an invalid secret name together, then exits" {
    run _ss "app=bogus
             secret_name='not a name'
             resolve_arguments; echo AFTER"
    assert_failure
    assert_output --partial "Invalid app specified: 'bogus'"
    assert_output --partial "Invalid secret name specified: 'not a name'"
    refute_output --partial "AFTER"
}

@test "resolve_arguments: rejects a missing secret name" {
    run _ss "resolve_arguments; echo AFTER"
    assert_failure
    assert_output --partial "Invalid secret name specified: ''"
    refute_output --partial "AFTER"
}

@test "resolve_arguments: rejects a secret name that starts with GITHUB_ (reserved by GitHub)" {
    run _ss "secret_name=GITHUB_TOKEN
             resolve_arguments; echo AFTER"
    assert_failure
    assert_output --partial "Invalid secret name specified: 'GITHUB_TOKEN'"
    refute_output --partial "AFTER"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _ss "get_arguments --app codespaces --repo-owner acme MY_SECRET
             declare -p repo_owner app secret_name"
    assert_success
    assert_output --partial 'declare -rx repo_owner="acme"'
    assert_output --partial 'declare -rx app="codespaces"'
    assert_output --partial 'declare -rx secret_name="MY_SECRET"'
}

@test "get_arguments: -h prints the usage and exits 0, even with an invalid app and no gh login" {
    _fake_gh 1
    run _ss "get_arguments -h --app bogus; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: reports the environment and the argument errors together, then exits" {
    _fake_gh 1
    run _ss "get_arguments --app bogus MY_SECRET; echo AFTER"
    assert_failure
    assert_output --partial "'gh' is not authenticated"
    assert_output --partial "Invalid app specified: 'bogus'"
    refute_output --partial "AFTER"
}
