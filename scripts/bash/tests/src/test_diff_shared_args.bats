#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/diff-shared.args.sh (with diff-shared.usage.sh).
#
# These files are designed to be 'source'd from diff-shared.sh, after core.sh has already established
# script_name/script_dir/lib_dir as readonly globals. They are exercised the same way as the scripts/bash/lib/*.sh
# characterization tests: each test spawns a fresh, ambient-environment-free ('env -i HOME="$HOME" PATH=...') bash
# subshell that sources core.sh and then the file(s) under test, so every test starts from a pristine, deterministic state.
#
# get_arguments() is a pipeline of stages, and the tests follow its seams:
#   - parse_arguments():    CLI tokens -> variables. Pure: no file system, no git, so these tests need no fixture.
#   - verify_environment(): argument-independent preconditions (tools). Reports, never exits.
#   - resolve_arguments():  validates, canonicalizes, and derives variables (sot_path, target_roots, target_paths), then
#                           freezes them. Needs real git repositories, so these tests build a hermetic, local-only
#                           $VM2_REPOS under $BATS_TEST_TMPDIR (_make_vm2_repos) -- they never read the real ~/repos/vm2.
#   - get_arguments():      the orchestration only: a few end-to-end tests over the same fixture.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

declare BATS_TEST_TMPDIR

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_invalid_arguments
declare -gxi err_argument_value
declare -gxi err_missing_argument
declare -gxi err_unknown_argument

declare -gxa vm2_repositories

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# Sources core.sh, then diff-shared.configuration.sh, diff-shared.functions.sh, diff-shared.summary.sh,
# diff-shared.args.sh, and diff-shared.usage.sh inside a fresh env -i subshell, then runs the caller-supplied bash snippet.
_ds() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/diff-shared.configuration.sh'
        source '$_src_dir/diff-shared.functions.sh'
        source '$_src_dir/diff-shared.summary.sh'
        source '$_src_dir/diff-shared.args.sh'
        source '$_src_dir/diff-shared.usage.sh'
        $1
    "
}

setup() {
    # canonical: resolve_vm2_repos() and resolve_target() return realpath-ed paths
    _tmp=$(realpath "$BATS_TEST_TMPDIR")
    _vm2="$_tmp/vm2"
}

# A local-only (no origin remote) git repository on 'main', with CI configured and one stable tag: it passes
# __validate_repo_root()'s checks without any network activity (see test_git_vm2.bats).
_make_repo() {
    local _dir="$1"
    mkdir -p "$_dir/.github/workflows"
    git -C "$_dir" init --quiet --initial-branch=main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo "name: CI" > "$_dir/.github/workflows/ci.yaml"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: initial commit"
    git -C "$_dir" tag v1.0.0
}

# A hermetic $VM2_REPOS: vm2.DevOps, vm2.Templates (with the default SoT's content directory), and one target, vm2.Target.
_make_vm2_repos() {
    _make_repo "$_vm2/vm2.DevOps"
    _make_repo "$_vm2/vm2.Templates"
    mkdir -p "$_vm2/vm2.Templates/templates/AddNewPackage/content"
    _make_repo "$_vm2/vm2.Target"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: collects positional arguments as target repos, de-duplicated" {
    run _ds "parse_arguments myrepo myrepo otherrepo
             declare -p target_repos"
    assert_success
    assert_output --partial 'target_repos=([0]="myrepo" [1]="otherrepo")'
}

@test "parse_arguments: --all-repos, --all-repositories, and -all populate target_repos from vm2_repositories" {
    local _option
    for _option in --all-repos --all-repositories -all; do
        run _ds "parse_arguments $_option
                 echo \"count=\${#target_repos[@]}\""
        assert_success
        assert_output --partial "count=${#vm2_repositories[@]}"
    done
}

