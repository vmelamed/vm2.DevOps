#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/core.sh, as it behaves TODAY.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi failure
declare -gxi err_invalid_arguments
declare -gxi err_argument_type
declare -gxi err_argument_value
declare -gxi err_invalid_nameref
declare -gxi err_not_found

# --- trap setup, on_err, on_exit, and controlled exits ------------------------------------------

@test "core.sh: sets the ERR and EXIT traps by default" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        [[ -n \$(trap -p ERR) ]]  || { echo 'ERR trap not set'; exit 1; }
        [[ -n \$(trap -p EXIT) ]] || { echo 'EXIT trap not set'; exit 1; }
        echo OK
    "
    assert_success
    assert_output "OK"
}

@test "core.sh --no-trap: suppresses the ERR and EXIT traps" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        [[ -z \$(trap -p ERR) ]]  || { echo 'ERR trap set despite --no-trap'; exit 1; }
        [[ -z \$(trap -p EXIT) ]] || { echo 'EXIT trap set despite --no-trap'; exit 1; }
        echo OK
    "
    assert_success
    assert_output "OK"
}

@test "on_err: a failing command prints the post-mortem" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        false
        echo 'reached after false'
    "
    assert_output --partial "ON ERROR post-mortem"
}

# errtrace (set -E in core.sh): without it, bash does not pass the ERR trap on to functions, and a failure inside a
# function -- where most of the work happens -- never reached on_err, so its post-mortem and call stack were lost.
@test "on_err: under set -e, a failure inside a function prints the post-mortem once, with the function in the stack" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        set -euo pipefail
        source '$lib_dir/core.sh' > /dev/null 2>&1
        inner_function() { false; }
        outer_function() { inner_function; }
        outer_function
    "
    assert_failure 1
    [[ $(grep -c "ON ERROR post-mortem" <<< "$output") == 1 ]]
    assert_output --partial "inner_function"
    assert_output --partial "outer_function"
}

@test "on_err: under set -e, a non-zero return two functions deep keeps its exit code, with no bash internal error" {
    # regression: on_err's non-zero return, and show_stack's '(( _take = 0 ))' failing under set -e inside the ERR
    # handler, turned 7 into 1 and made bash 5.2 report 'pop_var_context: head of shell_variables not a function context'
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        set -euo pipefail
        source '$lib_dir/core.sh' > /dev/null 2>&1
        inner_function() { return 7; }
        outer_function() { inner_function; }
        outer_function
        echo 'not reached'
    "
    assert_failure 7
    refute_output --partial "pop_var_context"
    refute_output --partial "not reached"
    [[ $(grep -c "ON ERROR post-mortem" <<< "$output") == 1 ]]
}

@test "on_err: a failure inside a function that the caller handles ('f || ...') prints no post-mortem" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        set -euo pipefail
        source '$lib_dir/core.sh' > /dev/null 2>&1
        failing_function() { false; }
        failing_function || echo 'handled by the caller'
    "
    assert_success
    assert_output "handled by the caller"
}

@test "on_exit: a script ending on a failing command reports it, and keeps its exit code" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        source '$lib_dir/core.sh' > /dev/null 2>&1
        false
    "
    assert_failure "$failure"
    assert_output --partial "EXIT: the command 'false' failed"
}

# Controlled exits (exit_with_error, usage, ...) used to call remove_traps first, to hide the fake post-mortem that
# on_exit's own non-zero return fired. on_exit now disables ERR and returns 0, so the traps stay in place: a controlled
# exit is still quiet, and the cleanups registered with add_trap now run on these error paths too.
@test "exit_with_error: under set -e, exits with its code, without a post-mortem or on_exit's line" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        set -euo pipefail
        source '$lib_dir/core.sh' > /dev/null 2>&1
        exit_with_error -ec 5 'controlled failure'
    "
    assert_failure 5
    assert_output --partial "controlled failure"
    refute_output --partial "ON ERROR post-mortem"
    refute_output --partial "EXIT: the command"
}

