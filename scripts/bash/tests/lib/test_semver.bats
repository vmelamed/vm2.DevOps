#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_semver.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx err_argument_value
declare -gx err_invalid_arguments
declare -gx failure
declare -gx semverRegex
declare -gx lib_dir

# --- is_valid_minver_settings ------------------------------------------------------------

@test "is_valid_minver_settings: accepts a plain tag prefix, with or without a prerelease id" {
    run is_valid_minver_settings "v"
    assert_success
    run is_valid_minver_settings "v" "preview.0"
    assert_success
    run is_valid_minver_settings "v" ""
    assert_success
}

@test "is_valid_minver_settings: fails on an invalid tag prefix or prerelease id" {
    # NOTE: this used to be a bug-exit (254). Regex-format validation of a caller-supplied
    # string now goes through 'error' (err_argument_value=4) and a plain 'return', not 'bug' --
    # see the summary note on lib functions no longer calling exit_if_has_errors.
    run is_valid_minver_settings "!!!"
    assert_failure "$err_argument_value"
    run is_valid_minver_settings "v" "!!!"
    assert_failure "$err_argument_value"
}

# --- get_semver_major / minor / patch / prerelease / build -------------------------------------

# --- semverRegex: the semver.org BNF ------------------------------------------------------------

@test "semverRegex: accepts the forms the SemVer 2.0.0 BNF allows" {
    local _v
    # numeric identifiers without leading zeros; alphanumeric ones may have them; build identifiers may be all digits,
    # leading zeros included (regression: a digits-only build identifier containing a 0 was rejected)
    for _v in 0.0.0 1.2.3 10.20.30 1.2.3-0 1.2.3-0a 1.2.3-00a 1.2.3-a-b 1.2.3-x.7.z.92 1.2.3--- \
              1.2.3+0 1.2.3+001 1.2.3+10 1.2.3+2024 1.2.3+a1 1.2.3+--- 1.0.0-alpha+001 1.2.3-a+b.c; do
        [[ $_v =~ $semverRegex ]] || fail "expected '$_v' to be a valid SemVer"
    done
}

@test "semverRegex: rejects the forms the SemVer 2.0.0 BNF forbids" {
    local _v
    for _v in 01.2.3 1.02.3 1.2.03 1.2.3-00 1.2.3-01 1.2.3- 1.2.3+ 1.2.3-a..b 1.2.3+a..b 1.2.3.4 v1.2.3 \
              " 1.2.3" 1.2.3_a 1.2.3-a_b 1.2.3+a_b; do
        [[ ! $_v =~ $semverRegex ]] || fail "expected '$_v' to be an invalid SemVer"
    done
}

@test "semverRegex: accepts only ASCII letters, in any locale" {
    local _locale
    # in en_US.UTF-8, bash's [A-Za-z] also matches letters like 'ä'; the regexes spell the letters out
    for _locale in C C.UTF-8 en_US.UTF-8; do
        run env LC_ALL="$_locale" bash -c "source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
                                           [[ 1.2.3-ä =~ \$semverRegex || 1.2.3+ä =~ \$semverRegex ]] && echo ACCEPTED || echo REJECTED"
        assert_output "REJECTED"
    done
}

@test "get_semver_major/minor/patch: extract their component from a release, a prerelease, and a version with build metadata" {
    local _version
    for _version in "4.2.3" "4.2.3-beta.5" "4.2.3+b1" "4.2.3-beta.5+b1"; do
        run --separate-stderr get_semver_major "$_version"
        assert_success
        assert_output "4"
        run --separate-stderr get_semver_minor "$_version"
        assert_success
        assert_output "2"
        run --separate-stderr get_semver_patch "$_version"
        assert_success
        assert_output "3"
    done
}

@test "get_semver_major/minor/patch: keep multi-digit components whole" {
    run --separate-stderr get_semver_major "10.20.30"
    assert_output "10"
    run --separate-stderr get_semver_minor "10.20.30"
    assert_output "20"
    run --separate-stderr get_semver_patch "10.20.30"
    assert_output "30"
}

