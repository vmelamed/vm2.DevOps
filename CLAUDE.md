# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@~/.claude/CLAUDE.md
@~/repos/vm2/CLAUDE.md
@.github/CONVENTIONS.md

## Project Context

This is a solo project — Val Melamed is currently the only developer. There is no team. This affects prioritization (correctness still matters; urgency and process overhead do not).

## What This Repository Is

vm2.DevOps is the shared CI/CD automation framework for all vm2 .NET packages. It provides:

- **Reusable GitHub Actions workflows** — consumed by every vm2 package repo
- **Bash script library** — 67 functions in `scripts/bash/lib/`, sourced by CI scripts and local utilities
- **CI/CD action scripts** — in `.github/scripts/`, each following the three-file convention

Consumer repos use workflow templates from `vm2.Templates`. The reusable workflows and the scripts they call live here.

## Architecture

Three-layer design:

    Consumer repo                   vm2.DevOps                         vm2.DevOps
    (top-level workflows)           (reusable workflows)               (bash scripts)
    ─────────────────────           ────────────────────               ──────────────
    CI.yaml ─────────────┐
    Prerelease.yaml ─────┤
    Release.yaml ─────────┤          _ci.yaml ──────► _build.yaml ──► build.sh
                          └────────►              ──► _test.yaml ───► run-tests.sh
                                              ──► _benchmarks.yaml ─► run-benchmarks.sh
                                              ──► _pack.yaml ───────► pack.sh
                                    _prerelease.yaml ───────────────► compute-release-version.sh
                                    _release.yaml ──────────────────► changelog-and-tag.sh
                                                                       publish-package.sh

See `docs/ARCHITECTURE.md` for the full design and `docs/WORKFLOWS_REFERENCE.md` for workflow inputs/outputs.

## Key Directories

| Path | Contents |
|------|----------|
| `.github/workflows/` | Reusable workflows (`_ci.yaml`, `_build.yaml`, `_test.yaml`, etc.) |
| `.github/scripts/` | CI/CD action scripts (three-file convention — see below) |
| `.github/actions/` | Custom composite actions (`setup-env`, `cache-dependencies`, etc.) |
| `scripts/bash/lib/` | Shared bash library (`_diagnostics.sh`, `_git.sh`, `_args.sh`, etc.) |
| `scripts/bash/` | Local dev utility scripts (`diff-shared.sh`, `repo-setup.sh`, etc.) |
| `docs/` | Reference documentation (12 `.md` files) |

## Common Local Commands

```bash
# Sync shared files from vm2.Templates canonical source
./scripts/bash/diff-shared.sh

# Audit and initialize repository configuration
./scripts/bash/repo-setup.sh

# Create a PR with vm2 conventions
./scripts/bash/gh-pr-create.sh
```

ShellCheck runs live in VSCode via the ShellCheck extension — do not run it from the CLI.

## Three-File Script Convention

Every CI/CD script in `.github/scripts/` consists of three files:

```
script.sh        # Main executable — processes args, calls library functions
script.usage.sh  # Help/usage text
script.args.sh   # Argument parser — maps CLI args to script variables
```

New scripts must follow this pattern. Source `gh_core.sh` at the top for GitHub Actions integration.

## Bash Library

All library files live in `scripts/bash/lib/` and are sourced by scripts that need them:

| File | Purpose |
|------|---------|
| `core.sh` | Initialization, trap handlers |
| `gh_core.sh` | GitHub Actions environment integration |
| `_args.sh` | Argument parsing (quiet, verbose, dry-run, trace modes) |
| `_diagnostics.sh` | Logging (`to_stdout`, `error`, `warning`, `trace`, etc.) |
| `_sanitize.sh` | Input validation (`is_safe_path`, `is_safe_configuration`, etc.) |
| `_git.sh` | Git operations |
| `_semver.sh` | Semantic versioning utilities |
| `_predicates.sh` | Boolean checks (`is_release`, `is_prerelease`, etc.) |
| `_error_codes.sh` | Error code constants |
| `_constants.sh` | ANSI color codes |

See `scripts/bash/lib/FUNCTIONS_REFERENCE.md` for the full function inventory.

## Shared File Sync

Files that are canonical in `vm2.Templates` (`.editorconfig`, `.github/CONVENTIONS.md`, `Directory.Build.props`, etc.) are synced here via `diff-shared.sh`. The mapping is in `scripts/bash/diff-shared.config.json`.

**Do not edit synced files directly** without also updating the canonical source in `vm2.Templates`.

## Writing and Documentation Conventions

When generating complete Markdown (`.md`) files, wrap the entire content in tilde fences and use 4-space indentation for code blocks inside (avoids nested backtick conflicts):

    ~~~markdown
    # Title

    ## Section

        command --flag value

    ~~~

Use `1.` for every item in ordered lists — renderers number them automatically.

Always check and correct spelling, grammar, and technical English style. Prefer active voice. Explain why suggested changes are better.

## Git and PR Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) — see `docs/DEVELOPER_WORKFLOW.md`
- PR description: What / Why / How / Risk / Rollback
- One logical concern per PR

## Documentation Reference

| File | Covers |
|------|--------|
| `docs/CONSUMER_GUIDE.md` | Integrating vm2.DevOps into a consumer repo |
| `docs/ARCHITECTURE.md` | Detailed workflow and script design |
| `docs/WORKFLOWS_REFERENCE.md` | All reusable workflows: inputs, outputs, secrets |
| `docs/SCRIPTS_REFERENCE.md` | CI/CD scripts: args and behavior |
| `docs/CONFIGURATION.md` | Required repository variables and secrets |
| `docs/RELEASE_PROCESS.md` | MinVer versioning, prerelease and stable flows |
| `docs/DEVELOPER_WORKFLOW.md` | Conventional Commits, PR process |
| `docs/GIT_PLAYBOOK.md` | Rebase-first workflow and git operations |
| `docs/ERROR_RECOVERY.md` | Failure scenarios and recovery runbooks |
