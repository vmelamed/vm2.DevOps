# Release Process

<!-- TOC tocDepth:2..5 chapterDepth:2..6 -->

- [Development Model](#development-model)
- [Version Source: MinVer](#version-source-minver)
- [Two Publishing Flows](#two-publishing-flows)
- [Prerelease Flow](#prerelease-flow)
- [Stable Release Flow](#stable-release-flow)
  - [Release Version Calculation Algorithm](#release-version-calculation-algorithm)
  - [Prerelease Version Calculation Algorithm](#prerelease-version-calculation-algorithm)
  - [Changelog and Tagging](#changelog-and-tagging)
- [Changelog Strategy](#changelog-strategy)
- [Initial Bootstrapping](#initial-bootstrapping)
- [NuGet Server Selection](#nuget-server-selection)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)
  - [Branch Protection Bypass](#branch-protection-bypass)

<!-- /TOC -->

How versioning, prerelease publishing, and stable release publishing work in the vm2 CI/CD system.

## Development Model

The vm2 repositories follow **trunk-based development** with **continuous delivery**:

- **Single trunk** (`main`) — all work merges via short-lived feature branches and pull requests
- **No long-lived branches** — no `develop`, `staging`, or `release` branches
- **Automated prerelease on every merge** — each PR merge to `main` triggers CI, and on success, a preview NuGet package is
  published automatically
- **Manual stable release** — a human decides *when* to promote to a stable release via `workflow_dispatch`; the *what* (version
  number) is computed automatically from conventional commits

This is a **library release model** layered on trunk-based development: every merge produces a consumable prerelease artifact, and stable releases are batched by human decision.

## Version Source: MinVer

All version numbers are derived from Git tags by [MinVer](https://github.com/adamralph/minver).

| Aspect                         | Value                                                      |
| :----------------------------- | :--------------------------------------------------------- |
| NuGet package version          | Git tag (exact match for releases and prereleases)         |
| `AssemblyInformationalVersion` | Full SemVer string including prerelease + commit metadata  |
| `FileVersion`                  | `Major.Minor.Patch.0`                                      |
| `AssemblyVersion`              | `Major.0.0.0` (MinVer default — keeps binding stable)      |

MinVer is declared once in `Directory.Build.props` (via Central Package Management) so all packable projects get it:

```xml
<!-- Directory.Packages.props -->
<PackageVersion Include="MinVer" Version="6.0.0" />

<!-- Directory.Build.props -->
<PackageReference Include="MinVer" PrivateAssets="all" />
```

The tag prefix is `v` (e.g. `v1.2.3`), configured via the `MINVERTAGPREFIX` repository variable.

## Two Publishing Flows

| Flow       | Trigger                                             | Version Format                    | NuGet Package |
| :--------- | :-------------------------------------------------- | :-------------------------------- | :------------ |
| Prerelease | PR merge → push to `main` → CI success (automated)  | `X.Y.Z-preview.N` (computed)      | Preview       |
| Release    | Manual `workflow_dispatch`                          | `X.Y.Z` (computed)                | Stable        |

Both flows share the same `changelog-and-tag.sh` and `publish-package.sh` scripts for changelog updates, tagging, and publishing.

## Prerelease Flow

```text
PR merged → push to main → CI workflow runs
                              │
                              │ (on success)
                              ↓
                        Prerelease workflow
                              │
                              ↓
                    ┌─────────────────────┐
                    │  compute-version    │
                    │  (job 1)            │
                    │  * scan commits     │
                    │  * determine bump   │
                    │  * compute preview  │
                    │    counter          │
                    └─────────┬───────────┘
                              │
                              ↓
                    ┌─────────────────────┐
                    │  changelog-and-tag  │
                    │  (job 2)            │
                    │  * git-cliff with   │
                    │    cliff.prerelease │
                    │    .toml            │
                    │  * commit + push    │
                    │    CHANGELOG.md     │
                    │  * git tag + push   │
                    └─────────┬───────────┘
                              │
                              ↓
                    ┌──────────────────────┐
                    │ package-and-publish  │
                    │  (job 3, per project)│
                    │  * checkout tag      │
                    │  * dotnet restore    │
                    │  * dotnet pack       │
                    │  * dotnet nuget push │
                    └──────────────────────┘
```

**Trigger guard** (in consumer `Prerelease.yaml`):

```yaml
if: |
  github.event_name == 'workflow_dispatch' ||
  ( github.event_name == 'workflow_run' &&
    github.event.workflow_run.conclusion == 'success' &&
    github.event.workflow_run.event == 'push' &&
    github.event.workflow_run.head_branch == 'main' )
```

This ensures prereleases only fire after a successful CI run on `main` (i.e. merged PRs), never from CI runs on feature branches.

**Version**: The `compute-prerelease-version.sh` script determines the next prerelease version by scanning conventional commits
since the last stable tag and appending a `-preview.N` suffix. The counter increments within the same base version and resets
when the bump type changes.

**Changelog**: `changelog-and-tag.sh` runs `git-cliff` with `cliff.prerelease.toml` to add an entry directly to `CHANGELOG.md`
on `main`, then creates and pushes the prerelease tag. This mirrors the stable release pattern — direct commit via `RELEASE_PAT`
to bypass branch protection.

**Manual trigger**: The prerelease workflow also supports `workflow_dispatch` with a custom `minver-prerelease-id` input (e.g.
`alpha`, `beta`, `rc1`).

## Stable Release Flow

```text
Manual workflow_dispatch (with reason)
           │
           ↓
  ┌────────────────────┐
  │  compute-version   │
  │  (job 1)           │
  │  * scan commits    │
  │  * determine bump  │
  │  * guard against   │
  │    prerelease      │
  └────────┬───────────┘
           │
           ↓
  ┌────────────────────┐
  │  changelog-and-tag │
  │  (job 2)           │
  │  * git-cliff       │
  │  * commit + push   │
  │    CHANGELOG.md    │
  │  * git tag + push  │
  └────────┬───────────┘
           │
           ↓
  ┌────────────────────┐
  │  release           │
  │  (job 3, per       │
  │   project)         │
  │  * checkout tag    │
  │  * dotnet restore  │
  │  * dotnet pack     │
  │  * dotnet nuget    │
  │    push            │
  └────────────────────┘
```

### Release Version Calculation Algorithm

The `compute-release-version.sh` script determines the next stable version:

1. **Find latest stable tag** — filter `v*` tags matching the release regex (`vX.Y.Z` with no hyphen), sort semantically, take
   the highest.

2. **Scan conventional commits** since that tag:

   | Commit Pattern                              | Bump  | Example                              |
   | :------------------------------------------ | :---- | :----------------------------------- |
   | `^[a-z]+(\(.+\))?!:` or `BREAKING CHANGE:`  | Major | `feat!: redesign API`                |
   | `^feat(\(.+\))?:`                           | Minor | `feat(parser): add glob negation`    |
   | Everything else                             | Patch | `fix: handle null input`             |

3. **SemVer floor**: if the computed major is `0`, the version is raised to `1.0.0` (SemVer 2.0.0 requires major ≥ 1 for
   releases).

4. **Prerelease guard**: if the latest prerelease tag (e.g. `v2.0.0-preview.3`) is *higher* than the computed release version,
   the release version adopts the prerelease's major.minor.patch. This prevents publishing a stable version lower than an
   existing prerelease.

5. **Duplicate guard**: if `HEAD` is already tagged or the computed tag already exists, the script fails with an error and
   suggests remediation.

### Prerelease Version Calculation Algorithm

The `compute-prerelease-version.sh` script determines the next prerelease version:

1. **Find latest stable and prerelease tags** — both are needed to determine the base version and counter.

2. **Scan conventional commits** since the last stable tag — same bump logic as the release algorithm.

3. **SemVer floor**: same `1.0.0` minimum.

4. **Compute the prerelease counter**:
   - If the latest prerelease has the same base version → increment the counter (`preview.N+1`)
   - If the base version changed (e.g. new `feat:` appeared) → reset counter to `1`
   - If no previous prerelease exists → start at `1`

5. **Duplicate guard**: same as release.

Example: latest stable `v1.2.3`, latest prerelease `v1.3.0-preview.2`, new commit is `fix: typo`:

- Commits since `v1.2.3` include a `feat:` → minor bump → base `1.3.0`
- Same base as latest prerelease → counter = 2 + 1 = **3**
- Result: `v1.3.0-preview.3`

### Changelog and Tagging

The `changelog-and-tag.sh` script is shared by both flows:

1. **Detects the tag type** (release or prerelease) and selects the appropriate git-cliff config:
   - Stable release → `cliff.release-header.toml` (outputs "See prereleases below.")
   - Prerelease → `cliff.prerelease.toml` (outputs a full commit-level changelog entry)
2. **Determines the commit range**:
   - Stable release → from last stable tag to HEAD
   - Prerelease → from last tag (any type) to HEAD
3. Commits and pushes the changelog update directly to `main`.
4. Creates an annotated tag and pushes it.

The publish job then checks out this tag so MinVer resolves the exact version.

## Changelog Strategy

Each prerelease gets its own entry in `CHANGELOG.md` — a detailed, commit-level record generated by `cliff.prerelease.toml`.

When a stable release is cut, `cliff.release-header.toml` adds a header entry that says "See prereleases below." This works
because the prerelease entries immediately below it already contain everything. No information is duplicated.

## Initial Bootstrapping

If no stable tag exists yet:

```bash
git tag -a v0.1.0 -m "Initial baseline"
git push origin v0.1.0
```

Subsequent PR merges create prerelease packages automatically. The first stable release
(via `workflow_dispatch`) will compute `v1.0.0` due to the SemVer floor.

## NuGet Server Selection

The `NUGET_SERVER` variable (or `nuget-server` input) determines where packages are pushed:

| Value      | Server                                             | API Key Secret           |
| :--------- | :------------------------------------------------- | :----------------------- |
| `github`   | `https://nuget.pkg.github.com/{owner}/index.json`  | `NUGET_API_GITHUB_KEY`   |
| `nuget`    | `https://api.nuget.org/v3/index.json`              | `NUGET_API_NUGET_KEY`    |
| Custom URL | The URL as provided                                | `NUGET_API_KEY`          |

`NUGET_API_KEY` is also the fallback if the server-specific secret is not defined.

## Quick Reference

| Action                          | How                                                                         |
| :------------------------------ | :-------------------------------------------------------------------------- |
| Trigger a prerelease            | Merge a PR to `main` (automatic after CI)                                   |
| Trigger a manual prerelease     | Actions → Publish NuGet Pre-Release → Run workflow                          |
| Trigger a stable release        | Actions → Publish NuGet Stable Release → Run workflow (provide reason)      |
| Inspect version locally         | `dotnet build -c Release -p:MinVerVerbosity=detailed`                       |
| Dry-run pack                    | `dotnet pack -c Release -o artifacts -p:MinVerTagPrefix=v`                  |
| Force a prerelease without code | `git commit --allow-empty -m "chore: trigger prerelease" && git push`       |
| Bootstrap first tag             | `git tag -a v0.1.0 -m "Initial baseline" && git push origin v0.1.0`         |

## Troubleshooting

| Symptom                              | Cause                       | Fix                                                                            |
| :----------------------------------- | :-------------------------- | :----------------------------------------------------------------------------- |
| Version always `0.0.0-alpha.0`       | No reachable tag            | Create initial tag (`v0.1.0`)                                                  |
| Prerelease not created after PR      | CI didn't succeed           | Check CI workflow run; fix failures                                            |
| Wrong bump type (patch vs minor)     | Commit messages don't match | Use conventional commit format: `feat:` for minor, `fix:` for patch            |
| Tag already exists error             | Duplicate release attempt   | Delete the tag, or release with a higher version                               |
| NuGet push fails (401/403)           | Invalid or missing API key  | Verify the `NUGET_API_*` secret matches the configured `NUGET_SERVER`          |
| Package version already exists       | Immutable NuGet versions    | Increment version; deprecate old package via NuGet.org UI                      |

### Branch Protection Bypass

Both the prerelease and release workflows push changelog commits and tags directly to `main`. Since `main` is protected by
repository rulesets requiring status checks, workflows must authenticate with a fine-grained Personal Access Token (`RELEASE_PAT`
secret) rather than the default `GITHUB_TOKEN`.

The PAT owner must be listed as a **Repository Admin** bypass actor in the ruleset. Create the PAT
with `contents: write` scope, scoped to the relevant repositories.
