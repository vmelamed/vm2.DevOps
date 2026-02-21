# Scripts Reference

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Sourcing Chains](#sourcing-chains)
  - [Common Switches](#common-switches)
- [1. Bash Library](#1-bash-library)
- [2. Utility Scripts](#2-utility-scripts)
  - [diff-common.sh](#diff-commonsh)
  - [move-commits-to-branch.sh](#move-commits-to-branchsh)
  - [Other Utilities](#other-utilities)
- [3. CI Scripts](#3-ci-scripts)
  - [validate-input.sh](#validate-inputsh)
  - [build.sh](#buildsh)
  - [run-tests.sh](#run-testssh)
  - [run-benchmarks.sh](#run-benchmarkssh)
  - [pack.sh](#packsh)
  - [publish-package.sh](#publish-packagesh)
  - [compute-release-version.sh](#compute-release-versionsh)
  - [compute-prerelease-version.sh](#compute-prerelease-versionsh)
  - [changelog-and-tag.sh](#changelog-and-tagsh)
  - [download-artifact.sh](#download-artifactsh)
  - [bootstrap-new-package.sh](#bootstrap-new-packagesh)

<!-- /TOC -->

vm2.DevOps contains three distinct categories of scripts:

1. **CI Scripts** — GitHub Actions scripts invoked by reusable workflows. Built on `gh_core.sh`.
1. **Utility Scripts** — Developer-facing tools for one-off chores. Built on `core.sh` directly.
1. **Bash Library** — Shared function library sourced by all scripts. The foundation layer.

## Sourcing Chains

    CI Scripts:          script.sh → gh_core.sh ---→ core.sh → all _*.sh modules
                                   ↘ _sanitize.sh
                                   ↘ _dotnet.sh

    Utility Scripts:     script.sh ----------------→ core.sh → all _*.sh modules

`core.sh` sources all component modules (`_constants.sh`, `_diagnostics.sh`, `_args.sh`,
`_predicates.sh`, `_dump_vars.sh`, `_git.sh`, `_semver.sh`, `_user.sh`).

`gh_core.sh` adds GitHub Actions–specific helpers on top, plus the CI specific `_sanitize.sh` and `_dotnet.sh`.

### Common Switches

All scripts (CI and utility) inherit these switches from the bash library:

| Switch             | Short | Description                                               |
| :----------------- | :---- | :-------------------------------------------------------- |
| `--verbose`        | `-v`  | Enable verbose output, tracing, and dump outputs          |
| `--trace`          | `-x`  | Verbose + bash `set -x`                                   |
| `--dry-run`        | `-y`  | Show commands without executing state-changing operations |
| `--quiet`          | `-q`  | Suppress interactive prompts (default in CI)              |
| `--graphical`      | `-gr` | Dump tables in graphical format                           |
| `--markdown`       | `-md` | Dump tables in markdown format (default in CI)            |
| `--help`           |       | Long usage text including common switches                 |
|                    | `-h`  | Short usage text                                          |

---

## 1. Bash Library

Located in **`scripts/bash/lib/`**. The foundation layer sourced by all scripts.

`core.sh` is the entry point — it sources all component modules automatically:

    core.sh
     ├── _constants.sh
     ├── _diagnostics.sh    (info, warning, error, trace)
     ├── _args.sh           (argument parsing, common switches, get_common_arg)
     ├── _predicates.sh     (boolean test functions)
     ├── _dump_vars.sh      (dump_vars for debugging)
     ├── _git.sh            (Git repository helpers)
     ├── _semver.sh         (semver parsing, comparison, tag validation)
     └── _user.sh           (user/identity helpers)

`gh_core.sh` extends `core.sh` for the GitHub Actions environment:

    gh_core.sh
     ├── core.sh            (everything above)
     ├── _sanitize.sh       (input sanitization: is_safe_reason, etc.)
     └── _dotnet.sh         (.NET SDK helpers)

See [FUNCTIONS_REFERENCE.md](../scripts/bash/lib/FUNCTIONS_REFERENCE.md) for the full list
of 67 library functions.

---

## 2. Utility Scripts

Located in **`scripts/bash/`**. Developer-facing tools for one-off chores. These source
`core.sh` directly (not `gh_core.sh`) and do not require the GitHub Actions environment.

They follow the same three-file pattern where applicable.

### diff-common.sh

Compares pre-defined shared set of files between source-of-truth repos (vm2.DevOps, .github) and a target project. Useful for
keeping common configuration files in sync across repos.

| Option                      | Short | Default      | Description                              |
| :-------------------------- | :---- | :----------- | :--------------------------------------- |
| `<repository-name-or-path>` |       | current dir  | Positional: repo name or path to compare |
| `--repos`                   | `-r`  | `$GIT_REPOS` | Parent directory of all repos            |
| `--minver-tag-prefix`       | `-mp` | `v`          | Tag prefix for detecting stable versions |
| `--files`                   | `-f`  | all          | Comma-separated list or regex of files   |

### move-commits-to-branch.sh

Moves commits from a specified SHA onward to a new branch, resetting main to the prior commit.

| Option            | Short | Description                             |
| :---------------- | :---- | :-------------------------------------- |
| `--commit-sha`    | `-c`  | SHA from which to move commits          |
| `--branch`        | `-b`  | New branch name                         |
| `--check-out-new` | `-n`  | Check out the new branch after the move |

### Other Utilities

| Script                  | Purpose                                    |
| :---------------------- | :----------------------------------------- |
| `add-spdx.sh`           | Add SPDX license headers to source files   |
| `retag.sh`              | Recreate a Git tag at a different commit   |
| `restore-force-eval.sh` | Force re-evaluation of NuGet restore       |

## 3. CI Scripts

Located in **`.github/actions/scripts/`**. These are the scripts invoked by the reusable
workflows documented in [WORKFLOWS_REFERENCE.md](WORKFLOWS_REFERENCE.md). They require
the GitHub Actions environment and source `gh_core.sh`.

Each CI script follows a **three-file pattern**:

| File               | Purpose                         |
| :----------------- | :------------------------------ |
| `script.sh`        | Entry point — sources lib, runs |
| `script.usage.sh`  | `--help` text                   |
| `script.utils.sh`  | Argument parsing                |

---

### validate-input.sh

Validates and normalizes all CI workflow inputs. Outputs them to `$GITHUB_OUTPUT` for
downstream jobs.

**Called by:** `_ci.yaml`

| Option                   | Short  | Default              | Description                                  |
| :----------------------- | :----- | :------------------- | :------------------------------------------- |
| `--build-projects`       | `-bp`  | auto-detect          | JSON array of project paths to build         |
| `--test-projects`        | `-tp`  | —                    | JSON array of test project paths             |
| `--benchmark-projects`   | `-bmp` | —                    | JSON array of benchmark project paths        |
| `--package-projects`     | `-pp`  | —                    | JSON array of project paths to pack          |
| `--runners-os`           | `-os`  | `["ubuntu-latest"]`  | JSON array of runner OS monikers             |
| `--dotnet-version`       | `-dn`  | `10.0.x`             | .NET SDK version                             |
| `--configuration`        | `-c`   | `Release`            | Build configuration                          |
| `--define`               | `-d`   | `""`                 | Preprocessor symbols                         |
| `--min-coverage-pct`     | `-min` | `80`                 | Minimum code coverage (50–100)               |
| `--max-regression-pct`   | `-max` | `20`                 | Maximum benchmark regression (0–50)          |
| `--minver-tag-prefix`    | `-mp`  | `v`                  | MinVer tag prefix                            |
| `--minver-prerelease-id` | `-mi`  | `preview.0`          | MinVer pre-release identifiers               |

**Outputs:** All inputs echoed to `$GITHUB_OUTPUT` in `kebab-case` format.

---

### build.sh

Compiles a .NET project or solution.

**Called by:** `_build.yaml`

| Option                   | Short | Default         | Description                    |
| :----------------------- | :---- | :-------------- | :----------------------------- |
| `--build-project`        | `-bp` | auto-detect     | Path to project/solution       |
| `--configuration`        | `-c`  | `Release`       | Build configuration            |
| `--define`               | `-d`  | `""`            | Preprocessor symbols           |
| `--minver-tag-prefix`    | `-mp` | `v`             | MinVer tag prefix              |
| `--minver-prerelease-id` | `-mi` | `preview.0`     | MinVer pre-release identifiers |
| `--nuget-username`       |       | `$GITHUB_ACTOR` | NuGet auth username            |
| `--nuget-password`       |       | `$GITHUB_TOKEN` | NuGet auth token               |

---

### run-tests.sh

Runs tests and collects code coverage. Assumes project layout:
`<solution>/test/<project>/<project>.csproj`.

**Called by:** `_test.yaml`

| Option                   | Short  | Default         | Description                          |
| :----------------------- | :----- | :-------------- | :----------------------------------- |
| `<test-project-path>`    |        | `$TEST_PROJECT` | Positional: path to test project     |
| `--configuration`        | `-c`   | `Release`       | Build configuration                  |
| `--define`               | `-d`   | `""`            | Preprocessor symbols                 |
| `--min-coverage-pct`     | `-min` | `80`            | Minimum coverage percentage (50–100) |
| `--minver-tag-prefix`    | `-mp`  | `v`             | MinVer tag prefix                    |
| `--minver-prerelease-id` | `-mi`  | `preview.0`     | MinVer pre-release identifiers       |
| `--artifacts`            | `-a`   | `TestArtifacts` | Artifacts output directory           |

**Output:** `results-dir` → `$GITHUB_OUTPUT`

---

### run-benchmarks.sh

Runs BenchmarkDotNet benchmarks. Assumes layout:
`<solution>/benchmarks/<project>/<project>.csproj`.

**Called by:** `_benchmarks.yaml`

| Option                   | Short  | Default              | Description                           |
| :----------------------- | :----- | :------------------- | :------------------------------------ |
| `<bm-project-path>`      |        | `$BENCHMARK_PROJECT` | Positional: path to benchmark project |
| `--configuration`        | `-c`   | `Release`            | Build configuration                   |
| `--define`               | `-d`   | `""`                 | Preprocessor symbols                  |
| `--max-regression-pct`   | `-max` | `20`                 | Max regression percentage (0–50)      |
| `--minver-tag-prefix`    | `-mp`  | `v`                  | MinVer tag prefix                     |
| `--minver-prerelease-id` | `-mi`  | `preview.0`          | MinVer pre-release identifiers        |
| `--artifacts`            | `-a`   | `BenchmarkArtifacts` | Artifacts output directory            |
| `--short-run`            | `-s`   | —                    | Shortcut for `--define SHORT_RUN`     |

**Output:** `results-dir` → `$GITHUB_OUTPUT`

---

### pack.sh

Validates that a project can be packed into a NuGet package (dry-run, no publish).

**Called by:** `_pack.yaml`

| Option                   | Short | Default     | Description                    |
| :----------------------- | :---- | :---------- | :----------------------------- |
| `--package-project`      | `-pp` | —           | Path to the project to pack    |
| `--configuration`        | `-c`  | `Release`   | Build configuration            |
| `--define`               | `-d`  | `""`        | Preprocessor symbols           |
| `--minver-tag-prefix`    | `-mp` | `v`         | MinVer tag prefix              |
| `--minver-prerelease-id` | `-mi` | `preview.0` | MinVer pre-release identifiers |

---

### publish-package.sh

Builds, packs, and pushes a NuGet package to the specified server.

**Called by:** `_prerelease.yaml`, `_release.yaml`

| Option                   | Short | Default                    | Description                                    |
| :----------------------- | :---- | :------------------------- | :--------------------------------------------- |
| `--package-project`      | `-pp` | —                          | Path to the project to package                 |
| `--define`               | `-d`  | `""`                       | Preprocessor symbols                           |
| `--minver-tag-prefix`    | `-mp` | `v`                        | MinVer tag prefix                              |
| `--minver-prerelease-id` | `-mi` | `preview.0`                | MinVer pre-release identifiers                 |
| `--reason`               | `-r`  | `release build`            | Reason for release (added to package metadata) |
| `--nuget-server`         | `-n`  | `github`                   | Target: `github`, `nuget`, or a custom URI     |
| `--artifacts-saved`      | `-a`  | `false`                    | Upload packages as workflow artifacts          |
| `--artifacts-dir`        | `-ad` | `artifacts/pack`           | Directory for saved artifacts                  |
| `--repo-owner`           | `-o`  | `$GITHUB_REPOSITORY_OWNER` | Repo owner (for GitHub Packages)               |

**NuGet API key resolution:**

| Server   | Primary env var          | Fallback         |
| :------- | :----------------------- | :--------------- |
| `github` | `$NUGET_API_GITHUB_KEY`  | `$NUGET_API_KEY` |
| `nuget`  | `$NUGET_API_NUGET_KEY`   | `$NUGET_API_KEY` |
| custom   | `$NUGET_API_KEY`         | —                |

---

### compute-release-version.sh

Determines the next stable release version from conventional commit messages.

**Called by:** `_release.yaml`

| Option                | Short | Default         | Description        |
| :-------------------- | :---- | :-------------- | :----------------- |
| `--minver-tag-prefix` | `-mp` | `v`             | MinVer tag prefix  |
| `--reason`            | `-r`  | `release build` | Reason for release |

**Outputs:** `release-version`, `release-tag`, `reason` → `$GITHUB_OUTPUT`

See [ARCHITECTURE.md — Release Version Calculation](ARCHITECTURE.md#release-version-calculation)
for the algorithm.

---

### compute-prerelease-version.sh

Determines the next prerelease version from conventional commit messages.

**Called by:** `_prerelease.yaml`

| Option                   | Short | Default      | Description                                            |
| :----------------------- | :---- | :----------- | :----------------------------------------------------- |
| `--minver-tag-prefix`    | `-mp` | `v`          | MinVer tag prefix                                      |
| `--minver-prerelease-id` | `-mi` | `preview.0`  | MinVer pre-release identifiers (e.g., `preview.0`)     |
| `--reason`               | `-r`  | `prerelease` | Reason for release                                     |

**Outputs:** `prerelease-version`, `prerelease-tag`, `reason` → `$GITHUB_OUTPUT`

See [ARCHITECTURE.md — Prerelease Version Calculation](ARCHITECTURE.md#prerelease-version-calculation)
for the algorithm.

---

### changelog-and-tag.sh

Updates CHANGELOG.md via git-cliff, then creates and pushes the tag (release or prerelease).

**Called by:** `_prerelease.yaml`, `_release.yaml`

**Requires:** `git-cliff` installed; `changelog/cliff.release-header.toml` (stable) or
`changelog/cliff.prerelease.toml` (prerelease) in the repo. Config is auto-selected based
on the tag type.

| Option                | Short | Default          | Description                                                      |
| :-------------------- | :---- | :--------------- | :--------------------------------------------------------------- |
| `--release-tag`       | `-t`  | —                | Tag to create (e.g., `v1.2.3` or `v1.3.0-preview.1`)             |
| `--minver-tag-prefix` | `-p`  | `v`              | MinVer tag prefix                                                |
| `--reason`            | `-r`  | auto-detected    | Reason (included in tag annotation); defaults based on tag type  |

---

### download-artifact.sh

Downloads the latest artifact from a previous workflow run.

**Called by:** utility — not directly invoked by the standard workflows.

| Option         | Short | Default                  | Description                           |
| :------------- | :---- | :----------------------- | :------------------------------------ |
| `--artifact`   | `-a`  | —                        | Name of the artifact to download      |
| `--directory`  | `-d`  | `./BmArtifacts/baseline` | Download destination directory        |
| `--repository` | `-r`  | —                        | GitHub repository (`owner/repo`)      |
| `--wf-id`      | `-i`  | —                        | Workflow ID                           |
| `--wf-name`    | `-n`  | —                        | Workflow name (as shown in GitHub UI) |
| `--wf-path`    | `-p`  | —                        | Workflow file path in the repo        |

Workflow lookup priority: `--wf-name` > `--wf-path` > `--wf-id` (or the corresponding env vars).

---

### bootstrap-new-package.sh

Bootstraps and configures a vm2 package repository using the GitHub CLI. Creates the repo,
sets secrets/variables, configures repo settings, Actions permissions, and branch protection.

**Requires:** `gh` (authenticated), `jq`

| Option             | Short | Default     | Description                                         |
| :----------------- | :---- | :---------- | :-------------------------------------------------- |
| `--repo`           | `-r`  | —           | Full repo name (`owner/repo`)                       |
| `--name`           | `-n`  | —           | Package name (repo becomes `<org>/vm2.<name>`)      |
| `--org`            | `-o`  | `vmelamed`  | GitHub owner/org (used with `--name`)               |
| `--visibility`     |       | `public`    | `public` or `private`                               |
| `--branch`         | `-b`  | `main`      | Branch to protect                                   |
| `--configure-only` |       | —           | Skip repo creation; configure existing repo only    |
| `--skip-secrets`   |       | —           | Skip setting repository secrets                     |
| `--skip-variables` |       | —           | Skip setting repository variables                   |
| `--audit`          |       | —           | Read-only: report current vs expected settings      |

Either `--repo` or `--name` is required (but not both).

See [CONFIGURATION.md — Repository Setup via UI](CONFIGURATION.md#repository-setup-via-ui) for the
equivalent manual steps.
