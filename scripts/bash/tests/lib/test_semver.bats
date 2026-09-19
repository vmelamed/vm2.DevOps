#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/lib/_semver.sh, as it behaves TODAY -- written before
# the tier-4 predicate/validator convention refactor so the refactor has a safety net.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# --- validate_semverTagComponents ------------------------------------------------------------

@test "validate_semverTagComponents: accepts a plain tag prefix, with or without a prerelease id" {
    run validate_semverTagComponents "v"
    assert_success
    run validate_semverTagComponents "v" "preview.0"
    assert_success
    run validate_semverTagComponents "v" ""
    assert_success
}

@test "validate_semverTagComponents: bug-exits on an invalid tag prefix or prerelease id" {
    run validate_semverTagComponents "!!!"
    assert_failure 254
    run validate_semverTagComponents "v" "!!!"
    assert_failure 254
}

# --- compare_semver -----------------------------------------------------------------------------

@test "compare_semver: equal versions" {
    run compare_semver "1.2.3" "1.2.3"
    assert_success
}

@test "compare_semver: major/minor/patch ordering" {
    run compare_semver "2.0.0" "1.9.9"
    assert_failure 1
    run compare_semver "1.9.9" "2.0.0"
    assert_failure 255
    run compare_semver "1.3.0" "1.2.9"
    assert_failure 1
    run compare_semver "1.2.4" "1.2.3"
    assert_failure 1
}

@test "compare_semver: a release version is greater than a prerelease of the same major.minor.patch" {
    run compare_semver "1.2.3" "1.2.3-alpha"
    assert_failure 1
    run compare_semver "1.2.3-alpha" "1.2.3"
    assert_failure 255
}

@test "compare_semver: numeric prerelease identifiers compare numerically, not lexically" {
    run compare_semver "1.2.3-alpha.10" "1.2.3-alpha.9"
    assert_failure 1
}

@test "compare_semver: alphanumeric prerelease identifiers always outrank numeric ones at the same position" {
    run compare_semver "1.2.3-alpha.beta" "1.2.3-alpha.9"
    assert_failure 1
    run compare_semver "1.2.3-alpha.9" "1.2.3-alpha.beta"
    assert_failure 255
}

@test "compare_semver: more prerelease fields outranks fewer, when the shared prefix is equal" {
    run compare_semver "1.2.3-alpha.1.2" "1.2.3-alpha.1"
    assert_failure 1
    run compare_semver "1.2.3-alpha.1" "1.2.3-alpha.1.2"
    assert_failure 255
}

@test "compare_semver: build metadata is ignored" {
    run compare_semver "1.2.3+build1" "1.2.3+build2"
    assert_success
}

@test "compare_semver: bug-exits on an invalid semver string" {
    run compare_semver "not-a-version" "1.2.3"
    assert_failure 254
}

# --- semver_equal / semver_greaterThan / semver_lessThan and their *OrEqual variants -----------

@test "semver_equal: true for equal versions, false otherwise" {
    run semver_equal "1.2.3" "1.2.3"
    assert_success
    run semver_equal "1.2.3" "1.2.4"
    assert_failure 1
}

@test "semver_greaterThan: true only when strictly greater" {
    run semver_greaterThan "1.2.4" "1.2.3"
    assert_success
    run semver_greaterThan "1.2.3" "1.2.3"
    assert_failure 1
    run semver_greaterThan "1.2.2" "1.2.3"
    assert_failure 1
}

@test "semver_greaterThanOrEqual: true when greater or equal" {
    run semver_greaterThanOrEqual "1.2.4" "1.2.3"
    assert_success
    run semver_greaterThanOrEqual "1.2.3" "1.2.3"
    assert_success
    run semver_greaterThanOrEqual "1.2.2" "1.2.3"
    assert_failure 1
}

@test "semver_lessThan: true only when strictly less" {
    run semver_lessThan "1.2.2" "1.2.3"
    assert_success
    run semver_lessThan "1.2.3" "1.2.3"
    assert_failure 1
    run semver_lessThan "1.2.4" "1.2.3"
    assert_failure 1
}

@test "semver_lessThanOrEqual: true when less or equal" {
    run semver_lessThanOrEqual "1.2.2" "1.2.3"
    assert_success
    run semver_lessThanOrEqual "1.2.3" "1.2.3"
    assert_success
    run semver_lessThanOrEqual "1.2.4" "1.2.3"
    assert_failure 1
}

# --- is_semver / is_semverPrerelease / is_semverRelease and their *Tag variants -----------------

@test "is_semver: accepts full semver forms, rejects garbage" {
    run is_semver "1.2.3"
    assert_success
    run is_semver "1.2.3-alpha.1+build.1"
    assert_success
    run is_semver "not-a-version"
    assert_failure 1
}

@test "is_semverRelease: accepts only versions without a prerelease identifier" {
    run is_semverRelease "1.2.3"
    assert_success
    run is_semverRelease "1.2.3-alpha"
    assert_failure 1
}

@test "is_semverPrerelease: accepts only versions with a prerelease identifier" {
    run is_semverPrerelease "1.2.3-alpha.1"
    assert_success
    run is_semverPrerelease "1.2.3"
    assert_failure 1
}

@test "is_semverTag / is_semverReleaseTag / is_semverPrereleaseTag: accept the configured tag prefix" {
    run is_semverTag "v1.2.3"
    assert_success
    run is_semverReleaseTag "v1.2.3"
    assert_success
    run is_semverReleaseTag "v1.2.3-alpha"
    assert_failure 1
    run is_semverPrereleaseTag "v1.2.3-alpha"
    assert_success
    run is_semverPrereleaseTag "v1.2.3"
    assert_failure 1
}

@test "is_semverTag: rejects a bare version with no tag prefix at all" {
    run is_semverTag "1.2.3"
    assert_failure 1
}

@test "is_semverTag: accepts any single alnum/underscore character as a generic tag prefix (not tied to the configured prefix)" {
    # semverTagRegex is a fixed, generic syntax check per its own docs -- it is not narrowed to
    # whatever prefix validate_semverTagComponents was actually called with.
    run is_semverTag "x1.2.3"
    assert_success
}
