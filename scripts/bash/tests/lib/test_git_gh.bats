#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/lib/_git_gh.sh: GitHub naming rules, the repo state, get_repo_state, and the 'gh' retry
# wrappers.
#
# No test calls GitHub: get_repo_state runs either with full_info=false, or against a fake 'gh' on the PATH (see
# _fake_gh). Repositories are throw-away 'git init's under $BATS_TEST_TMPDIR, except for a few read-only checks
# against the actual vm2.DevOps repository.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gx failure
declare -gx err_invalid_arguments
declare -gx err_invalid_nameref
declare -gx err_argument_value
declare -gx err_argument_type
declare -gx err_not_directory
declare -gx err_root_not_repo_name
declare -gx err_logic_error
declare -gx err_tool_error

setup() {
    _repo_root="$(cd "$lib_dir/../../.." && pwd)"
    # Hermetic git: ignore the developer's ~/.gitconfig. E.g. a 'url.git@github.com:.insteadOf https://github.com/'
    # rule makes 'git remote get-url' return SSH URLs for HTTPS remotes, which once hid an HTTPS-only bug in
    # get_repo_state (the '.git' suffix was stripped for SSH only) -- the tests passed locally for the wrong reason.
    export GIT_CONFIG_GLOBAL=/dev/null
}

# --- validate_gh_repo_owner / validate_gh_repo_name / validate_gh_repo_description --------------

@test "validate_gh_repo_owner: accepts a valid owner, rejects an empty or invalid one" {
    run validate_gh_repo_owner ""
    assert_failure 4
    run validate_gh_repo_owner "vmelamed"
    assert_success
    run validate_gh_repo_owner "-leading-hyphen"
    assert_failure 4
}

@test "validate_gh_repo_owner: bug-exits with the wrong argument count" {
    run validate_gh_repo_owner
    assert_failure "$err_invalid_arguments"
}

@test "validate_gh_repo_name: rejects empty, rejects .git suffix, accepts a valid name" {
    run validate_gh_repo_name ""
    assert_failure 4
    run validate_gh_repo_name "vm2.DevOps.git"
    assert_failure 4
    run validate_gh_repo_name "vm2.DevOps"
    assert_success
}

@test "validate_gh_repo_description: enforces the 3-350 character range" {
    run validate_gh_repo_description "ab"
    assert_failure 4
    run validate_gh_repo_description "A valid description"
    assert_success
    run validate_gh_repo_description "$(printf 'a%.0s' {1..351})"
    assert_failure 4
}

# --- initialize_repo_state -----------------------------------------------------------------------

@test "initialize_repo_state: populates every predefined key with an empty string" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; for k in \"\${!state[@]}\"; do echo \"\$k=[\${state[\$k]}]\"; done | sort"
    assert_success
    assert_line "name=[]"
    assert_line "owner=[]"
    assert_line "full_name=[]"
    assert_line "repo_id=[]"
    assert_line "default_branch=[]"
    assert_line "root=[]"
    assert_line "url=[]"
}

@test "initialize_repo_state: bug-exits on a non-associative-array argument" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a arr=(); initialize_repo_state arr"
    assert_failure "$err_invalid_nameref"
}

# --- get_repo_state (local git only, full_info=false to avoid network calls) --------------------

@test "get_repo_state: populates local fields for the real vm2.DevOps repo, without calling the GitHub API" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo_root' state false; echo \"root=[\${state[root]}]\"; echo \"owner=[\${state[owner]}]\"; echo \"name=[\${state[name]}]\"; echo \"repo_id=[\${state[repo_id]}]\""
    assert_success
    assert_output --partial "root=[$_repo_root]"
    assert_output --partial "name=[vm2.DevOps]"
    assert_output --partial "repo_id=[]"
}

@test "get_repo_state: bug-exits on a non-existent directory" {
    # NOTE: 'state' must be a real pre-declared associative array, or a second bug (arg-2
    # nameref) accumulates alongside the intended arg-1 directory bug, and exit_if_has_bugs
    # reports the LAST one recorded (err_invalid_nameref), not this test's intended
    # err_not_directory.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '/definitely/not/a/real/path' state false"
    assert_failure "$err_not_directory"
}

