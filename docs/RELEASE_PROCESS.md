# Release Process

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
| NuGet package version          | Git tag (or MinVer-computed prerelease if commits ahead)   |
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

| Flow       | Trigger                                            | Version Format                                    | NuGet Package |
| :--------- | :------------------------------------------------- | :------------------------------------------------ | :------------ |
| Prerelease | PR merge → push to `main` → CI success (automated) | MinVer-computed prerelease                        | Preview       |
| Release    | Manual `workflow_dispatch`                         | Computed stable `X.Y.Z` from conventional commits | Stable        |

Both flows call the same `publish-package.sh` script for the final build → pack → push steps.

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
                    │  changelog (job 1)  │
                    │  * git-cliff        │
                    │  * create PR for    │
                    │    CHANGELOG update │
                    └─────────┬───────────┘
                              │
                              ↓
                    ┌──────────────────────┐
                    │ package-and-publish  │
                    │  (job 2, per project)│
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

**Version**: MinVer computes the prerelease version automatically — it sees HEAD is ahead of the latest stable tag and appends
the prerelease identifier (e.g. `v1.2.3-preview.0.1`). No version computation script is involved.

**Changelog**: `git-cliff` generates a changelog entry and opens a PR (rather than pushing directly to `main`), to comply with
branch protection rules.

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

### Version Calculation Algorithm

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

4. **Prerelease guard**: if the latest prerelease tag (e.g. `v2.0.0-preview.0.3`) is *higher* than the computed release version,
   the release version adopts the prerelease's major.minor.patch. This prevents publishing a stable version lower than an
   existing prerelease.

5. **Duplicate guard**: if `HEAD` is already tagged or the computed tag already exists, the script fails with an error and
   suggests remediation.

### Changelog and Tagging

The `changelog-and-tag.sh` script:

1. Runs `git-cliff` with `changelog/cliff.release-header.toml` to prepend the release entry to `CHANGELOG.md`.
2. Commits and pushes the changelog update directly to `main`.
3. Creates an annotated tag (`git tag -a vX.Y.Z -m "Release vX.Y.Z"`) and pushes it.

The release job then checks out this tag so MinVer resolves the exact stable version.

## Initial Bootstrapping

If no stable tag exists yet:

```bash
git tag -a v0.1.0 -m "Initial baseline"
git push origin v0.1.0
```

Subsequent PR merges create MinVer-computed prereleases automatically. The first stable release
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

## Further Reading

| Topic              | Document                                         |
| :----------------- | :----------------------------------------------- |
| Architecture       | [ARCHITECTURE.md](ARCHITECTURE.md)               |
| Workflow reference | [WORKFLOWS_REFERENCE.md](WORKFLOWS_REFERENCE.md) |
| Script reference   | [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md)     |
| Configuration      | [CONFIGURATION.md](CONFIGURATION.md)             |
| Error recovery     | [ERROR_RECOVERY.md](ERROR_RECOVERY.md)           |
