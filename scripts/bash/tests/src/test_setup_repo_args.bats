#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/setup-repo.args.sh, as it behaves TODAY.
#
# Mirrors the approach used for diff-shared.args.sh: each test sources core.sh and the file(s)
# under test in a fresh, ambient-environment-free bash subshell.
#
# setup-repo.args.sh and setup-repo.usage.sh are self-contained (get_arguments() and
# usage_text() need only the variables/functions the args parser itself declares and core.sh's
# library) -- setup-repo.defaults.sh is deliberately NOT sourced here, matching the real
# setup-repo.sh's own order: it parses arguments FIRST (so --vm2-repos can override the
# default), only resolving and freezing vm2_repos afterward, and sources setup-repo.defaults.sh
# later still. Sourcing defaults.sh here would freeze vm2_repos readonly (it declares
# 'declare -xr vm2_repos', matching the real script's precondition that vm2_repos is already
# resolved by the time defaults.sh loads) before get_arguments() ever runs, so a test
# exercising --vm2-repos would crash on "vm2_repos: readonly variable" instead of exercising
# real behavior.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_too_many_arguments
declare -gxi err_unknown_argument
declare -gxi failure

_src_dir="$(cd "$lib_dir/../src" && pwd)"

declare BATS_TEST_TMPDIR

# A fake 'gh' first on PATH answers verify_environment()'s version and auth queries, so the tests never depend on the
# machine's gh login; $FAKE_UNAUTHENTICATED fails 'gh auth status'.
setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} != version && ${1:-} != --version ]] || { echo "gh version $gh_min_version"; exit 0; }
[[ "$*" == "auth status" ]] && { [[ -z ${FAKE_UNAUTHENTICATED:-} ]]; exit; }
exit 99
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}

# Runs the snippet $1 with the optional environment assignments $2 (several, space-separated).
_sr() {
    # shellcheck disable=SC2086 # $2 holds zero or more assignments: word splitting is intended
    env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:-} bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/setup-repo.args.sh'
        source '$_src_dir/setup-repo.usage.sh'
        declare -a arguments=()
        vm2_repos=\"\$HOME/repos/vm2\"
        repo_path=''
        visibility='public'
        branch='main'
        interactive_vars=false
        interactive_secrets=false
        configure_local=true
        audit=false
        main_protection_rs_name=''
        description=''
        use_ssh=true
        use_https=false
        set_quiet
        $1
    "
}

@test "get_arguments: the sole positional argument becomes repo_path" {
    run _sr "get_arguments myrepo; declare -p repo_path"
    assert_success
    assert_output --partial 'repo_path="myrepo"'
}

@test "get_arguments: a second positional argument fails with usage (too many arguments)" {
    run _sr "get_arguments repo1 repo2"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Too many positional arguments"
}

@test "get_arguments: rejects an unknown option instead of taking it as the project directory" {
    # The '-* )' arm must stop parsing before '--bogus' becomes repo_path, so the trailing 'declare -p' never runs.
    run _sr "get_arguments --bogus
              declare -p repo_path"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "repo_path="
}

@test "get_arguments: --owner, --branch, --visibility, --ruleset-name, and --description set the corresponding variables" {
    run _sr "get_arguments --owner acme --branch dev --visibility private --ruleset-name 'main protection' --description 'a repo'
              declare -p repo_owner branch visibility main_protection_rs_name description"
    assert_success
    assert_output --partial 'repo_owner="acme"'
    assert_output --partial 'branch="dev"'
    assert_output --partial 'visibility="private"'
    assert_output --partial 'main_protection_rs_name="main protection"'
    assert_output --partial 'description="a repo"'
}

@test "get_arguments: -n, -o, -b, and -rs are the short forms of the same options" {
    run _sr "get_arguments -o acme -b dev -rs 'main protection'
              declare -p repo_owner branch main_protection_rs_name"
    assert_success
    assert_output --partial 'repo_owner="acme"'
    assert_output --partial 'branch="dev"'
    assert_output --partial 'main_protection_rs_name="main protection"'
}

