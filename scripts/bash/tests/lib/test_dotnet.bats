#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_dotnet.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.
#
# The happy paths of dotnet_clean/dotnet_restore/dotnet_build/dotnet_pack (which invoke the real
# `dotnet` CLI) are exercised end-to-end separately, via build.sh/pack.sh against a real vm2
# package. Here we cover the pure-logic functions in full, and only the formal argument
# validation (bug-exit) of the dotnet-invoking functions.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

setup() {
    _fake_csproj="$BATS_TEST_TMPDIR/fake.csproj"
    echo "<Project />" > "$_fake_csproj"
}

# --- get_dotnet_error_message --------------------------------------------------------------

@test "get_dotnet_error_message: returns the message for a known dotnet exit code" {
    run get_dotnet_error_message 0
    assert_success
    assert_output "0: Build succeeded; no errors or warnings were reported"
    run get_dotnet_error_message 1
    assert_output "1: Unknown error or catch-all error; check the build output for details"
}

@test "get_dotnet_error_message: falls back to the unknown-code message" {
    run get_dotnet_error_message 999
    assert_success
    assert_output "999: Unknown dotnet error code"
}

@test "get_dotnet_error_message: bug-exits on a negative or missing argument" {
    run get_dotnet_error_message
    assert_failure 254
    run get_dotnet_error_message -1
    assert_failure 254
}

# --- convert_dotnet_args_to_msbuild_args -------------------------------------------------------

@test "convert_dotnet_args_to_msbuild_args: converts known options and passes the project through" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a msb=(); convert_dotnet_args_to_msbuild_args msb proj.csproj --configuration Release -c Debug --self-contained; printf '%s\n' \"\${msb[@]}\""
    assert_success
    assert_line --index 0 "proj.csproj"
    assert_line --index 1 '-property:Configuration="Release"'
    assert_line --index 2 '-property:Configuration="Debug"'
    assert_line --index 3 "-property:SelfContained=true"
}

@test "convert_dotnet_args_to_msbuild_args: drops @remove-mapped options like --no-build" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a msb=(); convert_dotnet_args_to_msbuild_args msb proj.csproj --no-build --no-restore; printf '%s\n' \"\${msb[@]}\""
    assert_success
    assert_output "proj.csproj"
}

@test "convert_dotnet_args_to_msbuild_args: passes an unrecognized option through unchanged" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a msb=(); convert_dotnet_args_to_msbuild_args msb proj.csproj --some-unknown-flag; printf '%s\n' \"\${msb[@]}\""
    assert_success
    assert_line --index 1 "--some-unknown-flag"
}

@test "convert_dotnet_args_to_msbuild_args: fails on the removed --os/--arch options" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a msb=(); convert_dotnet_args_to_msbuild_args msb proj.csproj --os linux"
    assert_failure 3
}

@test "convert_dotnet_args_to_msbuild_args: fails when an option requiring a value is given last" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a msb=(); convert_dotnet_args_to_msbuild_args msb proj.csproj --configuration"
    assert_failure 6
}

@test "convert_dotnet_args_to_msbuild_args: bug-exits with fewer than two arguments" {
    run convert_dotnet_args_to_msbuild_args
    assert_failure 254
}

# --- extract_dotnet_build_info --------------------------------------------------------------

@test "extract_dotnet_build_info: parses properties, result, warnings, and errors from build output" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        declare -A info=()
        extract_dotnet_build_info '$_fake_csproj' 0 info <<'EOF'
  Configuration=Release
  TargetFramework=net10.0
  Version=1.2.3
    1 Warning(s)
    0 Error(s)
Build succeeded.
EOF
        echo \"result=\${info[build_result]}\"
        echo \"config=\${info[Configuration]}\"
        echo \"tfm=\${info[TargetFramework]}\"
        echo \"version=\${info[Version]}\"
        echo \"warnings=\${info[warnings_count]}\"
        echo \"errors=\${info[errors_count]}\"
    "
    assert_success
    assert_line "result=succeeded"
    assert_line "config=Release"
    assert_line "tfm=net10.0"
    assert_line "version=1.2.3"
    assert_line "warnings=1"
    assert_line "errors=0"
}

@test "extract_dotnet_build_info: drops per-project keys (TargetPath, PackageId) for solution builds" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        _fake_slnx='$BATS_TEST_TMPDIR/fake.slnx'
        echo fake > \"\$_fake_slnx\"
        declare -A info=()
        extract_dotnet_build_info \"\$_fake_slnx\" 0 info <<'EOF'
  TargetPath=/some/path/out.dll
  PackageId=vm2.Fake
