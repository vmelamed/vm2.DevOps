# vm2 Shared Conventions

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [vm2 Shared Conventions](#vm2-shared-conventions)
  - [For AI Coding Assistants](#for-ai-coding-assistants)
    - [Code Generation and File Editing](#code-generation-and-file-editing)
    - [PR Review](#pr-review)
    - [Language and Writing Quality](#language-and-writing-quality)
  - [Project Structure](#project-structure)
  - [Dependency Management](#dependency-management)
  - [General C# Coding Conventions](#general-c-coding-conventions)
  - [Async](#async)
  - [Services (if applicable)](#services-if-applicable)
  - [Error Handling](#error-handling)
  - [Testing](#testing)
  - [Performance Benchmarks](#performance-benchmarks)
  - [Performance](#performance)
  - [Security](#security)
  - [Naming](#naming)
  - [AOT and Trimming](#aot-and-trimming)
  - [Git and PR Hygiene](#git-and-pr-hygiene)
  - [Documentation](#documentation)
    - [Markdown](#markdown)
  - [File Modification](#file-modification)
  - [CI / GitHub Actions](#ci--github-actions)

<!-- /TOC -->

The *vm2* family of repositories (packages, solutions, etc.) **share a common set of conventions** for the directory
structure, project structure, coding style, documentation style, Git and PR hygiene, and more. This file documents these
shared conventions to ensure **consistency across all repositories** and to provide guidance for contributors.

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document are to be interpreted as
described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

> [!NOTE]
> This file is **copied identically to each repo's `.github/` directory** via `diff-shared.sh`.
> The canonical source of truth is `vm2.Templates/templates/AddNewPackage/content/.github/CONVENTIONS.md`.
> **Edit the canonical copy first**, then propagate with `diff-shared.sh`.
> Repo-specific overrides belong in `CLAUDE.md` and `copilot-instructions.md`, not here.

## For AI Coding Assistants

This section consolidates instructions specifically for AI coding assistants (Claude, Copilot, etc.). The conventions
in the rest of this document apply to all contributors — human and AI alike.

### Code Generation and File Editing

- **Wrap complete generated Markdown files in tilde fences** (`~~~markdown`) so the user can copy them cleanly
- **Align Markdown table columns with spaces** so the table is readable in raw Markdown, not only in the rendered view
- Do not remove commented-out code or configuration comments without explicit permission; feel free to *suggest* removal
- Preserve YAML/JSON/XML comments in configuration files
- For GitHub Actions workflows: preserve commented-out alternatives and explanatory notes
- When adding new code, comment on *why* it exists — non-obvious constraints, invariants, workarounds, TODOs with context
- When refactoring, update affected comments to maintain accuracy

### PR Review

- If a PR addresses more than one logical concern, **reject it** and request that it be split — do not approve or suggest
  improvements until the scope is reduced to one concern

### Language and Writing Quality

The project owner is a non-native English speaker.

- Always check spelling, grammar, and technical English in all documentation and comments
- Recommend better, idiomatic wording for unclear, passive, or awkward sentences
- Prefer active voice
- Explain why a suggested change improves the text
- When suggesting a correction, add one short sentence stating exactly what changed and why — especially for small edits
  such as punctuation, articles, or word order
- Examples:
  - ❌ "The pattern is being matched by the enumerator"
  - ✅ "The enumerator matches the pattern"

## Project Structure

- Solutions: **`.slnx` format** (Visual Studio 2022+)
- `Directory.Build.props` for shared build settings
- `Directory.Packages.props` for centralized package version management
- Project files: **SDK-style**
- Global usings: defined in **`usings.cs`** per project
- Standard folder layout:
  - `src/` — source code for deliverables
  - `tests/` — test projects (xUnit v3, FluentAssertions, NSubstitute, MTP v2, Coverlet)
  - `benchmarks/` — BenchmarkDotNet projects (desirable)
  - `examples/` — usage examples (desirable; prefer single-file programs)
  - `docs/` — documentation beyond README.md (optional)
  - `.github/`
    - AI-specific guidance and conventions (`CONVENTIONS.md` and/or `copilot-instructions.md`)
    - dependabot configuration (`dependabot.yml`)
    - issue and pull request templates (`ISSUE_TEMPLATE/` and `PULL_REQUEST_TEMPLATE.md`)
  - `.github/workflows/` — GitHub Actions CI/CD (`CI.yaml`, `Prerelease.yaml`, `Release.yaml`, `RefreshLockFiles.yaml`, `AutoMerge.yaml`, `ClearCache.yaml`, `RebuildBenchHistory.yaml`)

## Dependency Management

- **Use `Directory.Build.props` and `Directory.Packages.props`** for shared build configuration and centralized package
  version management; `*.csproj` files reference packages without versions
- **Restore with `dotnet restore --use-lock-file`** to pin exact versions; commit `packages.lock.json`
- **Build with `dotnet restore --use-lock-file ... && dotnet build --no-restore ...`**
- When dependencies change: update `Directory.Packages.props`, **AND** then run `dotnet restore --force-evaluate`, commit both files
- Dependabot watches `Directory.Packages.props`; after merging a Dependabot PR, run `dotnet restore --force-evaluate` (also done by `RefreshLockFiles.yaml` and `AutoMerge.yaml`)

## General C# Coding Conventions

- **See the repo's `.editorconfig` first** — it is authoritative for style and analyzers
- File-scoped namespaces
- Implicit usings for common namespaces (defined in `usings.cs`)
- `record` for immutable data models and DTOs
- `readonly record struct` for small immutable value objects (e.g. `Ulid`, `Result<T>`)
- `internal` by default; **`public` only for intentional API surface**. For referencing internal classes and members from say test projects, use the `InternalsVisibleTo` attribute rather than making them `public`
- `sealed` by default; open **only** when extensibility is required and justified
- Expression-bodied members when trivial and readable (one-liners, simple getters)
- `var` when the type is obvious from the right-hand side
- **Nullable reference types always enabled**; treat warnings as design feedback
- **No static mutable state** unless guarded with proper synchronization (prefer `ReaderWriterLockSlim`)
- Prefer `[GeneratedRegex(...)]` partial methods over `new Regex(..., RegexOptions.Compiled)` for static patterns
- **Dependency injection** over service locator
- Use `System.TimeProvider` (.NET 8+) for time abstraction; `FakeTimeProvider` in tests — **never** a homegrown `IClock`
- Guard clauses at method entry (throw early; no nested pyramids)
- All public interfaces must validate their input parameters and throw appropriate exceptions (e.g., `ArgumentNullException`, `ArgumentException`) for invalid arguments even if nullable references are enabled
- Pattern matching (`is`, `switch` expressions) over `if`/`else` chains when semantically clearer
- No curly braces for single-line blocks unless they improve readability
- `#region` / `#endregion` acceptable for logical grouping in larger files and for interface implementations
- EBNF (ISO 14977) for grammar definitions: `=` definitions, `,` concatenation, `;` terminator, `[ ]` optional,
  `|` alternation, `"..."` terminals

## Async

- Async methods suffixed with `Async`
- `CancellationToken ct` **threaded through all async call chains**
- **No fire-and-forget** except documented background operations with proper error handling and logging
- `ValueTask` only when allocation reduction is measurable (hot paths, cached results)

## Services (if applicable)

- Prefer async APIs even when the current implementation is synchronous — avoids breaking changes later
- Within a cluster, prefer gRPC and messaging over HTTP/REST for performance and reliability

## Error Handling

- **Consider `Result<T>` for expected failure modes** instead of exceptions
- **Never use exceptions for expected control flow** (e.g. not-found) — prefer `Result<T>`
- **Exceptions for unrecoverable failures only** (e.g. `ArgumentException`)
- `Try<MethodName>` patterns over broad exception-based control flow
- **Never swallow exceptions** — at minimum log or rethrow
- **Never log sensitive data** (PII, secrets)
- **Use logger scopes** for contextual information; never string concatenation in log messages
- **Prefer `ILogger<T>`** with structured logging
- In services: prefer circuit breakers and retries over exceptions for transient faults
- In services: use health checks and OpenTelemetry for observability, not exceptions

## Testing

- Framework: **xUnit v3 with Microsoft Testing Platform (MTP) v2**
- Assertions: **FluentAssertions** (never `Assert.*` unless framework-specific)
- Mocks: **NSubstitute**
- Use **vm2.TestUtilities**:
  - `TestUtilities.PathLine()` — locates failing theory tests
  - `XUnitLogger` — captures structured logs without a real logger
  - `TestBase` — inherit `ITestOutputHelper Out`, suppress FluentAssertions licensing noise, get `FluentAssertionsExceptionFormatter`
- Test naming:
  - Sync:  `MethodName_WhenCondition_ShouldOutcome`
  - Async: `MethodName_WhenCondition_ShouldOutcome_Async`
- Arrange / Act / Assert with clear blank-line separation
- One logical assertion per test (chained FluentAssertions counts as one)
- Prefer `[Theory]` with inline data; use `[MemberData]` or `[ClassData]` for complex scenarios
- No testing of implementation details; mock only observable behavior
- `[Trait("Category","Integration")]` for slow or external-dependency tests
- Inject mock clock, e.g., `FakeTimeProvider` — never `DateTime.UtcNow` directly in tests
- Inject mock ID providers — never rely on live generation in tests
- Mock only external collaborators (I/O, time, random, repository, bus); never mock value objects
- Strive for 80% code coverage on critical paths; prioritize meaningful tests over coverage numbers
- Upload coverage to Codecov

## Performance Benchmarks

- Framework: **BenchmarkDotNet**
- Derive from `BenchmarkBase` to inherit consistent `MemoryDiagnoser`, `GcServer`, and other attributes
- Benchmark hot paths and critical scenarios, not every method
- Use `GlobalSetup` for expensive initialization; `IterationSetup` for per-iteration setup
- Use `Params` for parameterized benchmarks to compare inputs
- Upload results to Bencher for regression tracking

## Performance

- `AsNoTracking()` for read-only EF queries
- Prefer lazy evaluation with iterators (`yield return`) over eager materialization for sequences
- Prefer lazy initialization (`Lazy<T>`, `Lazy<T>(LazyThreadSafetyMode.*)`) for expensive objects
- No unnecessary `ToList()` inside query pipelines
- `ReadOnlySpan<char>` for parsing hot paths
- `stackalloc` for small buffers with heap fallback for large inputs

## Security

- No embedded secrets — secure storage, user secrets, or environment variables only
- Validate all external inputs at system boundaries
- Principle of least privilege throughout
- Prefer quantum-resistant algorithms for cryptography where applicable

## Naming

- Events: past tense — `OrderPlacedEvent`
- Commands: imperative — `PlaceOrderCommand`
- Handlers: `...Handler` suffix
- Prefer **domain-first public API type names** without suffixes unless required to avoid symbol conflicts
- **Package-first artifact identity**:
  - Package ID: `vm2.<Package>` or `vm2.<Package>.<Feature>`
  - Assembly name: `vm2.<Package>` or `vm2.<Package>.<Feature>`
- **Always set `<RootNamespace>` explicitly** in every `*.csproj`
- **Always set `<OutputType>` explicitly** in every `*.csproj`
- Test projects — assembly: `<Package>.Tests`; namespace: `vm2.Tests.<Package>[.<Feature>]`. Note the placement of the `Tests` segment and the mirroring of the assembly structure: it helps avoiding symbol conflicts. Always `<OutputType>Exe</OutputType>` - xUnit v3 + MTP v2.
- Benchmark projects — assembly: `<Package>.Benchmarks`; namespace: `vm2.Benchmarks.<Package>[.<Feature>]`. Note the placement of the `Benchmarks` segment and the mirroring of the assembly structure: it helps avoiding symbol conflicts. Always `<OutputType>Exe</OutputType>` - BenchmarkDotNet requires the default name for the entry point assembly.
- Do not mix naming strategies within a single repository

## AOT and Trimming

Scope via `Directory.Build.props` (folder-based conditions):

- **Test and benchmark projects** — AOT and trim checks disabled; optimize for correctness/perf feedback:
  `IsAotCompatible=false`, `VerifyReferenceAotCompatibility=false`, `EnableTrimAnalyzer=false`, `IsTrimmable=false`
- **Product projects** — AOT and trim checks enabled, unless code or dependencies explicitly require otherwise:
  `IsAotCompatible=true`, `VerifyReferenceAotCompatibility=true`, `EnableTrimAnalyzer=true`, `IsTrimmable=true`

Diagnostic classification:

- `IL2026` family — trimming compatibility; fix with `DynamicallyAccessedMembersAttribute` or
  `RequiresUnreferencedCodeAttribute` at the API boundary
- `IL3050` family — AOT dynamic-code; fix by removing dynamic patterns or annotating with
  `RequiresDynamicCodeAttribute`; split into AOT-safe core + non-AOT companion if the surface is large
- `IL3058` — referenced assembly not marked AOT-compatible

IL warning suppression policy:

- **Do not suppress IL warnings** (`IL2xxx`, `IL3xxx`) by default
- Only suppress when the safety argument is explicit, tested, and documented
- If suppression seems like the easiest fix, stop and re-evaluate the API design first

If strict AOT/trimming is not worth it for a specific product project, opt out explicitly in `*.csproj` with documented
rationale in README/CHANGELOG/PR.

## Git and PR Hygiene

- Commit messages: `<type>[(scope)][!]: <description>` — `!` marks a breaking change
  - `fix: correct null reference in UserService`
  - `feat(serialization): add IUtf8SpanFormattable implementation`
- One logical concern per PR

## Documentation

- **Technical and specification documents** MUST include the RFC 2119 boilerplate:
  "The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document are to be interpreted
  as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119)."
- **Blogs and free-form articles** (`docs/blog-*.md`) MUST NOT use RFC 2119 keywords as normative terms
- Use clear, concise, idiomatic language; prefer active voice and direct statements
- Explain the *why* and intent behind decisions, not just the *what*
- **XML docs on all public API surface**
- Line length: 128 characters maximum
- XML tags on their own lines unless the entire XML element fits on one line
- **Cite specifications** (POSIX, RFC, SemVer, ULID spec, etc.) with title and URL
- **README code examples must be self-contained and runnable**: include all `using` directives, declare all variables,
  avoid unexplained placeholders. A reader must be able to paste the example and have it compile
- Standard references block:

      ## References
      - [Title](URL) — Author or organization

### Markdown

- Follow markdownlint default rules (or `.markdownlint.json` if present)
- **Align table columns with spaces** for readability in raw Markdown
- 4-space indentation for code blocks inside Markdown
- **Use `1.` for all items in ordered lists** (renderers number automatically)
- Prefer kebab-case in YAML; avoid snake_case unless required by an external schema

## File Modification

- **Preserve existing comments** unless correcting inaccuracies or improving English
- Do not remove commented-out code without explicit permission
- Preserve YAML/JSON comments in configuration files
- For GitHub Actions workflows: preserve commented-out alternatives and explanatory notes

## CI / GitHub Actions

When adding a new project, register it in `.github/workflows/CI.yaml`:

| Array                | Purpose                               |
|----------------------|---------------------------------------|
| `BUILD_PROJECTS`     | Solutions/projects to build           |
| `TEST_PROJECTS`      | Test projects to build and run        |
| `BENCHMARK_PROJECTS` | Benchmark projects to build and run   |
| `PACKAGE_PROJECTS`   | Projects to pack as NuGet packages    |

Also add the project to the `.slnx` solution file under the appropriate folder.

---
*Canonical source: `vm2.Templates/templates/AddNewPackage/content/.github/CONVENTIONS.md`*
*Copies maintained by `diff-shared.sh` — edit the canonical copy first.*