@test "get_repo_state: bug-exits with the wrong argument count" {
    run get_repo_state "$_repo_root"
    assert_failure "$err_invalid_arguments"
}

# --- get_repo_state: the repository-identity convention (directory name == GitHub repository name) --
# Each test builds a throw-away local repo under $BATS_TEST_TMPDIR -- 'git init' plus an 'origin' URL is all
# get_repo_state needs with full_info=false (no commits, no network).

# Creates the directory $1 under $BATS_TEST_TMPDIR as a git working tree, with the remote 'origin' set to $2 if given.
_make_repo() {
    # shellcheck disable=SC2154 # BATS_TEST_TMPDIR is set by bats for each test at run time
    local _dir="$BATS_TEST_TMPDIR/$1"
    mkdir -p "$_dir"
    git -C "$_dir" init -q
    [[ -z ${2:-} ]] || git -C "$_dir" remote add origin "$2"
    echo "$_dir"
}

# Runs get_repo_state on $1 (full_info=false) and prints its exit code and the resolved repository name, owner, and
# full name.
_run_get_repo_state() {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$1' state false; echo \"rc=[\$?] name=[\${state[name]}] owner=[\${state[owner]}] full_name=[\${state[full_name]}]\""
}

@test "get_repo_state: succeeds when the directory name matches the GitHub repository name (HTTPS URL with .git)" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample.git)"
    assert_success
    assert_output --partial "rc=[0] name=[vm2.Sample]"
}

@test "get_repo_state: succeeds when the directory name matches the GitHub repository name (HTTPS URL without .git)" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample)"
    assert_success
    assert_output --partial "rc=[0] name=[vm2.Sample]"
}

@test "get_repo_state: succeeds when the directory name matches the GitHub repository name (SSH URL)" {
    _run_get_repo_state "$(_make_repo vm2.Sample git@github.com:vmelamed/vm2.Sample.git)"
    assert_success
    assert_output --partial "rc=[0] name=[vm2.Sample]"
}

@test "get_repo_state: returns err_root_not_repo_name and reports an error when the names differ" {
    _run_get_repo_state "$(_make_repo vm2.Renamed https://github.com/vmelamed/vm2.Sample.git)"
    assert_output --partial "rc=[$err_root_not_repo_name] name=[vm2.Sample]"
    assert_output --partial "The root directory name 'vm2.Renamed' does not match the repository name 'vm2.Sample'"
}

@test "get_repo_state: compares the names case-sensitively (the convention says 'including case')" {
    _run_get_repo_state "$(_make_repo vm2.sample https://github.com/vmelamed/vm2.Sample.git)"
    assert_output --partial "rc=[$err_root_not_repo_name] name=[vm2.Sample]"
}

@test "get_repo_state: succeeds with an empty name for a repo without a remote (e.g. before setup-repo.sh)" {
    _run_get_repo_state "$(_make_repo vm2.NoRemote)"
    assert_success
    assert_output --partial "rc=[0] name=[]"
}

# --- has_local_repo / has_remote_repo / has_github_remote ---------------------------------------

@test "has_local_repo / has_remote_repo: true for the real vm2.DevOps repo state" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo_root' state false; has_local_repo state"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo_root' state false; has_remote_repo state"
    assert_success
}

@test "has_local_repo: false for a freshly-initialized (empty) repo state" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; has_local_repo state"
    assert_failure "$failure"
}

@test "has_remote_repo: false for a local repository without a remote (regression: tested the root, not the URL)" {
    local _repo
    _repo="$(_make_repo vm2.NoRemote)"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo' state false; has_local_repo state && ! has_remote_repo state"
    assert_success
}

@test "get_repo_state: records the origin URL" {
    local _repo
    _repo="$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample.git)"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo' state false; echo \"url=[\${state[url]}]\""
    assert_success
    assert_output "url=[https://github.com/vmelamed/vm2.Sample.git]"
}

@test "has_github_remote: false without full repo-id info (full_info=false never populates it)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo_root' state false; has_github_remote state"
    assert_failure "$failure"
}

