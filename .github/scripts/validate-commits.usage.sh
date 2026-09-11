#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

declare -xra allowed_commit_types

function usage_text()
{
    local _long_text=$1
    local _common_switches=""
    local _common_vars=""

    if $_long_text; then

        _common_switches="\

Switches:
$common_switches"

        _common_vars="\

Environment Variables:
$common_vars"
    fi

    local _types
    printf -v _types -- '%s | ' "${allowed_commit_types[@]}"
    _types=${_types% | }

    cat << EOF
Usage:
  $script_name --base-ref <ref> [options]

Description:
  Validates that all commit messages between <base-ref> and HEAD follow the Conventional Commits specification
  (https://www.conventionalcommits.org). Merge commits are automatically skipped. Commit message format:

  commit-message = subject, [ LF, body ] ;
  subject        = type, [ "(", scope, ")" ], [ "!" ], ": ", description ;
  type           = $_types ;
  scope          = noun ;
  description    = non-empty string ;
  body           = free-form text ;

  Message type:       Required, one of: style build feat test tests fix refactor perf security doc docs chore revert remove ci
                      devops
  Scope:              Optional. A noun describing the section of the codebase affected by the change (e.g., 'api', 'ui', 'docs')
  Breaking Change:    Optional. '!' before ':' signals a breaking change
  Description:        Required. A short description of the change

  Examples:
    feat(api)!: change the 'getUserData' method of the API endpoint for user data
    fix(ui):    correct button alignment on homepage
    chore(ci):  update GitHub Actions workflow

Options:
  -b, --base-ref <ref>          Required. Git ref to compare against (e.g. origin/main, a SHA, or a tag).
$_common_switches$_common_vars
Examples:
  $script_name --base-ref origin/main
  $script_name --base-ref v1.0.0 --verbose
EOF
}