@test "parse_arguments: -all does not duplicate a repository already given as a positional argument" {
    run _ds "parse_arguments '${vm2_repositories[0]}' -all
             echo \"count=\${#target_repos[@]}\""
    assert_success
    assert_output --partial "count=${#vm2_repositories[@]}"
}

@test "parse_arguments: --vm2-repos, --diff, --summary-file, and --current-branch set the corresponding variables" {
    run _ds "parse_arguments --vm2-repos /some/path --diff --summary-file /some/sum.md --current-branch
             declare -p vm2_repos diff_only summary_file current_branch"
    assert_success
    assert_output --partial 'vm2_repos="/some/path"'
    assert_output --partial 'diff_only="true"'
    assert_output --partial 'summary_file="/some/sum.md"'
    assert_output --partial 'current_branch="true"'
}

@test "parse_arguments: -r, -d, -sf, and -cb set the corresponding variables" {
    run _ds "parse_arguments -r /some/path -d -sf /some/sum.md -cb
             declare -p vm2_repos diff_only summary_file current_branch"
    assert_success
    assert_output --partial 'vm2_repos="/some/path"'
    assert_output --partial 'diff_only="true"'
    assert_output --partial 'summary_file="/some/sum.md"'
    assert_output --partial 'current_branch="true"'
}

@test "parse_arguments: leaves the defaults when no options are given" {
    run _ds "parse_arguments
             declare -p diff_only summary_file current_branch target_repos"
    assert_success
    assert_output --partial 'diff_only="false"'
    assert_output --partial 'summary_file=""'
    assert_output --partial 'current_branch="false"'
    assert_output --partial 'target_repos=()'
}

@test "parse_arguments: matches the script's own option names case-insensitively" {
    run _ds "parse_arguments --DIFF --Current-Branch
             declare -p diff_only current_branch"
    assert_success
    assert_output --partial 'diff_only="true"'
    assert_output --partial 'current_branch="true"'
}

@test "parse_arguments: does not resolve or validate values (a non-existent --vm2-repos is taken as is)" {
    run _ds "parse_arguments --vm2-repos /definitely/not/a/real/path not-a-repo
             declare -p vm2_repos target_repos sot_path"
    assert_success
    assert_output --partial 'vm2_repos="/definitely/not/a/real/path"'
    assert_output --partial 'target_repos=([0]="not-a-repo")'
    assert_output --partial 'sot_path=""'
}

@test "parse_arguments: --file* option variants map to the right action via get_selector_action" {
    run _ds "parse_arguments --file-ignore '*.yaml' --file-copy '*.props'
             declare -p selectors_actions"
    assert_success
    assert_output --partial '["*.yaml"]="ignore"'
    assert_output --partial '["*.props"]="copy"'
}