# --- read_repo_state / print_repo_state ----------------------------------------------------------

@test "read_repo_state: deserializes key=value lines into the repo state" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); read_repo_state state < <(printf 'owner=acme\nname=widget\n'); echo \"owner=[\${state[owner]}] name=[\${state[name]}]\""
    assert_success
    assert_output "owner=[acme] name=[widget]"
}

@test "print_repo_state: prints every predefined key" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; state[owner]=acme; print_repo_state state"
    assert_success
    assert_output --partial "owner: acme"
    assert_output --partial "root:"
}

@test "print_repo_state: bug-exits with the wrong argument count (regression: was missing exit_if_has_bugs)" {
    # NOTE: print_repo_state()'s nameref check (is_associative_array "$1") isn't '-v'-guarded, so
    # it always runs even when $1 is simply missing, compounding a second bug (err_invalid_nameref)
    # on top of the arity one -- exit_if_has_bugs reports the LAST one recorded either way.
    run print_repo_state
    assert_failure "$err_invalid_nameref"
    run print_repo_state a b
    assert_failure "$err_invalid_nameref"
}

# --- execute_gh_with_retry / execute_gh_api_with_retry (formal validation only, no network) ------

@test "execute_gh_with_retry: bug-exits with too few arguments" {
    run execute_gh_with_retry 3 2
    assert_failure "$err_invalid_arguments"
}

@test "execute_gh_with_retry: bug-exits on a non-natural max-attempts or delay" {
    run execute_gh_with_retry -1 2 repo view
    assert_failure "$err_argument_type"
    run execute_gh_with_retry 3 -1 repo view
    assert_failure "$err_argument_type"
}

@test "execute_gh_with_retry: honors dry-run without invoking gh for real" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute_gh_with_retry 3 2 repo delete some/nonexistent-repo --yes"
    assert_success
    assert_output --partial "dry-run"
}

@test "execute_gh_api_with_retry: bug-exits with too few arguments" {
    run execute_gh_api_with_retry 3 2
    assert_failure "$err_invalid_arguments"
}

@test "execute_gh_api_with_retry: honors dry-run without invoking gh for real" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute_gh_api_with_retry 3 2 repos/acme/nonexistent"
    assert_success
    assert_output --partial "dry-run"
}


# --- get_repo_state: the forms of a GitHub remote URL ----------------------------------------------------------------
# Only owner and name matter: everything before 'github.com' and the optional port, '.git', and trailing '/' are
# accepted. An origin that is not GitHub is not an error: get_repo_state succeeds with the GitHub fields empty.

@test "get_repo_state: accepts an SSH URL without .git" {
    _run_get_repo_state "$(_make_repo vm2.Sample git@github.com:vmelamed/vm2.Sample)"
    assert_success
    assert_output "rc=[0] name=[vm2.Sample] owner=[vmelamed] full_name=[vmelamed/vm2.Sample]"
}

@test "get_repo_state: accepts an ssh:// URL with a port (GitHub's SSH over the HTTPS port)" {
    _run_get_repo_state "$(_make_repo vm2.Sample ssh://git@ssh.github.com:443/vmelamed/vm2.Sample.git)"
    assert_success
    assert_output "rc=[0] name=[vm2.Sample] owner=[vmelamed] full_name=[vmelamed/vm2.Sample]"
}

@test "get_repo_state: accepts an HTTPS URL with a user name" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://someone@github.com/vmelamed/vm2.Sample.git)"
    assert_success
    assert_output "rc=[0] name=[vm2.Sample] owner=[vmelamed] full_name=[vmelamed/vm2.Sample]"
}

@test "get_repo_state: accepts an HTTPS URL with a trailing slash" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample/)"
    assert_success
    assert_output "rc=[0] name=[vm2.Sample] owner=[vmelamed] full_name=[vmelamed/vm2.Sample]"
}

