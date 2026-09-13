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
    [[ $configuration == Debug ]]
}

@test "defaults: framework, artifacts, minver-tag-prefix have their documented defaults" {
    [[ $framework == '' ]]
    [[ $artifacts == artifacts ]]
    [[ $minver_tag_prefix == v ]]
}

# --- get_common_dotnet_arg -----------------------------------------------------------------

@test "get_common_dotnet_arg: recognizes --configuration/-c and sets \$configuration" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; get_common_dotnet_arg --configuration Release; echo \"\$configuration\""
    assert_success
    assert_output "Release"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; get_common_dotnet_arg -c Release; echo \"\$configuration\""
    assert_output "Release"
}

@test "get_common_dotnet_arg: recognizes --artifacts-path/-a and sets \$artifacts" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; get_common_dotnet_arg -a myartifacts; echo \"\$artifacts\""
    assert_success
    assert_output "myartifacts"
}

@test "get_common_dotnet_arg: recognizes --nuget-username/--nuget-password" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; get_common_dotnet_arg --nuget-username bob; echo \"\$gh_nuget_username\""
    assert_output "bob"
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; get_common_dotnet_arg --nuget-password s3cr3t; echo \"\$gh_nuget_password\""
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
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; sanitize_common_dotnet_args '$lib_dir/core.sh'; echo done; configuration=Changed 2>&1"
    assert_output --partial "done"
    assert_output --partial "readonly variable"
}

@test "sanitize_common_dotnet_args: rejects a GitHub username with no matching password" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; gh_nuget_username=user; gh_nuget_password=''; sanitize_common_dotnet_args '$lib_dir/core.sh'"
    assert_failure 4
}

@test "sanitize_common_dotnet_args: rejects a GitHub password with no matching username" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; gh_nuget_username=''; gh_nuget_password=secret; sanitize_common_dotnet_args '$lib_dir/core.sh'"
    assert_failure 4
}

@test "sanitize_common_dotnet_args: accepts a matching GitHub username/password pair" {
    run bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null; gh_nuget_username=user; gh_nuget_password=secret; sanitize_common_dotnet_args '$lib_dir/core.sh'"
    assert_success
}

@test "sanitize_common_dotnet_args: bug-exits with the wrong argument count" {
    run sanitize_common_dotnet_args
    assert_failure 254
}

# --- common_dotnet_to_output (requires gh_core.sh, not just core.sh) ---------------------------

@test "common_dotnet_to_output: writes key=value pairs for each common dotnet variable" {
    run bash -c "source '$lib_dir/gh_core.sh' --no-trap > /dev/null; common_dotnet_to_output"
    assert_output --partial "configuration=Debug"
    assert_output --partial "artifacts=artifacts"
    assert_output --partial "minver-tag-prefix=v"
}