@test "exit_with_error: the cleanups registered with add_trap run on a controlled exit" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        set -euo pipefail
        source '$lib_dir/core.sh' > /dev/null 2>&1
        add_trap 'echo cleanup' EXIT
        exit_with_error -ec 5 'controlled failure'
    "
    assert_failure 5
    assert_line "cleanup"
}

@test "usage: an error exit through usage runs the add_trap cleanups and prints no post-mortem" {
    run env -i HOME="$HOME" PATH="$PATH" bash -c "
        set -euo pipefail
        source '$lib_dir/core.sh' > /dev/null 2>&1
        source '$lib_dir/_core_args.sh'
        add_trap 'echo cleanup' EXIT
        usage -ec 6 'Unknown option: --bogus'
    "
    assert_failure 6
    assert_line "cleanup"
    refute_output --partial "ON ERROR post-mortem"
}

# --- add_trap ------------------------------------------------------------------------------
# The child scripts are single-quoted (lib_dir passed via LIB) so the quoting under test is not
# mangled by an extra layer of double-quote escaping.

@test "add_trap: appends the command after core.sh's on_exit instead of replacing it" {
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        source "$LIB/core.sh" > /dev/null 2>&1
        add_trap "echo cleanup" EXIT
        trap -p EXIT
    '
    assert_success
    assert_line --index 0 "trap -- 'on_exit"
    assert_line --index 1 "echo cleanup' EXIT"
    assert_line --index 2 "cleanup"
}

@test "add_trap: appends safely after an existing command ending in '&' or a comment" {
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        source "$LIB/core.sh" --no-trap > /dev/null 2>&1
        trap -- "echo first # a comment" EXIT
        add_trap "true &" EXIT
        add_trap "echo cleanup" EXIT
    '
    assert_success
    assert_output $'first\ncleanup'
}

@test "add_trap: the command runs on a non-zero exit, and the exit code is kept even when it fails" {
    # Without set -e; the set -e variants (where the old on_exit cut the trap short) are above.
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        source "$LIB/core.sh" > /dev/null 2>&1
        add_trap "echo cleanup; false" EXIT
        exit 7
    '
    assert_failure 7
    assert_line "cleanup"
}

# The real scripts run with 'set -euo pipefail'. on_exit used to return the exit code it captured: under set -e that
# stopped the EXIT trap right there, so the cleanups add_trap appends never ran on a failing run, and its non-zero
# return fired the ERR trap (a fake post-mortem after every explicit 'exit N').
@test "add_trap: under set -e, the appended cleanup still runs on a failing command, and the exit code is kept" {
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        set -euo pipefail
        source "$LIB/core.sh" > /dev/null 2>&1
        add_trap "echo cleanup" EXIT
        false
    '
    assert_failure 1
    assert_line "cleanup"
    [[ $(grep -c "ON ERROR post-mortem" <<< "$output") == 1 ]]     # one, for 'false' itself -- none from on_exit
}

@test "add_trap: under set -e, an explicit 'exit N' runs the cleanup, keeps N, and prints no post-mortem" {
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        set -euo pipefail
        source "$LIB/core.sh" > /dev/null 2>&1
        add_trap "echo cleanup" EXIT
        exit 7
    '
    assert_failure 7
    assert_line "cleanup"
    refute_output --partial "ON ERROR post-mortem"
}

@test "add_trap: under set -e, a failing cleanup does not stop the cleanups after it" {
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        set -euo pipefail
        source "$LIB/core.sh" > /dev/null 2>&1
        add_trap "false" EXIT
        add_trap "echo second cleanup" EXIT
        exit 3
    '
    assert_failure 3
    assert_line "second cleanup"
}

