#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_dotnet_args.sh, as it behaves TODAY -- written
# before the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- default values --------------------------------------------------------------------------

@test "defaults: configuration is Debug outside CI" {
    [[ -z $configuration ]]
}

@test "defaults: framework, artifacts, minver-tag-prefix have their documented defaults" {
    [[ -z $framework ]]
    [[ -z $artifacts ]]
    [[ $minver_tag_prefix == v ]]
}

# --- get_common_dotnet_arg -----------------------------------------------------------------

@test "get_common_dotnet_arg: recognizes --configuration/-c and sets \$configuration" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_dotnet_arg --configuration Release; echo \"\$configuration\""
    assert_success
    assert_output "Release"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_dotnet_arg -c Release; echo \"\$configuration\""
    assert_output "Release"
}

@test "get_common_dotnet_arg: recognizes --artifacts-path (long form only) and sets \$artifacts" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_dotnet_arg --artifacts-path myartifacts; echo \"\$artifacts\""
    assert_success
    assert_output "myartifacts"
}

@test "get_common_dotnet_arg: only --configuration has a short form -- -d/-f/-r/-a/-mp/-mi are no longer recognized" {
    local _opt
    for _opt in -d -f -r -a -mp -mi; do
        run get_common_dotnet_arg "$_opt" "some-value"
        assert_failure 1
    done
}

@test "get_common_dotnet_arg: a recognized option given an explicitly empty value is accepted, not rejected" {
    # This is the actual production bug this file's history is about: CI passes
    # --define '${{ inputs.preprocessor-symbols }}', which is empty on every path except
    # SHORT_RUN. The function only records option names and values; it does not judge them --
    # that is sanitize_common_dotnet_args()'s job. Rejecting an empty (but present) value here
    # broke every normal CI run.
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_dotnet_arg --define ''; echo \"[\$preprocessor_symbols]\""
    assert_success
    assert_output "[]"
}

@test "get_common_dotnet_arg: an unrecognized/positional argument with an empty value is still not mine" {
    # regression: membership (is this option name recognized at all?) must be decided before
    # any value is inspected -- otherwise a positional argument (e.g. a project path) that
    # happens to be paired with an empty next token could be misrouted into a value-setting arm.
    run get_common_dotnet_arg "some/positional/path.csproj" ""
    assert_failure 1
}

@test "get_common_dotnet_arg: recognizes --nuget-username/--nuget-password" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_dotnet_arg --nuget-username bob; echo \"\$gh_nuget_username\""
    assert_output "bob"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; get_common_dotnet_arg --nuget-password s3cr3t; echo \"\$gh_nuget_password\""
    assert_output "s3cr3t"
}

@test "get_common_dotnet_arg: returns failure for an unrecognized argument" {
    run get_common_dotnet_arg "--not-a-dotnet-flag" "value"
    assert_failure 1
}

@test "get_common_dotnet_arg: bug-exits with the wrong argument count" {
    run get_common_dotnet_arg "--configuration"
    assert_failure 254
}

# --- sanitize_common_dotnet_args -------------------------------------------------------------

@test "sanitize_common_dotnet_args: succeeds and freezes the arguments for valid values" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; sanitize_common_dotnet_args '$lib_dir/core.sh'; echo done; configuration=Changed 2>&1"
    assert_output --partial "done"
    assert_output --partial "readonly variable"
}

@test "sanitize_common_dotnet_args: rejects a GitHub username with no matching password" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; gh_nuget_username=user; gh_nuget_password=''; sanitize_common_dotnet_args '$lib_dir/core.sh'"
    assert_failure 4
}

@test "sanitize_common_dotnet_args: rejects a GitHub password with no matching username" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; gh_nuget_username=''; gh_nuget_password=secret; sanitize_common_dotnet_args '$lib_dir/core.sh'"
    assert_failure 4
}

@test "sanitize_common_dotnet_args: accepts a matching GitHub username/password pair" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; gh_nuget_username=user; gh_nuget_password=secret; sanitize_common_dotnet_args '$lib_dir/core.sh'"
    assert_success
}

@test "sanitize_common_dotnet_args: bug-exits with the wrong argument count" {
    run sanitize_common_dotnet_args
    assert_failure 254
}

@test "sanitize_common_dotnet_args: resolves \$artifacts to the documented 'artifacts' default (relative to the repo root) when not explicitly set" {
    mkdir -p "$BATS_TEST_TMPDIR/repo"
    touch "$BATS_TEST_TMPDIR/repo/project.csproj"
    run bash -c "cd '$BATS_TEST_TMPDIR/repo' && git init -q && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; sanitize_common_dotnet_args project.csproj; echo \"\$artifacts\""
    assert_success
    assert_output --regexp "^/.*/repo/artifacts$"
}

@test "sanitize_common_dotnet_args: resolves an explicitly-given \$artifacts to an absolute path" {
    mkdir -p "$BATS_TEST_TMPDIR/repo"
    touch "$BATS_TEST_TMPDIR/repo/project.csproj"
    run bash -c "cd '$BATS_TEST_TMPDIR/repo' && git init -q && source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1; artifacts=myartifacts; sanitize_common_dotnet_args project.csproj; echo \"\$artifacts\""
    assert_success
    assert_output --regexp "^/.*/repo/myartifacts$"
}

# --- common_dotnet_to_output (requires gh_core.sh, not just core.sh) ---------------------------

@test "common_dotnet_to_output: writes key=value pairs for each common dotnet variable" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1; common_dotnet_to_output"
    assert_output --partial "configuration="
    assert_output --partial "artifacts="
    assert_output --partial "minver-tag-prefix=v"
}