@test "get_repo_state: accepts the longest repository name (100 characters) followed by .git (regression)" {
    # The name pattern stops at 100 characters, so only the explicit '(\.git)?' in the URL regex can take the suffix.
    local _name
    _name="r$(printf 'x%.0s' {1..99})"
    _run_get_repo_state "$(_make_repo "$_name" "https://github.com/vmelamed/$_name.git")"
    assert_success
    assert_output "rc=[0] name=[$_name] owner=[vmelamed] full_name=[vmelamed/$_name]"
}

@test "get_repo_state: strips .git from the name when the name pattern swallows it" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample.git)"
    assert_success
    assert_output "rc=[0] name=[vm2.Sample] owner=[vmelamed] full_name=[vmelamed/vm2.Sample]"
}

@test "get_repo_state: treats a host other than GitHub as 'not GitHub', not as an error" {
    _run_get_repo_state "$(_make_repo vm2.Sample git@gitlab.com:vmelamed/vm2.Sample.git)"
    assert_success
    assert_output "rc=[0] name=[] owner=[] full_name=[]"
}

@test "get_repo_state: treats a host that merely ends in github.com as 'not GitHub'" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://notgithub.com/vmelamed/vm2.Sample.git)"
    assert_success
    assert_output "rc=[0] name=[] owner=[] full_name=[]"
}

@test "get_repo_state: treats a URL with an extra path segment as 'not GitHub'" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample/tree)"
    assert_success
    assert_output "rc=[0] name=[] owner=[] full_name=[]"
}

# --- get_repo_state: reusing one state variable ------------------------------------------------------------------------

@test "get_repo_state: a reused state starts empty -- nothing from the previous repository survives an early return" {
    local _github _local
    _github="$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample.git)"
    _local="$(_make_repo vm2.NoRemote)"
    # The GitHub fields are set by hand: full_info=false never fetches them.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        declare -A state=()
        get_repo_state '$_github' state false
        state[repo_id]=42; state[default_branch]=main
        get_repo_state '$_local' state false
        echo \"root=[\${state[root]}] url=[\${state[url]}] name=[\${state[name]}] repo_id=[\${state[repo_id]}] default_branch=[\${state[default_branch]}]\"
        has_github_remote state && echo 'github remote' || echo 'no github remote'"
    assert_success
    assert_line "root=[$_local] url=[] name=[] repo_id=[] default_branch=[]"
    assert_line "no github remote"
}

# --- is_repo_state_initialized ---------------------------------------------------------------------------------------

@test "is_repo_state_initialized: true after initialize_repo_state, also with an extra key" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; is_repo_state_initialized state && state[extra]=x && is_repo_state_initialized state"
    assert_success
}

@test "is_repo_state_initialized: false for an empty array, and for a state with a predefined key missing" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); is_repo_state_initialized state"
    assert_failure "$failure"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; unset 'state[repo_id]'; state[extra]=x; is_repo_state_initialized state"
    assert_failure "$failure"
}

@test "is_repo_state_initialized: tests the keys, not the values (regression: '-v \${state[key]}' tested the values)" {
    # A value that is the name of an existing variable once made the predicate true by accident.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; state[default_branch]=PATH; is_repo_state_initialized state"
    assert_success
}

# --- get_gh_repo_state / get_repo_state with full_info=true, against a fake 'gh' ------------------------------------
# The fake replaces 'gh' on the PATH. It prints $2 (the result of the jq query, as GitHub would produce it) and exits
# with $1; with a non-zero exit code, it prints $3 to stderr. A 'Not Found'-like message is not transient, so the retry
# wrapper does not retry (and does not sleep).

_fake_gh() {
    local _bin="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$_bin"
    {
        echo '#!/usr/bin/env bash'
        printf 'printf %%s %q\n' "$2"
        printf 'printf %%s %q >&2\n' "${3:-}"
        printf 'exit %d\n' "$1"
    } > "$_bin/gh"
    chmod +x "$_bin/gh"
    echo "$_bin"
}

# The jq query's output for vmelamed/$1 (default: vm2.Sample), with the owner $2 (default: vmelamed).
_gh_repo_state_output() {
    local _name=${1:-vm2.Sample} _owner=${2:-vmelamed}
    printf 'owner=%s\nname=%s\nfull_name=%s/%s\nrepo_id=123456\ndefault_branch=trunk\n' "$_owner" "$_name" "$_owner" "$_name"
}

