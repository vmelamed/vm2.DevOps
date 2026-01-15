# Add New Package

This document outlines the steps to create a dotnet template that creates a new GitHub package repository; and associated local project structure. The product of the project is a new NuGet package that can be published to GitHub Packages or GitHub Container Registry. The result should look like the existing already projects vm2.Ulid and vm2.Glob.

## The first step is to create a new dotnet template project

It should follow the structure of the existing projects in the vm2 set of projects.

```text
RootOfRepo/
├── .github/
│   └── dependabot.yml
│   └── workflows/
│       ├── ClearCache.yaml
│       ├── CI.yaml
│       ├── Prerelease.yaml
│       └── Release.yaml
├── benchmarks/               # Benchmark projects (recommended)
│   └── Project1.Benchmarks/
├── src/                      # Source code
│   └── Project1/
├── test/                     # Test projects (highly recommended)
│   └── Project1.Tests/
├── .editorconfig
├── .gitattributes
├── .gitignore
├── codecov.yml
├── Directory.Build.props
├── Directory.Packages.props
├── global.json
├── test.runsettings
├── README.md
├── LICENSE
└── CHANGELOG.md
```

Here are the sources and content of the listed files above:

## `.github/**/*.yaml` - copied from [vmelamed/.github/workflow-templates](https://github.com/vmelamed/.github/tree/main/workflow-templates) - basically materialize the templates for the new package repo

## In the root directory of the repo, most of the files should be coming from [vm2.DevOps](https://github.com/vmelamed/vm2.DevOps), unless explicitly specified otherwise (let me know to correct this document if needed)

- `.editorconfig`
- `.gitattributes`
- `.gitignore`
- `codecov.yml`
- `Directory.Build.props`
- `Directory.Packages.props`
- `global.json`
- `test.runsettings`
- `LICENSE` - the user should be able to choose the appropriate license (MIT by default).
- `README.md` - Some basic, common, conventional structure and contents should be provided for this file, but the user will need to customize it for the new package.
- `CHANGELOG.md` - again, some basic, common, conventional structure and contents should be provided for this file, but the user will need to customize it for the new package.

While working on the new template project, you may copy the content of these files from vm2.DevOps, and later customize them as needed. Also, notify me if you see things that should be improved in vm2.DevOps for better reusability.

## Code projects

All namespaces must starts with `vm2.` followed by the project name, and follow the file structure but the files and the folders (except the root project folder) should not have the `vm2.` prefix.

In every project, add an empty `usings.cs` file to the root of the project to enable global usings.

In general all project files should be very small relying on `Directory.Build.props` and `Directory.Packages.props` for the common settings and dependencies.

All source files should have an SPDX license identifier comment at the top of the file.

All source files in the src/ directory should have XML documentation comments enabled.

### `src/` - source code projects

Add a new project (`Project1` - CLI parameter) for the package you are creating. Follow the structure of existing projects such as vm2.Ulid or vm2.Glob. Add a very basic implementation that can be built, tested, and packaged.

The project file should include all the necessary metadata for creating a NuGet package (see existing projects for reference, e.g. vm2.Ulid/src/UlidType/UlidType.csproj).

### `test/` - test projects

Add a new test project (`Project1.Tests` - from the CLI parameter above) for the package you are creating. Follow the structure of existing projects such as vm2.Ulid.Tests or vm2.Glob.Tests.

Add basic test class and method(s) that test the simple class in the project above.

The test project (as well as all other projects)

Add `testconfig.json` file to the test project, following the structure of existing test projects.

### `benchmarks/` - benchmark projects (optional but recommended)

The CLI should allow the user to opt-out of creating benchmark projects if they do not want them. The default should be to create them.

Add a new benchmark project (`Project1.Benchmarks` - from the CLI parameter above) for the package you are creating. Follow the structure of existing projects such as vm2.Ulid.Benchmarks or vm2.Glob.Benchmarks.

Add basic benchmark class and method(s) that benchmark the simple class in the project above.

### Add `examples/` folder (optional - Opt-out via CLI)

### Add `docs/` folder (optional - Opt-out via CLI)

## Add a script/bootstrap tool/anything to create a new package repository on GitHub

Maybe it is worth exploring template repositories on GitHub for this purpose. The idea is to have a way to create a new repository on GitHub with the necessary settings (e.g., enabling GitHub Packages, setting up workflows, etc.) automatically or semi-automatically.

The actions of this repo should have the following:

