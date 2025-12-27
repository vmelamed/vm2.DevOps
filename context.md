# Implementation Plan: Composite Action for Scripts

## Goal

Make vm2.DevOps scripts reusable across repositories (vm2.TestUtilities, vm2.Glob) while maintaining full functionality for local execution by developers.

## Problem Statement

Current state:

- Scripts in `vm2.DevOps/scripts/bash/` are only accessible within vm2.DevOps
- Reusable workflows (`_ci.yaml`, `_test.yaml`, `_benchmarks.yaml`) expect scripts to exist locally
- External repositories calling these workflows fail with "No such file or directory" errors
- Scripts are designed for both CI/CD and local developer use with rich interactive features

Requirements:

- Scripts must be callable from external repositories via GitHub Actions
- Local execution capabilities must be preserved (interactive prompts, debugging, dry-run mode)
- No code duplication
- Version pinning capability for external repositories
- Maintain all existing script features: `--verbose`, `--dry-run`, `--trace`, `--debugger`, `--quiet`

## Solution: Composite Action + Symlinks

### Directory Structure

    vm2.DevOps/
      .github/
        actions/
            scripts/                         # Actual script files
              action.yaml                      # Composite action entry point
              _common.sh
              validate-vars.sh
              validate-vars.usage.sh
              validate-vars.utils.sh
              run-tests.sh
              run-tests.usage.sh
              run-tests.utils.sh
              run-benchmarks.sh
              run-benchmarks.usage.sh
              run-benchmarks.utils.sh
              download-artifact.sh
              download-artifact.usage.sh
              download-artifact.utils.sh
              summary.jq
              .shellcheckrc
      scripts/
        bash/  -> ../../.github/actions/scripts/  # Symlink for local use

### Implementation Steps

1. **Create composite action structure**
   - Create directory: `.github/actions/devops-scripts/`
   - Create `action.yaml` that makes scripts available in PATH
   - Move all scripts from `scripts/bash/` to `.github/actions/devops-scripts/scripts/`

1. **Create symlink for local execution**
   - Delete `scripts/bash/` directory
   - Create symlink: `scripts/bash` → `../../.github/actions/devops-scripts/scripts/`
   - This preserves all existing local execution paths

1. **Update reusable workflows**
   - Modify `_ci.yaml` to use the composite action
   - Modify `_test.yaml` to use the composite action
   - Modify `_benchmarks.yaml` to use the composite action
   - No changes needed to `_build.yaml` (doesn't use scripts)

1. **Update release workflows**
   - Modify `_prerelease.yaml` to add `nuget-server` input parameter
   - Modify `_release.yaml` to add `nuget-server` input parameter
   - Support both NuGet.org and GitHub Packages

1. **Create vm2.TestUtilities CI workflow**
   - Create `.github/workflows/TestUtilities.CI.yaml`
   - Call `vmelamed/vm2.DevOps/.github/workflows/_ci.yaml@main`
   - Pass empty arrays for test and benchmark projects

1. **Fix vm2.TestUtilities metadata**
   - Update `Directory.Build.props` to correct `RepositoryUrl`

1. **Update documentation**
   - Update vm2.DevOps README.md with multi-repo usage examples
   - Update vm2.TestUtilities README.md with installation instructions

### Files to Create/Modify

#### New Files

1. `.github/actions/devops-scripts/action.yaml`
1. `vm2.TestUtilities/.github/workflows/TestUtilities.CI.yaml`

#### Modified Files

1. `.github/workflows/_ci.yaml`
1. `.github/workflows/_test.yaml`
1. `.github/workflows/_benchmarks.yaml`
1. `.github/workflows/_prerelease.yaml`
1. `.github/workflows/_release.yaml`
1. `vm2.TestUtilities/Directory.Build.props`
1. `README.md` (both repositories)

#### Moved Files

All files from `scripts/bash/` → `.github/actions/scripts/`

#### Deleted

1. `scripts/bash/` directory (replaced with symlink)

### Key Benefits

1. **External repositories** can use scripts via:

       - uses: vmelamed/vm2.DevOps/.github/actions/devops-scripts@main

1. **Local execution** unchanged - developers can still run:

       ./scripts/bash/run-tests.sh --help
       ./scripts/bash/validate-vars.sh --verbose

1. **Version control** - external repos can pin to specific versions:

       - uses: vmelamed/vm2.DevOps/.github/actions/devops-scripts@v1.0.0

1. **Single source of truth** - scripts exist in one location only
1. **No duplication** - symlink ensures local and CI use same code
1. **All features preserved** - interactive prompts, debugging, dry-run, etc.

### Testing Strategy

1. Test local execution in vm2.DevOps:

       cd /home/valo/repos/vm2.DevOps
       ./scripts/bash/validate-vars.sh --help
       ./scripts/bash/run-tests.sh --help

1. Test CI execution in vm2.DevOps:
   - Push to feature branch
   - Verify Glob.Api.CI.yaml workflow runs successfully

1. Test external repository usage in vm2.TestUtilities:
   - Push TestUtilities.CI.yaml
   - Verify it calls vm2.DevOps workflows successfully
   - Verify build completes without test/benchmark runs

1. Test release workflows:
   - Verify _prerelease.yaml with `nuget-server: github`
   - Verify _release.yaml with `nuget-server: nuget`

### Rollback Plan

If issues arise:

1. Revert symlink changes
1. Move scripts back to `scripts/bash/`
1. Revert workflow changes
1. Merge the working version back to main

### Future Considerations

1. When vm2.Glob is created, it will use the same pattern
1. Scripts can be versioned via Git tags for stability
1. Additional composite actions can be created for other shared functionality
1. Consider publishing the action to GitHub Marketplace if useful to others

---

## Prerequisites

Before starting implementation:

1. Reset vm2.DevOps main branch to commit f9334a87:

       cd /home/valo/repos/vm2.DevOps
       git checkout main
       git reset --hard f9334a87
       git push origin main --force

1. Create feature branch:

       git checkout -b feature/composite-action-scripts

1. Verify TestUtilities exists in vm2.DevOps before proceeding
