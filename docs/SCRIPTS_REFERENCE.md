# Scripts Reference

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Scripts Reference](#scripts-reference)
  - [Sourcing Chains](#sourcing-chains)
    - [Common Switches](#common-switches)
  - [1. Bash Library](#1-bash-library)
  - [2. Utility Scripts](#2-utility-scripts)
    - [diff-shared.sh](#diff-sharedsh)
    - [move-commits-to-branch.sh](#move-commits-to-branchsh)
    - [rename-branch.sh](#rename-branchsh)
    - [Other Utilities](#other-utilities)
  - [3. CI Scripts](#3-ci-scripts)
    - [validate-commits.sh](#validate-commitssh)
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
    - [repo-setup.sh](#repo-setupsh)

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

### diff-shared.sh

Compares pre-defined set of files from the "source-of-truth" directories (cloned repositories `vm2.DevOps` and `.github`) with
the corresponding files in a target directory. Useful for keeping common files (config, settings, `Directory.*.props`, workflow
files, etc.) in-sync across repositories. The script assumes that the repositories `vm2.DevOps` and `.github` are in the same
directory which may be defined by the environment variable `$VM2_REPOS` or given by the option `--vm2-repos`

The tool comprises of the following files, expected to be in the same directory:

- `diff-shared.sh` - the main script
- `diff-shared.args.sh` - script arguments parsing (sourced)
- `diff-shared.usage.sh` - script usage information (sourced)
- `diff-shared.functions.sh` - script with reusable bash functions (sourced)
- `diff-shared.config.json` - mandatory global configuration file

The script compares one by one the source and the target files using a configurable comparison (`diff`-like) tool. If the target
file is not found, or there are differences between the files, the tool takes an action depending on the configured, per-file
default action. Here is the list of available action names and the resulting behaviors:

| Action          | If the target file is different from the source: | If the target file does not exist: |
|-----------------|--------------------------------------------------|------------------------------------|
| `ignore`        | does nothing                                     | does nothing                       |
| `merge or copy` | asks to copy, merge, or ignore                   | asks to copy or ignore             |
| `ask to merge`  | asks to merge or ignore                          | asks to copy or ignore             |
| `merge`         | merges source into target                        | copies the file                    |
| `ask to copy`   | asks to copy or ignore                           | asks to copy or ignore             |
| `copy`          | copies the file                                  | copies the file                    |

The script uses two configuration files with two different JSON formats:

- a **mandatory** global configuration file `diff-shared.config.json` from the directory of the the script files. It defines
  the two sets of files and the corresponding action if they differ, e.g.:

      ```json
      {
        "diff": {
          "tool": "delta",
          "command": "delta --side-by-side --line-numbers --paging never \"$LOCAL\" \"$REMOTE\""
        },
        "merge": {
          "tool": "code",
          "command": "code --new-window --wait --diff \"$REMOTE\" \"$LOCAL\" \"$REMOTE\" \"$LOCAL\""
        },
        "files": [
          {
            "sourceFile": "${vm2_repos}/vm2.DevOps/solution/.editorconfig",
            "targetFile": "${target_path}/.editorconfig",
            "action": "copy"
          },
          {
            "sourceFile": "${vm2_repos}/vm2.DevOps/solution/.gitignore",
            "targetFile": "${target_path}/.gitignore",
            "action": "copy"
          },
          ...
        ]
      }
      ```

- an **optional** configuration file `diff-shared.custom.json` from the directory of the target files, e.g.:

      ```json
      {
        "diff": {
          "tool": "delta",
          "command": "delta --side-by-side --line-numbers --paging never \"$LOCAL\" \"$REMOTE\""
        },
        "merge": {
          "tool": "code",
          "command": "code --new-window --wait --diff \"$REMOTE\" \"$LOCAL\" \"$REMOTE\" \"$LOCAL\""
        },
        "action_overrides": {
          ".editorconfig": "copy",
          ".gitattributes": "copy",
          ...
        }
      }
      ```

As you can see the custom config file allows overriding the actions in the `diff-shared.config.json` file for specific file
names.

Both files optionally define a comparison (`diff`-like) tool and a `merge`-like tool. If they are not specified explicitly the
tools picks the tools configured in the Git global configuration (e.g. `git config --global --get diff.tool`). If they are not
configured the tool assumes some default actions. The tools are picked in a priority order from highest to lowest:

1. Defined in `diff-shared.custom.json` from the target directory
1. Defined in `diff-shared.config.json` from the directory of the `diff-shared.sh` script
1. Git global configuration
1. Default tools (diff: `delta` if installed or `diff`, merge: `Visual Studio Code`)

> [!NOTE] The tools `Visual Studio Code` and `meld` do not behave well for the purpose of the compare operation in this script,
> therefore they are ignored. But they can be used for merge.

> [!TIP] For comparison we recommend the `delta` tool.

The property `files` in the mandatory `diff-shared.config.json` file defines the set of source files, and corresponding target
files and actions to take if the source and the target are different.

**Command Line Options:**

| Option                      | Short | Default      | Description                              |
| :-------------------------- | :---- | :----------- | :--------------------------------------- |
| `<repository-name-or-path>` |       | current dir  | Positional: repo name or path to compare |
| `--vm2-repos`               | `-r`  | `$VM2_REPOS` | Parent directory of all repos            |
| `--files`                   | `-f`  | all          | Comma-separated list of files or regex   |
| `--minver-tag-prefix`       | `-mp` | `v`          | Tag prefix for detecting stable versions |

### move-commits-to-branch.sh

Moves commits from a specified SHA onward to a new branch, resetting main to the prior commit.

| Option            | Short | Description                             |
| :---------------- | :---- | :-------------------------------------- |
| `--commit-sha`    | `-c`  | SHA from which to move commits          |
| `--branch`        | `-b`  | New branch name                         |
| `--check-out-new` | `-n`  | Check out the new branch after the move |

### rename-branch.sh

Renames a branch in the Git repository and in the remote origin.

| Parameter:              | Description                       |
|-------------------------|-----------------------------------|
| `<current branch name>` | Positional 1: Current branch name |
| `<new branch name>`     | Positional 2: New branch name     |

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
| `script.args.sh`   | Argument parsing                |

---

### validate-commits.sh

Validates that all commit messages in a PR follow the [Conventional Commits](https://www.conventionalcommits.org/) format.
Only runs on `pull_request` events.

**Called by:** `_ci.yaml`

| Option         | Short | Default | Description                              |
| :------------- | :---- | :------ | :--------------------------------------- |
| `--base-ref`   | `-b`  | —       | Git ref to compare against (e.g. `origin/main`) |

**Allowed types:** `feat` `fix` `perf` `refactor` `docs` `style` `test` `chore` `revert` `remove` `security` `build` `ci`

Merge commits and `Revert` commits are automatically skipped.

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
| `--nuget-username`       |       | `$GH_ACTOR`     | NuGet auth username            |
| `--nuget-password`       |       | `$GH_TOKEN`     | NuGet auth token               |

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
| `--tag`               | `-t`  | —                | Tag to create (e.g., `v1.2.3` or `v1.3.0-preview.1`)             |
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

### repo-setup.sh

Bootstraps and configures a vm2 package repository using the GitHub CLI. Creates the repo,
sets secrets/variables, configures repo settings, Actions permissions, and branch protection.

**Requires:** `gh` (authenticated), `jq`

| Option             | Short | Default     | Description                                                        |
| :----------------- | :---- | :---------- | :----------------------------------------------------------------- |
| parameter          |       | current dir | Path to the git repository root of working tree                    |
| `--vm2-repos`      |       | `$VM2_REPOS`| Path to the directory containing all vm2 repositories              |
| `--owner`          | `-o`  | `vmelamed`  | GitHub owner/org (used with `--name`)                              |
| `--repo-name`      | `-n`  |             | The name of the GitHub repository                                  |
| `--branch`         | `-b`  | `main`      | GitHub default branch                                              |
| `--visibility`     |       | `public`    | `public` or `private`                                              |
| `--ruleset-name`   | `-rs` |             | The name of the ruleset for protecting the default branch          |
| `--description`    | `-d`  |             | Short description for the GitHub repository (max 350 chars)        |
| `--ssh`            | `-s`  | true        | Use SSH URL for the remote origin                                  |
| `--https`          | `-t`  | false       | Use HTTPS URL for the remote origin                                |
| `--force-defaults` | `-f`  | false       | If the value of a repository variable is different from the default, assign it the default, without prompting for confirmation |
| `--audit`          |       | —           | Read-only: report current vs expected settings, variables, secrets |

Either `--repo` or `--name` is required (but not both).

See [CONFIGURATION.md — Repository Setup via UI](CONFIGURATION.md#repository-setup-via-ui) for the
equivalent manual steps.