Build succeeded.
EOF
        [[ -v info[TargetPath] ]] && echo 'TargetPath still present' || echo 'TargetPath removed'
        [[ -v info[PackageId] ]] && echo 'PackageId still present' || echo 'PackageId removed'
    "
    assert_success
    assert_line "TargetPath removed"
    assert_line "PackageId removed"
}

@test "extract_dotnet_build_info: bug-exits on a non-project/solution argument 1" {
    run extract_dotnet_build_info "not-a-project-file" 0 info
    assert_failure 254
}

@test "extract_dotnet_build_info: bug-exits with the wrong argument count" {
    run extract_dotnet_build_info "$_fake_csproj" 0
    assert_failure 254
}

# --- display_dotnet_build_summary ------------------------------------------------------------

@test "display_dotnet_build_summary: prints a summary without crashing on a minimal build-info array" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        declare -A info=([build_result]=succeeded [ExitCode]=0 [Version]=1.2.3)
        display_dotnet_build_summary info
    "
    assert_success
    assert_output --partial "succeeded"
    assert_output --partial "1.2.3"
}

@test "display_dotnet_build_summary: bug-exits on a non-associative-array argument" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a arr=(); display_dotnet_build_summary arr"
    assert_failure 254
}

# --- formal argument validation of the dotnet-invoking functions --------------------------------

@test "dotnet_clean: bug-exits on a non-existent/invalid project path" {
    run dotnet_clean "not-a-real-project.csproj"
    assert_failure 254
}

@test "dotnet_restore: bug-exits on a non-existent/invalid project path" {
    run dotnet_restore "not-a-real-project.csproj"
    assert_failure 254
}

@test "dotnet_build: bug-exits on a non-existent/invalid project path" {
    run dotnet_build "not-a-real-project.csproj"
    assert_failure 254
}

@test "dotnet_pack: bug-exits on a non-.csproj argument 1" {
    run dotnet_pack "not-a-real-project.slnx" "" properties
    assert_failure 254
}

@test "get_target_path: bug-exits on a non-existent .csproj project (regression: was silently bypassed by a -v \$1 typo)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare target=''; get_target_path 'totally-not-a-real-file.csproj' target"
    assert_failure 254
}

@test "get_target_path: bug-exits with the wrong argument count" {
    run get_target_path "$_fake_csproj"
    assert_failure 254
}

# --- update_nuget_sources_with_github_vm2 ------------------------------------------------------
#
# Credential precedence (highest to lowest): explicit positional args > $gh_nuget_username/
# $gh_nuget_password globals > $GH_ACTOR/$GH_TOKEN env vars -- the CI path sets GH_ACTOR/GH_TOKEN
# from github.actor/github.token; standalone runs rely on NuGet.config's own stored credentials
# and simply never call this function with any credentials available.
#
# Every test explicitly unsets GH_ACTOR/GH_TOKEN/gh_nuget_username/gh_nuget_password first: bats
# inherits the invoking shell's real environment (unlike the isolated env -i subshells used
# elsewhere in this file), and the developer's own shell commonly has GH_TOKEN set for the 'gh'
# CLI.

# Installs a fake 'dotnet' on $PATH that logs its arguments and exits with $1 (default 0).
# Rejects any option 'dotnet nuget update source' does not really support (regression guard --
# a real dotnet CLI rejected --no-logo here with exit 1, which a permissive stub would have
# silently accepted and never caught).
_install_fake_dotnet_nuget() {
    local _exit_code="${1:-0}"
    local _dir="$BATS_TEST_TMPDIR/fakebin"
    mkdir -p "$_dir"
    cat > "$_dir/dotnet" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$BATS_TEST_TMPDIR/dotnet.log"
if [[ "\$1 \$2 \$3" == "nuget update source" ]]; then
    shift 3
    while (( \$# > 0 )); do
        case "\$1" in
            -s|--source|-u|--username|-p|--password|--valid-authentication-types|--protocol-version|--configfile) shift 2 ;;
            --store-password-in-clear-text|--allow-insecure-connections|--force-english-output|-h|-\\?|--help) shift ;;
            github.vm2) shift ;;
            *) echo "Unrecognized command or argument '\$1'." >&2; exit 1 ;;
        esac
    done
fi
exit $_exit_code
EOF
    chmod +x "$_dir/dotnet"
    PATH="$_dir:$PATH"
}

