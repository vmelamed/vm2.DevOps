# vm2.DevOps

Reusable GitHub Actions workflows and bash automation scripts for building, testing, benchmarking,
packaging, and releasing .NET NuGet packages.

## Overview

vm2.DevOps provides a complete CI/CD automation toolkit for .NET solutions:

1. **Reusable GitHub Actions workflows** — build, test, benchmark, pack, prerelease, and release
1. **Bash script library** — 67 functions for local development and CI pipelines
1. **Workflow templates** — starter workflows for consumer repositories

### Relationship with the `.github` Repository

GitHub requires that organization-level workflow templates live in a repository named
[`.github`](https://github.com/vmelamed/.github). Because of this constraint, the consumer-facing
**workflow templates** (CI, Prerelease, Release, ClearCache, dependabot) are maintained in
[vmelamed/.github/workflow-templates](https://github.com/vmelamed/.github/tree/main/workflow-templates),
while the **reusable workflows** and **scripts** they call live here in vm2.DevOps. Logically, these
two repositories form a single system — `.github` is the distribution surface, vm2.DevOps is the
implementation.

## Architecture

The automation is organized in three layers. Each consumer repository contains a thin top-level
workflow that gathers inputs and delegates to the reusable layer:

    Consumer repo                    vm2.DevOps                          vm2.DevOps
    (top-level workflows)            (reusable workflows)                (bash scripts)
    ─────────────────────            ────────────────────                ──────────────

    CI.yaml ──────────────┐
    Prerelease.yaml ──────┤
    Release.yaml ─────────┤
    ClearCache.yaml ──────┤
                          │
                          ▼
                     _ci.yaml ──────────► _build.yaml ──────────────────► build.sh
                          │               _test.yaml ───────────────────► run-tests.sh
                          │               _benchmarks.yaml ─────────────► run-benchmarks.sh
                          │               _pack.yaml ───────────────────► pack.sh
                          │
                     _prerelease.yaml ──────────────────────────────────► compute-release-version.sh
                          │                                               changelog-and-tag.sh
                          │                                               publish-package.sh
                          │
                     _release.yaml ─────────────────────────────────────► compute-release-version.sh
                          │                                               changelog-and-tag.sh
                          │                                               publish-package.sh
                          │
                     _clear_cache.yaml

**Layer 1 — Consumer workflows** (in each repo's `.github/workflows/`):
Created from [workflow templates](https://github.com/vmelamed/.github/tree/main/workflow-templates)
or via `dotnet new vm2pkg`. These gather inputs from repository variables, secrets, and
`workflow_dispatch` UI, then pass them to Layer 2.

**Layer 2 — Reusable workflows** (in `vm2.DevOps/.github/workflows/`):
Orchestrate the CI/CD pipeline. `_ci.yaml` validates inputs and fans out to `_build.yaml`,
`_test.yaml`, `_benchmarks.yaml`, and `_pack.yaml` using matrix strategies. `_prerelease.yaml`
and `_release.yaml` handle package publishing.

**Layer 3 — Bash scripts** (in `vm2.DevOps/.github/actions/scripts/`):
Each script follows a three-file convention: `script.sh` (main), `script.usage.sh` (help text),
`script.utils.sh` (argument parsing). Scripts source the shared library from
`scripts/bash/lib/` for common behavior.

## Getting Started

For detailed setup instructions, see the [Consumer Guide](docs/CONSUMER_GUIDE.md).

**Quick start:**

1. Create a new repository for your .NET project
1. Configure repository [variables and secrets](docs/CONFIGURATION.md)
1. Copy workflow templates from
   [vmelamed/.github/workflow-templates](https://github.com/vmelamed/.github/tree/main/workflow-templates)
1. Customize the workflows for your project structure

Or use the dotnet template:

1. Install the template: `dotnet new install vm2.Templates`
1. Scaffold a project: `dotnet new vm2pkg --name YourPackage`
1. Run the bootstrap script to create the GitHub repository with all settings configured

## Naming Conventions

Inputs flow through layers with consistent name transformations:

| Layer                      | Format               | Example            |
|----------------------------|----------------------|--------------------|
| GitHub variables / secrets | `UPPER_SNAKE_CASE`   | `DOTNET_VERSION`   |
| Workflow inputs            | `lower-kebab-case`   | `dotnet-version`   |
| Script parameters          | `--lower-kebab-case` | `--dotnet-version` |
| Script variables           | `lower_snake_case`   | `dotnet_version`   |
| GitHub outputs             | `lower-kebab-case`   | `dotnet-version`   |

## Documentation

| Document                                                           | Description                                                   |
| ------------------------------------------------------------------ | ------------------------------------------------------------- |
| [Consumer Guide](docs/CONSUMER_GUIDE.md)                           | How to integrate vm2.DevOps into your repository              |
| [Architecture](docs/ARCHITECTURE.md)                               | Detailed design of workflows, scripts, and library            |
| [Workflows Reference](docs/WORKFLOWS_REFERENCE.md)                 | All reusable workflows with inputs, outputs, and secrets      |
| [Scripts Reference](docs/SCRIPTS_REFERENCE.md)                     | CI/CD action scripts (build, test, benchmark, pack, publish)  |
| [Bash Library Reference](scripts/bash/lib/FUNCTIONS_REFERENCE.md)  | All 67 shared bash library functions                          |
| [Configuration](docs/CONFIGURATION.md)                             | Repository variables, secrets, and branch protection setup    |
| [Release Process](docs/RELEASE_PROCESS.md)                         | Versioning with MinVer, prerelease and stable release flows   |
| [Cache Management](docs/CACHE_MANAGEMENT.md)                       | NuGet dependency caching strategy                             |
| [Error Recovery](docs/ERROR_RECOVERY.md)                           | Runbook for common failure scenarios                          |

## Additional Notes

1. All workflows default to .NET 10.0.x; override via the `DOTNET_VERSION` repository variable.
1. Scripts rely on `bash` and standard GNU utilities on Ubuntu GitHub-hosted runners. Additional
   tools (`jq`, `reportgenerator`) are installed on demand.
1. When adding new scripts, follow the three-file convention and keep code ShellCheck-clean.
