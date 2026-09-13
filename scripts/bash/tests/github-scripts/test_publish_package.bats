#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/publish-package.sh, as it behaves TODAY.
#
# KNOWN BUG (reported, deliberately left unfixed for now -- see "documents a known crash"
# below): line 77 reads `version=${properties["Version"]}`, but dotnet_pack's returned
# associative array key is "PackageVersion" (confirmed correct in pack.sh, which reads
# `_pack_properties[PackageVersion]`). Since "Version" is never set, this crashes with an
# "unbound variable" error under set -u on EVERY invocation that reaches that line -- i.e. the
# script currently cannot successfully publish anything. Only the argument-parsing and
# early-validation paths (which run before that line) are otherwise testable right now.
#
# Real `dotnet` is faked exactly as in pack.sh's tests (pack/msbuild/nuget subcommands), with
# matching pre-created .nupkg/.snupkg files -- reused here only for the crash-documentation
# test, since nothing past the crash point is currently reachable.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_publish_package="$_gh_scripts_dir/publish-package.sh"

_install_fake_dotnet_and_package() {
    local _dir="$1"
    local _id="${2:-App}"
    local _version="${3:-1.2.3}"
    mkdir -p "$_dir/fakebin" "$_dir/pkgout"
    echo fake > "$_dir/pkgout/$_id.$_version.nupkg"
    echo fake > "$_dir/pkgout/$_id.$_version.snupkg"

    cat > "$_dir/fakebin/dotnet" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "\$DOTNET_CALL_LOG"
case "\$1" in
    pack)  exit 0 ;;
    nuget) exit "\${FAKE_DOTNET_NUGET_EXIT:-0}" ;;
    msbuild)
        echo "PackageOutputPath=$_dir/pkgout"
        echo "PackageId=$_id"
        echo "PackageVersion=$_version"
        exit 0
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$_dir/fakebin/dotnet"
}

_make_repo_with_project() {
    local _dir="$1"
    mkdir -p "$_dir/src/App"
    git -C "$_dir" init --quiet
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo '<Project />' > "$_dir/src/App/App.csproj"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "init"
}

# $1 = repo dir, $2 = env-var assignments to prepend, $@ (rest) = CLI arguments.
_run_publish() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="$_dir/fakebin:/usr/local/bin:/usr/bin:/bin" DOTNET_CALL_LOG="$_dir/dotnet.log" bash -c "
        cd '$_dir' && $_env_vars bash '$_publish_package' $*
    "
}

# --- known bug, documented -------------------------------------------------------------------

@test "publish-package: documents a known crash -- properties[Version] should be properties[PackageVersion]" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' src/App/App.csproj
    assert_failure
    assert_output --partial 'properties["Version"]: unbound variable'
}

# --- validation failures (run before the crash point, so these work today) -------------------

@test "publish-package: rejects a package project path that does not exist" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' does-not-exist.csproj
    assert_failure
}

@test "publish-package: rejects a non-.csproj package project (e.g. a solution)" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    touch "$BATS_TEST_TMPDIR/repo/App.sln"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' App.sln
    assert_failure
    assert_output --partial "accepts only project files (*.csproj)"
}

@test "publish-package: rejects an unsafe --reason value" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' --reason "'-hack'" src/App/App.csproj
    assert_failure
}

@test "publish-package: rejects an invalid --nuget-server moniker" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' --nuget-server bogus src/App/App.csproj
    assert_failure
    assert_output --partial "Invalid NuGet server: bogus"
}

# --- argument handling ---------------------------------------------------------------------

@test "publish-package: fails when more than one package project is given" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' src/App/App.csproj Other.csproj
    assert_failure
    assert_output --partial "Multiple package projects specified"
}

@test "publish-package: fails with a clear error when a value-taking option is given without a value" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' --reason
    assert_failure
    assert_output --partial "Missing value for --reason"
}

@test "publish-package: fails on an unknown option" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' --bogus
    assert_failure
    assert_output --partial "Unknown option: --bogus"
}

@test "publish-package: -h prints usage and exits 0" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' -h
    assert_success
    assert_output --partial "Usage:"
}