@test "parse_arguments: an unspecified action for --file leaves the selector's action empty (use the pre-configured action)" {
    run _ds "parse_arguments --file '*.yaml'
             declare -p selectors_actions"
    assert_success
    assert_output --partial '["*.yaml"]=""'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --vm2-repos --file --summary-file; do
        run _ds "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: rejects an unknown option instead of taking it as a target repository" {
    # The '-* )' arm must stop parsing: '--bogus' never reaches target_repos, so the trailing 'declare -p' never runs.
    run _ds "parse_arguments myrepo --bogus; declare -p target_repos"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "target_repos="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _ds "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _ds "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when git is present" {
    run _ds "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "rc=0"
    assert_output --partial "NO_ERRORS"
}

@test "verify_environment: reports a missing git and returns instead of exiting" {
    # The stub stands in for a machine without git; replacing PATH would also hide the tools core.sh itself needs.
    run _ds "is_tool_present() { [[ \$1 != git ]]; }
             verify_environment
             echo REACHED
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: resolves vm2_repos, sot_path, and the targets' roots and paths" {
    _make_vm2_repos
    run _ds "vm2_repos='$_vm2'
             target_repos=(vm2.Target)
             summary_file='$_tmp/sum.md'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p vm2_repos sot_path target_roots"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial "vm2_repos=\"$_vm2\""
    assert_output --partial "sot_path=\"$_vm2/vm2.Templates/templates/AddNewPackage/content\""
    assert_output --partial "target_roots=([0]=\"$_vm2/vm2.Target\")"
}

@test "resolve_arguments: uses the current directory as the only target when none is given" {
    _make_vm2_repos
    run _ds "cd '$_vm2/vm2.Target'
             vm2_repos='$_vm2'
             summary_file='$_tmp/sum.md'
             resolve_arguments
             declare -p target_roots"
    assert_success
    assert_output --partial "target_roots=([0]=\"$_vm2/vm2.Target\")"
}

@test "resolve_arguments: reports an unresolvable target and still resolves the others" {
    _make_vm2_repos
    run _ds "vm2_repos='$_vm2'
             target_repos=(vm2.NotThere vm2.Target)
             summary_file='$_tmp/sum.md'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p target_roots"
    assert_success
    assert_output --partial "Could not resolve the Git working tree root of the target 'vm2.NotThere'"
    assert_output --partial "HAS_ERRORS"
    assert_output --partial "target_roots=([0]=\"$_vm2/vm2.Target\")"
}

@test "resolve_arguments: reports vm2.DevOps not on main" {
    _make_vm2_repos
    git -C "$_vm2/vm2.DevOps" switch --quiet -c feature
    run _ds "vm2_repos='$_vm2'
             target_repos=(vm2.Target)
             summary_file='$_tmp/sum.md'
             resolve_arguments
             exit_if_has_errors false"
    assert_failure
    assert_output --partial "is not on the branch 'main'"
}

@test "resolve_arguments: --current-branch accepts vm2.DevOps and vm2.Templates on other branches" {
    _make_vm2_repos
    git -C "$_vm2/vm2.DevOps" switch --quiet -c feature
    git -C "$_vm2/vm2.Templates" switch --quiet -c other
    run _ds "vm2_repos='$_vm2'
             current_branch=true
             target_repos=(vm2.Target)
             summary_file='$_tmp/sum.md'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p vm2_branch sot_branch"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'vm2_branch=""'
    assert_output --partial 'sot_branch=""'
}

@test "resolve_arguments: reports an invalid source of truth" {
    _make_vm2_repos
    run _ds "vm2_repos='$_vm2'
             sot=bogus
             target_repos=(vm2.Target)
             summary_file='$_tmp/sum.md'
             resolve_arguments
             exit_if_has_errors false"
    assert_failure
    assert_output --partial "Invalid source of truth 'bogus'"
}

@test "resolve_arguments: --diff overrides every file selector's action with 'ignore'" {
    _make_vm2_repos
    run _ds "vm2_repos='$_vm2'
             target_repos=(vm2.Target)
             summary_file='$_tmp/sum.md'
             diff_only=true
             selectors_actions=(['*.yaml']='copy' ['*.props']='merge')
             resolve_arguments
             declare -p selectors_actions"
    assert_success
    assert_output --partial '["*.yaml"]="ignore"'
    assert_output --partial '["*.props"]="ignore"'
}

@test "resolve_arguments: keeps a given summary file" {
    _make_vm2_repos
    run _ds "vm2_repos='$_vm2'
             target_repos=(vm2.Target)
             summary_file='$_tmp/sum.md'
             resolve_arguments
             declare -p summary_file"
    assert_success
    assert_output --partial "summary_file=\"$_tmp/sum.md\""
}

@test "resolve_arguments: creates a temp summary file when none is given, and removes it on exit" {
    _make_vm2_repos
    # --no-trap in _ds skips core.sh's own trap set-up; add_trap still registers the EXIT trap of this shell.
    run _ds "vm2_repos='$_vm2'
             target_repos=(vm2.Target)
             resolve_arguments
             [[ -f \$summary_file ]] && echo \"CREATED \$summary_file\" || echo MISSING"
    assert_success
    assert_output --regexp 'CREATED /tmp/diff-shared-log-[0-9]{8}-[0-9]{6}-[^ ]+\.md'

    local _file="${output#CREATED }"
    assert [ ! -e "$_file" ]
}

@test "resolve_arguments: freezes the resolved variables" {
    _make_vm2_repos
    run _ds "vm2_repos='$_vm2'
             target_repos=(vm2.Target)
             summary_file='$_tmp/sum.md'
             resolve_arguments
             declare -p vm2_repos sot_path target_roots target_paths diff_only summary_file current_branch"
    assert_success
    assert_output --partial "declare -rx vm2_repos="
    assert_output --partial "declare -rx sot_path="
    assert_output --partial "declare -ar target_roots="
    assert_output --partial "declare -ar target_paths="
    assert_output --partial "declare -rx diff_only="
    assert_output --partial "declare -rx summary_file="
    assert_output --partial "declare -rx current_branch="
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    _make_vm2_repos
    run _ds "get_arguments --vm2-repos '$_vm2' --summary-file '$_tmp/sum.md' vm2.Target
             declare -p target_roots"
    assert_success
    assert_output --partial "declare -ar target_roots=([0]=\"$_vm2/vm2.Target\")"
}

@test "get_arguments: -h prints the usage and exits 0 without running anything after it" {
    _make_vm2_repos
    run _ds "get_arguments -h --vm2-repos '$_vm2' --summary-file '$_tmp/sum.md' vm2.Target; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: -h still prints the usage when the environment is broken" {
    # vm2.DevOps is not on main: whatever else is reported, the user who asked for help gets it.
    _make_vm2_repos
    git -C "$_vm2/vm2.DevOps" switch --quiet -c feature
    run _ds "get_arguments -h --vm2-repos '$_vm2' --summary-file '$_tmp/sum.md' vm2.Target; echo AFTER"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: reports all resolution errors, then exits with the usage" {
    _make_vm2_repos
    run _ds "get_arguments --vm2-repos '$_vm2' --summary-file '$_tmp/sum.md' vm2.NotThere vm2.NotThereEither; echo AFTER"
    assert_failure
    assert_output --partial "'vm2.NotThere'"
    assert_output --partial "'vm2.NotThereEither'"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

# =====================================================================================
# get_selector_action()
# =====================================================================================

@test "get_selector_action: bug-exits on the wrong argument count" {
    run _ds "get_selector_action 'x'"
    assert_failure "$err_invalid_arguments"
    assert_output --partial "requires exactly 2 arguments"
}

@test "get_selector_action: fails with usage on an invalid action name" {
    run _ds "declare -A selectors_actions=(); get_selector_action '--file-bogus' 'a.txt'"
    assert_failure "$err_argument_value"
    assert_output --partial "Invalid action: bogus"
}

@test "get_selector_action: fails with usage when the file selector itself looks like an option" {
    run _ds "declare -A selectors_actions=(); get_selector_action '--file' '-badselector'"
    assert_failure "$err_argument_value"
    assert_output --partial "does not appear to be a valid file selector"
}

@test "get_selector_action: accepts the short 'mc'/'am'/'ac' action aliases" {
    run _ds "declare -A selectors_actions=()
             get_selector_action '--filemc' 'a.txt'
             declare -p selectors_actions"
    assert_success
    assert_output --partial '[a.txt]="merge or copy"'
}

@test "get_selector_action: accepts both the long and short forms of 'copy shared'/'ask to copy shared'" {
    run _ds "declare -A selectors_actions=()
             get_selector_action '--file-copy-shared' 'a.txt'
             get_selector_action '-facs' 'b.txt'
             declare -p selectors_actions"
    assert_success
    assert_output --partial '[a.txt]="copy shared"'
    assert_output --partial '[b.txt]="ask to copy shared"'
}
