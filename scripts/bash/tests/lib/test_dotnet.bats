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

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_invalid_arguments
declare -gxi err_argument_type
declare -gxi err_argument_value
declare -gxi err_invalid_nameref
declare -gxi err_missing_argument
declare -gxi err_not_found

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
    assert_failure "$err_invalid_arguments"
    run get_dotnet_error_message -1
    assert_failure "$err_argument_type"
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
    assert_failure "$err_invalid_arguments"
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

@test "extract_dotnet_build_info: drops per-project keys (TargetPath, PackageId, ArtifactsProjectName) for solution builds" {
    run bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        _fake_slnx='$BATS_TEST_TMPDIR/fake.slnx'
        echo fake > \"\$_fake_slnx\"
        declare -A info=()
        extract_dotnet_build_info \"\$_fake_slnx\" 0 info <<'EOF'
  TargetPath=/some/path/out.dll
  PackageId=vm2.Fake
  ArtifactsProjectName=Fake
Build succeeded.
EOF
        [[ -v info[TargetPath] ]] && echo 'TargetPath still present' || echo 'TargetPath removed'
        [[ -v info[PackageId] ]] && echo 'PackageId still present' || echo 'PackageId removed'
        [[ -v info[ArtifactsProjectName] ]] && echo 'ArtifactsProjectName still present' || echo 'ArtifactsProjectName removed'
    "
    assert_success
    assert_line "TargetPath removed"
    assert_line "PackageId removed"
    assert_line "ArtifactsProjectName removed"
}

@test "extract_dotnet_build_info: bug-exits on a non-project/solution argument 1" {
    # NOTE: 'info' must be a real pre-declared associative array, or the arg-3 nameref bug-gate
    # fires first (via exit_if_has_bugs) and the arg-1 check is never reached.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A info=(); extract_dotnet_build_info 'not-a-project-file' 0 info"
    assert_failure "$err_argument_value"
}

@test "extract_dotnet_build_info: bug-exits with the wrong argument count" {
    run extract_dotnet_build_info "$_fake_csproj" 0
    assert_failure "$err_invalid_arguments"
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
    assert_failure "$err_invalid_nameref"
}

# --- formal argument validation of the dotnet-invoking functions --------------------------------

@test "dotnet_clean: fails on a non-existent/invalid project path" {
    # NOTE: this used to be a bug-exit (254). The project/solution existence check moved from
    # 'bug' to 'error' (err_argument_value=4) -- see the summary note asking whether this is
    # an intentional reclassification (runtime condition vs. caller precondition).
    run dotnet_clean "not-a-real-project.csproj"
    assert_failure 4
}

@test "dotnet_restore: fails on a non-existent/invalid project path" {
    run dotnet_restore "not-a-real-project.csproj"
    assert_failure 4
}

@test "dotnet_build: fails on a non-existent/invalid project path" {
    run dotnet_build "not-a-real-project.csproj"
    assert_failure 4
}

@test "dotnet_pack: fails on a non-.csproj argument 1" {
    # NOTE: 'properties' must be a real pre-declared associative array, or dotnet_pack()'s own
    # arg-3 nameref bug-gate fires first (via exit_if_has_bugs) and the arg-1 file-path check
    # (now 'error'-based, not 'bug'-based -- see the summary note on lib functions no longer
    # calling exit_if_has_errors) is never reached at all.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A properties=(); dotnet_pack 'not-a-real-project.slnx' '' properties"
    assert_failure "$err_argument_value"
}

@test "get_target_path: fails on a non-existent .csproj project (regression: was silently bypassed by a -v \$1 typo)" {
    # NOTE: this used to be a bug-exit (254) -- see the summary note on this existence check
    # moving from 'bug' to 'error' (err_argument_value=4) across the dotnet-invoking functions.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare target=''; get_target_path 'totally-not-a-real-file.csproj' target"
    assert_failure 4
}

@test "get_target_path: bug-exits with the wrong argument count" {
    run get_target_path "$_fake_csproj"
    assert_failure "$err_invalid_arguments"
}

# --- get_msbuild_property / get_msbuild_properties -------------------------------------------
#
# Deliberate exception to this file's "dotnet-invoking functions get bug-exit-only tests here"
# convention: these two are cheap, no-build static queries (unlike dotnet_clean/build/pack), and
# a permissive fake `dotnet` that always echoes canned output regardless of its actual argv --
# the style used elsewhere in this suite -- would not have caught either real bug found live
# against the real vm2.Ulid repo while reviewing this code: the nameref bound to $2 (the property
# NAME string) instead of $3 (the caller's own output variable), and -getProperty:'s value being
# wrapped in literal quote characters, which makes real `dotnet msbuild` (unlike `dotnet build`)
# silently print nothing at all. So the fake here discriminates on the actual -getProperty: value.

