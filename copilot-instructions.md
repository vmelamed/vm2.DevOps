git commit --allow-empty -m "Trigger prerelease" && git push
dotnet build -c Release /p:MinVerVerbosity=detailed
# Copilot Instructions

## Architecture & Key Files
- Library lives in `src/UlidType/`; `Ulid` is a readonly struct, `UlidFactory` enforces monotonic IDs via an internal lock.
- Randomness is pluggable (`Providers/`), clocks abstracted behind `IClock`; JSON converters in `NsJson/` and `SysJson/` keep both serializer stacks aligned.
- Tests (`test/UlidType.Tests`) exercise byte/string/Guid round-trips and use `KnownGoodValues`; benchmarks compare Guid vs ULID in `benchmarks/`.

## Coding Conventions
- Project targets net9.0 only; `Directory.Build.props` turns warnings into errors, enables nullable refs, unsafe blocks, PGO, trimming analyzers.
- Root namespace is `vm2`; keep APIs allocation-conscious (`TryWrite`, `stackalloc`, `ReadOnlyMemory<byte>`). Aim for ~40 B allocation per new ULID.
- Dual JSON attributes must stay on `Ulid`; update both converters if wire formats change.

## Daily Workflow
```bash
dotnet build                               # default Debug build
dotnet test                                # FluentAssertions-based tests
dotnet run --project benchmarks/UlidType.Benchmarks -c Release
```
- Example app: `dotnet run --project examples/GenerateUlids`.
- For MinVer diagnostics: `dotnet build -c Release /p:MinVerVerbosity=detailed`.

## Scripts & Automation
- Shell automation lives under `scripts/bash/` using the 3-file pattern (`*.sh`, `*.usage.sh`, `*.utils.sh`); share helpers via `_common.sh`.
- GitHub Actions `.github/workflows/CI.yaml` starts with `setup-ci-vars.sh`; pass raw strings from YAML and validate/parse inside the script.
- When editing workflows, avoid multi-line `fromJSON` chains; prefer `fromJSON(value || fallback || 'default')`.

## Testing & Benchmarking Notes
- Use FluentAssertions; check `FluentAssertionsExtensions/` for custom setup that acknowledges the license warning.
- Keep `KnownGoodValues` in sync with spec; tests rely on exact 26-char Crockford Base32 strings.
- Benchmarks leverage BenchmarkDotNet attributes (`SimpleJob`, `MemoryDiagnoser`, `JsonExporter`) and compare Guid baselines—copy existing patterns when adding cases.

## Release & CI
- Versioning powered by MinVer: prereleases auto-tag on merges to `main` (`vX.Y.(Z+1)-preview.YYYYMMDD.<run>`); stable releases require manual `git tag -a vX.Y.Z`.
- CI workflows reuse `build.yaml`, `test.yaml`, `benchmarks.yaml`; `[skip ci]` only honored on push events.
- Publishing needs `NUGET_API_KEY`; artifacts and summaries are produced via scripts (`run-tests.sh`, `run-benchmarks.sh`).
