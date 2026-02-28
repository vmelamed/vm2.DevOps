# Architecture

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Layers](#layers)
  - [Layer 1: Consumer Workflows](#layer-1-consumer-workflows)
  - [Layer 2: Reusable Workflows](#layer-2-reusable-workflows)
    - [CI Pipeline (`_ci.yaml`)](#ci-pipeline-_ciyaml)
    - [Build (`_build.yaml`)](#build-_buildyaml)
    - [Test (`_test.yaml`)](#test-_testyaml)
    - [Benchmarks (`_benchmarks.yaml`)](#benchmarks-_benchmarksyaml)
    - [Pack (`_pack.yaml`)](#pack-_packyaml)
    - [Prerelease (`_prerelease.yaml`)](#prerelease-_prereleaseyaml)
    - [Release (`_release.yaml`)](#release-_releaseyaml)
      - [Algorithm for Calculating Release Version](#algorithm-for-calculating-release-version)
      - [Example Walkthrough](#example-walkthrough)
      - [Prerelease Guard](#prerelease-guard)
    - [Clear Cache (`_clear_cache.yaml`)](#clear-cache-_clear_cacheyaml)
  - [Layer 3: Bash Scripts](#layer-3-bash-scripts)
    - [CI Scripts (`/.github/actions/scripts/`)](#ci-scripts-githubactionsscripts)
    - [Composite Action (`action.yaml`)](#composite-action-actionyaml)
    - [Bash Library (`/scripts/bash/lib/`)](#bash-library-scriptsbashlib)
    - [Utility Scripts (`/scripts/bash/`)](#utility-scripts-scriptsbash)
- [Caching Strategy](#caching-strategy)
  - [NuGet Package Cache (dual-layer)](#nuget-package-cache-dual-layer)
  - [Build Artifact Cache](#build-artifact-cache)
  - [Cache Cleanup](#cache-cleanup)
- [Script Distribution](#script-distribution)
- [NuGet Authentication](#nuget-authentication)
- [Secrets](#secrets)
- [Naming Conventions](#naming-conventions)

<!-- /TOC -->

vm2.DevOps provides CI/CD automation for .NET NuGet packages through a three-layer architecture.

## Layers

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

### Layer 1: Consumer Workflows

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

### Layer 2: Reusable Workflows

Located in **`vm2.DevOps/.github/workflows/`**. All are `workflow_call` triggered.

#### CI Pipeline (`_ci.yaml`)

Orchestrates the full CI process. Accepts JSON arrays of project paths and fans out via matrix strategy.

```text
validate-input ──► build ──┬──► test
                           ├──► benchmarks
                           └──► pack
```

- **validate-input** — Normalizes and validates all inputs through `validate-input.sh`. Uses a `["__skip__"]` sentinel for
  optional stages (test, benchmarks, pack).
- **build** — Compiles via `_build.yaml`. Matrices over `runners-os × build-projects`.
- **test** — Runs via `_test.yaml`. Matrices over `runners-os`. Skipped when `test-projects` is the sentinel.
- **benchmarks** — Runs via `_benchmarks.yaml`. Matrices over `runners-os × benchmark-projects`. Also skipped on push commits
  containing `[skip bm]`.
- **pack** — Validates NuGet packaging via `_pack.yaml`. Matrices over `runners-os × package-projects`.

Concurrency group `ci-${{ github.workflow_ref }}` cancels in-progress runs on new pushes.

#### Build (`_build.yaml`)

1. Checks out repository with full history (`fetch-depth: 0`) for MinVer version calculation.
2. Restores NuGet packages (dual-layer cache — see [Caching Strategy](#caching-strategy)).
3. Calls `build.sh` to compile the project.
4. Saves build artifacts to cache with key `build-artifacts-{os}-{sha}-{configuration}-{run_id}`.

#### Test (`_test.yaml`)

1. Restores build artifacts from the build cache.
2. Iterates test projects (parsed from the JSON array via `jq`).
3. Calls `run-tests.sh` for each project.
4. Generates coverage reports with ReportGenerator.
5. Uploads coverage to Codecov.
6. Posts a PR comment with test results and coverage details.
7. Publishes GitHub Check annotations via `dorny/test-reporter`.

#### Benchmarks (`_benchmarks.yaml`)

1. Restores build artifacts from the build cache.
2. Caches the Bencher CLI binary.
3. Calls `run-benchmarks.sh` (BenchmarkDotNet).
4. Tracks results via `bencher run` using a percentage threshold test (`max-regression-pct`, default 20%).
5. Posts a PR comment with benchmark results.

#### Pack (`_pack.yaml`)

1. Restores build artifacts from the build cache.
2. Calls `pack.sh` to validate NuGet packaging succeeds.

#### Prerelease (`_prerelease.yaml`)

Triggered automatically when CI succeeds after a PR merge to main (a workflow_run on the CI workflow, gated to push events on
main with conclusion == 'success'). Can also be triggered manually via workflow_dispatch. Three sequential jobs:

1. **compute-version** — Calls `compute-prerelease-version.sh` to determine the next prerelease version from conventional
   commits.
1. **changelog-and-tag** — Calls `changelog-and-tag.sh` to update `CHANGELOG.md` using `cliff.prerelease.toml`, commit, and
   create the prerelease tag.
1. **package-and-publish** — Checks out the prerelease tag, then calls `publish-package.sh` to build, pack, and push the
   prerelease package to the configured NuGet server.

#### Release (`_release.yaml`)

Manual dispatch. Three sequential jobs:

1. **compute-version** — Calls `compute-release-version.sh` to determine the stable version from conventional commits.
2. **changelog-and-tag** — Calls `changelog-and-tag.sh` to update the changelog using `cliff.release-header.toml` and create the
   release Git tag.
3. **release** — Checks out the release tag, then calls `publish-package.sh` to build, pack, and push.

##### Algorithm for Calculating Release Version

1. Find the latest stable tag matching `{prefix}MAJOR.MINOR.PATCH` (e.g., `v1.2.3`).
1. If `HEAD` is already tagged, the script errors out.
1. Collect all commit subjects between that tag and `HEAD`.
1. Scan the subjects for version-bump keywords:

   | Commit Pattern                                 | Bump      | Example Subject                         | Regex (case-insensitive) |
   | :--------------------------------------------- | :-------- | :---------------------------------------|--------------------------|
   | **`BREAKING CHANGE:`** anywhere in subject     | **Major** | `BREAKING CHANGE: remove legacy API`    | ^BREAKING CHANGE:        |
   | **`type(scope)!:`** (trailing `!` on any type) | **Major** | `feat(api)!: redesign endpoint contract`| ^[a-z]+(\(.+\))?!:       |
   | **`feat:`** or **`feat(scope):`**              | **Minor** | `feat(glob): add recursive matching`    | ^feat(\(.+\))?:          |

1. If the resulting version would be `0.x.x`, it is adjusted to `1.0.0` (SemVer requires major >= 1 for releases).
1. If the computed version is **lower** than the latest prerelease tag, the major/minor/patch from that prerelease tag is
   adopted instead (so a release is never older than its prereleases).
1. If the computed tag already exists, the script errors out.

##### Example Walkthrough

Given latest stable tag `v1.2.3` and these commits since then:

  > - fix: correct boundary check
  > - feat(parser): add alternation support
  > - docs: update README

- No `BREAKING CHANGE:` or `!:` → not major
- `feat(parser):` matches → **minor bump**
- Result: `v1.3.0`

If there were also a `refactor(core)!: rewrite engine`:

- `!:` detected → **major bump**
- Result: `v2.0.0`

##### Prerelease Guard

If the latest prerelease tag is `v1.5.0-preview.3` but the commit-based calculation yields
`v1.3.0`, the script adopts `1.5.0` from the prerelease instead. This prevents publishing a
stable version with a lower number than an already-published prerelease.

#### Clear Cache (`_clear_cache.yaml`)

Emergency cleanup. Deletes caches matching an allowlisted prefix (`nuget-`, `build-artifacts-`, or `bencher-cli-`).

### Layer 3: Bash Scripts

#### CI Scripts (`/.github/actions/scripts/`)

Each CI script follows a **three-file pattern**:

| File                | Purpose                          |
| :------------------ | :------------------------------- |
| `script.sh`         | Entry point — sources lib, runs  |
| `script.usage.sh`   | `--help` text                    |
| `script.utils.sh`   | Argument parsing and validation  |

The CI scripts:

| Script                          | Called by                     | Purpose                                       |
| :------------------------------ | :---------------------------- | :-------------------------------------------- |
| `validate-input.sh`             | `_ci`                         | Validate and normalize workflow inputs        |
| `build.sh`                      | `_build`                      | Compile .NET projects                         |
| `run-tests.sh`                  | `_test`                       | Run tests and collect coverage                |
| `run-benchmarks.sh`             | `_benchmarks`                 | Run BenchmarkDotNet benchmarks                |
| `pack.sh`                       | `_pack`                       | Validate NuGet packaging                      |
| `publish-package.sh`            | `_prerelease`, `_release`     | Build, pack, and push NuGet packages          |
| `compute-prerelease-version.sh` | `_prerelease`                 | Determine prerelease version from commits     |
| `compute-release-version.sh`    | `_release`                    | Determine stable release version from commits |
| `changelog-and-tag.sh`          | `_prerelease`, `_release`     | Update changelog and create Git tag           |
| `download-artifact.sh`          | (utility)                     | Download and extract remote artifacts         |

#### Composite Action (`action.yaml`)

The file `.github/actions/scripts/action.yaml` is a composite action that adds both the scripts
directory and the bash library directory to `$PATH`, and exports `$DEVOPS_SCRIPTS_DIR` and
`$DEVOPS_LIB_DIR` for reference.

Every workflow checks out the vm2.DevOps repo (sparse-checkout of `scripts/bash/lib` and
`.github/actions/scripts`) and then invokes this action, making all scripts and library functions
available for the rest of the job.

#### Bash Library (`/scripts/bash/lib/`)

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
| `_git.sh`          | Git repository helpers                                                   |
| `_predicates.sh`   | Boolean test functions                                                   |
| `_sanitize.sh`     | Input sanitization                                                       |
| `_semver.sh`       | Semantic versioning utilities                                            |
| `_user.sh`         | User/identity helpers                                                    |

Scripts source the GitHub Actions helpers `gh_core.sh` (which chains into `core.sh`) and then source additional `_*.sh` modules
as needed.

#### Utility Scripts (`/scripts/bash/`)

Development-time scripts not used in CI:

| Script                      | Purpose                                    |
| :-------------------------- | :----------------------------------------- |
| `diff-common.sh`            | Diff shared files across vm2 repos         |
| `move-commits-to-branch.sh` | Move commits from one branch to another    |
| `repo-setup.sh`  | Bootstrap and configure a new GitHub repo  |
| `add-spdx.sh`               | Add SPDX license headers to source files   |
| `retag.sh`                  | Recreate a Git tag at a different commit   |
| `restore-force-eval.sh`     | Force re-evaluation of NuGet restore       |

These also follow the three-file pattern where applicable.

## Caching Strategy

The build pipeline uses a dual-layer NuGet cache and a build artifact cache.

### NuGet Package Cache (dual-layer)

1. **`setup-dotnet` built-in cache** — Keyed on `packages.lock.json` and `*.csproj` hashes.
2. **Explicit `actions/cache`** — Weekly rotation via a `YYYY-WVV` calendar-week key, with
   progressive fallback:

    ```text
    nuget-{os}-{week}-{lockfile-hash}    (exact)
    nuget-{os}-{week}-                   (same week, different deps)
    nuget-{os}-                          (any week)
    ```

### Build Artifact Cache

The build job saves compiled outputs (`**/bin/{config}` and `**/obj`) under key
`build-artifacts-{os}-{sha}-{configuration}-{run_id}`. Downstream jobs (test, benchmarks, pack) restore from this cache to avoid
rebuilding.

### Cache Cleanup

The `_clear_cache.yaml` workflow provides emergency cleanup. It restricts deletions to three allowlisted prefixes: `nuget-`,
`build-artifacts-`, and `bencher-cli-`.

## Script Distribution

When a consumer repo (e.g., vm2.Glob) runs a workflow:

1. The workflow checks out the consumer repo.
2. A second checkout sparse-clones `vm2.DevOps` — fetching only `scripts/bash/lib/` and `.github/actions/scripts/`.
3. The composite `action.yaml` adds these directories to `$PATH` and sets `$DEVOPS_LIB_DIR`.
4. For workflows running inside vm2.DevOps itself, the local checkout is used instead
   (`if: github.repository == 'vmelamed/vm2.DevOps'`).

## NuGet Authentication

All workflows that restore NuGet packages authenticate with GitHub Packages:

```bash
dotnet nuget update source github.vm2 \
    --username ${{ github.actor }} \
    --password ${{ secrets.GITHUB_TOKEN }} \
    --store-password-in-clear-text
```

The `github.vm2` source is configured in each repo's `NuGet.config`.

## Secrets

| Secret                       | Used by                       | Purpose                                                                           |
| :--------------------------- | :---------------------------- | :-------------------------------------------------------------------------------- |
| `NUGET_API_GITHUB_KEY`       | `_prerelease`, `_release`     | GitHub Packages API key                                                           |
| `NUGET_API_NUGET_KEY`        | `_prerelease`, `_release`     | nuget.org API key                                                                 |
| `NUGET_API_KEY`              | `_prerelease`, `_release`     | Custom NuGet server API key                                                       |
| `CODECOV_TOKEN`              | `_ci` → `_test`               | Codecov upload token                                                              |
| `BENCHER_API_TOKEN`          | `_ci` → `_benchmarks`         | Bencher.dev tracking token                                                        |
| `REPORTGENERATOR_LICENSE`    | `_ci` → `_test`               | ReportGenerator license key                                                       |
| `RELEASE_PAT`                | `_prerelease`, `_release`     | Fine-grained PAT (`contents: write`) for pushing to `main` past branch protection |

## Naming Conventions

Consistent naming transforms flow across the layers:

| Layer                      | Convention                | Example                 |
| :------------------------- | :------------------------ | :---------------------- |
| GitHub repo vars           | `UPPER_SNAKE_CASE`        | `MAX_REGRESSION_PCT`    |
| Workflow inputs            | `lower-kebab-case`        | `max-regression-pct`    |
| Script parameters          | `--lower-kebab-case`      | `--max-regression-pct`  |
| Script variables           | `lower_snake_case`        | `max_regression_pct`    |
