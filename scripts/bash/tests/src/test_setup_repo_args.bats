#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/setup-repo.args.sh (with setup-repo.usage.sh).
#
# These files are designed to be 'source'd from setup-repo.sh, after core.sh. Each test spawns a fresh, ambient-environment-free
# ('env -i') bash subshell that sources core.sh and then the files under test, so every test starts from a pristine,
# deterministic state. setup-repo.defaults.sh is deliberately NOT sourced: the real setup-repo.sh sources it only after
# get_arguments() has resolved the arguments.
#
# get_arguments() is a pipeline of stages, and the tests follow its seams (the same layout as test_diff_shared_args.bats):
#   - parse_arguments():    CLI tokens -> variables. Pure: no file system, no git, so these tests need no fixture.
#   - verify_environment(): argument-independent preconditions (tools). Reports, never exits.
#   - resolve_arguments():  validates, canonicalizes, and derives the variables (repo_path, repo_name, repo, ci_yaml), then
#                           freezes them. Needs real git repositories, so these tests build a hermetic, local-only $VM2_REPOS
#                           under $BATS_TEST_TMPDIR (_make_vm2_repos), and set $HOME there too: resolve_repo_root() falls back
#                           to searching all of $HOME for a target it cannot find under $VM2_REPOS.
#   - get_arguments():      the orchestration only: a few end-to-end tests over the same fixture.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

declare BATS_TEST_TMPDIR

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx err_missing_argument
declare -gx err_too_many_arguments
declare -gx err_unknown_argument

_src_dir="$(cd "$lib_dir/../src" && pwd)"

setup() {
    # canonical: resolve_vm2_repos() and resolve_repo_root() return realpath-ed paths
    _tmp=$(realpath "$BATS_TEST_TMPDIR")
    _vm2="$_tmp/vm2"

    # A fake 'gh', first on the PATH: with $HOME in the test's temporary directory, the real 'gh' would find no credentials.
    # verify_environment() needs only its version and 'auth status'.
    mkdir -p "$_tmp/bin"
    cat > "$_tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$*" in
    --version )   echo "gh version 2.80.0 (2026-01-01)"; exit 0 ;;
    "auth status" ) exit 0 ;;
esac
echo "unexpected gh call: $*" >&2
exit 1
GH
    chmod +x "$_tmp/bin/gh"
}

# Sources core.sh, setup-repo.args.sh, and setup-repo.usage.sh inside a fresh env -i subshell, with $HOME set to the
# test's own temporary directory and the fake 'gh' first on the PATH, then runs the caller-supplied bash snippet.
_sr() {
    env -i HOME="$_tmp" PATH="$_tmp/bin:/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/setup-repo.args.sh'
        source '$_src_dir/setup-repo.usage.sh'
        $1
    "
}

# A local-only (no origin remote) git repository on 'main', with a CI.yaml (including a gate job) and one stable tag: it
# passes __validate_repo_root()'s checks without any network activity (see test_git_vm2.bats).
_make_repo() {
    local _dir="$1"
    mkdir -p "$_dir/.github/workflows"
    git -C "$_dir" init --quiet --initial-branch=main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    printf 'name: CI\njobs:\n  postrun-ci:\n    name: Postrun-CI\n' > "$_dir/.github/workflows/CI.yaml"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: initial commit"
    git -C "$_dir" tag v1.0.0
}

# A hermetic $VM2_REPOS: vm2.DevOps, vm2.Templates, and one target, vm2.Target (with a sub-directory 'src').
_make_vm2_repos() {
    _make_repo "$_vm2/vm2.DevOps"
    _make_repo "$_vm2/vm2.Templates"
    mkdir -p "$_vm2/vm2.Templates/templates/AddNewPackage/content"
    _make_repo "$_vm2/vm2.Target"
    mkdir -p "$_vm2/vm2.Target/src"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: the sole positional argument becomes repo_path" {
    run _sr "parse_arguments myrepo
             declare -p repo_path"
    assert_success
    assert_output --partial 'repo_path="myrepo"'
}

@test "parse_arguments: a second positional argument fails with usage (too many arguments)" {
    run _sr "parse_arguments repo1 repo2"
    assert_failure "$err_too_many_arguments"
    assert_output --partial "Too many positional arguments"
}

@test "parse_arguments: rejects an unknown option instead of taking it as the project directory" {
    # The '-* )' arm must stop parsing before '--bogus' becomes repo_path, so the trailing 'declare -p' never runs.
    run _sr "parse_arguments --bogus
             declare -p repo_path"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "repo_path="
}

