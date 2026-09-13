#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/publish-package.sh, as it behaves TODAY.
#
# Was previously broken (crashed on every invocation): line 77 read
# `version=${properties["Version"]}`, but dotnet_pack's returned associative array key is
# "PackageVersion" -- since "Version" was never set, this crashed with "unbound variable" under
# set -u. Fixed to `properties["PackageVersion"]`; this file now exercises the real (working)
# behavior end to end.
#
# Real `dotnet` is faked exactly as in pack.sh's tests (pack/msbuild/nuget subcommands), with
# matching pre-created .nupkg/.snupkg files.

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

# --- happy path ---------------------------------------------------------------------------

@test "publish-package: with an API key, pushes to NuGet.org and reports the release summary" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" 'NUGET_API_KEY=secret' src/App/App.csproj
    assert_success
    assert_output --partial "were released to NuGet.org"
    assert_output --partial "App.1.2.3.nupkg"
    assert_output --partial "Stable release of App"

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    assert_output --partial "nuget push"
    assert_output --partial "--source https://api.nuget.org/v3/index.json"
    assert_output --partial "--api-key secret"
}

@test "publish-package: without an API key, does NOT push and says so in the summary" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" '' src/App/App.csproj
    assert_success
    assert_output --partial "were **NOT** released to NuGet.org"

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    refute_output --partial "nuget push"
}

@test "publish-package: --nuget-server github pushes to GitHub Packages under the given --repo-owner" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" 'NUGET_API_KEY=secret' --nuget-server github --repo-owner acme src/App/App.csproj
    assert_success
    assert_output --partial "were released to GitHub Packages"

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    assert_output --partial "--source https://nuget.pkg.github.com/acme/index.json"
}

@test "publish-package: a prerelease package version gets the pre-release summary header and default reason" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo" App "1.2.3-preview.1"
    run _run_publish "$BATS_TEST_TMPDIR/repo" 'NUGET_API_KEY=secret' src/App/App.csproj
    assert_success
    assert_output --partial "Pre-release Summary"
    assert_output --partial "Pre-release of App"
}

@test "publish-package: an explicit --reason overrides the default" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" 'NUGET_API_KEY=secret' --reason "'custom reason'" src/App/App.csproj
    assert_success
    assert_output --partial "custom reason"
}

# --- validation failures ---------------------------------------------------------------------

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

@test "publish-package: reports a failed NuGet push" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_publish "$BATS_TEST_TMPDIR/repo" 'NUGET_API_KEY=secret FAKE_DOTNET_NUGET_EXIT=1' src/App/App.csproj
    assert_failure
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

# --- CI parity ------------------------------------------------------------------------------

@test "publish-package: in CI mode, the release summary also lands in the step summary file" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/repo/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$BATS_TEST_TMPDIR/repo/dotnet.log" NUGET_API_KEY=secret \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_publish_package' --quiet src/App/App.csproj"
    assert_success

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "were released to NuGet.org"
}
