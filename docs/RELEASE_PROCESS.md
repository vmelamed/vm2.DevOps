# Release Process

This document explains how versioning, prerelease, and stable release automation publishing work for the vm2 repositories.

---

## 1. Version Source (MinVer)

We use [MinVer] to derive all version numbers from Git tags.

| Aspect                       | Source                                     |
| ---------------------------- | ------------------------------------------ |
| NuGet package version        | Git tag (or computed prerelease if ahead)  |
| AssemblyInformationalVersion | Full SemVer (incl. prerelease)             |
| FileVersion                  | Major.Minor.Patch.0                        |
| AssemblyVersion (binding)    | Major.0.0.0 (MinVer default for stability) |

We use central package management. Central version declaration exists in `Directory.Packages.props`:

```xml
<PackageVersion Include="MinVer" Version="6.0.0" />
```

The actual activation is via:

```xml
<PackageReference Include="MinVer" PrivateAssets="all" />
```

(Defined once in `Directory.Build.props` so all packable projects get it.)

### Optional MinVer knobs (only add if needed)

```xml
<PropertyGroup>
    <!-- Tag prefix (we use 'v' like v1.2.3) -->

    <MinVerTagPrefix>v</MinVerTagPrefix>

    <!-- Force a prerelease label when not on a tag (disabled now – prerelease tags are created instead) -->
    <!-- <MinVerDefaultPreReleaseIdentifiers>preview</MinVerDefaultPreReleaseIdentifiers> -->

    <!-- If you ever want AssemblyVersion = Major.Minor.Patch.0 -->
    <!-- <MinVerMajorMinorPatch>true</MinVerMajorMinorPatch> -->

</PropertyGroup>
```

---

## 2. Flows Overview

| Flow                    | Trigger                                            | Tag Format                                | Publishes?       | Result                   |
| ----------------------- | -------------------------------------------------- | ----------------------------------------- | ---------------- | ------------------------ |
| Local build (no tag)    | `dotnet build`                                     | Computed prerelease (if no tag reachable) | No               | For development only     |
| Prerelease (automated)  | Merge (push) to `main` (commit not already tagged) | `vX.Y.(Z+1)-preview.YYYYMMDD.<run>`       | Yes (prerelease) | Preview package on NuGet |
| Stable release (manual) | **Manually** activated, computed tag from commits  | `vX.Y.Z`                                  | Yes (stable)     | Final package on NuGet   |

---

## 3. Automated Prerelease Tagging

Workflow: the current repo's `.github/workflows/Prerelease.yml` is triggered on push to `main` (PR).

Logic:

1. On push to `main`, check if `HEAD` already has a `v*` tag.
1. If not, find latest stable `vX.Y.Z` (no hyphen).
1. Increment patch to `Z+1` to form base.
1. Create prerelease tag: `vX.Y.(Z+1)-preview.<UTCDate>.<GitHubRunNumber>`
1. Push tag.
1. Build, pack, publish to NuGet using MinVer (tag-driven).

Rationale: _Stable tags remain human-initiated; prereleases always advance from the last stable._

---

## 4. Stable Release

Manual steps:

1. Trigger the Release workflow via GitHub UI or CLI:

```bash
gh release create vX.Y.Z --generate-notes
```

This triggers `.github/workflows/Release.yml`, which:

1. Restore.
1. Build, pack, publish to NuGet using MinVer (tag-driven).
1. Publishes `.nupkg` + `.snupkg` to NuGet (with symbol/source link).

---

## 5. Secrets & Requirements

| Secret                 | Purpose                             |
| ---------------------- | ----------------------------------- |
| `NUGET_API_GITHUB_KEY` | Pushing packages to GitHub Packages |
| `NUGET_API_NUGET_KEY`  | Pushing packages to NuGet.org       |
| `NUGET_API_KEY`        | Pushing packages to another server  |

The key values are the respective API keys from the package hosts, stored as GitHub repository secrets. No need to define all
if not used. Also `NUGET_API_KEY` is generic for any server, e.g. if the server is NuGet.org and `NUGET_API_NUGET_KEY` is not
defined, `NUGET_API_KEY` is used.

Ensure branch protection on `main` with `build`, `test`, and `benchmark` if present, so only reviewed code generates prereleases.

---

## 6. Initial Bootstrapping

If no stable tag exists yet:

```bash
git tag -a v0.1.0 -m "Initial baseline"
git push origin v0.1.0
```

Subsequent merges create `v0.1.1-preview.*` prereleases automatically.

---

