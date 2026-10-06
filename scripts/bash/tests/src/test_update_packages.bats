#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/update-packages.functions.sh. Each test runs in a fresh, environment-free
# bash that sources core.sh and the functions file, the same way the other src/ characterization tests do.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

declare -gx lib_dir
declare -gxi err_invalid_arguments

_src_dir="$(cd "$lib_dir/../src" && pwd)"

_up() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        $1
    "
}

# --- select_upgrade_version ---------------------------------------------------------------------

@test "select_upgrade_version: picks the highest stable candidate that is newer than the current version" {
    run _up "select_upgrade_version 1.0.0 chosen 1.0.2 1.2.0 1.1.0; echo \"\$chosen\""
    assert_success
    assert_output "1.2.0"
}

@test "select_upgrade_version: keeps the current version when no candidate is newer" {
    run _up "select_upgrade_version 1.2.0 chosen 1.0.0 1.2.0; echo \"\$chosen\""
    assert_success
    assert_output "1.2.0"
}

@test "select_upgrade_version: ignores prerelease candidates" {
    run _up "select_upgrade_version 1.0.0 chosen 1.5.0-preview.1 1.0.1; echo \"\$chosen\""
    assert_success
    assert_output "1.0.1"
}

@test "select_upgrade_version: never downgrades a current prerelease to an older stable" {
    run _up "select_upgrade_version 1.1.0-preview.3 chosen 1.0.2 1.0.0; echo \"\$chosen\""
    assert_success
    assert_output "1.1.0-preview.3"
}

@test "select_upgrade_version: a stable candidate newer than a current prerelease is chosen" {
    run _up "select_upgrade_version 1.1.0-preview.3 chosen 1.1.0 1.0.2; echo \"\$chosen\""
    assert_success
    assert_output "1.1.0"
}

@test "select_upgrade_version: with no candidates the current version is kept" {
    run _up "select_upgrade_version 1.0.0 chosen; echo \"\$chosen\""
    assert_success
    assert_output "1.0.0"
}

@test "select_upgrade_version: bug-exits with fewer than two arguments" {
    run _up "select_upgrade_version 1.0.0"
    assert_failure "$err_invalid_arguments"
}

# --- read_package_versions / set_package_version ----------------------------------------------

_props_fixture() {
    cat > "$1" <<'XML'
<Project>
    <!-- <<<=== begin shared content -->
    <ItemGroup>
        <PackageVersion Include="vm2.TestUtilities" Version="2.1.5" />
        <PackageVersion Include="xunit.v3.mtp-v2" Version="4.0.1" />
    </ItemGroup>
    <!-- ===>>> end shared content -->
    <ItemGroup>
        <!--<PackageVersion Include="Commented.Out" Version="9.9.9" />-->
        <PackageVersion Include="vm2.Ulid" Version="1.0.7" />
    </ItemGroup>
</Project>
XML
}

@test "read_package_versions: the shared section lists only the shared block's packages" {
    _props_fixture "$BATS_TEST_TMPDIR/Directory.Packages.props"
    run _up "declare -A v=(); read_package_versions '$BATS_TEST_TMPDIR/Directory.Packages.props' shared v; declare -p v"
    assert_success
    assert_output --partial '[vm2.TestUtilities]="2.1.5"'
    assert_output --partial '[xunit.v3.mtp-v2]="4.0.1"'
    refute_output --partial "vm2.Ulid"
}

@test "read_package_versions: the repo section lists only packages outside the markers and ignores commented-out lines" {
    _props_fixture "$BATS_TEST_TMPDIR/Directory.Packages.props"
    run _up "declare -A v=(); read_package_versions '$BATS_TEST_TMPDIR/Directory.Packages.props' repo v; declare -p v"
    assert_success
    assert_output --partial '[vm2.Ulid]="1.0.7"'
    refute_output --partial "vm2.TestUtilities"
    refute_output --partial "Commented.Out"
}

