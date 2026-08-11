# vm2 Shared Conventions

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
- Implicit usings for common namespaces (defined in `usings.cs`) or `<Using Include="..." />` in `*.csproj` and `Directory.Build.props`
- `record` for immutable data models and DTOs
- `readonly record struct` for small immutable value objects (e.g. `Ulid`, `Result<T>`)
- `internal` by default; **`public` only for intentional API surface**. For referencing internal classes and members from say test projects, use the `InternalsVisibleTo` attribute rather than making them `public`
- `sealed` by default; open **only** when extensibility is required and justified
- **Instance methods for a type's own algebra; extension methods only to adapt what you don't own.** A method's
  natural home is *inside* the type when the type is yours and the method is part of its core behavior — it gets direct
  access to private state (no widening the public surface just to feed a helper), it is discoverable on `.` without an
  import, and the type's behavior stays cohesive in one file. Reach for an **extension method** when, and only when:
  - the receiver is a type you **do not own** (`Task<T>`, `IEnumerable<T>`, `Func<>`, `Nullable<T>`, a third-party type)
    — you *cannot* add an instance method, so lifting/adapting it (`.MapAsync`, `.Traverse`, `.ToResult`) must be an
    extension. This is why LINQ and most FP combinators over BCL types are extensions;
  - the operation is defined over a **pattern across several types** rather than one type (`Traverse`, `Sequence`,
    `Apply`), so no single type is its home.

  Do **not** scatter a type's own core operations (e.g. `Option<T>.Map`/`Bind`, `Result<T>.Ensure`/`Tap`) into external
  static classes; keep them inside the type. When extensions are unavoidable, group them in one clearly named static
  class per concern (`OptionExtensions`, `ResultAsyncExtensions`) so the out-of-type code is organized, not sprinkled.
- **Compose, don't impersonate.** A type MUST NOT implement an interface (or expose a conversion) merely to borrow the
  ergonomics that come with *being* that thing when it is not semantically that thing. Gain a capability from the
  *method shapes* the feature actually requires, not from a false `is-a`. For example, support LINQ query syntax over a
  monad by giving it `Select`/`SelectMany`/`Where` **methods** rather than implementing `IEnumerable<T>` — a monad
  (`Option<T>`, `Result<T>`, `Task<T>`) is **not** a collection, and claiming to be one floods its surface with
  meaningless operators (`OrderBy`, `Zip`, `Chunk`), re-opens throwing extractors (`First`, `Single`) that bypass the
  type's own safety, and boxes the value. This is distinct from *prefer composition over inheritance*: that rule governs
  implementation **reuse** (`has-a` over `extends-a`); this one governs interface **honesty** (do not advertise an
  identity you do not have).
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
- **Async-only for I/O-bound surfaces.** Where an operation is genuinely I/O-bound, expose **only** the async form — no
  synchronous twin. The only way to offer a sync twin over an async internal is sync-over-async (`.Result` /
  `.GetAwaiter().GetResult()`), which risks thread-pool starvation and deadlocks; refusing the sync twin is refusing to
  ship that hazard. (Precedent: the EF Core Cosmos DB provider is async-only and throws on synchronous calls.)
- Scope the rule to genuinely I/O-bound work. Code MUST NOT fake async over CPU-bound or in-memory work (no `Task.Run`
  wrappers to present an async face); pure-computation packages stay synchronous.
- An inherited or otherwise unavoidable synchronous seam (e.g. a sync interface member the type MUST implement) MUST throw
  a clear usage exception (e.g. "this API is async-only; call `…Async`"), never silently block via sync-over-async.
- Prefer the asynchronous BCL interfaces — `IAsyncDisposable` over `IDisposable`, `IAsyncEnumerable<T>` over
  `IEnumerable<T>` — so async-only surfaces have no synchronous dead ends.
- A library MUST NOT ship sync-over-async on a consumer's behalf. A consumer trapped in an inherently synchronous context
  owns that bridge; the library does not relocate the hazard into itself.

## Services (if applicable)

- Prefer async APIs even when the current implementation is synchronous — avoids breaking changes later
- Within a cluster, prefer gRPC and messaging over HTTP/REST for performance and reliability

## Error Handling

**The governing rule — exceptions guard the contract; results carry outcomes:**

> An **exception** means *the caller or the environment is broken*: a precondition was violated (a caller bug) or the
> machine failed (a catastrophe). A **`Result<T>`** means *the operation executed correctly and legitimately did not
> succeed* — a normal alternate outcome the caller is expected to branch on.

The deciding axis is **contractual outcome vs. contract violation**, **NOT** *recoverable vs. unrecoverable*. A failure
MAY be unrecoverable and still be a `Result` (for signature visibility, allocation cost, and error accumulation); a
failure MAY be trivially recoverable and still be an exception, because it was a caller bug.

- Expected, correct-usage failures (not-found, business-invariant violation, etc.) SHOULD be modeled as `Result<T>`.
- Caller mistakes — invalid arguments, violated preconditions the caller could have checked upfront, API misuse — MUST
  throw (the `ArgumentException` family). Fail fast and loud; these are bugs, not outcomes. This is **argument
  validation** and is distinct from **invariant validation** (below), which returns a `Result`.
