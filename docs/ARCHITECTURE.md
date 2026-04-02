# Architecture

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Architecture](#architecture)
  - [1. Layers](#1-layers)
    - [1.1. Layer 1: Consumer Workflows](#11-layer-1-consumer-workflows)
      - [1.1.1. Push De-dupe Logic](#111-push-de-dupe-logic)
    - [1.2. Layer 2: Reusable Workflows](#12-layer-2-reusable-workflows)
      - [1.2.1. CI Pipeline (`_ci.yaml`)](#121-ci-pipeline-_ciyaml)
      - [1.2.2. Build (`_build.yaml`)](#122-build-_buildyaml)
      - [1.2.3. Gate Job Pattern (`postrun-ci`)](#123-gate-job-pattern-postrun-ci)
      - [1.2.4. Test (`_test.yaml`)](#124-test-_testyaml)
      - [1.2.5. Benchmarks (`_benchmarks.yaml`)](#125-benchmarks-_benchmarksyaml)
      - [1.2.6. Pack (`_pack.yaml`)](#126-pack-_packyaml)
      - [1.2.7. Prerelease (`_prerelease.yaml`)](#127-prerelease-_prereleaseyaml)
      - [1.2.8. Release (`_release.yaml`)](#128-release-_releaseyaml)
        - [1.2.8.1. Example Walkthrough](#1281-example-walkthrough)
        - [1.2.8.2. Prerelease Guard](#1282-prerelease-guard)
      - [1.2.9. Clear Cache (`_clear_cache.yaml`)](#129-clear-cache-_clear_cacheyaml)
    - [1.3. Layer 3: Bash Scripts](#13-layer-3-bash-scripts)
      - [1.3.1. CI Scripts (`/.github/actions/scripts/`)](#131-ci-scripts-githubactionsscripts)
      - [1.3.2. Composite Action (`action.yaml`)](#132-composite-action-actionyaml)
      - [1.3.3. Bash Library (`/scripts/bash/lib/`)](#133-bash-library-scriptsbashlib)
      - [1.3.4. Utility Scripts (`/scripts/bash/`)](#134-utility-scripts-scriptsbash)
  - [2. Caching Strategy](#2-caching-strategy)
    - [2.1. NuGet Package Cache (dual-layer)](#21-nuget-package-cache-dual-layer)
    - [2.2. Build Artifact Cache](#22-build-artifact-cache)
    - [2.3. Cache Cleanup](#23-cache-cleanup)
  - [3. Script Distribution](#3-script-distribution)
  - [4. NuGet Authentication](#4-nuget-authentication)
  - [5. Actions Secrets](#5-actions-secrets)
  - [6. Dependabot Secrets](#6-dependabot-secrets)
  - [7. Naming Conventions](#7-naming-conventions)
    - [7.1. `args_to_github_output` — Automatic Name Translation](#71-args_to_github_output--automatic-name-translation)

<!-- /TOC -->

fourvm2.DevOps provides CI/CD automation for .NET NuGet packages through a four-layer architecture.

## 1. Layers

```text
┌─────────────────────────────────────────────────────────┐
│  Consumer Workflows  (vmelamed/.github templates)       │
│  CI.yaml · Prerelease.yaml · Release.yaml · …           │
├─────────────────────────────────────────────────────────┤
│  Reusable Workflows  (vm2.DevOps/.github/workflows/)    │
│  _ci · _build · _test · _benchmarks · _pack             │
│  _prerelease · _release · _clear_cache                  │
├─────────────────────────────────────────────────────────┤
│  Bash Scripts  (vm2.DevOps/.github/actions/scripts/)    │
│  build · run-tests · run-benchmarks · pack              │
│  validate-input · publish-package · changelog-and-tag   │
│  compute-release-version · download-artifact            │
├─────────────────────────────────────────────────────────┤
│  Bash Library  (vm2.DevOps/scripts/bash/lib/)           │
│  core.sh · gh_core.sh · 9 component modules             │
└─────────────────────────────────────────────────────────┘
```

### 1.1. Layer 1: Consumer Workflows

Stored in **`vmelamed/.github/workflow-templates/`**, these are the thin, per-repo entry points.
Each consumer workflow sets repo-specific parameters (project paths, coverage thresholds, etc.)
and delegates to a reusable workflow via GitHub Actions property
`uses: vmelamed/vm2.DevOps/.github/workflows/_*.yaml@main`.

| Template             | Triggers                                         | Calls          |
| :------------------- | :----------------------------------------------- | :------------- |
| `CI.yaml`            | `push` to main, `pull_request` targeting main    | `_ci.yaml`     |
| `Prerelease.yaml`    | workflow_run (after CI succeeds on main)         | `_prerelease`  |
| `Release.yaml`       | Manual `workflow_dispatch`                       | `_release`     |
| `ClearCache.yaml`    | Manual `workflow_dispatch`                       | `_clear_cache` |
| `AutoMerge.yaml`     | `pull_request` targeting main label "auto-merge" | N/A            |

#### 1.1.1. Push De-dupe Logic

When a branch has an open pull request, both `push` and `pull_request` events fire on every commit. To avoid duplicate CI runs,
each consumer `CI.yaml` includes de-dupe logic in the `prerun-ci` job:

1. For pushes to non-main branches, the workflow queries `gh pr list` for open PRs matching the
   branch.
1. If an open PR exists, the push-triggered run sets `skip-push=true` and the `run-ci` job is
   skipped (the PR-triggered run handles CI).
1. If no open PR exists, the push-triggered run proceeds and adds the `SHORT_RUN` preprocessor
   symbol for faster (albeit less comprehensive) benchmarks.

This ensures each commit runs CI exactly once regardless of event type.

### 1.2. Layer 2: Reusable Workflows

Located in **`vm2.DevOps/.github/workflows/`**. All are `workflow_call` triggered.

#### 1.2.1. CI Pipeline (`_ci.yaml`)

Orchestrates the full CI process. Accepts JSON arrays of project paths and fans out via matrix strategy.

```text
validate-input ──► build ──┬──► test
                           ├──► benchmarks
                           └──► pack
```

- **validate-input** — Normalizes and validates all inputs through `validate-input.sh`. Uses a `["__skip__"]` sentinel for
  optional stages (test, benchmarks, pack).  This is a workaround for GitHub Actions not supporting conditional `uses:` in
  matrix jobs — the matrix must always have at least one item, and `fromJSON('[]')` would fail. The sentinel ensures a valid
  non-empty array, and each downstream job checks `if: fromJSON(needs.validate-input.outputs.test-projects-len) > 0` to skip
  execution when no real projects are present.
- **build** — Compiles via `_build.yaml`. Matrices over `runners-os × build-projects`.
- **test** — Runs via `_test.yaml`. Matrices over `runners-os`. Skipped when `test-projects` is the sentinel.
- **benchmarks** — Runs via `_benchmarks.yaml`. Matrices over `runners-os × benchmark-projects`. Also skipped on push commits
  containing `[skip bm]`.
- **pack** — Validates NuGet packaging via `_pack.yaml`. Matrices over `runners-os × package-projects`.

Concurrency group `ci-${{ github.workflow_ref }}` cancels in-progress runs on new pushes.

#### 1.2.2. Build (`_build.yaml`)

1. Checks out repository with full history (`fetch-depth: 0`) for MinVer version calculation.
1. Restores NuGet packages (dual-layer cache — see [Caching Strategy](#caching-strategy)).
1. Calls `build.sh` to compile the project.
1. Saves build artifacts to cache with key `build-artifacts-{os}-{sha}-{configuration}-{run_id}`.

#### 1.2.3. Gate Job Pattern (`postrun-ci`)

With reusable workflows and matrix strategies, GitHub Actions produces check names that include the
workflow prefix, matrix parameters, inner job names, and event suffixes — making them impossible to
predict for branch-protection required checks. For example, a single test matrix job might appear as
`Run CI: Build, Test, Benchmark, Pack / Run tests (ubuntu-latest) (pull_request)`.

To solve this, each consumer `CI.yaml` includes a lightweight **gate job** that depends on all other
jobs and reports a single, stable check name:

```text
prerun-ci ──► run-ci (calls _ci.yaml) ──► postrun-ci
```

```yaml
postrun-ci:
  name: Postrun-CI        # ← this is the only required check in the branch ruleset
  needs: [prerun-ci, run-ci]
  if: always()            # ← must run even if dependencies fail or are cancelled
  runs-on: ubuntu-latest
  steps:
    - name: Evaluate CI result
      run: |
        if [[ "${{ needs.prerun-ci.result }}" == "failure" || ... ]]; then exit 1; fi
        if [[ "${{ needs.run-ci.result }}" == "failure" || ... ]]; then exit 1; fi
        echo "✅ CI completed"
```

**Key design points**:

- `if: always()` is mandatory — without it, if a dependency fails, the gate job is silently skipped and the branch-protection
  check stays in "Waiting" state forever.
- `needs` covers all upstream jobs so any failure is caught
- Branch rulesets match against the bare check-run name (Postrun-CI), not the UI-decorated form
  (CI: Build, Test, Benchmark, Pack / Postrun-CI (pull_request))
- The gate job name is extracted by `repo-setup.sh` → `detect_required_checks()` which parses the consumer's CI.yaml for the
  gate job's name: property and registers it in the branch ruleset

#### 1.2.4. Test (`_test.yaml`)

1. Restores build artifacts from the build cache.
1. Iterates test projects (parsed from the JSON array via `jq`).
1. Calls `run-tests.sh` for each project.
1. Generates coverage reports with ReportGenerator.
1. Uploads coverage to Codecov.
1. Posts a PR comment with test results and coverage details.
1. Publishes GitHub Check annotations via `dorny/test-reporter`.

#### 1.2.5. Benchmarks (`_benchmarks.yaml`)

1. Restores build artifacts from the build cache.
1. Caches the Bencher CLI binary.
1. Calls `run-benchmarks.sh` (BenchmarkDotNet).
1. Tracks results via `bencher run` using a percentage threshold test (`max-regression-pct`, default 20%).
1. Posts a PR comment with benchmark results.

#### 1.2.6. Pack (`_pack.yaml`)

1. Restores build artifacts from the build cache.
1. Calls `pack.sh` to validate NuGet packaging succeeds.

#### 1.2.7. Prerelease (`_prerelease.yaml`)

Triggered automatically when CI succeeds after a PR merge to main (a workflow_run on the CI workflow, gated to push events on
main with conclusion == 'success'). Can also be triggered manually via workflow_dispatch. Three sequential jobs:

1. **compute-version** — Calls `compute-prerelease-version.sh` to determine the next prerelease version from conventional
   commits.
1. **changelog-and-tag** — Calls `changelog-and-tag.sh` to update `CHANGELOG.md` using `cliff.prerelease.toml`, commit, and
   create the prerelease tag.
1. **package-and-publish** — Checks out the prerelease tag, then calls `publish-package.sh` to build, pack, and push the
   prerelease package to the configured NuGet server.

#### 1.2.8. Release (`_release.yaml`)

> [!IMPORTANT] Manual dispatch.

Three sequential jobs:

1. **compute-version** — Calls `compute-release-version.sh` to determine the stable version from conventional commits.
1. **changelog-and-tag** — Calls `changelog-and-tag.sh` to update the changelog using `cliff.release-header.toml` and create the
   release Git tag.
1. **release** — Checks out the release tag, then calls `publish-package.sh` to build, pack, and push. (see [Release Process](RELEASE_PROCESS.md#release-process))

##### 1.2.8.1. Example Walkthrough

Given latest stable tag `v1.2.3` and these commits since then:

  > - fix: correct boundary check
  > - feat(parser): add alternation support
  > - docs: update README

- No `!:` → not major
- `feat(parser):` matches → **minor bump**
- Result: `v1.3.0`

If there were also a `refactor(core)!: rewrite engine`:

- `!:` detected → **major bump**
- Result: `v2.0.0`

##### 1.2.8.2. Prerelease Guard

If the latest prerelease tag is `v1.5.0-preview.3` but the commit-based calculation yields
`v1.3.0`, the script adopts `1.5.0` from the prerelease instead. This prevents publishing a
stable version with a lower number than an already-published prerelease.

#### 1.2.9. Clear Cache (`_clear_cache.yaml`)

Emergency cleanup. Deletes caches matching an allowlisted prefix (`nuget-`, `build-artifacts-`, or `bencher-cli-`).

### 1.3. Layer 3: Bash Scripts

#### 1.3.1. CI Scripts (`/.github/actions/scripts/`)

Each CI script follows a **three-file pattern** for consistency and separation of concerns the files may be even more
than three if the script has more complex logical separation needs:

| File                | Purpose                          |
| :------------------ | :------------------------------- |
| `script.sh`         | Entry point — sources lib, runs  |
| `script.usage.sh`   | `--help` text                    |
| `script.args.sh`    | Argument parsing and validation  |

The CI scripts:

| Script                          | Called by                     | Purpose                                       |
| :------------------------------ | :---------------------------- | :-------------------------------------------- |
| `validate-commits.sh`           | `_ci`                         | Validate commit messages Conventional Commits |
| `validate-input.sh`             | `_ci`                         | Validate and normalize workflow inputs        |
| `build.sh`                      | `_build`                      | Compile .NET projects                         |
| `run-tests.sh`                  | `_test`                       | Run tests and collect coverage                |
| `run-benchmarks.sh`             | `_benchmarks`                 | Run BenchmarkDotNet benchmarks                |
| `pack.sh`                       | `_pack`                       | Validate NuGet packaging                      |
| `publish-package.sh`            | `_prerelease`, `_release`     | Build, pack, and push NuGet packages          |
| `compute-prerelease-version.sh` | `_prerelease`                 | Determine prerelease version from commits     |
| `compute-release-version.sh`    | `_release`                    | Determine stable release version from commits |
| `changelog-and-tag.sh`          | `_prerelease`, `_release`     | Update changelog and create Git tag           |
| `download-artifact.sh`          | (not used in CI)              | Download and extract remote artifacts         |

#### 1.3.2. Composite Action (`action.yaml`)

The file `.github/actions/scripts/action.yaml` is a composite action that adds both the scripts
directory and the bash library directory to `$PATH`, and exports `$DEVOPS_SCRIPTS_DIR` and
`$DEVOPS_LIB_DIR` for reference.

Every workflow checks out the vm2.DevOps repo (sparse-checkout of `scripts/bash/lib` and
`.github/actions/scripts`) and then invokes this action, making all scripts and library functions
available for the rest of the job.

#### 1.3.3. Bash Library (`/scripts/bash/lib/`)

A shared function library sourced by scripts at startup.

| Module             | Role                                                                     |
| :----------------- | :----------------------------------------------------------------------- |
| `core.sh`          | General-purpose functions (logging, paths, variables)                    |
| `gh_core.sh`       | GitHub Actions helpers — sources `core.sh`, `_sanitize.sh`, `_dotnet.sh` |
| `_args.sh`         | Argument parsing utilities                                               |
| `_constants.sh`    | Shared constants                                                         |
| `_diagnostics.sh`  | Debug and diagnostic output                                              |
| `_dotnet.sh`       | .NET SDK helpers                                                         |
| `_dump_vars.sh`    | Variable dump for debugging                                              |
| `_error_codes.sh`  | Standardized error codes for CI scripts                                  |
| `_git_vm2.sh`      | Git repository helpers specific to vm2 repos                             |
| `_git.sh`          | Git repository helpers                                                   |
| `_predicates.sh`   | Boolean test functions                                                   |
| `_sanitize.sh`     | Input sanitization                                                       |
| `_semver.sh`       | Semantic versioning utilities                                            |
| `_user.sh`         | User/identity helpers                                                    |

Scripts source the GitHub Actions helpers `gh_core.sh` (which chains into `core.sh`) and then source additional `_*.sh` modules
as needed.

#### 1.3.4. Utility Scripts (`/scripts/bash/`)

Development-time scripts not used in CI:

| Script                      | Purpose                                    |
| :-------------------------- | :----------------------------------------- |
| `diff-shared.sh`            | Diff common files across vm2 repos         |
| `local-git-config.sh`       | Bootstrap local Git config for vm2 work    |
| `move-commits-to-branch.sh` | Move commits from one branch to another    |
| `repo-setup.sh`             | Bootstrap and configure a new GitHub repo  |
| `add-spdx.sh`               | Add SPDX license headers to source files   |
| `retag.sh`                  | Recreate a Git tag at a different commit   |
| `restore-force-eval.sh`     | Force re-evaluation of NuGet restore       |

These also follow the three-file pattern where applicable.

## 2. Caching Strategy

The build pipeline uses a dual-layer NuGet cache and a build artifact cache.

### 2.1. NuGet Package Cache (dual-layer)

1. **`setup-dotnet` built-in cache** — Keyed on `packages.lock.json` and `*.csproj` hashes.
1. **Explicit `actions/cache`** — Weekly rotation via a `YYYY-WVV` calendar-week key, with
   progressive fallback:

    ```text
    nuget-{os}-{week}-{lockfile-hash}    (exact)
    nuget-{os}-{week}-                   (same week, different deps)
    nuget-{os}-                          (any week)
    ```

### 2.2. Build Artifact Cache

The build job saves compiled outputs (`**/bin/{config}` and `**/obj`) under key
`build-artifacts-{os}-{sha}-{configuration}-{run_id}`. Downstream jobs (test, benchmarks, pack) restore from this cache to avoid
rebuilding.

### 2.3. Cache Cleanup

The `_clear_cache.yaml` workflow provides emergency cleanup. It restricts deletions to three allowlisted prefixes: `nuget-`,
`build-artifacts-`, and `bencher-cli-`.

## 3. Script Distribution

When a consumer repo (e.g., vm2.Glob) runs a workflow:

1. The workflow checks out the consumer repo.
1. A second checkout sparse-clones `vm2.DevOps` — fetching only `scripts/bash/lib/` and `.github/actions/scripts/`.
1. The composite `action.yaml` adds these directories to `$PATH` and sets `$DEVOPS_LIB_DIR`.
1. For workflows running inside vm2.DevOps itself, the local checkout is used instead
   (`if: github.repository == 'vmelamed/vm2.DevOps'`).

## 4. NuGet Authentication

All workflows that restore NuGet packages authenticate with GitHub Packages:

```bash
dotnet nuget update source github.vm2 \
    --username ${{ github.actor }} \
    --password ${{ github.token }} \
    --store-password-in-clear-text
```

The `github.vm2` source is configured in each repo's `NuGet.config`.

## 5. Actions Secrets

| Secret                       | Used by                       | Purpose                                                                           |
| :--------------------------- | :---------------------------- | :-------------------------------------------------------------------------------- |
| `NUGET_API_KEY`              | `_prerelease`, `_release`     | The NuGet API key for the selected NuGet server                                     |
| `CODECOV_TOKEN`              | `_ci` → `_test`               | Codecov upload token                                                              |
| `BENCHER_API_TOKEN`          | `_ci` → `_benchmarks`         | Bencher.dev tracking token                                                        |
| `REPORTGENERATOR_LICENSE`    | `_ci` → `_test`               | ReportGenerator license key                                                       |
| `RELEASE_PAT`                | `_prerelease`, `_release`     | Fine-grained PAT (`contents: write`) for pushing to `main` past branch protection |

## 6. Dependabot Secrets

| Secret                       | Used by                       | Purpose                                                                           |
| :--------------------------- | :---------------------------- | :-------------------------------------------------------------------------------- |
| `GH_PACKAGES_TOKEN`          | `Dependabot`                  | The GitHub Packages token used by Dependabot to authenticate with GitHub Packages |

## 7. Naming Conventions

Consistent naming transforms flow across the layers:

| Layer                      | Convention                | Example                 |
| :------------------------- | :------------------------ | :---------------------- |
| GitHub repo vars           | `UPPER_SNAKE_CASE`        | `MAX_REGRESSION_PCT`    |
| Workflow inputs            | `lower-kebab-case`        | `max-regression-pct`    |
| Script parameters          | `--lower-kebab-case`      | `--max-regression-pct`  |
| Script variables           | `lower_snake_case`        | `max_regression_pct`    |

### 7.1. `args_to_github_output` — Automatic Name Translation

The `args_to_github_output` function (defined in `gh_core.sh`) bridges the naming gap between bash scripts and GitHub Actions.
It takes a list of bash variable names in `snake_case`, converts each to `kebab-case` (replacing `_` with `-`), and writes them
to `$GITHUB_OUTPUT`.

Every consumer workflow's `gather-params` step uses this function:

```bash
source $DEVOPS_LIB_DIR/gh_core.sh

build_projects='...'
test_projects='...'
runners_os='...'

args_to_github_output \
    build_projects \
    test_projects \
    runners_os
```

This outputs:

```text
build-projects=...
test-projects=...
runners-os=...
```

These kebab-case keys are then referenced in the workflow's outputs: map and passed to reusable workflows as with: inputs. This
function is used in every consumer workflow template (CI, Prerelease, Release).
