#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed
#
# gh pr-create — create a PR with commit messages auto-populated.
# Registered as a gh alias:  gh alias set --shell pr-create 'bash "<path>/gh-pr-create.sh" "$@"'
#
# Usage: gh pr-create [gh-pr-create-flags...]
# Example: gh pr-create --web
#          gh pr-create --reviewer someone
#          gh pr-create --fill

set -euo pipefail

base="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo main)"
commits="$(git log --reverse --format="- %s" "origin/${base}..HEAD" 2>/dev/null)"

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
    # Fallback: inline template
    template="# Summary

<!-- Brief description of what this PR does and why. -->

## Commits

<!-- commit-list -->

## Checklist

- [ ] Commit messages follow Conventional Commits format
- [ ] CHANGELOG entries are accurate and well-written
- [ ] Tests pass locally"
fi

body="${template/<!-- commit-list -->/$commits}"

exec gh pr create --body "$body" "$@"