- Variables:
  - ACTIONS_RUNNER_DEBUG: `false`: Whether to enable GitHub Actions runner debug logging
  - ACTIONS_STEP_DEBUG: `false`: Whether to enable GitHub Actions step debug logging
  - DOTNET_VERSION: `10.0.x`: the .NET SDK version to use
  - CONFIGURATION: `Release`: the build configuration to use (e.g., Release or Debug)
  - NUGET_SERVER: `github`: the NuGet server to publish to (supported values: 'github', 'nuget', or custom URI)
  - MINVERTAGPREFIX: `v`: Prefix for git tags to be recognized by MinVer
  - SEMVER_PRERELEASE_PREFIX: `preview`: Prefix for the prerelease tag, e.g. 'preview', 'alpha', 'beta', 'rc', etc.
  - SAVE_PACKAGE_ARTIFACTS: `false`: Whether to save package artifacts after build/publish
  - MIN_COVERAGE_PCT: `80`%: Minimum code coverage percentage required
  - MAX_REGRESSION_PCT: `20`%: Maximum allowed regression percentage

- Secrets:
  - BENCHER_API_TOKEN: ${{ secrets.BENCHER_API_TOKEN }}
  - CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
  - at least one of:
    - NUGET_API_GITHUB_KEY: ${{ secrets.NUGET_API_GITHUB_KEY }}
    - NUGET_API_NUGET_KEY: ${{ secrets.NUGET_API_NUGET_KEY }}
    - NUGET_API_KEY: ${{ secrets.NUGET_API_NUGET_KEY }}

The GitHub repositories have a lot of levers and knobs. Propose a sane default configuration for the new package repositories. You can discuss it with me as needed.

Please, ask me if you have any questions or need further clarifications.

I am sure I am missing something at the moment, so please be proactive in asking questions and suggesting improvements to this document and the overall process.

## Proposed bootstrap approach

- Keep the `dotnet new` template focused on scaffolding files and structure.
- Provide a companion bootstrapper (preferred: a `dotnet tool`; fallback: shell/PowerShell script) that:
  1. Collects org/repo name, visibility, default branch, license choice, and toggles (benchmarks/examples/docs opt-out).
  2. Preflight-checks GitHub CLI auth (or PAT + REST fallback).
  3. Creates the repo (`gh repo create ...`) with sane defaults (see below).
  4. Runs `dotnet new vm2-package ...` with computed parameters.
  5. Initializes git, commits, sets remote, and pushes.
- Optionally expose a single entry-point command (the bootstrapper) that wraps all of the above.
- Keep the bootstrapper generic so it can later support other project types (CLI, services, etc.), or ship a minimal script under `scripts/` in the generated repo when a full tool is overkill.
- Align the script with existing patterns in `.github/actions/scripts/` and reuse helpers from `_common_github.sh` where possible.

## Suggested repo defaults

- Branching: default branch `main`; protect with required checks (CI/prerelease/release) and require PRs; dismiss stale approvals on push.
- Actions variables: see Variables section above.
- Secrets expected: `BENCHER_API_TOKEN`, `CODECOV_TOKEN`, and at least one of: `NUGET_API_GITHUB_KEY`, `NUGET_API_NUGET_KEY`, `NUGET_API_KEY` - corresponding to the selected NuGet server.
- Repo features: issues on; wiki off; projects optional (off by default); vulnerability alerts on; Dependabot security updates on; Actions enabled.
- Permissions: least privilege for `GITHUB_TOKEN` (read by default; scoped write for release job); require approval for outside-contributor workflow runs.
- Environments: create `production` for release with required secrets; optional manual reviewer gate.
- Releases: enable provenance/signing if allowed; push to GitHub Packages + NuGet in release workflow.

## Decisions captured

- Bootstrapper: hard-require `gh` (available on all target environments).
- Default org: `vmelamed`; repo naming follows project name input.
- Licenses: MIT default; offer Apache-2.0 and BSD-3 options.
- Default branch: `main`.
- Merge strategy: default to squash merges; allow configuring (e.g., enable rebase) if desired later.
- Benchmarks/docs/examples: created by default; keep opt-out flags.
- CODEOWNERS: none for now; add later if needed.
- Required status checks to enforce on `main` (once workflows are in place): build; all test matrix jobs meeting coverage threshold; all benchmark matrix jobs with regression <= 20%; prerelease job.
- Signed commits: not enforced for now (can revisit; SSH signing possible later).

## Open items / clarifications

- Finalize the exact job IDs in the workflows to match the required checks above (build/test/benchmarks/prerelease) once CI YAML is settled.
