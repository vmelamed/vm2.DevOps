#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed
#
# gh create-pr — create a PR with commit messages auto-populated.
# Registered as a gh alias:  gh alias set --shell create-pr 'bash "<path>/create-pr.sh" "$@"'

#-------------------------------------------------------------------------------
# @description Creates a GitHub pull request whose body is auto-populated with the list of commits between the default
# branch and HEAD, merged into the repository's PR template. Falls back to a hard-coded minimal template if no
# '.github/PULL_REQUEST_TEMPLATE.md' or '.github/pull_request_template.md' is found in the current repository. All
# command-line arguments are forwarded verbatim to 'gh pr create'.
#
# Notes:
#   - The commit list replaces the literal placeholder '<!-- commit-list -->' in the template (or the fallback template) with
#     a Markdown bullet list of commit subjects, oldest first.
#   - If there are no commits between the default branch and HEAD, the placeholder is replaced with the literal text
#     "_(no commits)_".
#   - Intended to be registered as a 'gh' alias so it can be invoked as 'gh create-pr ...'.
#
# @arg $@ string Any flags accepted by 'gh pr create' (e.g. '--web', '--reviewer <user>', '--fill'); forwarded as-is.
#
# @exitcode Whatever 'gh pr create' exits with (the script 'exec's into it as the last step).
#
# @stdout A warning if no PR template file is found, followed by whatever 'gh pr create' prints.
#
# @example
#   gh create-pr --web
# @example
#   gh create-pr --reviewer someone
# @example
#   gh create-pr --fill
#-------------------------------------------------------------------------------

set -euo pipefail

base="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo main)"
commits="$(git log --reverse --format="- %s" "origin/$base..HEAD" 2>/dev/null)"

if [[ -z "$commits" ]]; then
    commits="_(no commits)_"
fi

# Try to find the PR template
template=""
for t in .github/PULL_REQUEST_TEMPLATE.md .github/pull_request_template.md; do
    if [[ -f "$t" ]]; then
        template="$(cat "$t")"
        break
    fi
done

if [[ -z "$template" ]]; then
    echo "⚠️  WARNING: No PR template found in .github/PULL_REQUEST_TEMPLATE.md. Using hard-coded, fallback template." >&2
    # Fallback: inline template
    template="# Summary

<!-- Brief description of what this PR does and why. -->

## Commits

<!-- commit-list -->

## Checklist

- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) format
- [ ] Tests pass locally, and cover new code and edge cases. Test coverage is above 80%.
- [ ] It is not expected that the performance will degrade by more than 20%
- [ ] Documentation is updated if necessary"
fi

body="${template/<!-- commit-list -->/$commits}"

exec gh pr create --body "$body" "$@"
