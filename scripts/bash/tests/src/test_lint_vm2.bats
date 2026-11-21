#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/lint-vm2.sh: the library sanity checks pass on the real
# library, and each check reports the silly error it exists for. The failing cases run the script
# from a committed copy of the library in a scratch git repository, so the real one is never touched.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required: see that file's own comment.
declare -gx lib_dir

_script="$(cd "$lib_dir/../src" && pwd)/lint-vm2.sh"

# Copies the library and the script into $BATS_TEST_TMPDIR/repo/scripts/bash/{lib,src} and commits
# them, so the untracked-file check passes until a test adds a file on purpose.
_copy_library()
{
    local _repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$_repo/scripts/bash/src"
    cp -r "$lib_dir" "$_repo/scripts/bash/lib"
    cp "$_script" "$_repo/scripts/bash/src/"
    git -C "$_repo" init -q
    git -C "$_repo" add -A
    git -C "$_repo" -c user.email=test@example.com -c user.name=test commit -qm "copy"
    _copy="$_repo/scripts/bash"
}

_run_copy()
{
    run env -i HOME="$HOME" PATH="$PATH" bash "$_copy/src/lint-vm2.sh"
}

# bats test_tags=time:6
@test "lint-vm2: passes on the real library" {
    run env -i HOME="$HOME" PATH="$PATH" bash "$_script"
    assert_success
    assert_output --partial "loaded fine"
}

@test "lint-vm2: reports a stray command at the top level of a library file, with its file and line" {
    _copy_library
    printf 'r\n' >> "$_copy/lib/_predicates.sh"
    _run_copy
    assert_failure
    assert_output --partial "_predicates.sh: line"
    assert_output --partial "r: command not found"
}

@test "lint-vm2: reports a library file that core.sh does not source" {
    _copy_library
    printf '(( ${__VM2_LIB_ORPHAN_SH_LOADED:-0} == 1 )) && return 0\ndeclare -ri __VM2_LIB_ORPHAN_SH_LOADED=1\n' > "$_copy/lib/_orphan.sh"
    git -C "$_copy" add -A && git -C "$_copy" -c user.email=t@e.com -c user.name=t commit -qm orphan
    _run_copy
    assert_failure
    assert_output --partial "'_orphan.sh' is not sourced by core.sh"
}

@test "lint-vm2: reports a library file whose source statement in core.sh is commented out" {
    _copy_library
    sed -i 's|^source "$lib_dir/_xml.sh"$|# &|' "$_copy/lib/core.sh"
    grep -qF '# source "$lib_dir/_xml.sh"' "$_copy/lib/core.sh"     # the sed above must have matched
    git -C "$_copy" -c user.email=t@e.com -c user.name=t commit -qam commented
    _run_copy
    assert_failure
    assert_output --partial "'_xml.sh' is not sourced by core.sh"
}

@test "lint-vm2: reports an untracked library file" {
    _copy_library
    printf '(( ${__VM2_LIB_NEW_SH_LOADED:-0} == 1 )) && return 0\ndeclare -ri __VM2_LIB_NEW_SH_LOADED=1\n' > "$_copy/lib/_new.sh"
    sed -i 's|^source "$lib_dir/_xml.sh"$|&\nsource "$lib_dir/_new.sh"|' "$_copy/lib/core.sh"
    _run_copy
    assert_failure
    assert_output --partial "Untracked library files"
    assert_output --partial "_new.sh"
}

@test "lint-vm2: reports an include guard that is not named after its file" {
    _copy_library
    sed -i 's/__VM2_LIB_XML_SH_LOADED/__VM2_LIB_XMLS_SH_LOADED/g' "$_copy/lib/_xml.sh"
    git -C "$_copy" -c user.email=t@e.com -c user.name=t commit -qam guard
    _run_copy
    assert_failure
    assert_output --partial "'_xml.sh': the include guard is '__VM2_LIB_XMLS_SH_LOADED', expected '__VM2_LIB_XML_SH_LOADED'"
}

@test "lint-vm2: reports a function defined in two library files, but not the known overrides" {
    _copy_library
    printf '\nfunction trim() { :; }\n' >> "$_copy/lib/_xml.sh"
    git -C "$_copy" -c user.email=t@e.com -c user.name=t commit -qam dup
    _run_copy
    assert_failure
    assert_output --partial "The function 'trim' is defined in more than one library file"
    refute_output --partial "The function 'usage'"
}

