# Configuration

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Configuration](#configuration)
  - [Configuration Layers](#configuration-layers)
  - [GitHub Repository Variables](#github-repository-variables)
  - [GitHub Repository Secrets](#github-repository-secrets)
    - [Actions Secrets](#actions-secrets)
    - [Dependabot Secrets](#dependabot-secrets)
  - [Per-Repo Configuration Files](#per-repo-configuration-files)
    - [NuGet.config](#nugetconfig)
    - [codecov.yaml](#codecovyaml)
    - [coverage.settings.xml](#coveragesettingsxml)
    - [testconfig.json](#testconfigjson)
    - [Changelog Configuration](#changelog-configuration)
    - [Git Hooks](#git-hooks)
    - [Local Git Settings](#local-git-settings)
  - [CI Behavior by Event Type](#ci-behavior-by-event-type)
  - [PR Gates and Checks](#pr-gates-and-checks)
    - [GitHub Check Names](#github-check-names)
    - [Setting Up Branch Protection](#setting-up-branch-protection)
    - [Required Permissions](#required-permissions)
  - [Consumer Workflow Customization](#consumer-workflow-customization)
    - [CI.yaml](#ciyaml)
    - [Prerelease.yaml](#prereleaseyaml)
    - [Release.yaml](#releaseyaml)
  - [Repository Setup via UI](#repository-setup-via-ui)
    - [Repository Settings](#repository-settings)
    - [Branch Protection](#branch-protection)
    - [Actions Permissions](#actions-permissions)
    - [Secrets](#secrets)
    - [Variables](#variables)
    - [Copilot Code Review](#copilot-code-review)
  - [Repository Setup using `repo-setup.sh`](#repository-setup-using-repo-setupsh)
  - [Running the Script `local-git-config.sh`](#running-the-script-local-git-configsh)

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
| `CONFIGURATION`                      | `Release`     | CI, Prerelease, Release    | Build configuration                            |
| `DOTNET_VERSION`                     | `10.0.x`      | CI, Prerelease, Release    | .NET SDK version                               |
| `MAX_REGRESSION_PCT`                 | `20`          | CI                         | Maximum benchmark regression percentage (0–50) |
| `MINVERDEFAULTPRERELEASEIDENTIFIERS` | `preview.0`   | CI, Prerelease, Release    | MinVer default pre-release identifiers         |
| `MINVERTAGPREFIX`                    | `v`           | CI, Prerelease, Release    | MinVer tag prefix                              |
| `MIN_COVERAGE_PCT`                   | `80`          | CI                         | Minimum code coverage percentage (50–100)      |
| `NUGET_SERVER`                       | `github`      | Prerelease, Release        | NuGet server: `github`, `nuget`, or URI        |
| `RESET_BENCHMARK_THRESHOLDS`         | `false`       | CI                         | Whether to reset Bencher thresholds            |
| `SAVE_PACKAGE_ARTIFACTS`             | `false`       | Prerelease                 | Upload packages as workflow artifacts          |
| `VERBOSE`                            | `false`       | All                        | Enable verbose logging in scripts              |

Also, for debugging purposes, you can define the GitHub standard variables ACTIONS_RUNNER_DEBUG and ACTIONS_STEP_DEBUG as
repository variables.

## GitHub Repository Secrets

### Actions Secrets

Set in repo Settings → Secrets and variables → Actions → Secrets.

| Secret                     | Required by         | Description                                              |
| :------------------------- | :------------------ | :------------------------------------------------------- |
| `BENCHER_API_TOKEN`        | CI (benchmarks)     | Bencher.dev API token for benchmark tracking             |
| `CODECOV_TOKEN`            | CI (test)           | Codecov API token for coverage uploads                   |
| `NUGET_API_KEY`            | Prerelease, Release | The NuGet API key for the selected NuGet server          |
| `REPORTGENERATOR_LICENSE`  | CI (test)           | ReportGenerator license key (optional, for Pro features) |
| `RELEASE_PAT`              | Prerelease, Release | Fine-grained PAT with `contents: write` — required to push the changelog commit and tag to `main` (bypasses branch protection rulesets) |

### Dependabot Secrets

Set in repo Settings → Secrets and variables → Dependabot → Secrets.

| Secret                       | Used by                       | Purpose                                                                           |
| :--------------------------- | :---------------------------- | :-------------------------------------------------------------------------------- |
| `GH_PACKAGES_TOKEN`          | `Dependabot`                  | The GitHub Packages token used by Dependabot to authenticate with GitHub Packages |

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

### Git Hooks

| File                                          | Purpose                                               |
| :-------------------------------------------- | :---------------------------------------------------- |
| `vm2.DevOps/scripts/githooks/commit-msg`      | Validates Conventional Commits format at commit time  |
| `vm2.DevOps/scripts/githooks/.gitmessage`     | Commit message template with allowed types            |

### Local Git Settings

Run once per clone to configure local git settings via `git config --local`:

| Setting                  | Value  | Purpose                                                    |
| :----------------------- | :----- | :--------------------------------------------------------- |
| `core.hooksPath`         | (path) | Points to shared commit-msg hook in vm2.DevOps             |
| `commit.template`        | (path) | Commit message template with allowed types                 |
| `pull.rebase`            | `true` | `git pull` rebases instead of creating merge commits       |
| `fetch.prune`            | `true` | Auto-removes stale remote-tracking branches on fetch/pull  |
| `push.autoSetupRemote`   | `true` | First push of a new branch auto-sets upstream tracking     |

```bash
git config --local core.hooksPath ~/repos/vm2/vm2.DevOps/scripts/githooks
git config --local commit.template ~/repos/vm2/vm2.DevOps/scripts/githooks/.gitmessage
git config --local pull.rebase true
git config --local fetch.prune true
git config --local push.autoSetupRemote true
```

## CI Behavior by Event Type

The CI workflow template adjusts its behavior based on the trigger:

| Event                | Behavior                                                              |
| :------------------- | :-------------------------------------------------------------------- |
| `push` to branch     | Adds `SHORT_RUN` preprocessor symbol; skipped if an open PR exists    |
| `push` to main       | Full CI with default parameters                                       |
| `pull_request`       | Full CI with default parameters                                       |
| `pull_request_review`| Configured at the GitHub repo level (Copilot review)                  |
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

1. **GitHub workflow templates** (from `vm2.Templates/templates/AddNewPackage/content/.github/workflows/`) — The templates
   contain `# *TODO*` markers at the usual customization points. The user must edit these before the workflow is usable.
2. **`dotnet new` project template** (from vm2.Templates) — The template engine substitutes project-specific values during
   instantiation. The generated workflows are ready to use without manual editing, although a review is recommended to
   understand and customize the configuration.

### CI.yaml

**`env:` block** — repo-specific project paths:

```yaml
env:
  BUILD_PROJECTS: >                     # JSON array of project/solution paths. If empty, assumes the solution file in the root
    [ "src/MyProject/MyProject.slnx" ]
  TEST_PROJECTS: >                      # JSON array of test project paths
    [ "test/MyProject.Tests/MyProject.Tests.csproj" ]
  BENCHMARK_PROJECTS: >                 # JSON array of benchmark project paths
    [ "benchmarks/MyProject.Benchmarks/MyProject.Benchmarks.csproj" ]
  PACKAGE_PROJECTS: >                   # JSON array of projects to package and publish
    [ "src/MyProject/MyProject.csproj" ]
  RUNNERS_OS: >                         # JSON array of runner OS monikers
    [ "ubuntu-latest" ]
  PREPROCESSOR_SYMBOLS: ""              # Space/Colon/Semicolon-separated preprocessor symbols
```

> [!NOTE] If any of the project arrays are empty, not set, or contains `["__skip__"]`, the corresponding CI steps will be skipped.

**`workflow_dispatch` inputs:**

| Input                  | Description                          |
| :--------------------- | :----------------------------------- |
| `preprocessor-symbols` | Comma-separated preprocessor symbols |
| `runners-os`           | Comma-separated runner OS overrides  |

**Secrets passed to `_ci.yaml`:**

```yaml
secrets:
  BENCHER_API_TOKEN: ${{ secrets.BENCHER_API_TOKEN }}
  CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
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
  RELEASE_PAT: ${{ secrets.RELEASE_PAT }}
  NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
```

## Repository Setup via UI

The `repo-setup.sh` script automates the steps below. If you prefer to configure it
manually, or need to verify/adjust settings on an existing repo, follow these steps.

### Repository Settings

**Settings → General → Features:**

1. ❌ **Wikis** (documentation lives in the repo README.md and possibly docs/ folder)
1. ❌ **Projects** (not used)

**Settings → General → Pull Requests:**

1. ❌ **Allow merge commits**
1. ❌ **Allow squash merging** (default merge strategy)
1. ✔️ **Allow rebase merging**
1. ✔️ **Allow auto-merge**
1. ✔️ **Automatically delete head branches**

### Branch Protection

**Settings → Rules → Rulesets → New ruleset:**

1. **Ruleset Name:** `main protection` (the name is mandatory - expected by the audit option of `repo-setup.sh`)
1. **Enforcement status:** Active
1. **Bypass list:** click **+ Add bypass** and choose:

   - **Repository admin (Role)** — allows the prerelease and release workflows (which authenticate via `RELEASE_PAT` as the repo
     admin) to push the changelog commit and tag directly to `main`
     - bypass mode **Always**

1. **Target branches:** click **Add target** and choose:

   - Include default branch

1. Enable rules:

   - ✔️ Restrict deletions
   - ✔️ Require linear history
   - ✔️ Require a pull request before merging (🔽 show additional settings)
     - Required approvals - **0** (for single maintainer repos, increase as needed)
     - ✔️ Dismiss stale pull request approvals when new commits are pushed
     - ✔️ Require conversation resolution before merging
     - 🔽 Allowed merge methods
       - ❌ Merge  (required for proper work of git-cliff)
       - ❌ Squash
       - ✔️ Rebase
   - Require status checks to pass 🔽 Select CI jobs* (see note below)
     - ✔️ Require up-to-date branches
   - ✔️ Block force pushes
   - ✔️ Automatically request Copilot code reviews
     - ✔️ Review new pushes
     - ✔️ Review draft pull requests (Optional)

Unfortunately, only the script `repo-setup.sh` can automatically configure the required status checks for branch
protection rules using the GitHub API and parameters that are otherwise not exposed in the GitHub UI. The idea is that
there is one final "dummy" job "Postrun-CI" that depends on all other jobs and reports a single, stable check name that
can be used in the branch protection rules. However in certain PR scenarios it registers a false negative which is
incorrect and the script fixes that by using UI-unexposed parameter(s).

Click **Create** or **Save changes** to save the ruleset.

### Actions Permissions

**Settings → Actions → General → Workflow permissions:**

1. Select  ✔️ **Read repository contents and packages permissions**

### Secrets

**Settings → Secrets and variables → Actions → Secrets → New repository secret** for each:

| Secret                    | Value                                             |
| :------------------------ | :------------------------------------------------ |
| `BENCHER_API_TOKEN`       | From [bencher.dev](https://bencher.dev) dashboard |
| `CODECOV_TOKEN`           | From [codecov.io](https://codecov.io) dashboard   |
| `NUGET_API_KEY`           | The NuGet API key for the selected NuGet server   |
| `RELEASE_PAT`             | Fine-grained PAT with `contents:write` — owner must be added as bypass actor in branch ruleset |
| `REPORTGENERATOR_LICENSE` | ReportGenerator Pro license key (optional)        |

### Variables

**Settings → Secrets and variables → Actions → Variables → New repository variable** for each:

| Variable                             | Default     |
| :----------------------------------- | :---------- |
| `CONFIGURATION`                      | `Release`   |
| `DOTNET_VERSION`                     | `10.0.x`    |
| `MAX_REGRESSION_PCT`                 | `20`        |
| `MINVERDEFAULTPRERELEASEIDENTIFIERS` | `preview.0` |
| `MINVERTAGPREFIX`                    | `v`         |
| `MIN_COVERAGE_PCT`                   | `80`        |
| `NUGET_SERVER`                       | `github`    |
| `RESET_BENCHMARK_THRESHOLDS`         | `false`     |
| `SAVE_PACKAGE_ARTIFACTS`             | `false`     |
| `VERBOSE`                            | `false`     |

All variables are optional — workflows use these defaults when the variable is not set. You may also want to add the GitHub
Actions standard `ACTIONS_RUNNER_DEBUG` and `ACTIONS_STEP_DEBUG` variables for debugging purposes.

### Copilot Code Review

**Settings → Copilot → Code review:**

1. Enable ✔️ **Copilot code review** to automatically review pull requests
2. This is advisory only — it does not block merging

## Repository Setup using `repo-setup.sh`

The `repo-setup.sh` script automates the repository setup steps outlined above, including:

- Checking prerequisites (GitHub CLI, API access, etc.)
- Initializing a new repository if the specified path is not already a git repository but contains a valid `CI.yaml`
- Creating or updating the GitHub repository with the correct settings and permissions
- Configuring branch protection rules with the correct status checks
- Verifying the presence of required secrets and variables

In the end the script does an audit of all settings and provides remediation steps for any manual configuration that is still required.
It can be safely re-run to fix any drift or misconfiguration that may occur over time. At the writing of this document the
audit result may look like this:

```text
❯ repo-setup.sh vm2.SemVer -a
ℹ️  INFO: Git repository path            => /home/valo/repos/vm2/vm2.SemVer
ℹ️  INFO: GitHub repository              => vmelamed/vm2.SemVer
ℹ️  INFO: GitHub repository Id           => 1199917173
ℹ️  INFO: GitHub default Branch          => main
ℹ️  INFO: GitHub repository URL          => git@github.com:vmelamed/vm2.SemVer.git
ℹ️  Audit
  ℹ️  Repository settings:
      ✅  Default branch                       => main
      ✅  Has wiki                             => false
      ✅  Has issues                           => true
      ✅  Has projects                         => false
      ✅  Has pull requests                    => true
      ✅  Pull request creation policy         => all
      ✅  Allow merge commit                   => false
      ✅  Allow squash merge                   => false
      ✅  Allow rebase merge                   => true
      ✅  Allow auto merge                     => true
      ✅  Delete branch on merge               => true
      ✅  Visibility                           => public
  ℹ️  Actions permissions:
      ✅  Can approve pull request reviews     => false
      ✅  Default workflow permissions         => read
  ℹ️  Actions Secrets:
      🆗  BENCHER_API_TOKEN                    => <set>
      🆗  CODECOV_TOKEN                        => <set>
      🆗  NUGET_API_KEY                        => <set>
      🆗  RELEASE_PAT                          => <set>
      🆗  REPORTGENERATOR_LICENSE              => <set>
  ℹ️  Dependabot Secrets:
      🆗  GH_PACKAGES_TOKEN                    => <set>
  ℹ️  Variables:
      ✅  ACTIONS_RUNNER_DEBUG                 => false
      ✅  ACTIONS_STEP_DEBUG                   => false
      ✅  CONFIGURATION                        => Release
      ✅  DOTNET_VERSION                       => 10.0.x
      ✅  MAX_REGRESSION_PCT                   => 20
      ✅  MIN_COVERAGE_PCT                     => 80
      ✅  MINVERDEFAULTPRERELEASEIDENTIFIERS   => preview.0
      ✅  MINVERTAGPREFIX                      => v
      ✅  NUGET_SERVER                         => github
      ✅  RESET_BENCHMARK_THRESHOLDS           => false
      ✅  SAVE_PACKAGE_ARTIFACTS               => false
      ✅  VERBOSE                              => false
  ℹ️  Ruleset 'main protection' for branch 'main' (id: 14653967):
      ✅  Enforcement                          => active
      ✅  Repository admin bypass              => present
      ✅  Deletion                             => present
      ✅  Required linear history              => present
      ✅  Pull request                         => present
      ✅  Required approving review count      => present
      ✅  Dismiss stale reviews on push        => present
      ✅  Require code owner review            => present
      ✅  Require last push approval           => present
      ✅  Required review thread resolution    => present
      ✅  Required reviewers                   => present
      ✅  Allowed merge methods                => present
      ✅  Required status checks               => present
      ✅  Do not enforce on create             => present
      ✅  Strict required status checks policy => present
      ✅  Non fast forward                     => present
      ℹ️  Required status checks list:
          ✅  Postrun-CI - present

──────────────────────
ℹ️  Totals:
    ✅  passed:     49
    ❓  different:   0
    ❌  missing:     0

ℹ️  INFO: Audit of https://github.com/vmelamed/vm2.SemVer completed.
```

## Running the Script `local-git-config.sh`

This is a one-time setup script that configures local git settings for the repository, such as hooks and pull
behavior.  It configures the repository with optional but highly recommended settings for a smooth development
experience, including:

| Setting                  | Value  | Purpose                                                    |
| :----------------------- | :----- | :--------------------------------------------------------- |
| `core.hooksPath`         | (path) | Points to shared commit-msg hook in vm2.DevOps             |
| `commit.template`        | (path) | Commit message template with allowed types                 |
| `pull.rebase`            | `true` | `git pull` rebases instead of creating merge commits       |
| `fetch.prune`            | `true` | Auto-removes stale remote-tracking branches on fetch/pull  |
| `push.autoSetupRemote`   | `true` | First push of a new branch auto-sets upstream tracking     |
