# Project Guidance for Copilot & Contributors

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [Project Guidance for Copilot \& Contributors](#project-guidance-for-copilot--contributors)
  - [Style Sources (Do Not Duplicate Here)](#style-sources-do-not-duplicate-here)
  - [Project Structure and Tooling](#project-structure-and-tooling)
  - [General Coding Conventions](#general-coding-conventions)
  - [Language and Writing Quality](#language-and-writing-quality)
  - [Documentation and Attribution](#documentation-and-attribution)
  - [Markdown File Generation](#markdown-file-generation)
    - [Always follow the Markdown lint default rules or defined in the `.markdownlint.json` file in the repository root](#always-follow-the-markdown-lint-default-rules-or-defined-in-the-markdownlintjson-file-in-the-repository-root)
    - [Ordered Lists](#ordered-lists)
  - [File Modification Guidelines](#file-modification-guidelines)
  - [Domain / DDD](#domain--ddd)
  - [EF Core](#ef-core)
  - [Async](#async)
  - [Error Handling / Logging](#error-handling--logging)
  - [Testing Conventions](#testing-conventions)
  - [Test Data Patterns](#test-data-patterns)
  - [Mocking Guidelines](#mocking-guidelines)
  - [Performance / Allocation](#performance--allocation)
  - [Naming](#naming)
  - [Git / PR Hygiene](#git--pr-hygiene)
  - [Security](#security)
  - [Copilot Prompting Hints](#copilot-prompting-hints)
  - [Anti-Patterns (Avoid)](#anti-patterns-avoid)
  - [Interceptor-Specific Guidance](#interceptor-specific-guidance)
  - [Tooling / Analyzer Suggestions](#tooling--analyzer-suggestions)
  - [Documentation](#documentation)
  - [Future Enhancements (Track Separately)](#future-enhancements-track-separately)
  - [When discussing modifications or extensions to existing code](#when-discussing-modifications-or-extensions-to-existing-code)

<!-- /TOC -->

## Style Sources (Do Not Duplicate Here)

Refer to:

- .editorconfig (authoritative code style + analyzers)
- Directory.Packages.props (centralized package versions)
- Directory.Build.props / .targets (shared build config)
- Each project's *.csproj
- Per project: usings.cs (global usings)

Keep this file focused on *intent* and *preferences* so Copilot infers patterns.

## Project Structure and Tooling

- **All new solutions should use the new `.slnx` format** (XML-based solution format introduced in Visual Studio 2022)
  - Easier to read and merge in source control
  - Better tooling support for modern .NET workflows
  - Use `dotnet new sln -n solution-name` to create .slnx solutions
- **All new projects should strive to use Central Package Management (CPM)**
  - Define package versions in `Directory.Packages.props`
  - Use `<PackageReference Include="..." />` without `Version` attribute in project files
  - Enable with `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`
  - Benefits: consistent versions across projects, easier updates, reduced merge conflicts
  - See existing `Directory.Packages.props` for reference implementation
- **All new projects should use SDK-style project files**
  - Simplified XML format
  - Implicit package references for common SDKs
  - Easier to read and maintain
- **All new projects should use implicit global usings where applicable**
  - Define common namespaces in `usings.cs` files
  - Reduces boilerplate in individual source files
  - Improves readability
- **All new projects should have the following folder structure:**
  - `.github/` for GitHub workflows and issue templates (optional)
  - `.github/workflows/` for GitHub Actions workflows (optional)
  - `src/` for source code
  - `tests/` for test projects (very rarely optional - only for test and other tiny utilities)
  - `benchmarks/` for performance benchmarks (desirable)
  - `examples/` for sample code and usage examples (desirable)
  - `docs/` for documentation (optional)
  - `tools/` for compiled utilities (optional)
  - `scripts/` for build and deployment scripts (optional)

## General Coding Conventions

- Use file-scoped namespaces.
- Grammar definitions must use EBNF (ISO 14977) notation: `=` for definitions, `,` for concatenation, `;` to terminate
  rules, `[ ]` for optional, `|` for alternation, `"..."` for terminals.
- Prefer `readonly record struct` for small immutable value objects.
- Prefer `internal` over `public` unless part of an intentional API surface.
- Use expression-bodied members when trivial and not harming readability.
- Use `sealed` by default for classes unless extensibility is required.
- Prefer `var` when the type is obvious from the right-hand side; otherwise be explicit.
- Always honor nullable reference types (treat warnings as design feedback).
- Avoid static mutable state.
- Use dependency injection over service locator.
- Prefer guard clauses at method start (throw early, no nested pyramid).
- Prefer pattern matching (`is`, `switch expressions`) over `if`/`else` chains when semantic.
- Do not use curly braces for single-line blocks unless improving readability.
- It's OK to use #region / #endregion for logical grouping in larger files.

## Language and Writing Quality

**IMPORTANT: The project owner is a non-native English speaker.**

- **ALWAYS** check spelling, grammar, and technical English style in all documentation and comments
- **ALWAYS** recommend better wording for:
  - Sentences that could be clearer or more concise
  - Paragraphs with awkward flow or structure
  - Entire documents that could be reorganized for better readability
- Prefer active voice over passive voice
- Use technical terminology correctly and consistently
- When suggesting changes, explain WHY the alternative is better
- Examples of improvements:
  - ❌ "The pattern is being matched by the enumerator"
  - ✅ "The enumerator matches the pattern"
  - ❌ "For doing the search"
  - ✅ "To search" or "For searching"

## Documentation and Attribution

**ALWAYS include proper credits and references:**

- When implementing specifications (POSIX, RFC, etc.), cite the source:
  - Include title, URL, and date accessed
  - Example: "Based on POSIX.2 glob specification (<https://www.man7.org/linux/man-pages/man7/glob.7.html>)"
- When using algorithms or concepts from papers/articles, cite them
- When adapting code patterns from other projects, acknowledge them
- Include links to relevant documentation for users to learn more
- Standard attribution format:

      ## References

      - [POSIX Glob Specification](https://www.man7.org/linux/man-pages/man7/glob.7.html) - The Linux man-pages project
      - [RFC XXXX](https://www.rfc-editor.org/rfc/rfcXXXX) - Title (if applicable)
      - [Article/Blog Title](URL) - Author Name (if used)

## Markdown File Generation

### Always follow the Markdown lint default rules or defined in the `.markdownlint.json` file in the repository root

**IMPORTANT: When generating complete Markdown (.md) file content:**

- **ALWAYS** wrap the entire file content in a code fence using **TILDES** (`~~~markdown` ... `~~~`)
- This prevents nesting issues with triple-backtick code blocks inside the Markdown content
- **Inside the Markdown content**, use **4-space indentation** for code blocks (not triple backticks)
- This avoids nested code fence conflicts while maintaining valid Markdown syntax
- Example format:

      ~~~markdown
      # README Title

      ## Installation

          dotnet tool install -g package-name

      ## Examples

          command "**/*.cs"
          command "*.json" -d ~/config

      ## References

      - [Source Documentation](https://example.com) - Proper attribution
      ~~~

- Benefits:
  - ✅ No nested code fence conflicts (tildes vs backticks)
  - ✅ Copy-paste ready content for users
  - ✅ Valid Markdown syntax (CommonMark compliant)
  - ✅ Works in Visual Studio Copilot pane
  - ✅ Renders correctly on GitHub, VS Code, and other Markdown viewers
- For partial edits or snippets, normal Markdown rendering is acceptable

### Ordered Lists

When creating ordered lists in Markdown documents, use `1.` for all items instead of sequential numbering (1., 2., 3., etc.). This approach provides several benefits:

- Easier to reorder items without renumbering
- Simpler to add new items without adjusting subsequent numbers
- Less maintenance when deleting items
- Markdown renderers automatically number items correctly

**Example:**

    ~~~markdown
    1. First item
    1. Second item
    1. Third item
    ~~~

This renders as:

1. First item
2. Second item
3. Third item

## File Modification Guidelines

**CRITICAL: When updating or modifying existing files:**

- **ALWAYS preserve existing comments** - Comments provide context, rationale, and documentation
- Existing comments can be modified if this improves English spelling and phrasing, as well as clarity or correctness.
- Also, existing comments can be modified if they contain inaccuracies or outdated information or they need to reflect modified behavior.
- When adding new code, include appropriate comments explaining:
  - Why the code exists (not just what it does)
  - Non-obvious implementation details
  - Business logic or domain-specific rationale
  - Temporary workarounds or TODOs with context
- Do not remove commented-out code without explicit permission
- Preserve YAML/JSON comments in configuration files (they document intentions and alternatives)
- When refactoring, update affected comments to maintain accuracy
- For workflow files (GitHub Actions, CI/CD):
  - Preserve commented-out alternative implementations
  - Keep notes about disabled features or experimental options
  - Maintain explanatory comments about concurrency, permissions, and environment setup

## Domain / DDD

- Aggregates enforce invariants; do not leak internal collections—expose read-only views.
- Use value objects where identity = value equality.
- Keep repositories binding-context–centric.
- One transaction = one aggregate unless explicitly extending via AllowedAggregateRoots (rare; justify in PR).
- Invariants validated via `IValidatable`; do not duplicate validation in services unless policy-specific.

## EF Core

- Avoid lazy loading (explicit or eager only).
- Keep DbContext lifetime scoped; no static context.
- No raw SQL unless unavoidable—prefer LINQ and query filters.
- Configure concurrency tokens where appropriate (RowVersion or concurrency columns).
- Interceptors (like DddInterceptor) should remain side‑effect minimal and deterministic.
- Do not call `.Result` / `.Wait()` on async database calls.

## Async

- Suffix async methods with `Async`.
- Pass `CancellationToken ct` through all async call chains.
- Avoid fire-and-forget except for explicitly scheduled background operations (document rationale).
- Use `ValueTask` only when it measurably reduces allocations (e.g. hot paths already returning cached results).

## Error Handling / Logging

- Throw domain-specific exceptions for business rule violations; not generic `InvalidOperationException` unless internal invariant.
- Avoid swallowing exceptions – log or rethrow.
- Do not log sensitive data (PII, secrets).
- For short `throw`-s use railway patterns (e.g. `Result<T>`) instead of controlling flow;
- for complex flows and when there is nothing to do to compensate the failed action (e.g. `ArgumentException`) use exceptions.
- Prefer domain-specific exception types over generic ones.
- Prefer `Try...` patterns over broad exception-based control flow where appropriate.

## Testing Conventions

- Framework: xUnit.
- Assertions: FluentAssertions (never Assert.* unless framework-specific).
- Mocks/Doubles: NSubstitute.
- Test naming:
  - Async: `MethodName_WhenCondition_ShouldOutcome_Async`
  - Sync: `MethodName_WhenCondition_ShouldOutcome`
- Use Arrange / Act / Assert with clear spacing.
- Minimize deep object graphs—use builders or inline records.
- Prefer one logical assertion per test (grouped FluentAssertions chain counts as one).
- Avoid testing implementation details (interactions only when behavior requires).
- Use `Trait` attributes (e.g. `[Trait("Category","Integration")]`) for slower or external tests.
- Deterministic time: inject clock abstractions (never rely on `DateTime.UtcNow` directly in tests).
- Deterministic IDs: inject or override ID providers when needed.

## Test Data Patterns

- Use a Test Data Builder (`EntityBuilder`) instead of repetitive object scaffolding.
- For complex aggregates, expose fluent methods (e.g. `.WithStatus(...)`, `.WithLineItems(params ...)`).
- Avoid shared mutable fixtures; prefer inline creation or per-test fixture classes.

## Mocking Guidelines

- Only mock external collaborators (I/O, time, random, repository, bus).
- Do not mock value objects.
- Default to strictness by verifying only meaningful interactions.

## Performance / Allocation

- Avoid premature optimization; but:
  - Use `AsNoTracking()` for read-only queries.
  - Avoid unnecessary `ToList()` materialization inside query pipelines.
  - Avoid large object graphs serialization unless required.

## Naming

- Events: past tense (e.g. `OrderPlacedEvent`).
- Commands: imperative (e.g. `PlaceOrderCommand`).
- Handlers: suffix with `Handler`.
- Repositories: `<AggregateRoot>Repository`.

## Git / PR Hygiene

- One logical concern per PR.
- PR description: What / Why / How / Risk / Rollback.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) — see `docs/DEVELOPER_WORKFLOW.md`.
  - Example: `feat(parser): add alternation support`

## Security

- Never embed secrets—use user secrets or environment variables.
- Validate all external inputs at boundaries (controllers, message consumers).
- Strive to follow the principle of least privilege in all access patterns.
- Strive to use quantum-resistant algorithms for cryptography where applicable.

## Copilot Prompting Hints

When asking Copilot for code:

- Specify: context (aggregate, EF entity, test scenario).
- Specify: required patterns (e.g. "value object with equality & validation").
- For tests: mention desired doubles, e.g. "use NSubstitute for IClock".

## Anti-Patterns (Avoid)

- Service classes that just forward to repository.
- Anemic domain models (add invariants to entities).
- Static utility god classes.
- Catch-all exception wrappers that rethrow without context.
- Copy/paste mapping logic (centralize with mappers or projection expressions).

## Interceptor-Specific Guidance

- DddInterceptor changes should include tests covering: audit, invariants, boundary violations, allowed extensions, soft delete semantics.
- Keep `ActionParameters` minimal—avoid adding transient computed values if derivable at call site.
- Order: Tenant -> Aggregate -> Audit -> Complete -> Validate (do not reorder without justification).

## Tooling / Analyzer Suggestions

- Add analyzers for: async usage, nullability misuse, concurrency tokens.
- Treat warnings as build errors for new code paths where feasible.

## Documentation

- Public surface: XML docs for all externally-consumed APIs.
- Limit to 128 characters per line.
- Internal code: only document non-obvious intent or domain rationale (avoid "what" duplication).
- Put the XML start and end element tags on their own lines, unless the internal text is short enough to fit the entire element
  on one line.
- Always proofread for spelling, grammar, and technical accuracy
- Include proper attribution and references (see "Documentation and Attribution" section above)

## Future Enhancements (Track Separately)

- Evaluate using `IClock` abstraction to remove direct time providers.
- Introduce domain events dispatch hook post-commit.
- Expand multi-tenant tests to include row-level security simulation.

## When discussing modifications or extensions to existing code

- Present the analysis with:
  - Problem statement
  - Mathematical proof (if applicable)
  - Trade-off analysis
  - Alternative approaches with pros/cons
  - Performance implications
  - Security/correctness considerations
- Ask before generating code:
  - "Would you like me to provide the complete implementation?"
  - "Should I generate the code for this approach?"
  - "Do you need the code, or would you like to implement it yourself?"
- Wait for your confirmation before writing:
  - Full implementation code
  - Test cases
  - Documentation snippets
- **When reviewing documentation or comments:**
  - Point out any spelling, grammar, or style issues
  - Suggest clearer or more idiomatic phrasing
  - Explain why the suggested change improves readability

---
(End of instructions – keep additions lean and purposeful; remove anything that drifts from active practice.)
