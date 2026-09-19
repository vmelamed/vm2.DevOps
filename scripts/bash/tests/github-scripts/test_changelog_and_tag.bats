#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for .github/scripts/changelog-and-tag.sh, as it behaves TODAY.
#
# changelog-and-tag.sh is a CI-only script (updates CHANGELOG.md via git-cliff, then creates
# and pushes a Git tag) -- it has no meaningful "standalone" mode distinct from CI beyond the
# `if $ci; then git config ...` branch, which one test covers directly.
#
# Unlike the other .github/scripts tests, this one does NOT mock git or git-cliff: both are
# real, local-only, deterministic tools with no network dependency once a local bare repo
# stands in for "origin" -- using the real tools exercises the actual commit-range/config
# selection logic faithfully, which a fake would have to reimplement anyway. Each fixture is a
# real repo with a real local bare "origin" remote (so `git push`/`--force-with-lease` work
# without touching the network), a real CHANGELOG.md, and minimal, self-contained
# cliff.prerelease.toml / cliff.release-header.toml configs written inline below (this repo
# doesn't ship its own -- those live in each *consumer* repo -- so the fixture can't depend on
# a sibling vm2 repo happening to be checked out; that would break in CI).
#
# $GITHUB_REPOSITORY and $RELEASE_PAT are only ever checked for presence (never used to call
# any API in this script), so dummy values are enough.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"
_changelog_and_tag="$_gh_scripts_dir/changelog-and-tag.sh"

# Minimal, self-contained git-cliff configs -- functionally equivalent to the real vm2 templates
# (conventional-commits grouping, same tag_pattern shape) but inlined so this test has no
# dependency on any other repo being checked out on disk.
_write_cliff_configs() {
    local _dir="$1/changelog"
    mkdir -p "$_dir"
    cat > "$_dir/cliff.prerelease.toml" <<'EOF'
[changelog]
header = """# Changelog\n"""
body = """{%- if tag is defined -%}
{%- set current_tag = tag -%}
{%- elif version is defined -%}
{%- set current_tag = version -%}
{%- else -%}
{%- set current_tag = "Unreleased" -%}
{%- endif -%}
{%- if timestamp is defined -%}
{%- set current_date = timestamp | date(format="%Y-%m-%d") -%}
{%- else -%}
{%- set current_date = now() | date(format="%Y-%m-%d") -%}
{%- endif -%}
{%- set grouped = commits | group_by(attribute="group") -%}
{%- if grouped | length > 0 -%}
## {{ current_tag }} - {{ current_date }}
{% for group, commits in grouped %}
### {{ group }}
{% for commit in commits %}
- {% if commit.breaking %}**BREAKING:** {% endif %}{{ commit.message | trim }}
{%- endfor %}
{% endfor -%}
{%- else -%}
## {{ current_tag }} - {{ current_date }}

### Internal

DevOps changes only.
{%- endif -%}
"""
trim = false
footer = ""

[git]
conventional_commits = true
filter_unconventional = true
tag_pattern = "^v(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)-(?:0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\\.(?:0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$"
protect_breaking_commits = true
commit_parsers = [
    { message = "^style", group = "Internal" },
    { message = "^build", skip = true },
    { message = "^feat", group = "Added" },
    { message = "^tests?", group = "Internal" },
    { message = "^fix", group = "Fixed" },
    { message = "^refactor", group = "Internal" },
    { message = "^perf", group = "Performance" },
    { message = "^security", group = "Security" },
    { message = "^docs?(\\([^)]*\\))?!?:", group = "Internal" },
    { message = "^chore", group = "Internal" },
    { message = "^revert", group = "Removed" },
    { message = "^remove", group = "Removed" },
    { message = "^ci", skip = true },
    { message = "^devops", skip = true },
]
EOF
    cat > "$_dir/cliff.release-header.toml" <<'EOF'
[changelog]
header = """# Changelog\n"""
body = """{%- if tag is defined -%}
{%- set current_tag = tag -%}
{%- elif version is defined -%}
{%- set current_tag = version -%}
{%- else -%}
{%- set current_tag = "Unreleased" -%}
{%- endif -%}
{%- if timestamp is defined -%}
{%- set current_date = timestamp | date(format="%Y-%m-%d") -%}
{%- else -%}
{%- set current_date = now() | date(format="%Y-%m-%d") -%}
{%- endif -%}
## {{ current_tag }} - {{ current_date }}

See prereleases below.
"""
trim = false
footer = ""

[git]
conventional_commits = true
filter_unconventional = true
tag_pattern = "^v(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$"
protect_breaking_commits = true
commit_parsers = [
    { message = "^style", group = "Internal" },
    { message = "^build", skip = true },
    { message = "^feat", group = "Added" },
    { message = "^tests?", group = "Internal" },
    { message = "^fix", group = "Fixed" },
    { message = "^refactor", group = "Internal" },
    { message = "^perf", group = "Performance" },
    { message = "^security", group = "Security" },
    { message = "^docs?(\\([^)]*\\))?!?:", group = "Internal" },
    { message = "^chore", group = "Internal" },
    { message = "^revert", group = "Removed" },
    { message = "^remove", group = "Removed" },
    { message = "^ci", skip = true },
    { message = "^devops", skip = true },
]
EOF
}

