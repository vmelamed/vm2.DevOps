#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/pack.sh, as it behaves TODAY.
#
# pack.sh is designed to run identically standalone and in GitHub Actions (it sources
# gh_core.sh) -- these tests run it the same way in both "modes", with one test explicitly
# setting the CI variables to confirm the summary lands there too.
#
# Real `dotnet` is faked: it logs every invocation to $DOTNET_CALL_LOG. Its `msbuild` case
# branches on the arguments: a `-getProperty:TargetPath` call (used by pack.sh's own
# already-built check, via get_target_path) prints $FAKE_TARGET_PATH; a `-getProperty:Configuration`
# call (dotnet_pack() resolving the project's actual Configuration before packing, since
# 'dotnet pack' on its own defaults to Release while 'dotnet build'/'dotnet msbuild' default to
# Debug) prints "Release"; any other `msbuild` call (dotnet_pack reading back
# PackageOutputPath/PackageId/PackageVersion) prints those three properties from $_id/$_version.
# The fixture pre-creates the matching .nupkg/.snupkg files, and an already-built
# $FAKE_TARGET_PATH, exactly as pack.sh expects to find them without rebuilding.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_pack="$_gh_scripts_dir/pack.sh"

# Installs the fake dotnet and pre-creates the package output the fake `dotnet msbuild` call
# will report -- so dotnet_pack's own "package file exists and is non-empty" check succeeds.
_install_fake_dotnet_and_package() {
    local _dir="$1"
    local _id="${2:-App}"
    local _version="${3:-1.2.3}"
    mkdir -p "$_dir/fakebin" "$_dir/pkgout"
    echo fake > "$_dir/pkgout/$_id.$_version.nupkg"
    echo fake > "$_dir/pkgout/$_id.$_version.snupkg"

    # Default: report an already-built target, so happy-path tests don't trigger pack.sh's
    # auto-build fallback. Tests exercising that fallback override FAKE_TARGET_PATH themselves.
    echo fake > "$_dir/App.dll"

    cat > "$_dir/fakebin/dotnet" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "\$DOTNET_CALL_LOG"
case "\$1" in
    pack)    exit "\${FAKE_DOTNET_PACK_EXIT:-0}" ;;
    clean)   exit "\${FAKE_DOTNET_CLEAN_EXIT:-0}" ;;
    restore) exit "\${FAKE_DOTNET_RESTORE_EXIT:-0}" ;;
    build)   exit "\${FAKE_DOTNET_BUILD_EXIT:-0}" ;;
    msbuild)
        case "\$*" in
            *-getProperty:TargetPath*)
                echo "\${FAKE_TARGET_PATH:-$_dir/App.dll}"
                ;;
            *-getProperty:ArtifactsPath*)
                # sanitize_common_dotnet_args' own real-MSBuild ArtifactsPath evaluation
                # (via get_artifacts_path): a single property value, like -getProperty:TargetPath.
                echo "$_dir/artifacts"
                ;;
            *-getProperty:Configuration*)
                # dotnet_pack()'s own pre-pack Configuration resolution (see file header comment).
                echo "Release"
                ;;
            *)
                echo "PackageOutputPath=$_dir/pkgout"
                echo "PackageId=$_id"
                echo "PackageVersion=$_version"
                ;;
        esac
        exit "\${FAKE_DOTNET_MSBUILD_EXIT:-0}"
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
_run_pack() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="$_dir/fakebin:/usr/local/bin:/usr/bin:/bin" DOTNET_CALL_LOG="$_dir/dotnet.log" bash -c "
        cd '$_dir' && $_env_vars bash '$_pack' $*
    "
}

# --- happy path ---------------------------------------------------------------------------

@test "pack: packs the given project and reports the package properties" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' src/App/App.csproj
    assert_success
    assert_output --partial "Packages Built Successfully"
    assert_output --partial "App.1.2.3.nupkg"
    assert_output --partial "App.1.2.3.snupkg"
    assert_output --partial "v1.2.3"

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    # index 0 is the real-MSBuild ArtifactsPath evaluation from sanitize_common_dotnet_args.
    assert_line --index 1 --partial "-getProperty:TargetPath"
    assert_line --index 2 --partial "-getProperty:Configuration"
    assert_line --index 3 --partial "pack src/App/App.csproj"
    refute_output --partial "restore"
    refute_output --partial "^build "
}

@test "pack: attempts a build before packing when the target output is missing (e.g. --skip-build-cache), and reports if it is still not found" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    # deliberately do NOT create the target file -- FAKE_TARGET_PATH points nowhere, and the fake
    # `dotnet build` (like the real one, here) never creates it either.
    run _run_pack "$BATS_TEST_TMPDIR/repo" "FAKE_TARGET_PATH=$BATS_TEST_TMPDIR/repo/does-not-exist.dll" src/App/App.csproj
    assert_failure
    assert_output --partial "was not found in the artifacts directory. Building the project before packing"
    assert_output --partial "still NOT FOUND"

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    # index 0 is the real-MSBuild ArtifactsPath evaluation from sanitize_common_dotnet_args.
    assert_line --index 1 --partial "-getProperty:TargetPath"
    assert_line --index 2 --partial "clean src/App/App.csproj"
    assert_line --index 3 --partial "restore src/App/App.csproj"
    assert_line --index 4 --partial "build src/App/App.csproj"
    refute_output --partial "pack src/App/App.csproj"
}