@test "get_arguments: --ssh and --https are mutually exclusive, each clearing the other" {
    run _sr "get_arguments --ssh; declare -p use_ssh use_https"
    assert_success
    assert_output --partial 'use_ssh="true"'
    assert_output --partial 'use_https="false"'

    run _sr "get_arguments --https; declare -p use_ssh use_https"
    assert_success
    assert_output --partial 'use_ssh="false"'
    assert_output --partial 'use_https="true"'
}

@test "get_arguments: --interactive-vars, --interactive-secrets, --skip-local-config, and --audit set their flags" {
    run _sr "get_arguments --interactive-vars --interactive-secrets --skip-local-config --audit
              declare -p interactive_vars interactive_secrets configure_local audit"
    assert_success
    assert_output --partial 'interactive_vars="true"'
    assert_output --partial 'interactive_secrets="true"'
    assert_output --partial 'configure_local="false"'
    assert_output --partial 'audit="true"'
}

@test "get_arguments: -iv, -is, -slc, and -a are the short forms of the same switches" {
    run _sr "get_arguments -iv -is -slc -a
              declare -p interactive_vars interactive_secrets configure_local audit"
    assert_success
    assert_output --partial 'interactive_vars="true"'
    assert_output --partial 'interactive_secrets="true"'
    assert_output --partial 'configure_local="false"'
    assert_output --partial 'audit="true"'
}

@test "get_arguments: fails with usage when a value-taking option is given without a value" {
    run _sr "get_arguments --owner"
    assert_failure "$err_missing_argument"
    assert_output --partial "Missing owner after '--owner'"
}

@test "get_arguments: --vm2-repos overrides the default vm2_repos" {
    run _sr "get_arguments --vm2-repos /some/other/path; declare -p vm2_repos"
    assert_success
    assert_output --partial 'vm2_repos="/some/other/path"'
}

@test "get_arguments: -h prints usage and exits 0" {
    run _sr "get_arguments -h"
    assert_success
    assert_output --partial "Usage:"
}

@test "get_arguments: --help prints the long usage text (includes common switches)" {
    run _sr "get_arguments --help"
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "--verbose"
}

@test "get_arguments: options are matched case-insensitively" {
    run _sr "get_arguments --OWNER acme; declare -p repo_owner"
    assert_success
    assert_output --partial 'repo_owner="acme"'
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when git, an authenticated gh, jq, and yq are present" {
    run _sr "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports every missing tool together, and returns instead of exiting" {
    run _sr "is_tool_present() { [[ \$1 != git && \$1 != gh && \$1 != jq && \$1 != yq ]]; }
             verify_environment
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "'gh' is not installed"
    assert_output --partial "'jq' is not installed"
    assert_output --partial "'yq' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "errors=4"
}

@test "verify_environment: reports an unauthenticated gh" {
    run _sr "verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" "FAKE_UNAUTHENTICATED=1"
    assert_success
    assert_output --partial "'gh' is not authenticated"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: requires the vm2 repositories on 'main' by default" {
    run _sr "resolve_arguments
             declare -p branches"
    assert_success
    assert_output --partial 'branches="main"'
}

@test "resolve_arguments: --current-branch lifts the 'main' requirement" {
    run _sr "current_branch=true
             resolve_arguments
             declare -p branches"
    assert_success
    assert_output --partial 'branches=""'
}

@test "resolve_arguments: freezes the switches" {
    run _sr "resolve_arguments
             declare -p current_branch branches interactive_vars interactive_secrets purge_vars purge_secrets configure_local audit"
    assert_success
    assert_output --partial "declare -rx current_branch="
    assert_output --partial "declare -rx branches="
    assert_output --partial "declare -rx interactive_vars="
    assert_output --partial "declare -rx interactive_secrets="
    assert_output --partial "declare -rx purge_vars="
    assert_output --partial "declare -rx purge_secrets="
    assert_output --partial "declare -rx configure_local="
    assert_output --partial "declare -rx audit="
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: -h prints the usage and exits 0, even with an unauthenticated gh" {
    run _sr "get_arguments -h; echo AFTER" "FAKE_UNAUTHENTICATED=1"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: an unauthenticated gh ends the run with the error and the usage" {
    run _sr "get_arguments myrepo; echo AFTER" "FAKE_UNAUTHENTICATED=1"
    assert_failure
    assert_output --partial "'gh' is not authenticated"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
