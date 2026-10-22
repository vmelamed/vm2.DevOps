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
declare -gxi err_invalid_item
declare -gxi err_tool_error
declare -gxi err_not_found
declare -gxi err_logic_error

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

@test "read_package_versions: accepts any whitespace (spaces, tabs) between the element's parts" {
    printf '<Project>\n  <ItemGroup>\n    <PackageVersion  Include="A.Pkg"\tVersion="1.2.3"   />\n  </ItemGroup>\n</Project>\n' \
        > "$BATS_TEST_TMPDIR/Directory.Packages.props"
    run _up "declare -A v=(); read_package_versions '$BATS_TEST_TMPDIR/Directory.Packages.props' repo v; declare -p v"
    assert_success
    assert_output --partial '[A.Pkg]="1.2.3"'
}

# --- validate_package_lines ------------------------------------------------------------------------

@test "validate_package_lines: succeeds when every PackageVersion line has the supported one-line shape" {
    _props_fixture "$BATS_TEST_TMPDIR/Directory.Packages.props"
    run _up "validate_package_lines '$BATS_TEST_TMPDIR/Directory.Packages.props'"
    assert_success
}

@test "validate_package_lines: rejects a multi-line element, naming the file and line, instead of skipping it" {
    cat > "$BATS_TEST_TMPDIR/Directory.Packages.props" <<'XML'
<Project>
    <ItemGroup>
        <PackageVersion
            Include="Multi.Line" Version="1.0.0" />
    </ItemGroup>
</Project>
XML
    run _up "validate_package_lines '$BATS_TEST_TMPDIR/Directory.Packages.props'"
    assert_failure "$err_invalid_item"
    assert_output --partial "Directory.Packages.props:3: unsupported PackageVersion format"
}

@test "validate_package_lines: rejects Version before Include, and reports EVERY offending line" {
    cat > "$BATS_TEST_TMPDIR/Directory.Packages.props" <<'XML'
<Project>
    <ItemGroup>
        <PackageVersion Version="1.0.0" Include="Reversed.One" />
        <PackageVersion Include="Fine" Version="2.0.0" />
        <PackageVersion Include='Single.Quotes' Version='3.0.0' />
    </ItemGroup>
</Project>
XML
    run _up "validate_package_lines '$BATS_TEST_TMPDIR/Directory.Packages.props'"
    assert_failure "$err_invalid_item"
    assert_output --partial "Directory.Packages.props:3:"
    assert_output --partial "Directory.Packages.props:5:"
    refute_output --partial "Directory.Packages.props:4:"
}

@test "validate_package_lines: ignores commented-out PackageVersion lines, like the reader does" {
    printf '<Project>\n  <ItemGroup>\n    <!-- <PackageVersion Version="1" Include="Ignored" /> -->\n  </ItemGroup>\n</Project>\n' \
        > "$BATS_TEST_TMPDIR/Directory.Packages.props"
    run _up "validate_package_lines '$BATS_TEST_TMPDIR/Directory.Packages.props'"
    assert_success
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
    echo '<Solution />' > "$_repo/repo.slnx"
    echo '<Project />' > "$_repo/src/App/App.csproj"
    echo '{"version":1,"old":true}' > "$_repo/src/App/packages.lock.json"
    git -C "$_repo" add -A && git -C "$_repo" commit -q -m init
    # Mirrors real 'dotnet restore <solution>' (as called by dotnet_restore): it regenerates a lock file only for a
    # project that still exists, never for one whose project was removed. Every restored solution is logged, so the
    # tests can check which ones were restored.
    cat > "$BATS_TEST_TMPDIR/bin/dotnet" <<'FAKE'
#!/usr/bin/env bash
[[ $1 == restore ]] || exit 0
echo "$2" >> "${BATS_TEST_TMPDIR:-/tmp}/restored.txt"
case $2 in
    *.slnx|*.sln ) _app="$(dirname "$2")/src/App" ;;   # the solution lists src/App/App.csproj
    *.csproj     ) _app=$(dirname "$2") ;;              # a single project: its lock file goes next to it
