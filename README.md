# vm2.DevOps

Reusable GitHub Actions workflows and automation scripts for .NET projects.

## Overview

This repository provides a complete CI/CD automation toolkit for .NET solutions, including:

- **Reusable GitHub Actions workflows** for building, testing, benchmarking, and releasing .NET packages
- **[Workflow templates](https://github.com/vmelamed/.github/tree/main/workflow-templates)** available from the [`.github`](https://github.com/vmelamed/.github) organization repository
- **Bash automation scripts** for local development and CI/CD pipelines
- **Standardized release processes** using MinVer for semantic versioning
- **Code coverage enforcement** with customizable thresholds
- **Performance regression detection** using BenchmarkDotNet
- **NuGet package publishing** to both NuGet.org and GitHub Packages

## Getting Started

For detailed setup instructions, see the [Consumer Guide](docs/CONSUMER_GUIDE.md).

**Quick Start:**

1. Copy workflow templates from [vmelamed/.github/workflow-templates](https://github.com/vmelamed/.github/tree/main/workflow-templates)
2. Configure repository variables (DOTNET_VERSION, MIN_COVERAGE_PCT, etc.)
3. Set up secrets (NUGET_API_KEY, CODECOV_TOKEN, etc.)
4. Customize the workflows for your project structure

## High-level reusable workflows

These top-level workflows are intended to be called directly via `workflow_call` from dependent repositories. They orchestrate the full CI/CD pipeline, and fan out to lower-level building blocks - reusable workflows and bash scripts as needed. The workflows and scripts share a common input surface to make it easy to toggle behavior across the pipeline:

- Common switches for all bash scripts:
  - `help`: If `true`, scripts will display usage information and exit (default: `false`)
  - `debugger`:  Set when the a script is running under a debugger, e.g. 'gdb'. If specified, the script will not set traps for DEBUG and EXIT, and will set the '--quiet' switch. (default: `false`)
  - `dry-run`: If `true`, scripts will simulate actions without making changes (default: `false`)
  - `quiet`: If `true`, scripts will suppress all functions that request input from the user - confirmations - Y/N, choices - 1) 2)..., etc. and will assume some sensible default input. (default: `false`, in CI - `true`)
  - `verbose`: If `true`, scripts will emit tracing and messages from all `trace()` calls, all executed commands, and all variable dumps (default: `false`)
- Switches and options for the CI workflows and bash scripts:
  - `target-os`: Operating systems to run the jobs on (default: `ubuntu-latest`)
  - `dotnet-version`: .NET SDK version to install (default: `10.0.x`)
  - `configuration`: Build configuration (default: `Release`)
  - `preprocessor-symbols`: Optional preprocessor symbols to pass to `dotnet build` (e.g. SHORT_RUN for benchmarks) (default: empty)
  - `test-project`: Relative path to the test project to execute (default: `tests/UnitTests/UnitTests.csproj`)
  - `min-coverage-pct`: Minimum acceptable line coverage percentage (default: `80`)
  - `run-benchmarks`: Whether to run benchmarks as part of the CI (default: `true`)
  - `benchmark-project`: Relative path to the benchmark project to execute (default: `benchmarks/Benchmarks/Benchmarks.csproj`)
  - `force-new-baseline`: Ignore the current baseline and make the current benchmark results the new baseline (default: `false`)
  - `max-regression-pct`: Maximum acceptable regression percentage (default: `10`)

### `.github/workflows/_ci.yaml`

- Orchestrates the full CI pipeline:
  1. Build
  1. Test
  1. Run benchmark tests
- Normalizes all incoming inputs (target OS, .NET SDK, configuration, defined symbols, etc.) through `validate-vars.sh` (see the list of parameters above).
- Fans out to the lower-level reusable workflows (`build.yaml`, `test.yaml`, `benchmarks.yaml`).
- Uploads/Downloads artifacts from/to artifact directories (`TestArtifacts`, `BmArtifacts`) so downstream jobs and scripts stay in sync, compare with previous versions (esp. for benchmarks), track progress of non-functional changes (e.g. test coverage and performance benchmarks), etc. history.

### `.github/workflows/_prerelease.yaml`

