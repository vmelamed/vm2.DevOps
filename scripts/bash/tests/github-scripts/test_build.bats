#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/build.sh, as it behaves TODAY.
#
# build.sh is designed to run identically standalone and in GitHub Actions (it sources
# gh_core.sh) -- these tests run it the same way in both "modes": every test runs under a clean
# 'env -i HOME="$HOME" PATH=...', and one test explicitly sets the CI variables to confirm the
# same output also lands there.
#
# build.sh's own logic (argument handling, path safety, auto-detecting a project file, and the
# clean/restore/build orchestration) is exercised against a FAKE `dotnet` executable that logs
# every invocation to $DOTNET_CALL_LOG and returns a controllable exit code per subcommand (via
# FAKE_DOTNET_<SUBCOMMAND>_EXIT env vars) -- real `dotnet build` is Microsoft's problem to test,
# not build.sh's; build.sh's job is only to invoke it correctly and propagate results.
#
# get_artifacts_path (reached via sanitize_common_dotnet_args) needs a real Git working tree,
# so every fixture directory is a real (local-only) git repo.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_build="$_gh_scripts_dir/build.sh"

_install_fake_dotnet() {
    local _dir="$1/fakebin"
    mkdir -p "$_dir"
    cat > "$_dir/dotnet" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$DOTNET_CALL_LOG"
case "$1" in
    nuget)   exit "${FAKE_DOTNET_NUGET_EXIT:-0}" ;;
    clean)   exit "${FAKE_DOTNET_CLEAN_EXIT:-0}" ;;
    restore) exit "${FAKE_DOTNET_RESTORE_EXIT:-0}" ;;
    build)
        echo "Build succeeded."
        exit "${FAKE_DOTNET_BUILD_EXIT:-0}"
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$_dir/dotnet"
}

_make_repo_with_project() {
    local _dir="$1"
    mkdir -p "$_dir"
    git -C "$_dir" init --quiet
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo '<Project />' > "$_dir/App.csproj"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "init"
}

# $1 = repo dir, $2 = env-var assignments to prepend (e.g. "FAKE_DOTNET_CLEAN_EXIT=1"), $@ (rest)
# = CLI arguments.
_run_build() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="$_dir/fakebin:/usr/local/bin:/usr/bin:/bin" DOTNET_CALL_LOG="$_dir/calls.log" bash -c "
        cd '$_dir' && $_env_vars bash '$_build' $*
    "
}

# --- happy path ---------------------------------------------------------------------------

@test "build: cleans, restores, and builds the given project, in order" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" '' App.csproj
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    assert_line --index 0 --partial "clean App.csproj"
    assert_line --index 1 --partial "restore App.csproj"
    assert_line --index 2 --partial "build App.csproj"
}

@test "build: auto-detects the sole project file in the current directory when none is given" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" ''
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    assert_line --index 0 --partial "clean ./App.csproj"
}

@test "build: \$BUILD_PROJECT provides the project when no positional argument is given" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    mv "$BATS_TEST_TMPDIR/repo/App.csproj" "$BATS_TEST_TMPDIR/repo/Other.csproj"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" 'BUILD_PROJECT=Other.csproj'
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    assert_line --index 0 --partial "clean Other.csproj"
}

@test "build: a positional argument overrides \$BUILD_PROJECT" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" 'BUILD_PROJECT=does-not-exist.csproj' App.csproj
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    assert_line --index 0 --partial "clean App.csproj"
}

@test "build: passes common dotnet arguments (e.g. --configuration) through to dotnet" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" '' --configuration Release App.csproj
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    assert_line --index 0 --partial "--configuration Release"
    assert_line --index 2 --partial "--configuration Release"
}

@test "build: updates the GitHub NuGet source when credentials are provided" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" 'GH_ACTOR=me GH_TOKEN=tok' App.csproj
    assert_success

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    assert_line --index 0 --partial "nuget update source github.vm2"
}

@test "build: warns but still succeeds when no NuGet credentials are provided" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" '' App.csproj
    assert_success
    assert_output --partial "GitHub NuGet source credentials are not provided"

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    refute_line --partial "nuget update source"
}

# --- failures --------------------------------------------------------------------------------

@test "build: no project given and none found in the current directory fails with a clear error" {
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/empty"
    run _run_build "$BATS_TEST_TMPDIR/empty" ''
    assert_failure
    assert_output --partial "No build project (*.slnx, *.sln, *.csproj) was specified or found"
}

@test "build: an unsafe (path-traversal) project path fails cleanly, without crashing" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" '' '../evil.csproj'
    assert_failure
    assert_output --partial "contains directory traversal sequences"
    refute_output --partial "BUG"

    [[ ! -e "$BATS_TEST_TMPDIR/repo/calls.log" ]]
}

@test "build: reports a failed clean, and still attempts restore and build" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" 'FAKE_DOTNET_CLEAN_EXIT=1' App.csproj
    assert_failure
    assert_output --partial "Cleaning the build project failed"

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    assert_line --index 0 --partial "clean App.csproj"
    assert_line --index 1 --partial "restore App.csproj"
    assert_line --index 2 --partial "build App.csproj"
}

@test "build: reports a failed restore, and still attempts build" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" 'FAKE_DOTNET_RESTORE_EXIT=1' App.csproj
    assert_failure
    assert_output --partial "Restoring the build project failed"

    run cat "$BATS_TEST_TMPDIR/repo/calls.log"
    assert_line --index 2 --partial "build App.csproj"
}

@test "build: reports a failed build" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" 'FAKE_DOTNET_BUILD_EXIT=1' App.csproj
    assert_failure
    assert_output --partial "Building the build project failed"
}

# --- argument handling ---------------------------------------------------------------------

@test "build: fails when more than one project is given" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" '' App.csproj Other.csproj
    assert_failure
    assert_output --partial "Multiple build projects specified"
}

@test "build: fails on an unknown option" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" '' --bogus
    assert_failure
    assert_output --partial "Unknown option: --bogus"
}

@test "build: -h prints usage and exits 0" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run _run_build "$BATS_TEST_TMPDIR/repo" '' -h
    assert_success
    assert_output --partial "Usage:"
}

# --- CI parity ------------------------------------------------------------------------------

@test "build: in CI mode, the build summary also lands in the step summary file" {
    _make_repo_with_project "$BATS_TEST_TMPDIR/repo"
    _install_fake_dotnet "$BATS_TEST_TMPDIR/repo"
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/repo/fakebin:/usr/local/bin:/usr/bin:/bin" \
        DOTNET_CALL_LOG="$BATS_TEST_TMPDIR/repo/calls.log" \
        GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_build' --quiet App.csproj"
    assert_success
    assert_output --partial "Build Summary"

    run cat "$BATS_TEST_TMPDIR/summary.md"
    assert_output --partial "Build Summary"
}
