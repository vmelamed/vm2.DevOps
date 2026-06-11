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
repo-setup runs). The win is the standardized env contract + summary + dry-run, not the loop itself.

**Trigger:** The next time a fleet-wide loop gets hand-written — e.g., rolling out the new git settings via
`foreach-repo.sh -- repo-setup.sh --audit`.
**Effort:** ~Half a day including docs.
