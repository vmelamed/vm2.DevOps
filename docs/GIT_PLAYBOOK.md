# Git Playbook (Rebase-First)

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [Git Playbook (Rebase-First)](#git-playbook-rebase-first)
  - [1) Personal Git Playbook](#1-personal-git-playbook)
    - [Start of day (per repo)](#start-of-day-per-repo)
    - [Before writing new code on a feature branch](#before-writing-new-code-on-a-feature-branch)
    - [During development](#during-development)
    - [Before push / PR update](#before-push--pr-update)
    - [After a rebase (the death-spiral rule)](#after-a-rebase-the-death-spiral-rule)
    - [Keeping a PR branch up to date (never merge `main` into it)](#keeping-a-pr-branch-up-to-date-never-merge-main-into-it)
    - [Fixing commit messages](#fixing-commit-messages)
    - [Viewing commit messages](#viewing-commit-messages)
    - [Conflict protocol (when VS Code looks inconsistent)](#conflict-protocol-when-vs-code-looks-inconsistent)
    - [Golden rule](#golden-rule)
  - [2) Safe Git Config + Aliases](#2-safe-git-config--aliases)
    - [Per-repo settings (enforced by setup-repo.sh)](#per-repo-settings-enforced-by-setup-reposh)
    - [Global aliases](#global-aliases)
  - [3) Branch Policy for vm2 Repos](#3-branch-policy-for-vm2-repos)
    - [Branch lifecycle](#branch-lifecycle)
    - [PR shape](#pr-shape)
    - [Parallel PRs on the same files](#parallel-prs-on-the-same-files)
    - [Update cadence](#update-cadence)
    - [Conflict policy](#conflict-policy)
    - [Merge readiness gates](#merge-readiness-gates)
  - [4) No Big Bang Merges!](#4-no-big-bang-merges)
    - [If the cause is a merge commit](#if-the-cause-is-a-merge-commit)
  - [Quick 10-Command Cheat Sheet](#quick-10-command-cheat-sheet)

<!-- /TOC -->

This playbook is optimized for solo/low-concurrency repos and for a rebase-first workflow.

## 1) Personal Git Playbook

### Start of day (per repo)

1. `git status`
2. `git branch --show-current`
3. `git fetch --all --prune`
4. `git rev-list --left-right --count origin/main...HEAD`

Or all four in one: `git preflight` (see [Global aliases](#global-aliases)).

Quick interpretation:

- Left count > 0: local branch is behind `origin/main`
- Right count > 0: local branch is ahead of `origin/main`
- Both > 0: branch diverged from `origin/main` (normal, rebase soon)

### Before writing new code on a feature branch

1. Ensure working tree is clean: `git status`
2. Rebase onto main: `git rebase origin/main`
3. If conflicts: resolve, `git add <files>`, `git rebase --continue`
4. If state gets confusing: `git rebase --abort`, then retry from clean state

### During development

1. Commit in small logical chunks
2. Push regularly (do not let branch drift for days)
3. Open PR early (draft PR is fine)

### Before push / PR update

1. `git status`
2. `git branch --show-current`
3. `git rev-list --left-right --count origin/main...HEAD`
4. Run build and fastest relevant tests
5. `git push` for new commits — but **after a rebase, always `git pushf`** (`--force-with-lease`)

### After a rebase (the death-spiral rule)

A rebase rewrites history, so a plain `git push` is rejected as non-fast-forward. The fatal "fix" is `git pull`: it merges
the **old** remote tip back into the rebased branch — undoing the rebase, doubling the commits, and putting the PR right
back into "unresolved conflicts". Repeat that loop a few times and it is 4:30am.

1. After every rebase, push with `git pushf` — never plain `push`, **never `pull`**
2. Rebase **once, immediately before merging**, then merge right away — automation (Prerelease changelog commits,
   dependabot auto-merges) keeps moving `main`, so do not rebase and then walk away
3. If the PR still shows conflicts after a `pushf`, stop and diagnose (`git preflight`) — do not re-rebase blindly

### Keeping a PR branch up to date (never merge `main` into it)

These repos only allow "Rebase and merge" and require linear history. A merge commit inside a feature branch breaks
that: GitHub must drop the merge and replay the branch's commits one by one, and if any of them conflicts with `main`,
the PR fails with **"This branch can't be rebased"** even though the tips merge cleanly.

1. **Locally:** `git sync` (fetch + rebase onto `origin/main`), then `git pushf`
1. **On GitHub:** the PR's **"Update branch"** button creates a **merge commit** by default. Open its dropdown and choose
   **"Update with rebase"** instead
1. Never `git pull origin main` (or "Sync" in VS Code) into a feature branch: both create the same merge commit

If a merge commit got in anyway, see [If the cause is a merge commit](#if-the-cause-is-a-merge-commit) below.

### Fixing commit messages

`validate-commits.sh` rejects any commit whose subject does not follow Conventional Commits. Fix the message before
pushing, or rewrite it afterwards.

1. **If the commit was made on GitHub** (a "Commit suggestion" button, the Copilot agent), bring it down first, or the
   rewrite below will not include it:

   ```bash
   git fetch origin
   git pull --ff-only     # fast-forward only, never a merge
   ```

1. **The last commit:**

   ```bash
   git commit --amend                                   # edit the message in the editor
   git commit --amend -m "fix: correct the -ec/-ns order"  # or set it directly
   ```

1. **An older commit:** `git rebase -i HEAD~N` (N = how far back), change `pick` to **`reword`** (or `r`) on each commit to
   fix, save, then edit each message as Git opens it. The content stays the same; the SHAs of that commit and every
   later one change.
1. **Push with `git pushf`** — never "Sync", never `git pull`: the branch now shows "ahead N, behind N", and either of
   them would merge the old commits right back in (the death spiral above)

**Prevention:** GitHub's "Commit suggestion" dialog has an editable commit message field. Type the Conventional Commits
message there before clicking *Commit*, and nothing needs rewriting afterwards.

### Viewing commit messages

```bash
git log --oneline origin/main..HEAD                # this branch's commits: exactly what the PR will contain
git log origin/main..HEAD --format='%h %s%n%b'     # subjects and bodies
git show -s --format=%B HEAD~2                     # the full message of one commit (here: the 3rd from the top)
git lg                                             # all branches, as a graph
```

`git log --oneline origin/main..HEAD` shows exactly the subjects `validate-commits.sh` will check in CI.

**The messages from before a rewrite** are no longer in `git log`, but they are in the **reflog**, Git's local record of
where `HEAD` has been (kept about 90 days by default):

```bash
git reflog --format='%h %gd %gs | %s'              # SHA, position, the action (commit/amend/rebase…), and the message
git reset --hard <sha>                             # back to any earlier state, if a rewrite went wrong
```

### Conflict protocol (when VS Code looks inconsistent)

1. Stop making unrelated edits
2. Run `git status` and identify mode:
   - Rebase in progress
   - Merge in progress
   - Normal state
3. Resolve only unmerged files listed by Git
4. **Never hand-resolve generated files** (`packages.lock.json` etc.) — take a side and regenerate.

   In repos set up by `setup-repo.sh` this is automatic: the `nugetlock` merge driver (bound via `.gitattributes`)
   takes the incoming side, so lockfile conflicts never stop a rebase or merge — you only see a reminder like
   `vm2: 'packages.lock.json' auto-resolved (took the incoming side) - regenerate with: dotnet restore --force-evaluate`.
   **The reminder is not optional**: regenerate before pushing, or CI's locked-mode restore will fail with `NU1004`.

   ```bash
   dotnet restore --force-evaluate
   git add '**/packages.lock.json'
   ```

   Manual fallback (repo not yet set up, so the driver is not configured and the conflict stops you):

   ```bash
   git checkout --theirs '**/packages.lock.json'
   dotnet restore --force-evaluate
   git add '**/packages.lock.json'
   ```

5. Continue operation:
   - Rebase: `git rebase --continue` (`git rbcontinue`)
   - Merge: `git commit`
6. Safe abort options:
   - `git rebase --abort` (`git rbabort`)
   - `git merge --abort`

Repeated conflicts on the same hunks across replayed commits resolve themselves after the first time — that is `rerere` +
`rerere.autoUpdate` doing their job. If the same conflict keeps stopping you, check `git config rerere.enabled` in that repo.

### Golden rule

Never mix operations:

- Do not start merge while rebasing
- Do not start rebase while merging
- Finish or abort one operation before starting another

## 2) Safe Git Config + Aliases

### Per-repo settings (enforced by setup-repo.sh)

The per-repo Git settings are **enforced by `setup-repo.sh`** from the `default_local_git_settings` table in
`scripts/bash/src/setup-repo.defaults.sh` — **that table is the source of truth**, not this document. Run `setup-repo.sh` after
cloning a vm2 repo (or against an existing clone to re-sync). What it applies and why:

| Setting                  | Value                                    | Why it matters                                         |
|--------------------------|------------------------------------------|--------------------------------------------------------|
| `core.hooksPath`         | `$VM2_REPOS/vm2.DevOps/scripts/githooks` | shared Git hooks across all vm2 repos                  |
| `commit.template`        | SoT `.gitmessage`                        | Conventional Commits template on every commit          |
| `merge.ff`               | `only`                                   | refuses non-fast-forward merges → linear history       |
| `pull.rebase`            | `true`                                   | aligns pull behavior with the rebase-first flow        |
| `fetch.prune`            | `true`                                   | removes stale remote refs                              |
| `push.autoSetupRemote`   | `true`                                   | the first push of a new branch sets up tracking automatically |
| `rerere.enabled`         | `true`                                   | remembers and reapplies repeated conflict resolutions  |
| `rerere.autoUpdate`      | `true`                                   | also **stages** rerere's auto-resolutions — replayed conflicts sail through |
| `rebase.autoStash`       | `true`                                   | auto-stash/reapply a dirty tree around rebase — no interruptions |
| `merge.conflictstyle`    | `zdiff3`                                 | conflict hunks include the common base — see *what changed*, not just results |
| `push.useForceIfIncludes`| `true`                                   | `--force-with-lease` also fails if the remote moved while you were rebasing   |
| `tag.sort`               | `version:refname`                        | `git tag` lists `v1.10.0` after `v1.9.0`               |
| `merge.nugetlock.*`      | custom merge driver                      | auto-resolves `packages.lock.json` conflicts by taking the incoming side (bound via `.gitattributes`); regenerate with `dotnet restore --force-evaluate` |

### Global aliases

Aliases are global — set once per machine:

```bash
git config --global alias.st "status -sb"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.last "log -1 --stat"
git config --global alias.undo "reset --soft HEAD~1"
git config --global alias.sync '!git fetch origin --prune && git rebase origin/main'
git config --global alias.preflight '!f(){ git status -sb; echo; echo "branch: $(git branch --show-current)"; echo; (git rev-list --left-right --count origin/main...HEAD 2>/dev/null && echo "format: behind ahead") || echo "no origin/main yet"; echo; if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then echo "REBASE IN PROGRESS"; else echo "no rebase in progress"; fi; }; f'
git config --global alias.rbcontinue "rebase --continue"
git config --global alias.rbabort "rebase --abort"
git config --global alias.pushf "push --force-with-lease"
```

| Alias                             | Use it for                                                                               |
|-----------------------------------|------------------------------------------------------------------------------------------|
| `git st`                          | quick status                                                                             |
| `git lg`                          | history graph                                                                            |
| `git last`                        | what did I just commit?                                                                  |
| `git undo`                        | un-commit the last commit, keep the changes staged                                       |
| `git sync`                        | fetch + rebase onto fresh `origin/main` in one move                                      |
| `git preflight`                   | start-of-day / pre-push check: status, branch, ahead/behind, rebase-in-progress          |
| `git rbcontinue` / `git rbabort`  | continue / abort a rebase                                                                |
| `git pushf`                       | **the only correct push after a rebase** (`--force-with-lease` + `useForceIfIncludes` guard)|

## 3) Branch Policy for vm2 Repos

### Branch lifecycle

1. Target branch lifespan: 1-3 days
2. If branch age exceeds 5 days, rebase before adding major new work
3. Keep one concern per branch (DevOps vs product logic)

### PR shape

1. Prefer smaller PRs
2. Split large work into stacked PRs where possible
3. Open draft PR early for CI signal

### Parallel PRs on the same files

Working on a second branch while the first PR is still open is fine. If both change the **same files**, though, the
second one will conflict when it is rebased after the first merges. Either:

1. **Merge the first PR before starting the second**, or
1. **Start the second branch from the first** (`git switch -c second first`), a "stacked" PR. After the first one
   merges, rebase the second onto `main` with `git rebase --onto origin/main first second`: only the second branch's own
   commits are replayed, so there is nothing left to conflict.

### Update cadence

1. Rebase at start of day: `git sync`
2. Rebase again before switching PR from draft to review
3. Rebase once more **immediately before merging** if main has moved — and merge right away (see
   [After a rebase](#after-a-rebase-the-death-spiral-rule))

### Conflict policy

1. Resolve conflicts locally (not in GitHub web editor) for non-trivial sets
2. If conflict state feels broken:
   - abort operation
   - return to clean state
   - retry in a single operation path

### Merge readiness gates

1. Clean working tree
2. CI green
3. Coverage thresholds understood
4. PR shows no stale conflict state after latest push

## 4) No Big Bang Merges

"Prefer smaller PRs" above isn't just about reviewability — a branch that grows too large before merging can hit a
GitHub-side limit that has nothing to do with actual conflicts.

**What happened:** `vm2.DevOps` PR #27 ("big-bang," 119 commits accumulated over several days) showed
`mergeable: true` / `mergeable_state: clean`, but `rebaseable: false`. A local `git rebase origin/main` was a
complete no-op — `origin/main` was already an ancestor, so there was nothing to replay and nothing that could
conflict — yet `gh pr merge --rebase` still failed with `GraphQL: This branch can't be rebased`. GitHub does not
document the exact `rebaseable` criteria (it's a separate computation from `mergeable`); community reports point to
roughly 100 commits as a practical threshold above which "Rebase and merge" starts refusing PRs with no real
conflicts.

**Rule of thumb:** if a branch is approaching on the order of 100 commits before you even open the PR, split the
work into multiple smaller PRs. Don't let one branch become a "big bang" merge.

**If you hit it anyway:**

1. Confirm it's not a real conflict: `git fetch origin && git rebase origin/main` — a no-op or clean resolve means
   the block is GitHub-side.
2. Confirm via the API: `gh api repos/<owner>/<repo>/pulls/<number> --jq '{mergeable, mergeable_state, rebaseable}'`.
3. This repository disables squash merging; split the work into smaller PRs or have an administrator explicitly change the ruleset before
   merging instead of relying on this fallback.

### If the cause is a merge commit

The other common cause of "This branch can't be rebased" is a **merge commit in the branch** ("Merge branch 'main' into
…", from the PR's "Update branch" button or a `git pull`). GitHub has to drop the merge and replay the commits before it
one by one, and the first one that conflicts with `main` stops it. Find it with:

```bash
git log --merges --oneline origin/main..origin/<branch>
```

**What happened:** `vm2.DevOps` PR #44 (14 commits) carried such a merge commit, and some of its early commits had
already reached `main` as rebased copies with different SHAs, so replaying them conflicted at the very first one.

**Fix:** if the branch already contains `main`'s current tip (that is what the merge commit did), collapse it into a single
commit on top of `main`. Its content is exactly "`main` + your changes", so nothing is lost:

```bash
git switch <branch>
git status -sb                                     # must show no ahead/behind against origin/<branch>
git merge-base --is-ancestor origin/main HEAD && echo "safe: the branch contains main"
git reset --soft origin/main                       # history = main; all of the branch's changes stay staged
git commit                                         # one Conventional Commits message for the whole PR
[[ $(git rev-parse HEAD^{tree}) == $(git rev-parse origin/<branch>^{tree}) ]] && echo "identical content"
git pushf                                          # NOT Sync, NOT pull
```

The PR then shows one commit, and "Rebase and merge" works again. The cost is that the branch's individual commits
become one; the PR's discussion on GitHub keeps the detail. If `merge-base --is-ancestor` fails, `main` has moved since the
merge: run `git sync` first and resolve the conflicts, then repeat.

To avoid it, see [Keeping a PR branch up to date](#keeping-a-pr-branch-up-to-date-never-merge-main-into-it).

## Quick 10-Command Cheat Sheet

```bash
# 1) check state: status + branch + ahead/behind + rebase-in-progress
git preflight
# 2) fetch + rebase onto fresh origin/main
git sync
# 3) if conflicts: resolve + stage (rerere auto-resolves and auto-stages repeats)
git add <resolved-files>
# 4) lockfile conflicts: the nugetlock merge driver takes a side for you — just regenerate
dotnet restore --force-evaluate && git add '**/packages.lock.json'
# 5) continue rebase
git rbcontinue
# 6) smoke checks
# dotnet build / dotnet test (as needed)
# 7) push new commits
git push
# 8) push after a rebase (NEVER plain push, NEVER pull)
git pushf
# 9) if confused, recover
git rbabort || git merge --abort
# 10) what did I just commit?
git last
```
