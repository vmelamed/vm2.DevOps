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
    - [set-secret.sh](#set-secretsh)
    - [update-packages.sh](#update-packagessh)
    - [Other Utilities](#other-utilities)
  - [3. CI Scripts](#3-ci-scripts)
    - [validate-commits.sh](#validate-commitssh)
    - [validate-input.sh](#validate-inputsh)
    - [build.sh](#buildsh)
    - [run-tests.sh](#run-testssh)
    - [run-benchmarks.sh](#run-benchmarkssh)
    - [pack.sh](#packsh)
    - [compute-release-version.sh](#compute-release-versionsh)
    - [compute-prerelease-version.sh](#compute-prerelease-versionsh)
    - [changelog-and-tag.sh](#changelog-and-tagsh)
    - [download-artifact.sh](#download-artifactsh)
    - [rebuild-bench-history.sh](#rebuild-bench-historysh)
    - [rebuild-bench-history-run.sh](#rebuild-bench-history-runsh)
    - [setup-repo.sh](#setup-reposh)

<!-- /TOC -->

vm2.DevOps contains three distinct categories of scripts:

1. **CI Scripts** — GitHub Actions scripts invoked by reusable workflows. Built on `gh_core.sh`.
1. **Utility Scripts** — Developer-facing tools for one-off chores. Built on `core.sh` directly.
1. **Bash Library** — Shared function library sourced by all scripts. The foundation layer.

## Sourcing Chains

    CI Scripts:          script.sh → gh_core.sh → core.sh → all _*.sh modules

    Utility Scripts:     script.sh ----------→ core.sh → all _*.sh modules

`core.sh` sources every component module directly, including the ones that used to be CI-only (`_sanitize.sh`,
`_dotnet.sh`, `_dotnet_args.sh`, `_git_vm2.sh`) — there is no longer a split between a "common" set sourced by
`core.sh` and a "CI-specific" set added on top by `gh_core.sh`. `gh_core.sh` now only sources `core.sh` and adds
GitHub Actions–specific environment variables (`GITHUB_ACTIONS`, `GITHUB_STEP_SUMMARY`, `GITHUB_OUTPUT`) and a
handful of functions on top: it overrides `to_stdout`/`to_stderr`/`to_output` to also write to the GitHub Actions
step summary/output files, and adds `gh_escape` and `args_to_github_output`.

### Common Switches

All scripts (CI and utility) inherit these switches from the bash library:

| Switch        | Short | Description                                               |
| :------------ | :---- | :-------------------------------------------------------- |
| `--verbose`   | `-v`  | Enable verbose output, tracing, and dump outputs          |
| `--trace`     | `-x`  | Verbose + bash `set -x`                                   |
| `--dry-run`   | `-y`  | Show commands without executing state-changing operations |
| `--quiet`     | `-q`  | Suppress interactive prompts (default in CI)              |
| `--graphical` | `-gr` | Dump tables in graphical format                           |
| `--markdown`  | `-md` | Dump tables in markdown format (default in CI)            |
| `--help`      |       | Long usage text including common switches                 |
|               | `-h`  | Short usage text                                          |

---

## 1. Bash Library

Located in **`scripts/bash/lib/`**. The foundation layer sourced by all scripts.

`core.sh` is the entry point — it sources every component module directly:

    core.sh
     ├── _constants.sh
     ├── _core_state.sh     (quiet/verbose/dry-run/trace state)
     ├── _error_codes.sh    (error code constants)
     ├── _predicates.sh     (boolean test functions)
     ├── _diagnostics.sh    (info, warning, error, trace)
     ├── _core_args.sh           (argument parsing, common switches, get_common_arg)
     ├── _semver.sh         (semver parsing, comparison, tag validation)
     ├── _sanitize.sh       (input sanitization: is_safe_reason, etc.)
     ├── _dump_vars.sh      (dump_vars for debugging)
     ├── _user.sh           (user/identity helpers)
     ├── _git.sh            (Git repository helpers)
     ├── _git_vm2.sh        (Git helpers specific to vm2 repos)
     ├── _dotnet_args.sh    (shared dotnet CLI argument parsing/defaults)
     └── _dotnet.sh         (.NET SDK helpers)

`gh_core.sh` only sources `core.sh` on top of that — it no longer adds any extra component modules — and then layers
GitHub Actions–specific environment variables and a handful of functions:

    gh_core.sh
     └── core.sh            (everything above)

See [FUNCTIONS_REFERENCE.md](../scripts/bash/lib/FUNCTIONS_REFERENCE.md) for the full list of library functions (the
library has grown past the `.gitmessage`/CLAUDE.md-era count of 67; see that document for the current total).

---

## 2. Utility Scripts

Located in **`scripts/bash/`**. Developer-facing tools for one-off chores. These source
`core.sh` directly (not `gh_core.sh`) and do not require the GitHub Actions environment.

They follow the same three-file pattern where applicable.

### diff-shared.sh

Compares a set of files from the repo `vm2.Templates` (the "source of truth") with the corresponding files in a target repository, and takes actions to keep them in sync based on the configuration or CLI parameters. Useful for keeping commonly shared files (config, settings, `Directory.*.props`, workflow files, etc.) in-sync across repositories provided the "source-of-truth" is up to data. The script assumes that the directories of the repositories `vm2.Templates` and the target repository are cloned under the same directory which may be defined by the environment variable `$VM2_REPOS` or given by the option `--vm2-repos`.

By default all files defined in the mandatory configuration file `diff-shared.config.json` are compared, but the user can modify that behavior by having an optional configuration file `diff-shared.custom.json` in the target repository or by providing CLI parameters to specify a subset of files and specific actions to compare.

The tool comprises of the following bash script files, expected to be in the same directory (usually `$VM2_REPOS/vm2.DevOps/scripts/bash/`):

- `diff-shared.sh` - the main script
- `diff-shared.args.sh` - implements parsing of the script arguments (sourced)
- `diff-shared.usage.sh` - provides the usage information (sourced)
- `diff-shared.functions.sh` - script with reusable bash functions (sourced)
- `diff-shared.config.json` - the mandatory global configuration file (rarely and centrally edited)

The script compares one by one the source and the target files using a configurable comparison (`diff`-like) tool. If the target
file is not found, or there are differences between the files, the tool takes an action depending on the configured, per-file
default action. Here is the list of available action names and the resulting behaviors:

| Action               | If the target file is different from the source:                    | If the target file does not exist: |
| :------------------- | :------------------------------------------------------------------ | :--------------------------------- |
| `ignore`             | does nothing                                                        | does nothing                       |
| `merge or copy`      | asks to copy, merge, or ignore                                      | asks to copy or ignore             |
| `ask to merge`       | asks to merge or ignore                                             | asks to copy or ignore             |
| `merge`              | merges source into target                                           | copies the file                    |
| `ask to copy`        | asks to copy or ignore                                              | asks to copy or ignore             |
| `copy`               | copies the file                                                     | copies the file                    |
| `copy shared`        | copies the shared block; merges instead if a marker is missing      | copies the whole file (bootstrap)  |
| `ask to copy shared` | asks to copy the shared block; asks to merge if a marker is missing | asks to copy or ignore             |

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
            "sourceFile": "$vm2_repos/$vm2_sot_shared/.editorconfig",
            "targetFile": "$target_repo_path/.editorconfig",
            "action": "copy"
          },
          {
            "sourceFile": "$vm2_repos/$vm2_sot_shared/.gitignore",
            "targetFile": "$target_repo_path/.gitignore",
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

| Option                                | Short   | Default      | Description                                                                              |
| :------------------------------------ | :------ | :----------- | :--------------------------------------------------------------------------------------- |
| `<repo-directory>...`                 |         | current dir  | Positional: one or more target repo names or paths to compare (repeatable)               |
| `--vm2-repos`                         | `-r`    | `$VM2_REPOS` | Parent directory of all repos                                                            |
| `--source-of-truth`                   | `-s`    | —            | The source-of-truth scenario to use (one of the scenarios in `vm2.Templates/templates/`) |
| `--file <pattern>`                    | `-f`    | all          | File name or quoted glob; repeatable; action taken from the configuration                |
| `--file-ignore <pattern>`             | `-fi`   | —            | Like `--file` but forces the action to `ignore`                                          |
| `--file-merge-or-copy <pattern>`      | `-fmc`  | —            | Like `--file` but forces the action to `merge or copy`                                   |
| `--file-ask-to-merge <pattern>`       | `-fam`  | —            | Like `--file` but forces the action to `ask to merge`                                    |
| `--file-merge <pattern>`              | `-fm`   | —            | Like `--file` but forces the action to `merge`                                           |
| `--file-ask-to-copy <pattern>`        | `-fac`  | —            | Like `--file` but forces the action to `ask to copy`                                     |
| `--file-copy <pattern>`               | `-fc`   | —            | Like `--file` but forces the action to `copy`                                            |
| `--file-copy-shared <pattern>`        | `-fcs`  | —            | Like `--file` but forces the action to `copy shared`                                     |
| `--file-ask-to-copy-shared <pattern>` | `-facs` | —            | Like `--file` but forces the action to `ask to copy shared`                              |
| `--summary <file>`                    |         | temp file    | Write the run summary to `<file>` in Markdown (shown and deleted if omitted)             |
| `--all-repos`                         | `-a`    | —            | Compare all pre-defined vm2 repositories under `$VM2_REPOS` (set in `_constants.sh`)     |
| `--diff`                              | `-d`    | —            | Compare and display differences only, taking no action                                   |
| `--current-branch`                    | `-cb`   | —            | Use the current branch of vm2.DevOps/the SoT repo instead of `main`                      |

There is no `--files` (comma-separated list) or `--minver-tag-prefix` option.

### move-commits-to-branch.sh

Moves commits from a specified SHA onward to a new branch, resetting main to the prior commit.

| Option            | Short | Description                             |
| :---------------- | :---- | :-------------------------------------- |
| `--commit-sha`    | `-c`  | SHA from which to move commits          |
| `--branch`        | `-b`  | New branch name                         |
| `--check-out-new` | `-n`  | Check out the new branch after the move |

### rename-branch.sh

Renames a branch in the Git repository and in the remote origin.

| Parameter                             | Description                                                                    |
| :------------------------------------ | :----------------------------------------------------------------------------- |
| `<new-branch-name>`                   | One positional argument: renames the currently checked-out branch to this name |
| `<old-branch-name> <new-branch-name>` | Two positional arguments: renames `<old-branch-name>` to `<new-branch-name>`   |

A third positional argument is an error.

### set-secret.sh

Creates or updates one repository secret for one GitHub application, in every vm2 repository (`$vm2_repositories`). It
prompts for the value once and reuses it for every repository. Before creating a secret that does not exist yet, it asks
for confirmation, separately for each repository. The value is not printed to the output.

```bash
set-secret.sh MY_SECRET --app actions
```

| Argument / option      | Short | Description                                                                  |
| :--------------------- | :---- | :--------------------------------------------------------------------------- |
| `<secret-name>`        | `-n`  | Name of the secret: a letter or underscore, then letters, digits, underscores |
| `--app <name>`         | `-a`  | GitHub application: `actions` (default), `dependabot`, or `codespaces`       |
| `--repo-owner <owner>` | `-o`  | Repository owner (default: `vmelamed`)                                       |
| `--dry-run`            | `-y`  | Show what would be set, without calling `gh secret set`                      |

**Auth:** the caller's `gh` login must be able to write secrets for the target application in each repository.

### update-packages.sh

Upgrades the NuGet package versions in `Directory.Packages.props` to the newest stable version found in the configured
NuGet sources (never a downgrade, never a prerelease). The shared block is upgraded in the SoT (`vm2.Templates`) first
and fanned out to the repositories with `diff-shared.sh`; each repository's own section is upgraded afterwards.

Versions are looked up with `dotnet package search <id> --exact-match --format json` against every source configured
in the local `NuGet.config` (nuget.org and `github.vm2`); a package found in more than one source takes the highest
stable version across all of them. Package IDs are matched case-insensitively (GitHub Packages returns them
lowercased), but the casing already in the file is kept when a version is rewritten. Versions are compared with SemVer
precedence (`scripts/bash/lib/_semver.sh`).

```bash
update-packages.sh
update-packages.sh --dry-run
update-packages.sh vm2.Ulid vm2.Glob
update-packages.sh --summary /tmp/update-packages.md
```

Before writing anything, every target repository is classified:

| Mode      | Condition                                                                            | Effect                                                                                                                                         |
| :-------- | :----------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| `publish` | on `main`, clean, identical to `origin/main`                                         | branch `deps/update-packages-<yyyy-mm-dd>` created, committed, and pushed; a PR is opened (`gh pr create`, or the existing open one is reused) |
| `inplace` | anything else (a feature branch, a dirty-but-pushed state, no `origin` remote, etc.) | the files are edited in the current branch; nothing is committed                                                                               |
| `skip`    | uncommitted changes exist                                                            | the repository is left completely untouched                                                                                                    |

Every `publish` or `inplace` repository has its `packages.lock.json` files deleted and regenerated with
`dotnet restore --force-evaluate` (they are generated, never hand-edited, so their previous state does not matter).
A `skip` repository bypasses this entirely, consistent with being left untouched. Only `publish` repositories are
committed and pushed.

| Option             | Description                                                                                                                                            |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<repository>...`  | One or more repository names (default: all vm2 repositories). Including `vm2.Templates` also upgrades the shared block in the SoT.                     |
| `--summary <file>` | Write the run's Markdown summary to `<file>`. If omitted, a temporary file is created, rendered (via `glow`, falling back to `cat`), and then deleted. |

The summary covers the package versions checked (current → new, or why not: already latest, prerelease only, not found
in any source, search failed), each repository's mode and status (including the opened PR's URL), and a per-phase
timing table.

### Other Utilities

| Script         | Purpose                                                                                                                                                              |
| :------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `add-spdx.sh`  | Add SPDX license headers to source files                                                                                                                             |
| `re-tag.sh`    | Recreate a Git tag at a different commit                                                                                                                             |
| `create-pr.sh` | `gh` alias (`gh create-pr`) — creates a PR with its body auto-populated from the commit list between the default branch and HEAD, merged into the repo's PR template |

## 3. CI Scripts

Located in **`.github/actions/scripts/`**. These are the scripts invoked by the reusable
workflows documented in [WORKFLOWS_REFERENCE.md](WORKFLOWS_REFERENCE.md). They require
the GitHub Actions environment and source `gh_core.sh`.

Each CI script follows a **three-file pattern**:

| File              | Purpose                         |
| :---------------- | :------------------------------ |
| `script.sh`       | Entry point — sources lib, runs |
| `script.usage.sh` | `--help` text                   |
| `script.args.sh`  | Argument parsing                |

---

### validate-commits.sh

Validates that all commit messages in a PR follow the [Conventional Commits](https://www.conventionalcommits.org/) format.
Only runs on `pull_request` events.

**Called by:** `_ci.yaml`

| Option       | Short | Default | Description                                     |
| :----------- | :---- | :------ | :---------------------------------------------- |
| `--base-ref` | `-b`  | —       | Git ref to compare against (e.g. `origin/main`) |

**Allowed types:** : `feat`, `fix`, `perf`, `security`, `doc`, `docs`, `deps`, `revert`, `remove`, `refactor`, `style`, `test`, `tests`, `ci`, `chore`

| Type:      | Use when:                                         | Bump:  |
| :--------- | :------------------------------------------------ | :----- |
| `!`        | Backwards incompatibility                         | major  |
| `feat`     | New feature                                       | minor  |
| `fix`      | Bug fix                                           | patch  |
| `perf`     | Performance improvement                           | patch  |
| `security` | Security fix or hardening                         | patch  |
| `doc(s)`   | Documentation only                                | patch  |
| `deps`     | Dependencies changes                              | patch  |
| `revert`   | Revert a previous commit                          | patch? |
| `remove`   | Remove feature or code                            | patch? |
| `refactor` | Code restructuring - no behavior change!          | patch? |
| `style`    | Formatting, whitespaces, etc. - no code change!   | n/a    |
| `test(s)`  | Adding or updating unit, integration, perf. tests | n/a    |
| `ci`       | Build and CI/CD related changes                   | n/a    |
| `chore`    | Insignificant build, tooling, config., etc.       | n/a    |

> [!NOTE]
> The type keywords are defined in the vm2.DevOps script: [vm2.DevOps/scripts/bash/lib/_constants.sh](../vm2.DevOps/scripts/bash/lib/_constants.sh) and should be kept in sync with:
>
> - [vm2.Templates/templates/AddNewPackage/content/.gitmessage](../vm2.Templates/templates/AddNewPackage/content/.gitmessage)
> - [vm2.Templates/changelog/cliff.prerelease.toml](../vm2.Templates/changelog/cliff.prerelease.toml)
> - [vm2.Templates/changelog/cliff.release-header.toml](../vm2.Templates/changelog/cliff.release-header.toml)

---

### validate-input.sh

Validates and normalizes all CI workflow inputs. Outputs them to `$GITHUB_OUTPUT` for
downstream jobs.

**Called by:** `_ci.yaml`

Among the common dotnet options, `--define` (`-d`), `--configuration` (`-c`), `--framework` (`-tfm`), and `--runtime`
(`-rid`) have short forms; `--minver-tag-prefix`, `--minver-prerelease-id`, and `--artifacts-path` are long-form only
(see `get_common_dotnet_arg()` in `scripts/bash/lib/_dotnet_args.sh`). There is no `--dotnet-version` option any more
-- the .NET SDK version comes from `global.json`, not a CI input.

| Option                         | Short  | Default             | Description                           |
| :----------------------------- | :----- | :------------------ | :------------------------------------ |
| `--build-projects`             | `-bp`  | auto-detect         | JSON array of project paths to build  |
| `--test-projects`              | `-tp`  | —                   | JSON array of test project paths      |
| `--benchmark-projects`         | `-bmp` | —                   | JSON array of benchmark project paths |
| `--package-projects`           | `-pp`  | —                   | JSON array of project paths to pack   |
| `--runners-os`                 | `-os`  | `["ubuntu-latest"]` | JSON array of runner OS monikers      |
| `--define`                     | `-d`   | `""`                | Preprocessor symbols                  |
| `--min-coverage-pct`           | `-min` | `80`                | Minimum code coverage (50–100)        |
| `--max-regression-pct`         | `-max` | `20`                | Maximum benchmark regression (0–50)   |
| `--max-gen1-collects`          | `-g1`  | `2`                 | Max Gen1 GC collections per 1000 ops  |
| `--max-gen2-collects`          | `-g2`  | `1`                 | Max Gen2 GC collections per 1000 ops  |
| `--minver-tag-prefix`          |        | `v`                 | MinVer tag prefix                     |
| `--minver-prerelease-id`       |        | `preview.0`         | MinVer pre-release identifiers        |
| `--reset-benchmark-thresholds` | `-rt`  | `false`             | Reset Bencher thresholds for this run |
| `--skip-build`                 | `-sb`  | `false`             | Skip the build job                    |
| `--skip-tests`                 | `-st`  | `false`             | Skip the test job                     |
| `--skip-benchmarks`            | `-sbm` | `false`             | Skip the benchmarks job               |
| `--skip-packages`              | `-sp`  | `false`             | Skip the pack job                     |

**Outputs:** All inputs echoed to `$GITHUB_OUTPUT` in `kebab-case` format.

---

### build.sh

Compiles a .NET project or solution.

**Called by:** `_build.yaml`

Among the common dotnet options, `--define` (`-d`) and `--configuration` (`-c`) have short forms; `--minver-tag-prefix`
and `--minver-prerelease-id` are long-form only.

| Option                   | Short | Default     | Description                    |
| :----------------------- | :---- | :---------- | :----------------------------- |
| `--build-project`        | `-bp` | auto-detect | Path to project/solution       |
| `--configuration`        | `-c`  | `Release`   | Build configuration            |
| `--define`               | `-d`  | `""`        | Preprocessor symbols           |
| `--minver-tag-prefix`    |       | `v`         | MinVer tag prefix              |
| `--minver-prerelease-id` |       | `preview.0` | MinVer pre-release identifiers |
| `--nuget-username`       |       | `$GH_ACTOR` | NuGet auth username            |
| `--nuget-password`       |       | `$GH_TOKEN` | NuGet auth token               |

`_build.yaml` currently invokes `build.sh` with only the project path and `--define`; the MinVer and Configuration
values are picked up from environment variables / `Directory.Build.props` rather than being passed explicitly.

---

### run-tests.sh

Runs tests and collects code coverage. Assumes project layout:
`<solution>/tests/<project>/<project>.csproj`.

**Called by:** `_test.yaml`

Among the common dotnet options, `--define` (`-d`) and `--configuration` (`-c`) have short forms; `--minver-tag-prefix`,
`--minver-prerelease-id`, and `--artifacts-path` are long-form only.

| Option                   | Short  | Default                               | Description                                                        |
| :----------------------- | :----- | :------------------------------------ | :----------------------------------------------------------------- |
| `<test-project-path>`    |        | `$TEST_PROJECT`                       | Positional: path to test project                                   |
| `--configuration`        | `-c`   | `Release`                             | Build configuration                                                |
| `--define`               | `-d`   | `""`                                  | Preprocessor symbols                                               |
| `--min-coverage-pct`     | `-min` | `80`                                  | Minimum coverage percentage (50–100)                               |
| `--minver-tag-prefix`    |        | `v`                                   | MinVer tag prefix                                                  |
| `--minver-prerelease-id` |        | `preview.0`                           | MinVer pre-release identifiers                                     |
| `--artifacts-path`       |        | resolved from `Directory.Build.props` | Artifacts output directory (there is no `--artifacts`/`-a` option) |

**Output:** `results-dir` → `$GITHUB_OUTPUT`

---

### run-benchmarks.sh

Runs BenchmarkDotNet benchmarks. Assumes layout:
`<solution>/benchmarks/<project>/<project>.csproj`.

**Called by:** `_benchmarks.yaml`

Among the common dotnet options, `--define` (`-d`) and `--configuration` (`-c`) have short forms; `--minver-tag-prefix`,
`--minver-prerelease-id`, and `--artifacts-path` are long-form only. There is no `--short-run`/`-s` option;
`SHORT_RUN` is applied via `--define SHORT_RUN` instead (see the push de-dupe logic in ARCHITECTURE.md).

| Option                   | Short  | Default                               | Description                           |
| :----------------------- | :----- | :------------------------------------ | :------------------------------------ |
| `<bm-project-path>`      |        | `$BENCHMARK_PROJECT`                  | Positional: path to benchmark project |
| `--configuration`        | `-c`   | `Release`                             | Build configuration                   |
| `--define`               | `-d`   | `""`                                  | Preprocessor symbols                  |
| `--max-regression-pct`   | `-max` | `20`                                  | Max regression percentage (0–50)      |
| `--minver-tag-prefix`    |        | `v`                                   | MinVer tag prefix                     |
| `--minver-prerelease-id` |        | `preview.0`                           | MinVer pre-release identifiers        |
| `--artifacts-path`       |        | resolved from `Directory.Build.props` | Artifacts output directory            |

**Output:** `results-dir` → `$GITHUB_OUTPUT`

---

### pack.sh

Validates that a project can be packed into a NuGet package (dry-run, no publish, unless `--build` is `true`).

**Called by:** `_pack.yaml`

The project path is a positional argument, not `--package-project`/`-pp`. Among the common dotnet options, `--define`
(`-d`) and `--configuration` (`-c`) have short forms; `--minver-tag-prefix` and `--minver-prerelease-id` are
long-form only.

| Option                   | Short | Default            | Description                                            |
| :----------------------- | :---- | :----------------- | :----------------------------------------------------- |
| `<package-project-path>` |       | `$PACKAGE_PROJECT` | Positional: path to the project to pack                |
| `--reason`               | `-r`  | `release build`    | Reason for release; recorded as a package release note |
| `--build`                | `-b`  | `false`            | Build the project before packing                       |
| `--configuration`        | `-c`  | `Release`          | Build configuration                                    |
| `--define`               | `-d`  | `""`               | Preprocessor symbols                                   |
| `--minver-tag-prefix`    |       | `v`                | MinVer tag prefix                                      |
| `--minver-prerelease-id` |       | `preview.0`        | MinVer pre-release identifiers                         |

`dotnet_pack()` resolves the project's `Configuration` MSBuild property itself when `--configuration` is not given,
since `dotnet pack` (unlike `dotnet build`/`dotnet msbuild`) defaults to `Release` on its own.

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

| Option                   | Short | Default      | Description                                        |
| :----------------------- | :---- | :----------- | :------------------------------------------------- |
| `--minver-tag-prefix`    | `-mp` | `v`          | MinVer tag prefix                                  |
| `--minver-prerelease-id` | `-mi` | `preview.0`  | MinVer pre-release identifiers (e.g., `preview.0`) |
| `--reason`               | `-r`  | `prerelease` | Reason for release                                 |

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

| Option                 | Short | Default       | Description                                                                                              |
| :--------------------- | :---- | :------------ | :------------------------------------------------------------------------------------------------------- |
| `--tag`                | `-t`  | —             | Tag to create (e.g., `v1.2.3` or `v1.3.0-preview.1`)                                                     |
| `--minver-tag-prefix`  | `-p`  | `v`           | MinVer tag prefix                                                                                        |
| `--reason`             | `-r`  | auto-detected | Reason (included in tag annotation); defaults based on tag type                                          |
| `--needs-empty-commit` |       | `false`       | `true` to create an empty commit before the changelog/tag (promoting a prerelease-tagged HEAD to stable) |

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

Workflow lookup priority: `--wf-id` > `--wf-name` > `--wf-path` (or the corresponding `WORKFLOW_ID`/`WORKFLOW_NAME`/
`WORKFLOW_PATH` env vars). A workflow ID, once known, is used as-is; otherwise the script resolves one from the name
or path via `gh workflow list`. Each `--wf-*` option clears the other two on the command line, so specifying more
than one keeps only the last one given.

---

### rebuild-bench-history.sh

Fan-out dispatcher: triggers each vm2 repo's `RebuildBenchHistory.yaml` to re-record its benchmark history to Bencher.dev.
Selects repos by probing for a `benchmarks/` directory via `gh api` (no clones), so it runs identically from a CLI and from a
workflow. Fire-and-forget — it dispatches the per-repo runs and returns.

**Called by:** `RebuildBenchHistory-AllRepos.yaml` (vm2.DevOps); also runnable directly from a CLI.

| Option       | Short | Default                              | Description                              |
| :----------- | :---- | :----------------------------------- | :--------------------------------------- |
| `--owner`    | `-o`  | `$GITHUB_REPOSITORY_OWNER` or remote | GitHub owner/org of the target repos     |
| `--repeat`   | `-n`  | `10`                                 | Independent runs to record per benchmark |
| `--workflow` | `-w`  | `RebuildBenchHistory.yaml`           | Per-repo workflow to dispatch            |

**Auth:** `$BENCH_DISPATCH_PAT` (exported as `GH_TOKEN`) with `Actions: write` + `Contents: read` on the target repos; falls
back to the ambient `gh auth`.

---

### rebuild-bench-history-run.sh

Per-repo run loop: discovers every benchmark project under `benchmarks/` (recursive, pruning
`bin`/`obj`/`BenchmarkDotNet.Artifacts`) and records each to Bencher.dev `--repeat` times. Record-only — no thresholds, no
`--err`, so a noisy point never fails the run.

**Called by:** `_rebuild_bench_history.yaml`

| Option                   | Short | Default              | Description                                        |
| :----------------------- | :---- | :------------------- | :------------------------------------------------- |
| `<bm-project-path>`      |       | `$BENCHMARK_PROJECT` | Positional: one project (else discover all)        |
| `--repeat`               | `-n`  | `10`                 | Independent runs to record per benchmark           |
| `--define`               | `-d`  | `""`                 | Preprocessor symbols (empty = full, non-SHORT_RUN) |
| `--minver-tag-prefix`    | `-mp` | `v`                  | MinVer tag prefix                                  |
| `--minver-prerelease-id` | `-mi` | `preview.0`          | MinVer pre-release identifiers                     |
| `--bencher-project`      | `-bp` | `$BENCHER_PROJECT`   | Bencher project slug (required)                    |
| `--bencher-testbed`      | `-tb` | `$BENCHER_TESTBED`   | Bencher testbed (required)                         |
| `--bencher-branch`       | `-br` | `main`               | Bencher branch to record to                        |
| `--bencher-adapter`      | `-ad` | `c_sharp_dot_net`    | Bencher adapter                                    |

There is no `--configuration`/`-c` or `--artifacts`/`-a` option: this script does not take a Configuration override,
and the artifacts path is resolved internally via `get_artifacts_path` from the project's own `Directory.Build.props`.

**Auth:** `$BENCHER_API_TOKEN` (required).

---

### setup-repo.sh

Bootstraps and configures a vm2 package repository using the GitHub CLI. Creates the repo,
sets secrets/variables, configures repo settings, Actions permissions, and branch protection.

**Requires:** `gh` (authenticated), `jq`

| Option                  | Short  | Default      | Description                                                                                                             |
| :---------------------- | :----- | :----------- | :---------------------------------------------------------------------------------------------------------------------- |
| `<repo-directory>`      |        | current dir  | Positional: path to the git repository's working tree                                                                   |
| `--vm2-repos`           |        | `$VM2_REPOS` | Path to the directory containing all vm2 repositories                                                                   |
| `--owner`               | `-o`   | `vmelamed`   | GitHub owner/org for the repository                                                                                     |
| `--repo-name`           | `-n`   |              | The name of the GitHub repository (prompted interactively if omitted)                                                   |
| `--branch`              | `-b`   | `main`       | GitHub default branch                                                                                                   |
| `--visibility`          |        | `public`     | `public` or `private`                                                                                                   |
| `--ruleset-name`        | `-rs`  |              | The name of the ruleset for protecting the default branch                                                               |
| `--description`         |        |              | Short description for the GitHub repository (max 350 chars)                                                             |
| `--ssh`                 | `-s`   | true         | Use SSH for the remote origin (mutually exclusive with `--https`)                                                       |
| `--https`               | `-t`   | false        | Use HTTPS for the remote origin                                                                                         |
| `--interactive-vars`    | `-iv`  | false        | Prompt interactively for repository variable values instead of using defaults                                           |
| `--interactive-secrets` | `-is`  | false        | Prompt interactively for repository secret values instead of placeholders                                               |
| `--interactive`         | `-i`   | false        | Shortcut for `--interactive-vars` + `--interactive-secrets`                                                             |
| `--purge-vars`          | `-pv`  | false        | Delete unknown or obsolete repository variables                                                                         |
| `--purge-secrets`       | `-ps`  | false        | Delete unknown or obsolete repository secrets                                                                           |
| `--purge`               | `-p`   | false        | Shortcut for `--purge-vars` + `--purge-secrets`                                                                         |
| `--skip-local-config`   | `-slc` | false        | Skip configuring local Git settings                                                                                     |
| `--audit`               | `-a`   | false        | Read-only: report current vs expected settings, variables, secrets (now also reports unknown/obsolete vars and secrets) |
| `--current-branch`      | `-cb`  | false        | Use the current branch of vm2.DevOps/the SoT repo instead of `main`                                                     |

`--audit` is mutually exclusive with `--interactive-vars`, `--interactive-secrets`, `--interactive`, `--purge-vars`,
`--purge-secrets`, and `--purge`. There is no `--repo`, `--name` (long form of `-n` is `--repo-name`), or
`--force-defaults`/`-f` option any more; the latter's force-assign-defaults behavior is now covered by running
without `--interactive-vars`/`--interactive-secrets`.

See [CONFIGURATION.md — Repository Setup via UI](CONFIGURATION.md#repository-setup-via-ui) for the
equivalent manual steps.
