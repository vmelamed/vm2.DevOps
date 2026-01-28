# vm2.DevOps

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [Overview](#overview)
- [Getting Started](#getting-started)
- [High-level reusable workflows](#high-level-reusable-workflows)
  - [`.github/workflows/_ci.yaml`](#githubworkflows_ciyaml)
    - [`.github/workflows/_build.yaml`](#githubworkflows_buildyaml)
    - [`.github/workflows/_test.yaml`](#githubworkflows_testyaml)
    - [`.github/workflows/_benchmarks.yaml`](#githubworkflows_benchmarksyaml)
  - [`.github/workflows/_prerelease.yaml`](#githubworkflows_prereleaseyaml)
  - [.github/workflows/\_release.yaml`](#githubworkflows_releaseyaml)
- [Script library (lowest layer)](#script-library-lowest-layer)
- [Additional notes](#additional-notes)

<!-- /TOC -->

Reusable GitHub Actions workflows and automation scripts for .NET projects.

## Overview

This repository provides a CI/CD automation toolkit for .NET solutions, including:

- **[Workflow templates](https://github.com/vmelamed/.github/tree/main/workflow-templates)** available from the [`.github`](https://github.com/vmelamed/.github) organization repository
- **Reusable GitHub Actions workflows** for building, testing, benchmarking, and releasing .NET packages
- **Bash automation scripts** for local development and CI/CD pipelines
- **Standardized release processes** using MinVer for semantic versioning
- **Code coverage enforcement** with customizable thresholds, using Codecov
- **Performance regression detection** using BenchmarkDotNet and Bencher
- **NuGet package publishing** to NuGet.org, GitHub Packages, or custom feeds

## Getting Started

For detailed setup instructions, see the [Consumer Guide](docs/CONSUMER_GUIDE.md).

**Quick Start:**

1. Create a new GitHub repository for your .NET project
1. Configure repository variables (DOTNET_VERSION, MIN_COVERAGE_PCT, etc.)
1. Set up secrets (NUGET_API_KEY, CODECOV_TOKEN, etc.)
1. Copy workflow templates from [vmelamed/.github/workflow-templates](https://github.com/vmelamed/.github/tree/main/workflow-templates)
1. Customize the workflows for your project structure

Alternatively:

1. Use `dotnet new vm2pkg` command to scaffold a new project with workflows and scripts for your project
1. Execute `templates/AddNewPackage/content/scripts/bootstrap-new-package.sh` to create the repository
1. Customize the generated workflows and scripts for your project

## High-level reusable workflows

These reusable GitHub Actions workflows are intended to be called directly via `workflow_call` from dependent repositories. They orchestrate the full CI/CD pipeline, and fan out to lower-level building blocks - reusable workflows and bash scripts as needed. The workflows and scripts share a common input surface to make it easy to toggle behavior across the pipeline:

- Common switches and options for the CI workflows and bash scripts:
  - `runners_os`: List of operating systems of the jobs runners (default: `ubuntu-latest`)
  - `dotnet-version`: .NET SDK version to install (default: `10.0.x`)
  - `configuration`: Build configuration (default: `Release`)
  - `preprocessor-symbols`: Optional preprocessor symbols to pass to `dotnet build` (e.g. SHORT_RUN for benchmarks) (default: empty)
  - `build-projects`: Array of relative paths to the solution or the projects to build (default: `[""]` to build the solution or root project)
  - `test-projects`: Array of relative paths to the test project to execute (while not recommended, the array can be empty)
  - `benchmark-projects`: Array of relative paths to benchmark projects to execute (may be empty)
  - `min-coverage-pct`: Minimum acceptable unit-test line coverage percentage (default: `80`)
  - `max-regression-pct`: Maximum acceptable performance regression percentage (default: `20`)
  - etc. (other switches may be added as needed)

- Common switches for all bash scripts:
  - `help`: If `true`, scripts will display usage information and exit (default: `false`)
  - `dry-run`: If `true`, scripts will simulate actions without making changes (default: `false`)
  - `quiet`: If `true`, scripts will suppress all functions that request input from the user - binary (Y/N) or multiple ( a., b., c. ...) choices - and will assume some sensible default input (default: `false` or `true`, `$CI=true` as in GitHub Actions)
  - `verbose`: If `true`, scripts will emit tracing and diagnostic messages from all `trace()` calls, all executed commands, and all variable dumps (default: `false`)

### `.github/workflows/_ci.yaml`

Orchestrates a "Continuous Integration" pipeline. Invoked by a workflow, typically created out of the template in `vmelamed/.github/workflow-templates/CI.yaml`, which is usually triggered on pull requests and pushes to `main` branches.

- Normalizes and validates all incoming inputs (target OS, .NET SDK, projects, configuration, defined symbols, etc.) through `validate-input.sh` (see the list of parameters above).
- Builds the specified projects/solution
- Unit and Integration Tests with coverage collection and enforcement
- Run benchmark tests
  - Fans out to the lower-level reusable workflows (`build.yaml`, `test.yaml`, `benchmarks.yaml`).
  - Uploads/Downloads artifacts from/to artifact directories (`TestArtifacts`, `BmArtifacts`) so downstream jobs and scripts stay in sync, compare with previous versions (esp. for benchmarks), track progress of non-functional changes (e.g. test coverage and performance benchmarks), etc. history.
- Comprehensive step summaries showing build, coverage and benchmark results
- [Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets):
  - `CODECOV_TOKEN`, to use Codecov for test coverage reporting
  - `BENCHER_API_TOKEN`, to use Bencher for benchmark reporting
- [Variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets) (treat them as policies):
  - `DOTNET_VERSION` (default: `10.0.x`)
  - `CONFIGURATION` (default: `Release`)
  - `MIN_COVERAGE_PCT` (default: `80`)
  - `MAX_REGRESSION_PCT` (default: `20`)
- Other Customizable Parameters:
  - `build-projects`: JSON array of main deliverable project paths (default: `[""]` for solution or root project)
  - `test-projects`: JSON array of unit/integration test project paths
  - `benchmark-projects`: JSON array of benchmark project paths
  - `dotnet-version`: .NET SDK version (default: `10.0.x`)

#### Composed CI workflow building blocks

These workflows are included by the high-level orchestrators, but can also be consumed individually if you only need part of the pipeline. E.g. all scripts are designed to be reusable and callable either from a workflow or directly from the command line. E.g. you can call `run-tests.sh` from your own workflow if you want to run tests with coverage but don't need the full CI.

##### `.github/workflows/_build.yaml`

Builds the specified projects/solution with caching for sharing the results between jobs and workflow runs.

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

- `runners_os`: Runner operating system (default: `ubuntu-latest`)
- `dotnet-version`: .NET SDK version (default: `10.0.x`)
- `configuration`: Build configuration like `Release` or `Debug` (default: `Release`)
- `build-project`: Path to specific project; empty/null builds solution or root project (optional)
- `preprocessor-symbols`: Semicolon-separated preprocessor defines (optional)

**Cache Strategy:**

- NuGet packages: Weekly rotation + lock file hash
- Build outputs: Cached in `**/bin/{configuration}` and `**/obj` by SHA and configuration

##### `.github/workflows/_test.yaml`

Runs the specified test projects with coverage collection and enforcement.

**Key Features:**

- Provisions the .NET SDK
- Calls `scripts/bash/run-tests.sh` to execute a specified test project with coverage collection
- Publishes the resulting `TestArtifacts` directory (coverage reports, logs) as an artifact for future inspections
- Populates `$GITHUB_STEP_SUMMARY` with coverage results, and fails the job if coverage is below the configured threshold

**Input Parameters:**

- `runners_os`: Runner operating system (default: `ubuntu-latest`)
- `dotnet-version`: .NET SDK version (default: `10.0.x`)
- `configuration`: Build configuration like `Release` or `Debug` (default: `Release`)
- `preprocessor-symbols`: Semicolon-separated preprocessor defines (optional)
- `test-project`: Path to specific test project to run
- `min-coverage-pct`: Minimum acceptable line coverage percentage (default: `80`)

##### `.github/workflows/_benchmarks.yaml`

Runs the specified benchmark projects, compares the results to previous runs, and enforces regression thresholds.

**Key Features:**

- Provisions the .NET SDK
- Calls `scripts/bash/run-benchmarks.sh` to execute a specified benchmark project
- Publishes the resulting `BmArtifacts` directory (benchmark reports, logs) as an artifact for future inspections
- Populates `$GITHUB_STEP_SUMMARY` with benchmark results, highlighting any regressions beyond the configured threshold
- Uploads benchmark results to [Bencher.io](https://bencher.io/) if `BENCHER_API_TOKEN` secret is provided

**Input Parameters:**

- `runners_os`: Runner operating system (default: `ubuntu-latest`)
- `dotnet-version`: .NET SDK version (default: `10.0.x`)
- `configuration`: Build configuration like `Release` or `Debug` (default: `Release`)
- `preprocessor-symbols`: Semicolon-separated preprocessor defines (optional)
- `benchmark-project`: Path to specific benchmark project to run
- `max-regression-pct`: Maximum acceptable performance regression percentage (default: `20`)

### `.github/workflows/_prerelease.yaml`

Reusable workflow for publishing prerelease packages with automatic semantic versioning. Invoked by a workflow, typically created out of the template in `vmelamed/.github/workflow-templates/Prerelease.yaml`, which is usually triggered on merging pull requests to `main` branches.

**Key Features:**

- MinVer tag prefix configurable via `vars.MinVerTagPrefix` (default: `v`)
- Computes semantic prerelease tags (`vX.Y.(Z+1)-<prefix>.<YYYYMMDD>.<run>`) from latest stable version tags
- Normalizes and validates package-projects inputs
- Tag skip guard: prevents duplicate releases, unless `force-publish` is enabled
- Multi-project matrix support via JSON array input
- Publishes to NuGet Package server of choice (e.g. NuGet.org or GitHub Packages)
- Optional workflow artifact uploads for `.nupkg` files (default: enabled)
- Comprehensive step summaries showing computed tags and published packages
- [Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets):
  - `NUGET_API_GITHUB_KEY`, if the packages will be published to GitHub Packages
  - `NUGET_API_NUGET_KEY`, if the packages will be published to NuGet.org
  - `NUGET_API_KEY`, if the packages will be published to custom NuGet server
- [Variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets) (treat them as policies):
  - `DOTNET_VERSION` (default: `10.0.x`)
  - `CONFIGURATION` (default: `Release`)
  - `MIN_COVERAGE_PCT` (default: `80`)
  - `MAX_REGRESSION_PCT` (default: `20`)
  - `MinVerTagPrefix` (default: `v`)
- Other Parameters:
  - `package-projects`: JSON array of project paths to be packaged as NuGet packages
  - `dotnet-version`: .NET SDK version (default: `10.0.x`)
  - `minver-prerelease-id`: Prerelease label like `preview`, `alpha`, `beta`, `rc` (default: `preview`)
  - `force-publish`: Bypass tag-already-exists check (default: `false`)
  - `reason`: Reason for manual triggering of a pre-release
  - `nuget-server`: Target server - `nuget`, `github`, or custom URL
  - `save-package-artifacts`: Enables uploading packages as artifacts (default: `false`)

### .github/workflows/\_release.yaml`

Reusable workflow for publishing stable release packages with automatic semantic versioning. Invoked by a workflow, typically created out of the template in `vmelamed/.github/workflow-templates/Release.yaml`, which is usually triggered on administrator creating Git tags matching the stable version pattern (e.g. `vX.Y.Z`).

**Key Features:**

- MinVer tag prefix configurable via `vars.MinVerTagPrefix` (default: `v`)
- Validates the latest semantic version tags
- Tag skip guard: prevents duplicate releases, unless `force-publish` is enabled
- Multi-project matrix support via JSON array input
- Publishes to NuGet Package server of choice (e.g. NuGet.org or GitHub Packages)
- Comprehensive step summaries showing computed tags and published packages
- [Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets):
  - `NUGET_API_GITHUB_KEY`, if the packages will be published to GitHub Packages
  - `NUGET_API_NUGET_KEY`, if the packages will be published to NuGet.org
  - `NUGET_API_KEY`, if the packages will be published to custom NuGet server
- [Variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets) (treat them as policies):
  - `DOTNET_VERSION` (default: `10.0.x`)
  - `CONFIGURATION` (default: `Release`)
  - `MIN_COVERAGE_PCT` (default: `80`)
  - `MAX_REGRESSION_PCT` (default: `20`)
  - `MinVerTagPrefix` (default: `v`)
- Other Parameters:
  - `package-projects`: JSON array of project paths to be packaged as NuGet packages
  - `dotnet-version`: .NET SDK version (default: `10.0.x`)
  - `force-publish`: Bypass tag-already-exists check (default: `false`)
  - `reason`: Reason for manual triggering of a release
  - `nuget-server`: Target server - `nuget`, `github`, or custom URL
  - `save-package-artifacts`: Enables uploading packages as artifacts (default: `false`)

## Script library (lowest layer)

See [Scripts Reference](docs/SCRIPTS_REFERENCE.md) for detailed script documentation.

## Additional notes

- All workflows default to .NET 10.0.x SDKs; update the workflow inputs if you need to target a different version.
- Scripts rely on `bash` and standard GNU utilities available on Ubuntu GitHub-hosted runners. Any additional tooling they need (e.g., `jq`, `reportgenerator`) is installed on demand.
- When adding new scripts, follow the existing three-file pattern and keep code ShellCheck-clean so the shared lint step continues to pass.