esac
[[ -f $_app/App.csproj ]] && echo '{"version":1,"regenerated":true}' > "$_app/packages.lock.json"
exit 0
FAKE
    chmod +x "$BATS_TEST_TMPDIR/bin/dotnet"
}

_refresh() {
    run env PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" HOME="$HOME" BATS_TEST_TMPDIR="$BATS_TEST_TMPDIR" bash -c "
        export PATH='$BATS_TEST_TMPDIR/bin':\"\$PATH\"
        source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        source '$_src_dir/update-packages.repos.sh'
        ${REFRESH_DRY_RUN:+set_dry_run}
        refresh_lock_files '$BATS_TEST_TMPDIR/repo'
    "
}

@test "refresh_lock_files: restores every project, nested ones included, and not the solution" {
    _lock_repo
    mkdir -p "$BATS_TEST_TMPDIR/repo/tests/T"
    echo '<Project />' > "$BATS_TEST_TMPDIR/repo/tests/T/T.csproj"
    _refresh
    assert_success
    # find_files_by_precedence does not sort, so neither does the restore order: compare as a set
    run sort "$BATS_TEST_TMPDIR/restored.txt"
    assert_output "$BATS_TEST_TMPDIR/repo/src/App/App.csproj"$'\n'"$BATS_TEST_TMPDIR/repo/tests/T/T.csproj"
    run cat "$BATS_TEST_TMPDIR/repo/src/App/packages.lock.json"
    assert_output --partial '"regenerated":true'
}

@test "refresh_lock_files: skips projects under 'templates', 'bin', and 'obj' directories" {
    _lock_repo
    mkdir -p "$BATS_TEST_TMPDIR/repo/templates/T/content/src/P" "$BATS_TEST_TMPDIR/repo/src/App/bin" "$BATS_TEST_TMPDIR/repo/src/App/obj"
    echo '<Project />' > "$BATS_TEST_TMPDIR/repo/templates/T/content/src/P/P.csproj"
    echo '<Project />' > "$BATS_TEST_TMPDIR/repo/src/App/bin/Copied.csproj"
    echo '<Project />' > "$BATS_TEST_TMPDIR/repo/src/App/obj/Generated.csproj"
    _refresh
    assert_success
    run cat "$BATS_TEST_TMPDIR/restored.txt"
    assert_output "$BATS_TEST_TMPDIR/repo/src/App/App.csproj"
}

@test "refresh_lock_files: fails with err_not_found, restoring nothing, when the repository has no projects" {
    _lock_repo
    rm "$BATS_TEST_TMPDIR/repo/src/App/App.csproj"
    _refresh
    assert_failure "$err_not_found"
    [[ ! -e "$BATS_TEST_TMPDIR/restored.txt" ]]
}

@test "refresh_lock_files: in dry-run mode, restores nothing and reports the restore" {
    _lock_repo
    REFRESH_DRY_RUN=1 _refresh
    assert_success
    assert_output --partial "dry-run\$ dotnet restore"
    run cat "$BATS_TEST_TMPDIR/repo/src/App/packages.lock.json"
    assert_output '{"version":1,"old":true}'
    [[ ! -e "$BATS_TEST_TMPDIR/restored.txt" ]]
}

@test "refresh_lock_files: regenerates the lock file in place and commits nothing" {
    _lock_repo
    _refresh
    assert_success
    run git -C "$BATS_TEST_TMPDIR/repo" log --oneline
    refute_output --partial "refresh packages.lock.json"
    run cat "$BATS_TEST_TMPDIR/repo/src/App/packages.lock.json"
    assert_output --partial '"regenerated":true'
}

@test "refresh_lock_files: regenerates lock files even when they had uncommitted changes" {
    _lock_repo
    echo '{"local-edit":true}' > "$BATS_TEST_TMPDIR/repo/src/App/packages.lock.json"
    _refresh
    assert_success
    run cat "$BATS_TEST_TMPDIR/repo/src/App/packages.lock.json"
    assert_output --partial '"regenerated":true'
}