@test "get_semver_prerelease: outputs the prerelease without its leading hyphen and without the build metadata" {
    run --separate-stderr get_semver_prerelease "4.2.3-beta.5"
    assert_success
    assert_output "beta.5"
    run --separate-stderr get_semver_prerelease "4.2.3-beta.5+b1"
    assert_success
    assert_output "beta.5"
    run --separate-stderr get_semver_prerelease "4.2.3-beta.5.1+b1"
    assert_success
    assert_output "beta.5.1"
}

@test "get_semver_prerelease: strips only the separator hyphen, not hyphens inside the prerelease" {
    run --separate-stderr get_semver_prerelease "1.0.0-x-y.1"
    assert_success
    assert_output "x-y.1"
    run --separate-stderr get_semver_prerelease "1.0.0-x-y.1.2.1bc"
    assert_success
    assert_output "x-y.1.2.1bc"
}

@test "get_semver_prerelease: outputs an empty value for a release, with or without build metadata" {
    run --separate-stderr get_semver_prerelease "4.2.3"
    assert_success
    assert_output ""
    run --separate-stderr get_semver_prerelease "4.2.3+b1"
    assert_success
    assert_output ""
}

@test "get_semver_build: outputs the build metadata without its leading plus sign" {
    run --separate-stderr get_semver_build "4.2.3+b1"
    assert_success
    assert_output "b1"
    run --separate-stderr get_semver_build "4.2.3-beta.5+2026-11-08.1"
    assert_success
    assert_output "2026-11-08.1"
}

@test "get_semver_build: outputs an empty value for a version without build metadata" {
    run --separate-stderr get_semver_build "4.2.3"
    assert_success
    assert_output ""
    run --separate-stderr get_semver_build "4.2.3-beta.5"
    assert_success
    assert_output ""
}

@test "get_semver_*: fail with err_argument_value and output nothing for an invalid semver" {
    local _function _version
    for _function in get_semver_major get_semver_minor get_semver_patch get_semver_prerelease get_semver_build; do
        for _version in "4.2" "v4.2.3" "4.2.3-" "" "not-a-version"; do
            # A valid match first, so a stale BASH_REMATCH would show up as output.
            [[ "9.8.7-stale" =~ $semverRegex ]]
            run --separate-stderr "$_function" "$_version"
            assert_failure "$err_argument_value"
            assert_output ""
            [[ $stderr == *"requires argument 1 to be a valid Semantic Versioning 2.0.0 string"* ]] ||
                fail "$_function '$_version': missing the error message in stderr: $stderr"
        done
    done
}

@test "get_semver_*: bug-exit with the wrong argument count" {
    local _function
    for _function in get_semver_major get_semver_minor get_semver_patch get_semver_prerelease get_semver_build; do
        run "$_function"
        assert_failure "$err_invalid_arguments"
        run "$_function" "1.2.3" "extra"
        assert_failure "$err_invalid_arguments"
    done
}

# --- compare_semver -----------------------------------------------------------------------------

@test "compare_semver: equal versions" {
    run compare_semver "1.2.3" "1.2.3"
    assert_success
}

@test "compare_semver: major/minor/patch ordering" {
    run compare_semver "2.0.0" "1.9.9"
    assert_failure "$failure"
    run compare_semver "1.9.9" "2.0.0"
    assert_failure 255
    run compare_semver "1.3.0" "1.2.9"
    assert_failure "$failure"
    run compare_semver "1.2.4" "1.2.3"
    assert_failure "$failure"
}

@test "compare_semver: a release version is greater than a prerelease of the same major.minor.patch" {
    run compare_semver "1.2.3" "1.2.3-alpha"
    assert_failure "$failure"
    run compare_semver "1.2.3-alpha" "1.2.3"
    assert_failure 255
}

@test "compare_semver: numeric prerelease identifiers compare numerically, not lexically" {
    run compare_semver "1.2.3-alpha.10" "1.2.3-alpha.9"
    assert_failure "$failure"
}

@test "compare_semver: alphanumeric prerelease identifiers always outrank numeric ones at the same position" {
    run compare_semver "1.2.3-alpha.beta" "1.2.3-alpha.9"
    assert_failure "$failure"
    run compare_semver "1.2.3-alpha.9" "1.2.3-alpha.beta"
    assert_failure 255
}

