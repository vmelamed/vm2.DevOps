# Developer Workflow Guide

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [Developer Workflow Guide](#developer-workflow-guide)
  - [Overview](#overview)
  - [Branching Model](#branching-model)
  - [The Standard Workflow](#the-standard-workflow)
    - [Step 1: Update Your Local Main](#step-1-update-your-local-main)
    - [Step 2: Create a Feature Branch](#step-2-create-a-feature-branch)
    - [Step 3: Make Changes and Commit](#step-3-make-changes-and-commit)
    - [Step 4: Push and Open a Pull Request](#step-4-push-and-open-a-pull-request)
    - [Step 5: CI Runs Automatically](#step-5-ci-runs-automatically)
    - [Step 6: Merge the Pull Request](#step-6-merge-the-pull-request)
    - [Step 7: Clean Up Locally](#step-7-clean-up-locally)
  - [What Happens After Merge](#what-happens-after-merge)
    - [Reviewing the Changelog](#reviewing-the-changelog)
    - [Changelog-Only Cleanup PR](#changelog-only-cleanup-pr)
  - [Linear History and Rebase](#linear-history-and-rebase)
    - [Why Linear History](#why-linear-history)
  - [Conventional Commits](#conventional-commits)
    - [Commit Message Format](#commit-message-format)
    - [How Commits Drive Automation](#how-commits-drive-automation)
    - [Good Commit Messages](#good-commit-messages)
    - [Commit Message Enforcement](#commit-message-enforcement)
    - [Commit Message Template](#commit-message-template)
  - [Handling PR Feedback](#handling-pr-feedback)
    - [Simple Fix: Amend and Force-Push](#simple-fix-amend-and-force-push)
    - [Larger Changes: Add New Commits](#larger-changes-add-new-commits)
    - [Lock File Becomes Inconsistent (NU1004)](#lock-file-becomes-inconsistent-nu1004)
  - [Keeping Your Branch Current](#keeping-your-branch-current)
    - [Rebasing onto Main](#rebasing-onto-main)
    - [Resolving Conflicts During Rebase](#resolving-conflicts-during-rebase)
    - [The CHANGELOG.md Conflict](#the-changelogmd-conflict)
    - [A Merge Commit Appeared on Your Branch](#a-merge-commit-appeared-on-your-branch)
  - [Recovery Scenarios](#recovery-scenarios)
    - [Fixing a Bad Commit Message](#fixing-a-bad-commit-message)
      - [Last Commit, Not Yet Pushed](#last-commit-not-yet-pushed)
      - [Older Commit, Not Yet Pushed](#older-commit-not-yet-pushed)
      - [Already Pushed to a PR Branch](#already-pushed-to-a-pr-branch)
    - [Undo the Last Commit (Not Yet Pushed)](#undo-the-last-commit-not-yet-pushed)
    - [Revert a Pushed Commit](#revert-a-pushed-commit)
    - [You Pushed to Main by Accident](#you-pushed-to-main-by-accident)
    - [Branch Started from the Wrong Base](#branch-started-from-the-wrong-base)
    - [Cherry-Pick a Commit from Another Branch](#cherry-pick-a-commit-from-another-branch)
    - [Recovering Stashed Work](#recovering-stashed-work)
  - [Working with Multiple Developers](#working-with-multiple-developers)
  - [Quick Reference](#quick-reference)
    - [Settings to Enable First](#settings-to-enable-first)
    - [The Happy Path](#the-happy-path)
    - [Recovery Commands](#recovery-commands)
    - [Key Rules](#key-rules)

<!-- /TOC -->

## Overview

This guide describes the day-to-day development workflow for vm2 repositories. The CI/CD framework
automates versioning, changelogs, and package publishing — your job is to write good code with good
commit messages, and the automation handles the rest.

Every step that involves Git or GitHub shows three ways to do it:

1. **CLI** (the primary, explicit method — shown inline)
2. **VS Code** (collapsed panel — click to expand)
3. **Visual Studio** (collapsed panel — click to expand)

The usual happy-path workflow comes first. Recovery scenarios and edge cases follow in their own
sections — refer to them only when something goes wrong.

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
- Delete the branch after merge (automatic on remote, clean-up yourself locally)

**Branch naming** is free-form, but these conventions help:

| Prefix      | Use for                  | Example                      |
| :---------- | :----------------------- | :--------------------------- |
| `feat/`     | New features             | `feat/alternation-support`   |
| `fix/`      | Bug fixes                | `fix/buffer-overflow`        |
| `ci/`       | CI/CD changes            | `ci/fix-benchmark-thresholds`|
| `docs/`     | Documentation-only       | `docs/update-readme`         |
| `chore/`    | Build, deps, tooling     | `chore/update-deps`          |
| `refactor/` | Code restructuring       | `refactor/glob-engine`       |

---

## The Standard Workflow

These seven steps are the normal, day-to-day flow. If nothing unusual happens (no conflicts, no
review comments), this is all you need.

### Step 1: Update Your Local Main

Start every task from a clean, up-to-date `main`:

```bash
git fetch origin            # optional — git pull does a fetch internally,
                            # but an explicit fetch also updates tags and
                            # remote-tracking branches for other branches
git checkout main
git pull
```

<details>
<summary><strong>VS Code</strong></summary>

1. Click the **branch name** in the Status Bar (bottom-left) and select **main**.
2. Open **Source Control** (`Ctrl+Shift+G`) → click `···` → **Pull**.
   - Or: the **Sync Changes** button in the Status Bar pulls and pushes in one click.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. Click the **branch name** in the Status Bar (bottom-right) and select **main**.
2. **Git** menu → **Pull**, or press `Ctrl+T` then `Pull`.

</details>

### Step 2: Create a Feature Branch

```bash
git checkout -b feat/my-feature
```

<details>
<summary><strong>VS Code</strong></summary>

1. Click the **branch name** in the Status Bar → **Create new branch...**.
2. Type the branch name (e.g. `feat/my-feature`) and press Enter.
   - This branches from the currently checked-out commit (which should be `main` from Step 1).

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. **Git** menu → **New Branch...** (or click the branch name in the Status Bar → **New Branch**).
2. Name the branch, confirm **Based on: main**, and click **Create**.

</details>

### Step 3: Make Changes and Commit

Edit your code, then stage and commit with a [Conventional Commit](#conventional-commits) message:

```bash
git add .
git commit -m "feat(parser): add alternation support"
```

<details>
<summary><strong>VS Code</strong></summary>

1. Open **Source Control** (`Ctrl+Shift+G`).
2. Review changed files. Click `+` next to each file (or `+` on the **Changes** header to stage all).
3. Type your commit message in the text box at the top.
4. Click the **Commit** button (checkmark icon), or press `Ctrl+Enter`.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. Open **Git Changes** (`Ctrl+0, Ctrl+G`, or **View** menu → **Git Changes**).
2. Review changed files. Click `+` next to each file to stage, or click **Stage All**.
3. Type your commit message in the text box.
4. Click **Commit Staged** (or **Commit All** if you didn't stage individually).

</details>

> [!TIP]
> Each commit message appears **verbatim** in the changelog. Write them as release notes.
> See [Conventional Commits](#conventional-commits) for the full format reference.

### Step 4: Push and Open a Pull Request

```bash
# First push sets the upstream tracking branch
git push -u origin feat/my-feature

# Create PR from the command line
gh pr create --fill
```

<details>
<summary><strong>VS Code</strong></summary>

1. After your first commit, VS Code shows **Publish Branch** in the Source Control panel. Click it.
   - On subsequent pushes: click `···` → **Push**, or use the **Sync Changes** button.
2. To create the PR: install the **GitHub Pull Requests** extension, then:
   - Open the **GitHub Pull Requests** view in the sidebar.
   - Click **Create Pull Request**.
   - Fill in title and description, then click **Create**.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. **Git** menu → **Push** (or click the up-arrow in **Git Changes**).
   - On the first push, Visual Studio automatically sets the upstream.
2. After pushing, a notification toast appears: **"Create a Pull Request"**. Click it.
   - Or: **Git** menu → **Create Pull Request** (opens your browser to the GitHub new-PR page).

</details>

<details>
<summary><strong>GitHub Web</strong></summary>

After pushing, GitHub shows a yellow banner on the repository page:

> **Compare & pull request** — `feat/my-feature` had recent pushes

Click it, fill in the title and description, and click **Create pull request**.

</details>

### Step 5: CI Runs Automatically

When you open a PR, the CI pipeline runs:

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

The branch ruleset requires the **Postrun-CI** check to pass before merging. This single gate
replaces per-job required checks, which are unpredictable with reusable workflows and matrix
strategies.

No action is needed here — just wait for the checks to finish. If something fails, CI tells you
what broke and you push a fix (see [Handling PR Feedback](#handling-pr-feedback)).

### Step 6: Merge the Pull Request

Once CI passes and reviews (if any) are approved:

```bash
gh pr merge --rebase --delete-branch
```

<details>
<summary><strong>VS Code</strong></summary>

1. Open the **GitHub Pull Requests** sidebar → find your PR → click **Merge Pull Request**.
2. Select **Rebase and Merge** from the merge method dropdown (this is the only allowed method).

</details>

<details>
<summary><strong>GitHub Web</strong></summary>

1. On the PR page, click the green **Rebase and merge** button.
   - If you see "Merge" or "Squash and merge" instead, click the dropdown arrow and select
     **Rebase and merge**. (The repository settings enforce this as the only method, so the others
     are typically disabled.)
2. The branch is automatically deleted after merge.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

Visual Studio does not have a built-in PR merge button. Use the **GitHub Web** or **CLI** method.

</details>

### Step 7: Clean Up Locally

After the PR merges, update your local clone:

```bash
git checkout main
git pull
git branch -d feat/my-feature
```

<details>
<summary><strong>VS Code</strong></summary>

1. Click the **branch name** in the Status Bar → select **main**.
2. Click `···` → **Pull** (or the **Sync Changes** button).
3. To delete the old branch: click the **branch name** → **Delete Branch...** → select the old
   branch. Or use the Command Palette: `Git: Delete Branch`.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. Click the **branch name** in the Status Bar → select **main**.
2. **Git** menu → **Pull**.
3. **Git** menu → **Manage Branches** → right-click the old branch → **Delete**.

</details>

---

## What Happens After Merge

After your PR is rebased onto `main`:

1. **CI runs** on the push to `main` (verifies the rebased code)
2. **Prerelease workflow** triggers automatically after CI succeeds:
   - Computes the next prerelease version from commit messages
   - Updates `CHANGELOG.md`
   - Creates a prerelease Git tag (e.g. `v1.3.0-preview.1`)
   - Publishes a prerelease NuGet package
3. The prerelease package is available for testing immediately
4. **Review the generated changelog entry** (see below)

### Reviewing the Changelog

After each prerelease, `git-cliff` generates a changelog entry from your commit messages and pushes
it to `main`. This is the best moment to review and curate the entry — before a stable release bakes
it in permanently.

If the generated entry needs cleanup (e.g. rewording, grouping related items, adding context for
breaking changes), create a small cleanup PR:

```bash
git checkout main && git pull
git checkout -b docs/curate-changelog

# Edit CHANGELOG.md — review, curate, save

git add CHANGELOG.md
git commit -m "docs: curate changelog for vX.Y.Z-preview.N"
git push -u origin docs/curate-changelog
gh pr create --fill
```

### Changelog-Only Cleanup PR

Treat changelog cleanup as a tiny, focused PR. Do not bundle it with code, CI, or dependency changes.

Use this checklist:

1. Branch from latest `main`
2. Edit **only** `CHANGELOG.md`
3. Verify scope before commit:

```bash
git diff --name-only origin/main...HEAD
```

Expected output: `CHANGELOG.md` only. If you see extra files, reset them:

```bash
git restore --source=origin/main -- <file>
```

**Stable releases** are triggered **manually only** when ready — see
[RELEASE_PROCESS.md](RELEASE_PROCESS.md).

---

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

---

## Conventional Commits

### Commit Message Format

All vm2 repositories use [Conventional Commits](https://www.conventionalcommits.org/). The format:

```ebnf
commit-message = subject, [ LF, body ] ;
subject        = type, [ "(", scope, ")" ], [ "!" ], ": ", description ;
type           = "style" | "build" | "feat" | "test" | "fix" | "refactor"
               | "perf" | "security" | "doc" | "docs" | "chore" | "revert" | "remove"
               | "remove" | "ci" | "devops" ;
scope          = noun ;
description    = non-empty string ;
body           = free-form text ;
```

Where:

- **Type**: Required. One of the keywords: `style` `build` `feat` `test` `fix` `refactor` `perf` `security` `doc` `docs` `chore`
  `revert` `remove` `ci` `devops`
- **Scope**: Optional. A noun describing the section of the codebase (e.g. `api`, `ui`, `docs`)
- **Breaking Change**: Optional. **`!`** before `:` signals a breaking change
- **Description**: Required. A short description of the change

Examples:

```text
feat(api)!: change the 'getUserData' method of the API endpoint for user data. The change is not backwards compatible!
fix(ui):    correct button alignment on homepage
chore(ci):  update GitHub Actions workflow
```

| Type       | Triggers       | Use when                                              |
| :--------- | :------------- | :---------------------------------------------------- |
| `!`        | **major bump** | Creates backwards-incompatible changes                |
| `feat`     | **minor bump** | Adding new functionality                              |
| `fix`      | **patch bump** | Fixing a bug                                          |
| `perf`     | **patch bump** | Performance improvement                               |
| `security` | **patch bump** | Security fixes                                        |
| `remove`   | **patch bump** | Removing code or functionality                        |
| `revert`   | **patch bump** | Reverting a previous commit                           |
| `refactor` | no bump        | Code restructuring without behavior change            |
| `style`    | no bump        | Code style changes (whitespace, formatting, etc.)     |
| `build`    | no bump        | Changes that affect the build system or dependencies  |
| `test`     | no bump        | Adding or updating tests                              |
| `doc`      | no bump        | Documentation changes only                            |
| `docs`     | no bump        | Documentation changes only                            |
| `chore`    | no bump        | Build, CI, tooling, dependency updates                |
| `ci`       | no bump        | Continuous Integration related changes                |
| `devops`   | no bump        | DevOps related changes                                |

**Breaking changes** trigger a **major** bump. Mark them with `!` after the type/scope:

```text
refactor(core)!: rewrite matching engine
```

### How Commits Drive Automation

Your commit messages directly control what happens when code reaches `main`:

```text
feat(parser): add alternation support:  minor version bump:  v1.3.0-preview.N  →  v1.3.1-preview.1
fix: correct boundary check          :  patch version bump:  v1.2.4-preview.N  →  v1.2.5-preview.1
refactor!: rewrite engine            :  major version bump:  v1.2.5-preview.N  →  v2.0.0-preview.1
```

1. **git-cliff** parses commit messages to generate `CHANGELOG.md` entries
2. **MinVer** + version computation scripts determine the next version from the highest-impact
   commit type since the last tag
3. **Prerelease** publishes automatically after CI succeeds on `main`
4. **Stable release** is triggered **manually** via `workflow_dispatch`

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

> [!TIP]
> If you just want to save your work, commit with `chore: WIP [skip ci]` and push — this will
> not trigger a release or affect the changelog. Use `git rebase -i origin/main` to squash or
> reorder WIP commits before merging.

### Commit Message Enforcement

Conventional Commits are enforced at two levels:

1. **Local git hook** — fast feedback at `git commit` time. To enable, run once per clone:

   ```bash
   git config core.hooksPath ~/repos/vm2/vm2.DevOps/scripts/githooks
   ```

   The hook rejects non-conforming subject lines. You may bypass it with `git commit --no-verify`,
   but CI will still catch it.

2. **CI check** — the `validate-commits` job in `_ci.yaml` validates all commit messages in the
   PR range. This is the hard gate — it cannot be bypassed.

### Commit Message Template

A commit message template shows the allowed types and format in your editor every time you run
`git commit`. To enable, run once per clone:

```bash
git config commit.template ~/repos/vm2/vm2.DevOps/scripts/githooks/.gitmessage
```

> [!NOTE]
> `repo-setup.sh` configures both settings automatically via `git config --local` on first run.
> You only need the commands above if you set up a clone manually.

Both settings in one go:

```bash
git config --local core.hooksPath ~/repos/vm2/vm2.DevOps/scripts/githooks
git config --local commit.template ~/repos/vm2/vm2.DevOps/scripts/githooks/.gitmessage
```

---

## Handling PR Feedback

When a reviewer (human or Copilot) requests changes on your PR, you have two strategies depending
on the size of the fix.

### Simple Fix: Amend and Force-Push

For small, targeted fixes (a renamed variable, a typo, a formatting tweak), **amend** the existing
commit rather than adding a new one. This keeps the branch history clean — one logical commit per
purpose.

```bash
# Make your fixes, then:
git add .
git commit --amend --no-edit       # fold fixes into the last commit, keep the message
git push --force-with-lease        # update the PR (safe force-push)
```

If you also need to fix the commit message:

```bash
git commit --amend -m "feat(parser): add alternation support"
git push --force-with-lease
```

<details>
<summary><strong>VS Code</strong></summary>

1. Make your fixes and stage them in **Source Control** (`Ctrl+Shift+G`) → click `+`.
2. Click the **dropdown arrow** next to the **Commit** button → select **Commit (Amend)**.
   - Or: `···` menu → **Commit** → **Commit (Amend)**.
   - VS Code opens an editor with the previous message. Edit or keep it, then save and close.
3. Push with force:
   - `···` menu → **Pull, Push** → **Push (Force With Lease)**.

> [!IMPORTANT]
> The force-push option only appears if you enable `git.allowForcePush` in VS Code settings.
> Open Settings (`Ctrl+,`), search for `allowForcePush`, and check the box.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. Make your fixes and stage them in **Git Changes**.
2. Check the **Amend** checkbox (below the commit message box) → click **Commit Staged** (or
   **Commit All Amended**).
3. **Git** menu → **Push**. If the remote is ahead of your rewritten history, Visual Studio
   prompts you to force-push. Select **Push (Force With Lease)**.

> [!NOTE]
> In Visual Studio 2022 17.7+, force-push uses `--force-with-lease` by default.

</details>

CI re-runs automatically after the force-push. Review comments that were addressed should be
resolved by the reviewer or by you.

### Larger Changes: Add New Commits

If the feedback requires substantial rework (new tests, refactored logic, design changes), add
separate commits with their own conventional messages:

```bash
git add .
git commit -m "test: add edge-case tests for alternation"
git push
```

This preserves the review trail — reviewers can see exactly what changed between rounds by looking
at the new commits.

### Lock File Becomes Inconsistent (NU1004)

When you update a package version in `Directory.Packages.props` but the `packages.lock.json` files
still reference the old version, CI fails with:

```text
error NU1004: The packages lock file is inconsistent with the project dependencies
```

Fix by regenerating the lock files and amending:

```bash
dotnet restore --force-evaluate      # regenerate all packages.lock.json files
git add **/packages.lock.json
git commit --amend --no-edit
git push --force-with-lease
```

<details>
<summary><strong>VS Code / Visual Studio</strong></summary>

1. Open a terminal and run `dotnet restore --force-evaluate` in the repository root.
2. The updated `packages.lock.json` files appear in Source Control / Git Changes.
3. Stage them and amend (see [Simple Fix: Amend and Force-Push](#simple-fix-amend-and-force-push)).

</details>

---

## Keeping Your Branch Current

If `main` moves ahead while your PR is open (other PRs merged, CI changelog commits), you need to
**rebase** your branch before it can merge. GitHub shows a "This branch is out of date" banner.

### Rebasing onto Main

```bash
git fetch origin main
git rebase origin/main
# Resolve any conflicts (see below), then:
git push --force-with-lease
```

`--force-with-lease` only overwrites commits **you** authored on your branch. If someone else
somehow pushed to your branch, the push fails safely instead of overwriting their work.

<details>
<summary><strong>VS Code</strong></summary>

VS Code's built-in **Pull (Rebase)** only rebases onto the branch's upstream tracking branch
(i.e. `origin/feat/my-feature`), **not** onto `origin/main`. To rebase onto main you need the
terminal:

1. Open the integrated terminal (`Ctrl+`` `).
2. Run:

   ```bash
   git fetch origin main
   git rebase origin/main
   ```

3. If conflicts arise, VS Code highlights them in the editor with inline merge markers.
   Resolve each file, stage it (`+`), then run `git rebase --continue` in the terminal.
4. Push: `···` menu → **Pull, Push** → **Push (Force With Lease)**.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. **Git** menu → **Manage Branches**.
2. Expand **remotes/origin** → right-click **main** → **Rebase `<current-branch>` onto
   `origin/main`**.
3. If conflicts arise, Visual Studio opens the **Merge Conflict** editor. Resolve each file and
   click **Accept Merge**.
4. **Git** menu → **Push** → when prompted, select **Force Push (With Lease)**.

</details>

### Resolving Conflicts During Rebase

During a rebase, Git replays your commits one at a time on top of the new base. If a conflict
occurs:

```bash
# Git stops and tells you which files conflict.
# Fix the conflicts in your editor, then:
git add <resolved-files>
git rebase --continue

# To abort and go back to where you started:
git rebase --abort
```

The advantage over merge conflicts: you resolve one commit at a time, so each conflict is small
and focused.

<details>
<summary><strong>VS Code</strong></summary>

When a conflict occurs during rebase, VS Code:

1. Shows conflicting files with a `C` badge in **Source Control**.
2. Opens a side-by-side diff with **Accept Current**, **Accept Incoming**, or **Accept Both**
   buttons inline.
3. After resolving all files, stage them (`+`), then run `git rebase --continue` in the terminal.
   - To abort: run `git rebase --abort` in the terminal.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. Visual Studio shows a **Merge Conflict** notification in **Git Changes**.
2. Click each conflicting file to open the three-way merge editor.
3. Choose the correct resolution for each section and click **Accept Merge**.
4. After all conflicts are resolved, click **Continue Rebase** in the **Git Changes** panel.

</details>

### The CHANGELOG.md Conflict

`CHANGELOG.md` is the **most common conflict** in vm2 rebases, and it always resolves the same way.

**Why it happens:** CI auto-commits the changelog to `main` via `[skip ci]` commits every time a
branch merges. Your branch was cut before that commit, so Git sees two diverging versions of
`CHANGELOG.md`.

**The rule:** Always take the version from `main` (theirs during rebase, but accessed via
`--ours` because rebase inverts the perspective):

```bash
git checkout --ours CHANGELOG.md
git add CHANGELOG.md
git rebase --continue
```

Your branch must never modify `CHANGELOG.md` manually — CI owns that file.

<details>
<summary><strong>VS Code</strong></summary>

When the CHANGELOG conflict appears, click the file in Source Control. In the merge editor:

1. Click **Accept Current Change** (which is `main`'s version during rebase) for every conflict
   section.
2. Stage the file (`+`) and run `git rebase --continue` in the terminal.

> [!TIP]
> If the file is heavily conflicted, it's faster to run `git checkout --ours CHANGELOG.md` in
> the terminal than to resolve each hunk individually.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

In the merge editor, use **Take Source** (the `main` version) for every section of
`CHANGELOG.md`. Then click **Accept Merge** and **Continue Rebase**.

</details>

### A Merge Commit Appeared on Your Branch

GitHub's "Update branch" button (the one that says "This branch is out of date") performs a
**merge**, not a rebase. This creates a merge commit on your branch, which GitHub then refuses to
rebase-merge. The fix:

```bash
# 1. Stash any uncommitted work
git stash

# 2. Rebase onto main (this replays your commits, discarding the merge commit)
git fetch origin main
git rebase origin/main
# Resolve any conflicts (CHANGELOG → always --ours)

# 3. Verify the graph is linear — no merge commits
git log --oneline --graph -8
# Should show a straight line: * * * * (no branches/merges)

# 4. Force-push to update the PR
git push --force-with-lease

# 5. Restore stashed work
git stash pop
```

> [!WARNING]
> **Never click GitHub's "Update branch" button.** It creates a merge commit that breaks the
> linear history requirement. Always rebase manually instead.

<details>
<summary><strong>VS Code / Visual Studio</strong></summary>

Neither IDE has a one-click "rebase onto main" button that avoids merge commits. Use the terminal
commands above (or Visual Studio's rebase-onto feature under **Manage Branches**). The key is to
avoid any "merge" or "update branch" action that creates a merge commit.

</details>

---

## Recovery Scenarios

These situations are uncommon but recoverable. Each section is self-contained — jump directly to
the one that matches your problem.

### Fixing a Bad Commit Message

A commit slipped through with the wrong message (e.g. you used `--no-verify`, or the hook wasn't
configured yet). The fix depends on when you catch it.

#### Last Commit, Not Yet Pushed

The simplest case — `--amend` rewrites only the most recent commit:

```bash
git commit --amend -m "fix: corrected message"
```

<details>
<summary><strong>VS Code</strong></summary>

1. Open **Source Control** → `···` → **Commit** → **Commit (Amend)**.
   - Or click the dropdown arrow next to the **Commit** button → **Commit (Amend)**.
2. Edit the message in the editor that opens, then save and close.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. In **Git Changes**, check the **Amend** checkbox.
2. Edit the message and click **Commit Amended**.

</details>

#### Older Commit, Not Yet Pushed

Use interactive rebase to rewrite any commit in your branch:

```bash
git rebase -i origin/main
```

Git opens your editor with the list of commits:

```text
pick a1b2c3d feat: add widget
pick d4e5f6a bad message here         <-- this one needs fixing
pick f7g8h9i fix: handle null input
```

Change `pick` to `reword` on the bad line, save, and close. Git replays commits in order, pausing
at each `reword` to let you type the corrected message:

```text
pick a1b2c3d feat: add widget
reword d4e5f6a bad message here
pick f7g8h9i fix: handle null input
```

> [!NOTE]
> Other useful interactive rebase commands: `edit` (pause to change code + message), `squash`
> (fold into previous commit, keep both messages), `fixup` (fold into previous, discard message),
> `drop` (delete the commit entirely).

<details>
<summary><strong>VS Code</strong></summary>

No built-in interactive rebase UI. Run `git rebase -i origin/main` in the integrated terminal.
VS Code opens the rebase todo list in the editor — edit and save to proceed.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

Visual Studio 2022 (17.6+) has interactive rebase support:

1. **Git** menu → **Manage Branches** → right-click your branch → **Interactive Rebase...**.
2. A commit list appears. Right-click the commit with the bad message → **Reword**.
3. Edit the message and click **Start Rebase**.

</details>

#### Already Pushed to a PR Branch

Same as above, then force-push:

```bash
git rebase -i origin/main
# ... reword the commit ...
git push --force-with-lease
```

CI re-runs automatically after the force-push and `validate-commits` will pass.

<details>
<summary><strong>VS Code / Visual Studio</strong></summary>

Follow the interactive rebase steps above. Then force-push:

- **VS Code**: `···` → **Pull, Push** → **Push (Force With Lease)** (requires `git.allowForcePush`
  setting enabled).
- **Visual Studio**: **Git** menu → **Push** → select **Force Push (With Lease)** when prompted.

</details>

### Undo the Last Commit (Not Yet Pushed)

If you committed something wrong and haven't pushed yet:

```bash
# Keep changes staged (ready to re-commit differently)
git reset --soft HEAD~1

# Keep changes in working directory (unstaged)
git reset HEAD~1

# Discard the changes entirely (DESTRUCTIVE — cannot be undone)
git reset --hard HEAD~1
```

<details>
<summary><strong>VS Code</strong></summary>

- **Undo last commit (keep changes)**: `···` menu → **Commit** → **Undo Last Commit**.
  This is equivalent to `git reset --soft HEAD~1` — your changes remain staged.
- There is no UI equivalent for `--hard` reset. Use the terminal if you want to discard changes.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. **Git** menu → **Manage Branches** → **History** (or **View** → **Git Repository**).
2. Right-click the commit before your mistake → **Reset** → choose **Keep Changes (--mixed)**
   or **Delete Changes (--hard)**.

</details>

### Revert a Pushed Commit

If a bad commit already landed on `main` or on a shared branch, do **not** rewrite history with
`reset`. Instead, create a **revert commit** that undoes the change:

```bash
git revert <commit-sha>
git push
```

This creates a new commit that inverts the bad one, preserving history.

<details>
<summary><strong>VS Code</strong></summary>

No built-in revert UI for arbitrary commits. Use the terminal:

```bash
git log --oneline -5      # find the commit SHA
git revert <sha>
```

VS Code opens the commit message editor. Edit or accept the default revert message, save, and
close. Then push normally.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. **Git** menu → **Manage Branches** → **History** (or open the **Git Repository** window).
2. Right-click the bad commit → **Revert**.
3. Visual Studio creates the revert commit automatically.
4. **Git** menu → **Push**.

</details>

### You Pushed to Main by Accident

Branch protection rules normally block direct pushes to `main`, but if you have admin bypass:

**Option 1: Revert (safe, preserves history)**

```bash
git checkout main
git revert HEAD
git push
```

**Option 2: Force-reset (only if you are the sole developer and the push just happened)**

```bash
git checkout main
git reset --hard HEAD~1
git push --force-with-lease origin main
```

> [!WARNING]
> Force-pushing to `main` rewrites shared history. Only do this if you are absolutely certain no
> one else has fetched the bad commit. Prefer `git revert` in almost all cases.

<details>
<summary><strong>VS Code / Visual Studio</strong></summary>

Use the revert approach described in [Revert a Pushed Commit](#revert-a-pushed-commit). Avoid
using the reset approach through the UI — the risk of accidental data loss is too high without
seeing the exact commands.

</details>

### Branch Started from the Wrong Base

You created a branch from an old `main`, or from another feature branch by mistake. Rebase onto
the correct base:

```bash
# Rebase onto the correct base (origin/main)
git fetch origin main
git rebase --onto origin/main <wrong-base> <your-branch>

# Example: you branched from feat/old instead of main
git rebase --onto origin/main feat/old feat/my-feature

git push --force-with-lease
```

If you branched from an old `main` (the common case), a plain rebase suffices:

```bash
git fetch origin main
git rebase origin/main
git push --force-with-lease
```

<details>
<summary><strong>VS Code</strong></summary>

Use the terminal for `--onto` rebases — there is no UI equivalent. For a plain rebase onto main,
see [Rebasing onto Main](#rebasing-onto-main).

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

For a plain rebase onto main: **Git** menu → **Manage Branches** → right-click **origin/main** →
**Rebase onto**. For `--onto` rebases with a specific wrong-base, use the terminal.

</details>

### Cherry-Pick a Commit from Another Branch

To copy a single commit from another branch into your current branch:

```bash
# Find the commit SHA
git log --oneline other-branch -10

# Cherry-pick it
git cherry-pick <commit-sha>
```

If conflicts occur, resolve them the same way as during rebase:

```bash
# Fix conflicts, then:
git add <resolved-files>
git cherry-pick --continue

# Or abort:
git cherry-pick --abort
```

<details>
<summary><strong>VS Code</strong></summary>

No built-in cherry-pick UI. Use the terminal. After cherry-picking, the new commit appears in
Source Control history normally.

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. **Git** menu → **Manage Branches** → expand the source branch.
2. Open the branch's **History**, right-click the commit → **Cherry-Pick**.
3. Visual Studio creates a copy of the commit on your current branch.

</details>

### Recovering Stashed Work

If you stashed work in progress and need it back:

```bash
# See what's stashed
git stash list

# Apply the most recent stash (keeps it in the stash list)
git stash apply

# Apply and remove from the stash list
git stash pop

# Apply a specific stash
git stash apply stash@{2}

# Drop a stash you no longer need
git stash drop stash@{0}
```

<details>
<summary><strong>VS Code</strong></summary>

1. Open **Source Control** → `···` → **Stash** → **Apply Stash...** or **Pop Stash...**.
2. VS Code shows a list of stashes to choose from.
3. To create a stash: `···` → **Stash** → **Stash** (or **Stash (Include Untracked)**).

</details>

<details>
<summary><strong>Visual Studio</strong></summary>

1. **Git** menu → **Manage Stash** (or the stash icon in **Git Changes**).
2. The stash list appears. Click **Apply** or **Pop** next to the desired stash.
3. To create a stash: in **Git Changes**, click the stash dropdown → **Stash All** or **Stash
   All (Include Untracked)**.

</details>

---

## Working with Multiple Developers

The rebase workflow naturally prevents stepping on each other's work:

1. **Each developer works on their own branch** — no shared branches
2. **PRs are the only path to `main`** — the branch ruleset blocks direct pushes
3. **Rebase before merge** — each developer resolves conflicts with the current `main`, not with
   other branches
4. **`--force-with-lease` protects your branch** — if another developer pushed to your branch,
   your push fails safely instead of overwriting their commits
5. **Stale review dismissal** — if you push new commits after approval, the review is reset,
   ensuring reviewers see the final code

---

## Quick Reference

### Settings to Enable First

Run these once per clone (or let `repo-setup.sh` do it):

```bash
git config --local core.hooksPath ~/repos/vm2/vm2.DevOps/scripts/githooks
git config --local commit.template ~/repos/vm2/vm2.DevOps/scripts/githooks/.gitmessage
```

In VS Code, enable force-push support:

```json
{
  "git.allowForcePush": true
}
```

### The Happy Path

| Step | CLI | VS Code / VS |
| :--- | :-- | :----------- |
| **1. Update main** | `git checkout main && git pull` | Switch branch → Pull |
| **2. Create branch** | `git checkout -b feat/x` | Branch picker → Create new branch |
| **3. Commit** | `git add . && git commit -m "feat: ..."` | Stage (`+`) → type message → Commit |
| **4. Push + PR** | `git push -u origin feat/x && gh pr create --fill` | Publish Branch → Create Pull Request |
| **5. Wait for CI** | *(automatic)* | *(automatic)* |
| **6. Merge** | `gh pr merge --rebase --delete-branch` | GitHub web: Rebase and merge |
| **7. Clean up** | `git checkout main && git pull && git branch -d feat/x` | Switch to main → Pull → Delete branch |

### Recovery Commands

| Situation | CLI |
| :-------- | :-- |
| **Rebase onto main** | `git fetch origin main && git rebase origin/main && git push --force-with-lease` |
| **Amend last commit** | `git commit --amend --no-edit && git push --force-with-lease` |
| **Fix commit message** | `git commit --amend -m "new message" && git push --force-with-lease` |
| **Interactive rebase** | `git rebase -i origin/main` (then `reword`, `squash`, etc.) |
| **CHANGELOG conflict** | `git checkout --ours CHANGELOG.md && git add CHANGELOG.md && git rebase --continue` |
| **Lock file mismatch** | `dotnet restore --force-evaluate && git add **/packages.lock.json` |
| **Undo last commit** | `git reset --soft HEAD~1` (keep changes) or `git reset --hard HEAD~1` (discard) |
| **Revert pushed commit** | `git revert <sha> && git push` |
| **Cherry-pick** | `git cherry-pick <sha>` |
| **View stashes** | `git stash list` |
| **Apply stash** | `git stash pop` |

### Key Rules

- Always use conventional commit messages
- Always rebase (never merge) to update your branch
- Always use `--force-with-lease` (never `--force`)
- Never click GitHub's "Update branch" button
- Never edit `CHANGELOG.md` on a feature branch (CI owns it)
- Let the CI pipeline tell you if something is wrong
- Let the automation handle versioning and changelogs