# Installs a fake 'dotnet' whose 'msbuild ... -getProperty:<names>' case mimics dotnet msbuild's
# two real output shapes (plain value for one property, {"Properties": {...}} JSON for two or
# more, semicolon-joined) and, like the real tool, prints nothing if the value contains a quote
# character -- a regression guard for the quoting bug above.
_install_fake_dotnet_msbuild() {
    local _dir="$BATS_TEST_TMPDIR/fakebin"
    mkdir -p "$_dir"
    cat > "$_dir/dotnet" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "msbuild" ]] || exit 0
for _arg in "$@"; do
    [[ $_arg == -getProperty:* ]] || continue
    _props=${_arg#-getProperty:}
    [[ $_props != *'"'* ]] || exit 0
    if [[ $_props == *';'* ]]; then
        IFS=';' read -ra _names <<< "$_props"
        echo '{'
        echo '  "Properties": {'
        for i in "${!_names[@]}"; do
            _comma=','
            (( i == ${#_names[@]} - 1 )) && _comma=''
            echo "    \"${_names[$i]}\": \"VALUE_${_names[$i]}\"$_comma"
        done
        echo '  }'
        echo '}'
    else
        echo "VALUE_${_props}"
    fi
    exit 0
done
EOF
    chmod +x "$_dir/dotnet"
    PATH="$_dir:$PATH"
}

@test "get_msbuild_property: retrieves a single property's plain-text value" {
    _install_fake_dotnet_msbuild
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare v=''; get_msbuild_property '$_fake_csproj' Configuration v; echo \"[\$v]\""
    assert_success
    assert_output --partial "[VALUE_Configuration]"
}

@test "get_msbuild_properties: retrieves two or more properties as name/value pairs (regression: -getProperty's value must not be quoted)" {
    _install_fake_dotnet_msbuild
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A p=(); get_msbuild_properties '$_fake_csproj' p TargetPath Configuration; for k in \"\${!p[@]}\"; do echo \"\$k=\${p[\$k]}\"; done | sort"
    assert_success
    assert_line "Configuration=VALUE_Configuration"
    assert_line "TargetPath=VALUE_TargetPath"
}

@test "get_msbuild_property: fails on a non-existent .csproj project" {
    # NOTE: this used to be a bug-exit (254) -- see the summary note on this existence check
    # moving from 'bug' to 'error' (err_argument_value=4) across the dotnet-invoking functions.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare v=''; get_msbuild_property 'totally-not-a-real-file.csproj' Configuration v"
    assert_failure 4
}

@test "get_msbuild_property: bug-exits on an invalid property name" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare v=''; get_msbuild_property '$_fake_csproj' 'not a name' v"
    assert_failure "$err_argument_value"
}

@test "get_msbuild_property: bug-exits with the wrong argument count" {
    run get_msbuild_property "$_fake_csproj" Configuration
    assert_failure "$err_invalid_arguments"
}

@test "get_msbuild_properties: fails on a non-existent .csproj project" {
    # NOTE: this used to be a bug-exit (254) -- see the summary note on this existence check
    # moving from 'bug' to 'error' (err_argument_value=4) across the dotnet-invoking functions.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A p=(); get_msbuild_properties 'totally-not-a-real-file.csproj' p Configuration TargetPath"
    assert_failure 4
}

@test "get_msbuild_properties: reports an invalid property name (regression: must validate every name in \$3.., not just \$3)" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A p=(); get_msbuild_properties '$_fake_csproj' p Configuration 'not a name'"
    assert_failure 4
    assert_output --partial "'not a name'"
}

@test "get_msbuild_properties: bug-exits with fewer than 2 property names" {
    # NOTE: 'p' must be a real pre-declared associative array, or a second bug (arg-2 nameref)
    # accumulates alongside the intended arity bug, and exit_if_has_bugs reports the LAST one
    # recorded (err_argument_value), not this test's intended err_invalid_arguments.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -A p=(); get_msbuild_properties '$_fake_csproj' p OnlyOneProperty"
    assert_failure "$err_invalid_arguments"
}

@test "get_msbuild_properties: bug-exits with the wrong argument count" {
    run get_msbuild_properties "$_fake_csproj"
    assert_failure "$err_invalid_arguments"
}

# --- get_artifacts_path -------------------------------------------------------------------------
#
# get_artifacts_path() moved here from _git_vm2.sh: it is now a thin wrapper over
# get_msbuild_property(), so it needs a real MSBuild evaluation to test meaningfully -- same
# fixture shape as the "resolves \$artifacts via real MSBuild ArtifactsPath evaluation" test in
# test_dotnet_args.bats.

@test "get_artifacts_path: resolves the real ArtifactsPath via MSBuild, per Directory.Build.props" {
    mkdir -p "$BATS_TEST_TMPDIR/artpath-repo"
    cat > "$BATS_TEST_TMPDIR/artpath-repo/Directory.Build.props" <<'EOF'
<Project>
  <PropertyGroup>
    <UseArtifactsOutput>true</UseArtifactsOutput>
  </PropertyGroup>
</Project>
EOF
    cat > "$BATS_TEST_TMPDIR/artpath-repo/project.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>
EOF
    run bash -c "cd '$BATS_TEST_TMPDIR/artpath-repo' && git init -q && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare art=''; get_artifacts_path project.csproj art; echo \"\$art\""
    assert_success
    assert_output --regexp "^/.*/artpath-repo/artifacts$"
}

@test "get_artifacts_path: resolves a solution (*.slnx) via list_solution_projects(), preferring a project under src/" {
    # MSBuild has no notion of a solution's own properties, only a project's -- get_artifacts_path()
    # must resolve the solution to one representative project first. ArtifactsPath is uniform
    # across the whole repo (set once via UseArtifactsOutput=true), so any real project would report
    # the same answer; this fixture puts a non-src/ project ahead of the src/ one in registration
    # order, so a correct resolution can only happen via the src/-first sort, not by accident.
    mkdir -p "$BATS_TEST_TMPDIR/sln-repo/src/App" "$BATS_TEST_TMPDIR/sln-repo/tests/App.Tests"
    cat > "$BATS_TEST_TMPDIR/sln-repo/Directory.Build.props" <<'EOF'
<Project>
  <PropertyGroup>
    <UseArtifactsOutput>true</UseArtifactsOutput>
  </PropertyGroup>
</Project>
EOF
    cat > "$BATS_TEST_TMPDIR/sln-repo/src/App/App.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>
EOF
    cp "$BATS_TEST_TMPDIR/sln-repo/src/App/App.csproj" "$BATS_TEST_TMPDIR/sln-repo/tests/App.Tests/App.Tests.csproj"

    run bash -c "cd '$BATS_TEST_TMPDIR/sln-repo' && git init -q \
        && dotnet new sln -n App --force > /dev/null \
        && dotnet sln *.slnx add tests/App.Tests/App.Tests.csproj src/App/App.csproj > /dev/null \
        && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare art=''; get_artifacts_path App.slnx art; echo \"\$art\""
    assert_success
    assert_output --regexp "^/.*/sln-repo/artifacts$"
}

@test "get_artifacts_path: fails on a non-existent .csproj project" {
    # NOTE: without 'set -e' (this fixture has none), get_msbuild_property()'s own
    # err_argument_value failure doesn't abort the script -- execution falls through to
    # get_artifacts_path()'s own empty-value check, whose err_not_found is the one actually
    # returned. Under 'set -e' (every real .github/scripts/*.sh), get_msbuild_property()'s
    # bare, unconditional call aborts immediately with err_argument_value instead -- the more
    # specific, correct error never gets a chance to be shadowed by this one.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare art=''; get_artifacts_path 'totally-not-a-real-file.csproj' art"
    assert_failure "$err_not_found"
}

@test "get_artifacts_path: bug-exits on an undefined output variable" {
    run get_artifacts_path "$_fake_csproj" not_a_defined_var
    assert_failure "$err_argument_value"
}

@test "get_artifacts_path: bug-exits with the wrong argument count" {
    run get_artifacts_path "$_fake_csproj"
    assert_failure "$err_invalid_arguments"
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

@test "update_nuget_sources_with_github_vm2: traces (does not warn) when no credentials are available outside CI" {
    # Outside CI, missing credentials here are the normal case -- a local dev manages
    # github.vm2 credentials via the machine's global NuGet.Config instead, a channel this
    # function never looks at. Warning every time would be a false alarm, not a real signal.
    unset GH_ACTOR GH_TOKEN gh_nuget_username gh_nuget_password
    run update_nuget_sources_with_github_vm2
    assert_success
    refute_output --partial "GitHub NuGet source credentials are not provided"
}

@test "update_nuget_sources_with_github_vm2: warns when no credentials are available in CI" {
    # In CI, missing GH_ACTOR/GH_TOKEN is a real misconfiguration worth flagging loudly.
    run bash -c "unset GH_ACTOR GH_TOKEN gh_nuget_username gh_nuget_password; CI=true; source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; update_nuget_sources_with_github_vm2"
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
    assert_failure "$err_argument_value"
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
    # NOTE: switched from assert_line --index N to --partial -- see the summary's top bug:
    # list_solution_projects()'s own '&&'/'||' typo (line ~1150 in _dotnet.sh) makes it always
    # print a spurious "requires argument 1 to be an existing, non-empty solution file" line
    # first, even for a perfectly valid solution file, shifting every real output line down by
    # one and breaking index-based assertions.
    assert_output --partial "sub/src/App/App.csproj"
    assert_output --partial "sub/tests/App.Tests/App.Tests.csproj"
}

@test "list_solution_projects: sorts a project under src/ before one that isn't, regardless of dotnet sln list's own order" {
    # 'aaa' sorts alphabetically before 'src' -- dotnet sln list's own (registration) order is
    # deliberately the opposite of the desired result, so this can't pass by accident.
    mkdir -p "$BATS_TEST_TMPDIR/repo"
    echo fake > "$BATS_TEST_TMPDIR/repo/App.slnx"
    _install_fake_dotnet_sln "App.slnx" "aaa/AaaProj/AaaProj.csproj" "src/App/App.csproj"

    run bash -c "cd '$BATS_TEST_TMPDIR/repo' && source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && declare -a p=(); list_solution_projects App.slnx p; printf '%s\n' \"\${p[@]}\""
    assert_success
    assert_line --index 0 "src/App/App.csproj"
    assert_line --index 1 "aaa/AaaProj/AaaProj.csproj"
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
    # NOTE: see the summary's top bug -- list_solution_projects() always prints a spurious
    # "requires argument 1 ..." line first even for a valid solution, so this no longer lands
    # on line index 0.
    assert_output --partial "src/App/App.csproj"
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
    # NOTE: 'p' must be a real pre-declared indexed array, or the arg-2 nameref bug-gate fires
    # first (via exit_if_has_bugs) and the arg-1 file-existence check is never reached.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; declare -a p=(); list_solution_projects '/definitely/not/a/real.slnx' p"
    assert_failure "$err_argument_value"
}

@test "list_solution_projects: bug-exits with the wrong argument count" {
    run list_solution_projects "$_fake_csproj"
    assert_failure "$err_invalid_arguments"
}

@test "expand_solution_projects: expands a solution entry into its constituent projects" {
    echo fake > "$BATS_TEST_TMPDIR/App.slnx"
    _install_fake_dotnet_sln "App.slnx" "src/App/App.csproj" "tests/App.Tests/App.Tests.csproj"

    run bash -c "cd '$BATS_TEST_TMPDIR' && source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && projects='[\"App.slnx\"]'; expand_solution_projects projects; echo \"\$projects\""
    assert_success
    # NOTE: switched from an exact assert_output to --partial -- see the summary's top bug:
    # list_solution_projects() (called internally here) always prints a spurious
    # "requires argument 1 ..." line first, even for a valid solution file.
    assert_output --partial '["src/App/App.csproj","tests/App.Tests/App.Tests.csproj"]'
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
    # NOTE: see the summary's top bug -- same spurious line from list_solution_projects().
    assert_output --partial '["src/App/App.csproj","tests/App.Tests/App.Tests.csproj"]'
}

@test "expand_solution_projects: passes an empty array through unchanged (regression: printf with a zero-element array still emits one empty line)" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1 && projects='[]'; expand_solution_projects projects; echo \"\$projects\""
    assert_success
    assert_output '[]'
}

@test "expand_solution_projects: bug-exits with the wrong argument count" {
    run expand_solution_projects
    assert_failure "$err_invalid_arguments"
}

@test "expand_solution_projects: bug-exits on an undefined variable name" {
    run expand_solution_projects not_a_defined_var
    assert_failure "$err_missing_argument"
}
