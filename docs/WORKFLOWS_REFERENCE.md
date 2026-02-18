# Workflows Reference

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [_ci.yaml](#_ciyaml)
  - [Inputs](#inputs)
  - [Secrets](#secrets)
  - [Concurrency](#concurrency)
  - [Jobs](#jobs)
- [_build.yaml](#_buildyaml)
  - [Inputs](#inputs)
  - [Permissions](#permissions)
  - [Cache Keys](#cache-keys)
  - [Script](#script)
- [_test.yaml](#_testyaml)
  - [Inputs](#inputs)
  - [Secrets](#secrets)
  - [Permissions](#permissions)
  - [Script](#script)
- [_benchmarks.yaml](#_benchmarksyaml)
  - [Inputs](#inputs)
  - [Secrets](#secrets)
  - [Permissions](#permissions)
  - [Script](#script)
- [_pack.yaml](#_packyaml)
  - [Inputs](#inputs)
  - [Permissions](#permissions)
  - [Script](#script)
- [_prerelease.yaml](#_prereleaseyaml)
  - [Inputs](#inputs)
  - [Secrets](#secrets)
  - [Permissions](#permissions)
  - [Concurrency](#concurrency)
  - [Jobs](#jobs)
  - [Scripts](#scripts)
- [_release.yaml](#_releaseyaml)
  - [Inputs](#inputs)
  - [Secrets](#secrets)
  - [Permissions](#permissions)
  - [Concurrency](#concurrency)
  - [Jobs](#jobs)
  - [Scripts](#scripts)
- [_clear_cache.yaml](#_clear_cacheyaml)
  - [Inputs](#inputs)
  - [Permissions](#permissions)

<!-- /TOC -->

Reusable workflows in `vm2.DevOps/.github/workflows/`. All are triggered via `workflow_call`.

## _ci.yaml

Orchestrates the full CI pipeline: validate → build → test / benchmarks / pack.

### Inputs

| Input                  | Type     | Required | Default              | Description                                                           |
| :--------------------- | :------- | :------- | :------------------- | :-------------------------------------------------------------------- |
| `build-projects`       | `string` | no       | —                    | JSON array of project/solution paths to build. Auto-detects if empty. |
| `test-projects`        | `string` | no       | —                    | JSON array of test project paths. Skipped if empty.                   |
| `benchmark-projects`   | `string` | no       | —                    | JSON array of benchmark project paths. Skipped if empty.              |
| `package-projects`     | `string` | no       | —                    | JSON array of project paths to pack. Skipped if empty.                |
| `runners-os`           | `string` | no       | `["ubuntu-latest"]`  | JSON array of runner OS monikers.                                     |
| `dotnet-version`       | `string` | no       | `10.0.x`             | .NET SDK version.                                                     |
| `configuration`        | `string` | no       | `Release`            | Build configuration.                                                  |
| `preprocessor-symbols` | `string` | no       | `""`                 | Semicolon-separated preprocessor symbols.                             |
| `min-coverage-pct`     | `number` | no       | `80`                 | Minimum acceptable code coverage percentage.                          |
| `max-regression-pct`   | `number` | no       | `20`                 | Maximum acceptable performance regression percentage.                 |
| `minver-tag-prefix`    | `string` | no       | `v`                  | MinVer tag prefix for version calculation.                            |
| `minver-prerelease-id` | `string` | no       | `preview.0`          | MinVer default pre-release identifiers.                               |

### Secrets

| Secret                     | Required | Description                              |
| :------------------------- | :------- | :--------------------------------------- |
| `CODECOV_TOKEN`            | no       | Codecov API token for coverage uploads   |
| `BENCHER_API_TOKEN`        | no       | Bencher.dev API token for benchmarks     |
| `REPORTGENERATOR_LICENSE`  | no       | ReportGenerator license key              |

### Concurrency

    group: ci-${{ github.workflow_ref }}
    cancel-in-progress: true

### Jobs

| Job              | Needs            | Matrix                               | Condition                                                |
| :--------------- | :--------------- | :----------------------------------- | :------------------------------------------------------- |
| `validate-input` | —                | —                                    | Always                                                   |
| `build`          | `validate-input` | `runners-os × build-projects`        | Always                                                   |
| `test`           | `build`          | `runners-os`                         | `test-projects` is not `["__skip__"]`                    |
| `benchmarks`     | `build`          | `runners-os × benchmark-projects`    | Not `["__skip__"]`; also skipped on push with `[skip bm]`|
| `pack`           | `build`          | `runners-os × package-projects`      | `package-projects` is not `["__skip__"]`                 |

---

## _build.yaml

Compiles the project and caches build artifacts for downstream jobs.

### Inputs

| Input                  | Type     | Required | Default         | Description                                     |
| :--------------------- | :------- | :------- | :-------------- | :---------------------------------------------- |
| `build-project`        | `string` | no       | —               | Path to project to build. Auto-detects if empty.|
| `runner-os`            | `string` | no       | `ubuntu-latest` | Runner OS.                                      |
| `dotnet-version`       | `string` | no       | `10.0.x`        | .NET SDK version.                               |
| `configuration`        | `string` | no       | `Release`       | Build configuration.                            |
| `preprocessor-symbols` | `string` | no       | `""`            | Preprocessor symbols.                           |
| `minver-tag-prefix`    | `string` | no       | `v`             | MinVer tag prefix.                              |
| `minver-prerelease-id` | `string` | no       | `preview.0`     | MinVer pre-release identifiers.                 |

### Permissions

    contents: read
    packages: read

### Cache Keys

| Cache                | Key Pattern                                                          |
| :------------------- | :------------------------------------------------------------------- |
| NuGet (weekly)       | `nuget-{os}-{YYYY-WVV}-{lockfile-hash}`                              |
| Build artifacts      | `build-artifacts-{os}-{sha}-{configuration}-{run_id}`                |

### Script

`build.sh`

---

## _test.yaml

Runs tests, generates coverage reports, uploads to Codecov, and posts PR comments.

### Inputs

| Input                  | Type     | Required | Default         | Description                                        |
| :--------------------- | :------- | :------- | :-------------- | :------------------------------------------------- |
| `test-projects`        | `string` | **yes**  | —               | JSON array of test project paths.                  |
| `test-subject`         | `string` | no       | —               | Name of the project under test (inferred if empty).|
| `runner-os`            | `string` | no       | `ubuntu-latest` | Runner OS.                                         |
| `dotnet-version`       | `string` | no       | `10.0.x`        | .NET SDK version.                                  |
| `configuration`        | `string` | no       | `Release`       | Build configuration.                               |
| `preprocessor-symbols` | `string` | no       | `""`            | Preprocessor symbols.                              |
| `min-coverage-pct`     | `number` | no       | `80`            | Minimum acceptable code coverage percentage.       |
| `minver-tag-prefix`    | `string` | no       | `v`             | MinVer tag prefix.                                 |
| `minver-prerelease-id` | `string` | no       | `preview.0`     | MinVer pre-release identifiers.                    |

### Secrets

| Secret                    | Required | Description                              |
| :------------------------ | :------- | :--------------------------------------- |
| `CODECOV_TOKEN`           | **yes**  | Codecov API token for coverage uploads   |
| `REPORTGENERATOR_LICENSE` | no       | ReportGenerator license key              |

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

| Input                  | Type     | Required | Default         | Description                                       |
| :--------------------- | :------- | :------- | :-------------- | :------------------------------------------------ |
| `benchmark-project`    | `string` | **yes**  | —               | Path to the benchmark project.                    |
| `runner-os`            | `string` | no       | `ubuntu-latest` | Runner OS.                                        |
| `dotnet-version`       | `string` | no       | `10.0.x`        | .NET SDK version.                                 |
| `configuration`        | `string` | no       | `Release`       | Build configuration.                              |
| `preprocessor-symbols` | `string` | no       | `""`            | Preprocessor symbols.                             |
| `minver-tag-prefix`    | `string` | no       | `v`             | MinVer tag prefix.                                |
| `minver-prerelease-id` | `string` | no       | `preview.0`     | MinVer pre-release identifiers.                   |
| `max-regression-pct`   | `number` | no       | `20`            | Maximum acceptable performance regression (%).    |

### Secrets

| Secret              | Required | Description                          |
| :------------------ | :------- | :----------------------------------- |
| `BENCHER_API_TOKEN` | **yes**  | Bencher.dev API token                |

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

| Input                  | Type     | Required | Default         | Description                    |
| :--------------------- | :------- | :------- | :-------------- | :----------------------------- |
| `package-project`      | `string` | **yes**  | —               | Path to the project to pack.   |
| `runner-os`            | `string` | no       | `ubuntu-latest` | Runner OS.                     |
| `dotnet-version`       | `string` | no       | `10.0.x`        | .NET SDK version.              |
| `configuration`        | `string` | no       | `Release`       | Build configuration.           |
| `preprocessor-symbols` | `string` | no       | `""`            | Preprocessor symbols.          |
| `minver-tag-prefix`    | `string` | no       | `v`             | MinVer tag prefix.             |
| `minver-prerelease-id` | `string` | no       | `preview.0`     | MinVer pre-release identifiers.|

### Permissions

    contents: read
    packages: read

### Script

`pack.sh`

---

## _prerelease.yaml

Computes a prerelease version, updates the changelog, tags, and publishes a prerelease NuGet package.

### Inputs

| Input                   | Type      | Required | Default       | Description                                               |
| :---------------------- | :-------- | :------- | :------------ | :-------------------------------------------------------- |
| `package-projects`      | `string`  | no       | `[""]`        | JSON array of project paths to package and publish.       |
| `dotnet-version`        | `string`  | no       | `10.0.x`      | .NET SDK version.                                         |
| `preprocessor-symbols`  | `string`  | no       | `""`          | Preprocessor symbols.                                     |
| `minver-tag-prefix`     | `string`  | no       | `v`           | MinVer tag prefix.                                        |
| `minver-prerelease-id`  | `string`  | no       | `preview.0`   | Pre-release identifier (e.g., `preview.0`, `alpha`, `rc`).|
| `reason`                | `string`  | no       | `""`          | Reason for manual pre-release.                            |
| `nuget-server`          | `string`  | no       | `nuget`       | Target NuGet server (`nuget`, `github`, or a URI).        |
| `save-package-artifacts`| `boolean` | no       | `false`       | Upload packages as workflow artifacts.                    |

### Secrets

| Secret                 | Required | Description                                          |
| :--------------------- | :------- | :--------------------------------------------------- |
| `NUGET_API_KEY`        | no       | Default/custom NuGet server API key                  |
| `NUGET_API_GITHUB_KEY` | no       | GitHub Packages API key                              |
| `NUGET_API_NUGET_KEY`  | no       | nuget.org API key                                    |
| `RELEASE_PAT`          | **yes**  | PAT with `contents:write` for pushing to main        |

### Permissions

    contents: write

### Concurrency

    group: prerelease-${{ github.ref }}
    cancel-in-progress: false

### Jobs

| Job                    | Needs                                    | Description                                           |
| :--------------------- | :--------------------------------------- | :---------------------------------------------------- |
| `compute-version`      | —                                        | Determines prerelease version from conventional commits|
| `changelog-and-tag`    | `compute-version`                        | Updates CHANGELOG.md and creates prerelease Git tag    |
| `package-and-publish`  | `compute-version`, `changelog-and-tag`   | Checks out tag, builds, packs, and pushes to NuGet     |

### Scripts

`compute-prerelease-version.sh`, `changelog-and-tag.sh`, `publish-package.sh`

---

## _release.yaml

Computes a stable release version, updates the changelog, tags, and publishes.

### Inputs

| Input                   | Type      | Required | Default | Description                                               |
| :---------------------- | :-------- | :------- | :------ | :-------------------------------------------------------- |
| `dotnet-version`        | `string`  | **yes**  | —       | .NET SDK version.                                         |
| `package-projects`      | `string`  | **yes**  | —       | JSON array of project paths to package and publish.       |
| `preprocessor-symbols`  | `string`  | **yes**  | —       | Preprocessor symbols.                                     |
| `minver-tag-prefix`     | `string`  | **yes**  | —       | MinVer tag prefix.                                        |
| `minver-prerelease-id`  | `string`  | **yes**  | —       | Pre-release identifier.                                   |
| `reason`                | `string`  | **yes**  | —       | Reason for the release.                                   |
| `nuget-server`          | `string`  | **yes**  | —       | Target NuGet server.                                      |
| `save-package-artifacts`| `boolean` | **yes**  | —       | Upload packages as workflow artifacts.                    |

### Secrets

| Secret                 | Required | Description                                          |
| :--------------------- | :------- | :--------------------------------------------------- |
| `NUGET_API_KEY`        | no       | Default/custom NuGet server API key                  |
| `NUGET_API_GITHUB_KEY` | no       | GitHub Packages API key                              |
| `NUGET_API_NUGET_KEY`  | no       | nuget.org API key                                    |
| `RELEASE_PAT`          | **yes**  | PAT with `contents:write` for pushing to main        |

### Permissions

    contents: write

### Concurrency

    group: ci-${{ github.ref }}
    cancel-in-progress: true

### Jobs

| Job                 | Needs                                 | Description                                         |
| :------------------ | :------------------------------------ | :-------------------------------------------------- |
| `compute-version`   | —                                     | Determines stable version from conventional commits |
| `changelog-and-tag` | `compute-version`                     | Finalizes CHANGELOG.md and creates Git tag          |
| `release`           | `compute-version`, `changelog-and-tag`| Checks out tag, builds, packs, and publishes        |

### Scripts

`compute-release-version.sh`, `changelog-and-tag.sh`, `publish-package.sh`

---

## _clear_cache.yaml

Emergency cache cleanup with allowlisted prefixes.

### Inputs

| Input            | Type     | Required | Default                    | Description                                                                          |
| :--------------- | :------- | :------- | :------------------------- | :----------------------------------------------------------------------------------- |
| `reason`         | `string` | no       | `Emergency cache cleanup`  | Reason for clearing cache.                                                           |
| `cache-pattern`  | `string` | no       | `nuget-`                   | Cache key prefix to delete. Allowlist: `nuget-`, `build-artifacts-`, `bencher-cli-`. |

### Permissions

    actions: write
    contents: read
