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

# Runs get_repo_state (full_info=false) on a repo vm2.Sample with the origin $1 and prints the recorded URL and name.
_run_get_repo_state_url() {
    local _repo
    _repo="$(_make_repo vm2.Sample "$1")"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo' state false; echo \"rc=[\$?] url=[\${state[url]}] name=[\${state[name]}]\""
}

@test "get_repo_state: never records the credentials of an HTTPS URL (user and password)" {
    _run_get_repo_state_url https://user:s3cr3t@github.com/vmelamed/vm2.Sample.git
    assert_success
    assert_output "rc=[0] url=[https://github.com/vmelamed/vm2.Sample.git] name=[vm2.Sample]"
    refute_output --partial "s3cr3t"
}

@test "get_repo_state: never records the credentials of an HTTPS URL (a token as the user name)" {
    _run_get_repo_state_url https://ghp_FAKEtoken0123456789@github.com/vmelamed/vm2.Sample
    assert_success
    assert_output "rc=[0] url=[https://github.com/vmelamed/vm2.Sample] name=[vm2.Sample]"
}

@test "get_repo_state: keeps the user of an ssh:// URL -- it is the login, not a secret" {
    _run_get_repo_state_url ssh://git@ssh.github.com:443/vmelamed/vm2.Sample.git
    assert_success
    assert_output "rc=[0] url=[ssh://git@ssh.github.com:443/vmelamed/vm2.Sample.git] name=[vm2.Sample]"
}

@test "get_repo_state: keeps the user of an scp-like SSH URL" {
    _run_get_repo_state_url git@github.com:vmelamed/vm2.Sample.git
    assert_success
    assert_output "rc=[0] url=[git@github.com:vmelamed/vm2.Sample.git] name=[vm2.Sample]"
}

