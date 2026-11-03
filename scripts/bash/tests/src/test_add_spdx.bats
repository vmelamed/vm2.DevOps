#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# End-to-end tests for scripts/bash/src/add-spdx.sh. Each test builds a small directory tree under $BATS_TEST_TMPDIR and runs
# the real script on it in a fresh, environment-free bash ('env -i'), from inside that tree, so the default directory (the
# current one) is exercised as well.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

declare -gx lib_dir
declare -gxi err_not_file
declare -gxi err_not_directory
declare -gxi err_argument_value
declare -gxi err_missing_argument
declare -gxi err_unknown_argument
declare -gxi err_too_many_arguments

_script="$(cd "$lib_dir/../src" && pwd)/add-spdx.sh"

# Runs add-spdx.sh from directory $1 with the remaining arguments. Environment variables for the script (e.g. LICENSE=...)
# can be put in $_env before the call.
_spdx() {
    local _cwd="$1"; shift
    # shellcheck disable=SC2086 # $_env is unquoted on purpose: it splits into the NAME=value words env expects
    (cd "$_cwd" && env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" ${_env:-} bash "$_script" "$@")
}

# The SPDX/copyright header lines for C#-style and '#'-style comments.
_cs_header() { printf '// SPDX-License-Identifier: %s\n// Copyright (c) 2025-2026 Val Melamed\n\n' "${1:-MIT}"; }
_sh_header() { printf '# SPDX-License-Identifier: %s\n# Copyright (c) 2025-2026 Val Melamed\n\n' "${1:-MIT}"; }

_skip_if_root() {
    (( EUID != 0 )) || skip "root can write read-only files"
}

setup() {
    dir="$BATS_TEST_TMPDIR/d"
    mkdir -p "$dir"
}

# --- writing the header -------------------------------------------------------------------------------------------------------

@test "add-spdx: prepends the header to a C# file and keeps its final newline" {
    printf 'class A {}\n' > "$dir/a.cs"

    run _spdx "$dir"

    assert_success
    assert_output --partial "Added header to: ./a.cs"
    assert_equal "$(cat -A "$dir/a.cs")" "$( { _cs_header; printf 'class A {}\n'; } | cat -A)"
}

@test "add-spdx: strips a leading UTF-8 BOM from a C# file" {
    printf '\xEF\xBB\xBFclass A {}\n' > "$dir/a.cs"

    run _spdx "$dir"

    assert_success
    assert_equal "$(od -An -tx1 "$dir/a.cs")" "$( { _cs_header; printf 'class A {}\n'; } | od -An -tx1)"
}

@test "add-spdx: inserts the header after the shebang line of a bash file" {
    printf '#!/usr/bin/env bash\necho hi\n' > "$dir/b.sh"

    run _spdx "$dir"

    assert_success
    assert_equal "$(cat -A "$dir/b.sh")" "$( { printf '#!/usr/bin/env bash\n'; _sh_header; printf 'echo hi\n'; } | cat -A)"
}

@test "add-spdx: prepends the header to a bash file without a shebang" {
    printf 'echo hi\n' > "$dir/b.sh"

    run _spdx "$dir"

    assert_success
    assert_equal "$(cat -A "$dir/b.sh")" "$( { _sh_header; printf 'echo hi\n'; } | cat -A)"
}

@test "add-spdx: processes *.bats files like bash files" {
    printf '#!/usr/bin/env bats\n@test "x" { true; }\n' > "$dir/c.bats"

    run _spdx "$dir"

    assert_success
    assert_output --partial "Added header to: ./c.bats"
    assert_equal "$(sed -n 2p "$dir/c.bats")" "# SPDX-License-Identifier: MIT"
}

@test "add-spdx: prepends the header to *.yaml and *.yml files" {
    printf 'a: 1\n' > "$dir/a.yaml"
    printf 'b: 2\n' > "$dir/b.yml"

    run _spdx "$dir"

    assert_success
    assert_equal "$(cat -A "$dir/a.yaml")" "$( { _sh_header; printf 'a: 1\n'; } | cat -A)"
    assert_equal "$(cat -A "$dir/b.yml")"  "$( { _sh_header; printf 'b: 2\n'; } | cat -A)"
}

@test "add-spdx: preserves the file mode" {
    printf '#!/usr/bin/env bash\necho hi\n' > "$dir/b.sh"
    chmod 0751 "$dir/b.sh"

    run _spdx "$dir"

    assert_success
    assert_equal "$(stat -c %a "$dir/b.sh")" "751"
}

@test "add-spdx: leaves no temporary files behind" {
    printf 'class A {}\n' > "$dir/a.cs"
    printf 'echo hi\n'    > "$dir/b.sh"

    run _spdx "$dir"

    assert_success
    assert_equal "$(ls -A "$dir" | tr '\n' ' ')" "a.cs b.sh "
}

@test "add-spdx: scans subdirectories recursively" {
    mkdir -p "$dir/x/y"
    printf 'class A {}\n' > "$dir/x/y/a.cs"

    run _spdx "$dir"

    assert_success
    assert_output --partial "Added header to: ./x/y/a.cs"
}

# --- the license ---------------------------------------------------------------------------------------------------------------

@test "add-spdx: --license sets the SPDX license identifier" {
    printf 'class A {}\n' > "$dir/a.cs"

    run _spdx "$dir" --license Apache-2.0

    assert_success
    assert_equal "$(head -n 1 "$dir/a.cs")" "// SPDX-License-Identifier: Apache-2.0"
}

@test "add-spdx: \$LICENSE sets the SPDX license identifier" {
    printf 'class A {}\n' > "$dir/a.cs"

    _env="LICENSE=BSD-3-Clause" run _spdx "$dir"

    assert_success
    assert_equal "$(head -n 1 "$dir/a.cs")" "// SPDX-License-Identifier: BSD-3-Clause"
}

@test "add-spdx: --license overrides \$LICENSE" {
    printf 'class A {}\n' > "$dir/a.cs"

    _env="LICENSE=BSD-3-Clause" run _spdx "$dir" --license Apache-2.0

    assert_success
    assert_equal "$(head -n 1 "$dir/a.cs")" "// SPDX-License-Identifier: Apache-2.0"
}

# --- what is skipped -----------------------------------------------------------------------------------------------------------

@test "add-spdx: skips a file that already has an SPDX header and leaves it unchanged" {
    printf '// SPDX-License-Identifier: Apache-2.0\nclass A {}\n' > "$dir/a.cs"

    run _spdx "$dir"

    assert_success
    assert_output --partial "Skipping (has header): ./a.cs"
    assert_equal "$(cat "$dir/a.cs")" "$(printf '// SPDX-License-Identifier: Apache-2.0\nclass A {}')"
}

@test "add-spdx: skips a read-only file that already has a header (not an error)" {
    printf '// SPDX-License-Identifier: MIT\nclass A {}\n' > "$dir/a.cs"
    chmod a-w "$dir/a.cs"

    run _spdx "$dir"

    assert_success
    assert_output --partial "Skipping (has header): ./a.cs"
    assert_output --partial "skipped=1, failed=0"
}

@test "add-spdx: ignores generated C# files and the obj/ and bin/ directories" {
    mkdir -p "$dir/obj" "$dir/bin"
    for f in obj/o.cs bin/b.cs AssemblyInfo.cs x.g.cs x.designer.cs; do
        printf 'class A {}\n' > "$dir/$f"
    done

    run _spdx "$dir"

    assert_success
    assert_output --partial "scanned=0"
    for f in obj/o.cs bin/b.cs AssemblyInfo.cs x.g.cs x.designer.cs; do
        assert_equal "$(cat "$dir/$f")" "class A {}"
    done
}

@test "add-spdx: ignores files with other extensions" {
    printf 'text\n' > "$dir/a.txt"
    printf 'echo hi\n' > "$dir/script"

    run _spdx "$dir"

    assert_success
    assert_output --partial "scanned=0"
}

@test "add-spdx: does not descend into .git" {
    git -C "$dir" init -q
    printf 'echo hi\n' > "$dir/.git/x.sh"

    run _spdx "$dir"

    assert_success
    assert_output --partial "scanned=0"
    assert_equal "$(cat "$dir/.git/x.sh")" "echo hi"
}

@test "add-spdx: does not touch git submodules" {
    local _sub="$BATS_TEST_TMPDIR/sub"
    git init -q "$_sub"
    printf 'echo third-party\n' > "$_sub/lib.sh"
    git -C "$_sub" add lib.sh
    git -C "$_sub" -c user.name=t -c user.email=t@t commit -q -m "init"

    git -C "$dir" init -q
    git -C "$dir" -c protocol.file.allow=always submodule add -q "$_sub" libs/sub
    printf 'echo ours\n' > "$dir/ours.sh"

    run _spdx "$dir"

    assert_success
    assert_output --partial "Added header to: ./ours.sh"
    refute_output --partial "libs/sub"
    assert_equal "$(cat "$dir/libs/sub/lib.sh")" "echo third-party"
}

@test "add-spdx: works outside a git work tree without a post-mortem" {
    printf 'echo hi\n' > "$dir/b.sh"

    run _spdx "$dir"

    assert_success
    refute_output --partial "post-mortem"
}

# --- dry run -------------------------------------------------------------------------------------------------------------------

@test "add-spdx: --dry-run reports the changes but modifies nothing and leaves no temporary files" {
    printf 'class A {}\n' > "$dir/a.cs"
    printf 'echo hi\n'    > "$dir/b.sh"

    run _spdx "$dir" --dry-run

    assert_success
    assert_output --partial "Would've added header to: ./a.cs"
    assert_output --partial "Would've added header to: ./b.sh"
    assert_output --partial "dry-run$ mv"
    assert_output --partial "Summary (dry run): scanned=2, modified=2, skipped=0, failed=0"
    assert_equal "$(cat "$dir/a.cs")" "class A {}"
    assert_equal "$(cat "$dir/b.sh")" "echo hi"
    assert_equal "$(ls -A "$dir" | tr '\n' ' ')" "a.cs b.sh "
}

# --- failures ------------------------------------------------------------------------------------------------------------------

@test "add-spdx: reports a read-only file without a header as an error, leaves it unchanged, and processes the rest" {
    _skip_if_root
    printf 'a: 1\n'       > "$dir/ro.yaml"
    chmod a-w "$dir/ro.yaml"
    printf 'class A {}\n' > "$dir/a.cs"

    run _spdx "$dir"

    assert_failure "$err_not_file"
    assert_output --partial "to be an existing writable file"
    assert_output --partial "Added header to: ./a.cs"
    assert_equal "$(cat "$dir/ro.yaml")" "a: 1"
}

@test "add-spdx: the summary counts each file exactly once (scanned = modified + skipped + failed)" {
    _skip_if_root
    printf 'class A {}\n'                          > "$dir/new.cs"
    printf '// SPDX-License-Identifier: MIT\n'     > "$dir/has.cs"
    printf 'a: 1\n'                                > "$dir/ro.yaml"
    chmod a-w "$dir/ro.yaml"

    run _spdx "$dir"

    assert_failure "$err_not_file"
    assert_output --partial "Summary: scanned=3, modified=1, skipped=1, failed=1"
}

# --- arguments -----------------------------------------------------------------------------------------------------------------

@test "add-spdx: scans the directory given as the positional argument" {
    printf 'class A {}\n' > "$dir/a.cs"

    run _spdx "$BATS_TEST_TMPDIR" "$dir"

    assert_success
    assert_output --partial "Added header to: ./a.cs"
}

@test "add-spdx: rejects a second directory" {
    run _spdx "$dir" "$dir" "$dir"

    assert_failure "$err_too_many_arguments"
    assert_output --partial "Multiple directories specified"
}

@test "add-spdx: rejects a directory that does not exist" {
    run _spdx "$dir" "$dir/missing"

    assert_failure "$err_not_directory"
    assert_output --partial "Directory not found: '$dir/missing'"
}

@test "add-spdx: rejects an empty --license" {
    run _spdx "$dir" --license ''

    assert_failure "$err_argument_value"
    assert_output --partial "The license (--license) must not be empty."
}

@test "add-spdx: rejects --license without a value" {
    run _spdx "$dir" --license

    assert_failure "$err_missing_argument"
    assert_output --partial "Missing value for --license"
}

@test "add-spdx: rejects an unknown option" {
    run _spdx "$dir" --bogus

    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
}
