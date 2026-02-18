# Cache Management

How NuGet dependency caching works in the vm2 CI/CD pipeline and how to manage it.

## Caching Strategy

The pipeline uses a **multi-layer caching approach** to balance build speed with dependency freshness:

| Layer                      | Mechanism                                                   | Status  |
| :------------------------- | :---------------------------------------------------------- | :------ |
| Package lock files         | `packages.lock.json` ensures deterministic restores         | Done    |
| Dependabot                 | Weekly automated PRs for dependency updates                 | Done    |
| Weekly cache rotation      | Calendar-week key in cache forces refresh every Monday      | Done    |
| Manual cache clear         | `_clear_cache` workflow for emergency invalidation          | Done    |
| Cache age monitoring       | Warn when cached packages are older than a threshold        | Planned |
| Scheduled cache cleanup    | Automatic deletion of caches older than N days              | Planned |

## How It Works

### Package Lock Files

`Directory.Build.props` enables deterministic package resolution:

```xml
<RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
<RestoreLockedMode Condition="'$(CI)' == 'true'">true</RestoreLockedMode>
```

- CI builds fail if `packages.lock.json` is out of date (locked mode).
- Developers update lock files locally with `dotnet restore --force-evaluate` and commit the result.
- Cache keys include `**/packages.lock.json`, so any dependency change invalidates the cache.

### Weekly Cache Rotation

All three CI workflows (`_build`, `_test`, `_benchmarks`) compute a weekly cache key:

```yaml
- name: Get cache timestamp (weekly rotation)
  id: cache-timestamp
  run: echo "week=$(date +%Y-W%V)" >> "$GITHUB_OUTPUT"
```

This key feeds into two cache layers:

1. **`actions/setup-dotnet`** built-in cache (keyed on `packages.lock.json` + `*.csproj`)
2. **Explicit `actions/cache@v5`** with the weekly rotation key:

   ```yaml
   key: nuget-{os}-{week}-{hash(packages.lock.json)}
   restore-keys:
     nuget-{os}-{week}-
     nuget-{os}-
   ```

The first build each week downloads fresh packages; subsequent builds within the same week hit cache.

### Dependabot

Weekly Dependabot PRs update NuGet packages and GitHub Actions versions. When merged, the updated
`packages.lock.json` files naturally invalidate the NuGet cache. See the `dependabot.yml` template
in [CONSUMER_GUIDE.md](CONSUMER_GUIDE.md).

### Bencher CLI Cache

The `_benchmarks` workflow separately caches the Bencher CLI binary at `~/.cargo/bin/bencher`,
also rotated weekly:

```yaml
key: bencher-cli-{os}-{week}
```

## Manual Cache Clear

The `_clear_cache` reusable workflow deletes caches matching a specified pattern. Trigger it via
Actions → ClearCache → Run workflow.

Allowed patterns (enforced by allowlist):

| Pattern              | What it clears          |
| :------------------- | :---------------------- |
| `nuget-`             | NuGet package caches    |
| `build-artifacts-`   | Build artifact caches   |
| `bencher-cli-`       | Bencher CLI cache       |

## MTP v1 vs v2 Lock File Interaction

Visual Studio uses MTP v1 (via `BuildingInsideVisualStudio`), while CI and VS Code use MTP v2.
The two platforms pull different test packages, which causes lock file divergence.

**Workaround for Visual Studio users:**

```bash
# After pulling from GitHub — re-evaluate for VS:
BuildingInsideVisualStudio=true dotnet restore --force-evaluate

# Before committing — restore lock files to CI state:
dotnet restore --force-evaluate
git add **/packages.lock.json
```

This is temporary until Visual Studio adopts MTP v2.

## Troubleshooting

| Problem                                          | Solution                                                        |
| :----------------------------------------------- | :-------------------------------------------------------------- |
| Build fails with "restore failed in locked mode" | Run `dotnet restore --force-evaluate` and commit lock files     |
| Cache size approaching 10 GB limit               | Run ClearCache workflow; consider reducing rotation period      |
| First build of week is slow                      | Expected — weekly rotation downloads fresh packages             |
| Dependabot PRs failing tests                     | Review changelog for breaking changes; update code accordingly  |

## Further Reading

| Topic              | Document                                         |
| :----------------- | :----------------------------------------------- |
| Configuration      | [CONFIGURATION.md](CONFIGURATION.md)             |
| Workflow reference | [WORKFLOWS_REFERENCE.md](WORKFLOWS_REFERENCE.md) |
| Error recovery     | [ERROR_RECOVERY.md](ERROR_RECOVERY.md)           |