@test "update_nuget_sources_with_github_vm2: warns and succeeds when no credentials are available anywhere" {
    unset GH_ACTOR GH_TOKEN gh_nuget_username gh_nuget_password
    run update_nuget_sources_with_github_vm2
    assert_success
    assert_output --partial "GitHub NuGet source credentials are not provided"
}

@test "update_nuget_sources_with_github_vm2: falls back to \$GH_ACTOR/\$GH_TOKEN when no globals or arguments are given" {
    unset gh_nuget_username gh_nuget_password
    export GH_ACTOR="ci-actor"
    export GH_TOKEN="ci-token"
    _install_fake_dotnet_nuget
    run update_nuget_sources_with_github_vm2
    assert_success
    run cat "$BATS_TEST_TMPDIR/dotnet.log"
    assert_output --partial "--username ci-actor"
    assert_output --partial "--password ci-token"
}

@test "update_nuget_sources_with_github_vm2: \$gh_nuget_username/\$gh_nuget_password globals take precedence over \$GH_ACTOR/\$GH_TOKEN" {
    export GH_ACTOR="ci-actor"
    export GH_TOKEN="ci-token"
    gh_nuget_username="global-user"
    gh_nuget_password="global-pass"
    _install_fake_dotnet_nuget
    run update_nuget_sources_with_github_vm2
    assert_success
    run cat "$BATS_TEST_TMPDIR/dotnet.log"
    assert_output --partial "--username global-user"
    assert_output --partial "--password global-pass"
}

@test "update_nuget_sources_with_github_vm2: explicit positional arguments take precedence over globals and env vars" {
    unset GH_ACTOR GH_TOKEN
    gh_nuget_username="global-user"
    gh_nuget_password="global-pass"
    _install_fake_dotnet_nuget
    run update_nuget_sources_with_github_vm2 "arg-user" "arg-pass"
    assert_success
    run cat "$BATS_TEST_TMPDIR/dotnet.log"
    assert_output --partial "--username arg-user"
    assert_output --partial "--password arg-pass"
}

@test "update_nuget_sources_with_github_vm2: bug-exits when only one positional argument is given" {
    run update_nuget_sources_with_github_vm2 "only-user"
    assert_failure 254
}

@test "update_nuget_sources_with_github_vm2: reports err_tool_error when 'dotnet nuget update source' fails" {
    unset GH_ACTOR GH_TOKEN
    _install_fake_dotnet_nuget 1
    run update_nuget_sources_with_github_vm2 "user" "pass"
    assert_failure 66
    assert_output --partial "Failed to update the NuGet sources with GitHub packages from vm2"
}

# --- list_solution_projects / expand_solution_projects ---------------------------------------
#
# A solution-level `dotnet build` always resolves its own "solution configuration" (Debug,
# unless -c is given) and passes it to every project as an explicit global MSBuild property,
# silently overriding Directory.Build.props's IsCI-based Configuration default -- confirmed
# live against a real repo. So build-projects keeps accepting a solution file for developer
# convenience, but it gets expanded into its constituent projects before the build matrix fans
# out, so each project builds independently and Directory.Build.props stays the source of truth.

# Installs a fake 'dotnet' on $PATH whose 'sln <sln-name> list' case echoes the fixed two-line
# header real `dotnet sln list` always prints, followed by the given project paths. <sln-name>
# MUST match exactly what the caller passes to `dotnet sln <sln-name> list` (i.e. the same
# string the test itself passes to list_solution_projects/expand_solution_projects) -- it is
# NOT a filesystem path to create; create the actual (dummy-content) solution file separately.
_install_fake_dotnet_sln() {
    local _dir="$BATS_TEST_TMPDIR/fakebin"
    mkdir -p "$_dir"
    local _sln_name=$1; shift
    {
        echo '#!/usr/bin/env bash'
        echo "if [[ \"\$1 \$2 \$3\" == \"sln $_sln_name list\" ]]; then"
        echo '    echo "Project(s)"'
        echo '    echo "----------"'
        local _p
        for _p in "$@"; do
            echo "    echo '$_p'"
        done
        echo 'fi'
    } > "$_dir/dotnet"
    chmod +x "$_dir/dotnet"
    PATH="$_dir:$PATH"
}