@test "add_trap: with no trap set, the command becomes the whole trap" {
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        source "$LIB/core.sh" --no-trap > /dev/null 2>&1
        add_trap "echo cleanup" EXIT
        trap -p EXIT
    '
    assert_success
    assert_line --index 0 "trap -- 'echo cleanup' EXIT"
}

@test "add_trap: keeps an existing command containing quotes and \$ intact" {
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        source "$LIB/core.sh" --no-trap > /dev/null 2>&1
        x=value
        trap -- "echo \"it'\''s \$x\"" EXIT
        add_trap '\''echo "and $x"'\'' EXIT
    '
    assert_success
    assert_output $'it\'s value\nand value'
}

@test "add_trap: appends to every given signal" {
    run env -i HOME="$HOME" PATH="$PATH" LIB="$lib_dir" bash -c '
        source "$LIB/core.sh" --no-trap > /dev/null 2>&1
        add_trap "echo cleanup" EXIT INT
        trap -p INT
        trap - EXIT
    '
    assert_success
    assert_output "trap -- 'echo cleanup' SIGINT"
}

@test "add_trap: bug-exits with fewer than two arguments" {
    run add_trap 'echo cleanup'
    assert_failure "$err_invalid_arguments"
}

@test "add_trap: bug-exits on an invalid signal name" {
    run add_trap 'echo cleanup' NOT_A_SIGNAL
    assert_failure "$err_argument_value"
    assert_output --partial "NOT_A_SIGNAL"
}

# --- execute -------------------------------------------------------------------------------

@test "execute: bug-exits with no arguments" {
    run execute
    assert_failure "$err_invalid_arguments"
}

@test "execute: runs the command and forwards its stdout and exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute echo 'ran for real'"
    assert_success
    assert_output "ran for real"
}

@test "execute: in dry-run mode, prints the would-be command instead of running it" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute touch '$BATS_TEST_TMPDIR/should-not-exist'"
    assert_success
    assert_output "dry-run\$ touch $BATS_TEST_TMPDIR/should-not-exist"
    [[ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]]
}

@test "execute: forwards the failing command's own exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute bash -c 'exit 7'"
    assert_failure 7
}

@test "execute: in dry-run mode, the would-be command goes to stderr, never into a capture of stdout" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        set_dry_run
        captured=\$(execute echo data 2> /dev/null)
        printf '[%s]\n' \"\$captured\"
        execute echo data 2>&1 > /dev/null
    "
    assert_success
    assert_line --index 0 "[]"
    assert_line --index 1 "dry-run\$ echo data"
}

@test "execute: in dry-run mode, quotes the arguments so the printed command is exact" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute git commit -m 'Initial commit'"
    assert_success
    assert_output "dry-run\$ git commit -m Initial\\ commit"
}

@test "execute --quiet: bug-exits when no command follows the flag" {
    run execute --quiet
    assert_failure "$err_invalid_arguments"
}

@test "execute --quiet: discards the command's stdout and stderr, and forwards its exit code" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute --quiet bash -c 'echo out; echo err >&2; exit 7'"
    assert_failure 7
    assert_output ""
}

@test "execute --quiet: in verbose mode, shows the command's stdout and stderr" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_verbose; execute --quiet bash -c 'echo out; echo err >&2'"
    assert_success
    assert_line "out"
    assert_line "err"
}

@test "execute --quiet: in dry-run mode, still prints the would-be command and does not run it" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute --quiet touch '$BATS_TEST_TMPDIR/should-not-exist'"
    assert_success
    assert_output "dry-run\$ touch $BATS_TEST_TMPDIR/should-not-exist"
    [[ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]]
}

# --- execute_with_retry ---------------------------------------------------------------------

@test "execute_with_retry: bug-exits with fewer than three arguments" {
    run execute_with_retry 3 1
    assert_failure "$err_invalid_arguments"
}

