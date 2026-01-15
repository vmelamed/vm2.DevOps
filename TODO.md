# Pre-Production Testing TODO

**Date Created:** January 15, 2026
**Target Test Date:** January 16, 2026
**First Test Repository:** vm2.TestUtilities

---

## Pre-Flight Checklist

### ✅ Script Permissions

- [x] All common scripts are executable
  - `_common_sanitize.sh` - Fixed
  - `_common_user.sh` - Fixed
  - `_common_predicates.sh` - Fixed
- [x] All action scripts verified executable

### ✅ Bash Syntax Validation

- [x] All `.sh` files validated with `bash -n`
- [x] No syntax errors found

### ⏳ Secrets Configuration (VERIFY BEFORE TESTING)

Run these commands to verify secrets are configured:

```bash
# For vm2.TestUtilities
gh secret list --repo vmelamed/vm2.TestUtilities

# For vm2.Glob
gh secret list --repo vmelamed/vm2.Glob

# For vm2.Ulid
gh secret list --repo vmelamed/vm2.Ulid
```

**Required Secrets:**

- `NUGET_API_KEY` - For nuget.org publishing
- `NUGET_GITHUB_TOKEN` - For GitHub Packages (can use GITHUB_TOKEN)

**Note:** Secrets defined in `.github` repo are NOT automatically available to other repos. Each consuming repository must have secrets configured independently.

### ⏳ Changelog Configuration (VERIFY BEFORE TESTING)

For each repository, verify these files exist:

- `changelog/cliff.prerelease.toml` - Prerelease changelog config
- `changelog/cliff.release-header.toml` - Release changelog header config

Test with:

```bash
# In each repo directory
ls -la changelog/
```

### ⏳ Workflow Configuration (VERIFY BEFORE TESTING)

For each repository, verify in `.github/workflows/Prerelease.yaml` and `Release.yaml`:

**vm2.TestUtilities:**

- `PACKAGE_PROJECTS: src/TestUtilities`
- `NUGET_SERVER: https://api.nuget.org/v3/index.json`

**vm2.Glob:**

- `PACKAGE_PROJECTS: packages/Glob|packages/Glob.Api`
- `NUGET_SERVER: https://api.nuget.org/v3/index.json`

**vm2.Ulid:**

- `PACKAGE_PROJECTS: src/UlidType`
- `NUGET_SERVER: https://api.nuget.org/v3/index.json`

---

## 3-Phase Testing Strategy

### Phase 1: CI Workflow Test (LOWEST RISK)

**Objective:** Validate build and test steps work correctly

**Steps:**

1. Create feature branch in vm2.TestUtilities:

   ```bash
   cd ~/repos/vm2.TestUtilities
   git checkout -b test/ci-workflow
   ```

2. Make trivial change (e.g., add comment to README.md)

3. Push and create PR:

   ```bash
   git add .
   git commit -m "test: Validate CI workflow"
   git push -u origin test/ci-workflow
   # Create PR via GitHub UI
   ```

4. **Monitor CI workflow:**
   - Check workflow runs successfully
   - Verify all jobs complete (build, test, coverage)
   - Review any warnings or errors

5. **If successful:** Merge PR and delete branch
6. **If failures:** Review logs, fix issues, repeat

---

### Phase 2: Prerelease Workflow Test (MEDIUM RISK)

**Objective:** Validate version computation, changelog, and package publishing

**Prerequisites:**

- ✅ CI workflow passing
- ✅ Secrets configured
- ✅ Changelog configs present

**Steps:**

1. Create feature branch:

   ```bash
   cd ~/repos/vm2.TestUtilities
   git checkout -b test/prerelease-workflow
   ```

2. Make a conventional commit:

   ```bash
   # Example: Add trivial feature
   echo "// Test change" >> src/TestUtilities/TestUtilities.cs
   git add .
   git commit -m "feat: Add test feature for prerelease validation"
   git push -u origin test/prerelease-workflow
   ```

3. Create and merge PR (this triggers Prerelease workflow)

4. **Monitor Prerelease workflow:**
   - Check compute-version job produces correct version
   - Verify changelog job updates CHANGELOG.md with new entry
   - Confirm package-and-publish job succeeds
   - Validate package appears on NuGet.org and/or GitHub Packages

5. **Verify artifacts:**

   ```bash
   # Check the prerelease tag was created
   git fetch --tags
   git tag | grep "prerelease-"

   # Check CHANGELOG.md was updated
   git pull
   cat CHANGELOG.md | head -30
   ```

6. **Expected Outcomes:**
   - Tag created: `prerelease-<version>-<timestamp>`
   - CHANGELOG.md updated with new prerelease section
   - Package published to NuGet server(s)
   - No "No API key" errors in logs

**Common Issues to Watch For:**