@test "print_repo_state: does not print the credentials of the origin URL" {
    local _repo
    _repo="$(_make_repo vm2.Sample https://user:s3cr3t@github.com/vmelamed/vm2.Sample.git)"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A state=(); get_repo_state '$_repo' state false; print_repo_state state"
    assert_success
    assert_output --partial "url: https://github.com/vmelamed/vm2.Sample.git"
    refute_output --partial "s3cr3t"
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

# --- execute_gh_with_retry / execute_gh_api_with_retry against a scripted fake 'gh' -----------------------------------
# The fake logs every call's arguments to $BATS_TEST_TMPDIR/gh.log and plays one scripted response per call: for the
# N-th call, the exit code, stdout, and stderr come from the files $BATS_TEST_TMPDIR/gh.N.{rc,out,err} (missing files:
# exit 0, no output). The delay is 0, so a retry costs no time.

_scripted_gh() {
    local _bin="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$_bin"
    cat > "$_bin/gh" <<EOF
#!/usr/bin/env bash
_dir='$BATS_TEST_TMPDIR'
echo "\$*" >> "\$_dir/gh.log"
_n=\$(wc -l < "\$_dir/gh.log")
[[ -f "\$_dir/gh.\$_n.out" ]] && cat "\$_dir/gh.\$_n.out"
[[ -f "\$_dir/gh.\$_n.err" ]] && cat "\$_dir/gh.\$_n.err" >&2
exit "\$(cat "\$_dir/gh.\$_n.rc" 2>/dev/null || echo 0)"
EOF
    chmod +x "$_bin/gh"
    echo "$_bin"
}

# $1 = the call number, $2 = its exit code, $3 = its stdout, $4 = its stderr
_gh_response() {
    echo "$2" > "$BATS_TEST_TMPDIR/gh.$1.rc"
    printf '%s' "$3" > "$BATS_TEST_TMPDIR/gh.$1.out"
    printf '%s\n' "$4" > "$BATS_TEST_TMPDIR/gh.$1.err"
}

# Runs $1 (bash code) with the scripted 'gh' first on the PATH, then prints the exit code, the error count, and the
# number of 'gh' calls.
_run_scripted_gh() {
    local _bin
    _bin="$(_scripted_gh)"
    run bash -c "export PATH='$_bin':\"\$PATH\"; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
                 $1; _rc=\$?
                 echo \"rc=[\$_rc] errors=[\$(get_errors)] calls=[\$(cat '$BATS_TEST_TMPDIR/gh.log' 2>/dev/null | wc -l)]\""
}

@test "execute_gh_with_retry: in a dry run, a --query runs, so the caller gets real data" {
    _gh_response 1 0 'real-data' ''
    _run_scripted_gh "set_dry_run; x=\$(execute_gh_with_retry 3 0 --query repo view); echo \"captured=[\$x]\""
    assert_output --partial "captured=[real-data]"
    assert_output --partial "calls=[1]"
}

@test "execute_gh_with_retry: in a dry run, a command that is not a --query is only printed, quoted with %q" {
    _run_scripted_gh "set_dry_run; execute_gh_with_retry 3 0 repo create 'my repo' --public"
    assert_output --partial 'dry-run$ gh repo create my\ repo --public'
    assert_output --partial "rc=[0] errors=[0] calls=[0]"
}

@test "execute_gh_with_retry: --quiet discards the command's stdout, not its stderr" {
    _gh_response 1 0 'to-stdout' 'to-stderr'
    _run_scripted_gh "execute_gh_with_retry 3 0 --quiet repo view"
    refute_output --partial "to-stdout"
    assert_output --partial "to-stderr"
    assert_output --partial "rc=[0]"
}

@test "execute_gh_with_retry: takes the switches in any order, and passes everything after them to gh unchanged" {
    _run_scripted_gh "set_dry_run; execute_gh_with_retry 3 0 --quiet --query repo view --json name; execute_gh_with_retry 3 0 --query --quiet pr list"
    assert_output --partial "calls=[2]"
    run cat "$BATS_TEST_TMPDIR/gh.log"
    assert_output $'repo view --json name\npr list'
}

@test "execute_gh_with_retry: retries a transient failure (HTTP 503), and succeeds" {
    _gh_response 1 1 '' 'gh: Service Unavailable (HTTP 503)'
    _gh_response 2 0 'ok' ''
    _run_scripted_gh "execute_gh_with_retry 3 0 repo view"
    assert_output --partial "Transient command failure (attempt 1/3)"
    assert_output --partial "rc=[0] errors=[0] calls=[2]"
}

@test "execute_gh_with_retry: returns err_tool_error after exhausting the attempts, without reporting an error" {
    _gh_response 1 1 '' 'gh: Service Unavailable (HTTP 503)'
    _gh_response 2 1 '' 'gh: Service Unavailable (HTTP 503)'
    _run_scripted_gh "execute_gh_with_retry 2 0 repo view"
    refute_output --partial "ERROR"
    assert_output --partial "rc=[$err_tool_error] errors=[0] calls=[2]"
}

@test "execute_gh_with_retry: does not retry a non-transient failure (HTTP 404); returns err_tool_error, without an error" {
    _gh_response 1 1 '' 'gh: Not Found (HTTP 404)'
    _run_scripted_gh "execute_gh_with_retry 3 0 run view 42"
    assert_output --partial "gh: Not Found (HTTP 404)"
    refute_output --partial "ERROR"
    assert_output --partial "rc=[$err_tool_error] errors=[0] calls=[1]"
}

@test "execute_gh_with_retry: a number like 500 inside a non-transient message (a run ID) is not mistaken for HTTP 500" {
    _gh_response 1 1 '' 'gh: Not Found (HTTP 404): https://api.github.com/repos/o/n/actions/runs/15004291234/artifacts'
    _run_scripted_gh "execute_gh_with_retry 3 0 run download 15004291234"
    assert_output --partial "calls=[1]"
}

@test "execute_gh_api_with_retry: calls 'gh api' with the route and its arguments" {
    _gh_response 1 0 '42' ''
    _run_scripted_gh "x=\$(execute_gh_api_with_retry 3 0 --query repos/acme/x --jq .id); echo \"captured=[\$x]\""
    assert_output --partial "captured=[42]"
    run cat "$BATS_TEST_TMPDIR/gh.log"
    assert_output "api repos/acme/x --jq .id"
}

@test "execute_gh_api_with_retry: in a dry run, a request that is not a --query is only printed" {
    _run_scripted_gh "set_dry_run; execute_gh_api_with_retry 3 0 -X PATCH repos/acme/x -F delete_branch_on_merge=true"
    assert_output --partial 'dry-run$ gh api -X PATCH repos/acme/x -F delete_branch_on_merge=true'
    assert_output --partial "rc=[0] errors=[0] calls=[0]"
}

@test "execute_gh_api_with_retry: retries on a transient JSON status (503), and succeeds" {
    _gh_response 1 1 '{"message":"Service Unavailable","status":"503"}' 'gh: Service Unavailable (HTTP 503)'
    _gh_response 2 0 '{"id":42}' ''
    _run_scripted_gh "execute_gh_api_with_retry 3 0 --query repos/acme/x"
    assert_output --partial '{"id":42}'
    assert_output --partial "rc=[0] errors=[0] calls=[2]"
}

@test "execute_gh_api_with_retry: does not retry a non-transient JSON status (404); returns err_tool_error, without an error" {
    _gh_response 1 1 '{"message":"Not Found","status":"404"}' 'gh: Not Found (HTTP 404)'
    _run_scripted_gh "execute_gh_api_with_retry 3 0 --query repos/acme/x/contents/benchmarks"
    refute_output --partial "ERROR"
    assert_output --partial "rc=[$err_tool_error] errors=[0] calls=[1]"
}

@test "execute_gh_api_with_retry: the JSON status decides, not numbers in stderr" {
    # the JSON body says 404 (not transient); a stderr that mentions '500' (e.g. in a URL) must not make it a retry
    _gh_response 1 1 '{"message":"Not Found","status":"404"}' 'gh: Not Found (HTTP 404): repos/o/n/actions/runs/15004291234'
    _run_scripted_gh "execute_gh_api_with_retry 3 0 --query repos/o/n/actions/runs/15004291234"
    assert_output --partial "calls=[1]"
}

@test "execute_gh_api_with_retry: without a JSON body, a network error in stderr is retried" {
    _gh_response 1 1 'not json' 'error connecting to api.github.com: network is unreachable'
    _gh_response 2 0 '{"id":42}' ''
    _run_scripted_gh "execute_gh_api_with_retry 3 0 --query repos/acme/x"
    assert_output --partial "rc=[0] errors=[0] calls=[2]"
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

@test "get_repo_state: treats a URL with github.com in its path as 'not GitHub' (regression: a mirror matched)" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://mirror.example/github.com/vmelamed/vm2.Sample.git)"
    assert_success
    assert_output "rc=[0] name=[] owner=[] full_name=[]"
}

@test "get_repo_state: treats a local path remote with a github.com directory as 'not GitHub'" {
    _run_get_repo_state "$(_make_repo vm2.Sample /srv/github.com/vmelamed/vm2.Sample)"
    assert_success
    assert_output "rc=[0] name=[] owner=[] full_name=[]"
}

@test "get_repo_state: treats a host that merely starts with github.com as 'not GitHub'" {
    _run_get_repo_state "$(_make_repo vm2.Sample https://github.com.evil.com/vmelamed/vm2.Sample)"
    assert_success
    assert_output "rc=[0] name=[] owner=[] full_name=[]"
}

@test "get_repo_state: treats github.com/owner/name without a scheme as a relative local path, not GitHub (regression)" {
    # Git reads 'host:path' as the scp-like form only when a ':' comes before the first '/'; otherwise it is a local path.
    _run_get_repo_state "$(_make_repo vm2.Sample github.com/vmelamed/vm2.Sample.git)"
    assert_success
    assert_output "rc=[0] name=[] owner=[] full_name=[]"
}

@test "get_repo_state: treats user@github.com/owner/name without a scheme as a relative local path, not GitHub" {
    _run_get_repo_state "$(_make_repo vm2.Sample git@github.com/vmelamed/vm2.Sample)"
    assert_success
    assert_output "rc=[0] name=[] owner=[] full_name=[]"
}

@test "get_repo_state: accepts the scp-like form without a user (github.com:owner/name)" {
    _run_get_repo_state "$(_make_repo vm2.Sample github.com:vmelamed/vm2.Sample)"
    assert_success
    assert_output "rc=[0] name=[vm2.Sample] owner=[vmelamed] full_name=[vmelamed/vm2.Sample]"
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
