# CLAUDE.md

@~/.claude/CLAUDE.md
@~/repos/vm2/CLAUDE.md
@.github/CONVENTIONS.md

Additional references:

@docs/ARCHITECTURE.md
@docs/WORKFLOWS_REFERENCE.md
@docs/GIT_PLAYBOOK.md
@docs/RELEASE_PROCESS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

Val is currently the only developer on this project. There is no team. This affects prioritization (correctness still matters; urgency and process overhead do not).

## What This Repository Is

vm2.DevOps is the shared CI/CD automation framework for all vm2 .NET packages. It provides:

- **Reusable GitHub Actions workflows** — consumed by every vm2 package repo
- **Bash script library** — 67 functions in `scripts/bash/lib/`, sourced by CI scripts and local utilities
- **CI/CD action scripts** — in `.github/scripts/`, each following the three-file convention

Consumer repos use workflow templates from `vm2.Templates`. The reusable workflows and the scripts they call live here.

## Architecture

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
                                   └──► _pack.yaml ────────► pack.sh ───────────────────────►

Prerelease.yaml ───────► _prerelease.yaml ───────────────┬─► compute-prerelease-version.sh ─►
                                                         ├─► changelog-and-tag.sh ──────────►
                                                         └─► publish-package.sh ────────────►

Release.yaml ──────────► _release.yaml ──────────────────┬─► compute-release-version.sh ────►
                                                         ├─► changelog-and-tag.sh ──────────►
                                                         └─► publish-package.sh ────────────►

```

See `docs/ARCHITECTURE.md` for the full design and `docs/WORKFLOWS_REFERENCE.md` for workflow inputs/outputs.

## Key Directories

| Path                   | Contents                                                             |
|------------------------|----------------------------------------------------------------------|
| `.github/workflows/`   | Reusable workflows (`_ci.yaml`, `_build.yaml`, `_test.yaml`, etc.)   |
| `.github/scripts/`     | CI/CD action scripts (three-file convention — see below)             |
| `.github/actions/`     | Custom composite actions (`setup-env`, `cache-dependencies`, etc.)   |
| `scripts/bash/lib/`    | Shared bash library (`_diagnostics.sh`, `_git.sh`, `_args.sh`, etc.) |
| `scripts/bash/`        | Local dev utility scripts (`diff-shared.sh`, `setup-repo.sh`, etc.)  |
| `docs/`                | Reference documentation (12 `.md` files)                             |

## Common Local Commands

```bash
# Sync shared files from vm2.Templates canonical source
./scripts/bash/diff-shared.sh

# Audit and initialize repository configuration
./scripts/bash/setup-repo.sh

# Create a PR with vm2 conventions
./scripts/bash/gh-create-pr.sh
```

ShellCheck runs live in VSCode via the ShellCheck extension — do not run it from the CLI.

## Script Filenames Base Convention: `<action>-<target>`

The first part of the script (`script`) should follow the convention <action>-<target> (or <verb>-<noun>), where `<action>` describes the action the script performs and `<target>` describes the target or context of the action. For example, `setup-repo*.sh` for a script that sets up the repository or `diff-shared*.sh` for the script that compares files with shared content between the canonical source and the local repository.

## Three-File Script Convention

Every CI/CD script in `.github/scripts/` should consist of three files:

```text
action-target.sh        # Main executable — processes args, calls library functions
action-target.usage.sh  # Help/usage text
action-target.args.sh   # Argument parser — maps CLI args to script variables
```

New scripts should follow the pattern: `*.usage.sh` and `*.args.sh` and should implement the boilerplate code for input and help text. Source `gh_core.sh` at the top for GitHub Actions integration.

## Bash Library

All core library files live in `scripts/bash/lib/` and are sourced by scripts that need them:

| File              | Purpose                                                          |
|-------------------|------------------------------------------------------------------|
| `core.sh`         | Initialization, trap handlers                                    |
| `gh_core.sh`      | GitHub Actions environment integration                           |
| `_args.sh`        | Argument parsing (quiet, verbose, dry-run, trace modes)          |
| `_diagnostics.sh` | Logging (`to_stdout`, `error`, `warning`, `trace`, etc.)         |
| `_sanitize.sh`    | Input validation (`is_safe_path`, `is_safe_configuration`, etc.) |
| `_git.sh`         | Git operations                                                   |
| `_git_vm2.sh`     | Git operations with focus on vm2 repos                           |
| `_semver.sh`      | Semantic versioning utilities                                    |
| `_predicates.sh`  | Boolean checks (`is_array`, `is_positive`, etc.)                 |
| `_error_codes.sh` | Error code constants                                             |
| `_constants.sh`   | ANSI color codes and a few other constants                       |
| `_dotnet.sh`      | Manages the output of `dotnet build` command                     |
| `_dump_vars.sh`   | Dumps the values of bash variables in a tabular format           |
| `_user.sh`        | User interface primitives                                        |

See `scripts/bash/lib/FUNCTIONS_REFERENCE.md` for the full function inventory.

## Shared File Sync

Files that are canonical in `vm2.Templates` (`.editorconfig`, `.github/CONVENTIONS.md`, `Directory.Build.props`, etc.) are synced here via `diff-shared.sh`. The mapping is in `scripts/bash/diff-shared.config.json`.

**Do not edit synced files directly** without also updating the canonical source in `vm2.Templates`.

## Documentation Reference

| File                          | Covers                                           |
|-------------------------------|--------------------------------------------------|
| `docs/CONSUMER_GUIDE.md`      | Integrating vm2.DevOps into a consumer repo      |
| `docs/ARCHITECTURE.md`        | Detailed workflow and script design              |
| `docs/WORKFLOWS_REFERENCE.md` | All reusable workflows: inputs, outputs, secrets |
| `docs/SCRIPTS_REFERENCE.md`   | CI/CD scripts: args and behavior                 |
| `docs/CONFIGURATION.md`       | Required repository variables and secrets        |
| `docs/RELEASE_PROCESS.md`     | MinVer versioning, prerelease and stable flows   |
| `docs/DEVELOPER_WORKFLOW.md`  | Conventional Commits, PR process                 |
| `docs/GIT_PLAYBOOK.md`        | Rebase-first workflow and git operations         |
| `docs/ERROR_RECOVERY.md`      | Failure scenarios and recovery runbooks          |