@test "execute_with_retry: bug-exits on a non-natural max-attempts or delay" {
    run execute_with_retry 0 1 echo hi
    assert_failure "$err_argument_type"
    run execute_with_retry 3 -1 echo hi
    assert_failure "$err_argument_type"
}

@test "execute_with_retry: succeeds without retrying when the command succeeds immediately" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 3 1 echo hi"
    assert_success
    refute_output --partial "Retrying"
}

@test "execute_with_retry: a command literally named 'true'/'false' is consumed as the output-suppression flag, not run (accepted, documented ambiguity)" {
    # is_boolean "$1" && $1 && _output=... always treats a bare 'true'/'false' as the optional
    # output-suppression flag (core.sh:230-231), so it can never be the command itself -- see the
    # function's own doc comment for why this is accepted rather than fixed (retrying the literal
    # command 'true' or 'false' is never something a real caller would want).
    run execute_with_retry 3 1 true
    assert_failure "$err_invalid_arguments"
}

@test "execute_with_retry: retries on failure and returns success once the command succeeds" {
    local _counter="$BATS_TEST_TMPDIR/counter"
    local _script="$BATS_TEST_TMPDIR/attempt.sh"
    echo 0 > "$_counter"
    cat > "$_script" <<'SCRIPT'
#!/usr/bin/env bash
n=$(<"$1")
n=$((n + 1))
echo "$n" > "$1"
(( n >= 2 ))
SCRIPT
    chmod +x "$_script"

    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 3 1 bash '$_script' '$_counter'"
    assert_success
    assert_output --partial "Command failed (attempt 1/3). Retrying in 1s."
    [[ "$(cat "$_counter")" == 2 ]]
}

@test "execute_with_retry: returns the command's own exit code after exhausting all attempts" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 2 1 bash -c 'exit 7'"
    assert_failure 7
    assert_output --partial "Command failed (attempt 1/2)."
}

@test "execute_with_retry: redirects the command's stdout to \$_ignore when the output-suppression flag is true" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 3 1 true echo should-be-suppressed"
    assert_success
    refute_output --partial "should-be-suppressed"
}

@test "execute_with_retry: leaves the command's stdout visible when the output-suppression flag is false" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; execute_with_retry 3 1 false echo should-be-visible"
    assert_success
    assert_output --partial "should-be-visible"
}

@test "execute_with_retry: in dry-run mode, never executes the command" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; set_dry_run; execute_with_retry 3 1 touch '$BATS_TEST_TMPDIR/should-not-exist'"
    assert_success
    assert_output --partial "dry-run\$ touch"
    [[ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]]
}

# --- list_of_files ---------------------------------------------------------------------------

@test "list_of_files: bug-exits with the wrong argument count" {
    run list_of_files
    assert_failure "$err_invalid_arguments"
}

@test "list_of_files: bug-exits on an empty pattern" {
    run list_of_files ""
    assert_failure "$err_argument_value"
}

@test "list_of_files: expands a glob pattern to its matching files" {
    mkdir -p "$BATS_TEST_TMPDIR/glob"
    touch "$BATS_TEST_TMPDIR/glob/a.txt" "$BATS_TEST_TMPDIR/glob/b.txt"
    run bash -c "cd '$BATS_TEST_TMPDIR/glob' && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; list_of_files '*.txt'"
    assert_success
    assert_output "a.txt b.txt"
}

@test "list_of_files: a pattern with no matches expands to an empty string (nullglob)" {
    mkdir -p "$BATS_TEST_TMPDIR/glob-empty"
    run bash -c "cd '$BATS_TEST_TMPDIR/glob-empty' && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; list_of_files 'nomatch*.zzz'"
    assert_success
    assert_output ""
}

@test "list_of_files: a '**' pattern matches recursively into subdirectories (globstar)" {
    mkdir -p "$BATS_TEST_TMPDIR/glob-recursive/sub"
    touch "$BATS_TEST_TMPDIR/glob-recursive/a.txt" "$BATS_TEST_TMPDIR/glob-recursive/sub/c.txt"
    run bash -c "cd '$BATS_TEST_TMPDIR/glob-recursive' && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; list_of_files '**/*.txt'"
    assert_success
    assert_output "a.txt sub/c.txt"
}

