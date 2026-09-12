#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/setup-repo.args.sh, as it behaves TODAY.
#
# Mirrors the approach used for diff-shared.args.sh: each test sources core.sh and the file(s)
# under test in a fresh, ambient-environment-free bash subshell.
#
# setup-repo.usage.sh's usage_text() calls get_vm2_sot_path("$vm2_repos", "$sot", ...)
# unconditionally, so any test that can reach usage() (an unknown/missing-value option, too
# many positional args, or -h/--help) needs vm2_repos and sot to already hold real,
# resolvable values -- exactly as the real setup-repo.sh guarantees by assigning
# vm2_repos="${VM2_REPOS:-$HOME/repos/vm2}" and sourcing setup-repo.defaults.sh (which sets
# sot) BEFORE ever calling get_arguments(). Skipping that setup in a test would crash inside
# usage_text() itself with an unrelated bug about an empty argument -- not a real defect, just
# a precondition the isolated test must replicate.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_src_dir="$(cd "$lib_dir/../src" && pwd)"

_sr() {
    env -i HOME="$HOME" PATH="/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        source '$_src_dir/setup-repo.defaults.sh'
        source '$_src_dir/setup-repo.args.sh'
        source '$_src_dir/setup-repo.usage.sh'
        declare -a arguments=()
        vm2_repos=\"\$HOME/repos/vm2\"
        repo_path=''
        visibility='public'
        branch='main'
        interactive_vars=false
        interactive_secrets=false
        configure_local=true
        audit=false
        main_protection_rs_name=''
        description=''
        use_ssh=true
        use_https=false
        set_quiet
        $1
    "
}

@test "get_arguments: the sole positional argument becomes repo_path" {
    run _sr "get_arguments myrepo; declare -p repo_path"
    assert_success
    assert_output --partial 'repo_path="myrepo"'
}

@test "get_arguments: a second positional argument fails with usage (too many arguments)" {
    run _sr "get_arguments repo1 repo2"
    assert_failure 1
    assert_output --partial "Too many positional arguments"
}

@test "get_arguments: --owner, --branch, --visibility, --ruleset-name, and --description set the corresponding variables" {
    run _sr "get_arguments --owner acme --branch dev --visibility private --ruleset-name 'main protection' --description 'a repo'
              declare -p repo_owner branch visibility main_protection_rs_name description"
    assert_success
    assert_output --partial 'repo_owner="acme"'
    assert_output --partial 'branch="dev"'
    assert_output --partial 'visibility="private"'
    assert_output --partial 'main_protection_rs_name="main protection"'
    assert_output --partial 'description="a repo"'
}

@test "get_arguments: -n, -o, -b, and -rs are the short forms of the same options" {
    run _sr "get_arguments -n myrepo -o acme -b dev -rs 'main protection'
              declare -p repo_name repo_owner branch main_protection_rs_name"
    assert_success
    assert_output --partial 'repo_name="myrepo"'
    assert_output --partial 'repo_owner="acme"'
    assert_output --partial 'branch="dev"'
    assert_output --partial 'main_protection_rs_name="main protection"'
}

@test "get_arguments: --ssh and --https are mutually exclusive, each clearing the other" {
    run _sr "get_arguments --ssh; declare -p use_ssh use_https"
    assert_success
    assert_output --partial 'use_ssh="true"'
    assert_output --partial 'use_https="false"'

    run _sr "get_arguments --https; declare -p use_ssh use_https"
    assert_success
    assert_output --partial 'use_ssh="false"'
    assert_output --partial 'use_https="true"'
}

@test "get_arguments: --interactive-vars, --interactive-secrets, --skip-local-config, and --audit set their flags" {
    run _sr "get_arguments --interactive-vars --interactive-secrets --skip-local-config --audit
              declare -p interactive_vars interactive_secrets configure_local audit"
    assert_success
    assert_output --partial 'interactive_vars="true"'
    assert_output --partial 'interactive_secrets="true"'
    assert_output --partial 'configure_local="false"'
    assert_output --partial 'audit="true"'
}

@test "get_arguments: -iv, -is, -slc, and -a are the short forms of the same switches" {
    run _sr "get_arguments -iv -is -slc -a
              declare -p interactive_vars interactive_secrets configure_local audit"
    assert_success
    assert_output --partial 'interactive_vars="true"'
    assert_output --partial 'interactive_secrets="true"'
    assert_output --partial 'configure_local="false"'
    assert_output --partial 'audit="true"'
}

@test "get_arguments: fails with usage when a value-taking option is given without a value" {
    run _sr "get_arguments --owner"
    assert_failure 1
    assert_output --partial "Missing owner after '--owner'"
}

@test "get_arguments: --vm2-repos overrides the default vm2_repos" {
    run _sr "get_arguments --vm2-repos /some/other/path; declare -p vm2_repos"
    assert_success
    assert_output --partial 'vm2_repos="/some/other/path"'
}

@test "get_arguments: -h prints usage and exits 0" {
    run _sr "get_arguments -h"
    assert_success
    assert_output --partial "Usage:"
}

@test "get_arguments: --help prints the long usage text (includes common switches)" {
    run _sr "get_arguments --help"
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "--verbose"
}

@test "get_arguments: options are matched case-insensitively" {
    run _sr "get_arguments --OWNER acme; declare -p repo_owner"
    assert_success
    assert_output --partial 'repo_owner="acme"'
}
