#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/changelog-and-tag.args.sh (with changelog-and-tag.usage.sh), following the seams of the
# get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each
# test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell.
#
# The script needs $GITHUB_REPOSITORY and $RELEASE_PAT, and 'git-cliff' on PATH. _ct passes the two variables (dummy
# values) unless a test asks for an environment without them, and a fake 'git-cliff' in $BATS_TEST_TMPDIR/bin stands in
# for the real one, so the tests never depend on what is installed. A missing tool is simulated by stubbing
# is_tool_present(): removing it from PATH would also hide the tools core.sh itself needs.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_unknown_argument
declare -gx  default_minver_tag_prefix

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 with the environment assignments $2 (default: dummy GITHUB_REPOSITORY and RELEASE_PAT; pass a
# different assignment, e.g. "TAG=", to run without them).
_ct() {
    local _env=${2-"GITHUB_REPOSITORY=acme/repo RELEASE_PAT=dummy"}
    # shellcheck disable=SC2086 # $_env holds one or more assignments: word splitting is intended
    env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" $_env bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/changelog-and-tag.usage.sh'
        source '$_gh_scripts_dir/changelog-and-tag.args.sh'
        $1
    "
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/git-cliff"
    chmod +x "$BATS_TEST_TMPDIR/bin/git-cliff"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves the defaults when no arguments are given" {
    run _ct "parse_arguments
             declare -p tag minver_tag_prefix reason needs_empty_commit is_release is_prerelease"
    assert_success
    assert_output --partial 'tag=""'
    assert_output --partial "minver_tag_prefix=\"$default_minver_tag_prefix\""
    assert_output --partial 'reason=""'
    assert_output --partial 'needs_empty_commit="false"'
    assert_output --partial 'is_release="false"'
    assert_output --partial 'is_prerelease="false"'
}

@test "parse_arguments: the defaults come from \$TAG, \$MINVERTAGPREFIX, \$REASON, and \$NEEDS_EMPTY_COMMIT" {
    run _ct "parse_arguments
             declare -p tag minver_tag_prefix reason needs_empty_commit" \
            "TAG=v1.2.3 MINVERTAGPREFIX=rel REASON=hotfix NEEDS_EMPTY_COMMIT=true"
    assert_success
    assert_output --partial 'tag="v1.2.3"'
    assert_output --partial 'minver_tag_prefix="rel"'
    assert_output --partial 'reason="hotfix"'
    assert_output --partial 'needs_empty_commit="true"'
}

@test "parse_arguments: --tag/-t, --minver-tag-prefix/-p, --reason/-r, and --needs-empty-commit set the variables" {
    run _ct "parse_arguments --tag v1.2.3 --minver-tag-prefix rel --reason 'a fix' --needs-empty-commit true
             declare -p tag minver_tag_prefix reason needs_empty_commit"
    assert_success
    assert_output --partial 'tag="v1.2.3"'
    assert_output --partial 'minver_tag_prefix="rel"'
    assert_output --partial 'reason="a fix"'
    assert_output --partial 'needs_empty_commit="true"'

    run _ct "parse_arguments -T v2.0.0 -P ver -R 'another fix'
             declare -p tag minver_tag_prefix reason"
    assert_success
    assert_output --partial 'tag="v2.0.0"'
    assert_output --partial 'minver_tag_prefix="ver"'
    assert_output --partial 'reason="another fix"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --tag --minver-tag-prefix --reason --needs-empty-commit; do
        run _ct "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: rejects an unknown option and any positional argument" {
    run _ct "parse_arguments --bogus; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: --bogus"
    refute_output --partial "AFTER"

    run _ct "parse_arguments v1.2.3; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument: v1.2.3"
    refute_output --partial "AFTER"
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _ct "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _ct "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently with the variables set, git, and git-cliff" {
    run _ct "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports missing \$GITHUB_REPOSITORY/\$RELEASE_PAT and returns instead of exiting" {
    local _env
    for _env in "RELEASE_PAT=dummy" "GITHUB_REPOSITORY=acme/repo" "TAG="; do
        run _ct "verify_environment
                 echo REACHED
                 has_errors && echo HAS_ERRORS || echo NO_ERRORS" "$_env"
        assert_success
        assert_output --partial "GITHUB_REPOSITORY and/or RELEASE_PAT are not set."
        assert_output --partial "REACHED"
        assert_output --partial "HAS_ERRORS"
    done
}

@test "verify_environment: reports a missing git-cliff" {
    run _ct "is_tool_present() { [[ \$1 != git-cliff ]]; }
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "'git-cliff' is not installed"
    assert_output --partial "HAS_ERRORS"
}

@test "verify_environment: reports a missing git" {
    run _ct "is_tool_present() { [[ \$1 != git ]]; }
             verify_environment
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "'git' is not installed"
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: a stable tag is a release, with the default reason 'stable release'" {
    run _ct "tag=v1.2.3
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p tag reason is_release is_prerelease"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx tag="v1.2.3"'
    assert_output --partial 'declare -rx reason="stable release"'
    assert_output --partial 'declare -rx is_release="true"'
    assert_output --partial 'declare -rx is_prerelease="false"'
}

@test "resolve_arguments: a prerelease tag is a prerelease, with the default reason 'pre-release'" {
    run _ct "tag=v1.2.3-preview.4
             resolve_arguments
             declare -p reason is_release is_prerelease"
    assert_success
    assert_output --partial 'declare -rx reason="pre-release"'
    assert_output --partial 'declare -rx is_release="false"'
    assert_output --partial 'declare -rx is_prerelease="true"'
}

@test "resolve_arguments: keeps a given reason" {
    run _ct "tag=v1.2.3
             reason='a fix'
             resolve_arguments
             declare -p reason"
    assert_success
    assert_output --partial 'declare -rx reason="a fix"'
}

@test "resolve_arguments: freezes every argument" {
    run _ct "tag=v1.2.3
             resolve_arguments
             declare -p tag reason minver_tag_prefix needs_empty_commit is_release is_prerelease"
    assert_success
    assert_output --partial "declare -rx tag="
    assert_output --partial "declare -rx reason="
    assert_output --partial "declare -rx minver_tag_prefix="
    assert_output --partial "declare -rx needs_empty_commit="
    assert_output --partial "declare -rx is_release="
    assert_output --partial "declare -rx is_prerelease="
}

@test "resolve_arguments: reports a tag that is neither a release nor a prerelease, and returns" {
    local _tag
    for _tag in '' bogus 1.2.3; do
        run _ct "tag='$_tag'
                 resolve_arguments
                 echo REACHED
                 has_errors && echo HAS_ERRORS || echo NO_ERRORS
                 declare -p is_release is_prerelease"
        assert_success
        assert_output --partial "Tag '$_tag' is not a valid semver release or prerelease tag."
        assert_output --partial "REACHED"
        assert_output --partial "HAS_ERRORS"
        assert_output --partial 'is_release="false"'
        assert_output --partial 'is_prerelease="false"'
    done
}

@test "resolve_arguments: reports a --needs-empty-commit that is not a boolean, and returns" {
    local _value
    for _value in '' yes 1 TRUE; do
        run _ct "tag=v1.2.3
                 needs_empty_commit='$_value'
                 resolve_arguments
                 echo REACHED
                 echo \"errors=\$(get_errors)\""
        assert_success
        assert_output --partial "The input '$_value' is not a valid boolean."
        assert_output --partial "REACHED"
        assert_output --partial "errors=1"
    done
}

@test "resolve_arguments: no longer checks \$GITHUB_REPOSITORY and \$RELEASE_PAT (verify_environment does)" {
    run _ct "tag=v1.2.3
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS" ""
    assert_success
    refute_output --partial "GITHUB_REPOSITORY"
    assert_output --partial "NO_ERRORS"
}

@test "resolve_arguments: reports an invalid tag prefix and an unsafe reason" {
    run _ct "tag=v1.2.3
             minver_tag_prefix='a b'
             reason='-rf /'
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "(provided 'a b')"
    assert_output --partial "The reason '-rf /' appears to be a command or contains unsafe characters."
    assert_output --partial "HAS_ERRORS"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _ct "get_arguments --tag v1.2.3-preview.1 --needs-empty-commit true
             declare -p tag is_prerelease needs_empty_commit"
    assert_success
    assert_output --partial 'declare -rx tag="v1.2.3-preview.1"'
    assert_output --partial 'declare -rx is_prerelease="true"'
    assert_output --partial 'declare -rx needs_empty_commit="true"'
}

@test "get_arguments: -h prints the usage and exits 0, even without the variables and with an invalid tag" {
    run _ct "get_arguments -h --tag bogus; echo AFTER" "TAG="
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: reports the environment and the argument errors together, then exits with the usage" {
    run _ct "get_arguments --tag bogus; echo AFTER" "TAG="
    assert_failure
    assert_output --partial "GITHUB_REPOSITORY and/or RELEASE_PAT are not set."
    assert_output --partial "Tag 'bogus' is not a valid semver release or prerelease tag."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
