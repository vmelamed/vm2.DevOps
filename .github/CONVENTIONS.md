# vm2 Shared Conventions

This file is the single source of truth for conventions shared across all vm2 packages.
It lives in vm2.Templates and is copied to each repo's .github/ directory.
Copies are kept in sync by diff-shared.sh. Edit the canonical copy first.

## Style Sources (Do Not Duplicate Here)

- .editorconfig — authoritative code style and analyzers
- Directory.Packages.props — centralized package versions
- Directory.Build.props / .targets — shared build configuration
- Each project's *.csproj
- Per project: usings.cs — global usings

## Project Structure

- Solutions: `.slnx` format (Visual Studio 2022+)
- Package versions: Central Package Management via `Directory.Packages.props`
- Project files: SDK-style
- Global usings: defined in `usings.cs` per project
- Standard folder layout:
  - `src/` — source code
  - `test/` — test projects
  - `benchmarks/` — BenchmarkDotNet projects (desirable)
  - `examples/` — usage examples (desirable)
  - `docs/` — documentation (optional)
  - `.github/workflows/` — GitHub Actions CI/CD

## General Coding Conventions

- File-scoped namespaces.
- `readonly record struct` for small immutable value objects.
- `internal` by default; `public` only for intentional API surface.
- `sealed` by default; open only when extensibility is required.
- Expression-bodied members when trivial and readable.
- `var` when the type is obvious from the right-hand side; explicit otherwise.
- Nullable reference types always enabled; treat warnings as design feedback.
- No static mutable state.
- Dependency injection over service locator.
- Guard clauses at method entry (throw early, no nested pyramids).
- Pattern matching (`is`, `switch` expressions) over `if`/`else` chains when semantic.
- No curly braces for single-line blocks unless they improve readability.
- `#region` / `#endregion` acceptable for logical grouping in larger files.
- EBNF (ISO 14977) for grammar definitions: `=` definitions, `,` concatenation,
  `;` rule terminator, `[ ]` optional, `|` alternation, `"..."` terminals.

## Async

- Async methods suffixed with `Async`.
- `CancellationToken ct` threaded through all async call chains.
- No fire-and-forget except documented background operations.
- `ValueTask` only when allocation reduction is measurable (hot paths, cached results).

## Error Handling

- Domain-specific exceptions for business rule violations.
- Never swallow exceptions — log or rethrow.
- Never log sensitive data (PII, secrets).
- Railway patterns (`Result<T>`) for short throws and flow control.
- Exceptions for unrecoverable failures (e.g. `ArgumentException`).
- `Try...` patterns preferred over broad exception-based control flow.

## Testing

- Framework: xUnit v3 with MTP v2.
- Assertions: FluentAssertions (never `Assert.*` unless framework-specific).
- Mocks: NSubstitute.
- Naming:
  - Sync:  `MethodName_WhenCondition_ShouldOutcome`
  - Async: `MethodName_WhenCondition_ShouldOutcome_Async`
- Arrange / Act / Assert with clear blank-line separation.
- One logical assertion per test (chained FluentAssertions counts as one).
- No testing of implementation details; mock only observable behavior.
- `[Trait("Category","Integration")]` for slow or external-dependency tests.
- Inject clock abstractions — never `DateTime.UtcNow` directly in tests.
- Inject ID providers — never rely on live generation in tests.
- Only mock external collaborators (I/O, time, random, repository, bus).
- Do not mock value objects.

## Performance

- `AsNoTracking()` for read-only EF queries.
- No unnecessary `ToList()` inside query pipelines.
- `ReadOnlySpan<char>` for parsing hot paths.
- `stackalloc` for small buffers with heap fallback for large inputs.

## Security

- No embedded secrets — user secrets or environment variables only.
- Validate all external inputs at system boundaries.
- Principle of least privilege throughout.
- Prefer quantum-resistant algorithms for cryptography where applicable.

## Naming

- Events: past tense — `OrderPlacedEvent`.
- Commands: imperative — `PlaceOrderCommand`.
- Handlers: `...Handler` suffix.

## Git and PR Hygiene

- One logical concern per PR.
- PR description: What / Why / How / Risk / Rollback.
- Commit messages: `<scope>: <imperative summary>`
  - Example: `ulid: add IUtf8SpanFormattable implementation`

## Documentation

- XML docs on all public API surface.
- Line length: 128 characters maximum.
- Internal code: document intent and rationale only — not what the code does.
- XML tags on their own lines unless the content fits on one line.
- Always proofread for spelling, grammar, and technical accuracy.
- Cite specifications (POSIX, RFC, SemVer, ULID spec, etc.) with title and URL.
- Standard references block format:

      ## References
      - [Title](URL) — Author or organization

## Markdown

- Follow markdownlint default rules (or `.markdownlint.json` if present).
- Wrap complete generated Markdown files in tilde fences (`~~~markdown`).
- Use 4-space indentation for code blocks inside Markdown content.
- Use `1.` for all items in ordered lists (renderers number automatically).
- Prefer kebab-case in YAML; avoid snake_case unless required by external schema.

## Language and Writing Quality

The project owner is a non-native English speaker.

- Always check spelling, grammar, and technical English in all documentation and comments.
- Recommend better wording for unclear, passive, or awkward sentences.
- Prefer active voice.
- Explain why a suggested change improves the text.
- Examples:
  - ❌ "The pattern is being matched by the enumerator"
  - ✅ "The enumerator matches the pattern"

## File Modification

- Preserve existing comments unless correcting inaccuracies or improving English.
- Document why new code exists, not just what it does.
- Do not remove commented-out code without explicit permission.
- Preserve YAML/JSON comments in configuration files.
- For GitHub Actions workflows: preserve commented-out alternatives and explanatory notes.

## CI / GitHub Actions

When adding a new project, register it in `.github/workflows/CI.yaml`:

| Array                | Purpose                    |
|----------------------|----------------------------|
| `BUILD_PROJECTS`     | Solutions/projects to build |
| `TEST_PROJECTS`      | Test projects to run        |
| `BENCHMARK_PROJECTS` | Benchmark projects to run   |
| `PACKAGE_PROJECTS`   | Projects to pack as NuGet   |

Also add the project to the `.slnx` solution file under the appropriate folder.

---
*Canonical source: vm2.Templates/templates/AddNewPackage/content/.github/CONVENTIONS.md*
*Copies maintained by diff-shared.sh — edit the canonical copy first.*