- ❌ "No API key found" → Secrets not configured correctly
- ❌ Version calculation wrong → Check conventional commit format
- ❌ Changelog not updated → Verify git-cliff config files exist
- ❌ NuGet push fails → Check package already exists or API key invalid

---

### Phase 3: Release Workflow Test (HIGHEST RISK)

**Objective:** Validate full release process including stable versioning and tagging

**Prerequisites:**

- ✅ CI workflow passing
- ✅ Prerelease workflow successful
- ✅ No outstanding issues from Phase 2

**Steps:**

1. Ensure main branch has merged conventional commits from Phase 2

2. **Manually trigger Release workflow:**
   - Go to GitHub Actions → Release workflow
   - Click "Run workflow"
   - Select `main` branch
   - Provide release reason (e.g., "Initial release test")
   - Click "Run workflow"

3. **Monitor Release workflow:**
   - Check compute-version produces stable version (no prerelease suffix)
   - Verify changelog updates with release header
   - Confirm tag-release creates annotated tag
   - Validate release job publishes packages

4. **Verify artifacts:**

   ```bash
   # Check the release tag was created
   git fetch --tags
   git tag | grep "v"

   # View tag annotation
   git show <tag-name>

   # Check CHANGELOG.md
   git pull
   cat CHANGELOG.md | head -50
   ```

5. **Expected Outcomes:**
   - Stable tag created: `v1.0.0` (or appropriate version)
   - CHANGELOG.md updated with release section and header
   - Package published to NuGet.org
   - GitHub Release created with notes

**Recovery Procedures:**
If anything goes wrong, see `ERROR_RECOVERY.md` for specific scenarios:

- Tag creation failures
- NuGet push failures
- Version conflicts
- Rollback procedures

---

## Rollout Plan After Successful Testing

### Order of Deployment

1. ✅ **vm2.TestUtilities** (simplest - single project)
2. **vm2.Glob** (more complex - two packages with pipe separator)
3. **vm2.Ulid** (validation of consistency)

### For Each Repository

1. Run Phase 1 (CI) first
2. Run Phase 2 (Prerelease) second
3. Run Phase 3 (Release) only if both above succeed
4. Document any edge cases or issues encountered

---

## Important Reminders

### Security Fixes Applied

- ✅ Input sanitization added to all scripts
- ✅ Secrets properly passed as environment variables
- ✅ Shell injection risks mitigated

### Critical Files Modified

- `.github/workflows/_prerelease.yaml` - Added secrets env block (lines 200-202)
- `.github/workflows/_release.yaml` - Added secrets env block (lines 183-185)
- `_common_semver.sh` - Fixed BASH_REMATCH indexing
- `_common_sanitize.sh` - NEW - Input validation functions
- `create-release-tag.sh` - Removed duplicate git tag, added error handling
- All version/publish scripts - Added sanitization calls

### Key Testing Focus Areas

1. **Version Calculation:** Verify conventional commits drive version bumps correctly
2. **Secrets Access:** Confirm no "No API key" errors appear
3. **Changelog Updates:** Ensure git-cliff produces correct changelog entries
4. **Package Publishing:** Validate packages appear on target servers
5. **Concurrency:** Test what happens if two PRs merge simultaneously
6. **Error Recovery:** If failures occur, use ERROR_RECOVERY.md procedures

---

## Quick Command Reference

### Check Workflow Status

```bash
gh run list --repo vmelamed/vm2.TestUtilities
gh run view <run-id> --repo vmelamed/vm2.TestUtilities
```

### Check Secrets

```bash
gh secret list --repo vmelamed/vm2.TestUtilities
```

### Check Tags

```bash
git fetch --tags
git tag -l | sort -V
```

### View Changelog

```bash
git pull
cat CHANGELOG.md | head -50
```

### Check Package on NuGet.org

```bash
# Search for package
dotnet package search vm2.TestUtilities --source https://api.nuget.org/v3/index.json
```

---

## Success Criteria

**Phase 1 Complete When:**

- ✅ CI workflow runs without errors
- ✅ All tests pass
- ✅ Coverage reports generated

**Phase 2 Complete When:**

- ✅ Prerelease version calculated correctly
- ✅ CHANGELOG.md updated with prerelease entry
- ✅ Prerelease tag created
- ✅ Package published to NuGet server(s)
- ✅ No security errors or warnings

**Phase 3 Complete When:**

- ✅ Stable version calculated correctly
- ✅ CHANGELOG.md updated with release section
- ✅ Release tag created with annotation
- ✅ Stable package published to NuGet.org
- ✅ GitHub Release created

**Ready for Rollout When:**

- ✅ All three phases complete successfully
- ✅ No blocking issues discovered
- ✅ Error recovery procedures validated (if needed)

---

## Notes & Observations

*(Use this section to document any findings during testing)*

---

**Last Updated:** January 15, 2026
**Status:** Ready for testing