Reusable workflow for publishing prerelease packages with automatic semantic versioning.

**Key Features:**

- Computes semantic prerelease tags (`vX.Y.(Z+1)-<prefix>.<YYYYMMDD>.<run>`) from latest stable version
- Validates and normalizes package-projects input (supports auto-detect with `[""]` sentinel)
- Tag skip guard: prevents duplicate releases unless `force-publish` is enabled
- Multi-project matrix support via JSON array input
- Publishes to NuGet.org or GitHub Packages
- Optional workflow artifact uploads for `.nupkg` files
- MinVer tag prefix configurable via `vars.MinVerTagPrefix` (default: `v`)
- Comprehensive step summaries showing computed tags and published packages

**Input Parameters:**

- `package-projects`: JSON array of project paths (default: `[""]` for auto-detect)
- `dotnet-version`: .NET SDK version (default: `10.0.x`)
- `semver-build-prefix`: Prerelease label like `preview`, `alpha`, `beta`, `rc` (default: `preview`)
- `force-publish`: Bypass tag-already-exists check (default: `false`)
- `reason`: Description for release notes
- `nuget-server`: Target server - `nuget` or `github` (default: `nuget`)
- `save_package_artifacts`: Upload packages as artifacts (default: `false`)

**Secrets:**

- `NUGET_API_KEY`: Authentication token for the selected NuGet server

## Composable workflow building blocks

These workflows are included by the high-level orchestrators, but can also be consumed individually if you only need part of the pipeline. E.g. all scripts are designed to be reusable and callable either from a workflow or directly from the command line. E.g. you can call `run-tests.sh` from your own workflow if you want to run tests with coverage but don't need the full CI.

### `.github/workflows/_build.yaml`

Reusable workflow for building .NET projects with optimized caching.

**Key Features:**

- Weekly NuGet cache rotation (cache key based on calendar week)
- Dual-layer caching strategy:
  - Built-in `setup-dotnet` cache for packages
  - Explicit `actions/cache` for `~/.nuget/packages`
- Locked-mode NuGet restore for reproducible builds
- Optional preprocessor symbols support
- Build artifacts cached per SHA and configuration
- Comprehensive build summaries

**Input Parameters:**

- `os`: Runner operating system (default: `ubuntu-latest`)
- `dotnet-version`: .NET SDK version (default: `10.0.x`)
- `configuration`: Build configuration like `Release` or `Debug` (default: `Release`)
- `build-project`: Path to specific project; empty/null builds solution or root project (optional)
- `preprocessor-symbols`: Semicolon-separated preprocessor defines (optional)

**Cache Strategy:**

- NuGet packages: Weekly rotation + lock file hash
- Build outputs: Cached in `**/bin/{configuration}` and `**/obj` by SHA and configuration

### `.github/workflows/_test.yaml`

- Provisions the .NET SDK
- Calls `scripts/bash/run-tests.sh` to execute a specified test project with coverage collection
- Publishes the resulting `TestArtifacts` directory (coverage reports, logs) as an artifact for future inspections
- Populates `$GITHUB_STEP_SUMMARY` with coverage results, and fails the job if coverage is below the configured threshold

### `.github/workflows/_benchmarks.yaml`

- Restores baseline benchmark summaries (if available) via `download-artifact.sh`
- Executes `scripts/bash/run-benchmarks.sh`
- Analyses the results and compares to the baseline (results from previous runs)
- Enforces regression thresholds
- Always publishes the latest benchmark summaries
- Optionally pushes a refreshed baseline when large improvements are observed
- When large regressions are detected, the job fails and the summary contains guidance on how to proceed, possibly by forcing a new baseline

## Script library (lowest layer)

See [Scripts Reference](docs/SCRIPTS_REFERENCE.md) for detailed script documentation.

## Additional notes

- All workflows assume .NET 10.0.x SDKs; update the workflow inputs if you need to target a different version.
- Scripts rely on `bash` and standard GNU utilities available on Ubuntu GitHub-hosted runners. Any additional tooling they need (e.g., `jq`, `reportgenerator`) is installed on demand.
- When adding new scripts, follow the existing three-file pattern and keep code ShellCheck-clean so the shared lint step continues to pass.