@test "parse_arguments: --vm2-repos, --owner, --branch, --visibility, --ruleset-name, and --description set their variables" {
    run _sr "parse_arguments --vm2-repos /some/path --owner acme --branch dev --visibility private --ruleset-name 'main protection' --description 'a repo'
             declare -p vm2_repos repo_owner default_branch visibility branch_protection_rs_name description"
    assert_success
    assert_output --partial 'vm2_repos="/some/path"'
    assert_output --partial 'repo_owner="acme"'
    assert_output --partial 'default_branch="dev"'
    assert_output --partial 'visibility="private"'
    assert_output --partial 'branch_protection_rs_name="main protection"'
    assert_output --partial 'description="a repo"'
}

@test "parse_arguments: -o, -b, and -rs are the short forms of the same options" {
    run _sr "parse_arguments -o acme -b dev -rs 'main protection'
             declare -p repo_owner default_branch branch_protection_rs_name"
    assert_success
    assert_output --partial 'repo_owner="acme"'
    assert_output --partial 'default_branch="dev"'
    assert_output --partial 'branch_protection_rs_name="main protection"'
}

@test "parse_arguments: is pure: a non-existent --vm2-repos or project directory is not an error at this stage" {
    run _sr "parse_arguments --vm2-repos /no/such/dir /no/such/project
             declare -p vm2_repos repo_path"
    assert_success
    assert_output --partial 'vm2_repos="/no/such/dir"'
    assert_output --partial 'repo_path="/no/such/project"'
}

@test "parse_arguments: --ssh and --https are mutually exclusive, each clearing the other" {
    run _sr "parse_arguments --ssh
             declare -p use_ssh use_https"
    assert_success
    assert_output --partial 'use_ssh="true"'
    assert_output --partial 'use_https="false"'

    run _sr "parse_arguments --https
             declare -p use_ssh use_https"
    assert_success
    assert_output --partial 'use_ssh="false"'
    assert_output --partial 'use_https="true"'

    run _sr "parse_arguments -t -s
             declare -p use_ssh use_https"
    assert_success
    assert_output --partial 'use_ssh="true"'
    assert_output --partial 'use_https="false"'
}

@test "parse_arguments: --interactive-vars, --interactive-secrets, --purge-vars, --purge-secrets, --skip-local-config, and --audit set their flags" {
    run _sr "parse_arguments --interactive-vars --interactive-secrets --purge-vars --purge-secrets --skip-local-config --audit
             declare -p interactive_vars interactive_secrets purge_vars purge_secrets configure_local audit"
    assert_success
    assert_output --partial 'interactive_vars="true"'
    assert_output --partial 'interactive_secrets="true"'
    assert_output --partial 'purge_vars="true"'
    assert_output --partial 'purge_secrets="true"'
    assert_output --partial 'configure_local="false"'
    assert_output --partial 'audit="true"'
}

@test "parse_arguments: -iv, -is, -pv, -ps, -slc, and -a are the short forms of the same switches" {
    run _sr "parse_arguments -iv -is -pv -ps -slc -a
             declare -p interactive_vars interactive_secrets purge_vars purge_secrets configure_local audit"
    assert_success
    assert_output --partial 'interactive_vars="true"'
    assert_output --partial 'interactive_secrets="true"'
    assert_output --partial 'purge_vars="true"'
    assert_output --partial 'purge_secrets="true"'
    assert_output --partial 'configure_local="false"'
    assert_output --partial 'audit="true"'
}

@test "parse_arguments: --interactive and --purge (-i, -p) each set both the vars and the secrets flags" {
    run _sr "parse_arguments --interactive --purge
             declare -p interactive_vars interactive_secrets purge_vars purge_secrets"
    assert_success
    assert_output --partial 'interactive_vars="true"'
    assert_output --partial 'interactive_secrets="true"'
    assert_output --partial 'purge_vars="true"'
    assert_output --partial 'purge_secrets="true"'

    run _sr "parse_arguments -i -p
             declare -p interactive_vars interactive_secrets purge_vars purge_secrets"
    assert_success
    assert_output --partial 'interactive_vars="true"'
    assert_output --partial 'interactive_secrets="true"'
    assert_output --partial 'purge_vars="true"'
    assert_output --partial 'purge_secrets="true"'
}

