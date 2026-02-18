# Error Recovery

Recovery procedures for common CI/CD failure scenarios.

## General Principles

- **Never retag** a pushed version — immutability ensures reproducibility.
- **Prerelease versions are disposable** — fix the issue, merge again, and a new prerelease is published automatically.
- **Stable releases are sequential** — if a release fails, fix and re-run; the version computation will produce the same result
  until the tag is created.

## Prerelease Failures

### NuGet Push Failed

The prerelease workflow does not create Git tags — MinVer computes the prerelease version from commit distance. A failed push
has no side effects on Git state.

**Recovery:** Fix the cause (API key, network), then either:

- Re-run the failed workflow job: `gh run rerun <run-id> --failed`
- Or merge any new PR — the next prerelease will supersede the failed one

### Changelog PR Creation Blocked

The prerelease changelog step creates a PR for the changelog update. If the repository doesn't allow GitHub Actions to create
PRs, the step logs a warning but the publish still proceeds.

**Recovery:** Enable Settings → Actions → General → Allow GitHub Actions to create and approve pull requests. Or update
CHANGELOG.md manually.

## Stable Release Failures

The release workflow runs three sequential jobs: `compute-version` → `changelog-and-tag` → `release`. Failure at each stage has
different recovery procedures.

### Version Computation Failed

No side effects — nothing was committed or tagged.

**Recovery:** Fix the issue (e.g. commit messages, tag conflicts) and re-run the workflow.

### Changelog Committed But Tag Not Created

The `changelog-and-tag.sh` script commits the changelog first, then creates the tag. If tagging fails after the changelog push:

```bash
# Revert the changelog commit
git checkout main && git pull
git revert HEAD --no-edit -m 1
git push origin main

# Re-run the release workflow
```

### Tag Created But NuGet Push Failed

The tag and changelog are on `main`, but the package wasn't published.

```bash
# Option A: Re-run the failed job
gh run rerun <run-id> --failed

# Option B: Delete tag, revert changelog, and retry from scratch
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3
git checkout main && git pull
git revert HEAD --no-edit
git push origin main
# Re-run the release workflow
```

### Package Version Already Exists on NuGet

NuGet.org does not allow replacing published packages.

```bash
# Delete the tag
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3

# Deprecate the old package via NuGet.org UI

# The next release will compute the next version (v1.2.4 or higher)
```

## Infrastructure Failures

### NuGet Server Down

Check [status.nuget.org](https://status.nuget.org/). Wait for recovery, then re-run the failed job:

```bash
gh run rerun <run-id> --failed
```

### Invalid or Expired API Key

```bash
# Verify secrets exist
gh secret list

# Regenerate on NuGet.org and update
gh secret set NUGET_API_NUGET_KEY
```

### Cache-Related Build Failures

Run the ClearCache workflow: Actions → ClearCache → Run workflow. See [CACHE_MANAGEMENT.md](CACHE_MANAGEMENT.md).

## Useful Commands

```bash
# Check recent workflow runs
gh run list --workflow=Release.yaml --limit 5

# View run logs
gh run view <run-id> --log

# List tags
git fetch --tags && git tag | sort -V | tail -5

# Check published package versions
curl -s "https://api.nuget.org/v3-flatcontainer/<package-id>/index.json" | jq '.versions[-5:]'

# Delete a local + remote tag
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
```

## Further Reading

| Topic              | Document                                         |
| :----------------- | :----------------------------------------------- |
| Release process    | [RELEASE_PROCESS.md](RELEASE_PROCESS.md)         |
| Cache management   | [CACHE_MANAGEMENT.md](CACHE_MANAGEMENT.md)       |
| Configuration      | [CONFIGURATION.md](CONFIGURATION.md)             |