- Unrecoverable or catastrophic failures (I/O loss, OOM) MUST propagate to a single top-level boundary handler. Code MUST
  NOT wrap every call in `try`/`catch`, and MUST NOT catch `Exception` to repackage it as a `Result` — that hides bugs
  and catastrophes that MUST surface loudly. Convert an exception to a `Result` only at a specific boundary, catching a
  **specific, known** exception type that represents an expected outcome (e.g. via a `Try(...)` combinator).
- **Never use exceptions for expected control flow.** **Never swallow exceptions** — at minimum log or rethrow.
- **Never log sensitive data** (PII, secrets). **Use logger scopes** for context; never string concatenation in messages.
- **Prefer `ILogger<T>`** with structured logging.
- In services: prefer circuit breakers and retries over exceptions for transient faults; a transient fault handled by a
  resilience pipeline (e.g. optimistic-concurrency retry) MAY be surfaced as an exception, because the resilience layer
  is exception-shaped.
- In services: use health checks and OpenTelemetry for observability, not exceptions.

### The `Do` / `TryDo` dual pattern

When an operation's failure may be *either* a caller bug *or* an expected outcome depending on the call site, expose
**both** forms (generalizing `Parse` / `TryParse`):

- `Do(...)` — the bare-named method THROWS on failure. Use at **trusted internal call sites** where a failure is a bug.
  The thrown exception SHOULD carry the full failure detail (e.g. every validation failure, like a good parser).
- `TryDo(...)` — returns `Result<T>` (or `Result`). Use at **boundaries** (untrusted input, optional presence) where a
  failure is an expected outcome to branch on.

Concrete instances: `Validate` / `TryValidate`, `Find` / `TryFind`, `Get` / `TryGet`. The dual form makes the functional
dependency **opt-in**: a consumer who does not want railway-oriented code uses the throwing `Do` form, catches ordinary
exceptions, and never references `vm2.Functional`; `TryDo` is for consumers who opt into `Result`.

### `Result<T>` and railway-oriented programming (ROP)

- `Result<T>` and its `Error` hierarchy live in **`vm2.Functional`**. `Result<T>` is a `readonly record struct`; `Error`
  is a polymorphic class hierarchy matched (via `switch`) at the boundary — the ROP analogue of a `catch` series.
- Compose fallible steps with combinators (`Bind`, `Map`, `Ensure`, `Tap`, `Match`). The upstream-failure short-circuit
  MUST live in the combinators, written once; business functions take the **unwrapped** value and return `Result<T>`,
  and MUST NOT re-check upstream failure. `Match` is the only place a pipeline leaves the rails.
- Invariant validation MUST accumulate **all** failures into one aggregate `Error` (applicative), not just the first.
- An `Error.Code`, when present, is a **stable, external contract** for consumers that cannot see the CLR type (API
  clients, localization, telemetry). Namespace it as `<resource>.<kind>` (e.g. `order.not_found`, `file.not_found`) and
  match its granularity to how consumers branch. Derive it from a stable **domain term**, NEVER from the CLR type name;
  omit it entirely for purely internal errors (discriminate by type instead). For coarse in-process handling shared
  across several codes, use a marker interface (e.g. `INotFoundError`) alongside the specific `Code`.

### API surface vs. inner workings

- Opinionated third-party libraries (e.g. FluentValidation) are **implementation details**. They MUST NOT appear on the
  public surface; wrap them behind a clean vm2 interface (`IValidatable`) so consumers see `Result` / `Validate`, never
  the library's vocabulary.
- The public surface MUST expose only vm2-owned outcome types (`Result<T>`, `Error`). Code MUST NOT surface a
  third-party `Result` / `Either` / `OneOf` type — its version bumps would become your breaking changes.
- A type on a **published** API surface is a binary-compatibility commitment. A `vm2.Functional` type MUST be stabilized
  (shape locked, edge cases such as the `default(Result<T>)` state decided, tests in place) **before** it appears on a
  published signature.
- Async surfaces are `ValueTask<Result<T>>` / `Task<Result<T>>`; the async combinator family (`BindAsync`, `MapAsync`,
  `EnsureAsync`) MUST be provided so the double-wrapped result composes without hand-unwrapping.

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
- **Credit AI co-authorship.** When an AI coding assistant materially contributed to a commit (wrote or substantially
  shaped the code, tests, or docs), add a `Co-Authored-By:` trailer at the end of the commit message naming the
  assistant, e.g. `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. This keeps authorship honest and the
  history auditable; it is not optional vanity — it records who (or what) actually shaped the change.

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

- **Edit shared files at their canonical source, never in a consumer repo.** Files synced by `diff-shared.sh` (mapped in
  `diff-shared.config.json`) are sourced from `vm2.Templates` (the `AddNewPackage` content). Edit the canonical copy
  first, then propagate with `diff-shared.sh`.
  - Action **`copy`** (`.editorconfig`, `.gitignore`, `.gitattributes`, `.gitmessage`, `CONVENTIONS.md`, `global.json`,
    `LICENSE`, `NuGet.config`, `dependabot.yml`, the `cliff.*` configs, and several workflows — see the config for the
    authoritative list): **100% shared and overwritten verbatim.** A direct edit in a consumer repo MUST NOT be made —
    the next `diff-shared.sh` run silently clobbers it.
  - Action **`ask to merge`** (`CI`/`Prerelease`/`Release` workflows, `Directory.Build.props`, `Directory.Packages.props`,
    `copilot-instructions.md`): partially shared — still edit the canonical copy first, then merge; keep repo-specific
    overrides in the consumer repo.
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