@test "set_package_version: rewrites only the version of the matching line in the repo section" {
    _props_fixture "$BATS_TEST_TMPDIR/Directory.Packages.props"
    run _up "set_package_version '$BATS_TEST_TMPDIR/Directory.Packages.props' repo vm2.Ulid 1.0.8; cat '$BATS_TEST_TMPDIR/Directory.Packages.props'"
    assert_success
    assert_output --partial 'Include="vm2.Ulid" Version="1.0.8"'
    assert_output --partial 'Include="vm2.TestUtilities" Version="2.1.5"'
}

@test "set_package_version: matches the ID case-insensitively and keeps the casing in the file" {
    _props_fixture "$BATS_TEST_TMPDIR/Directory.Packages.props"
    run _up "set_package_version '$BATS_TEST_TMPDIR/Directory.Packages.props' shared VM2.TESTUTILITIES 2.2.0; cat '$BATS_TEST_TMPDIR/Directory.Packages.props'"
    assert_success
    assert_output --partial 'Include="vm2.TestUtilities" Version="2.2.0"'
}

@test "set_package_version: never edits a package that is in the other section" {
    _props_fixture "$BATS_TEST_TMPDIR/Directory.Packages.props"
    run _up "set_package_version '$BATS_TEST_TMPDIR/Directory.Packages.props' repo vm2.TestUtilities 2.2.0"
    assert_failure "$err_logic_error"
    run cat "$BATS_TEST_TMPDIR/Directory.Packages.props"
    assert_output --partial 'Include="vm2.TestUtilities" Version="2.1.5"'
}

# --- query_package_versions (fake dotnet) -----------------------------------------------------------

_fake_dotnet() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/dotnet" <<'FAKE'
#!/usr/bin/env bash
cat <<'JSON'
{"version":2,"problems":[],"searchResult":[
 {"sourceName":"nuget.org","packages":[{"id":"vm2.Ulid","version":"1.0.7"},{"id":"vm2.Ulid","version":"1.0.8-preview.1"}]},
 {"sourceName":"github.vm2","packages":[{"id":"vm2.ulid","version":"1.0.9"}]}
]}
JSON
FAKE
    chmod +x "$BATS_TEST_TMPDIR/bin/dotnet"
}

@test "query_package_versions: collects the versions of the package from all sources, matching the ID case-insensitively" {
    _fake_dotnet
    run env PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" HOME="$HOME" bash -c "
        export PATH='$BATS_TEST_TMPDIR/bin':\"\$PATH\"
        source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        declare -a found=(); query_package_versions vm2.Ulid found; printf '%s\\n' \"\${found[@]}\"
    "
    assert_success
    assert_output --partial "1.0.7"
    assert_output --partial "1.0.8-preview.1"
    assert_output --partial "1.0.9"
}

# --- refresh_lock_files (temporary git repo, fake dotnet) ----------------------------------------

_lock_repo() {
    local _repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$_repo/src/App" "$BATS_TEST_TMPDIR/bin"
    git -C "$_repo" init -q
    git -C "$_repo" config user.email test@example.invalid
    git -C "$_repo" config user.name test
    echo '{"version":1,"old":true}' > "$_repo/src/App/packages.lock.json"
    git -C "$_repo" add -A && git -C "$_repo" commit -q -m init
    cat > "$BATS_TEST_TMPDIR/bin/dotnet" <<'FAKE'
#!/usr/bin/env bash
[[ $1 == restore ]] && echo '{"version":1,"regenerated":true}' > src/App/packages.lock.json
exit 0
FAKE
    chmod +x "$BATS_TEST_TMPDIR/bin/dotnet"
}

_refresh() {
    run env PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" HOME="$HOME" bash -c "
        export PATH='$BATS_TEST_TMPDIR/bin':\"\$PATH\"
        source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        source '$_src_dir/update-packages.repos.sh'
        refresh_lock_files '$BATS_TEST_TMPDIR/repo'
    "
}

