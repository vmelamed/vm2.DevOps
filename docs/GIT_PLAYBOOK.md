# Git Playbook (Rebase-First)

This playbook is optimized for solo/low-concurrency repos and for a rebase-first workflow.

## 1) Personal Git Playbook

### Start of day (per repo)

1. `git status`
2. `git branch --show-current`
3. `git fetch --all --prune`
4. `git rev-list --left-right --count origin/main...HEAD`

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
5. `git push`

### Conflict protocol (when VS Code looks inconsistent)

1. Stop making unrelated edits
2. Run `git status` and identify mode:
   - Rebase in progress
   - Merge in progress
   - Normal state
3. Resolve only unmerged files listed by Git
4. Continue operation:
   - Rebase: `git rebase --continue`
   - Merge: `git commit`
5. Safe abort options:
   - `git rebase --abort`
   - `git merge --abort`

### Golden rule

Never mix operations:

- Do not start merge while rebasing
- Do not start rebase while merging
- Finish or abort one operation before starting another

## 2) Safe Git Config + Aliases

Run once (global):

```bash
git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global fetch.prune true
git config --global rerere.enabled true
git config --global merge.conflictstyle zdiff3

git config --global alias.st "status -sb"
git config --global alias.br "branch -vv"
git config --global alias.lg "log --oneline --graph --decorate --all -20"
git config --global alias.aheadbehind "rev-list --left-right --count origin/main...HEAD"
git config --global alias.whereami "!git status -sb && echo --- && git branch --show-current && echo --- && git rev-list --left-right --count origin/main...HEAD"
git config --global alias.syncmain "!git fetch origin --prune && git rebase origin/main"
git config --global alias.unstage "restore --staged ."
git config --global alias.abortall "!git rebase --abort 2>/dev/null; git merge --abort 2>/dev/null; true"
```

Why these matter:

- `pull.rebase=true`: aligns pull behavior with rebase-first flow
- `rebase.autoStash=true`: reduces interruptions from local unstaged edits
- `fetch.prune=true`: removes stale remote refs
- `rerere.enabled=true`: remembers and reapplies repeated conflict resolutions
- `zdiff3`: gives better conflict context than default style

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

1. Rebase at start of day: `git fetch --prune && git rebase origin/main`
2. Rebase again before switching PR from draft to review
3. Rebase again before final merge window if main has moved

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
# 1) check state
git status
# 2) branch
git branch --show-current
# 3) refresh remotes
git fetch --all --prune
# 4) divergence vs main
git rev-list --left-right --count origin/main...HEAD
# 5) rebase
git rebase origin/main
# 6) if conflicts: resolve + stage
git add <resolved-files>
# 7) continue rebase
git rebase --continue
# 8) smoke checks
# dotnet build / dotnet test (as needed)
# 9) push
git push
# 10) if confused, recover
git rebase --abort || git merge --abort
```
