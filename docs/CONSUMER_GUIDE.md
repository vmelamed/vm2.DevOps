# Consumer Guide: Using vm2.DevOps Workflows

This guide explains how to integrate vm2.DevOps automation into your own .NET repositories.

⚠️ TODO: #12 Some of the copying and customizing work below will be implemented in a `dotnet` template package in the future for easier setup.

## Table of Contents

- [Quick Start](#quick-start)
- [Repository Setup](#repository-setup)
- [Workflow Templates](#workflow-templates)
- [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
- [Examples](#examples)

## Quick Start

### Prerequisites

Your repository should have:

1. A .NET solution in a `.slnx` format, or a project `.csproj`. If you are still using `.sln` files, please migrate them to `.slnx` with:

   ```bash
   dotnet solution migrate
   ```

   ⚠️ TODO: #11 At the moment, there is no support for single `.cs` file. I am not sure that this is a priority use case. But if you need it, please open an issue.

1. Test projects (highly recommended)
1. Benchmark projects (recommended)
1. GitHub repository with Actions enabled
1. [Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets):

   - `NUGET_API_GITHUB_KEY`, if the packages will be published to GitHub Packages
   - `NUGET_API_NUGET_KEY`, if the packages will be published to NuGet.org
   - `CODECOV_TOKEN`, to use Codecov for test coverage reporting
   - `BENCHER_API_TOKEN`, to use Bencher for benchmark reporting

1. [Variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets) (treat them as policies):

   - `DOTNET_VERSION` (default: `10.0.x`)
   - `CONFIGURATION` (default: `Release`)
   - `MIN_COVERAGE_PCT` (default: `80`)
   - `MAX_REGRESSION_PCT` (default: `10`)

## Repository Setup

### Required Directory Structure

Your repository is expected to follow the following structure:

```txt
YourRepo/
├── .github/
│   └── workflows/
│       │ # Copied from `*.template._yaml` (see below)
│       ├── ClearCache.yaml
│       ├── CI.yaml
│       ├── Prerelease.yaml
│       └── Release.yaml
├── benchmarks/               # Benchmark projects (recommended)
│   └── Project1.Benchmarks/
│   └── Project2.Benchmarks/
├── src/                      # Source code
│   └── Project1/
│   └── Project2/
├── test/                     # Test projects (highly recommended)
│   └── Project1.Tests/
│   └── Project2.Tests/
│ # Copied from this repo and customized (see below)
├── .editorconfig
├── .gitattributes
├── .gitignore
├── codecov.yml
├── Directory.Build.props
├── Directory.Packages.props
├── global.json
├── LICENSE
├── test.runsettings
│ # Provided by you
├── README.md
└── CHANGELOG.md
```

> ⚠️ Note that the `src/`, `test/`, `benchmarks/`, etc. [folders are conventional and highly recommended](https://learn.microsoft.com/en-us/dotnet/core/porting/project-structure) but vm2 makes them mandatory and assumes this structure in the called GitHub workflows.
> Also please note that we are committed to using the following features:
>
> - [`.slnx` solution files](https://devblogs.microsoft.com/dotnet/introducing-slnx-support-dotnet-cli/) (instead of `.sln`)
> - [`Directory.Build.props`](https://learn.microsoft.com/en-us/visualstudio/msbuild/customize-your-build?view=vs-2022) and [`Directory.Packages.props`](<https://learn.microsoft.com/en-us/>> nuget/consume-packages/central-package-management) for centralized configuration, a.k.a. "Central Package Management" (CPM)
> - [`.editorconfig`](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/code-style-rule-options) for common code style settings, please do not change formatting settings > unless you have specific needs; communicate the changes to your    team
> - [`global.json`](https://learn.microsoft.com/en-us/dotnet/core/tools/global-json) to pin the .NET SDK version (a matter of policy that is also reflected in the CI workflows variable > `vars.DOTNET_VERSION`)
> - [`.gitignore`](https://git-scm.com/docs/gitignore) and [`.gitattributes`](https://git-scm.com/docs/gitattributes) for Git configuration
> - [`test.runsettings`](https://learn.microsoft.com/en-us/visualstudio/test/configure-unit-tests-by-using-a-dot-runsettings-file?view=visualstudio) for test execution settings
> - [`codecov.yml`](https://about.codecov.io/product/feature/yaml/) for code coverage configuration

### Initial Setup

1. **Copy workflow templates** to your repository:

   ```bash
   # From your repository root
   mkdir -p .github/workflows
   curl -o .github/workflows/CI.yaml https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/.github/workflows/Repo.CI.template._yaml
   curl -o .github/workflows/ClearCache.yaml https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/.github/workflows/ClearCache.template._yaml
   curl -o .github/workflows/Prerelease.yaml https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/.github/workflows/Repo.Prerelease.template._yaml
   curl -o .github/workflows/Release.yaml https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/.github/workflows/Repo.Release.template._yaml
   ```

1. Recommended Configuration Files

   Copy the pre-configured files from vm2.DevOps to your repository root:

   ```bash
   # Copy configuration files from vm2.DevOps
   curl -o Directory.Build.props https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/Directory.Build.props
   curl -o Directory.Packages.props https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/Directory.Packages.props
   curl -o global.json https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/global.json
   curl -o test.runsettings https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/test.runsettings
   curl -o codecov.yml https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/codecov.yml
   curl -o .editorconfig https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/.editorconfig
   curl -o .gitignore https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/.gitignore
   curl -o .gitattributes https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/.gitattributes
   curl -o LICENSE https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/LICENSE
   ```

### Customizing Configuration Files

Then **edit these files** to customize for your project:

#### `Directory.Packages.props`

Add your project-specific package versions:

```xml
<ItemGroup>
  ...
  <!-- The file already contains common packages like MinVer, SourceLink, etc. -->
  <!-- Add your additional dependency packages here -->
  <PackageVersion Include="YourDependencyPackage" Version="1.0.0" />
  ...
</ItemGroup>
```

Remove package versions you don't need.

#### `Directory.Build.props`

This file has several sections you might want to review and customize:

1. Common settings for all projects (e.g., `TargetFramework`, `LangVersion`, etc.). Key settings are already provided to follow vm2 accepted standards:
    - The latest LTS .NET version is used as `TargetFramework`
    - C# `LangVersion` is set to `latest`
    - `Nullable` is enabled
    - `ImplicitUsings` is enabled
    - `AnalysisLevel` is set to `latest`
    - `WarningLevel` is set to `9999`
    - `TreatWarningsAsErrors` is enabled. As you can see, all warnings are visible at compile time and treated as errors to enforce high code quality. Strive to not suppress warnings unless absolutely necessary, mostly in source code.
    - `ManagePackageVersionsCentrally` is enabled as we are using `Directory.Packages.props`
    - `RestorePackagesWithLockFile` is enabled for deterministic package resolution
    - `PublishRepositoryUrl` is enabled to include repository URL in package metadata (see [SourceLink](https://github.com/dotnet/sourcelink))

1. Common settings for NuGet package metadata (e.g., `Company`, `Authors`, `Copyright`, `PackageLicenseExpression`, etc.) For the vm2 projects, these are already pre-configured. Update them as needed for your project. Other project-specific settings must be set in individual `.csproj` files (e.g., `PackageId`, `Title`, `Description`, `PackageTags`, `PackageProjectUrl`, `RepositoryUrl`, `PackageReadme`).

1. Common package references, e.g. `System.Configuration.ConfigurationManager`, `Microsoft.Extensions.Configuration.Json`, `Microsoft.Extensions.Hosting`, etc. Update as needed for your project. We use `MinVer` for automatic semantic versioning based on Git tags, and `Microsoft.SourceLink.GitHub` for source code debugging support.

   Add or remove common package references as needed for your project, corresponding to what you did in `Directory.Packages.props`. E.g.:

   ```xml
   <ItemGroup>
     ...
     <PackageReference Include="YourDependencyPackage" />
     ...
   </ItemGroup>
   ```

1. Settings for test projects.
   > ⚠️ `vm2` is fully committed to the new [Microsoft Test Platform](https://learn.microsoft.com/en-us/dotnet/core/testing/microsoft-testing-platform-intro?tabs=dotnetcli). The file already includes the required settings and package references. Please note that Visual Studio 2026 is still not fully compatible with the new test platform, so be aware of that limitation and tread carefully when you edit sections that are conditioned on `$(BuildingInsideVisualStudio)`. The provided settings are tested and known to work correctly with:
   > - executing the test executable standalone from CLI, e.g. `./test/YourTests/bin/Release/net10.0/YourTests.exe`
   > - `dotnet run` CLI (used in the CI workflows), both on Windows and Linux, e.g. `dotnet run --project ./test/YourTests/YourTests.csproj --configuration Release`
   > - Visual Studio Code with the C# extension, both on Windows and Linux
   > - Visual Studio 2026 on Windows

   > ⚠️ Hopefully VS 2026 will improve its support for the new test platform in the near future and this section will be simplified.

   Other parts of the test stack (already included via `Directory.Packages.props`) are:
   - `xunit` test framework
   - `FluentAssertions` for better assertions and mocking
   - Code coverage with `ReportGenerator` uploaded to Codecov

1. Settings for test libraries - see [vm2.TestUtilities](https://github.com/vmelamed/vm2.TestUtilities) repo for reference.

1. Settings for benchmark projects. The file already includes the required settings and package references for `BenchmarkDotNet`. Update as needed for your project. the workflows here will run benchmarks and upload results to [Bencher](https://bencher.dev/).

#### `global.json`

Usually no changes needed unless you want a different .NET SDK version:

```jsonc
{
  "sdk": {
    "version": "10.0.101",  // Change if needed
    "rollForward": "latestFeature"
  }
}
```

#### `test.runsettings`

Adjust test execution settings if needed (code coverage paths, test timeouts, etc.).

#### `codecov.yml`

Update code coverage configuration:

- Adjust coverage thresholds
- Configure which files/folders to exclude from coverage
- Set up coverage badges

#### `.editorconfig`

Contains code style settings for consistent formatting across the team. Usually no changes needed unless you have specific style preferences different from vm2 standards.

#### `.gitignore`

Review and add any project-specific files/folders to ignore. The file already includes common .NET patterns (bin/, obj/, .vs/, etc.).

#### `.gitattributes`

Controls Git line ending handling and merge strategies. Typically no changes needed.

---

## Workflow Templates

### CI Workflow (`CI.yaml` copied from `CI.template._yaml`)

**Purpose:** Build, test, and benchmark on every push, pull request, and manual workflow dispatch.

**Triggers:**

- Push to any branch
- Pull requests to any branch
- Manual workflow dispatch

> ⚠️ If you need to just push you code as is without running the full CI pipeline (e.g., for documentation changes, or just save your work when you know that it is still early to build and test), you can temporarily disable the CI workflow triggering by adding **`[skip ci]`** to your commit message.

**What it does:**

1. Invokes `_ci.yaml`, which gathers,validates and normalizes all input parameters passed from this workflow, from repository variables, environment variables, and from workflow dispatch inputs.
1. Builds **multiple projects in parallel** the solution(s) src directory (one job per project, per OS)
1. Runs **multiple test projects in parallel** (one job per test project, per OS)
1. Executes **multiple benchmark projects in parallel** (one job per benchmark project, per OS)
1. Publishes results and artifacts

**Key feature:** The `_ci.yaml` workflow accepts **arrays of projects** and automatically creates matrix jobs to run each test project and benchmark project in parallel, improving efficiency for repositories with multiple test suites (e.g., unit tests, integration tests, end-to-end tests).

#### Customizing the CI Workflow

The `CI.yaml` invokes the reusable `_ci.yaml` workflow, that orchestrates the rest of the process.

1. **Specify your projects** to build, test, and benchmark as JSON arrays of strings in the respective environment variables:

   - `env.BUILD_PROJECTS` - the projects to be built (solutions or individual projects). If empty, the workflow will attempt to build the `.slnx` or `csproj` file found in the repository root.
     > ⚠️ If you have multiple projects, prefer specifying the solution file (`.slnx`) to ensure proper dependency resolution or simply leave the default value `[""]` to let the workflow find the solution file automatically.
   - `env.TEST_PROJECTS` - the test projects to run. If none, use an empty JSON array: `[]`
   - `env.BENCHMARK_PROJECTS` - the benchmark projects to run. If none, use an empty JSON array: `[]`

   E.g.:

     ```yaml
     env:
       BUILD_PROJECTS: >-
         [
         "./src/Project1/Project1.csproj",
         "./src/Project2/Project2.csproj"
         ]
       TEST_PROJECTS: >-
         [
         "./test/Project1.Tests/Project1.Tests.csproj",
         ]
       BENCHMARK_PROJECTS: >-
         ["./benchmarks/Project1.Benchmarks/Project1.Benchmarks.csproj"]
     ```

   > ⚠️ Hint: JSON arrays of strings require double quotes around each string, and the entire array must be a string, enclosed in quotes (because of the brackets). This can get tricky, especially, e.g.
   >
   > ```yaml
   > BUILD_PROJECTS: "[\u0022./src/Project1/Project1.csproj\u0022, \u0022./src/Project2/Project2.csproj\u0022]"
   > ```
   >
   > Prefer using the YAML [block scalar syntax](https://yaml-multiline.info/) instead:
   >
   > ```yaml
   > BUILD_PROJECTS: >-
   >   [
   >   "./src/Project1/Project1.csproj",
   >   "./src/Project2/Project2.csproj"
   >   ]
   > ```

1. **Specify the OS-es of the GitHub runners** as a JSON array of strings in the `env.OS` environment variable. By default its value is `["ubuntu-latest"]`. To test on multiple platforms, specify multiple OS monikers:

   E.g.:

   ```yaml
   env:
     OS: >-
       [
       "ubuntu-latest",
       "windows-latest",
       "macos-latest"
       ]
   ```

1. **Specify any preprocessor symbols** to pass to the compiler in the `env.PREPROCESSOR_SYMBOLS` environment variable:

   ```yaml
   env:
     PREPROCESSOR_SYMBOLS: "FEATURE_FLAG_A;DEBUG_MODE"
   ```

   > ⚠️ Note that for `push` events, `SHORT_RUN` is automatically added to the preprocessor symbols to speed up benchmark tests. This is a small optimization to reduce CI time and cost at the expense of precision. If you want to disable this behavior, you can edit the `get-params` job in the `CI.yaml` workflow.

#### Trigger the CI Workflow Manually

From the GitHub UI, navigate to the **Actions** tab, select the **CI** workflow from the left sidebar, and click the **Run workflow** button. You can specify:

- `os`: Comma-separated list of OS monikers (e.g., `ubuntu-latest,windows-latest,macos-latest`). Note that this will be converted to a JSON array internally.
- `preprocessor-symbols`: Semicolon-separated list of preprocessor symbols (e.g., `FEATURE_FLAG_A;DEBUG_MODE;SHORT_RUN`)

### Prerelease Workflow (`Prerelease.yaml` copied from `Prerelease.template._yaml`)

**Purpose:** Automatically publish prerelease packages when PRs are merged to `main`.

**Triggers:**

- PR closed and merged to `main` branch
- Manual workflow dispatch

**What it does:**

1. Creates a prerelease tag (e.g., `v1.2.3-preview.20251227.1`)
1. Builds and packs the solution
1. Publishes to NuGet or GitHub Packages
1. Saves package artifacts

#### Customizing the Prerelease Workflow

The most important here is to specify which projects to package. If you have only one project in the `./src` directory, you can leave the default value but if you have multiple projects, specify them as a JSON array of strings in the `PACKAGE_PROJECTS` environment variable, e.g.:

```yaml
env:
  PACKAGE_PROJECTS: >-
    [
    "src/Project1/Project1.csproj",
    "src/Project2/Project2.csproj"
    ]
```

**Key points to customize:**

1. **NuGet server**: Set `nuget-server` to:
   - `github` for GitHub Packages (<https://nuget.pkg.github.com/>)
   - `nuget` for NuGet.org (<https://api.nuget.org/v3/index.json>)
1. **Prerelease prefix**: Default is `preview`, can also be `alpha`, `beta`, `rc`
1. **Workflow name**: Update to match your repo

### Release Workflow (`Repo.Release.template._yaml`)

**Purpose:** Publish stable releases when version tags are pushed.

**Triggers:**

- Push tags matching `v1.2.3` or `v1.2.3.4` pattern
- Manual workflow dispatch

**What it does:**

1. Validates the tag format
1. Builds and packs the solution
1. Publishes stable packages to NuGet
1. Creates GitHub release

#### Customizing the Release Workflow

```yaml
jobs:
  release:
    uses: vmelamed/vm2.DevOps/.github/workflows/_release.yaml@main
    with:
      dotnet-version: ${{ vars.DOTNET_VERSION || '10.0.x' }}
      force-publish: ${{ inputs.force-publish || false }}
      save_package_artifacts: true
      nuget-server: nuget  # Usually 'nuget' for stable releases
```

**Key points to customize:**

1. **NuGet server**: Typically `nuget` for stable releases
1. **Tag pattern**: Modify the `on.push.tags` pattern if needed
1. **Workflow name**: Update to match your repo

---

## Configuration

### Repository Variables

Set these in your GitHub repository: **Settings → Secrets and variables → Actions → Variables**

| Variable              | Required | Default    | Description                                    |
|-----------------------|----------|------------|------------------------------------------------|
| `DOTNET_VERSION`      | No       | `10.0.x`   | .NET SDK version to use                        |
| `CONFIGURATION`       | No       | `Release`  | Build configuration (`Debug` or `Release`)     |
| `MIN_COVERAGE_PCT`    | No       | `80`       | Minimum code coverage percentage (0-100)       |
| `MAX_REGRESSION_PCT`  | No       | `10`       | Maximum benchmark regression percentage        |
| `FORCE_NEW_BASELINE`  | No       | `false`    | Ignore baseline and create new benchmark base  |

### Repository Secrets

Set these in your GitHub repository: **Settings → Secrets and variables → Actions → Secrets**

| Secret           | Required | Purpose                                          |
|------------------|----------|--------------------------------------------------|
| `NUGET_API_KEY`  | Yes*     | API key for publishing to NuGet.org              |
| `GITHUB_TOKEN`   | No       | Automatically provided for GitHub Packages       |

*Required only if publishing to NuGet.org (`nuget-server: nuget`)

### Branch Protection Rules

It's recommended to set up branch protection for `main`:

1. Navigate to **Settings → Branches**
1. Add rule for `main` branch
1. Enable:
   - ☑ Require a pull request before merging
   - ☑ Require status checks to pass before merging
   - ☑ Require branches to be up to date before merging

See [PR_GATES_SETUP.md](../PR_GATES_SETUP.md) for detailed instructions.

---

## Advanced Usage

### Using Composite Action for Scripts

The bash scripts are available as a composite action that you can use in your custom workflows:

```yaml
jobs:
  custom-job:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Load DevOps scripts
        uses: vmelamed/vm2.DevOps/.github/actions/scripts@main

      - name: Run tests with custom options
        shell: bash
        run: |
          run-tests.sh \
            --project ./test/MyTests/MyTests.csproj \
            --configuration Debug \
            --min-coverage 90 \
            --verbose
```

### Script Flags

All scripts support these common flags:

```bash
script-name.sh [options]

Common Options:
  --help, -h           Show usage information
  --verbose, -v        Enable detailed output
  --quiet, -q          Suppress interactive prompts (CI mode)
  --dry-run, -n        Preview actions without executing
  --trace, -x          Enable bash execution tracing
  --debugger           Running under debugger (disables traps)
```

### Custom Workflows

You can call individual reusable workflows instead of the full CI pipeline:

#### Build Only

The `_build.yaml` workflow builds a **single project or solution**:

```yaml
jobs:
  build:
    uses: vmelamed/vm2.DevOps/.github/workflows/_build.yaml@main
    with:
      os: 'ubuntu-latest'  # Single OS (not an array)
      dotnet-version: '10.0.x'
      configuration: 'Release'
      build-project: './YourSolution.slnx'  # Single project (not an array)
```

To build on multiple platforms, use a matrix:

```yaml
jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    uses: vmelamed/vm2.DevOps/.github/workflows/_build.yaml@main
    with:
      os: ${{ matrix.os }}
      dotnet-version: '10.0.x'
      configuration: 'Release'
      build-project: './YourSolution.slnx'
```

#### Test Only

The `_test.yaml` workflow tests a **single test project**:

```yaml
jobs:
  test:
    uses: vmelamed/vm2.DevOps/.github/workflows/_test.yaml@main
    with:
      os: 'ubuntu-latest'  # Single OS (not an array)
      dotnet-version: '10.0.x'
      configuration: 'Release'
      test-project: './test/YourTests/YourTests.csproj'  # Single project (not an array)
      min-coverage-pct: 85
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

To test multiple projects, use a matrix:

```yaml
jobs:
  test:
    strategy:
      matrix:
        test-project:
          - ./test/YourProject.Tests/YourProject.Tests.csproj
          - ./test/YourProject.Integration.Tests/YourProject.Integration.Tests.csproj
    uses: vmelamed/vm2.DevOps/.github/workflows/_test.yaml@main
    with:
      os: 'ubuntu-latest'
      dotnet-version: '10.0.x'
      configuration: 'Release'
      test-project: ${{ matrix.test-project }}
      min-coverage-pct: 85
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

#### Benchmarks Only

The `_benchmarks.yaml` workflow runs benchmarks for a **single benchmark project**:

```yaml
jobs:
  benchmark:
    uses: vmelamed/vm2.DevOps/.github/workflows/_benchmarks.yaml@main
    with:
      os: 'ubuntu-latest'  # Single OS (not an array)
      dotnet-version: '10.0.x'
      configuration: 'Release'
      benchmark-project: './benchmarks/YourBenchmarks/YourBenchmarks.csproj'  # Single project (not an array)
      max-regression-pct: 10
    secrets:
      BENCHER_API_TOKEN: ${{ secrets.BENCHER_API_TOKEN }}
```

To run multiple benchmark projects, use a matrix:

```yaml
jobs:
  benchmark:
    strategy:
      matrix:
        benchmark-project:
          - ./benchmarks/CoreBenchmarks/CoreBenchmarks.csproj
          - ./benchmarks/ApiBenchmarks/ApiBenchmarks.csproj
    uses: vmelamed/vm2.DevOps/.github/workflows/_benchmarks.yaml@main
    with:
      os: 'ubuntu-latest'
      dotnet-version: '10.0.x'
      configuration: 'Release'
      benchmark-project: ${{ matrix.benchmark-project }}
      max-regression-pct: 10
    secrets:
      BENCHER_API_TOKEN: ${{ secrets.BENCHER_API_TOKEN }}
```

### Multi-Platform Builds

To test on multiple operating systems:

```yaml
# In your CI.yaml, modify the workflow_dispatch inputs:
on:
  workflow_dispatch:
    inputs:
      os:
        description: "Runner OS (comma-separated)"
        type: string
        default: "ubuntu-latest,windows-latest,macos-latest"
```

Then in the `get-params` job:

```bash
# For push/PR, test on all platforms
if [ "${{ github.event_name }}" == "push" ] || \
   [ "${{ github.event_name }}" == "pull_request" ]; then
    os='["ubuntu-latest", "windows-latest", "macos-latest"]'
fi
```

### Preprocessor Symbols

Pass custom symbols to the compiler:

```yaml
# In workflow_dispatch inputs
preprocessor-symbols:
  description: "Define constants"
  type: string
  default: "SHORT_RUN;EXCLUDE_SLOW_TESTS"

# Or in the get-params job
preprocessor_symbols="FEATURE_FLAG_A;DEBUG_MODE"
```

---

## Examples

### Example 1: Simple Library Project

**Repository structure:**

```
MyLib/
├── src/MyLib/MyLib.csproj
├── test/MyLib.Tests/MyLib.Tests.csproj
└── MyLib.sln
```

**CI.yaml customization:**

```yaml
build_projects='["./MyLib.sln"]'
test_projects='["./test/MyLib.Tests/MyLib.Tests.csproj"]'
benchmark_projects='[]'  # No benchmarks
```

### Example 2: Multi-Project Solution

**Repository structure:**

```
MyApp/
├── src/
│   ├── MyApp.Core/
│   └── MyApp.Api/
├── test/
│   ├── MyApp.Core.Tests/
│   └── MyApp.Api.Tests/
└── benchmarks/
    └── MyApp.Benchmarks/
```

**CI.yaml customization:**

```yaml
build_projects='["./MyApp.sln"]'
test_projects='[
  "./test/MyApp.Core.Tests/MyApp.Core.Tests.csproj",
  "./test/MyApp.Api.Tests/MyApp.Api.Tests.csproj"
]'
benchmark_projects='["./benchmarks/MyApp.Benchmarks/MyApp.Benchmarks.csproj"]'
```

### Example 3: Testing vm2.Glob Repository

This is a real-world example from the vm2.Glob repository:

**CI workflow configuration:**

```yaml
build_projects='["./vm2.Glob.slnx"]'
test_projects='[
  "./test/Glob.Api.FakeFileSystem.Tests/Glob.Api.FakeFileSystem.Tests.csproj",
  "./test/Glob.Api.Tests/Glob.Api.Tests.csproj"
]'
benchmark_projects='["./benchmarks/Glob.Api.Benchmarks/Glob.Api.Benchmarks.csproj"]'
```

### Example 4: Utilities Package (No Tests/Benchmarks)

**Repository structure:**

```
vm2.TestUtilities/
└── src/vm2.TestUtilities/vm2.TestUtilities.csproj
```

**CI.yaml customization:**

```yaml
build_projects='["./src/vm2.TestUtilities/vm2.TestUtilities.csproj"]'
test_projects='[]'       # No test projects
benchmark_projects='[]'  # No benchmarks
```

---

## Troubleshooting

### Common Issues

**Issue:** Workflows fail with "file not found" errors for scripts

**Solution:** The composite action will automatically make scripts available. Ensure you're calling the reusable workflows correctly:

```yaml
uses: vmelamed/vm2.DevOps/.github/workflows/_ci.yaml@main
```

**Issue:** Code coverage fails below threshold

**Solution:** Either improve test coverage or adjust `MIN_COVERAGE_PCT` variable in repository settings.

**Issue:** Benchmark regression detected

**Solution:**

1. Review the benchmark results in the workflow summary
1. If expected, set `FORCE_NEW_BASELINE=true` to create a new baseline
1. If unexpected, investigate performance regression

**Issue:** NuGet push fails with authentication error

**Solution:**

- For GitHub Packages: Ensure workflow has `contents: write` permission
- For NuGet.org: Verify `NUGET_API_KEY` secret is set correctly

### Getting Help

1. Check the [Scripts Reference](SCRIPTS_REFERENCE.md) for detailed script documentation
1. Review [PR Gates Setup](../PR_GATES_SETUP.md) for branch protection configuration
1. See [Cache Management](../CACHE_MANAGEMENT.md) for dependency cache strategies
1. Consult [Release Process](../ReleaseProcess.md) for versioning and publishing

---

## Next Steps

- 📖 Read the [Scripts Reference](SCRIPTS_REFERENCE.md) for detailed script documentation
- 🔧 Check the [Maintainer Guide](MAINTAINER_GUIDE.md) if you want to contribute
- 🔒 Set up [PR Gates](../PR_GATES_SETUP.md) for quality enforcement
- ⚡ Optimize [Cache Management](../CACHE_MANAGEMENT.md) for faster builds
- 🚀 Master the [Release Process](../ReleaseProcess.md) for publishing packages
