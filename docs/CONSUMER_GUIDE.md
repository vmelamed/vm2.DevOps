# Consumer Guide

How to set up a new .NET repository to use vm2.DevOps CI/CD automation.

## Prerequisites

- A .NET solution in `.slnx` format (migrate .sln files with `dotnet solution migrate` if needed)
- GitHub repository with Actions enabled
- Repository variables and secrets configured (see [CONFIGURATION.md](CONFIGURATION.md#github-repository-secrets))

## Two Setup Paths

### Option A: `dotnet new` Template (Recommended)

The vm2.Templates package scaffolds a ready-to-use repository:

```bash
dotnet new vm2 -n MyProject
```

This generates the full directory structure, workflows, and configuration files — no manual
customization needed.

Still it is very useful to familiarize yourself with the `scripts/bash/diff-common.sh` script and its usage to streamline the
process of your subsequent updates of common files.

### Option B: `diff-common.sh` Script

Clone the .github and vm2.DevOps repositories and run the `scripts/bash/diff-common.sh` script to copy all required files from

- the `workflow-templates/` directory of the `vmelamed/.github` repository
- the `.github/dependabot.yml` from the `vmelamed/vm2.DevOps` repository
- the `solution/` directory of the `vmelamed/vm2.DevOps` repository

> [!Tip]
> The `diff-common.sh` script automates the process of copying the common files, ensuring consistency and saving time. It would
be a good idea to familiarize yourself with the script and its usage to streamline the process of your setup and subsequent
updates.

### Option C: GitHub Workflow Templates + Manual Setup

1. **Create workflows** from the GitHub UI:
   - Go to your repo → Actions → New workflow
   - Search for the `vmelamed` organization templates
   - Add: CI, Prerelease, Release, ClearCache, dependabot

   Or copy manually:

   ```bash
   mkdir -p .github/workflows
   for wf in CI Prerelease Release ClearCache; do
       curl -o .github/workflows/${wf}.yaml \
           https://raw.githubusercontent.com/vmelamed/.github/main/workflow-templates/${wf}.yaml
   done
   curl -o .github/dependabot.yml \
    <https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/.github/dependabot.yml>
   ```

1. **Copy configuration files** from vm2.DevOps `solution/` directory:

   ```bash
   for f in Directory.Build.props Directory.Packages.props global.json \
            .editorconfig .gitignore .gitattributes NuGet.config \
            codecov.yaml coverage.settings.xml testconfig.json LICENSE; do
       curl -o "$f" \
           https://raw.githubusercontent.com/vmelamed/vm2.DevOps/main/solution/${f}
   done
   ```

1. **Edit the `# *TODO*` markers** in each workflow .yaml file to set your project paths and other repo-specific values.

1. **Customize configuration files** for your project (see below).

## Required Directory Structure

```text
YourRepo/
├── .github
│   ├── dependabot.yml
│   └── workflows/
│       ├── CI.yaml
│       ├── Prerelease.yaml
│       ├── Release.yaml
│       └── ClearCache.yaml
├── src/
│   └── MyProject/
├── test/                           # not having one MUST be justified
│   └── MyProject.Tests/
├── benchmarks/                     # highly recommended
│   └── MyProject.Benchmarks/
├── changelog/
│   ├── cliff.prerelease.toml
│   └── cliff.release-header.toml
├── .editorconfig
├── .gitignore
├── .gitattributes
├── Directory.Build.props
├── Directory.Packages.props
├── NuGet.config
├── global.json
├── codecov.yaml
├── coverage.settings.xml
├── testconfig.json
├── CHANGELOG.md
├── LICENSE
├── README.md
└── MyRepo.slnx
```

> [!Important]
> Note that GitHub only recognizes `dependabot.yml` filename, not `dependabot.yAml`

The `src/`, `test/`, and `benchmarks/` folder conventions are mandatory — the CI scripts assume this layout (e.g.,
`<solution>/src/<project>/<project>.csproj` or `<solution>/test/<project.Tests>/<project.Tests>.csproj`).

Most of the files in the root are required for the workflows to function correctly. Once created they rarely need changes. And
that's why we recommend using the `dotnet new vm2` template which generates them all correctly from the start or at least manually
copying. If you choose to set up manually use the `diff-common.sh` script to do this for you. The files in the `solution/`
directory of this repository are the canonical versions that you can copy from.

## Customizing Configuration Files

### Directory.Build.props

1. Common MSBuild settings for all projects. Key defaults:

   - `TargetFramework`: latest LTS .NET
   - `LangVersion`: latest
   - `Nullable`: enabled
   - `TreatWarningsAsErrors`: enabled
   - `ManagePackageVersionsCentrally`: enabled (Central Package Management)
   - `RestorePackagesWithLockFile`: enabled

1. Common package properties are defined in the `NuGetCommon` property group. Common for all vm2 packages. Example:

   ```xml
   <PropertyGroup Label="NuGetCommon">
       <IsPackable>true</IsPackable>
       <Company>vm</Company>
       <Product>vm2</Product>
       <ProductName>vm2 packages and tools</ProductName>
       <Authors>Val Melamed</Authors>
       <Copyright>Copyright &copy;2025 vm</Copyright>
       <PackageLicenseExpression>MIT</PackageLicenseExpression>
       ...
   ```

   > [!Note] Project-specific NuGet metadata (`PackageId`, `Title`, `Description`, etc.) goes in individual `.csproj` files.

1. Test Stack

   This is where the properties and references to the common test stack is defined based on entries conditioned via the MSBuild
   property `IsTestProject`. The test stack includes:

   - Microsoft Testing Platform (MTP v2)
   - xUnit
   - FluentAssertions,
   - ReportGenerator

   > [!Note] The file includes also a few references that might be needed by test library projects (.e.g.
     `vm2.Glob/test/Glob.Api.FakeFileSystem`). These are conditioned on `IsTestLibraryProject`.

1. Benchmark Stack

   The benchmark stack is defined based on entries conditioned via the MSBuild property `IsBenchmarkProject`. The benchmark
   stack includes:

   - BenchmarkDotNet

Add more `PackageReference` entries at the bottom of the file as needed.

### Directory.Packages.props

Central package version management. Add your project-specific dependency versions here. Already includes MinVer, SourceLink,
xUnit, FluentAssertions, BenchmarkDotNet, and ReportGenerator.

### global.json

Pins the .NET SDK version. Should match the `DOTNET_VERSION` repository variable (default `10.0.x`). Rarely needs changes after
initial setup.

### NuGet.config

Must include the `github.vm2` source for private package restore. The source name `github.vm2` is referenced by the workflow
authentication step. Rarely needs changes after initial setup.

### codecov.yaml

Per-repo configuration coverage flags matching your test project names. See existing repos (vm2.Glob, vm2.Ulid) for examples.
Rarely needs changes after initial setup.

## .NET Conventions

vm2 projects are committed to:

- [`.slnx` solution files](https://devblogs.microsoft.com/dotnet/introducing-slnx-support-dotnet-cli/)
- [Central Package Management](https://learn.microsoft.com/en-us/nuget/consume-packages/central-package-management) via
  `Directory.Build.props` + `Directory.Packages.props`
- [Microsoft Testing Platform](https://learn.microsoft.com/en-us/dotnet/core/testing/microsoft-testing-platform-intro)
  with xUnit
- [MinVer](https://github.com/adamralph/minver) for Git tag–based semantic versioning
- [SourceLink](https://github.com/dotnet/sourcelink) for source-level debugging

## Workflow Customization

After setup, customize the workflow `env:` blocks, `inputs:`, and `secrets:` for your repo. See [CONFIGURATION.md — Consumer
Workflow Customization](CONFIGURATION.md#consumer-workflow-customization)
for the full reference.

### Quick Example (CI.yaml)

```yaml
env:
  BUILD_PROJECTS: >
    [ "vm2.MyProject.slnx" ]
  TEST_PROJECTS: >
    [
    "test/MyProject.Tests/MyProject.Tests.csproj",
    "test/MyProject.Integration.Tests/MyProject.Integration.Tests.csproj"
    ]
  BENCHMARK_PROJECTS: >
    [ "benchmarks/MyProject.Benchmarks/MyProject.Benchmarks.csproj" ]
  PACKAGE_PROJECTS: >
    [ "src/MyProject/MyProject.csproj" ]
```

> JSON arrays require double quotes around each string. Use the YAML block scalar `>` for
> readability. An empty or omitted array means the stage is skipped. Use `["__skip__"]` as
> an explicit sentinel if needed.

## Troubleshooting

**Workflows fail with "file not found" for scripts:**
Ensure you're calling `vmelamed/vm2.DevOps/.github/workflows/_ci.yaml@main` — the reusable
workflows handle script checkout automatically.

**Code coverage below threshold:**
Improve test coverage or adjust `MIN_COVERAGE_PCT` in repository variables (default 80).

**Benchmark regression detected:**
Review results in the workflow summary. If the regression is expected (e.g., new feature
with known cost), the new baseline will be established on the next main branch run.

**NuGet push fails with authentication error:**
Verify the appropriate `NUGET_API_*` secret is set for your configured `NUGET_SERVER`.

**Prerelease fails with "GitHub Actions is not permitted to create or approve pull requests":**
Enable `Settings -> Actions -> General -> Workflow permissions -> Allow GitHub Actions to create and approve pull requests`.

## Further Reading

| Topic                     | Document                                            |
| :------------------------ | :-------------------------------------------------- |
| Architecture overview     | [ARCHITECTURE.md](ARCHITECTURE.md)                  |
| Workflow details          | [WORKFLOWS_REFERENCE.md](WORKFLOWS_REFERENCE.md)    |
| Script details            | [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md)        |
| All configuration options | [CONFIGURATION.md](CONFIGURATION.md)                |
| Release process           | [RELEASE_PROCESS.md](RELEASE_PROCESS.md)            |
| Cache management          | [CACHE_MANAGEMENT.md](CACHE_MANAGEMENT.md)          |
| Error recovery            | [ERROR_RECOVERY.md](ERROR_RECOVERY.md)              |
