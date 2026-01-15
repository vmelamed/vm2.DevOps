# DevOps - architecture for CI/CD of .NET packages

## Main workflows

There are 3 main workflows that do the CI/CD for publishing packages: CI.yaml, Prerelease.yaml, and Release.yaml.

They must be created in the `.github/workflows` directory of each repo, There are two ways to create them:

1. Via the GitHub UI backed by the GitHub actions workflow templates in the repo `.github` - `~/repos/.github/workflow-templates`.
   In the templates the customization is manual, and the customization points are marked with **TODO**-s.
1. Via dotnet template in the vm2.Templates repo. The templates are in the repo `vm2.Templates` -
   `~/repos/vm2.Templates/templates/AddNewPackage/content/.github/workflows`. The customization is via template parameters.

Both ways create the same workflows (please verify!).

The main workflows call reusable workflows in the `vm2.DevOps` repo: `~/repos/vm2.DevOps/.github/workflows`. The reusable
workflows are doing the actual work of building, testing, packing, and publishing the packages by using the standard GitHub
actions, and script that we worked on earlier.

## CI.yaml in each repo

The CI workflow is triggered on push to a branch. It calls the following reusable workflows:

### _build.yaml (vm2.DevOps/.github/workflows/_build.yaml)

- builds the solution/project
- runs the tests
- if there are benchmarks, runs them with SHORT_RUN

### _test.yaml (vm2.DevOps/.github/workflows/_test.yaml)

- runs the tests in the project/solution
- uploads the test results to CodeCov
- succeeds if tests pass and the code coverage is above the threshold %

### _benchmark.yaml (vm2.DevOps/.github/workflows/_benchmarks.yaml)

If present in the repo, the benchmark workflow:

- runs the benchmarks in the project/solution
- uploads the benchmark results to bencher.io
- succeeds if benchmarks run successfully and the performance regression is below the threshold%

## Prerelease.yaml in each repo

The Prerelease workflow is triggered on push to `main` (on approved and merged PR with successful checks `build`, `test`,
`benchmark`). It calls the following reusable workflow:

### _prerelease.yaml (vm2.DevOps/.github/workflows/_prerelease.yaml)

- computes the next prerelease version by calling the script `compute-prerelease-version.sh` in the repo `vm2.DevOps` -
  `~/repos/vm2.DevOps/.github/actions/scripts/compute-prerelease-version.sh`
- updates the changelog from the commits since the last stable release using `git-cliff`
- publishes the prerelease packages to NuGet server (GitHub Packages, NuGet.org, or any other server) by calling the script
  `publish-nuget-packages.sh` in the repo `vm2.DevOps` - `~/repos/vm2.DevOps/.github/actions/scripts/publish-nuget-packages.sh`

## Release.yaml in each repo

The Release workflow is triggered manually via GitHub CLI or UI. It calls the following reusable workflow:

### _release.yaml (vm2.DevOps/.github/workflows/_release.yaml)

- computes the release version by calling the script `compute-release-version.sh` in the repo `vm2.DevOps` -
  `~/repos/vm2.DevOps/.github/actions/scripts/compute-release-version.sh`:
  - The script computes the release version from the commit messages (keywords like `BREAKING CHANGE`, `feat`, `fix`) since the
    last release tag
  - compares the computed version with the prerelease version to make sure the release version is higher than the prerelease
    version
- updates the changelog from the commits since the last release using `git-cliff`
- creates the computed tag by using the script `create-release-tag.sh` in the repo `vm2.DevOps` -
  `~/repos/vm2.DevOps/.github/actions/scripts/create-release-tag.sh`
- publishes the release packages to NuGet server (GitHub Packages, NuGet.org, or any other server) by calling the script
  `publish-nuget-packages.sh` in the repo `vm2.DevOps` - `~/repos/vm2.DevOps/.github/actions/scripts/publish-nuget-packages.sh`
