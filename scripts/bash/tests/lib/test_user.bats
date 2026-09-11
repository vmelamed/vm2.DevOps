#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_user.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- press_any_key ------------------------------------------------------------------------

@test "press_any_key: returns immediately without prompting when quiet" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_quiet; press_any_key" < /dev/null
    assert_success
    refute_output --partial "Press any key to continue"
}

@test "press_any_key: consumes exactly one character of input and returns successfully when not quiet" {
    # read -p only ever displays its prompt when stdin is a real terminal (per bash(1)), which
    # is never true under bats -- so the prompt text itself isn't observable here; this checks
    # the actual behavior instead: it reads one key and returns.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; press_any_key; echo done" <<< "x"
    assert_success
    assert_output --partial "done"
}

# --- confirm --------------------------------------------------------------------------------

@test "confirm: quiet mode returns the default (y) without prompting" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_quiet; confirm 'Proceed?'"
    assert_success
}

@test "confirm: quiet mode honors an explicit 'n' default" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_quiet; confirm 'Proceed?' n"
    assert_failure 1
}

@test "confirm: reads y/n from stdin when not quiet" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; echo y | confirm 'Proceed?'"
    assert_success
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; echo n | confirm 'Proceed?'"
    assert_failure 1
}

@test "confirm: empty input falls back to the default" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; echo '' | confirm 'Proceed?' n"
    assert_failure 1
}

@test "confirm: re-prompts on invalid input until a valid y/n is given" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; printf 'maybe\ny\n' | confirm 'Proceed?'"
    assert_success
    assert_output --partial "Please enter one of Y or N"
}

@test "confirm: bug-exits with the wrong argument count" {
    run confirm
    assert_failure 254
}

@test "confirm: bug-exits on an invalid default response" {
    run confirm "Proceed?" "maybe"
    assert_failure 254
}

# --- enter_value ------------------------------------------------------------------------------

@test "enter_value: quiet mode echoes the default without prompting" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_quiet; declare v=''; enter_value 'Name' v 'default-val'"
    assert_success
    assert_output "default-val"
}

@test "enter_value: reads input from stdin and stores it via the nameref" {
    # `<<<` (herestring), not a pipe: enter_value writes into $v via a nameref, and the right
    # side of a pipe runs in a subshell -- that write would be lost (see the file-level warning
    # at the top of _diagnostics.sh about piping into functions that set variables).
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare v=''; enter_value 'Name' v <<< 'typed-value'; echo \"[\$v]\""
    assert_success
    assert_output --partial "[typed-value]"
}

@test "enter_value: empty input falls back to the default" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare v=''; enter_value 'Name' v 'fallback' <<< ''; echo \"[\$v]\""
    assert_success
    assert_output --partial "[fallback]"
}

@test "enter_value: re-prompts until the validation function accepts the input" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        function only_abc() { [[ \$1 == abc ]]; }
        declare v=''
        enter_value 'Name' v '' false only_abc <<< \$'wrong\nabc'
        echo \"[\$v]\"
    "
    assert_success
    assert_output --partial "[abc]"
}

@test "enter_value: bug-exits on an undefined output variable" {
    run enter_value "Name" not_a_defined_var
    assert_failure 254
}

@test "enter_value: bug-exits on a non-boolean secret flag" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare v=''; enter_value 'Name' v '' maybe"
    assert_failure 254
}

@test "enter_value: bug-exits when the default value itself fails validation" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        function only_abc() { [[ \$1 == abc ]]; }
        declare v=''
        enter_value 'Name' v 'not-abc' false only_abc
    "
    assert_failure 254
}

# --- choose -----------------------------------------------------------------------------------

@test "choose: quiet mode returns the first (default) option without prompting" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; set_quiet; declare c=''; choose 'Pick one:' c A B C; echo \"\$c\""
    assert_success
    assert_output "1"
}

@test "choose: reads a valid numeric choice from stdin" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare c=''; choose 'Pick one:' c A B C <<< 2; echo \"[\$c]\""
    assert_success
    assert_output --partial "[2]"
}

@test "choose: empty input falls back to the default (1)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare c=''; choose 'Pick one:' c A B C <<< ''; echo \"[\$c]\""
    assert_success
    assert_output --partial "[1]"
}

@test "choose: re-prompts on an out-of-range or non-numeric choice" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; declare c=''; choose 'Pick one:' c A B C <<< \$'abc\n99\n2'; echo \"[\$c]\""
    assert_success
    assert_output --partial "Invalid choice"
    assert_output --partial "[2]"
}

@test "choose: bug-exits with fewer than four arguments" {
    run choose "Pick one:" c A
    assert_failure 254
}

@test "choose: bug-exits on an empty choice text" {
    run choose "Pick one:" c A ""
    assert_failure 254
}

@test "choose: bug-exits on an undefined output variable" {
    run choose "Pick one:" not_a_defined_var A B
    assert_failure 254
}

# --- print_sequence ---------------------------------------------------------------------------

@test "print_sequence: default quoting and comma separator, no parentheses" {
    run print_sequence apple banana cherry
    assert_success
    assert_output "'apple','banana','cherry'"
}

@test "print_sequence: --json-array shorthand" {
    run print_sequence --json-array apple banana
    assert_success
    assert_output '["apple", "banana"]'
}

@test "print_sequence: custom quote, separator, and parentheses" {
    run print_sequence --quote='"' --separator='; ' --paren='()' apple banana cherry
    assert_success
    assert_output '("apple"; "banana"; "cherry")'
}

@test "print_sequence: bracket and brace parentheses" {
    run print_sequence --paren='[]' a b
    assert_success
    assert_output "['a','b']"
    run print_sequence --paren='{}' a b
    assert_success
    assert_output "{'a','b'}"
}

@test "print_sequence: 'nl' separator and paren produce newlines" {
    run print_sequence --separator=nl a b
    assert_success
    assert_line --index 0 "'a'"
    assert_line --index 1 "'b'"
}

@test "print_sequence: warns and drops parentheses on an unknown paren type" {
    run print_sequence --paren=weird a b
    assert_success
    assert_output --partial "Unknown paren type"
    assert_output --partial "'a','b'"
}

@test "print_sequence: preserves a value that looks like a flag, e.g. a negative number (regression)" {
    run print_sequence apple -5 banana
    assert_success
    assert_output "'apple','-5','banana'"
}

@test "print_sequence: empty quote produces no quoting" {
    run print_sequence --quote='' a b
    assert_success
    assert_output "a,b"
}
