# Error Recovery Guide for DevOps Workflows

## Common Failure Scenarios and Recovery Procedures

### 1. Prerelease Tag Created But Push to NuGet Failed

**Symptoms:**

- Git tag exists (e.g., `v1.2.3-preview.20260115.123`)
- Package not published to NuGet
- Workflow failed at publish step

**Recovery:**

```bash
# Option A: Delete tag and re-run workflow
git tag -d v1.2.3-preview.20260115.123
git push origin :refs/tags/v1.2.3-preview.20260115.123

# Trigger new prerelease workflow
# The next run will get a new timestamp and version

# Option B: Manual publish (if tag should be kept)
dotnet pack src/YourProject/YourProject.csproj \
    --configuration Release \
    --output ./artifacts/pack \
    /p:MinVerTagPrefix=v

dotnet nuget push ./artifacts/pack/*.nupkg \
    --source https://api.nuget.org/v3/index.json \
    --api-key $NUGET_API_KEY
```

**Prevention:**

- Ensure API keys are valid before running workflow
- Test with `--dry-run` locally (when implemented)

---

### 2. Release Tag Created But Changelog Not Committed

**Symptoms:**

- Tag exists on remote (e.g., `v1.2.3`)
- CHANGELOG.md not updated in main branch
- Workflow failed after tag creation

**Recovery:**

```bash
# 1. Check out main and pull latest
git checkout main
git pull origin main

# 2. Manually update changelog
git-cliff -c changelog/cliff.release-header.toml \
    --tag v1.2.3 \
    --prepend CHANGELOG.md \
    v1.2.2..v1.2.3

# 3. Commit and push
git add CHANGELOG.md
git commit -m "chore: update changelog for v1.2.3"
git push origin main

# 4. Move the tag to include changelog commit
git tag -d v1.2.3
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3 --force
```

**Prevention:**

- Workflow now has better error handling for git operations
- Changelog job runs before tagging

---

### 3. Release Tag Exists But Package Not Published

**Symptoms:**

- Tag exists on GitHub (e.g., `v1.2.3`)
- Package not on NuGet.org
- Workflow failed during publish step

**Recovery:**

```bash
# Option A: Delete tag and retry entire release
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3

# Revert changelog commit if it was pushed
git revert HEAD --no-edit
git push origin main

# Re-run release workflow

# Option B: Manually publish from the tag
git checkout v1.2.3

dotnet restore --locked-mode
dotnet pack src/YourProject/YourProject.csproj \
    --configuration Release \
    --output ./artifacts/pack \
    /p:MinVerTagPrefix=v

dotnet nuget push ./artifacts/pack/*.nupkg \
    --source https://api.nuget.org/v3/index.json \
    --api-key $NUGET_API_KEY \
    --skip-duplicate
```

**Best Practice:**

- Use Option B (manual publish) if tag has been public for >1 hour
- Use Option A (delete and retry) if tag was just created

---

### 4. Concurrent Release Attempts (Race Condition)

**Symptoms:**

- Error: "Tag v1.2.3 already exists"
- Two workflows triggered simultaneously
- One succeeded, one failed

**Recovery:**

```bash
# 1. Identify which workflow succeeded
gh run list --workflow=Release.yaml --limit 5

# 2. Verify the tag and package
git fetch --tags
git tag | grep v1.2.3
# Check NuGet.org for package

# 3. If package is published correctly, no action needed
# If not published, follow "Release Tag Exists But Package Not Published"

# 4. Cancel the duplicate workflow run if still running
gh run cancel <run-id>
```

**Prevention:**

- Workflow already has concurrency control (`concurrency: group: ci-${{ github.ref }}`)
- Check for existing tags before creating new ones

---

### 5. Version Calculation Incorrect (Wrong Bump Type)

**Symptoms:**

- Expected minor bump (1.2.0 → 1.3.0) but got patch (1.2.1)
- Conventional commits not detected properly

**Recovery:**

```bash
# If package NOT yet published:
git tag -d v1.2.1
git push origin :refs/tags/v1.2.1

# Fix commit messages if needed
git rebase -i HEAD~5  # Adjust commit count as needed
# Change commit messages to proper conventional format:
# feat: new feature     (for minor bump)
# fix: bug fix         (for patch bump)
# BREAKING CHANGE:     (for major bump)

# Re-run release workflow

# If package ALREADY published:
# Create a new prerelease with correct version
# Then create proper release
```

**Prevention:**

- Use conventional commits format strictly
- Review version calculation in workflow summary before publishing

---

### 6. NuGet Server Temporarily Down

**Symptoms:**

- 503 Service Unavailable
- Timeout errors
- Package built successfully but push failed

**Recovery:**

```bash
# 1. Wait for service to recover (check status.nuget.org)

# 2. Re-run the failed workflow job
gh run rerun <run-id> --failed

# OR manually publish the artifact
gh run download <run-id> -n nuget-packages-v1.2.3-<hash>
dotnet nuget push *.nupkg \
    --source https://api.nuget.org/v3/index.json \
    --api-key $NUGET_API_KEY \
    --skip-duplicate
```

---

### 7. Invalid API Key or Permissions

**Symptoms:**

- 401 Unauthorized or 403 Forbidden
- "API key is invalid" error

**Recovery:**

```bash
# 1. Verify API key in GitHub Secrets
gh secret list

# 2. Regenerate API key on NuGet.org or GitHub Packages

# 3. Update GitHub secret
gh secret set NUGET_API_NUGET_KEY

# 4. Re-run workflow
gh workflow run Release.yaml
```

---

### 8. Package Already Exists (Duplicate Version)

**Symptoms:**

- Error: "Package version already exists"
- `--skip-duplicate` prevented error but package not updated

**Recovery:**

```bash
# NuGet.org does NOT allow replacing packages
# You MUST increment version

# 1. Delete the git tag
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3

# 2. Deprecate/obsolete the old package on NuGet.org
# (Do this via NuGet.org web interface)

# 3. Create new version
# Trigger new release workflow - will auto-bump to v1.2.4
```

**Important:** This aligns with your "no force/republish" philosophy!

---

## General Recovery Commands

### Check Workflow Status

```bash
# List recent workflow runs
gh run list --workflow=Release.yaml --limit 10

# View specific run
gh run view <run-id>

# View logs
gh run view <run-id> --log
```

### Check Published Packages

```bash
# Check NuGet.org
curl -s "https://api.nuget.org/v3-flatcontainer/yourpackage/index.json" | jq '.versions'

# Check GitHub Packages
gh api /user/packages/nuget/YourPackage/versions
```

### Clean Up Failed State

```bash
# Remove local tag
git tag -d v1.2.3

# Remove remote tag
git push origin :refs/tags/v1.2.3

# Revert changelog commit
git revert <commit-hash> --no-edit
git push origin main
```

---

## Workflow Re-run Best Practices

1. **Always check current state first**

   ```bash
   git fetch --tags
   git tag | grep v1.2
   ```

2. **Verify what was published**
   - Check NuGet.org package page
   - Check GitHub Releases
   - Check CHANGELOG.md in main branch

3. **Clean up before retry**
   - Delete failed tags
   - Revert failed changelog commits
   - Ensure main branch is clean

4. **Re-run with awareness**
   - Prerelease: Will get new timestamp automatically
   - Release: May need to manually trigger or create PR

---

## Emergency Contacts & Resources

- **NuGet.org Status**: <https://status.nuget.org/>
- **GitHub Status**: <https://www.githubstatus.com/>
- **Package Management**: Contact package owner (you!)
- **API Key Rotation**: <https://www.nuget.org/account/apikeys>