# Runs get_repo_state on $2 with full_info=true and the fake 'gh' in the directory $1 first on the PATH.
_run_get_repo_state_full() {
    run bash -c "export PATH='$1':\"\$PATH\"; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$2' state; echo \"rc=[\$?] full_name=[\${state[full_name]}] repo_id=[\${state[repo_id]}] default_branch=[\${state[default_branch]}] root=[\${state[root]}]\""
}

@test "get_repo_state: full_info fills in the GitHub fields and keeps the local ones" {
    local _repo
    _repo="$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample.git)"
    _run_get_repo_state_full "$(_fake_gh 0 "$(_gh_repo_state_output)")" "$_repo"
    assert_success
    assert_line "rc=[0] full_name=[vmelamed/vm2.Sample] repo_id=[123456] default_branch=[trunk] root=[$_repo]"
}

@test "get_repo_state: full_info reports a repository that GitHub knows under another name (renamed or transferred)" {
    # GitHub follows the redirect of a renamed repository and returns its new name.
    local _repo
    _repo="$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample.git)"
    _run_get_repo_state_full "$(_fake_gh 0 "$(_gh_repo_state_output vm2.Renamed)")" "$_repo"
    assert_output --partial "rc=[$err_logic_error]"
    assert_output --partial "do not match the properties on GitHub"
}

@test "get_repo_state: full_info reports an owner whose case differs from GitHub's" {
    # GitHub resolves names case-insensitively, but returns them in their canonical case.
    local _repo
    _repo="$(_make_repo vm2.Sample https://github.com/VMelamed/vm2.Sample.git)"
    _run_get_repo_state_full "$(_fake_gh 0 "$(_gh_repo_state_output)")" "$_repo"
    assert_output --partial "rc=[$err_logic_error]"
}

@test "get_repo_state: full_info fails with err_tool_error when the GitHub API call fails, and leaves the GitHub fields empty" {
    local _repo
    _repo="$(_make_repo vm2.Sample https://github.com/vmelamed/vm2.Sample.git)"
    _run_get_repo_state_full "$(_fake_gh 1 '' 'gh: Not Found (HTTP 404)')" "$_repo"
    assert_output --partial "rc=[$err_tool_error] full_name=[vmelamed/vm2.Sample] repo_id=[] default_branch=[]"
}

@test "get_gh_repo_state: ignores an empty API result, e.g. a dry run (regression: assigned the empty key '')" {
    run bash -c "export PATH='$(_fake_gh 0 '')':\"\$PATH\"; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); initialize_repo_state state; get_gh_repo_state vmelamed/vm2.Sample state; echo \"rc=[\$?] repo_id=[\${state[repo_id]}]\""
    assert_success
    assert_line "rc=[0] repo_id=[]"
}

@test "get_gh_repo_state: bug-exits on a state that is not initialized" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_gh_repo_state vmelamed/vm2.Sample state"
    assert_failure "$err_invalid_nameref"
}

# --- get_gh_repo_property --------------------------------------------------------------------------------------------

@test "get_gh_repo_property: prints the property's value from the API" {
    run bash -c "export PATH='$(_fake_gh 0 trunk)':\"\$PATH\"; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_gh_repo_property vmelamed/vm2.Sample default_branch"
    assert_success
    assert_output "trunk"
}

@test "get_gh_repo_property: fails with err_tool_error when the API call fails (regression: _rc was not declared)" {
    run bash -c "export PATH='$(_fake_gh 1 '' 'gh: Not Found (HTTP 404)')':\"\$PATH\"; set -u; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_gh_repo_property vmelamed/vm2.Sample default_branch"
    assert_failure "$err_tool_error"
}

@test "get_gh_repo_property: bug-exits on an invalid full name or property name" {
    run get_gh_repo_property not-a-full-name default_branch
    assert_failure "$err_argument_value"
    run get_gh_repo_property vmelamed/vm2.Sample 'x; rm -rf'
    assert_failure "$err_argument_value"
}