@test "parse_arguments: the switches default to SSH, non-interactive, no purge, no audit, and configuring the local repository" {
    run _sr "parse_arguments
             declare -p use_ssh use_https interactive_vars interactive_secrets purge_vars purge_secrets configure_local audit"
    assert_success
    assert_output --partial 'use_ssh="true"'
    assert_output --partial 'use_https="false"'
    assert_output --partial 'interactive_vars="false"'
    assert_output --partial 'interactive_secrets="false"'
    assert_output --partial 'purge_vars="false"'
    assert_output --partial 'purge_secrets="false"'
    assert_output --partial 'configure_local="true"'
    assert_output --partial 'audit="false"'
}

@test "parse_arguments: --current-branch (-cb) clears the branch the vm2.DevOps and vm2.Templates must be on" {
    run _sr "parse_arguments
             declare -p branches"
    assert_success
    assert_output --partial 'branches="main"'

    local _option
    for _option in --current-branch -cb; do
        run _sr "parse_arguments $_option
                 declare -p branches"
        assert_success
        assert_output --partial 'branches=""'
    done
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --vm2-repos --owner --branch --visibility --ruleset-name --description; do
        run _sr "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "after '$_option'"
    done
}

@test "parse_arguments: options are matched case-insensitively" {
    run _sr "parse_arguments --OWNER acme
             declare -p repo_owner"
    assert_success
    assert_output --partial 'repo_owner="acme"'
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: reports every missing tool, and returns instead of exiting" {
    mkdir -p "$_tmp/empty-bin"
    run _sr "PATH='$_tmp/empty-bin'
             verify_environment
             echo \"returned \$? with \$(get_errors) errors\""
    assert_output --partial "'git' is not installed"
    assert_output --partial "'gh' is not installed"
    assert_output --partial "'jq' is not installed"
    assert_output --partial "'yq' is not installed"
    assert_output --partial "returned 0 with 4 errors"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: resolves the project directory to its repository root, and derives repo_name, repo, and ci_yaml" {
    _make_vm2_repos
    run _sr "parse_arguments --vm2-repos '$_vm2' --owner acme '$_vm2/vm2.Target/src'
             resolve_arguments
             declare -p vm2_repos repo_path repo_name repo ci_yaml
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "vm2_repos=\"$_vm2\""
    assert_output --partial "repo_path=\"$_vm2/vm2.Target\""
    assert_output --partial 'repo_name="vm2.Target"'
    assert_output --partial 'repo="acme/vm2.Target"'
    assert_output --partial "ci_yaml=\"$_vm2/vm2.Target/.github/workflows/CI.yaml\""
    assert_output --partial "errors=0"
}

@test "resolve_arguments: a bare repository name is looked up under vm2_repos" {
    _make_vm2_repos
    run _sr "parse_arguments --vm2-repos '$_vm2' vm2.Target
             resolve_arguments
             declare -p repo_path repo_name
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "repo_path=\"$_vm2/vm2.Target\""
    assert_output --partial 'repo_name="vm2.Target"'
    assert_output --partial "errors=0"
}

@test "resolve_arguments: freezes the arguments that cannot change later" {
    _make_vm2_repos
    run _sr "parse_arguments --vm2-repos '$_vm2' vm2.Target
             resolve_arguments
             declare -p vm2_repos ci_yaml visibility audit interactive_vars interactive_secrets purge_vars purge_secrets configure_local"
    assert_success
    assert_output --partial "declare -rx vm2_repos="
    assert_output --partial "declare -rx ci_yaml="
    assert_output --partial "declare -rx visibility="
    assert_output --partial "declare -rx audit="
    assert_output --partial "declare -rx interactive_vars="
    assert_output --partial "declare -rx interactive_secrets="
    assert_output --partial "declare -rx purge_vars="
    assert_output --partial "declare -rx purge_secrets="
    assert_output --partial "declare -rx configure_local="
}

@test "resolve_arguments: canonicalizes the visibility to lower case" {
    _make_vm2_repos
    run _sr "parse_arguments --vm2-repos '$_vm2' --visibility PRIVATE vm2.Target
             resolve_arguments
             declare -p visibility
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial 'visibility="private"'
    assert_output --partial "errors=0"
}