_make_fixture() {
    local _dir="$1"
    mkdir -p "$_dir/origin.git" "$_dir/repo"
    git init --quiet --bare "$_dir/origin.git"
    git -C "$_dir/repo" init --quiet
    git -C "$_dir/repo" config user.email "test@test.local"
    git -C "$_dir/repo" config user.name "test"
    git -C "$_dir/repo" remote add origin "$_dir/origin.git"
    echo "# Changelog" > "$_dir/repo/CHANGELOG.md"
    _write_cliff_configs "$_dir/repo"
    echo hello > "$_dir/repo/README.md"
    git -C "$_dir/repo" add -A
    git -C "$_dir/repo" commit --quiet -m "chore: init"
    git -C "$_dir/repo" push --quiet -u origin main
}

# $1 = repo dir, $2 = env-var assignments to prepend (in addition to the required
# GITHUB_REPOSITORY/RELEASE_PAT, already supplied), $@ (rest) = CLI arguments.
_run_changelog_and_tag() {
    local _dir="$1"; shift
    local _env_vars="$1"; shift
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" GITHUB_REPOSITORY=acme/repo RELEASE_PAT=dummy bash -c "
        cd '$_dir' && $_env_vars bash '$_changelog_and_tag' $*
    "
}

# --- happy path ---------------------------------------------------------------------------

@test "changelog-and-tag: creates a prerelease tag and updates the changelog" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag v0.2.0-preview.1
    assert_success
    assert_output --partial "CHANGELOG updated and pushed"
    assert_output --partial "Tag v0.2.0-preview.1 created and pushed"

    run cat "$BATS_TEST_TMPDIR/repo/CHANGELOG.md"
    assert_output --partial "v0.2.0-preview.1"

    run git -C "$BATS_TEST_TMPDIR/repo" show v0.2.0-preview.1 --no-patch
    assert_output --partial "Prerelease v0.2.0-preview.1"
    assert_output --partial "Reason: pre-release"

    run git -C "$BATS_TEST_TMPDIR/origin.git" tag --list
    assert_output --partial "v0.2.0-preview.1"
}

@test "changelog-and-tag: creates a stable release tag with the 'stable release' default reason" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag v1.0.0
    assert_success

    run git -C "$BATS_TEST_TMPDIR/repo" show v1.0.0 --no-patch
    assert_output --partial "Release v1.0.0"
    assert_output --partial "Reason: stable release"
}

@test "changelog-and-tag: an explicit --reason overrides the tag-type default" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag v0.2.0-preview.1 --reason "'custom reason'"
    assert_success

    run git -C "$BATS_TEST_TMPDIR/repo" show v0.2.0-preview.1 --no-patch
    assert_output --partial "Reason: custom reason"
}