## 7. Verifying a Build Locally

```bash
dotnet clean
dotnet build -c Release -p:MinVerVerbosity=detailed
```

Inspect produced dll

```bash
dotnet tool install -g dotnet-ildasm
dotnet-ildasm src/UlidType/bin/Release/net10.0/UlidType.dll | grep InformationalVersion
```

Or:

```bash
strings src/UlidType/bin/Release/net10.0/UlidType.dll | grep InformationalVersion
```

Or

```powershell
# PowerShell
([System.Reflection.Assembly]::LoadFrom("src/UlidType/bin/Release/net10.0/UlidType.dll")).GetCustomAttributes(
   [System.Reflection.AssemblyInformationalVersionAttribute], $false).InformationalVersion
```

Or

```powershell
# PowerShell
(Get-ItemProperty -Path src/UlidType/bin/Release/net9.0/UlidType.dll).VersionInfo.ProductVersion
```

---

## 8. Changelog Integration (Optional)

Maintaining `CHANGELOG.md`:

1. During development: append under `## [Unreleased]`.
1. Before stable tag: move `Unreleased` content under `## [X.Y.Z] - YYYY-MM-DD`.
1. Commit & tag.

---

## 9. Rollback / Yank Procedure

If a broken prerelease:

1. Delete the package version on NuGet (if urgent) or leave (prereleases seldom consumed widely).
1. Revert offending commit(s) on `main`.
1. A new prerelease tag will be created on next push automatically.

If a broken stable:

1. Create a patch fix commit.
1. Tag next patch: `vX.Y.(Z+1)`.

Never retag an existing pushed version (immutability ensures reproducibility).

---

## 10. Forcing a New Prerelease Without Code Changes

Empty commit then push

```bash
git checkout main
git pull
git commit --allow-empty -m "Trigger prerelease"
git push
```

Generates a new prerelease tag & package.

---

## 11. Adding Another Prerelease Channel

Example: introduce `beta` before `preview`.

Adjust prerelease workflow compute step to decide label:

- Use `beta` if feature freeze label file exists.
- Fallback to `preview`.

Or define environment-driven label:

```bash
LABEL=${PR_CHANNEL:-preview}
PRERELEASE_TAG="v${MAJOR}.${MINOR}.${PATCH}-${LABEL}.${DATE}.${RUN}"
```

---

## 12. Custom Assembly Version Strategy (Optional)

If you decide to align `AssemblyVersion` with full Major.Minor.Patch (risking binding churn):

```xml
<PropertyGroup>
    <MinVerMajorMinorPatch>true</MinVerMajorMinorPatch>
</PropertyGroup>
```

Avoid unless strong justification (most libraries keep AssemblyVersion stable across patches).

---

## 13. Summary Cheat Sheet

| Action                  | Command(s)                                                 |
| ----------------------- | ---------------------------------------------------------- |
| Manual stable release   | `git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z`    |
| Trigger prerelease      | Merge to `main` (no existing tag)                          |
| Inspect version locally | `dotnet build -c Release -p:MinVerVerbosity=detailed`      |
| Dry-run pack            | `dotnet pack -c Release -o artifacts -p:MinVerTagPrefix=v` |
| Fix failed prerelease   | Commit fix ? merge ? new prerelease tag                    |
| Introduce first tag     | `git tag -a v0.1.0 -m v0.1.0 && git push origin v0.1.0`    |

---

## 14. Troubleshooting

| Symptom                                | Cause                       | Fix                                                                        |
| -------------------------------------- | --------------------------- | -------------------------------------------------------------------------- |
| Package version always 1.0.0           | MinVer not referenced       | Ensure `<PackageReference Include="MinVer" PrivateAssets="all" />` present |
| Prerelease not created                 | Commit already tagged       | Make a new commit (even empty)                                             |
| Stable tag produced prerelease package | Tag included hyphen         | Use strictly `vX.Y.Z` for stable                                           |
| Symbols missing                        | Symbol package not pushed   | Confirm `.snupkg` is in `artifacts/pack` and push step not skipped         |
| Wrong next prerelease base             | Latest stable tag incorrect | Retag correct latest stable (new higher stable version)                    |

---

## 15. Future Enhancements (Optional Ideas)

- Auto-generate GitHub Release notes from commits.
- Dual publish to GitHub Packages (add secondary source).
- Add SBOM / signing (`dotnet nuget sign`) if required.
- Add validation job to ensure tag matches CHANGELOG.

Introduce [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/).

---

See also: [MinVer](https://github.com/adamralph/minver)
