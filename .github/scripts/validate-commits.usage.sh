#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_args_usage
declare -xr script_name

declare -xra allowed_commit_types

function usage_text()
{
    (( $# ==1 ))    || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    local _types
    printf -v _types -- '%s | ' "${allowed_commit_types[@]}"
    _types=${_types% | }

    cat << EOF
Usage:
  $script_name [<base-ref>] [--<long option> <value> | -<short option> <value> | --<long switch> | -<short switch> ]*

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

Argument:
  <base-ref>                         Required. Git ref to compare against (e.g. origin/main, a SHA, or a tag).

$_common_args
Examples:
  $script_name origin/main
  $script_name v1.0.0 --verbose
EOF
}