@test "changelog-and-tag: --needs-empty-commit creates and pushes an empty commit first" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag v1.0.0 --needs-empty-commit true
    assert_success
    assert_output --partial "Empty commit created"

    run git -C "$BATS_TEST_TMPDIR/repo" log --oneline
    assert_output --partial "chore: promote to stable v1.0.0"
}

@test "changelog-and-tag: in CI mode, configures the git identity before committing" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" 'GITHUB_ACTIONS=true' --quiet --tag v0.2.0-preview.1
    assert_success

    run git -C "$BATS_TEST_TMPDIR/repo" config user.name
    assert_output "vmelamed"
    run git -C "$BATS_TEST_TMPDIR/repo" config user.email
    assert_output "vmelamed@users.noreply.github.com"
}

# --- degraded but non-fatal paths ------------------------------------------------------------

@test "changelog-and-tag: warns and skips the changelog update when the cliff config is missing, but still tags" {
    _make_fixture "$BATS_TEST_TMPDIR"
    rm "$BATS_TEST_TMPDIR/repo/changelog/cliff.prerelease.toml"
    git -C "$BATS_TEST_TMPDIR/repo" commit --quiet -am "chore: remove cliff config"

    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag v0.2.0-preview.1
    assert_success
    assert_output --partial "Missing changelog/cliff.prerelease.toml; skipping changelog update"
    assert_output --partial "Tag v0.2.0-preview.1 created and pushed"
}

# --- validation failures ---------------------------------------------------------------------

@test "changelog-and-tag: rejects a tag that is not a valid semver release or prerelease" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag notasemver
    assert_failure
    assert_output --partial "is not a valid semver release or prerelease tag"
}

@test "changelog-and-tag: fails fast when CHANGELOG.md is missing" {
    _make_fixture "$BATS_TEST_TMPDIR"
    rm "$BATS_TEST_TMPDIR/repo/CHANGELOG.md"
    git -C "$BATS_TEST_TMPDIR/repo" commit --quiet -am "chore: remove changelog"

    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag v0.2.0-preview.1
    assert_failure
    assert_output --partial "Missing CHANGELOG.md in repo root"
}

@test "changelog-and-tag: fails when the tag already exists" {
    _make_fixture "$BATS_TEST_TMPDIR"
    git -C "$BATS_TEST_TMPDIR/repo" tag v0.2.0-preview.1
    git -C "$BATS_TEST_TMPDIR/repo" push --quiet origin v0.2.0-preview.1

    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag v0.2.0-preview.1
    assert_failure
    assert_output --partial "Failed to create tag v0.2.0-preview.1"
}

@test "changelog-and-tag: fails cleanly (not with an unbound-variable crash) when \$RELEASE_PAT is entirely unset" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" GITHUB_REPOSITORY=acme/repo \
        bash -c "cd '$BATS_TEST_TMPDIR/repo' && bash '$_changelog_and_tag' --quiet --tag v0.2.0-preview.1"
    assert_failure
    assert_output --partial "GITHUB_REPOSITORY and/or RELEASE_PAT are not set"
    refute_output --partial "unbound variable"
}

# --- argument handling ---------------------------------------------------------------------

@test "changelog-and-tag: fails with a clear error when --tag is given without a value" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --tag
    assert_failure
    assert_output --partial "Missing value for --tag"
}

@test "changelog-and-tag: fails on an unknown option" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' --quiet --bogus
    assert_failure
    assert_output --partial "Unknown argument: --bogus"
}

@test "changelog-and-tag: -h prints usage and exits 0" {
    _make_fixture "$BATS_TEST_TMPDIR"
    run _run_changelog_and_tag "$BATS_TEST_TMPDIR/repo" '' -h
    assert_success
    assert_output --partial "Usage:"
}
