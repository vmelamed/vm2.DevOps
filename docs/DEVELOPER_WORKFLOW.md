# Developer Workflow Guide

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [Developer Workflow Guide](#developer-workflow-guide)
  - [Overview](#overview)
  - [Branching Model](#branching-model)
  - [Linear History and Rebase](#linear-history-and-rebase)
    - [Why Linear History](#why-linear-history)
    - [How to Rebase](#how-to-rebase)
    - [Resolving Conflicts](#resolving-conflicts)
  - [Conventional Commits](#conventional-commits)
    - [Commit Message Format](#commit-message-format)
    - [How Commits Drive Automation](#how-commits-drive-automation)
    - [Good Commit Messages](#good-commit-messages)
    - [Commit Message Enforcement](#commit-message-enforcement)
    - [Commit Message Template](#commit-message-template)
    - [Fixing Bad Commit Messages](#fixing-bad-commit-messages)
      - [Last commit, not yet pushed](#last-commit-not-yet-pushed)
      - [Older commit, not yet pushed](#older-commit-not-yet-pushed)
      - [Already pushed to a PR branch](#already-pushed-to-a-pr-branch)
  - [Pull Request Workflow](#pull-request-workflow)
    - [Creating a PR](#creating-a-pr)
    - [CI Checks](#ci-checks)
    - [Addressing Feedback](#addressing-feedback)
    - [Merging](#merging)
  - [What Happens After Merge](#what-happens-after-merge)
    - [Reviewing the Changelog](#reviewing-the-changelog)
  - [Common Scenarios](#common-scenarios)
    - [Starting a New Feature](#starting-a-new-feature)
    - [Fixing a Bug](#fixing-a-bug)
    - [Updating Dependencies](#updating-dependencies)
    - [Running CI Locally](#running-ci-locally)
  - [Working with Multiple Developers](#working-with-multiple-developers)
  - [Quick Reference](#quick-reference)

<!-- /TOC -->

## Overview

This guide describes the day-to-day development workflow for vm2 repositories. The CI/CD framework
automates versioning, changelogs, and package publishing — your job is to write good code with good
commit messages, and the automation handles the rest.

## Branching Model

All vm2 repositories use **trunk-based development** with `main` as the sole long-lived branch.

```text
main ─────●─────●─────●─────●─────●─────
          │                  ▲
          └── feature/x ─────┘  (PR + rebase)
```

- Create short-lived feature branches for each change
- Open a pull request to `main`
- Merge via **rebase** (the only allowed merge method)
- Delete the branch after merge (automatic)

**Branch naming** is free-form, but these conventions help:

| Prefix      | Use for                  | Example                      |
| :---------- | :----------------------- | :--------------------------- |
| `feat/`     | New features             | `feat/alternation-support`   |
| `fix/`      | Bug fixes                | `fix/buffer-overflow`        |
| `ci/`       | CI/CD changes            | `ci/fix-benchmark-thresholds`|
| `docs/`     | Documentation-only       | `docs/update-readme`         |
| `refactor/` | Code restructuring       | `refactor/glob-engine`       |

## Linear History and Rebase

### Why Linear History

All repositories enforce **linear history** via branch rulesets. This means:

- **Every commit on `main` is bisect-able** — `git bisect` works perfectly because there are no
  merge commits combining unrelated changes.
- **`git log --oneline main` is the complete story** — no diverge-and-merge topology, no
  interleaved commits from different branches.
- **Changelogs are simple** — git-cliff walks `main` linearly to produce the changelog. Each
  commit appears exactly once, in order.
- **Version calculation is deterministic** — MinVer counts commits from the last tag along a
  single path.

### How to Rebase

Before your PR can be merged, your branch must be up to date with `main`. If `main` has moved
ahead, **`rebase` your branch**:

```bash
# Fetch the latest main
git fetch origin main

# Rebase your branch onto main
git rebase origin/main

# Push (force-with-lease is the safe force-push)
git push --force-with-lease
```

`--force-with-lease` is safe:

- It only overwrites commits **you** authored on your branch
- If someone else somehow pushed to your branch, the push **fails** instead of overwriting their work
- It's the default recommendation everywhere in this project

### Resolving Conflicts

During a rebase, Git replays your commits one at a time on top of the new base. If a conflict
occurs:

```bash
# Git stops and shows you the conflicting files
# Fix the conflicts in your editor, then:
git add <resolved-files>
git rebase --continue

# To abort and go back to where you started:
git rebase --abort
```

The advantage over merge conflicts: you resolve one commit at a time, so each conflict is small
and focused. With merge, you get all conflicts at once.

## Conventional Commits

### Commit Message Format

All vm2 repositories use [Conventional Commits](https://www.conventionalcommits.org/). The format of the commit messages can be
described with the following grammar:

```ebnf
commit-message = subject, [ LF, body ] ;
subject        = type, [ "(", scope, ")" ], [ "!" ], ": ", description ;
type           = "style" | "build" | "feat" | "test" | "fix" | "refactor"
               | "perf" | "security" | "docs" | "chore" | "revert" | "remove"
               | "remove" | "ci" | "devops" ;
scope          = noun ;
description    = non-empty string ;
body           = free-form text ;
```

Where:

- Message type:       Required, one of: style build feat test fix refactor perf security docs chore revert remove ci devops
- Scope:              Optional. A noun describing the section of the codebase affected by the change (e.g., 'api', 'ui', 'docs')
- Breaking Change:    Optional. '!' before ':' signals a breaking change
- Description:        Required. A short description of the change

Examples:

```text
feat(api)!: change the 'getUserData' method of the API endpoint for user data
fix(ui):    correct button alignment on homepage
chore(ci):  update GitHub Actions workflow
```

| Type       | Triggers       | Use when                                              |
| :--------- | :------------- | :---------------------------------------------------- |
| !          | **major bump** | creates backwards compatibility breaking changes      |
| `style`    | no bump        | Code style changes (whitespace, formatting, etc.)     |
| `build`    | no bump        | Changes that affect the build system or dependencies  |
| `feat`     | **minor bump** | Adding new functionality                              |
| `test`     | no bump        | Adding or updating tests                              |
| `fix`      | **patch bump** | Fixing a bug                                          |
| `refactor` | no bump        | Code restructuring without behavior change            |
| `perf`     | no bump        | Performance improvement                               |
| `security` | no bump        | Security fixes                                        |
| `docs`     | no bump        | Documentation changes only                            |
| `chore`    | no bump        | Build, CI, tooling, dependency updates                |
| `revert`   | no bump        | Reverting a previous commit                           |
| `remove`   | no bump        | Removing code or functionality                        |
| `ci`       | no bump        | Continuous Integration related changes                |
| `devops`   | no bump        | DevOps related changes                                |

**Breaking changes** trigger a **major** bump. Mark them with `!` after the type/scope:

```text
refactor(core)!: rewrite matching engine
```

### How Commits Drive Automation

Your commit messages directly control what happens when code reaches `main`:

```text
feat(parser): add alternation support  →  minor version bump  →  v1.3.0-preview.1
fix: correct boundary check            →  patch version bump  →  v1.2.4-preview.1
refactor!: rewrite engine              →  major version bump  →  v2.0.0-preview.1
```

1. **git-cliff** parses commit messages to generate `CHANGELOG.md` entries
2. **MinVer** + version computation scripts determine the next version from the highest-impact
   commit type since the last tag
3. **Prerelease** publishes automatically after CI succeeds on main
4. **Stable release** is triggered manually via `workflow_dispatch`

### Good Commit Messages

```text
✅ feat(glob): add support for character class negation [^abc]
✅ fix: prevent stack overflow on deeply nested patterns
✅ docs: add DEVELOPER_WORKFLOW.md
✅ build(nuget): update BenchmarkDotNet to 0.14.0

❌ update stuff
❌ fix bug
❌ WIP
❌ changes
```

Each commit message appears **verbatim** in the changelog. Write them as if they're release notes
— because they are.

> [!TIP] If you really just want to save your work you can commit with a message like `chore: WIP [skip ci]` and push — this
> will not trigger a release or affect the changelog. You can even use `git rebase -i origin/main` (interactive rebase) to
> squash or reorder your WIP commits before merging.

### Commit Message Enforcement

Conventional Commits are enforced at two levels:

1. **Local git hook** — fast feedback at `git commit` time. To enable, run once per clone:

   ```bash
   git config core.hooksPath ~/repos/vm2/vm2.DevOps/scripts/githooks
   ```

   The hook rejects commits whose subject line doesn't match the Conventional Commits format.
   You may try to bypass it with `git commit --no-verify`, but CI will still catch it.

2. **CI check** — the `validate-commits` job in `_ci.yaml` validates all commit messages in the
   PR range. This is the hard gate — it cannot be bypassed.

### Commit Message Template

A commit message template shows the allowed types and format in your editor every time you run
`git commit`. To enable, run once per clone:

```bash
git config commit.template ~/repos/vm2/vm2.DevOps/scripts/githooks/.gitmessage
```

> [!NOTE] `repo-setup.sh` configures both settings automatically via `git config --local` on the first run of the script. You
> only need to run the commands below if you are setting up a clone manually.

Both settings (hook + template) can be set in one go:

```bash
git config --local core.hooksPath ~/repos/vm2/vm2.DevOps/scripts/githooks
git config --local commit.template ~/repos/vm2/vm2.DevOps/scripts/githooks/.gitmessage
```

### Fixing Bad Commit Messages

If a commit slips through with the wrong message (e.g. you used `--no-verify`, or the hook
wasn't configured yet), here's how to fix it depending on when you catch it.

#### Last commit, not yet pushed

The simplest case — `--amend` rewrites only the most recent commit:

```bash
git commit --amend -m "fix: corrected message"
```

Git opens your editor (or accepts `-m` inline), replaces the commit with a new one that has
the corrected message and the same code changes. The commit gets a new SHA.

#### Older commit, not yet pushed

Use interactive rebase to rewrite any commit in your branch:

```bash
git rebase -i origin/main
```

Git opens your editor with the list of commits on your branch:

```text
pick a1b2c3d feat: add widget
pick d4e5f6a bad message here         <-- this one needs fixing
pick f7g8h9i fix: handle null input
```

Change `pick` to `reword` on the bad line:

```text
pick a1b2c3d feat: add widget
reword d4e5f6a bad message here       <-- git will pause here
pick f7g8h9i fix: handle null input
```

Save and close. Git replays the commits in order, pausing at each `reword` to let you type the
corrected message. The reworded commit (and every commit after it) gets a new SHA because
history changed.

> [!NOTE] Other useful interactive rebase commands: `edit` (pause to change code + message),
> `squash` (fold into previous commit, keep both messages), `fixup` (fold into previous, discard
> message), `drop` (delete the commit entirely).

#### Already pushed to a PR branch

Same as above, then force-push:

```bash
git push --force-with-lease
```

`--force-with-lease` is the safe variant of `--force`: it checks that the remote branch hasn't
moved since your last fetch. If someone else pushed in the meantime, it refuses instead of
silently overwriting their work. Since you're a solo developer this is just a safety habit, but
a good one.

CI re-runs automatically after the force-push and `validate-commits` will pass.

## Pull Request Workflow

### Creating a PR

```bash
# Create your branch and make changes
git checkout -b feat/my-feature
# ... edit, commit ...

# Push and create PR
git push -u origin feat/my-feature
gh pr create --fill   # or use the GitHub UI, or Visual Studio Code UI, etc...
```

### CI Checks

When you open a PR, the CI pipeline runs automatically:

```text
prerun-ci (gather parameters)
    ├── run-ci (_ci.yaml)
    │       ├── validate-commits (PR only: Conventional Commits check)
    │       ├── validate-input
    │       ├── build (compile)
    │       ├── test (unit tests + coverage)
    │       ├── benchmarks (performance)
    │       └── pack (NuGet validation)
    └── postrun-ci (gate check: Postrun-CI ✅ or ❌)
```

The branch ruleset requires the `Postrun-CI` check to pass before merging. This single gate check
replaces per-job required checks which are unpredictable with reusable workflows and matrix strategies.

### Addressing Feedback

When you push additional commits to your PR branch:

- CI runs again on the updated code
- Stale review approvals are automatically dismissed
- If your branch falls behind `main`, rebase (see [How to Rebase](#how-to-rebase))

### Merging

Once CI passes and reviews are approved:

1. Click **"Rebase and merge"** (the only allowed merge method)
2. The branch is automatically deleted after merge
3. Prerelease automation kicks in (see below)

## What Happens After Merge

After your PR is rebased onto `main`:

1. **CI runs** on the push to `main` (verifies the rebased code)
2. **Prerelease workflow** triggers automatically after CI succeeds:
   - Computes next prerelease version from commit messages
   - Updates `CHANGELOG.md`
   - Creates a prerelease Git tag
   - Publishes a prerelease NuGet package
3. The prerelease package is available for testing immediately
4. **Review the generated changelog entry** (see below)

### Reviewing the Changelog

After each prerelease, `git-cliff` generates a changelog entry from your commit messages and pushes it to `main`. This is the
best moment to review and curate the entry — before a stable release bakes it in permanently.

If the generated entry needs cleanup (e.g., rewording, grouping related items, adding context for breaking changes):

```bash
# Create a short-lived branch off the latest main (which now has the prerelease tag)
git checkout main && git pull
git checkout -b fix/changelog

# Edit CHANGELOG.md
# ... review, curate, and save ...

git add CHANGELOG.md
git commit -m "docs: curate changelog for vX.Y.Z-preview.N"
git push -u origin fix/changelog
gh pr create --fill
```

This lightweight PR merges quickly and ensures the changelog is accurate before any stable promotion.

**Stable releases** are triggered **manually only** when ready — see
[RELEASE_PROCESS.md](RELEASE_PROCESS.md).

## Common Scenarios

### Starting a New Feature

```bash
git checkout main && git pull
git checkout -b feat/my-feature

# Make changes, commit with conventional messages
git add .
git commit -m "feat(parser): add alternation support"

# Push and create PR
git push -u origin feat/my-feature
gh pr create --title "feat(parser): add alternation support" --body "..."
```

### Fixing a Bug

```bash
git checkout main && git pull
git checkout -b fix/boundary-check

git add .
git commit -m "fix: prevent off-by-one in boundary check"

git push -u origin fix/boundary-check
gh pr create --fill
```

### Updating Dependencies

Dependabot handles most dependency updates automatically via weekly PRs. For manual updates:

```bash
git checkout main && git pull
git checkout -b chore/update-deps

dotnet outdated
dotnet update                          # update packages
dotnet restore --force-evaluate        # regenerate lock files

git add .
git commit -m "chore: update NuGet dependencies"
git push -u origin chore/update-deps
```

### Running CI Locally

The CI scripts can be run locally for faster iteration. The bash library is available directly:

```bash
# From your repo root:
source /path/to/vm2.DevOps/scripts/bash/lib/core.sh

# Build
dotnet build YourProject.slnx --configuration Release

# Run tests with coverage
dotnet test --configuration Release /p:CollectCoverage=true

# Run benchmarks
dotnet run --project benchmarks/YourBenchmarks/YourBenchmarks.csproj -c Release
```

## Working with Multiple Developers

The rebase workflow naturally prevents stepping on each other's work:

1. **Each developer works on their own branch** — no shared branches
2. **PRs are the only path to `main`** — the branch ruleset blocks direct pushes
3. **Rebase before merge** — each developer resolves conflicts with the current `main`, not with
   other branches
4. **`--force-with-lease` protects your branch** — if somehow another developer pushed to your
   branch, your push fails safely instead of overwriting their commits
5. **Stale review dismissal** — if you push new commits after approval, the review is reset,
   ensuring reviewers see the final code

## Quick Reference

```bash
# Daily workflow
git checkout main && git pull
git checkout -b feat/my-feature
# ... code and commit ...
git push -u origin feat/my-feature
gh pr create --fill

# Rebase if main moved ahead
git fetch origin main
git rebase origin/main
git push --force-with-lease

# After PR is merged — main auto-updates
git checkout main && git pull
git branch -d feat/my-feature   # clean up local branch
```

**Key rules:**

- Always use conventional commit messages
- Always rebase (never merge) to update your branch
- Always use `--force-with-lease` (never `--force`)
- Let the CI pipeline tell you if something is wrong
- Let the automation handle versioning and changelogs