@test "refresh_lock_files: restores and commits the regenerated lock file as its own commit" {
    _lock_repo
    _refresh
    assert_success
    run git -C "$BATS_TEST_TMPDIR/repo" log --format=%s -1
    assert_output "chore(deps): refresh packages.lock.json after Directory.Packages.props update"
    run git -C "$BATS_TEST_TMPDIR/repo" status --porcelain
    assert_output ""
}

@test "refresh_lock_files: regenerates lock files even when they had uncommitted changes" {
    _lock_repo
    echo '{"local-edit":true}' > "$BATS_TEST_TMPDIR/repo/src/App/packages.lock.json"
    _refresh
    assert_success
    run git -C "$BATS_TEST_TMPDIR/repo" status --porcelain
    assert_output ""
    run cat "$BATS_TEST_TMPDIR/repo/src/App/packages.lock.json"
    assert_output --partial '"regenerated":true'
}

@test "refresh_lock_files: a repository without lock files gets no commit" {
    _lock_repo
    git -C "$BATS_TEST_TMPDIR/repo" rm -q src/App/packages.lock.json && git -C "$BATS_TEST_TMPDIR/repo" commit -q -m "drop locks"
    _refresh
    assert_success
    run git -C "$BATS_TEST_TMPDIR/repo" log --oneline
    refute_output --partial "refresh packages.lock.json"
}

# --- prepare_upgrade_branch -------------------------------------------------------------------------

@test "prepare_upgrade_branch: switches to an existing upgrade branch instead of failing" {
    _lock_repo
    git -C "$BATS_TEST_TMPDIR/repo" branch deps/update-packages-test
    run env HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        source '$_src_dir/update-packages.repos.sh'
        prepare_upgrade_branch '$BATS_TEST_TMPDIR/repo' deps/update-packages-test ''
    "
    assert_success
    run git -C "$BATS_TEST_TMPDIR/repo" branch --show-current
    assert_output "deps/update-packages-test"
}

@test "prepare_upgrade_branch: creates the upgrade branch from the given base, not from the current branch" {
    _lock_repo
    git -C "$BATS_TEST_TMPDIR/repo" switch -q -c feature
    echo change > "$BATS_TEST_TMPDIR/repo/feature.txt"
    git -C "$BATS_TEST_TMPDIR/repo" add -A && git -C "$BATS_TEST_TMPDIR/repo" commit -q -m "feature work"
    git -C "$BATS_TEST_TMPDIR/repo" branch -q -f main HEAD~1
    run env HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        source '$_src_dir/update-packages.repos.sh'
        prepare_upgrade_branch '$BATS_TEST_TMPDIR/repo' deps/update-packages-test main
    "
    assert_success
    run git -C "$BATS_TEST_TMPDIR/repo" log --oneline -1 --format=%s
    assert_output "init"
}

@test "merge_back_to_starting_branch: fast-forwards the starting branch and deletes the upgrade branch" {
    _lock_repo
    git -C "$BATS_TEST_TMPDIR/repo" switch -q -c deps/update-packages-test
    echo change > "$BATS_TEST_TMPDIR/repo/up.txt"
    git -C "$BATS_TEST_TMPDIR/repo" add -A && git -C "$BATS_TEST_TMPDIR/repo" commit -q -m "upgrade"
    run env HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        source '$_src_dir/update-packages.repos.sh'
        merge_back_to_starting_branch '$BATS_TEST_TMPDIR/repo' main deps/update-packages-test
    "
    assert_success
    run git -C "$BATS_TEST_TMPDIR/repo" branch --show-current
    assert_output "main"
    run git -C "$BATS_TEST_TMPDIR/repo" log --oneline -1 --format=%s
    assert_output "upgrade"
    run git -C "$BATS_TEST_TMPDIR/repo" branch --list 'deps/*'
    assert_output ""
}