@test "list_solution_projects: lists a solution's projects, resolved relative to the current directory" {
    mkdir -p "$BATS_TEST_TMPDIR/repo/sub"
    echo fake > "$BATS_TEST_TMPDIR/repo/sub/App.slnx"
    _install_fake_dotnet_sln "sub/App.slnx" "src/App/App.csproj" "tests/App.Tests/App.Tests.csproj"

    run bash -c "cd '$BATS_TEST_TMPDIR/repo' && source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && declare -a p=(); list_solution_projects sub/App.slnx p; printf '%s\n' \"\${p[@]}\""
    assert_success
    assert_line --index 0 "sub/src/App/App.csproj"
    assert_line --index 1 "sub/tests/App.Tests/App.Tests.csproj"
}

@test "list_solution_projects: tolerates extra preamble lines before the header (regression: live CI runners print SDK diagnostics before 'dotnet sln list''s own output, e.g. '10.0.111 [/usr/share/dotnet/sdk]')" {
    local _dir="$BATS_TEST_TMPDIR/fakebin"
    mkdir -p "$_dir"
    {
        echo '#!/usr/bin/env bash'
        echo 'if [[ "$1 $2 $3" == "sln App.slnx list" ]]; then'
        echo '    echo "10.0.111 [/usr/share/dotnet/sdk]"'
        echo '    echo "Project(s)"'
        echo '    echo "----------"'
        echo '    echo "src/App/App.csproj"'
        echo 'fi'
    } > "$_dir/dotnet"
    chmod +x "$_dir/dotnet"
    PATH="$_dir:$PATH"
    echo fake > "$BATS_TEST_TMPDIR/App.slnx"

    run bash -c "cd '$BATS_TEST_TMPDIR' && source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && declare -a p=(); list_solution_projects App.slnx p; printf '%s\n' \"\${p[@]}\""
    assert_success
    assert_line --index 0 "src/App/App.csproj"
    refute_output --partial "10.0.111"
}

@test "list_solution_projects: fails when 'dotnet sln list' returns no projects" {
    echo fake > "$BATS_TEST_TMPDIR/Empty.slnx"
    _install_fake_dotnet_sln "Empty.slnx"

    run bash -c "cd '$BATS_TEST_TMPDIR' && source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && declare -a p=(); list_solution_projects Empty.slnx p"
    assert_failure 66
    assert_output --partial "'dotnet sln Empty.slnx list' returned no projects"
}

@test "list_solution_projects: bug-exits on a non-existent solution file" {
    run list_solution_projects "/definitely/not/a/real.slnx" p
    assert_failure 254
}

@test "list_solution_projects: bug-exits with the wrong argument count" {
    run list_solution_projects "$_fake_csproj"
    assert_failure 254
}

@test "expand_solution_projects: expands a solution entry into its constituent projects" {
    echo fake > "$BATS_TEST_TMPDIR/App.slnx"
    _install_fake_dotnet_sln "App.slnx" "src/App/App.csproj" "tests/App.Tests/App.Tests.csproj"

    run bash -c "cd '$BATS_TEST_TMPDIR' && source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && projects='[\"App.slnx\"]'; expand_solution_projects projects; echo \"\$projects\""
    assert_success
    assert_output '["src/App/App.csproj","tests/App.Tests/App.Tests.csproj"]'
}

@test "expand_solution_projects: leaves non-solution entries unchanged" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && projects='[\"src/App/App.csproj\"]'; expand_solution_projects projects; echo \"\$projects\""
    assert_success
    assert_output '["src/App/App.csproj"]'
}

@test "expand_solution_projects: de-duplicates a project listed both standalone and via a solution" {
    echo fake > "$BATS_TEST_TMPDIR/App.slnx"
    _install_fake_dotnet_sln "App.slnx" "src/App/App.csproj" "tests/App.Tests/App.Tests.csproj"

    run bash -c "cd '$BATS_TEST_TMPDIR' && source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && projects='[\"src/App/App.csproj\", \"App.slnx\"]'; expand_solution_projects projects; echo \"\$projects\""
    assert_success
    assert_output '["src/App/App.csproj","tests/App.Tests/App.Tests.csproj"]'
}

@test "expand_solution_projects: passes an empty array through unchanged (regression: printf with a zero-element array still emits one empty line)" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && projects='[]'; expand_solution_projects projects; echo \"\$projects\""
    assert_success
    assert_output '[]'
}

@test "expand_solution_projects: bug-exits with the wrong argument count" {
    run expand_solution_projects
    assert_failure 254
}

@test "expand_solution_projects: bug-exits on an undefined variable name" {
    run expand_solution_projects not_a_defined_var
    assert_failure 254
}
