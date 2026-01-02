# Workflow Status Summary

**Date:** December 31, 2025

## ✅ Completed Workflows

### Reusable Workflows

#### `_build.yaml`

- **Status:** ✅ Complete and integrated
- **Used by:** `_ci.yaml` (line 130)
- **Location:** `.github/workflows/_build.yaml`
- **Features:**
  - Weekly NuGet cache rotation
  - Dual-layer caching (setup-dotnet + explicit actions/cache)
  - Locked-mode restore for reproducibility
  - Optional preprocessor symbols
  - Build artifacts caching per SHA/configuration
  - Comprehensive step summaries
- **Documentation:** Updated in README.md and CONSUMER_GUIDE.md

#### `_prerelease.yaml`

- **Status:** ✅ Complete and ready for use
- **Location:** `.github/workflows/_prerelease.yaml`
- **Features:**
  - Auto-computes prerelease tags (vX.Y.Z+1-prefix.YYYYMMDD.run)
  - Input validation with step summaries
  - Tag skip guard with force-publish override
  - Multi-project matrix support
  - NuGet.org and GitHub Packages support
  - Optional artifact uploads
  - MinVer tag prefix from variables
- **Documentation:** Updated in README.md and CONSUMER_GUIDE.md

### Workflow Templates

All workflow templates have been migrated to **[vmelamed/.github](https://github.com/vmelamed/.github/tree/main/workflow-templates)**:

- ✅ `CI.yaml` - Full CI/CD pipeline (build, test, benchmarks)
- ✅ `Prerelease.yaml` - Prerelease publishing workflow
- ✅ `Release.yaml` - Stable release workflow
- ✅ `ClearCache.yaml` - Manual cache clearing
- ✅ `dependabot.yaml` - Dependency updates

Each template includes:

- Properties file (`.properties.json`) with metadata
- Customization points marked with `*CP*` comments
- Default configurations for vm2 projects

## 📝 Documentation Updates

### README.md

- ✅ Added "Getting Started" section linking to CONSUMER_GUIDE
- ✅ Updated workflow template location references
- ✅ Enhanced `_build.yaml` documentation with detailed features
- ✅ Enhanced `_prerelease.yaml` documentation with inputs/secrets
- ✅ Added link to `.github` repository for templates

### CONSUMER_GUIDE.md

- ✅ Updated workflow template download URLs to `.github` repository
- ✅ Added note about GitHub workflow templates UI
- ✅ Updated directory structure comments
- ✅ Removed outdated template filename references
- ✅ Cleaned up workflow section headers

## 🎯 Integration Status

### vm2.TestUtilities

- Current: Uses `_ci.yaml` workflow (which uses `_build.yaml`)
- Opportunity: Could add `Prerelease.yaml` workflow for automatic prerelease publishing

### vm2.DevOps (this repository)

- Self-hosting all reusable workflows
- Templates published to `.github` repository
- Documentation up to date

## 📋 Recommendations

### For New Projects

1. **Copy templates from `.github` repository:**

   ```bash
   curl -o .github/workflows/CI.yaml https://raw.githubusercontent.com/vmelamed/.github/main/workflow-templates/CI.yaml
   curl -o .github/workflows/Prerelease.yaml https://raw.githubusercontent.com/vmelamed/.github/main/workflow-templates/Prerelease.yaml
   curl -o .github/workflows/Release.yaml https://raw.githubusercontent.com/vmelamed/.github/main/workflow-templates/Release.yaml
   ```

2. **Customize the *CP* (Customization Points):**
   - Set `PACKAGE_PROJECTS` for prerelease/release
   - Set `BUILD_PROJECTS`, `TEST_PROJECTS`, `BENCHMARK_PROJECTS` for CI
   - Configure `NUGET_SERVER` (github/nuget)
   - Set repository variables and secrets

3. **Configure repository variables:**
   - `DOTNET_VERSION` (default: 10.0.x)
   - `CONFIGURATION` (default: Release)
   - `MIN_COVERAGE_PCT` (default: 80)
   - `MAX_REGRESSION_PCT` (default: 10)
   - `MinVerTagPrefix` (default: v)

4. **Set up secrets:**
   - `NUGET_API_GITHUB_KEY` - for GitHub Packages
   - `NUGET_API_NUGET_KEY` - for NuGet.org
   - `CODECOV_TOKEN` - for code coverage
   - `BENCHER_API_TOKEN` - for benchmarks

### For vm2.TestUtilities

Consider adding `Prerelease.yaml`:

```yaml
name: Publish NuGet Prerelease

on:
  pull_request:
    types: [closed]
    branches: [main]
  workflow_dispatch:

env:
  PACKAGE_PROJECTS: '["src/TestUtilities/TestUtilities.csproj"]'
  NUGET_SERVER: nuget

jobs:
  prerelease:
    if: github.event.pull_request.merged == true || github.event_name == 'workflow_dispatch'
    uses: vmelamed/vm2.DevOps/.github/workflows/_prerelease.yaml@main
    permissions:
      contents: write
    secrets:
      NUGET_API_KEY: ${{ secrets.NUGET_API_NUGET_KEY }}
    with:
      package-projects: ${{ env.PACKAGE_PROJECTS }}
      dotnet-version: ${{ vars.DOTNET_VERSION || '10.0.x' }}
      nuget-server: ${{ env.NUGET_SERVER }}
```

## 🔍 Quality Checks

- ✅ All workflows use consistent input naming
- ✅ Validation steps provide user-friendly error messages
- ✅ Step summaries show computed values and results
- ✅ Caching strategies are optimized
- ✅ Documentation is comprehensive and accurate
- ✅ Templates include helpful comments and examples

## 🚀 Next Steps

1. **Optional**: Create Prerelease workflow for vm2.TestUtilities
2. **Optional**: Add Release workflow for vm2.TestUtilities
3. **Monitor**: Watch for GitHub template usage in the organization
4. **Improve**: Consider feedback from consumers and iterate

---

**Notes:**

- All reusable workflows follow the `_*.yaml` naming convention
- All consumer templates use simple names (`CI.yaml`, `Prerelease.yaml`, etc.)
- Template metadata in `.properties.json` files makes them discoverable in GitHub UI
- All workflows support both automated triggers and manual workflow_dispatch
