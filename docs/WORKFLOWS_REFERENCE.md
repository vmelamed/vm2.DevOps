# Workflows Reference

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Workflows Reference](#workflows-reference)
  - [\_ci.yaml](#_ciyaml)
    - [Inputs](#inputs)
    - [Secrets](#secrets)
    - [Concurrency](#concurrency)
    - [Jobs](#jobs)
  - [\_build.yaml](#_buildyaml)
    - [Inputs](#inputs-1)
    - [Permissions](#permissions)
    - [Cache Keys and Artifacts](#cache-keys-and-artifacts)
    - [Script](#script)
  - [\_test.yaml](#_testyaml)
    - [Inputs](#inputs-2)
    - [Secrets](#secrets-1)
    - [Permissions](#permissions-1)
    - [Script](#script-1)
  - [\_benchmarks.yaml](#_benchmarksyaml)
    - [Inputs](#inputs-3)
    - [Secrets](#secrets-2)
    - [Permissions](#permissions-2)
    - [Script](#script-2)
  - [\_pack.yaml](#_packyaml)
    - [Inputs](#inputs-4)
    - [Permissions](#permissions-3)
    - [Script](#script-3)
  - [\_prerelease.yaml](#_prereleaseyaml)
    - [Inputs](#inputs-5)
    - [Secrets](#secrets-3)
    - [⚠️ `RELEASE_PAT` — Special Setup Required](#️-release_pat--special-setup-required)
      - [Why it's needed](#why-its-needed)
      - [Setup steps](#setup-steps)
      - [What happens if this is misconfigured](#what-happens-if-this-is-misconfigured)
      - [⚠️ Security considerations](#️-security-considerations)
    - [Permissions](#permissions-4)
    - [Concurrency](#concurrency-1)
    - [Jobs](#jobs-1)
    - [Scripts](#scripts)
  - [\_release.yaml](#_releaseyaml)
    - [Inputs](#inputs-6)
    - [Secrets](#secrets-4)
    - [⚠️ `RELEASE_PAT` — Special Setup Required](#️-release_pat--special-setup-required-1)
    - [Permissions](#permissions-5)
    - [Concurrency](#concurrency-2)
    - [Jobs](#jobs-2)
    - [Scripts](#scripts-1)
  - [\_clear\_cache.yaml](#_clear_cacheyaml)
    - [Inputs](#inputs-7)
    - [Permissions](#permissions-6)
  - [\_rebuild\_bench\_history.yaml](#_rebuild_bench_historyyaml)
    - [Inputs](#inputs-8)
    - [Secrets](#secrets-5)
    - [Script](#script-4)
  - [RebuildBenchHistory-AllRepos.yaml (fan-out, in vm2.DevOps)](#rebuildbenchhistory-allreposyaml-fan-out-in-vm2devops)
    - [Inputs](#inputs-9)
    - [Secrets](#secrets-6)
    - [Permissions](#permissions-7)
    - [Script](#script-5)

<!-- /TOC -->

Reusable workflows in `vm2.DevOps/.github/workflows/`. All are triggered via `workflow_call`.

## _ci.yaml

Orchestrates the full CI pipeline: validate → build → test / benchmarks / pack.

### Inputs

| Input                        | Type      | Required | Default             | Description                                                           |
| :--------------------------- | :-------- | :------- | :------------------ | :-------------------------------------------------------------------- |
| `build-projects`             | `string`  | no       | —                   | JSON array of project/solution paths to build. Auto-detects if empty. |
| `test-projects`              | `string`  | no       | —                   | JSON array of test project paths. Skipped if empty.                   |
| `benchmark-projects`         | `string`  | no       | —                   | JSON array of benchmark project paths. Skipped if empty.              |
| `package-projects`           | `string`  | no       | —                   | JSON array of project paths to pack. Skipped if empty.                |
| `runners-os`                 | `string`  | no       | `["ubuntu-latest"]` | JSON array of runner OS monikers.                                     |
| `preprocessor-symbols`       | `string`  | no       | `""`                | Semicolon-separated preprocessor symbols.                             |
| `min-coverage-pct`           | `number`  | no       | `80`                | Minimum acceptable code coverage percentage.                          |
| `max-regression-pct`         | `number`  | no       | `20`                | Maximum acceptable performance regression percentage.                 |
| `max-gen1-collects`          | `number`  | no       | `2`                 | Max Gen1 GC collections per 1000 ops (Bencher static threshold).      |
| `max-gen2-collects`          | `number`  | no       | `1`                 | Max Gen2 GC collections per 1000 ops (Bencher static threshold).      |
| `minver-tag-prefix`          | `string`  | no       | `v`                 | MinVer tag prefix for version calculation.                            |
| `minver-prerelease-id`       | `string`  | no       | `preview.0`         | MinVer default pre-release identifiers.                               |
| `reset-benchmark-thresholds` | `boolean` | no       | `false`             | Reset Bencher thresholds for this run (see ARCHITECTURE.md).          |
| `skip-build`                 | `boolean` | no       | `false`             | Skip the `build` job entirely.                                        |
| `skip-tests`                 | `boolean` | no       | `false`             | Skip the `test` job entirely.                                         |
| `skip-benchmarks`            | `boolean` | no       | `false`             | Skip the `benchmarks` job entirely.                                   |
| `skip-packages`              | `boolean` | no       | `false`             | Skip the `pack` job entirely.                                         |

`_ci.yaml` no longer takes a `dotnet-version` or `configuration` input: the .NET SDK version comes from `global.json`,
and `Configuration` is resolved by `Directory.Build.props`/the project itself (see
[CONVENTIONS.md — Build Configuration](../.github/CONVENTIONS.md#build-configuration-tfms-rids-and-preprocessor-symbols)).
See [ARCHITECTURE.md — Per-run threshold reset](ARCHITECTURE.md#per-run-threshold-reset-reset-benchmark-thresholds) for
`reset-benchmark-thresholds`.

### Secrets

| Secret                    | Required | Description                            |
| :------------------------ | :------- | :------------------------------------- |
| `CODECOV_TOKEN`           | no       | Codecov API token for coverage uploads |
| `BENCHER_API_TOKEN`       | no       | Bencher.dev API token for benchmarks   |
| `REPORTGENERATOR_LICENSE` | no       | ReportGenerator license key            |

### Concurrency

    group: ci-${{ github.workflow_ref }}
    cancel-in-progress: true

### Jobs

| Job              | Needs                     | Matrix                            | Condition                                                                             |
| :--------------- | :------------------------ | :-------------------------------- | :------------------------------------------------------------------------------------ |
| `validate-input` | —                         | —                                 | Always                                                                                |
| `build`          | `validate-input`          | `runners-os × build-projects`     | `build-projects[0] != null` and `skip-build` is `false`                               |
| `test`           | `validate-input`, `build` | `runners-os`                      | `test-projects[0] != null` and `skip-tests` is `false`                                |
| `benchmarks`     | `validate-input`, `build` | `runners-os × benchmark-projects` | `benchmark-projects[0] != null`, no `[skip bm]` on push, `skip-benchmarks` is `false` |
| `pack`           | `validate-input`, `build` | `runners-os × package-projects`   | `package-projects[0] != null`, `build` succeeded/skipped, `skip-packages` is `false`  |

`build-projects`, `test-projects`, `benchmark-projects`, and `package-projects` are JSON arrays; `[0] != null` means
the array's first element is not `null` — the convention `validate-input.sh` now uses to mean "nothing to do here,"
replacing the earlier `["__skip__"]` sentinel.

---

## _build.yaml

Compiles the project and caches build artifacts for downstream jobs.

### Inputs

| Input                  | Type     | Required | Default         | Description                                                                                                             |
| :--------------------- | :------- | :------- | :-------------- | :---------------------------------------------------------------------------------------------------------------------- |
| `build-project`        | `string` | no       | —               | Path to project to build. Auto-detects if empty.                                                                        |
| `runner-os`            | `string` | no       | `ubuntu-latest` | Runner OS.                                                                                                              |
| `preprocessor-symbols` | `string` | no       | `""`            | Preprocessor symbols.                                                                                                   |
| `job-index`            | `number` | no       | `0`             | The calling job's own matrix leg index (`strategy.job-index`), used only to name this leg's uploaded artifact uniquely. |

`_build.yaml` no longer takes `dotnet-version`, `configuration`, `minver-tag-prefix`, or `minver-prerelease-id` inputs.
`build.sh` is invoked with only the project path and `--define`; the MinVer tag prefix/pre-release identifiers come
from the `MINVERTAGPREFIX`/`MINVERDEFAULTPRERELEASEIDENTIFIERS` repo variables via `env:`, and `Configuration` is left
to resolve from `Directory.Build.props`/the project itself (see
[CONVENTIONS.md — Build Configuration](../.github/CONVENTIONS.md#build-configuration-tfms-rids-and-preprocessor-symbols)).

### Permissions

    contents: read
    packages: read

### Cache Keys and Artifacts

| Mechanism                                                | Name / Key Pattern                                 |
| :------------------------------------------------------- | :------------------------------------------------- |
| NuGet cache (weekly)                                     | `nuget-{os}-{YYYY-WVV}-{lockfile-hash}`            |
| Build artifacts (workflow artifact, `retention-days: 1`) | `built-artifacts-{runner.os}-{run_id}-{job-index}` |

### Script

`build.sh`

---

## _test.yaml

Runs tests, generates coverage reports, uploads to Codecov, and posts PR comments.

### Inputs

| Input                  | Type     | Required | Default         | Description                                         |
| :--------------------- | :------- | :------- | :-------------- | :-------------------------------------------------- |
| `test-projects`        | `string` | **yes**  | —               | JSON array of test project paths.                   |
| `test-subject`         | `string` | no       | —               | Name of the project under test (inferred if empty). |
| `runner-os`            | `string` | no       | `ubuntu-latest` | Runner OS.                                          |
| `configuration`        | `string` | no       | `Release`       | Build configuration.                                |
| `preprocessor-symbols` | `string` | no       | `""`            | Preprocessor symbols.                               |
| `min-coverage-pct`     | `number` | no       | `80`            | Minimum acceptable code coverage percentage.        |
| `minver-tag-prefix`    | `string` | no       | `v`             | MinVer tag prefix.                                  |
| `minver-prerelease-id` | `string` | no       | `preview.0`     | MinVer pre-release identifiers.                     |

### Secrets

| Secret                    | Required | Description                            |
| :------------------------ | :------- | :------------------------------------- |
| `CODECOV_TOKEN`           | **yes**  | Codecov API token for coverage uploads |
| `REPORTGENERATOR_LICENSE` | no       | ReportGenerator license key            |

### Permissions

    contents: read
    checks: write
    pull-requests: write

### Script

`run-tests.sh`

---

## _benchmarks.yaml

Runs BenchmarkDotNet benchmarks and tracks results via Bencher.dev.

### Inputs

| Input                        | Type      | Required | Default         | Description                                           |
| :--------------------------- | :-------- | :------- | :-------------- | :---------------------------------------------------- |
| `benchmark-project`          | `string`  | **yes**  | —               | Path to the benchmark project.                        |
| `runner-os`                  | `string`  | no       | `ubuntu-latest` | Runner OS.                                            |
| `target-framework`           | `string`  | no       | `10.0.x`        | Version of .NET SDK to use.                           |
| `configuration`              | `string`  | no       | `Release`       | Build configuration.                                  |
| `preprocessor-symbols`       | `string`  | no       | `""`            | Preprocessor symbols.                                 |
| `minver-tag-prefix`          | `string`  | no       | `v`             | MinVer tag prefix.                                    |
| `minver-prerelease-id`       | `string`  | no       | `preview.0`     | MinVer pre-release identifiers.                       |
| `max-regression-pct`         | `number`  | no       | `20`            | Maximum acceptable performance regression (%).        |
| `max-gen1-collects`          | `number`  | no       | `2`             | Max Gen1 GC collections / 1000 ops (static).          |
| `max-gen2-collects`          | `number`  | no       | `1`             | Max Gen2 GC collections / 1000 ops (static).          |
| `reset-benchmark-thresholds` | `boolean` | no       | `false`         | Reset Bencher thresholds if a regression is expected. |

Note the input is `target-framework` here (not `dotnet-version` as in `_ci.yaml`'s own input before it was removed).

### Secrets

| Secret              | Required | Description           |
| :------------------ | :------- | :-------------------- |
| `BENCHER_API_TOKEN` | **yes**  | Bencher.dev API token |

### Permissions

    contents: read
    checks: write
    pull-requests: write

### Script

`run-benchmarks.sh`

---

## _pack.yaml

Validates that projects can be packed into NuGet packages.

### Inputs

| Input                  | Type      | Required | Default         | Description                                                                                                                 |
| :--------------------- | :-------- | :------- | :-------------- | :-------------------------------------------------------------------------------------------------------------------------- |
| `package-project`      | `string`  | **yes**  | —               | Path to the project to pack.                                                                                                |
| `runner-os`            | `string`  | no       | `ubuntu-latest` | Runner OS.                                                                                                                  |
| `configuration`        | `string`  | no       | `Release`       | Declared but not currently wired to `pack.sh` — `dotnet_pack()` resolves `Configuration` from the project itself.           |
| `preprocessor-symbols` | `string`  | no       | `""`            | Preprocessor symbols.                                                                                                       |
| `minver-tag-prefix`    | `string`  | no       | `v`             | MinVer tag prefix.                                                                                                          |
| `minver-prerelease-id` | `string`  | no       | `preview.0`     | MinVer pre-release identifiers.                                                                                             |
| `skip-build-cache`     | `boolean` | no       | `false`         | Skip downloading the build job's artifacts; build during pack instead (e.g. template packages with no separate build step). |

`_pack.yaml` no longer takes a `dotnet-version` input.

### Permissions

    contents: read
    packages: read

### Script

`pack.sh`

---

## _prerelease.yaml

Computes a prerelease version, updates the changelog, tags, and publishes a prerelease NuGet package.

### Inputs

| Input                  | Type     | Required | Default     | Description                                                                                                                        |
| :--------------------- | :------- | :------- | :---------- | :--------------------------------------------------------------------------------------------------------------------------------- |
| `package-projects`     | `string` | no       | `[]`        | JSON array of project paths to package and publish. Auto-detects if empty.                                                         |
| `preprocessor-symbols` | `string` | no       | `""`        | Preprocessor symbols.                                                                                                              |
| `minver-tag-prefix`    | `string` | no       | `v`         | MinVer tag prefix.                                                                                                                 |
| `minver-prerelease-id` | `string` | no       | `preview.0` | Pre-release identifier (e.g., `preview.0`, `alpha`, `rc`).                                                                         |
| `reason`               | `string` | no       | `""`        | Reason for manual pre-release.                                                                                                     |
| `sha`                  | `string` | no       | `""`        | Exact git SHA to compute the version from and tag (pins the prerelease to the CI-validated commit); defaults to `HEAD` when empty. |

`_prerelease.yaml` no longer takes `dotnet-version`, `nuget-server`, or `save-package-artifacts` inputs — NuGet server
selection and artifact-saving are handled entirely in the *consumer's own* `Prerelease.yaml` (its `env:` block), not
threaded through this reusable workflow.

### Secrets

| Secret        | Required | Description                                   |
| :------------ | :------- | :-------------------------------------------- |
| `RELEASE_PAT` | **yes**  | PAT with `contents:write` for pushing to main |

`_prerelease.yaml` itself declares no `NUGET_API_KEY` secret — the actual NuGet push, and its API key, live in the
consumer's own `Prerelease.yaml` job (see [Architecture — NuGet Authentication](ARCHITECTURE.md#nuget-authentication)).

### ⚠️ `RELEASE_PAT` — Special Setup Required

`RELEASE_PAT` is not a regular secret. It requires **both** secret creation **and** branch ruleset bypass configuration to
function correctly.

#### Why it's needed

The `_prerelease.yaml` and `_release.yaml` workflows push commits and tags directly to `main`
(e.g., changelog updates, version tags). Branch protection rules block direct pushes — including
from GitHub Actions using the default `github.token`. `RELEASE_PAT` is a Personal Access Token
that belongs to a user (e.g. Admin) configured as a **bypass actor** in the branch ruleset.

#### Setup steps

1. **Create a fine-grained PAT** for the repository owner with these permissions:
   - `Contents: Read and write` (push commits and tags)
   - `Metadata: Read-only`

2. **Add as a repository secret:**
   - Go to *Settings → Secrets and variables → Actions*
   - Create secret named `RELEASE_PAT`

3. **Configure branch ruleset bypass** (this is the step most people miss):
   - Go to *Settings → Rules → Rulesets*
   - Edit the ruleset protecting `main`
   - Under *Bypass list*, add the PAT owner as a bypass actor
   - The actor must have **"Always"** bypass permission (not "Pull requests only")

4. **Verify** by running a manual `workflow_dispatch` of the Prerelease workflow.

#### What happens if this is misconfigured

| Symptom                                                                | Cause                                     |
| :--------------------------------------------------------------------- | :---------------------------------------- |
| `_prerelease.yaml` fails with "push declined"                          | PAT owner not in bypass list              |
| `_prerelease.yaml` fails with "Resource not accessible by integration" | PAT lacks `Contents: write` permission    |
| `_release.yaml` creates tag but changelog push fails                   | PAT expired or revoked                    |
| Everything works on `workflow_dispatch` but fails on auto-trigger      | Wrong PAT scope (classic vs fine-grained) |

#### ⚠️ Security considerations

- The PAT owner can push directly to `main`, bypassing all branch protections
- If the PAT leaks, an attacker can push arbitrary code to `main`
- **Mitigation:** Use fine-grained PATs (scoped to single repo), set short expiration,
  rotate regularly
- Monitor the repository *Settings → Security log* for unexpected pushes

> **Cross-reference:** See [ERROR_RECOVERY.md](ERROR_RECOVERY.md#branch-protection-bypass) for
> recovery procedures if release pushes fail due to PAT issues.

### Permissions

    contents: write
    packages: read
    actions: read

### Concurrency

    group: prerelease-${{ github.ref }}
    cancel-in-progress: false

### Jobs

| Job                  | Needs                | Description                                                                 |
| :------------------- | :------------------- | :-------------------------------------------------------------------------- |
| `prepare-prerelease` | —                    | Computes the prerelease version, updates CHANGELOG.md, creates the tag      |
| `package`            | `prepare-prerelease` | Checks out the tag and builds+packs each project (does **not** push)        |
| `collect-artifacts`  | `package`            | Collects the uploaded package artifacts' IDs into the `artifact-ids` output |

The actual `dotnet nuget push` happens in the *consumer's* own `Prerelease.yaml` (its
`publish-prerelease` job), which downloads the artifacts by the IDs above — see
[Architecture](ARCHITECTURE.md#nuget-authentication) for why.

### Scripts

`compute-prerelease-version.sh`, `changelog-and-tag.sh`, `pack.sh`

---

## _release.yaml

Computes a stable release version, updates the changelog, tags, and builds/packs each project for publishing.

### Inputs

| Input                  | Type     | Required | Default | Description                                         |
| :--------------------- | :------- | :------- | :------ | :-------------------------------------------------- |
| `package-projects`     | `string` | no       | `[]`    | JSON array of project paths to package and publish. |
| `preprocessor-symbols` | `string` | **yes**  | —       | Preprocessor symbols.                               |
| `minver-tag-prefix`    | `string` | **yes**  | —       | MinVer tag prefix.                                  |
| `reason`               | `string` | **yes**  | —       | Reason for the release.                             |

### Secrets

| Secret        | Required | Description                                   |
| :------------ | :------- | :-------------------------------------------- |
| `RELEASE_PAT` | **yes**  | PAT with `contents:write` for pushing to main |

### ⚠️ `RELEASE_PAT` — Special Setup Required

Same setup as for [`_prerelease.yaml`](#️-release_pat--special-setup-required). `RELEASE_PAT` is
required for both prerelease and stable release workflows.

### Permissions

    contents: write
    packages: read
    actions: read

### Concurrency

    group: release-${{ github.ref }}
    cancel-in-progress: false

### Jobs

| Job                 | Needs                                  | Description                                                                 |
| :------------------ | :------------------------------------- | :-------------------------------------------------------------------------- |
| `compute-version`   | —                                      | Determines the stable version from conventional commits                     |
| `changelog-and-tag` | `compute-version`                      | Finalizes CHANGELOG.md and creates the Git tag                              |
| `package`           | `compute-version`, `changelog-and-tag` | Checks out the tag and builds+packs each project (does **not** push)        |
| `collect-artifacts` | `package`                              | Collects the uploaded package artifacts' IDs into the `artifact-ids` output |

The actual `dotnet nuget push` happens in the *consumer's* own `Release.yaml` (its
`publish-release` job), which downloads the artifacts by the IDs above — see
[Architecture](ARCHITECTURE.md#nuget-authentication) for why.

### Scripts

`compute-release-version.sh`, `changelog-and-tag.sh`, `pack.sh`

---

## _clear_cache.yaml

Emergency cache cleanup with allowlisted prefixes.

### Inputs

| Input           | Type     | Required | Default                   | Description                                                                          |
| :-------------- | :------- | :------- | :------------------------ | :----------------------------------------------------------------------------------- |
| `reason`        | `string` | no       | `Emergency cache cleanup` | Reason for clearing cache.                                                           |
| `cache-pattern` | `string` | no       | `nuget-`                  | Cache key prefix to delete. Allowlist: `nuget-`, `built-artifacts-`, `bencher-cli-`. |

### Permissions

    actions: write
    contents: read

---

## _rebuild_bench_history.yaml

Re-records a repo's benchmark history to Bencher.dev to rebuild a baseline (e.g. after a runner-image change or a benchmark
restructure). Discovers every benchmark project under `benchmarks/` and records each `repeat` times. **Record-only**: no
thresholds, no `--err` — a noisy point never fails the run.

### Inputs

| Input                  | Type     | Required | Default         | Description                                         |
| :--------------------- | :------- | :------- | :-------------- | :-------------------------------------------------- |
| `repeat`               | `number` | no       | `10`            | Independent runs to record per benchmark.           |
| `runner-os`            | `string` | no       | `ubuntu-latest` | Runner OS.                                          |
| `target-framework`     | `string` | no       | `10.0.x`        | Version of .NET SDK to use.                         |
| `configuration`        | `string` | no       | `Release`       | Build configuration.                                |
| `preprocessor-symbols` | `string` | no       | `""`            | Preprocessor symbols (empty = full, non-SHORT_RUN). |
| `minver-tag-prefix`    | `string` | no       | `v`             | MinVer tag prefix.                                  |
| `minver-prerelease-id` | `string` | no       | `preview.0`     | MinVer pre-release identifiers.                     |
| `bencher-branch`       | `string` | no       | `main`          | Bencher branch whose history is being rebuilt.      |

### Secrets

| Secret              | Required | Description           |
| :------------------ | :------- | :-------------------- |
| `BENCHER_API_TOKEN` | **yes**  | Bencher.dev API token |

### Script

`rebuild-bench-history-run.sh`

---

## RebuildBenchHistory-AllRepos.yaml (fan-out, in vm2.DevOps)

Manually dispatched (UI/phone) fan-out. Triggers each vm2 package repo's own `RebuildBenchHistory.yaml` (which calls
`_rebuild_bench_history.yaml`). Selects targets by probing for a `benchmarks/` directory via `gh api`. **Fire-and-forget** —
it dispatches the per-repo runs and returns; the rebuilds proceed in each repo's own Actions.

### Inputs

| Input    | Type     | Required | Default | Description                               |
| :------- | :------- | :------- | :------ | :---------------------------------------- |
| `repeat` | `number` | no       | `10`    | Independent runs to record per benchmark. |

### Secrets

| Secret               | Required | Description                                                                                                                                |
| :------------------- | :------- | :----------------------------------------------------------------------------------------------------------------------------------------- |
| `BENCH_DISPATCH_PAT` | **yes**  | Fine-grained PAT (`Actions: write` + `Contents: read`) — set on vm2.DevOps only. See [CONFIGURATION.md](CONFIGURATION.md#actions-secrets). |

### Permissions

    contents: read

### Script

`rebuild-bench-history.sh`