@test "compare_semver: more prerelease fields outranks fewer, when the shared prefix is equal" {
    run compare_semver "1.2.3-alpha.1.2" "1.2.3-alpha.1"
    assert_failure "$failure"
    run compare_semver "1.2.3-alpha.1" "1.2.3-alpha.1.2"
    assert_failure 255
}

@test "compare_semver: build metadata is ignored" {
    run compare_semver "1.2.3+build1" "1.2.3+build2"
    assert_success
}

@test "compare_semver: fails on an invalid semver string" {
    run compare_semver "not-a-version" "1.2.3"
    assert_failure "$err_argument_value"
}

# --- semver_eq / semver_gt / semver_lt and their *OrEqual variants -----------

@test "semver_eq: true for equal versions, false otherwise" {
    run semver_eq "1.2.3" "1.2.3"
    assert_success
    run semver_eq "1.2.3" "1.2.4"
    assert_failure "$failure"
}

@test "semver_gt: true only when strictly greater" {
    run semver_gt "1.2.4" "1.2.3"
    assert_success
    run semver_gt "1.2.3" "1.2.3"
    assert_failure "$failure"
    run semver_gt "1.2.2" "1.2.3"
    assert_failure "$failure"
}

@test "semver_gte: true when greater or equal" {
    run semver_gte "1.2.4" "1.2.3"
    assert_success
    run semver_gte "1.2.3" "1.2.3"
    assert_success
    run semver_gte "1.2.2" "1.2.3"
    assert_failure "$failure"
}

@test "semver_lt: true only when strictly less" {
    run semver_lt "1.2.2" "1.2.3"
    assert_success
    run semver_lt "1.2.3" "1.2.3"
    assert_failure "$failure"
    run semver_lt "1.2.4" "1.2.3"
    assert_failure "$failure"
}

@test "semver_lte: true when less or equal" {
    run semver_lte "1.2.2" "1.2.3"
    assert_success
    run semver_lte "1.2.3" "1.2.3"
    assert_success
    run semver_lte "1.2.4" "1.2.3"
    assert_failure "$failure"
}

# --- is_semver / is_semver_prerelease / is_semver_release and their *Tag variants -----------------

@test "is_semver: accepts full semver forms, rejects garbage" {
    run is_semver "1.2.3"
    assert_success
    run is_semver "1.2.3-alpha.1+build.1"
    assert_success
    run is_semver "not-a-version"
    assert_failure "$failure"
}

@test "is_semver_release: accepts only versions without a prerelease identifier" {
    run is_semver_release "1.2.3"
    assert_success
    run is_semver_release "1.2.3-alpha"
    assert_failure "$failure"
}

@test "is_semver_prerelease: accepts only versions with a prerelease identifier" {
    run is_semver_prerelease "1.2.3-alpha.1"
    assert_success
    run is_semver_prerelease "1.2.3"
    assert_failure "$failure"
}

@test "is_semver_tag / is_semver_release_tag / is_semver_prerelease_tag: accept the configured tag prefix" {
    run is_semver_tag "v1.2.3"
    assert_success
    run is_semver_release_tag "v1.2.3"
    assert_success
    run is_semver_release_tag "v1.2.3-alpha"
    assert_failure "$failure"
    run is_semver_prerelease_tag "v1.2.3-alpha"
    assert_success
    run is_semver_prerelease_tag "v1.2.3"
    assert_failure "$failure"
}

@test "is_semver_tag: rejects a bare version with no tag prefix at all" {
    run is_semver_tag "1.2.3"
    assert_failure "$failure"
}

@test "is_semver_tag: accepts any single alnum/underscore character as a generic tag prefix (not tied to the configured prefix)" {
    # semverTagRegex is a fixed, generic syntax check per its own docs -- it is not narrowed to
    # whatever prefix is_valid_minver_settings was actually called with.
    run is_semver_tag "x1.2.3"
    assert_success
}

# --- print_semver_regexes -------------------------------------------------------------------

@test "print_semver_regexes: dumps every documented semver regex, grouped under its own header" {
    run print_semver_regexes
    assert_success
    assert_output --partial "Semantic Version Components"
    assert_output --partial "Semantic Versions"
    assert_output --partial "Semantic Version/MinVer Tags"
    assert_output --partial "majorLabelRex"
    assert_output --partial "semverRex"
    assert_output --partial "semverTagRegex"
}
