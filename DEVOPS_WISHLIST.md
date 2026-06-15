# DevOps Wishlist

DevOps is **feature-frozen** until vm2.Repository ships a preview. This list is where the itch goes: when a DevOps idea
strikes, capture it here in two minutes and get back to the Repository. Items are executed **when pulled by pain** (the
problem actually bites), not pushed by the itch — or batched in a quarterly review.

The list is ordered by priority — add new items where they belong, not at the end.

## 1. Demote `latency`/`throughput` to record-only

**What:** Delete the `latency` and `throughput` threshold blocks from `BENCHER_ARGS` in
`.github/workflows/_benchmarks.yaml`. Both measures stay uploaded and charted in Bencher — they just stop gating CI.
Keep `allocated` (percentage) and `gen1`/`gen2`-collects (static caps) as the hard gates: they are deterministic, so a
false alarm is nearly impossible and a real regression is exactly what should block a merge.

**Why:** The timing gates' lifetime scorecard is 0 true regressions caught, 100% false alarms (degenerate near-zero
percentage thresholds; runner-image step changes; ±40% shared-runner jitter on sub-µs benchmarks). Deterministic measures
gate well; noisy measures chart well.

**Trigger:** The next time the latency/throughput gate cries wolf.
**Effort:** Minutes — thresholds are per-measure, `--err` stays for the remaining gated measures.

## 2. `foreach-repo.sh` — fleet-wide Where/ForEach utility

**What:** `scripts/bash/foreach-repo.sh` (three-file convention, on the lib): iterate `$vm2_repositories`, filter by a
predicate command, run an action command. LINQ over the repo fleet: `all_repos.Where(condition).ForEach(action)`.

- Action/condition as **argv after `--`** (no eval-quoting hell); pipes allowed via `bash -c`.
- **Environment contract:** runs with `cwd = repo root`; exports `REPO_NAME` (`vm2.Ulid`), `REPO_ROOT` (abs path),
  `REPO` (`owner/name` from the actual remote via `get_repo_state`), `REPO_DEFAULT_BRANCH`. Local-first
  (`resolve_repo_root`); remote conditions stay expressible as `gh api "repos/$REPO/..."`.
- **Keep-going + summary** (`matched / skipped / failed`, like the rebuild dispatcher); `--fail-fast` opt-in;
  dry-run free from the lib.
- **Not in scope:** `--parallel`, retrofitting `diff-shared.sh` (interactive — stays specialized), any DSL or
  config-driven pipeline (the inner-platform effect: reinventing bash inside bash, badly).

**Why:** The pattern has appeared three times (rebuild-bench-history dispatch, diff-shared targets, fleet-wide
setup-repo runs). The win is the standardized env contract + summary + dry-run, not the loop itself.

**Trigger:** The next time a fleet-wide loop gets hand-written — e.g., rolling out the new git settings via
`foreach-repo.sh -- setup-repo.sh --audit`.
**Effort:** ~Half a day including docs.

## 3. DevOps for vm2.DevOps — ShellCheck, tests, PR gates

**What:** Give vm2.DevOps the same rigor it enforces on every other repo. Candidate pieces, roughly in value order:

- **actionlint** in CI — static analysis purpose-built for GitHub Actions workflows (expression typos, invalid inputs,
  shellcheck of embedded `run:` blocks — the YAML-embedded bash that the IDE ShellCheck extension never sees).
- **ShellCheck as a CI gate** over `scripts/bash/` and `.github/scripts/` — the IDE extension covers interactive editing;
  CI covers everything else (bulk edits, AI-generated changes, future contributors).
- **Tests for the bash library** (e.g. bats-core) — 67 functions in `scripts/bash/lib/` with zero automated tests;
  start with the highest-risk ones (`_sanitize.sh`, `_semver.sh`, `_args.sh`).
- **PR gate** — a `Postrun-CI`-style required check on vm2.DevOps's own PRs running the above.
- **(Bigger, separate decision)** Release channel for the reusable workflows: consumers reference `@main`, so every merge
  deploys fleet-wide instantly and a PR cannot exercise the very workflows it changes. Tagged refs (`@v1`) or a
  `stable` branch would decouple "merged" from "deployed" — at the cost of a promotion step.

**Why:** vm2.DevOps has the largest blast radius in the ecosystem (all repos consume it `@main`) and the weakest gates —
the inverse of how it should be. Today a workflow typo ships to every repo the moment it merges.

**Trigger:** The first time a vm2.DevOps merge breaks a consumer repo's CI (or earlier, if a quiet week begs for it —
but vm2.Repository ships first).
**Effort:** actionlint + ShellCheck + gate: ~half a day. Library tests: incremental, start small. Release channel: a
design discussion first.