@test "refresh_lock_files: a repository without lock files is left without any" {
    _lock_repo
    # Replace the project with one that does not use a lock file (the fake 'dotnet' writes one only for App.csproj):
    # deleting every project instead would now fail with err_not_found -- see the test above.
    git -C "$BATS_TEST_TMPDIR/repo" rm -q -r src/App
    mkdir -p "$BATS_TEST_TMPDIR/repo/src/Lib" && echo '<Project />' > "$BATS_TEST_TMPDIR/repo/src/Lib/Lib.csproj"
    git -C "$BATS_TEST_TMPDIR/repo" add -A && git -C "$BATS_TEST_TMPDIR/repo" commit -q -m "a project without a lock file"
    _refresh
    assert_success
    run git -C "$BATS_TEST_TMPDIR/repo" status --porcelain
    assert_output ""
}


# --- classify_repo ----------------------------------------------------------------------------------

# A clone of a bare 'origin', on 'main' and identical to it.
_clone_repo() {
    local _bare="$BATS_TEST_TMPDIR/origin.git" _repo="$BATS_TEST_TMPDIR/clone"
    git init -q --bare -b main "$_bare"
    git init -q -b main "$BATS_TEST_TMPDIR/seed"
    git -C "$BATS_TEST_TMPDIR/seed" config user.email test@example.invalid
    git -C "$BATS_TEST_TMPDIR/seed" config user.name test
    echo one > "$BATS_TEST_TMPDIR/seed/file.txt"
    git -C "$BATS_TEST_TMPDIR/seed" add -A && git -C "$BATS_TEST_TMPDIR/seed" commit -q -m init
    git -C "$BATS_TEST_TMPDIR/seed" push -q "$_bare" main
    git clone -q "$_bare" "$_repo"
    git -C "$_repo" config user.email test@example.invalid
    git -C "$_repo" config user.name test
}

_classify() {
    run env HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        source '$_src_dir/update-packages.repos.sh'
        classify_repo '$BATS_TEST_TMPDIR/clone' m r; echo \"\$m\"
    "
}

@test "classify_repo: publish for a clean repository on main, identical to origin/main" {
    _clone_repo
    _classify
    assert_success
    assert_output "publish"
}

@test "classify_repo: skip when there are uncommitted changes" {
    _clone_repo
    echo dirty >> "$BATS_TEST_TMPDIR/clone/file.txt"
    _classify
    assert_output "skip"
}

@test "classify_repo: inplace when the current branch is not main" {
    _clone_repo
    git -C "$BATS_TEST_TMPDIR/clone" switch -q -c feature
    _classify
    assert_output "inplace"
}

@test "classify_repo: inplace when main has a local commit that origin does not have" {
    _clone_repo
    echo two > "$BATS_TEST_TMPDIR/clone/other.txt"
    git -C "$BATS_TEST_TMPDIR/clone" add -A && git -C "$BATS_TEST_TMPDIR/clone" commit -q -m local
    _classify
    assert_output "inplace"
}

@test "classify_repo: inplace when there is no origin remote" {
    _clone_repo
    git -C "$BATS_TEST_TMPDIR/clone" remote remove origin
    _classify
    assert_output "inplace"
}

# --- start_publish_branch -----------------------------------------------------------------------

@test "start_publish_branch: creates the upgrade branch from the current HEAD" {
    _clone_repo
    run env HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap >/dev/null 2>&1
        source '$_src_dir/update-packages.functions.sh'
        source '$_src_dir/update-packages.repos.sh'
        start_publish_branch '$BATS_TEST_TMPDIR/clone' deps/update-packages-test
    "
    assert_success
    run git -C "$BATS_TEST_TMPDIR/clone" branch --show-current
    assert_output "deps/update-packages-test"
}
