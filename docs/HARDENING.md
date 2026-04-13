# vm2.DevOps Hardening Roadmap

vm2.DevOps enforces discipline on every repo it supports but applies none to itself.
This document lists the concrete steps to close that gap, ordered from highest to lowest risk.

---

## 1. Enable Branch Protection on `main`  *(critical)*

Currently `main` has no protection: direct-push is allowed, no reviews required, no CI gates.

**Actions:**

- Require pull requests to merge (no direct push).
- Require at least 1 approval (can be a self-review via `gh pr review --approve`).
- Require status checks to pass before merging (see [item 2](#2-add-a-ci-workflow-for-vm2devops-itself--critical)).
- Enable "Enforce for administrators".

---

## 2. Add a CI Workflow for vm2.DevOps Itself  *(critical)*

Every consumer gets a CI pipeline. vm2.DevOps gets nothing. At minimum, CI should run:

- **ShellCheck** on all `*.sh` files (`.shellcheckrc` is already present).
- **JSON validation** (`jq empty`) on all `*.json` config/config files.
- **Markdownlint** on `docs/` and root `.md` files.

Add `.github/workflows/CI.yaml` that runs on push and pull_request, calling a simple job matrix
for the three checks above.

---

## 3. Pin Consumers to Tags, Not `@main`  *(high)*

Every consumer workflow references reusable workflows as:

```yaml
uses: vmelamed/vm2.DevOps/.github/workflows/_ci.yaml@main
```

A breaking change in a reusable workflow is **instantly live** in every consumer, with no opt-in
window.

**Actions:**

- Introduce semver tags (`v1`, `v1.0`, `v1.0.0`) on vm2.DevOps. Even just a floating `v1` major tag is enough.
- Update the template in vm2.Templates to pin `@v1` instead of `@main`.
- When a breaking interface change is needed, bump to `v2` and give consumers a migration window.
- Use `git tag -f v1 HEAD && git push --force origin v1` to advance the floating major tag on non-breaking releases.

---

## 4. Add Script Tests  *(medium)*

The bash scripts are complex enough to break quietly. No unit tests exist.

Use [BATS](https://github.com/bats-core/bats-core) with
[bats-support](https://github.com/bats-core/bats-support) +
[bats-assert](https://github.com/bats-core/bats-assert).
Build the test suite bottom-up, from pure leaf modules to orchestrators:

### Layer 0 — Pure constants  *(zero external dependencies)*

`lib/_error_codes.sh`, `lib/_constants.sh`

- Source the file in a subshell; assert every symbolic name resolves to the expected integer.
- Assert `error_message()` returns the right string for known codes and degrades gracefully for unknown ones.
- These tests never fail due to environment differences — ideal smoke-test gate.

### Layer 1 — Pure functions  *(depend only on Layer 0)*

`lib/_predicates.sh`, `lib/_sanitize.sh`, `lib/_semver.sh`

- `_predicates.sh`: table-driven tests for `is_defined`, `is_integer`, `is_non_negative`, `is_in`, etc.
  Both happy-path and boundary ("empty string", "zero", "negative") cases.
- `_sanitize.sh`: round-trip tests — assert that sanitized output matches expected strings,
  no filesystem or process access needed.
- `_semver.sh`: the highest-value target here.
  Test every regex (`semverRegex`, `semverPrereleaseRegex`, `semverTagRegex`, …) against a matrix
  of valid/invalid inputs.  Test semver comparison and component-extraction functions.
  No git, no network — pure string matching.

### Layer 2 — I/O and argument parsing  *(touch env/stderr, no external processes)*

`lib/_diagnostics.sh`, `lib/_args.sh`

- `_diagnostics.sh`: redirect stderr to a temp file; assert error/warn/info output format.
- `_args.sh`: invoke argument-parse functions with crafted `$@` arrays; assert flag variables
  are set correctly and that invalid input returns `err_invalid_arguments`.

### Layer 3 — Pure parts of external-process modules  *(no real git/gh needed)*

`lib/_git.sh` (URL and owner/name validation functions only)

- Test `is_valid_github_owner`, `is_valid_repo_name`, URL-parse helpers with table-driven inputs.
- Stub `git` and `gh` with local `function` overrides for the few calls that do need a process.

### Layer 4 — CI script logic  *(mock git + gh)*

`.github/scripts/compute-prerelease-version.sh`, `compute-release-version.sh`

These own the version-bump logic and are the highest-risk scripts in the repo.

- Stub `git tag --list`, `git describe`, and `gh` with canned outputs.
- Assert computed version strings against known expected values (first commit, pre-release bump,
  release bump, build-label passthrough).

### Layer 5 — Top-level orchestrators  *(integration, mock filesystem)*

`diff-shared.sh`, `repo-setup.sh`, `validate-input.sh`

- Use `BATS_TMPDIR` for scratch repos; stub network calls.
- Focus on argument-validation paths and error-exit codes rather than end-to-end execution.

### Wire-up

Add `tests/` to the repo root.
Run `bats tests/` in the CI workflow from [item 2](#2-add-a-ci-workflow-for-vm2devops-itself--critical).
Install BATS and helpers via `git submodule` under `tests/libs/`
(same pattern as other repos that use git submodules for dev tooling).

---

## 5. Define a Breaking Change Process  *(medium)*

There is no documented procedure for what to do when a reusable workflow interface changes
(new required input, removed output, renamed secret, etc.).

**Actions:**

- Document in `ARCHITECTURE.md` what constitutes a breaking change vs. a non-breaking change.
- Add a checklist item to the PR template: *"Does this PR change a reusable workflow interface?"*
- Commit breaking changes with `feat!:` or `refactor!:` so they surface clearly in the changelog.
- Notify consumers via the CHANGELOG (and eventually via tag-pinning from item 3).

---

## 6. Adopt git-cliff for vm2.DevOps Own Changelog  *(low)*

vm2.DevOps authors and enforces git-cliff based changelogs for all consumers but maintains its own
`CHANGELOG.md` by hand, which drifts and is inconsistently formatted.

**Actions:**

- Add `changelog/cliff.prerelease.toml` and `changelog/cliff.release-header.toml` to vm2.DevOps
  (copy from vm2.Templates content).
- Wire the same Prerelease/Release workflows that vm2.DevOps already provides.

---

## 7. Archive or Retire `vmelamed/.github`  *(low)*

Now that `vm2.Templates/templates/AddNewPackage/content/` is the single source of truth for
consumer-facing files, the `vmelamed/.github/workflow-templates/` directory is a redundant copy
that can silently diverge.

**Actions:**

- Remove `workflow-templates/` from `vmelamed/.github` (or archive the repo).
- Update its `README.md` to redirect to vm2.Templates.
- If GitHub's "starter workflow" discovery (org-level) was ever the goal, note that GitHub only
  surfaces those templates from the `.github` repo; decide whether to keep a thin redirect or drop
  the feature entirely.

---

## 8. Focused PR + CHANGELOG Guardrails  *(high)*

The recurring failure mode is broad PRs that mix code/config changes with changelog edits.
This creates avoidable rebase conflicts, especially at the top of `CHANGELOG.md`.

**Target operating model:**

- Feature/infra PRs are code/config only.
- Changelog curation happens in tiny dedicated PRs.
- Release flows allow changelog changes but validate structure/quality.

**Implementation plan:**

1. Add a PR scope guard in CI (deny mode for normal PRs).

- Fail `pull_request` runs when `CHANGELOG.md` is changed unexpectedly.
- Allow via explicit signal only (for example PR label/title convention such as `release` or `changelog`).

1. Add changelog quality checks (allow mode for prerelease/release).

- Detect duplicate top-level version headings.
- Detect malformed basic structure.
- Fail with actionable output.

1. Add a pre-PR local sanity command.

- One command to list changed files and fail fast when `CHANGELOG.md` appears unexpectedly.
- Provide as reusable script + optional VS Code task.

1. Harden branch policy.

- Keep force-push disabled on `main`.
- Require status checks, up-to-date branch, and approval.

1. Roll out incrementally.

- Start in one repo (vm2.TestUtilities), then copy the same guardrails to vm2.SemVer, vm2.Ulid,
    vm2.Glob, vm2.Linq.Expressions, and vm2.Templates.

**Expected impact:**

- Smaller, easier-to-review PRs.
- Fewer rebase conflicts around `CHANGELOG.md`.
- Less reliance on memory and manual discipline.

---

## Summary Table

| # | Item | Risk if ignored | Effort |
|---|------|----------------|--------|
| 1 | Branch protection | Direct-push breakage lands silently on main | Low – 5 min in repo settings |
| 2 | CI for DevOps itself | Bad scripts reach main undetected | Medium – new workflow file |
| 3 | Tag pinning for consumers | Any push to main can break all consumers | Medium – tagging + template update |
| 4 | Script tests | Silent regressions in automation | High – 5-layer BATS suite |
| 5 | Breaking change process | Consumers surprised by interface changes | Low – documentation + PR template |
| 6 | git-cliff for own CHANGELOG | Inconsistent release notes | Low – copy config from templates |
| 7 | Retire `vmelamed/.github` | Duplicate drift in workflow templates | Low – delete + redirect |
| 8 | Focused PR + CHANGELOG guardrails | Rebase churn and accidental changelog regressions | Medium – CI checks + small script + policy |