@test "resolve_arguments: a directory with a CI.yaml that is not a Git repository yet is accepted, with a note that it will be initialized" {
    _make_vm2_repos
    mkdir -p "$_vm2/vm2.New/.github/workflows"
    printf 'name: CI\n' > "$_vm2/vm2.New/.github/workflows/CI.yaml"
    run _sr "parse_arguments --vm2-repos '$_vm2' '$_vm2/vm2.New'
             resolve_arguments
             declare -p repo_path repo_name
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "A new Git repository will be initialized in '$_vm2/vm2.New'"
    assert_output --partial "repo_path=\"$_vm2/vm2.New\""
    assert_output --partial 'repo_name="vm2.New"'
    assert_output --partial "errors=0"
}

@test "resolve_arguments: a repository with a workflows directory but no CI.yaml is an error" {
    _make_vm2_repos
    git -C "$_vm2/vm2.Target" mv .github/workflows/CI.yaml .github/workflows/other.yaml
    run _sr "parse_arguments --vm2-repos '$_vm2' vm2.Target
             resolve_arguments
             echo \"returned \$? with \$(get_errors) errors\""
    assert_output --partial "missing .github/workflows/CI.yaml"
    assert_output --partial "returned 0 with 1 errors"
}

@test "resolve_arguments: a project directory that cannot be found is reported by the name the user gave" {
    _make_vm2_repos
    run _sr "parse_arguments --vm2-repos '$_vm2' vm2.NoSuchRepo
             resolve_arguments"
    assert_output --partial "Failed to resolve the path of the target repository 'vm2.NoSuchRepo'"
}

@test "resolve_arguments: reports every invalid value (owner, branch, visibility, description), and returns" {
    _make_vm2_repos
    run _sr "parse_arguments --vm2-repos '$_vm2' --owner '-bad-' --branch '..bad..' --visibility bogus --description ab vm2.Target
             resolve_arguments
             echo \"returned \$? with \$(get_errors) errors\""
    assert_output --partial "Invalid GitHub repository owner '-bad-': use 2 to 39 letters, digits, or hyphens"
    assert_output --partial "Invalid branch name '..bad..': it must be a valid refname."
    assert_output --partial "Invalid repository visibility 'bogus': use one of public,private."
    assert_output --partial "Invalid repository description 'ab': use 3 to 350 characters."
    assert_output --partial "returned 0 with 4 errors"
}

@test "resolve_arguments: an empty description is valid (setup-repo.sh asks for one only when it creates the repository)" {
    _make_vm2_repos
    run _sr "parse_arguments --vm2-repos '$_vm2' vm2.Target
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    refute_output --partial "use 3 to 350 characters"
    assert_output --partial "errors=0"
}

@test "resolve_arguments: vm2.DevOps off 'main' is an error, unless --current-branch is given" {
    _make_vm2_repos
    git -C "$_vm2/vm2.DevOps" switch --quiet -c feature

    run _sr "parse_arguments --vm2-repos '$_vm2' vm2.Target
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    refute_output --partial "errors=0"

    run _sr "parse_arguments --vm2-repos '$_vm2' --current-branch vm2.Target
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "errors=0"
}

@test "resolve_arguments: an unresolvable vm2_repos stops the run (a circuit breaker), instead of cascading into the target" {
    _make_vm2_repos
    run _sr "parse_arguments --vm2-repos '$_tmp/no-such-dir' vm2.Target
             resolve_arguments
             echo 'still running'"
    assert_failure
    refute_output --partial "still running"
    refute_output --partial "Failed to resolve the path of the target repository"
}

# =====================================================================================
# get_arguments()
# =====================================================================================

@test "get_arguments: -h prints the usage and exits 0, before any check (even of a non-existent --vm2-repos)" {
    run _sr "get_arguments --vm2-repos /no/such/dir -h"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "ERROR"
}

@test "get_arguments: --help prints the long usage text (includes the common switches)" {
    run _sr "get_arguments --help"
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "--verbose"
}

@test "get_arguments: a valid command line resolves the arguments and returns" {
    _make_vm2_repos
    run _sr "get_arguments --vm2-repos '$_vm2' --owner acme vm2.Target
             declare -p repo"
    assert_success
    assert_output --partial 'repo="acme/vm2.Target"'
}

@test "get_arguments: invalid values exit through exit_if_has_errors, after reporting all of them" {
    _make_vm2_repos
    run _sr "get_arguments --vm2-repos '$_vm2' --branch '..bad..' --visibility bogus vm2.Target
             echo 'still running'"
    assert_failure
    assert_output --partial "Invalid branch name '..bad..': it must be a valid refname."
    assert_output --partial "Invalid repository visibility 'bogus': use one of public,private."
    refute_output --partial "still running"
}
