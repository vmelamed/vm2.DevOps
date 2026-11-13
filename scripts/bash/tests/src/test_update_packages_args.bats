#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/update-packages.args.sh (with update-packages.usage.sh), following the seams of the
# get_arguments() pipeline (see test_diff_shared_args.bats, the reference implementation). Each test sources core.sh, the
# script's function files, and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell.
#
# resolve_arguments() needs real git repositories, so those tests build a hermetic, local-only $VM2_REPOS under
# $BATS_TEST_TMPDIR (_make_vm2_repos): vm2.DevOps, vm2.Templates (with the default SoT's content directory), and vm2.Ulid
# and vm2.Glob as targets -- names from $vm2_repositories, since resolve_arguments() only accepts those.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_unknown_argument
declare -gx  default_vm2_repos_path
declare -gx  default_sot
declare -gxa vm2_repositories

declare BATS_TEST_TMPDIR

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# Runs the snippet $1 in the directory $2 (default: $BATS_TEST_TMPDIR), with the optional environment assignments $3.
_up() {
    (cd "${2:-$BATS_TEST_TMPDIR}" && env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" ${3:+"$3"} bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        declare -xr dpp_file_name='Directory.Packages.props'
        source '$_src_dir/update-packages.functions.sh'
        source '$_src_dir/update-packages.repos.sh'
        source '$_src_dir/update-packages.args.sh'
        source '$_src_dir/update-packages.usage.sh'
        $1
    ")
}

setup() {
    # canonical: resolve_vm2_repos() and resolve_repo_root() return realpath-ed paths
    _tmp=$(realpath "$BATS_TEST_TMPDIR")
    _vm2="$_tmp/vm2"
}

# A local-only git repository on 'main' with CI configured and one stable tag, so it passes __validate_repo_root()'s
# checks without any network activity (see test_git_vm2.bats). With $2 == true, it also gets a valid
# Directory.Packages.props.
_make_repo() {
    local _dir="$1"
    mkdir -p "$_dir/.github/workflows"
    git -C "$_dir" init --quiet --initial-branch=main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo "name: CI" > "$_dir/.github/workflows/ci.yaml"
    [[ ${2:-false} != true ]] || _write_dpp "$_dir"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: initial commit"
    git -C "$_dir" tag v1.0.0
}

_write_dpp() {
    cat > "$1/Directory.Packages.props" <<'EOF'
<Project>
  <ItemGroup>
    <PackageVersion Include="xunit.v3" Version="3.0.0" />
  </ItemGroup>
</Project>
EOF
}

_make_vm2_repos() {
    _make_repo "$_vm2/vm2.DevOps"
    _make_repo "$_vm2/vm2.Templates"
    mkdir -p "$_vm2/vm2.Templates/templates/$default_sot/content"
    _write_dpp "$_vm2/vm2.Templates/templates/$default_sot/content"
    _make_repo "$_vm2/vm2.Ulid" true
    _make_repo "$_vm2/vm2.Glob" true
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _up "parse_arguments
             declare -p vm2_repos sot summary_file target_repos"
    assert_success
    assert_output --partial "vm2_repos=\"$default_vm2_repos_path\""
    assert_output --partial "sot=\"$default_sot\""
    assert_output --partial 'summary_file=""'
    assert_output --partial 'target_repos=()'
}

@test "parse_arguments: the default vm2_repos comes from \$VM2_REPOS when it is set" {
    run _up "parse_arguments
             declare -p vm2_repos" "" "VM2_REPOS=/from/env"
    assert_success
    assert_output --partial 'vm2_repos="/from/env"'
}

@test "parse_arguments: --vm2-repos and --summary-file set the corresponding variables; positionals are target repos" {
    run _up "parse_arguments --vm2-repos /some/path --summary-file /some/sum.md vm2.Ulid vm2.Ulid vm2.Glob
             declare -p vm2_repos summary_file target_repos"
    assert_success
    assert_output --partial 'vm2_repos="/some/path"'
    assert_output --partial 'summary_file="/some/sum.md"'
    assert_output --partial '[vm2.Ulid]=""'
    assert_output --partial '[vm2.Glob]=""'
}

@test "parse_arguments: -r and -sf set the corresponding variables, case-insensitively" {
    run _up "parse_arguments -R /some/path -SF /some/sum.md
             declare -p vm2_repos summary_file"
    assert_success
    assert_output --partial 'vm2_repos="/some/path"'
    assert_output --partial 'summary_file="/some/sum.md"'
}

@test "parse_arguments: --all-repos, --all-repositories, and -all add every vm2 repository once" {
    local _option
    for _option in --all-repos --all-repositories -all; do
        run _up "parse_arguments vm2.Ulid $_option
                 echo \"count=\${#target_repos[@]}\""
        assert_success
        assert_output "count=${#vm2_repositories[@]}"
    done
}

@test "parse_arguments: does not validate values (an unknown repository is taken as is)" {
    run _up "parse_arguments vm2.NotThere
             declare -p target_repos"
    assert_success
    assert_output --partial '[vm2.NotThere]=""'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --vm2-repos --summary-file; do
        run _up "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: rejects an unknown option instead of taking it as a target repository" {
    run _up "parse_arguments vm2.Ulid --bogus; declare -p target_repos"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "target_repos="
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _up "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _up "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently" {
    run _up "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: resolves vm2_repos, sot_path, and the targets' paths, and freezes them" {
    _make_vm2_repos
    run _up "vm2_repos='$_vm2'
             summary_file='$_tmp/sum.md'
             target_repos=([vm2.Ulid]='' [vm2.Glob]='')
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p vm2_repos sot sot_path target_repos summary_file"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial "declare -rx vm2_repos=\"$_vm2\""
    assert_output --partial "declare -rx sot=\"$default_sot\""
    assert_output --partial "declare -rx sot_path=\"$_vm2/vm2.Templates/templates/$default_sot/content\""
    assert_output --partial "[vm2.Ulid]=\"$_vm2/vm2.Ulid\""
    assert_output --partial "[vm2.Glob]=\"$_vm2/vm2.Glob\""
    assert_output --partial "declare -rx summary_file=\"$_tmp/sum.md\""
}

@test "resolve_arguments: starts the summary file with its heading" {
    _make_vm2_repos
    run _up "vm2_repos='$_vm2'
             summary_file='$_tmp/sum.md'
             target_repos=([vm2.Ulid]='')
             resolve_arguments"
    assert_success
    run head -1 "$_tmp/sum.md"
    assert_output "# Update Packages Summary"
}

@test "resolve_arguments: uses the repository of the current directory when no target is given" {
    _make_vm2_repos
    run _up "vm2_repos='$_vm2'
             summary_file='$_tmp/sum.md'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p target_repos" "$_vm2/vm2.Ulid"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial "target_repos=([vm2.Ulid]=\"$_vm2/vm2.Ulid\" )"
}

@test "resolve_arguments: reports a current directory outside any vm2 repository when no target is given" {
    _make_vm2_repos
    run _up "vm2_repos='$_vm2'
             summary_file='$_tmp/sum.md'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "The current directory is not a vm2 repository"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports a repository that is not in the vm2 list, and still resolves the others" {
    _make_vm2_repos
    run _up "vm2_repos='$_vm2'
             summary_file='$_tmp/sum.md'
             target_repos=([vm2.NotThere]='' [vm2.Ulid]='')
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p target_repos"
    assert_success
    assert_output --partial "The specified repository 'vm2.NotThere' is not in the vm2 repositories list."
    assert_output --partial "HAS_ERRORS"
    assert_output --partial "[vm2.Ulid]=\"$_vm2/vm2.Ulid\""
}

@test "resolve_arguments: skips, with a warning, a target without Directory.Packages.props" {
    _make_vm2_repos
    git -C "$_vm2/vm2.Glob" rm --quiet Directory.Packages.props
    git -C "$_vm2/vm2.Glob" commit --quiet -m "chore: no packages"
    run _up "vm2_repos='$_vm2'
             summary_file='$_tmp/sum.md'
             target_repos=([vm2.Ulid]='' [vm2.Glob]='')
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p target_repos"
    assert_success
    assert_output --partial "Missing 'Directory.Packages.props' in 'vm2.Glob'. Skipping the repo."
    assert_output --partial "NO_ERRORS"
    refute_output --partial "[vm2.Glob]="
    assert_output --partial "[vm2.Ulid]=\"$_vm2/vm2.Ulid\""
}

@test "resolve_arguments: reports a target whose Directory.Packages.props has an unsupported line shape" {
    _make_vm2_repos
    sed -i 's|<PackageVersion Include="xunit.v3" Version="3.0.0" />|<PackageVersion Version="3.0.0" Include="xunit.v3" />|' \
        "$_vm2/vm2.Ulid/Directory.Packages.props"
    run _up "vm2_repos='$_vm2'
             summary_file='$_tmp/sum.md'
             target_repos=([vm2.Ulid]='')
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "Invalid package lines in $_vm2/vm2.Ulid/Directory.Packages.props."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports an invalid source of truth" {
    _make_vm2_repos
    run _up "vm2_repos='$_vm2'
             sot=bogus
             summary_file='$_tmp/sum.md'
             target_repos=([vm2.Ulid]='')
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_output --partial "Invalid source of truth 'bogus'"
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: creates a temp summary file when none is given, and removes it on exit" {
    _make_vm2_repos
    run _up "vm2_repos='$_vm2'
             target_repos=([vm2.Ulid]='')
             resolve_arguments
             [[ -f \$summary_file ]] && echo \"CREATED \$summary_file\" || echo MISSING"
    assert_success
    assert_output --regexp 'CREATED /tmp/update-packages-summary-[0-9]{8}-[0-9]{6}-[^ ]+\.md'

    local _file="${output#CREATED }"
    assert [ ! -e "$_file" ]
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    _make_vm2_repos
    run _up "get_arguments --vm2-repos '$_vm2' --summary-file '$_tmp/sum.md' vm2.Ulid
             declare -p target_repos"
    assert_success
    assert_output --partial "declare -Ar target_repos=([vm2.Ulid]=\"$_vm2/vm2.Ulid\" )"
}

@test "get_arguments: -h prints the usage and exits 0 without running anything after it" {
    run _up "get_arguments -h vm2.NotThere; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: reports all resolution errors, then exits with the usage" {
    _make_vm2_repos
    run _up "get_arguments --vm2-repos '$_vm2' --summary-file '$_tmp/sum.md' vm2.NotThere vm2.NotThereEither; echo AFTER"
    assert_failure
    assert_output --partial "'vm2.NotThere'"
    assert_output --partial "'vm2.NotThereEither'"
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