@test "lint-vm2: reports a readonly variable declared without a value" {
    _copy_library
    printf '\ndeclare -xri err_renamed_away\n' >> "$_copy/lib/_xml.sh"
    git -C "$_copy" -c user.email=t@e.com -c user.name=t commit -qam readonly
    _run_copy
    assert_failure
    assert_output --partial "The readonly variable 'err_renamed_away' is declared, but never given a value"
}

@test "lint-vm2: reports a syntax error in a script" {
    _copy_library
    printf '#!/usr/bin/env bash\nif true; then\n' > "$_copy/src/broken.sh"
    git -C "$_copy" add -A && git -C "$_copy" -c user.email=t@e.com -c user.name=t commit -qm broken
    _run_copy
    assert_failure
    assert_output --partial "Syntax error in"
    assert_output --partial "broken.sh"
}

# --- check 8: the message templates ----------------------------------------------------------

# Appends a function with the given message call to a library file of the copy, and commits it.
_add_message()
{
    printf '\nfunction __lint_probe()\n{\n    %s\n}\n' "$1" >> "$_copy/lib/_xml.sh"
    git -C "$_copy" -c user.email=t@e.com -c user.name=t commit -qam probe
}

@test "lint-vm2: reports a bug message whose verb is not 'requires'" {
    _copy_library
    # shellcheck disable=SC2016 # the message is literal text for the probe function
    _add_message 'bug "${FUNCNAME[0]}() expects 1 argument (provided $#)." -ec "$err_invalid_arguments"'
    _run_copy
    assert_failure
    assert_output --partial "the verb is 'requires'"
    assert_output --partial "_xml.sh:"
}

@test "lint-vm2: reports an argument count in words, or with 'exactly'" {
    _copy_library
    # shellcheck disable=SC2016 # the messages are literal text for the probe function
    _add_message 'bug "${FUNCNAME[0]}() requires exactly 2 arguments (provided $#)." -ec "$err_invalid_arguments"
    bug "${FUNCNAME[0]}() requires two arguments (provided $#)." -ec "$err_invalid_arguments"'
    _run_copy
    assert_failure
    assert_output --partial "the argument count uses digits"
    assert_output --partial "the argument count has no 'exactly'"
}

@test "lint-vm2: reports an unquoted or misplaced provided value" {
    _copy_library
    # shellcheck disable=SC2016 # the messages are literal text for the probe function
    _add_message 'bug "${FUNCNAME[0]}() requires argument 1 to be a file (provided ${1-<missing>})." -ec "$err_not_file"
    bug "${FUNCNAME[0]}() requires 1 argument ($# provided)." -ec "$err_invalid_arguments"'
    _run_copy
    assert_failure
    assert_output --partial "the provided value is quoted"
    assert_output --partial "the provided value reads"
}

@test "lint-vm2: reports '-ec' before a message part" {
    _copy_library
    # shellcheck disable=SC2016 # the message is literal text for the probe function
    _add_message 'error "Failed to read the file." -ec "$err_io_failure" "Check its permissions."'
    _run_copy
    assert_failure
    assert_output --partial "'-ec' comes after the message parts"
}

@test "lint-vm2: reports 'Please' in a message, but not in a help text or a comment" {
    _copy_library
    # shellcheck disable=SC2016 # the message is literal text for the probe function
    _add_message 'warning "Please install the tool."'
    printf '# Please note: a comment\n' >> "$_copy/lib/_git.sh"
    printf '#!/usr/bin/env bash\necho "Please see the help."\n' > "$_copy/src/demo.usage.sh"
    git -C "$_copy" add -A && git -C "$_copy" -c user.email=t@e.com -c user.name=t commit -qm please
    _run_copy
    assert_failure
    assert_output --partial "without 'Please'"
    assert_output --partial "_xml.sh:"
    refute_output --partial "_git.sh:"
    refute_output --partial "demo.usage.sh:"
}

@test "lint-vm2: a message that follows the templates is not reported" {
    _copy_library
    # shellcheck disable=SC2016 # the messages are literal text for the probe function
    _add_message 'bug "${FUNCNAME[0]}() requires 1 or 2 arguments (provided $#):" "  - the path" -ec "$err_invalid_arguments"
    bug "${FUNCNAME[0]}() requires argument 1, the path, to be a file (provided '"'"'${1-<missing>}'"'"')." -ec "$err_not_file"'
    _run_copy
    assert_success
}