@test "pack: --build true cleans, restores, and builds before packing" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' --build true src/App/App.csproj
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    # index 0 is the real-MSBuild ArtifactsPath evaluation from sanitize_common_dotnet_args.
    assert_line --index 1 --partial "-getProperty:TargetPath"
    assert_line --index 2 --partial "clean src/App/App.csproj"
    assert_line --index 3 --partial "restore src/App/App.csproj"
    assert_line --index 4 --partial "build src/App/App.csproj"
    assert_line --index 5 --partial "-getProperty:Configuration"
    assert_line --index 6 --partial "pack src/App/App.csproj"
}

@test "pack: --reason is included as a package release note and reflected in the summary" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' --reason "'test release'" src/App/App.csproj
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/dotnet.log"
    assert_output --partial 'PackageReleaseNotes="test release"'
}

# --- validation failures ---------------------------------------------------------------------

@test "pack: rejects a package project path that does not exist" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' does-not-exist.csproj
    assert_failure
}

@test "pack: rejects a non-.csproj package project (e.g. a solution)" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    touch "$BATS_TEST_TMPDIR/repo/App.sln"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' App.sln
    assert_failure
    assert_output --partial "accepts only project files (*.csproj)"
}

@test "pack: rejects an unsafe --reason value" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' --reason '-hack' src/App/App.csproj
    assert_failure
}

@test "pack: rejects an invalid --build value instead of silently ignoring it" {
    # KNOWN REAL BUG (reported to Val, not fixed here -- see summary): _diagnostics.sh's
    # top-level '__summary_output' resolution block (added this session) calls is_tool_present(),
    # which calls exit_if_has_bugs() -- but that function is defined LATER in the same file, so
    # under $ci=false (any non-CI run) every script sourcing core.sh prints a spurious
    # "exit_if_has_bugs: command not found" to stderr. Harmless to control flow (it's inside an
    # 'if' condition, so `set -e` doesn't propagate it) but it pollutes real script output.
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' --build maybe src/App/App.csproj
    assert_failure
    assert_output --partial "not a valid boolean"
}

@test "pack: fails when the produced package files are missing" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    mkdir -p "$BATS_TEST_TMPDIR/repo/fakebin"
    echo fake > "$BATS_TEST_TMPDIR/repo/App.dll"
    cat > "$BATS_TEST_TMPDIR/repo/fakebin/dotnet" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "\$DOTNET_CALL_LOG"
case "\$1" in
    pack) exit 0 ;;
    msbuild)
        case "\$*" in
            *-getProperty:TargetPath*)
                echo "$BATS_TEST_TMPDIR/repo/App.dll"
                ;;
            *-getProperty:ArtifactsPath*)
                # sanitize_common_dotnet_args' own real-MSBuild ArtifactsPath evaluation
                # (via get_artifacts_path): a single property value, like -getProperty:TargetPath.
                echo "$BATS_TEST_TMPDIR/repo/artifacts"
                ;;
            *)
                echo "PackageOutputPath=$BATS_TEST_TMPDIR/repo/nonexistent"
                echo "PackageId=App"
                echo "PackageVersion=1.2.3"
                ;;
        esac
        exit 0
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/repo/fakebin/dotnet"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' src/App/App.csproj
    assert_failure
    assert_output --partial "not found or empty"
}

# --- argument handling ---------------------------------------------------------------------

@test "pack: fails when more than one package project is given" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' src/App/App.csproj Other.csproj
    assert_failure
    assert_output --partial "Multiple package projects specified"
}

@test "pack: fails on an unknown option" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' --bogus
    assert_failure
    assert_output --partial "Unknown option: --bogus"
}

@test "pack: -h prints usage and exits 0" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run _run_pack "$BATS_TEST_TMPDIR/repo" '' -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "pack: in CI mode, the package summary also lands in the step summary file" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/repo/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$BATS_TEST_TMPDIR/repo/dotnet.log" \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_pack' --quiet src/App/App.csproj"
    assert_success

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "Packages Built Successfully"
    assert_output --partial "App.1.2.3.nupkg"
}

@test "pack: reports the resolved package output directory as an output" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet_and_package "$BATS_TEST_TMPDIR/repo"
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/repo/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$BATS_TEST_TMPDIR/repo/dotnet.log" \
        GITHUB_ACTIONS=true GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output.txt" \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_pack' --quiet src/App/App.csproj"
    assert_success

    run cat "$BATS_TEST_TMPDIR/output.txt"
    assert_output --partial "package-output-path=$BATS_TEST_TMPDIR/repo/pkgout"
}
