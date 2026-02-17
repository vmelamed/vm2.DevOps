# Configuration

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Configuration Layers](#configuration-layers)
- [GitHub Repository Variables](#github-repository-variables)
- [GitHub Repository Secrets](#github-repository-secrets)
- [Per-Repo Configuration Files](#per-repo-configuration-files)
  - [NuGet.config](#nugetconfig)
  - [codecov.yaml](#codecovyaml)
  - [coverage.settings.xml](#coveragesettingsxml)
  - [testconfig.json](#testconfigjson)
  - [Changelog Configuration](#changelog-configuration)
- [CI Behavior by Event Type](#ci-behavior-by-event-type)
- [PR Gates and Checks](#pr-gates-and-checks)
  - [GitHub Check Names](#github-check-names)
  - [Setting Up Branch Protection](#setting-up-branch-protection)
  - [Required Permissions](#required-permissions)
- [Consumer Workflow Customization](#consumer-workflow-customization)
  - [CI.yaml](#ciyaml)
  - [Prerelease.yaml](#prereleaseyaml)
  - [Release.yaml](#releaseyaml)

<!-- /TOC -->

How to configure the CI/CD pipelines for a consumer repository.

## Configuration Layers

Settings flow through five layers, each overriding the previous:

1. **Scripts defaults** — Hardcoded defaults in the reusable scripts (e.g., `v`, or `preview.0`).
1. **Workflow defaults** — Hardcoded defaults in reusable workflows (e.g., `dotnet-version: 10.0.x`, or `Release`).
1. **GitHub repository variables** (`vars.*`) — Set in repo Settings → Secrets and variables → Actions → Variables.
1. **Workflow `env:` block** — Per-repo values set directly in the consumer workflow YAML.
1. **`workflow_dispatch` inputs** — Manual overrides when triggering a run from the UI.

## GitHub Repository Variables

Optional. When set, they override the workflow defaults. All consumer templates read these
via the `${{ vars.NAME || '<default>' }}` pattern.

| Variable                             | Default       | Used by                    | Description                                    |
| :----------------------------------- | :------------ | :------------------------- | :--------------------------------------------- |
| `DOTNET_VERSION`                     | `10.0.x`      | CI, Prerelease, Release    | .NET SDK version                               |
| `CONFIGURATION`                      | `Release`     | CI, Prerelease, Release    | Build configuration                            |
| `MIN_COVERAGE_PCT`                   | `80`          | CI                         | Minimum code coverage percentage (50–100)      |
| `MAX_REGRESSION_PCT`                 | `20`          | CI                         | Maximum benchmark regression percentage (0–50) |
| `MINVERTAGPREFIX`                    | `v`           | CI, Prerelease, Release    | MinVer tag prefix                              |
| `MINVERDEFAULTPRERELEASEIDENTIFIERS` | `preview.0`   | CI, Prerelease, Release    | MinVer default pre-release identifiers         |
| `NUGET_SERVER`                       | `github`      | Prerelease, Release        | NuGet server: `github`, `nuget`, or URI        |
| `SAVE_PACKAGE_ARTIFACTS`             | `false`       | Prerelease                 | Upload packages as workflow artifacts          |
| `VERBOSE`                            | `false`       | All                        | Enable verbose logging in scripts              |

Also, for debugging purposes, you can define the GitHub standard variables ACTIONS_RUNNER_DEBUG and ACTIONS_STEP_DEBUG as
repository variables.

## GitHub Repository Secrets

Set in repo Settings → Secrets and variables → Actions → Secrets.

| Secret                     | Required by         | Description                                              |
| :------------------------- | :------------------ | :------------------------------------------------------- |
| `CODECOV_TOKEN`            | CI (test)           | Codecov API token for coverage uploads                   |
| `BENCHER_API_TOKEN`        | CI (benchmarks)     | Bencher.dev API token for benchmark tracking             |
| `REPORTGENERATOR_LICENSE`  | CI (test)           | ReportGenerator license key (optional, for Pro features) |
| `NUGET_API_KEY`            | Prerelease, Release | Default NuGet API key (fallback for any server)          |
| `NUGET_API_GITHUB_KEY`     | Prerelease, Release | GitHub Packages API key                                  |
| `NUGET_API_NUGET_KEY`      | Prerelease, Release | nuget.org API key                                        |

For NuGet publishing, the key used depends on the `NUGET_SERVER` value:

| Server   | Primary secret           | Fallback          |
| :------- | :----------------------- | :---------------- |
| `github` | `NUGET_API_GITHUB_KEY`   | `NUGET_API_KEY`   |
| `nuget`  | `NUGET_API_NUGET_KEY`    | `NUGET_API_KEY`   |
| custom   | `NUGET_API_KEY`          | —                 |

## Per-Repo Configuration Files

Beyond the workflows, each consumer repo needs these configuration files:

### NuGet.config

Registers the GitHub Packages feed for private package restore:

```xml
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="github.vm2" value="https://nuget.pkg.github.com/vmelamed/index.json" />
</packageSources>
```

The `github.vm2` source name is referenced by the workflow authentication step.

### codecov.yaml

Codecov configuration for coverage thresholds, flags, and PR comments. Each consumer repo maintains its own `codecov.yaml` with
project-specific flag names matching the test project names.

### coverage.settings.xml

Code coverage collection settings for `dotnet test`. Defines assembly exclusions (test assemblies, utilities) and source file
exclusions (generated code, designer files).

### testconfig.json

Test runner (usually xUnit) configuration. Controls parallelism, culture, diagnostics, and long-running test thresholds.

### Changelog Configuration

| File                                  | Purpose                              |
| :------------------------------------ | :----------------------------------- |
| `changelog/cliff.prerelease.toml`     | git-cliff config for prerelease runs |
| `changelog/cliff.release-header.toml` | git-cliff config for stable releases |

## CI Behavior by Event Type

The CI workflow template adjusts its behavior based on the trigger:

| Event                | Behavior                                                              |
| :------------------- | :-------------------------------------------------------------------- |
| `push` to main       | Full CI with default parameters                                       |
| `push` to branch     | Adds `SHORT_RUN` preprocessor symbol; skipped if an open PR exists    |
| `pull_request`       | Full CI with default parameters                                       |
| `pull_request_review`| Runs only on `approved` reviews                                       |
| `workflow_dispatch`  | Accepts manual overrides for `runners-os` and `preprocessor-symbols`  |

Commit message keywords:

| Keyword       | Effect                                    | Applies to     |
| :------------ | :---------------------------------------- | :------------- |
| `[skip ci]`   | Skip the entire CI run                    | `push` events  |
| `[skip bm]`   | Skip benchmarks only                      | `push` events  |

## PR Gates and Checks

### GitHub Check Names

When CI runs, it creates these checks (visible in the PR Checks tab):

| Check                                                 | Created by        |
| :---------------------------------------------------- | :---------------- |
| `Build / build ({os})`                                | `_build.yaml`     |
| `Tests / test ({os}, {test-project})`                 | `_test.yaml`      |
| `Benchmarks / benchmarks ({os}, {benchmark-project})` | `_benchmarks.yaml`|

### Setting Up Branch Protection

1. Navigate to repo **Settings → Rules → Rulesets** (or **Branches** for classic rules).
2. Create a rule targeting `main`.
3. Enable **Require status checks to pass**.
4. Search for and add the check names listed above.
5. Optionally enable **Require branches to be up to date before merging**.

> **Note:** GitHub only shows checks that have run at least once. Create a test PR first
> to populate the check list.

### Required Permissions

Consumer workflows must grant these permissions for checks and PR comments to work:

```yaml
permissions:
  contents: read
  packages: read
  pull-requests: write    # PR comments
  checks: write           # GitHub Check annotations
```

## Consumer Workflow Customization

Each consumer workflow has customizable `env:` variables, `inputs:`, and `secrets:` sections. Consumer workflows can be created
in two ways:

1. **GitHub workflow templates** (from `vmelamed/.github/workflow-templates/`) — The templates contain `# *TODO*` markers at the
   usual customization points. The user must edit these before the workflow is usable.
1. **`dotnet new` project template** (from vm2.Templates) — The template engine substitutes project-specific values during
   instantiation. The generated workflows are ready to use without manual editing.

### CI.yaml

**`env:` block** — repo-specific project paths:

```yaml
env:
  BUILD_PROJECTS: >                     # JSON array of project/solution paths
    [ "src/MyProject/MyProject.slnx" ]
  TEST_PROJECTS: >                      # JSON array of test project paths
    [ "test/MyProject.Tests/MyProject.Tests.csproj" ]
  BENCHMARK_PROJECTS: >                 # JSON array of benchmark project paths (optional)
    [ "benchmarks/MyProject.Benchmarks/MyProject.Benchmarks.csproj" ]
  PACKAGE_PROJECTS: >                   # JSON array of projects to pack (optional)
    [ "src/MyProject/MyProject.csproj" ]
  RUNNERS_OS: >                         # JSON array of runner OS monikers
    [ "ubuntu-latest" ]
  PREPROCESSOR_SYMBOLS: ""              # Semicolon-separated preprocessor symbols
```

**`workflow_dispatch` inputs:**

| Input                  | Description                          |
| :--------------------- | :----------------------------------- |
| `runners-os`           | Comma-separated runner OS overrides  |
| `preprocessor-symbols` | Comma-separated preprocessor symbols |

**Secrets passed to `_ci.yaml`:**

```yaml
secrets:
  CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
  BENCHER_API_TOKEN: ${{ secrets.BENCHER_API_TOKEN }}
  REPORTGENERATOR_LICENSE: ${{ secrets.REPORTGENERATOR_LICENSE }}
```

### Prerelease.yaml

**`env:` block:**

```yaml
env:
  PACKAGE_PROJECTS: >                   # JSON array of projects to package and publish
    [ "src/MyProject/MyProject.csproj" ]
  PREPROCESSOR_SYMBOLS: ""              # Semicolon-separated preprocessor symbols
```

**`workflow_dispatch` inputs:**

| Input                  | Description                                   |
| :--------------------- | :-------------------------------------------- |
| `minver-prerelease-id` | Prerelease prefix (e.g., `preview`, `alpha`)  |
| `reason`               | Reason for manual pre-release                 |

**Secrets passed to `_prerelease.yaml`:**

```yaml
secrets:
  NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
  NUGET_API_GITHUB_KEY: ${{ secrets.NUGET_API_GITHUB_KEY }}
  NUGET_API_NUGET_KEY: ${{ secrets.NUGET_API_NUGET_KEY }}
```

### Release.yaml

**`env:` block:**

```yaml
env:
  PACKAGE_PROJECTS: >                   # JSON array of projects to package and publish
    [ "src/MyProject/MyProject.csproj" ]
  PREPROCESSOR_SYMBOLS: ""              # Semicolon-separated preprocessor symbols
```

**`workflow_dispatch` inputs:**

| Input    | Description                  |
| :------- | :--------------------------- |
| `reason` | Reason for manual release    |

**Secrets passed to `_release.yaml`:**

```yaml
secrets:
  NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
  NUGET_API_GITHUB_KEY: ${{ secrets.NUGET_API_GITHUB_KEY }}
  NUGET_API_NUGET_KEY: ${{ secrets.NUGET_API_NUGET_KEY }}
```
