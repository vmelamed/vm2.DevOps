# Architecture

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Architecture](#architecture)
  - [Layers](#layers)
    - [Layer 1: Consumer Workflows](#layer-1-consumer-workflows)
      - [Push De-dupe Logic](#push-de-dupe-logic)
      - [Gathering Inputs](#gathering-inputs)
    - [Layer 2: Reusable Workflows](#layer-2-reusable-workflows)
      - [CI Pipeline (`_ci.yaml`)](#ci-pipeline-_ciyaml)
      - [Build (`_build.yaml`)](#build-_buildyaml)
      - [Gate Job Pattern (`postrun-ci`)](#gate-job-pattern-postrun-ci)
      - [Test (`_test.yaml`)](#test-_testyaml)
      - [Benchmarks (`_benchmarks.yaml`)](#benchmarks-_benchmarksyaml)
      - [Pack (`_pack.yaml`)](#pack-_packyaml)
      - [Prerelease (`_prerelease.yaml`)](#prerelease-_prereleaseyaml)
      - [Release (`_release.yaml`)](#release-_releaseyaml)
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
  - [Actions Secrets](#actions-secrets)
  - [Dependabot Secrets](#dependabot-secrets)
  - [Naming Conventions](#naming-conventions)
    - [`args_to_github_output` — Automatic Name Translation](#args_to_github_output--automatic-name-translation)

<!-- /TOC -->

vm2.DevOps provides CI/CD automation framework for .NET NuGet packages through a four-layer architecture.

## Layers

```text
┌─────────────────────────────────────────────────────────┐
│  Consumer Workflows  (vm2.Templates content)            │
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

```text
Top-level Workflows      Reusable Workflows                  Bash Scripts                     Bash Library
vm2.*                    vm2.DevOps/.github/workflows        vm2.DevOps/.github/scripts/      vm2.DevOps/scripts/bash/lib/

═══════════════════════► ══════════════════════════════════► ═══════════════════════════════► ════════════════════════════

CI.yaml ───────┬───────► actions/gather-inputs/action.yaml
               └───────► _ci.yaml ─┬───────────────────────► validate-commits.sh ───────────►
                                   ├───────────────────────► validate-inputs.sh ────────────►
                                   ├──► _build.yaml ───────► build.sh ──────────────────────►
                                   ├──► _test.yaml ────────► run-tests.sh ──────────────────►
                                   ├──► _benchmarks.yaml ──► run-benchmarks.sh ─────────────►
                                   └──► _pack.yaml ────────► pack.s ────────────────────────►

Prerelease.yaml ───────► _prerelease.yaml ───────────────┬─► compute-prerelease-version.sh ─►
                                                         ├─► changelog-and-tag.sh ──────────►
                                                         └─► publish-package.s ─────────────►

Release.yaml ──────────► _release.yaml ──────────────────┬─► compute-release-version.sh ────►
                                                         ├─► changelog-and-tag.sh ──────────►
                                                         └─► publish-package.sh ────────────►

```

### Layer 1: Consumer Workflows

The GitHub Actions workflows at this level originate at **`vm2.Templates/templates/AddNewPackage/content/.github/workflows/`**. They are practically copied to every new vm2 repo's `.github/workflows` when it is created with `dotnet install new vm2pkg`. These are the thin, per-repo entry points. Changes at this layer (although quite stable these days) must be kept in sync with the template's original. This is achieved by executing the standalone script `diff-shared.sh`. The script compares and then copies or merges the source-of-truth template files into the files with shared content, like the workloads at this level. Each consumer workflow sets repo-specific parameters (project paths, coverage thresholds, etc.) and delegates to a reusable workflow via GitHub Actions property `uses: vmelamed/vm2.DevOps/.github/workflows/_*.yaml@main`. For example, `CI.yaml` calls
`_ci.yaml`, `Prerelease.yaml` calls `_prerelease.yaml`, and so on, see the diagram above.

#### Push De-dupe Logic

When a branch has an open pull request, both `push` and `pull_request` events fire on every commit. To avoid duplicate CI runs,
each consumer `CI.yaml` includes de-dupe logic in the `prerun-ci` job:

1. For pushes to non-main branches, the workflow queries `gh pr list` for open PRs matching the
   branch.
1. If an open PR exists, the push-triggered run sets `skip-push=true` and the `run-ci` job is
   skipped (the PR-triggered run handles CI).
1. If no open PR exists, the push-triggered run proceeds and adds the `SHORT_RUN` preprocessor
   symbol for faster (albeit less comprehensive) benchmarks.

This ensures each commit runs CI exactly once regardless of event type.

#### Gathering Inputs

The workflows at this level have a number of inputs: GitHub Actions `vars`, `secrets`, and `env`-s, manually triggered actions bring inputs from the UI, etc. To handle and prioritize the inputs a composite action `gather-inputs` (`vm2.DevOps/.github/actions/gather-inputs/action.yaml`) at this level gathers the relevant inputs and exports them as parameters (`uses: ... with:...`) for the reusable workflows and scripts to consume. The input-gathering action also performs normalization and validation of inputs, ensuring consistent formats (e.g., JSON arrays for project paths) and enforcing required parameters. When extending the composite action, remember that `vars` and `env` are not automatically passed through to reusable workflows, so they must be explicitly included in the action's `outputs` and then passed as `with` parameters to the reusable workflows. See `gather-inputs/action.yaml` for the full implementation.

### Layer 2: Reusable Workflows

Located in **`vm2.DevOps/.github/workflows/`**. All are `workflow_call` triggered.

#### CI Pipeline (`_ci.yaml`)

Orchestrates the full CI process. Accepts JSON arrays of project paths and fans out via matrix strategy.

```text
_ci.yaml ─┬───────────────────────► validate-commits.sh ──►
          ├───────────────────────► validate-inputs.sh ───►
          ├──► _build.yaml ───────► build.sh ─────────────►
          ├──► _test.yaml ────────► run-tests.sh ─────────►
          ├──► _benchmarks.yaml ──► run-benchmarks.sh ────►
          └──► _pack.yaml ────────► pack.s ───────────────►
```

- **validate-commits** — Validates commit messages against Conventional Commits spec via `validate-commits.sh`. This is a CI
  gate to enforce commit message quality and ensure reliable version calculation from commits
- **validate-input** — Normalizes and validates all inputs through `validate-input.sh`
- **build** — Compiles via `_build.yaml`. Matrices over `runners-os × build-projects`. Skipped when `build-projects` is empty.
- **test** — Runs via `_test.yaml`. Matrices over `runners-os`. Skipped when `test-projects` is empty
- **benchmarks** — Runs via `_benchmarks.yaml`. Matrices over `runners-os × benchmark-projects`. Skipped when `benchmark-projects` is empty or the push commits contain `[skip bm]`
- **pack** — Validates NuGet packaging via `_pack.yaml`. Matrices over `runners-os × package-projects`. Skipped when `package-projects`

Concurrency group `ci-${{ github.workflow_ref }}` cancels in-progress runs on new pushes.

#### Build (`_build.yaml`)

1. Checks out repository with full history (`fetch-depth: 0`) for MinVer version calculation.
1. Restores NuGet packages (dual-layer cache — see [Caching Strategy](#2-caching-strategy)).
1. Calls `build.sh` to compile the project.
1. Saves build artifacts to cache with key `build-artifacts-{os}-{sha}-{configuration}-{run_id}`.

#### Gate Job Pattern (`postrun-ci`)

With reusable workflows and matrix strategies, GitHub Actions produces check names that include the workflow prefix, matrix parameters, inner job names, and event suffixes — making them impossible to predict for branch-protection required checks. For example, a single test matrix job might appear as `Run CI: Build, Test, Benchmark, Pack / Run tests (ubuntu-latest) (pull_request)`.

To solve this, each consumer `CI.yaml` includes a final lightweight **gate job** that depends (wiats for) on all other jobs and reports a single, stable check name:

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

#### Test (`_test.yaml`)

1. Restores build artifacts from the build cache.
1. Iterates test projects (parsed from the JSON array via `jq`).
1. Calls `run-tests.sh` for each project.
1. Generates coverage reports with ReportGenerator.
1. Uploads coverage to Codecov.
1. Posts a PR comment with test results and coverage details.
1. Publishes GitHub Check annotations via `dorny/test-reporter`.

#### Benchmarks (`_benchmarks.yaml`)

1. Restores build artifacts from the build cache.
1. Caches the Bencher CLI binary.
1. Calls `run-benchmarks.sh` (BenchmarkDotNet).
1. Tracks results via `bencher run` using a percentage threshold test (`max-regression-pct`, default 20%).
1. Posts a PR comment with benchmark results.

#### Pack (`_pack.yaml`)

1. Restores build artifacts from the build cache.
1. Calls `pack.sh` to validate NuGet packaging succeeds.

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

> [!IMPORTANT] Manual dispatch.

Three sequential jobs:

1. **compute-version** — Calls `compute-release-version.sh` to determine the stable version from conventional commits.
1. **changelog-and-tag** — Calls `changelog-and-tag.sh` to update the changelog using `cliff.release-header.toml` and create the
   release Git tag.
1. **release** — Checks out the release tag, then calls `publish-package.sh` to build, pack, and push. (see [Release Process](RELEASE_PROCESS.md#release-process))

##### Example Walkthrough

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

##### Prerelease Guard

If the latest prerelease tag is `v1.5.0-preview.3` but the commit-based calculation yields
`v1.3.0`, the script adopts `1.5.0` from the prerelease instead. This prevents publishing a
stable version with a lower number than an already-published prerelease.

#### Clear Cache (`_clear_cache.yaml`)

Emergency cleanup. Deletes caches matching an allowlisted prefix (`nuget-`, `build-artifacts-`, or `bencher-cli-`).

### Layer 3: Bash Scripts

#### CI Scripts (`/.github/actions/scripts/`)

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
| `_error_codes.sh`  | Standardized error codes for CI scripts                                  |
| `_git_vm2.sh`      | Git repository helpers specific to vm2 repos                             |
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
| `diff-shared.sh`            | Diff common files across vm2 repos         |
| `local-git-config.sh`       | Bootstrap local Git config for vm2 work    |
| `move-commits-to-branch.sh` | Move commits from one branch to another    |
| `repo-setup.sh`             | Bootstrap and configure a new GitHub repo  |
| `add-spdx.sh`               | Add SPDX license headers to source files   |
| `retag.sh`                  | Recreate a Git tag at a different commit   |
| `restore-force-eval.sh`     | Force re-evaluation of NuGet restore       |

These also follow the three-file pattern where applicable.

## Caching Strategy

The build pipeline uses a dual-layer NuGet cache and a build artifact cache.

### NuGet Package Cache (dual-layer)

1. **`setup-dotnet` built-in cache** — Keyed on `packages.lock.json` and `*.csproj` hashes.
1. **Explicit `actions/cache`** — Weekly rotation via a `YYYY-WVV` calendar-week key, with
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
1. A second checkout sparse-clones `vm2.DevOps` — fetching only `scripts/bash/lib/` and `.github/actions/scripts/`.
1. The composite `action.yaml` adds these directories to `$PATH` and sets `$DEVOPS_LIB_DIR`.
1. For workflows running inside vm2.DevOps itself, the local checkout is used instead
   (`if: github.repository == 'vmelamed/vm2.DevOps'`).

## NuGet Authentication

All workflows that restore NuGet packages authenticate with GitHub Packages:

```bash
dotnet nuget update source github.vm2 \
    --username ${{ github.actor }} \
    --password ${{ github.token }} \
    --store-password-in-clear-text
```

The `github.vm2` source is configured in each repo's `NuGet.config`.

## Actions Secrets

| Secret                       | Used by                       | Purpose                                                       |
| :--------------------------- | :---------------------------- | :------------------------------------------------------------ |
| `NUGET_API_KEY`              | `_prerelease`, `_release`     | The NuGet API key for the selected NuGet server               |
| `CODECOV_TOKEN`              | `_ci` → `_test`               | Codecov upload token                                          |
| `BENCHER_API_TOKEN`          | `_ci` → `_benchmarks`         | Bencher.dev tracking token                                    |
| `REPORTGENERATOR_LICENSE`    | `_ci` → `_test`               | ReportGenerator license key                                   |
| `RELEASE_PAT`                | `_prerelease`, `_release`     | Fine-grained PAT (`contents: write`) for pushing to `main` past branch protection |

## Dependabot Secrets

| Secret                       | Used by                       | Purpose                                                       |
| :--------------------------- | :---------------------------- | :------------------------------------------------------------ |
| `GH_PACKAGES_TOKEN`          | `Dependabot`                  | The GitHub Packages token used by Dependabot to authenticate with GitHub Packages |

## Naming Conventions

Consistent naming transforms flow across the layers:

| Layer                      | Convention                | Example                 |
| :------------------------- | :------------------------ | :---------------------- |
| GitHub repo vars           | `UPPER_SNAKE_CASE`        | `MAX_REGRESSION_PCT`    |
| Workflow inputs            | `lower-kebab-case`        | `max-regression-pct`    |
| Script parameters          | `--lower-kebab-case`      | `--max-regression-pct`  |
| Script variables           | `lower_snake_case`        | `max_regression_pct`    |

### `args_to_github_output` — Automatic Name Translation

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
