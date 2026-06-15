# Git Playbook (Rebase-First)

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
`scripts/bash/setup-repo.defaults.sh` — **that table is the source of truth**, not this document. Run `setup-repo.sh` after
cloning a vm2 repo (or against an existing clone to re-sync). What it applies and why:

| Setting                  | Value                                    | Why it matters                                                              |
|--------------------------|------------------------------------------|------------------------------------------------------------------------------|
| `core.hooksPath`         | `$VM2_REPOS/vm2.DevOps/scripts/githooks` | shared Git hooks across all vm2 repos                                         |
| `commit.template`        | SoT `.gitmessage`                        | Conventional Commits template on every commit                                 |
| `merge.ff`               | `only`                                   | refuses non-fast-forward merges → linear history                              |
| `pull.rebase`            | `true`                                   | aligns pull behavior with the rebase-first flow                               |
| `fetch.prune`            | `true`                                   | removes stale remote refs                                                     |
| `push.autoSetupRemote`   | `true`                                   | the first push of a new branch sets up tracking automatically                 |
| `rerere.enabled`         | `true`                                   | remembers and reapplies repeated conflict resolutions                         |
| `rerere.autoUpdate`      | `true`                                   | also **stages** rerere's auto-resolutions — replayed conflicts sail through   |
| `rebase.autoStash`       | `true`                                   | auto-stash/reapply a dirty tree around rebase — no interruptions              |
| `merge.conflictstyle`    | `zdiff3`                                 | conflict hunks include the common base — see *what changed*, not just results |
| `push.useForceIfIncludes`| `true`                                   | `--force-with-lease` also fails if the remote moved while you were rebasing   |
| `tag.sort`               | `version:refname`                        | `git tag` lists `v1.10.0` after `v1.9.0`, not before it                       |
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

| Alias                             | Use it for                                                                                |
|-----------------------------------|--------------------------------------------------------------------------------------------|
| `git st`                          | quick status                                                                                |
| `git lg`                          | history graph                                                                               |
| `git last`                        | what did I just commit?                                                                     |
| `git undo`                        | un-commit the last commit, keep the changes staged                                          |
| `git sync`                        | fetch + rebase onto fresh `origin/main` in one move                                         |
| `git preflight`                   | start-of-day / pre-push check: status, branch, ahead/behind, rebase-in-progress             |
| `git rbcontinue` / `git rbabort`  | continue / abort a rebase                                                                   |
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
