# vm2 Shared Conventions

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [vm2 Shared Conventions](#vm2-shared-conventions)
  - [For AI Coding Assistants](#for-ai-coding-assistants)
    - [Code Generation and File Editing](#code-generation-and-file-editing)
    - [PR Review](#pr-review)
    - [Language and Writing Quality](#language-and-writing-quality)
  - [Directory Structure](#directory-structure)
  - [Document Convention](#document-convention)
    - [Files with shared content](#files-with-shared-content)
  - [Dependency Management](#dependency-management)
    - [Files with shared content](#files-with-shared-content-1)
  - [Project Structure](#project-structure)
    - [Files with shared content](#files-with-shared-content-2)
  - [General C# Coding Conventions](#general-c-coding-conventions)
    - [Files with shared content](#files-with-shared-content-3)
  - [Async](#async)
  - [Services (if applicable)](#services-if-applicable)
  - [Error Handling](#error-handling)
  - [Testing](#testing)
    - [Files with shared content](#files-with-shared-content-4)
  - [Performance](#performance)
  - [Security](#security)
  - [Naming](#naming)
  - [Git and PR Hygiene](#git-and-pr-hygiene)
    - [Files with shared content](#files-with-shared-content-5)
  - [Documentation](#documentation)
  - [Markdown](#markdown)
  - [File Modification](#file-modification)
  - [CI / GitHub Actions](#ci--github-actions)

<!-- /TOC -->

The *vm2* family of repositories (packages, solutions, etc.) **share a common set of conventions** for the directory structure, project structure, coding style, documentation style, Git and PR hygiene, and more. This file documents these shared conventions to ensure **consistency across all repositories** and to provide guidance for contributors.

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

> [!NOTE]
> This file contains common conventions for contributing to the *vm2* repos targeting both humans and the AI coding systems. It is **copied to each repo's `.github/` directory**. The content of this file should be relatively stable and constant across repos. However, it may evolve over time as we learn and grow. Changes will be discussed, possibly leading to change in the SoT file at `$VM2_REPOS/vm2.Templates/templates/AddNewPackage/content/.github/CONVENTIONS.md`, and then propagate it to all repos.
>
> It is quite possible that some projects and solutions are "special" (e.g. vm2.DevOps) and require extra conventions and/or deviation from the shared conventions. `diff-shared.sh` allows for that: merge the source into the special target, instead of manual copy/paste. For more details about the `diff-shared.sh` script, clone the repo vm2.DevOps if you haven't done so and see the [tool's documentation](../vm2.DevOps/docs/diff-shared.md). Please, refrain from changing local copies of SoT files manually and thus deviating from the conventions in individual repos - use the tool.

## For AI Coding Assistants

This section consolidates instructions specifically for AI coding assistants (Claude, Copilot, etc.). The conventions in the rest of this document apply to all contributors — human and AI alike.

### Code Generation and File Editing

- **Wrap complete generated Markdown files in tilde fences** (`~~~markdown`) so the user can copy them cleanly
- Do not remove commented-out code without explicit permission
- Preserve YAML/JSON comments in configuration files
- For GitHub Actions workflows: preserve commented-out alternatives and explanatory notes

### PR Review

- If a PR addresses more than one logical concern, **reject it** and request it be split — do not approve or suggest improvements until the scope is reduced to one concern

### Language and Writing Quality

The project owner is a non-native English speaker.

- Always check spelling, grammar, and technical English in all documentation and comments
- Recommend better wording for unclear, passive, or awkward sentences
- Prefer active voice
- Explain why a suggested change improves the text
- Examples:
  - ❌ "The pattern is being matched by the enumerator"
  - ✅ "The enumerator matches the pattern"

## Directory Structure

- For ease of locating repositories (repos), solutions, and project files and for ease of parameter specification in the cross solution tools, the repos of **all solutions are located under a single parent folder** (e.g. `~/repos/vm2/`). This parent folder is not committed to git, but **its existence is a convention for local organization of the repos**. By convention this folder is specified by the **global environment variable `VM2_REPOS`**. However, every cross-solution tool or script also accepts an option (named parameter) **--vm2-repos** that overrides the env. variable. If neither is specified, the tools and scripts assume default location `$HOME/repos/vm2/` which may not be what you'd like or what other contributors are using, so **it is recommended to set the env. variable VM2_REPOS**
- Usually **every .NET solution is placed in one git repository** and has one or more closely related C# projects, e.g. source code projects, test projects, benchmark projects, examples, etc. Sometimes in the documentation and colloquial speech **we use "solution" and "repository" interchangeably**, but it always means the same thing: a repository that contains one solution with one or more projects in it
- The solutions may produce one or more NuGet packages, dotnet tools, templates, set of scripts (vm2.DevOps), containerized services, etc
- Use the set of shared tools (scripts) for cross-solution tasks like building, testing, benchmarking, code coverage, changelog generation, etc. To make them available to all solutions, keep them in a separate repository in **$VM2_REPOS/vm2.DevOps** that must be cloned locally alongside the other solution repos
- To propagate many of the conventions and environmental choices **do not share content with git submodules or symlinks**. This can be difficult to work with across different OSes, platforms and IDEs. Use a **copy-and-merge strategy for shared content**
- The **source-of-truth files (SoT)** for shared content are located in the **`$VM2_REPOS/vm2.Templates/templates/AddNewPackage/content/`**. The solution `vm2.Templates` is a C# template solution for creating new solutions that produce a NuGet package with `dotnet new vm2pkg <solution name>`, therefore the `vm2.Templates` solution should also be cloned and synced often
- When shared content needs to be updated (add/modify/delete a convention, setting, variable, dependency version),
  1. **first update the source-of-truth file in vm2.Templates**
  1. Build and deploy the template package to NuGet repository
  1. **Use the `diff-shared.sh` script to propagate the changes** to all existing repos

  This way, all new projects created with the template and all existing projects will have the latest content and will be following the latest conventions.

## Document Convention

- Files that should be identical across all repos are marked with an asterisk **\***. If any of those change, **the sharing tool will copy the content of the source SoT file over the target repo's corresponding file**
- Files which content is only partially shared are marked with a double asterisk **\*\***. If any of those change, **the sharing tool will display the differences and ask if you want to ignore the new content, copy the new content (overwriting the existing file), or merge the new content with the existing file** (both the diff tool and the merge tool are configurable in the script or use the git defaults - see the documentation for details)
- Files that are not shared and should be maintained separately in each repo are not marked
- These conventions are implemented by the `diff-shared.sh` script, which is used to propagate changes from the source-of-truth files in the template content folder to the target repos. The script can be configured to specify which files are shared and how to handle changes to them. For even more nuanced and flexible control, it defines 6 different actions for handling changes to shared files:
  - **`ignore`**: do not update the target file, keep it as is
  - **`merge_or_copy`**: ask the user to choose between ignoring, merging or copying the new content over the existing the new content.
  - **`ask_to_merge`**: ask the user if they want to merge the new content with the existing file; if they choose not to merge, do not update the target file
  - **`merge`**: open the merge utility without asking the user to merge the new content with the existing file, preserving both the shared content and the repo-specific content
  - **`ask_to_copy`**: ask the user if they want to copy the new content over the existing file; if they choose not to copy, do not update the target file
  - **`copy`**: copy the new content over the existing file (overwriting it) without asking

  By default all documents marked with **\*** are set to `copy`, and all documents marked with **\*\*** are set to `merge_or_copy`.

  For more details on how to use the `diff-shared.sh` script, see the [tool's documentation](../vm2.DevOps/docs/diff-shared.md).

### Files with shared content

- `.editorconfig` **\*** — **authoritative code style and analyzers** (used by IDEs and dotnet CLI)

## Dependency Management

- **Use `Directory.Build.props` and `Directory.Packages.props` for shared build configuration and centralized package version management**. Each project file (`*.csproj`) references the shared properties and packages that it uses without versions (unless they are already referenced in `Directory.Build.props`). This ensures consistency across all projects and makes it easier to update dependencies in one place. That's why our *.csproj files are surprisingly small and clean
- **Restore the project's dependencies with `dotnet restore --use-lock-file`** to ensure that the exact versions specified in the lock files are used, and to prevent unintended updates of dependencies
- **Build projects and solutions with `dotnet restore --use-lock-file ... && dotnet build --no-restore ...`**
- If the dependencies changed **update the version in `Directory.Packages.props`, then run `dotnet restore --force-evaluate` to update the lock files, and commit both the updated `Directory.Packages.props` and the updated `packages.lock.json` files**
- Dependabot configuration is defined in `.github/dependabot.yml` * and should be set up to check for updates in the `Directory.Packages.props` file, which is the source of truth for package versions. This way, when a new version of a dependency is released, dependabot will create a PR with the updated version in `Directory.Packages.props`, and then you can review, merge, and then run `dotnet restore --force-evaluate` to update the lock files

### Files with shared content

- `global.json` **\*** — shared SDK version and global tool versions
- `Directory.Build.props` **\*\*** — shared build configuration
- `Directory.Packages.props` **\*\*** — centralized package versions
- `*.csproj` - always prefer referencing shared packages and settings from the above files, without versions, to ensure consistency and ease of maintenance
- `packages.lock.json` — generated by `dotnet restore --use-lock-file` to lock down exact dependency versions; must be committed to source control; update by running `dotnet restore --force-evaluate` after changing versions in `Directory.Packages.props`
- `NuGet.config` **\*** — for custom package sources or credentials, e.g. GitHub Packages, Azure Artifacts, etc. Create with `dotnet new nugetConfig` and then customize as needed. The SoT version of the file is usually enough

## Project Structure

- Solutions: **`.slnx` format** (Visual Studio 2022+)
- Package versions: **Central Package Management via `Directory.Packages.props`**
- Project files: **SDK-style**
- Global usings: defined in **`usings.cs` per project**
- Standard folder layout:
  - `src/` — source code
  - `test/` — test projects. The stack is: **xUnit, FluentAssertions, NSubstitute, MTP v2, coverage**
  - `benchmarks/` — **BenchmarkDotNet** projects (desirable)
  - `examples/` — usage examples (desirable). Prefer single-file programs for simplicity, but multi-file projects are acceptable if the example is complex enough to warrant it.
  - `docs/` — documentation (optional, in addition to README.md, e.g. blogs, design docs, etc.)
  - `.github/workflows/` — **GitHub Actions CI/CD**:
    - `CI.yaml` kicks-in the **inputs validation, build, test, benchmark, and package** shared workflows
    - `Prerelease.yaml` for **prerelease workflows**: computes the pre-release version, e.g. `1.2.0-preview.3`; tags the main branch with a tag like `v1.2.0-preview.3`; builds pre-release package(s); **publishes the pre-release packages to GitHub Packages or NuGet.org**; **updates CHANGELOG.md** using cliff-git. Triggered by a successful merge of a pull request
    - `Release.yaml` for **release workflows**: computes the release version, e.g. `1.2.0`; tags the main branch with a tag like `v1.2.0`; builds release package(s); **publishes the pre-release packages to GitHub Packages or NuGet.org**; **updates CHANGELOG.md** using cliff-git. Triggered manually when we want to cut a release, usually after a successful prerelease validation

### Files with shared content

- `.github/`:
  - `PULL_REQUEST_TEMPLATE.md` **\*** — shared **PR description template**
  - `dependabot.yml` **\*** — shared **dependabot configuration** for automated dependency updates
  - `CONVENTIONS.md` **\*** — **this file**: **shared conventions for contributing to the repo**, including coding style, testing, documentation, Git hygiene, etc. This file itself is shared content and should be identical across all repos. **Used by Claude AI**. Usually copied without modification from SoT
  - `copilot-instructions.md` **\*** — **instructions for Copilot** to ensure consistent code generation style and patterns across all repos. Usually it refers to the `CONVENTIONS.md` file and is copied without modification from SoT
  - `workflows/`:
    - `CI.yaml` **\*\*** — **continuous integration (CI) workflow. Declares the build, test, benchmark, and packaged projects** and possible other differences. Usually this file merges the SoT file to preserve the repo-specific differences in the workflow configuration.
    - `Prerelease.yaml` **\*\*** — **prerelease workflow. Declares the packaged pre-release projects**. Usually this file merges the SoT file to preserve the repo-specific differences in the workflow configuration.
    - `Release.yaml` **\*\*** — **release workflow. Declares the packaged release projects**. Usually this file merges the SoT file to preserve the repo-specific differences in the workflow configuration.

## General C# Coding Conventions

- **See .editorconfig** first
- File-scoped namespaces
- Implicit usings for common namespaces (defined in `usings.cs`)
- `record` for immutable data models and DTOs
- `readonly record struct` for small immutable value objects (e.g. `Ulid`, `Result<T>`, etc.)
- `internal` by default; **`public` only for intentional API surface**
- `sealed` by default; open **only** when extensibility is required and justified
- Expression-bodied members when trivial and readable, e.g. one-liners, simple getters, etc.
- `var` when the type is obvious from the right-hand side
- **Nullable reference types always enabled**; treat warnings as design feedback.
- **No static mutable state** unless guarded with **proper encapsulation and synchronization** (prefer `ReaderWriterLockSlim` over `Lock`, `Mutex`, `Event`)
- **Dependency injection** over service locator
- Guard clauses at method entry (throw early, no nested pyramids)
- Pattern matching (`is`, `switch` expressions) over `if`/`else` chains when semantically clearer
- No curly braces for single-line blocks unless they improve readability
- `#region` / `#endregion` acceptable for logical grouping in larger files, especially interface implementations, and generated code
- EBNF (ISO 14977) for grammar definitions: `=` definitions, `,` concatenation, `;` rule terminator, `[ ]` optional, `|` alternation, `"..."` terminals.

### Files with shared content

- `.editorconfig` **\*** — **authoritative code style and analyzers** (used by IDEs and dotnet CLI)

## Async

- Async methods suffixed with `Async`
- `CancellationToken ct` **threaded through all async call chains**
- **No fire-and-forget** except documented background operations, e.g. `Task.Run` for CPU-bound work, or explicitly detached background tasks with proper error handling and logging
- `ValueTask` only when allocation reduction is measurable (hot paths, cached results)

## Services (if applicable)

- For inter-service communications **prefer async APIs** with `Task`/`ValueTask` over synchronous APIs, even if the current implementation is synchronous, to allow for future async implementations without breaking changes
- For inter-service communications within a (k8s) cluster **prefer gRPC and messaging** over HTTP/REST for better performance and reliability, even if the current implementation is HTTP/REST, to allow for future gRPC/messaging implementations without breaking changes

## Error Handling

- **Always consider using `Result<T>` for expected failure modes** instead of exceptions
- **Never use exceptions for expected control flow** (e.g. not found) — prefer `Result<T>` or similar patterns instead
- **Exceptions for unrecoverable failures only** (e.g. `ArgumentException`)
- Railway patterns (`Result<T>`) for short throws and flow control.
- `Try...` patterns preferred over broad exception-based control flow.
- **Domain-specific exceptions** for business rule violations
- **Never swallow exceptions** — log or rethrow
- **Never log sensitive data** (PII, secrets)
- **Use logger scopes** for contextual information, not string concatenation or interpolation in log messages
- **Prefer `ILogger<T>`** with structured logging over static loggers or string-based logging
- In services with external dependencies, prefer **circuit breakers and retries** over exceptions for transient faults
- In services use **health checks and monitoring** to detect and respond to failures instead of relying on exceptions for observability
- In services for distributed systems **use Open Telemetry** for distributed tracing and metrics to understand system behavior and failures instead of relying on exceptions alone

## Testing

- Framework: **xUnit v3 with Microsoft Testing Platform (MTP) v2**
- Assertions: **FluentAssertions** (never `Assert.*` unless framework-specific)
- Mocks: **NSubstitute**
- Use vm2.TestUtilities:
  - **for easy locating failing theory tests** with `TestUtilities.PathLine()`, etc.
  - **use the `XUnitLogger` for capturing structured logs** in tests without needing to set up a real logger
  - **use `TestBase`** to
    - derive test classes and **inherit `ITestOutputHelper Out`**
    - **suppress the `FluentAssertions` licensing messages** (we bought it)
    - to have the **`FluentAssertionsExceptionFormatter`  that usually hides nested exceptions**
- Naming:
  - Sync:  `MethodName_WhenCondition_ShouldOutcome`
  - Async: `MethodName_WhenCondition_ShouldOutcome_Async`
- Arrange / Act / Assert with clear blank-line separation
- One logical assertion per test (chained FluentAssertions counts as one)
- No testing of implementation details; mock only observable behavior
- `[Trait("Category","Integration")]` for slow or external-dependency tests (usually integration tests)
- Inject mock clock abstractions — never `DateTime.UtcNow` directly in tests
- Inject mock ID providers — never rely on live generation in tests
- Only mock external collaborators (I/O, time, random, repository, bus)
- Do not mock value objects

### Files with shared content

- `Directory.Build.props` **\*\*** — shared build configuration for tests and test libraries, including referencing and configuring the test stack: MTP v2, xUnit, FluentAssertions, NSubstitute, code coverage
- `Directory.Packages.props` **\*\*** — centralized package versions for tests and test libraries, including referencing and configuring the test stack: MTP v2, xUnit, FluentAssertions, NSubstitute, code coverage
- `codecov.yml` **\*** — shared codecov configuration for codecov.io, e.g. repository token, upload settings, etc. This file is used by the CI pipeline to configure codecov reporting
- `coverage.settings.xml` **\*** — shared code coverage configuration for Coverlet, e.g. include/exclude filters, thresholds, etc. This file is used by the CI pipeline to configure code coverage collection and reporting
- `testconfig.json` **\*** — shared test configuration, e.g. test timeouts, parallelization settings, etc. This file is used by the test projects to configure the test runner (MTP)

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

- Commit messages: `<type>[(scope)][!]: <description>` - where scope is optional `!` marks **breaking change(s)**
  - `fix: correct null reference in UserService`
  - `feat(serialization): add IUtf8SpanFormattable implementation`
- One logical concern per PR (Val!)

### Files with shared content

- `.github/PULL_REQUEST_TEMPLATE.md` **\*** — PR description: What / Why / How / Risk / Rollback
- `.gitmessage` **\*** — shared Git commit message template with EBNF format and examples

## Documentation

- **Technical and specification documents** (README, design docs, CONVENTIONS, XML docs, API specs, etc.) **MUST** include the RFC 2119 boilerplate at the top: "The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119)."
- **Blogs and free-form articles** (e.g. `docs/blog-*.md`) **MUST NOT** use RFC 2119 keywords as normative terms — in prose, MUST and SHOULD are emphasis, not specifications
- Use clear, concise language with proper grammar and spelling
- Prefer active voice and direct statements
- Explain the "why" and intent behind decisions, not just the "what"
- Use examples to illustrate complex concepts or usage patterns
- **XML docs on all public API surface** at least
- Line length: 128 characters maximum
- Internal code: **document intent and rationale only** — not what the code does (the code should be clear enough on its own)
- XML tags on their own lines unless the content fits on one line
- Always **proofread for spelling, grammar, and technical accuracy**
- **Cite specifications** (POSIX, RFC, SemVer, ULID spec, etc.) with title and URL
- **README code examples must be self-contained and runnable**: include all required `using` directives, declare all variables, and avoid unexplained placeholders (`...`, `// ...`). **A reader must be able to paste the example into a project and have it compile without guessing missing context**
- Standard references block format:

      ## References
      - [Title](URL) — Author or organization

## Markdown

- **Follow markdownlint default rules** (or `.markdownlint.json` if present).
- Use 4-space indentation for code blocks inside Markdown content.
- **Use `1.` for all items in ordered lists** (renderers number automatically).
- Prefer kebab-case in YAML; avoid snake_case unless required by external schema.

## File Modification

- **Preserve existing comments** unless correcting inaccuracies or improving English
- **Document why new code exists**, not just what it does
- Do not remove commented-out code without explicit permission
- Preserve YAML/JSON comments in configuration files
- For GitHub Actions workflows: preserve commented-out alternatives and explanatory notes

## CI / GitHub Actions

When adding a new project, register it in `.github/workflows/CI.yaml`:

| Array                | Purpose                     |
|----------------------|-----------------------------|
| `BUILD_PROJECTS`     | Solutions/projects to build |
| `TEST_PROJECTS`      | Test projects to run        |
| `BENCHMARK_PROJECTS` | Benchmark projects to run   |
| `PACKAGE_PROJECTS`   | Projects to pack as NuGet   |

Also, add the project to the `.slnx` solution file under the appropriate folder.

---
*Canonical source: vm2.Templates/templates/AddNewPackage/content/.github/CONVENTIONS.md*
*Copies maintained by diff-shared.sh — edit the canonical copy first.*