# --- find_files_by_precedence ----------------------------------------------------------------

# Runs find_files_by_precedence on <dir> with the given patterns and prints the found files, sorted (the function itself
# does not sort), one per line. Returns the function's own exit code.
_ffp() {
    local -a _found=()
    local _dir=$1 _rc=0
    shift
    find_files_by_precedence "$_dir" _found "$@" || _rc=$?
    (( ${#_found[@]} == 0 )) || printf '%s\n' "${_found[@]}" | sort
    return "$_rc"
}

@test "find_files_by_precedence: returns only the files of the first pattern that matches anything" {
    local d="$BATS_TEST_TMPDIR/ffp"
    mkdir -p "$d/src" && touch "$d/x.sln" "$d/y.sln" "$d/src/a.csproj"
    run _ffp "$d" '*.slnx' '*.sln' '*.csproj'
    assert_success
    assert_output "$d/x.sln"$'\n'"$d/y.sln"
}

@test "find_files_by_precedence: falls through to a later pattern when the earlier ones match nothing, at any depth" {
    local d="$BATS_TEST_TMPDIR/ffp"
    mkdir -p "$d/src/deep/er" && touch "$d/src/deep/er/a.csproj"
    run _ffp "$d" '*.slnx' '*.sln' '*.csproj'
    assert_success
    assert_output "$d/src/deep/er/a.csproj"
}

@test "find_files_by_precedence: returns err_not_found, silently and with an empty array, when nothing matches" {
    local d="$BATS_TEST_TMPDIR/ffp"
    mkdir -p "$d" && touch "$d/readme.md"
    run _ffp "$d" '*.slnx' '*.csproj'
    assert_failure "$err_not_found"
    assert_output ""
}

@test "find_files_by_precedence: skips the '.git', 'bin', 'obj', and 'templates' directories" {
    local d="$BATS_TEST_TMPDIR/ffp"
    mkdir -p "$d/.git" "$d/src/bin" "$d/src/obj" "$d/templates/T/content"
    touch "$d/src/a.csproj" "$d/.git/g.csproj" "$d/src/bin/b.csproj" "$d/src/obj/o.csproj" "$d/templates/T/content/t.csproj"
    run _ffp "$d" '*.csproj'
    assert_success
    assert_output "$d/src/a.csproj"
}

@test "find_files_by_precedence: still searches a start directory that is itself named like a skipped one (e.g. 'bin')" {
    local d="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$d/src" && touch "$d/src/a.csproj"
    run _ffp "$d" '*.csproj'
    assert_success
    assert_output "$d/src/a.csproj"
}

@test "find_files_by_precedence: bug-exits with fewer than three arguments" {
    # shellcheck disable=SC2034 # only its name is passed: the call is missing the patterns
    local -a found=()
    run find_files_by_precedence "$BATS_TEST_TMPDIR" found
    assert_failure "$err_invalid_arguments"
}

@test "find_files_by_precedence: bug-exits when argument 2 is not the name of an indexed array" {
    # shellcheck disable=SC2034 # only its name is passed: the function must reject a scalar
    local scalar='not an array'
    run find_files_by_precedence "$BATS_TEST_TMPDIR" scalar '*.csproj'
    assert_failure "$err_invalid_nameref"
}

# --- to_summary (core.sh's plain, non-GitHub-Actions form) ------------------------------------

@test "to_summary: prepends a '## Summary' heading and passes each stdin line through" {
    run bash -c "CI=true; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; printf 'line1\nline2\n' | to_summary"
    assert_success
    assert_line --index 0 "## Summary"
    assert_line --index 1 "line1"
    assert_line --index 2 "line2"
}
